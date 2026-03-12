import json

from shared.shared_tiles import rebuild_and_store_shared_tile_snapshot


def _message_key(payload):
    world_id = (payload.get("worldId") or "global").strip().lower()
    tile_id = str(payload.get("tileId") or "").strip()
    if not tile_id:
        raise Exception("Shared tile rebuild message is missing tileId.")
    return world_id, tile_id


def handler(event, context):
    unique_tiles = set()
    for record in event.get("Records", []):
        payload = json.loads(record["body"])
        unique_tiles.add(_message_key(payload))

    rebuilt = 0
    for world_id, tile_id in sorted(unique_tiles):
        rebuild_and_store_shared_tile_snapshot(world_id, tile_id)
        rebuilt += 1

    return {
        "rebuiltTileCount": rebuilt,
    }
