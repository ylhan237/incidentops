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
