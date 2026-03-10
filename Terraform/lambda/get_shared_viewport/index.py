from time import time
from boto3.dynamodb.conditions import Key
from shared.common import dynamodb, utc_now_iso
from shared.config import LANDMARKS_TABLE, PLAYER_PRESENCE_TABLE, SHARED_CELLS_TABLE
from shared.geo import in_bounds, tile_ids_for_bounds

shared_cells_table = dynamodb.Table(SHARED_CELLS_TABLE)
presence_table = dynamodb.Table(PLAYER_PRESENCE_TABLE)
landmarks_table = dynamodb.Table(LANDMARKS_TABLE)
VIEWPORT_CACHE = {}
VIEWPORT_CACHE_TTL_SECONDS = 8
VIEWPORT_CACHE_MAX_ENTRIES = 64


def _cache_key(world_id, tile_ids):
    return f"{world_id}|{'|'.join(tile_ids)}"


def _prune_cache(now_epoch):
    expired = [
        key
        for key, entry in VIEWPORT_CACHE.items()
        if entry["expiresAtEpoch"] <= now_epoch
    ]
    for key in expired:
        VIEWPORT_CACHE.pop(key, None)

    while len(VIEWPORT_CACHE) > VIEWPORT_CACHE_MAX_ENTRIES:
        oldest_key = min(
            VIEWPORT_CACHE,
            key=lambda key: VIEWPORT_CACHE[key]["expiresAtEpoch"],
        )
        VIEWPORT_CACHE.pop(oldest_key, None)


def _query_shared_cells(world_id, tile_id):
    return shared_cells_table.query(
        KeyConditionExpression=Key("pk").eq(f"WORLD#{world_id}#TILE#{tile_id}"),
        ProjectionExpression="sk, lat, lon, discovererCount, tileId, lastDiscoveredAt",
    ).get("Items", [])


def _query_presence(world_id, tile_id):
    return presence_table.query(
        KeyConditionExpression=Key("pk").eq(f"WORLD#{world_id}#TILE#{tile_id}"),
        ProjectionExpression="userId, displayName, lat, lon, lastSeenAt, #ttl",
        ExpressionAttributeNames={"#ttl": "ttl"},
    ).get("Items", [])


def _query_landmarks(world_id, tile_id):
    return landmarks_table.query(
        KeyConditionExpression=Key("pk").eq(f"WORLD#{world_id}#TILE#{tile_id}"),
        ProjectionExpression="landmarkId, title, description, category, lat, lon, #status, approvedObjectKey, createdAt",
        ExpressionAttributeNames={"#status": "status"},
    ).get("Items", [])

def handler(event, context):
    args = event.get("arguments") or {}
    world_id = (args.get("worldId") or "global").strip().lower()
    min_lat = float(args["minLat"])
    max_lat = float(args["maxLat"])
    min_lon = float(args["minLon"])
    max_lon = float(args["maxLon"])
    zoom = int(args["zoom"])

    tile_ids = tile_ids_for_bounds(min_lat, max_lat, min_lon, max_lon, zoom)[:150]
    now_epoch = int(time())
    cache_key = _cache_key(world_id, tile_ids)
    _prune_cache(now_epoch)

    cached = VIEWPORT_CACHE.get(cache_key)
    if cached and cached["expiresAtEpoch"] > now_epoch:
        return cached["payload"]

    cells_by_id = {}
    players_by_user = {}
    landmarks_by_id = {}

    for tile_id in tile_ids:
        for item in _query_shared_cells(world_id, tile_id):
            lat = float(item["lat"])
            lon = float(item["lon"])
            if in_bounds(lat, lon, min_lat, max_lat, min_lon, max_lon):
                cell_id = str(item["sk"]).replace("CELL#", "")
                existing = cells_by_id.get(cell_id)
                candidate = {
                    "cellId": cell_id,
                    "lat": lat,
                    "lon": lon,
                    "discovererCount": int(item.get("discovererCount", 1)),
                    "tileId": item.get("tileId", tile_id),
                    "lastDiscoveredAt": item.get("lastDiscoveredAt", utc_now_iso()),
                }
                if existing is None or candidate["lastDiscoveredAt"] > existing["lastDiscoveredAt"]:
                    cells_by_id[cell_id] = candidate

        for item in _query_presence(world_id, tile_id):
            ttl = int(item.get("ttl", 0))
            if ttl and ttl <= now_epoch:
                continue

            lat = float(item["lat"])
            lon = float(item["lon"])
            if in_bounds(lat, lon, min_lat, max_lat, min_lon, max_lon):
                existing = players_by_user.get(item["userId"])
                candidate = {
                    "userId": item["userId"],
                    "displayName": item.get("displayName", "Explorer"),
                    "lat": lat,
                    "lon": lon,
                    "lastSeenAt": item.get("lastSeenAt", utc_now_iso()),
                }
                if existing is None or candidate["lastSeenAt"] > existing["lastSeenAt"]:
                    players_by_user[item["userId"]] = candidate

        for item in _query_landmarks(world_id, tile_id):
            if item.get("status") != "APPROVED":
                continue
            lat = float(item["lat"])
            lon = float(item["lon"])
            if in_bounds(lat, lon, min_lat, max_lat, min_lon, max_lon):
                landmark_id = item["landmarkId"]
                existing = landmarks_by_id.get(landmark_id)
                candidate = {
                    "landmarkId": landmark_id,
                    "title": item.get("title", ""),
                    "description": item.get("description", ""),
                    "category": item.get("category", ""),
                    "lat": lat,
                    "lon": lon,
                    "status": item.get("status", "APPROVED"),
                    "approvedObjectKey": item.get("approvedObjectKey"),
                    "createdAt": item.get("createdAt", utc_now_iso()),
                }
                if existing is None or candidate["createdAt"] > existing["createdAt"]:
                    landmarks_by_id[landmark_id] = candidate

    players = sorted(
        players_by_user.values(),
        key=lambda player: player["lastSeenAt"],
        reverse=True,
    )
    cells = sorted(
        cells_by_id.values(),
        key=lambda cell: cell["lastDiscoveredAt"],
        reverse=True,
    )
    landmarks = sorted(
        landmarks_by_id.values(),
        key=lambda landmark: landmark["createdAt"],
        reverse=True,
    )

    payload = {
        "worldId": world_id,
        "cells": cells,
        "players": players,
        "landmarks": landmarks,
        "generatedAt": utc_now_iso(),
    }

    VIEWPORT_CACHE[cache_key] = {
        "expiresAtEpoch": now_epoch + VIEWPORT_CACHE_TTL_SECONDS,
        "payload": payload,
    }
    _prune_cache(now_epoch)

    return payload
