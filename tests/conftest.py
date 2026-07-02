"""
conftest.py

Shared pytest fixtures for the API test suite.

The API base URL is read from the API_URL environment variable rather than hardcoded,
so the exact same test suite can run against any deployment (local, dev, CI/CD, prod)
without code changes — just by setting a different environment variable.
"""

import os
import pytest
import requests


@pytest.fixture(scope="session")
def api_url():
    """Base URL of the deployed API, e.g. https://xxxx.execute-api.eu-west-1.amazonaws.com"""
    url = os.environ.get("API_URL")
    if not url:
        pytest.fail(
            "API_URL environment variable is not set. "
            "Run: export API_URL=https://your-api-id.execute-api.eu-west-1.amazonaws.com"
        )
    return url.rstrip("/")


@pytest.fixture
def created_todo_ids():
    """
    Tracks IDs of to-do items created during a test, so they can be cleaned up
    afterwards — keeps the DynamoDB table tidy between test runs regardless of
    whether the test passed or failed.
    """
    ids = []
    yield ids
    # Teardown: nothing to do here directly: cleanup itself happens in the test
    # via the api_url fixture + requests, kept explicit in each test for clarity.


def create_todo(api_url, title):
    """Helper: create a to-do item and return the parsed JSON response + status code."""
    response = requests.post(f"{api_url}/todos", json={"title": title})
    return response


def delete_todo(api_url, item_id):
    """Helper: delete a to-do item by id."""
    return requests.delete(f"{api_url}/todos/{item_id}")
