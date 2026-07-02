"""
test_create_todo.py

Test suite for POST /todos.

Test design approach (ISTQB techniques applied explicitly):

1. Equivalence Partitioning — the 'title' field is divided into these classes:
   - Valid class: a normal, non-empty string within the length limit
   - Invalid class: empty string
   - Invalid class: missing field entirely
   One representative test per class, rather than testing many similar valid inputs.

2. Boundary Value Analysis — the 200-character length limit is a boundary. We test:
   - Exactly at the boundary (200 chars) — should be VALID
   - Just over the boundary (201 chars) — should be INVALID
   Boundaries are where off-by-one errors typically hide, so these are tested explicitly
   rather than just testing "a short string" and "a very long string".
"""

import requests
from conftest import create_todo, delete_todo


class TestCreateTodoEquivalencePartitioning:
    """Equivalence classes for the 'title' field."""

    def test_valid_title_creates_todo(self, api_url):
        """Valid equivalence class: a normal non-empty title should succeed."""
        response = create_todo(api_url, "Buy milk")
        assert response.status_code == 201

        body = response.json()
        assert body["title"] == "Buy milk"
        assert body["completed"] is False
        assert "id" in body

        # Cleanup
        delete_todo(api_url, body["id"])

    def test_empty_title_is_rejected(self, api_url):
        """Invalid equivalence class: empty string should be rejected with 400."""
        response = create_todo(api_url, "")
        assert response.status_code == 400
        assert "error" in response.json()

    def test_missing_title_field_is_rejected(self, api_url):
        """Invalid equivalence class: missing field entirely should be rejected with 400."""
        response = requests.post(f"{api_url}/todos", json={})
        assert response.status_code == 400
        assert "error" in response.json()

    def test_whitespace_only_title_is_rejected(self, api_url):
        """
        Invalid equivalence class: a title that is only whitespace should be treated
        the same as empty, since it carries no real content once trimmed.
        """
        response = create_todo(api_url, "   ")
        assert response.status_code == 400


class TestCreateTodoBoundaryValueAnalysis:
    """Boundary values around the 200-character title length limit."""

    def test_title_at_200_characters_is_accepted(self, api_url):
        """Exactly at the boundary (200 chars) — should be the last VALID value."""
        title = "a" * 200
        response = create_todo(api_url, title)
        assert response.status_code == 201

        body = response.json()
        delete_todo(api_url, body["id"])  # cleanup

    def test_title_at_201_characters_is_rejected(self, api_url):
        """Just past the boundary (201 chars) — should be the first INVALID value."""
        title = "a" * 201
        response = create_todo(api_url, title)
        assert response.status_code == 400

    def test_title_at_199_characters_is_accepted(self, api_url):
        """One below the boundary — sanity check that valid values just under the limit work."""
        title = "a" * 199
        response = create_todo(api_url, title)
        assert response.status_code == 201

        body = response.json()
        delete_todo(api_url, body["id"])  # cleanup
