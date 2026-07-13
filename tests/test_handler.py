import json

import pytest

from src.api import handler as api


class FakeTable:
    """Simulation minimale d'une table DynamoDB pour les tests."""

    def __init__(self):
        self.items = {}

    def scan(self, Limit=50):
        return {
            "Items": list(self.items.values())[:Limit]
        }

    def get_item(self, Key):
        incident_id = Key["id"]

        if incident_id not in self.items:
            return {}

        return {
            "Item": self.items[incident_id]
        }

    def put_item(self, Item):
        self.items[Item["id"]] = Item

        return {
            "ResponseMetadata": {
                "HTTPStatusCode": 200
            }
        }


@pytest.fixture
def fake_table(monkeypatch):
    table = FakeTable()

    monkeypatch.setattr(
        api,
        "_table",
        lambda: table,
    )

    return table


def build_event(
    method="GET",
    path="/health",
    body=None,
    path_parameters=None,
):
    return {
        "requestContext": {
            "http": {
                "method": method
            }
        },
        "rawPath": path,
        "pathParameters": path_parameters,
        "body": body,
    }


def parse_body(response):
    return json.loads(response["body"])


def test_health_endpoint():
    response = api.handler(
        build_event(
            method="GET",
            path="/health",
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 200
    assert body["status"] == "healthy"
    assert body["service"] == "incidentops-api"
    assert "environment" in body


def test_list_incidents_empty(fake_table):
    response = api.handler(
        build_event(
            method="GET",
            path="/incidents",
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 200
    assert body == {
        "items": []
    }


def test_create_incident(fake_table):
    response = api.handler(
        build_event(
            method="POST",
            path="/incidents",
            body=json.dumps(
                {
                    "title": "API latency elevated",
                    "severity": "high",
                }
            ),
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 201
    assert body["title"] == "API latency elevated"
    assert body["severity"] == "high"
    assert body["status"] == "open"
    assert "id" in body
    assert "createdAt" in body
    assert body["id"] in fake_table.items


def test_create_incident_with_missing_title(fake_table):
    response = api.handler(
        build_event(
            method="POST",
            path="/incidents",
            body=json.dumps(
                {
                    "severity": "medium"
                }
            ),
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 400
    assert body["message"] == "title is required"


def test_create_incident_with_invalid_severity(fake_table):
    response = api.handler(
        build_event(
            method="POST",
            path="/incidents",
            body=json.dumps(
                {
                    "title": "Database unavailable",
                    "severity": "critical",
                }
            ),
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 400
    assert body["message"] == (
        "severity must be low, medium, or high"
    )


def test_create_incident_with_invalid_json(fake_table):
    response = api.handler(
        build_event(
            method="POST",
            path="/incidents",
            body="{invalid-json}",
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 400
    assert body["message"] == "Invalid JSON body"


def test_get_existing_incident(fake_table):
    fake_table.items["incident-001"] = {
        "id": "incident-001",
        "title": "Service unavailable",
        "severity": "high",
        "status": "open",
    }

    response = api.handler(
        build_event(
            method="GET",
            path="/incidents/incident-001",
            path_parameters={
                "id": "incident-001"
            },
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 200
    assert body["id"] == "incident-001"
    assert body["title"] == "Service unavailable"


def test_get_unknown_incident(fake_table):
    response = api.handler(
        build_event(
            method="GET",
            path="/incidents/unknown",
            path_parameters={
                "id": "unknown"
            },
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 404
    assert body["message"] == "Incident not found"


def test_unknown_route():
    response = api.handler(
        build_event(
            method="GET",
            path="/unknown",
        ),
        None,
    )

    body = parse_body(response)

    assert response["statusCode"] == 404
    assert body["message"] == "Route not found"


def test_options_request():
    response = api.handler(
        build_event(
            method="OPTIONS",
            path="/incidents",
        ),
        None,
    )

    assert response["statusCode"] == 204