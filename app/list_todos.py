"""
list_todos.py

Lambda function: returns all to-do items from DynamoDB.

Triggered by: API Gateway (GET /todos)
Returns: 200 with a JSON array of items.
"""

import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    # Note: table.scan() reads the entire table. That's fine at this project's scale
    # (a portfolio to-do app), but in a production system with a large table you'd
    # want a Query with an index instead, to avoid high read costs and latency.
    result = table.scan()
    items = result.get("Items", [])

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(items),
    }
