"""
delete_todo.py

Lambda function: deletes a to-do item from DynamoDB by id.

Triggered by: API Gateway (DELETE /todos/{id})
Returns: 200 on success, 404 if the item doesn't exist, 400 if id is missing.
"""

import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")

    if not item_id:
        return _response(400, {"error": "Path parameter 'id' is required"})

    existing = table.get_item(Key={"id": item_id})
    if "Item" not in existing:
        return _response(404, {"error": f"No to-do item found with id '{item_id}'"})

    try:
        table.delete_item(Key={"id": item_id})
    except ClientError as e:
        return _response(500, {"error": str(e)})

    return _response(200, {"message": f"Item '{item_id}' deleted"})


def _response(status_code, body_dict):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Strict-Transport-Security": "max-age=63072000; includeSubDomains",
            "X-Content-Type-Options": "nosniff",
            "Cross-Origin-Resource-Policy": "cross-origin",
        },
        "body": json.dumps(body_dict),
    }
