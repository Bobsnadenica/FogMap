from decimal import Decimal
from botocore.exceptions import ClientError
from shared.common import dynamodb, get_display_name, require_authenticated_user, utc_now_iso, epoch_seconds_after
from shared.config import PLAYER_PRESENCE_TABLE, PRESENCE_TTL_SECONDS, SHARED_CELLS_TABLE, USER_DISCOVERIES_TABLE
from shared.geo import tile_id_for_point

user_discoveries_table = dynamodb.Table(USER_DISCOVERIES_TABLE)
shared_cells_table = dynamodb.Table(SHARED_CELLS_TABLE)
presence_table = dynamodb.Table(PLAYER_PRESENCE_TABLE)

def _validate_coordinates(lat, lon):
    if not (-90 <= lat <= 90): raise Exception("Latitude is out of range.")
    if not (-180 <= lon <= 180): raise Exception("Longitude is out of range.")

def handler(event, context):
    args = event.get("arguments") or {}
    user_id = require_authenticated_user(event)
    now_iso = utc_now_iso()
    world_id = (args.get("worldId") or "global").strip().lower()
    map_zoom = int(args.get("mapZoom") or 17)
    display_name = ((args.get("displayName") or "").strip() or get_display_name(event))[:80]
    cells = args.get("cellsJson") or []
    if isinstance(cells, str):
        import json; cells = json.loads(cells)
    if not isinstance(cells, list): raise Exception("cellsJson must be a JSON array or parsed list.")
    accepted = new_personal = updated_shared = 0
    for cell in cells[:500]:
        accepted += 1
        cell_id = str(cell["cellId"])
        lat = Decimal(str(cell["lat"])); lon = Decimal(str(cell["lon"]))
        _validate_coordinates(float(lat), float(lon))
        tile_id = cell.get("tileId") or tile_id_for_point(float(lat), float(lon), map_zoom)
        try:
            user_discoveries_table.put_item(Item={"pk":f"USER#{user_id}","sk":f"CELL#{cell_id}","userId":user_id,"worldId":world_id,"cellId":cell_id,"lat":lat,"lon":lon,"tileId":tile_id,"discoveredAt":now_iso}, ConditionExpression="attribute_not_exists(pk) AND attribute_not_exists(sk)")
            new_personal += 1
            shared_cells_table.update_item(Key={"pk":f"WORLD#{world_id}#TILE#{tile_id}","sk":f"CELL#{cell_id}"}, UpdateExpression="SET lat = if_not_exists(lat,:lat), lon = if_not_exists(lon,:lon), tileId = if_not_exists(tileId,:tile), worldId = if_not_exists(worldId,:worldId), firstDiscoveredAt = if_not_exists(firstDiscoveredAt,:now), lastDiscoveredAt = :now ADD discovererCount :one", ExpressionAttributeValues={":lat":lat,":lon":lon,":tile":tile_id,":worldId":world_id,":now":now_iso,":one":Decimal("1")})
            updated_shared += 1
        except ClientError as exc:
            if exc.response["Error"]["Code"] != "ConditionalCheckFailedException": raise
    if args.get("currentLat") is not None and args.get("currentLon") is not None:
        current_lat = Decimal(str(args["currentLat"])); current_lon = Decimal(str(args["currentLon"]))
        _validate_coordinates(float(current_lat), float(current_lon))
        tile_id = tile_id_for_point(float(current_lat), float(current_lon), map_zoom)
        presence_table.put_item(Item={"pk":f"WORLD#{world_id}#TILE#{tile_id}","sk":f"USER#{user_id}","userId":user_id,"displayName":display_name,"lat":current_lat,"lon":current_lon,"tileId":tile_id,"worldId":world_id,"lastSeenAt":now_iso,"ttl":epoch_seconds_after(PRESENCE_TTL_SECONDS)})
    return {"acceptedCellCount":accepted,"newPersonalCellCount":new_personal,"updatedSharedCellCount":updated_shared,"trackingActive":True,"timestamp":now_iso}
