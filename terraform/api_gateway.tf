# API Gateway (HTTP API — simpler and cheaper than REST API, sufficient for this project).
#
# Routes:
#   POST   /todos       -> create_todo Lambda
#   GET    /todos        -> list_todos Lambda
#   DELETE /todos/{id}  -> delete_todo Lambda

resource "aws_apigatewayv2_api" "todo_api" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # fine for a portfolio demo; would be locked down to a specific domain in production
    allow_methods = ["GET", "POST", "DELETE"]
    allow_headers = ["content-type"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Auto-deploying stage — every change is deployed immediately, no manual "deploy" step.
# Simple and appropriate for a portfolio project; a production setup might use named
# stages (dev/staging/prod) with manual promotion instead.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.todo_api.id
  name        = "$default"
  auto_deploy = true
}

# --- Integrations: connect each route to its Lambda function ---

resource "aws_apigatewayv2_integration" "create_todo" {
  api_id                 = aws_apigatewayv2_api.todo_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_todo.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list_todos" {
  api_id                 = aws_apigatewayv2_api.todo_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list_todos.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "delete_todo" {
  api_id                 = aws_apigatewayv2_api.todo_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.delete_todo.invoke_arn
  payload_format_version = "2.0"
}

# --- Routes: map HTTP method + path to an integration ---

resource "aws_apigatewayv2_route" "create_todo" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "POST /todos"
  target    = "integrations/${aws_apigatewayv2_integration.create_todo.id}"
}

resource "aws_apigatewayv2_route" "list_todos" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "GET /todos"
  target    = "integrations/${aws_apigatewayv2_integration.list_todos.id}"
}

resource "aws_apigatewayv2_route" "delete_todo" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "DELETE /todos/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.delete_todo.id}"
}

# --- Permissions: allow API Gateway to invoke each Lambda ---

resource "aws_lambda_permission" "create_todo" {
  statement_id  = "AllowAPIGatewayInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_todo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.todo_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "list_todos" {
  statement_id  = "AllowAPIGatewayInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_todos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.todo_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "delete_todo" {
  statement_id  = "AllowAPIGatewayInvokeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_todo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.todo_api.execution_arn}/*/*"
}
