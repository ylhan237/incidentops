output "api_url" {
  description = "HTTP API endpoint."
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "cloudfront_url" {
  description = "CloudFront distribution URL for the static site."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidations."
  value       = aws_cloudfront_distribution.site.id
}

output "site_bucket_name" {
  description = "Private S3 bucket used for the static frontend."
  value       = aws_s3_bucket.site.bucket
}

output "incidents_table_name" {
  description = "DynamoDB table used by the incidents API."
  value       = aws_dynamodb_table.incidents.name
}

output "gitlab_deploy_role_arn" {
  description = "IAM role ARN for GitLab OIDC deployments."
  value       = var.enable_gitlab_oidc ? aws_iam_role.gitlab_deploy[0].arn : null
}

output "lambda_log_group_name" {
  description = "CloudWatch log group automatically used by Lambda execution logs."
  value       = "/aws/lambda/${aws_lambda_function.api.function_name}"
}

output "api_access_log_group_name" {
  description = "CloudWatch log group for API Gateway access logs."
  value       = aws_cloudwatch_log_group.api_access.name
}

output "alarm_topic_arn" {
  description = "SNS topic ARN used by CloudWatch alarms. Null when alarm_email is empty."
  value       = var.alarm_email != "" ? aws_sns_topic.alarms[0].arn : null
}
