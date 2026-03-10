import os

from boto3.dynamodb.conditions import Key

from shared.common import dynamodb

USER_DISCOVERIES_TABLE = os.environ["USER_DISCOVERIES_TABLE"]
table = dynamodb.Table(USER_DISCOVERIES_TABLE)


def _user_id_from_event(event):
    identity = event.get("identity") or {}
    claims = identity.get("claims") or {}
    return identity.get("sub") or claims.get("sub")


def handler(event, context):
    user_id = _user_id_from_event(event)
    if not user_id:
        raise Exception("Unauthorized")

    items = []
    last_evaluated_key = None

    while True:
        query_args = {
            "KeyConditionExpression": Key("pk").eq(f"USER#{user_id}"),
            "ProjectionExpression": "sk, lat, lon",
        }
        if last_evaluated_key:
            query_args["ExclusiveStartKey"] = last_evaluated_key

        response = table.query(**query_args)
        items.extend(response.get("Items", []))
        last_evaluated_key = response.get("LastEvaluatedKey")

        if not last_evaluated_key:
            break

        if len(items) >= 50000:
            break

    cells = [
        {
            "cellId": str(item["sk"]).replace("CELL#", ""),
            "lat": float(item["lat"]),
            "lon": float(item["lon"]),
        }
        for item in items
    ]

    return {"cells": cells}
