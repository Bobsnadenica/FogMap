from boto3.dynamodb.conditions import Key

from .atlas_tiles import item_cells
from .common import dynamodb, utc_now_iso
from .config import (
    LANDMARKS_TABLE,
    SHARED_CELLS_TABLE,
    SHARED_TILE_CACHE_PREFIX,
    SHARED_TILE_CACHE_TTL_SECONDS,
    SHARED_TILE_EDGE_CACHE_SECONDS,
)
from .discovery_cache import cache_object_key, store_cached_json

CELL_DEGREES = 0.00018

shared_cells_table = dynamodb.Table(SHARED_CELLS_TABLE)
landmarks_table = dynamodb.Table(LANDMARKS_TABLE)


def _query_shared_tile_items(world_id, tile_id):
    return shared_cells_table.query(
        KeyConditionExpression=Key("pk").eq(f"WORLD#{world_id}#TILE#{tile_id}"),
    ).get("Items", [])


def _query_landmarks(world_id, tile_id):
    return landmarks_table.query(
        KeyConditionExpression=Key("pk").eq(f"WORLD#{world_id}#TILE#{tile_id}"),
        ProjectionExpression="landmarkId, title, description, category, lat, lon, #status, approvedObjectKey, createdAt",
        ExpressionAttributeNames={"#status": "status"},
    ).get("Items", [])


def build_shared_tile_snapshot(world_id, tile_id):
    cells_by_id = {}
    for item in _query_shared_tile_items(world_id, tile_id):
        for cell in item_cells(
            item,
            fallback_tile_id=tile_id,
            default_cell_degrees=CELL_DEGREES,
        ):
            cells_by_id[cell["cellId"]] = {
                "cellId": cell["cellId"],
                "lat": float(cell["lat"]),
                "lon": float(cell["lon"]),
                "discovererCount": int(item.get("discovererCount", 1)),
                "tileId": tile_id,
                "lastDiscoveredAt": item.get("updatedAt")
                or item.get("lastDiscoveredAt")
                or utc_now_iso(),
            }

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
        "cells": sorted(
            cells_by_id.values(),
            key=lambda cell: cell["lastDiscoveredAt"],
            reverse=True,
        ),
        "landmarks": landmarks,
    }


def shared_tile_cache_key(world_id, tile_id):
    return cache_object_key(SHARED_TILE_CACHE_PREFIX, world_id, tile_id)


def rebuild_and_store_shared_tile_snapshot(world_id, tile_id):
    return store_cached_json(
        shared_tile_cache_key(world_id, tile_id),
        build_shared_tile_snapshot(world_id, tile_id),
        SHARED_TILE_CACHE_TTL_SECONDS,
        cache_control_seconds=SHARED_TILE_EDGE_CACHE_SECONDS,
    )
