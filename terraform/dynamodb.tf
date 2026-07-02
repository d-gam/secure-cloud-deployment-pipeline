# DynamoDB table to store to-do items.
#
# Using on-demand (PAY_PER_REQUEST) billing mode instead of provisioned capacity.
# This means we only pay for the requests we actually make — ideal for a low-traffic
# portfolio project, and safely within the AWS Free Tier (25 GB storage + 25 WCU/RCU
# equivalent always free).

resource "aws_dynamodb_table" "todos" {
  name         = "${var.project_name}-todos-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # String — we'll use a UUID as the primary key for each to-do item
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
