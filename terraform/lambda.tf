# Lambda functions.
#
# Each function is packaged as a zip built automatically by Terraform from the
# corresponding .py file in ../app. Using archive_file means we don't have to
# manually zip anything — Terraform handles it and re-zips automatically whenever
# the source file changes, so `terraform plan` correctly detects code changes.

data "archive_file" "create_todo" {
  type        = "zip"
  source_file = "${path.module}/../app/create_todo.py"
  output_path = "${path.module}/build/create_todo.zip"
}

data "archive_file" "list_todos" {
  type        = "zip"
  source_file = "${path.module}/../app/list_todos.py"
  output_path = "${path.module}/build/list_todos.zip"
}

data "archive_file" "delete_todo" {
  type        = "zip"
  source_file = "${path.module}/../app/delete_todo.py"
  output_path = "${path.module}/build/delete_todo.zip"
}

resource "aws_lambda_function" "create_todo" {
  function_name    = "${var.project_name}-create-todo-${var.environment}"
  role              = aws_iam_role.lambda_exec.arn
  handler           = "create_todo.handler"
  runtime           = "python3.12"
  filename          = data.archive_file.create_todo.output_path
  source_code_hash  = data.archive_file.create_todo.output_base64sha256
  timeout           = 10 # seconds — generous for a simple DynamoDB write

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todos.name
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_function" "list_todos" {
  function_name    = "${var.project_name}-list-todos-${var.environment}"
  role              = aws_iam_role.lambda_exec.arn
  handler           = "list_todos.handler"
  runtime           = "python3.12"
  filename          = data.archive_file.list_todos.output_path
  source_code_hash  = data.archive_file.list_todos.output_base64sha256
  timeout           = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todos.name
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_function" "delete_todo" {
  function_name    = "${var.project_name}-delete-todo-${var.environment}"
  role              = aws_iam_role.lambda_exec.arn
  handler           = "delete_todo.handler"
  runtime           = "python3.12"
  filename          = data.archive_file.delete_todo.output_path
  source_code_hash  = data.archive_file.delete_todo.output_base64sha256
  timeout           = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todos.name
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
