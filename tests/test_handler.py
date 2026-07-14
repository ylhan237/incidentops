import json
from unittest.mock import MagicMock

import src.api.handler as api


def make_event(method, path, body=None, incident_id=None):
    event = {
        "requestContext": {
            "http": {
                "method": method,
            }
        },
        "rawPath": path,
        "pathParameters": {},
    }

    if body is not None:
        event["body"] = json.dumps(body)

    if incident_id is not None:
        event["pathParameters"]["id"] = incident_id

    return event


def response_body(response):
    return json.loads(response["body"])


def test_health():
    event = make_event("GET", "/health")

    response = api.handler(event, None)
    body = response_body(response)

    assert response["statusCode"] == 200
    assert body["status"] == "healthy"


def test_list_incidents(monkeypatch):
    table = MagicMock()
    table.scan.return_value = {
        "Items": [
            {
                "id": "incident-1",
                "title": "API unavailable",
                "severity": "high",
                "status": "open",
            }
        ]
    }

    monkeypatch.setattr(api, "_table", lambda: table)

    event = make_event("GET", "/incidents")

    response = api.handler(event, None)
    body = response_body(response)

    assert response["statusCode"] == 200
    assert len(body["items"]) == 1
    assert body["items"][0]["id"] == "incident-1"

    table.scan.assert_called_once_with(Limit=50)


def test_create_incident(monkeypatch):
    table = MagicMock()

    monkeypatch.setattr(api, "_table", lambda: table)

    event = make_event(
        "POST",
        "/incidents",
        body={
            "title": "Database latency",
            "severity": "medium",
        },
    )

    response = api.handler(event, None)
    body = response_body(response)

    assert response["statusCode"] == 201
    assert body["title"] == "Database latency"
    assert body["severity"] == "medium"
    assert body["status"] == "open"
    assert "id" in body

    table.put_item.assert_called_once()


def test_update_incident_status(monkeypatch):
    table = MagicMock()
    table.update_item.return_value = {
        "Attributes": {
            "id": "incident-1",
            "title": "Database latency",
            "severity": "medium",
            "status": "investigating",
        }
    }

    monkeypatch.setattr(api, "_table", lambda: table)

    event = make_event(
        "PATCH",
        "/incidents/incident-1",
        body={
            "status": "investigating",
        },
        incident_id="incident-1",
    )

    response = api.handler(event, None)
    body = response_body(response)

    assert response["statusCode"] == 200
    assert body["status"] == "investigating"

    table.update_item.assert_called_once()


def test_reject_invalid_status(monkeypatch):
    table = MagicMock()

    monkeypatch.setattr(api, "_table", lambda: table)

    event = make_event(
        "PATCH",
        "/incidents/incident-1",
        body={
            "status": "deleted",
        },
        incident_id="incident-1",
    )

    response = api.handler(event, None)
    body = response_body(response)

    assert response["statusCode"] == 400
    assert "status" in body["message"]

    table.update_item.assert_not_called()


def test_unknown_route():
    event = make_event("GET", "/unknown")

    response = api.handler(event, None)

    assert response["statusCode"] == 404