# IAM role that all three Lambda functions will assume when running.
#
# Security design note: rather than using a broad managed policy, we write a custom
# policy scoped to exactly the actions needed on exactly this one DynamoDB table
# (least privilege principle). This is worth highlighting in interviews — it's the
# difference between "it works" and "it works safely."

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Basic CloudWatch Logs permissions — every Lambda needs these to write logs.
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom least-privilege policy: only the specific DynamoDB actions each function
# needs, only on our one table (not "dynamodb:*" on "*").
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.project_name}-dynamodb-access-${var.environment}"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",   # used by create_todo
          "dynamodb:Scan",      # used by list_todos
          "dynamodb:GetItem",   # used by delete_todo (existence check)
          "dynamodb:DeleteItem" # used by delete_todo
        ]
        Resource = aws_dynamodb_table.todos.arn
      }
    ]
  })
}
