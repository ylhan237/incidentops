import json
import os
import time
import uuid
import logging
from decimal import Decimal

logger = logging.getLogger()
logger.setLevel(logging.INFO)

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    boto3 = None
    ClientError = Exception


TABLE_NAME = os.environ.get(
    "TABLE_NAME",
    "incidentops-dev-incidents",
)

ENVIRONMENT = os.environ.get(
    "ENVIRONMENT",
    "local",
)
VALID_STATUSES = {
    "open",
    "investigating",
    "resolved",
}

def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "content-type": "application/json",
            "access-control-allow-origin": "*",
            "access-control-allow-methods": "GET,POST,PATCH,OPTIONS",
            "access-control-allow-headers": "content-type",
        },
        "body": json.dumps(body, default=_json_default),
    }


def _json_default(value):
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def _table():
    if boto3 is None:
        raise RuntimeError("boto3 is required when running inside AWS Lambda")
    return boto3.resource("dynamodb").Table(TABLE_NAME)

def health():
    return _response(
        200,
        {
            "status": "healthy",
            "service": "incidentops-api",
            "environment": ENVIRONMENT,
        },
    )

def list_incidents():
    result = _table().scan(Limit=50)
    return _response(200, {"items": result.get("Items", [])})


def get_incident(incident_id):
    result = _table().get_item(Key={"id": incident_id})
    item = result.get("Item")
    if not item:
        return _response(404, {"message": "Incident not found"})
    return _response(200, item)


def create_incident(event):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"message": "Invalid JSON body"})

    title = str(payload.get("title", "")).strip()
    severity = str(payload.get("severity", "low")).strip().lower()

    if not title:
        return _response(400, {"message": "title is required"})

    if severity not in {"low", "medium", "high"}:
        return _response(400, {"message": "severity must be low, medium, or high"})

    now = int(time.time())
    item = {
        "id": str(uuid.uuid4()),
        "title": title,
        "severity": severity,
        "status": "open",
        "createdAt": now,
        "updatedAt": now,
    }

    _table().put_item(Item=item)
    return _response(201, item)

def update_incident_status(event, incident_id):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(
            400,
            {"message": "Invalid JSON body"},
        )

    status = str(payload.get("status", "")).strip().lower()

    if status not in VALID_STATUSES:
        return _response(
            400,
            {
                "message": (
                    "status must be open, investigating, or resolved"
                )
            },
        )

    now = int(time.time())

    try:
        result = _table().update_item(
            Key={
                "id": incident_id,
            },
            UpdateExpression=(
                "SET #incident_status = :status, "
                "updatedAt = :updated_at"
            ),
            ExpressionAttributeNames={
                "#incident_status": "status",
            },
            ExpressionAttributeValues={
                ":status": status,
                ":updated_at": now,
            },
            ConditionExpression="attribute_exists(id)",
            ReturnValues="ALL_NEW",
        )
    except ClientError as error:
        error_code = (
            error.response
            .get("Error", {})
            .get("Code")
        )

        if error_code == "ConditionalCheckFailedException":
            return _response(
                404,
                {"message": "Incident not found"},
            )

        raise

    return _response(
        200,
        result["Attributes"],
    )

def handler(event, context):
    try:
        method = (
            event.get("requestContext", {})
            .get("http", {})
            .get("method", "GET")
        )
        raw_path = event.get("rawPath", "/incidents")
        path_parameters = event.get("pathParameters") or {}

        logger.info(
            "Processing request method=%s path=%s request_id=%s",
            method,
            raw_path,
            getattr(context, "aws_request_id", "local"),
        )

        if method == "OPTIONS":
            return _response(204, {})

        if method == "GET" and raw_path == "/health":
            return health()

        if method == "GET" and raw_path == "/incidents":
            return list_incidents()

        incident_id = path_parameters.get("id")

        if method == "GET" and incident_id:
            return get_incident(incident_id)

        if method == "PATCH" and incident_id:
            return update_incident_status(
                event,
                incident_id,
            )

        if method == "POST" and raw_path == "/incidents":
            return create_incident(event)

        return _response(404, {"message": "Route not found"})

    except Exception:
        logger.exception(
            "Unhandled error while processing request"
        )

        return _response(
            500,
            {
                "message": "Internal server error",
                "environment": ENVIRONMENT,
            },
        )


if __name__ == "__main__":
    print(json.dumps(_response(200, {"message": "IncidentOps handler loaded"}), indent=2))
