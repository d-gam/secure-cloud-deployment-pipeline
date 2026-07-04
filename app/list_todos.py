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
    result = table.scan()
    items = result.get("Items", [])

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Strict-Transport-Security": "max-age=63072000; includeSubDomains",
            "X-Content-Type-Options": "nosniff",
            "Cross-Origin-Resource-Policy": "cross-origin",
        },
        "body": json.dumps(items),
    }
