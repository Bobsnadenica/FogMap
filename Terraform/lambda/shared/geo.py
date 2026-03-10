import math

def clamp(value, min_value, max_value):
    return max(min_value, min(value, max_value))

def aggregate_tile_zoom(map_zoom):
    if map_zoom <= 5: return 5
    if map_zoom <= 8: return 8
    if map_zoom <= 11: return 11
    if map_zoom <= 14: return 13
    return 14

def slippy_tile(lat, lon, map_zoom):
    z = aggregate_tile_zoom(map_zoom)
    lat = clamp(lat, -85.05112878, 85.05112878)
    n = 2 ** z
    x = int((lon + 180.0) / 360.0 * n)
    lat_rad = math.radians(lat)
    y = int((1.0 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2.0 * n)
    return x, y, z

def tile_id_for_point(lat, lon, map_zoom):
    x, y, z = slippy_tile(lat, lon, map_zoom)
    return f"z{z}/x{x}/y{y}"

def tile_ids_for_bounds(min_lat, max_lat, min_lon, max_lon, map_zoom):
    z = aggregate_tile_zoom(map_zoom)
    # Use the original map zoom here so slippy_tile aggregates only once.
    x1, y1, _ = slippy_tile(max_lat, min_lon, map_zoom)
    x2, y2, _ = slippy_tile(min_lat, max_lon, map_zoom)
    ids = []
    for x in range(min(x1, x2), max(x1, x2) + 1):
        for y in range(min(y1, y2), max(y1, y2) + 1):
            ids.append(f"z{z}/x{x}/y{y}")
    return ids

def in_bounds(lat, lon, min_lat, max_lat, min_lon, max_lon):
    return min_lat <= lat <= max_lat and min_lon <= lon <= max_lon
