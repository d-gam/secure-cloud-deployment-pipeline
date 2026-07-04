output "dynamodb_table_name" {
  description = "Name of the DynamoDB table created for to-do items"
  value       = aws_dynamodb_table.todos.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.todos.arn
}

output "api_endpoint" {
  description = "Base URL of the deployed HTTP API — use this to test with curl"
  value       = aws_apigatewayv2_api.todo_api.api_endpoint
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain — this is the public entry point to use instead of the raw API Gateway URL, since it adds security headers to all responses"
  value       = "https://${aws_cloudfront_distribution.api_distribution.domain_name}"
}
