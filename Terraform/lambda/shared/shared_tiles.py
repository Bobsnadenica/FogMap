from boto3.dynamodb.conditions import Key

from .common import dynamodb, utc_now_iso
from .config import LANDMARKS_TABLE, SHARED_CELLS_TABLE

shared_cells_table = dynamodb.Table(SHARED_CELLS_TABLE)
landmarks_table = dynamodb.Table(LANDMARKS_TABLE)


def _query_shared_cells(world_id, tile_id):
    return shared_cells_table.query(
        KeyConditionExpression=Key("pk").eq(f"WORLD#{world_id}#TILE#{tile_id}"),
        ProjectionExpression="sk, lat, lon, discovererCount, tileId, lastDiscoveredAt",
    ).get("Items", [])


def _query_landmarks(world_id, tile_id):
    return landmarks_table.query(
        KeyConditionExpression=Key("pk").eq(f"WORLD#{world_id}#TILE#{tile_id}"),
        ProjectionExpression="landmarkId, title, description, category, lat, lon, #status, approvedObjectKey, createdAt",
        ExpressionAttributeNames={"#status": "status"},
    ).get("Items", [])


def build_shared_tile_snapshot(world_id, tile_id):
    cells = []
    for item in _query_shared_cells(world_id, tile_id):
        cells.append(
            {
                "cellId": str(item["sk"]).replace("CELL#", ""),
                "lat": float(item["lat"]),
                "lon": float(item["lon"]),
                "discovererCount": int(item.get("discovererCount", 1)),
                "tileId": item.get("tileId", tile_id),
                "lastDiscoveredAt": item.get("lastDiscoveredAt", utc_now_iso()),
            }
        )

    landmarks = []
    for item in _query_landmarks(world_id, tile_id):
        if item.get("status") != "APPROVED":
            continue
        landmarks.append(
            {
                "landmarkId": item["landmarkId"],
                "title": item.get("title", ""),
                "description": item.get("description", ""),
                "category": item.get("category", ""),
                "lat": float(item["lat"]),
                "lon": float(item["lon"]),
                "status": item.get("status", "APPROVED"),
                "approvedObjectKey": item.get("approvedObjectKey"),
                "createdAt": item.get("createdAt", utc_now_iso()),
            }
        )

    return {
        "worldId": world_id,
        "tileId": tile_id,
        "cells": cells,
        "landmarks": landmarks,
    }
