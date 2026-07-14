locals {
  name_prefix = "${var.project_name}-${var.environment}"
  gitlab_host = replace(replace(var.gitlab_url, "https://", ""), "http://", "")

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_dynamodb_table" "incidents" {
  name         = "${local.name_prefix}-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_s3_bucket" "site" {
  bucket = "${local.name_prefix}-site-${random_id.suffix.hex}"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.name_prefix}-site-oac"
  description                       = "OAC for the IncidentOps static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "site"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags
}

data "aws_iam_policy_document" "site_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket.json
}

data "archive_file" "api" {
  type        = "zip"
  source_file = "${path.module}/../../../../src/api/handler.py"
  output_path = "${path.module}/api.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "${local.name_prefix}-api-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "api_dynamodb" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
    ]

    resources = [aws_dynamodb_table.incidents.arn]
  }
}

resource "aws_iam_policy" "api_dynamodb" {
  name   = "${local.name_prefix}-api-dynamodb"
  policy = data.aws_iam_policy_document.api_dynamodb.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "api_dynamodb" {
  role       = aws_iam_role.api.name
  policy_arn = aws_iam_policy.api_dynamodb.arn
}

resource "aws_lambda_function" "api" {
  function_name    = "${local.name_prefix}-incidents-api"
  role             = aws_iam_role.api.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.incidents.name
      ENVIRONMENT = var.environment
    }
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_api" "api" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "*"
    ]

    allow_methods = [
      "GET",
      "POST",
      "PATCH",
      "OPTIONS",
    ]

    allow_headers = [
      "content-type",
    ]
  }
}

resource "aws_apigatewayv2_integration" "api" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

resource "aws_apigatewayv2_route" "update_incident" {
  api_id = aws_apigatewayv2_api.api.id

  route_key = "PATCH /incidents/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

resource "aws_apigatewayv2_route" "list_create_incidents" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /incidents"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

resource "aws_apigatewayv2_route" "get_incident" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /incidents/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationErr = "$context.integrationErrorMessage"
    })
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.name_prefix}-api-access-${random_id.suffix.hex}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_sns_topic" "alarms" {
  count = var.alarm_email != "" ? 1 : 0

  name = "${local.name_prefix}-alarms"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  alarm_description   = "Triggers when the incidents Lambda returns errors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name_prefix}-api-5xx"
  alarm_description   = "Triggers when API Gateway returns server-side errors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.api.id
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  count = var.enable_gitlab_oidc ? 1 : 0

  url            = var.gitlab_url
  client_id_list = [var.gitlab_oidc_audience]

  tags = local.common_tags
}

data "aws_iam_policy_document" "gitlab_deploy_assume_role" {
  count = var.enable_gitlab_oidc ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.gitlab[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.gitlab_host}:aud"
      values   = [var.gitlab_oidc_audience]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.gitlab_host}:sub"
      values   = ["project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.gitlab_deploy_branch}"]
    }
  }
}

resource "aws_iam_role" "gitlab_deploy" {
  count = var.enable_gitlab_oidc ? 1 : 0

  name               = "${local.name_prefix}-gitlab-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.gitlab_deploy_assume_role[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "gitlab_deploy" {
  count = var.enable_gitlab_oidc ? 1 : 0

  statement {
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]

    resources = [
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*"
    ]
  }

  statement {
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_policy" "gitlab_deploy" {
  count = var.enable_gitlab_oidc ? 1 : 0

  name   = "${local.name_prefix}-gitlab-deploy"
  policy = data.aws_iam_policy_document.gitlab_deploy[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "gitlab_deploy" {
  count = var.enable_gitlab_oidc ? 1 : 0

  role       = aws_iam_role.gitlab_deploy[0].name
  policy_arn = aws_iam_policy.gitlab_deploy[0].arn
}
