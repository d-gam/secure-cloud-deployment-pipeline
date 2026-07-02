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
