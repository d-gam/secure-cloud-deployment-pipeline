"""
create_todo.py

Lambda function: creates a new to-do item in DynamoDB.

Triggered by: API Gateway (POST /todos)
Expected input (event body, JSON): { "title": "Buy milk" }
Returns: 201 with the created item, or 400 if validation fails.
"""

import json
import os
import uuid
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON in request body"})

    title = body.get("title", "").strip()

    # --- Input validation (ISTQB: boundary value / equivalence partitioning applied) ---
    # Equivalence classes considered: empty string, missing field, valid string,
    # excessively long string (boundary check).
    if not title:
        return _response(400, {"error": "Field 'title' is required and cannot be empty"})

    if len(title) > 200:
        return _response(400, {"error": "Field 'title' must be 200 characters or fewer"})

    item = {
        "id": str(uuid.uuid4()),
        "title": title,
        "completed": False,
    }

    table.put_item(Item=item)

    return _response(201, item)


def _response(status_code, body_dict):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body_dict),
    }
