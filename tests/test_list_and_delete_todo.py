"""
test_list_and_delete_todo.py

Test suite for GET /todos and DELETE /todos/{id}.

Continues the same test design approach as test_create_todo.py: equivalence
partitioning for the delete endpoint (valid existing id vs. non-existent id),
plus a state-based end-to-end scenario for list + delete together.
"""

import requests
from conftest import create_todo, delete_todo


class TestListTodos:
    def test_list_returns_created_item(self, api_url):
        """A created item should appear in the list response."""
        create_response = create_todo(api_url, "Test list item")
        created_id = create_response.json()["id"]

        list_response = requests.get(f"{api_url}/todos")
        assert list_response.status_code == 200

        items = list_response.json()
        ids_in_list = [item["id"] for item in items]
        assert created_id in ids_in_list

        # Cleanup
        delete_todo(api_url, created_id)

    def test_list_returns_json_array(self, api_url):
        """The list endpoint should always return a JSON array, even if empty."""
        response = requests.get(f"{api_url}/todos")
        assert response.status_code == 200
        assert isinstance(response.json(), list)


class TestDeleteTodo:
    """Equivalence classes for DELETE /todos/{id}: existing id vs. non-existent id."""

    def test_delete_existing_item_succeeds(self, api_url):
        """Valid equivalence class: deleting an id that exists should succeed."""
        create_response = create_todo(api_url, "To be deleted")
        item_id = create_response.json()["id"]

        delete_response = delete_todo(api_url, item_id)
        assert delete_response.status_code == 200
        assert "message" in delete_response.json()

    def test_deleted_item_no_longer_appears_in_list(self, api_url):
        """State check: after deletion, the item should not appear in GET /todos."""
        create_response = create_todo(api_url, "Temporary item")
        item_id = create_response.json()["id"]

        delete_todo(api_url, item_id)

        list_response = requests.get(f"{api_url}/todos")
        ids_in_list = [item["id"] for item in list_response.json()]
        assert item_id not in ids_in_list

    def test_delete_nonexistent_id_returns_404(self, api_url):
        """
        Invalid equivalence class: deleting an id that was never created (or already
        deleted) should return 404, not silently succeed. This matters because a
        silent no-op could hide bugs where the client thinks something was deleted
        when nothing actually happened.
        """
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = delete_todo(api_url, fake_id)
        assert response.status_code == 404
        assert "error" in response.json()
