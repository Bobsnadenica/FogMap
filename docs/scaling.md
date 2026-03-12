# Scaling Model

## Source of truth

- `user_discoveries` in DynamoDB remains the personal-map write source of truth.
- `shared_cells` in DynamoDB remains the shared-map write source of truth.
- `player_presence` in DynamoDB remains live-presence only and is intentionally short-lived with TTL.

This keeps writes simple, idempotent, and operationally safe.

## Personal map restore

The app should render from its local per-user profile first.

Backend restore now uses a private S3 bootstrap cache:

- `get_my_discovery_bootstrap` reads from a cached JSON snapshot in S3 when present
- on cache miss, Lambda rebuilds the snapshot from the user’s DynamoDB partition
- `sync_discoveries` invalidates that user snapshot when new personal cells are written

That means:

- returning users still get reliable restore
- the app does not need to rebuild personal map state from DynamoDB every time
- new-device login is still supported

## Shared map reads

The expensive part of the old design was rebuilding every shared viewport directly from DynamoDB tile queries.

The current design now caches shared tile snapshots in private S3:

- `get_shared_viewport` reads tile snapshots from S3 for cells and approved landmarks
- on cache miss, Lambda rebuilds only the missing tile from DynamoDB
- `sync_discoveries` invalidates the affected shared tile snapshot when new cells are discovered
- `moderate_landmark` invalidates the affected shared tile snapshot when landmark visibility changes
- live player presence is still read directly from DynamoDB, because presence must remain fresh and should disappear quickly when the app closes

This changes the read path from:

- many DynamoDB tile queries per shared viewport

to:

- mostly cheap cached snapshot reads
- live presence queries only

On the client, the app now also keeps a bounded on-device cache of shared cells and landmarks:

- once a realm area has been loaded, the client can render that cached area immediately across zoom changes
- the app can restore recently seen shared-map areas after restart without waiting for a full viewport round trip
- network refresh still runs in the background so the map converges to fresh data

This improves perceived speed without turning the phone into source-of-truth.

## Why this is cost-effective

- DynamoDB stays optimized for writes and truth
- S3 absorbs repeated bootstrap and shared-map read traffic
- AppSync schema and client contract stay stable
- presence remains the only hot read path, which is much smaller than map-cell reconstruction

## Cache lifetime strategy

Tile/bootstrap snapshots are invalidation-driven:

- `sync_discoveries` deletes affected shared-tile and user-bootstrap cache objects when truth changes
- `moderate_landmark` deletes affected shared-tile cache objects when approval state changes

That means cache TTL should be long, not short. Short TTL only forces unnecessary DynamoDB rebuilds for unchanged map data.

The current default should therefore be:

- long shared-tile snapshot TTL
- long user-bootstrap snapshot TTL
- longer S3 retention for discovery-cache objects

Freshness still comes from invalidation, while S3 absorbs repeated reads cheaply.

## Current write-model limit

The current read model is in good shape for `10,000` users.

The current write model is still not the final planet-scale design for years of heavy play, because:

- personal discoveries are stored as one DynamoDB item per discovered cell
- shared discoveries are stored as one DynamoDB item per shared cell

That is operationally simple and safe, but long-term storage will grow linearly with discovered cells.

The next major backend step, when discovery history gets large enough to matter, is:

1. compact personal discoveries into per-user/per-tile bitsets or another packed tile format
2. compact shared discoveries into tile snapshots derived from those packed writes
3. keep S3/CloudFront as the main read path for shared-map tiles

## What I would do next for larger scale

If shared concurrency gets materially higher, the next step is:

1. serve shared tile snapshots directly via CloudFront instead of always routing through AppSync
2. split shared-tile reads from live presence, keeping AppSync/Lambda only for auth-sensitive operations and live presence
3. optionally move the shared spatial index from the current fixed cell grid to H3 if you need better multi-resolution aggregation

I would not move to H3 first. The bigger win is the read-model split:

- DynamoDB for truth and writes
- cached tile snapshots for reads

That gives the largest cost and latency improvement with the least product risk.
