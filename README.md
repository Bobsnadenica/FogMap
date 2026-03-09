# FogFrontier
# Current package choices

The starter uses:

- `flutter_map`
- `geolocator`
- `path_provider`
- `share_plus`
- `latlong2`
- `cross_file`

## Why these were chosen

### flutter_map
Chosen because it is flexible, open, and well-suited for custom overlay rendering such as fog-of-war.

### geolocator
Chosen for location permissions and streaming user position.

### path_provider
Used to store the local JSON profile in the app documents directory.

### share_plus
Used to export/share the user profile JSON.

### latlong2
Used for geospatial coordinate handling.

---

# Current folder structure

world_of_fog_cloud/
├─ amplify/
│  ├─ package.json
│  ├─ tsconfig.json
│  └─ amplify/
│     ├─ backend.ts
│     ├─ auth/
│     │  └─ resource.ts
│     ├─ data/
│     │  └─ resource.ts
│     └─ functions/
│        ├─ _shared/
│        │  ├─ config.ts
│        │  ├─ dynamo.ts
│        │  └─ geo.ts
│        ├─ sync-discoveries/
│        │  ├─ resource.ts
│        │  └─ handler.ts
│        ├─ get-shared-viewport/
│        │  ├─ resource.ts
│        │  └─ handler.ts
│        ├─ create-upload-ticket/
│        │  ├─ resource.ts
│        │  └─ handler.ts
│        ├─ finalize-landmark/
│        │  ├─ resource.ts
│        │  └─ handler.ts
│        ├─ approve-landmark/
│        │  ├─ resource.ts
│        │  └─ handler.ts
│        └─ get-landmark-view-url/
│           ├─ resource.ts
│           └─ handler.ts
├─ terraform/
│  ├─ providers.tf
│  ├─ variables.tf
│  ├─ main.tf
│  ├─ outputs.tf
│  └─ terraform.tfvars.example
└─ flutter/
   └─ lib/
      └─ cloud/
         ├─ map_mode.dart
         ├─ models/shared_viewport_models.dart
         ├─ services/shared_map_service.dart
         └─ widgets/map_mode_toggle.dart

File-by-file responsibility guide
lib/main.dart
Application entry point.
Responsibilities:
initialize Flutter bindings
create the main AppController
initialize local state before app start
inject core services into the app
run the root widget
lib/app.dart
Root MaterialApp wrapper.
Responsibilities:
apply app theme
set app title
launch the root shell
lib/core/constants/app_constants.dart
Central constants.
Responsibilities:
tile URL template
zoom settings
discovery radius values
profile file name
default initial map position
lib/core/theme/app_theme.dart
Global fantasy-style UI theme.
Responsibilities:
dark fantasy palette
card styles
input styles
navigation theme
app bar theme
lib/core/utils/discovery_math.dart
Pure math helpers for discovery and stats.
Responsibilities:
map coordinates to cell IDs
calculate reveal cells inside radius
calculate meters-per-pixel for render scaling
compute approximate coverage percentage
lib/data/models/reveal_point.dart
A single reveal event/location.
Responsibilities:
latitude / longitude storage
timestamp storage
JSON serialization
lib/data/models/player_profile.dart
The local player state object.
Responsibilities:
profile metadata
display name
reveal history
discovered cells
total distance traveled
last known location
JSON serialization
lib/data/models/achievement.dart
Achievement definitions and unlock logic.
Responsibilities:
model achievement item
derive unlocked achievements from profile progress
lib/services/local_profile_store.dart
Local storage service.
Responsibilities:
create/read profile JSON file
save updated profile
initialize default profile if missing
lib/services/location_service.dart
Location permission and location streaming.
Responsibilities:
permission checks
location service readiness validation
stream user position updates
lib/services/share_service.dart
User profile export sharing.
Responsibilities:
serialize local profile to JSON
prepare share payload
invoke native sharing sheet
lib/controllers/app_controller.dart
Main application controller.
Responsibilities:
orchestrate app state
manage tracking lifecycle
process GPS updates
create reveal points
update discovered cells
accumulate distance
save profile changes
expose computed values to UI
provide achievements to screens
This is the most important file in the current MVP.
lib/ui/screens/app_shell.dart
Bottom navigation container.
Responsibilities:
hold main tabs
show Map / Profile / Achievements screens
surface controller errors via snackbars
lib/ui/screens/map_screen.dart
Main gameplay screen.
Responsibilities:
render map
render player marker
render traveled polyline
render fog overlay
show quick stats
start / stop tracking
center on current location
lib/ui/widgets/fog_of_war_overlay.dart
Custom fog painter.
Responsibilities:
paint dark fog over the map
cut transparent reveal circles around discovered points
scale reveal radius with zoom level
lib/ui/screens/profile_screen.dart
Player profile and export screen.
Responsibilities:
edit display name
show stats summary
export/share map state
lib/ui/screens/achievements_screen.dart
Achievements list screen.
Responsibilities:
show unlocked/locked achievements
summarize overall achievement progress
lib/sync/sync_mode.dart
Enum representing solo vs community mode.
lib/sync/map_sync_repository.dart
Future sync abstraction.
Responsibilities:
define how player data would be pushed/pulled later
allow backend mode without coupling current UI directly to AWS implementation


File-by-file responsibility guide
lib/main.dart
Application entry point.
Responsibilities:
initialize Flutter bindings
create the main AppController
initialize local state before app start
inject core services into the app
run the root widget
lib/app.dart
Root MaterialApp wrapper.
Responsibilities:
apply app theme
set app title
launch the root shell
lib/core/constants/app_constants.dart
Central constants.
Responsibilities:
tile URL template
zoom settings
discovery radius values
profile file name
default initial map position
lib/core/theme/app_theme.dart
Global fantasy-style UI theme.
Responsibilities:
dark fantasy palette
card styles
input styles
navigation theme
app bar theme
lib/core/utils/discovery_math.dart
Pure math helpers for discovery and stats.
Responsibilities:
map coordinates to cell IDs
calculate reveal cells inside radius
calculate meters-per-pixel for render scaling
compute approximate coverage percentage
lib/data/models/reveal_point.dart
A single reveal event/location.
Responsibilities:
latitude / longitude storage
timestamp storage
JSON serialization
lib/data/models/player_profile.dart
The local player state object.
Responsibilities:
profile metadata
display name
reveal history
discovered cells
total distance traveled
last known location
JSON serialization
lib/data/models/achievement.dart
Achievement definitions and unlock logic.
Responsibilities:
model achievement item
derive unlocked achievements from profile progress
lib/services/local_profile_store.dart
Local storage service.
Responsibilities:
create/read profile JSON file
save updated profile
initialize default profile if missing
lib/services/location_service.dart
Location permission and location streaming.
Responsibilities:
permission checks
location service readiness validation
stream user position updates
lib/services/share_service.dart
User profile export sharing.
Responsibilities:
serialize local profile to JSON
prepare share payload
invoke native sharing sheet
lib/controllers/app_controller.dart
Main application controller.
Responsibilities:
orchestrate app state
manage tracking lifecycle
process GPS updates
create reveal points
update discovered cells
accumulate distance
save profile changes
expose computed values to UI
provide achievements to screens
This is the most important file in the current MVP.
lib/ui/screens/app_shell.dart
Bottom navigation container.
Responsibilities:
hold main tabs
show Map / Profile / Achievements screens
surface controller errors via snackbars
lib/ui/screens/map_screen.dart
Main gameplay screen.
Responsibilities:
render map
render player marker
render traveled polyline
render fog overlay
show quick stats
start / stop tracking
center on current location
lib/ui/widgets/fog_of_war_overlay.dart
Custom fog painter.
Responsibilities:
paint dark fog over the map
cut transparent reveal circles around discovered points
scale reveal radius with zoom level
lib/ui/screens/profile_screen.dart
Player profile and export screen.
Responsibilities:
edit display name
show stats summary
export/share map state
lib/ui/screens/achievements_screen.dart
Achievements list screen.
Responsibilities:
show unlocked/locked achievements
summarize overall achievement progress
lib/sync/sync_mode.dart
Enum representing solo vs community mode.
lib/sync/map_sync_repository.dart
Future sync abstraction.
Responsibilities:
define how player data would be pushed/pulled later
allow backend mode without coupling current UI directly to AWS implementation



Notes for future continuation with ChatGPT
When continuing this project later, assume the following is already decided unless explicitly changed:
Product assumptions
app name: FogFrontier
Flutter / Dart for Android + iOS
real-world map
WoW/MMORPG-inspired fantasy presentation
offline-first architecture first
local JSON profile persistence first
future AWS community mode second
Current technical assumptions
AppController is the main orchestrator
local profile is the source of truth in MVP
fog rendering is handled via custom painter overlay
progress tracking is based on reveal points + discovered cells
export currently uses JSON sharing
Current style assumptions
dark fantasy
bronze/gold accents
explorer/cartographer tone
not sci-fi
not flat bright casual map style
Current roadmap assumptions
first finish local single-player feel
then improve visuals
then friend sharing/import
then backend collaborative mode




Notes for future continuation with ChatGPT
When continuing this project later, assume the following is already decided unless explicitly changed:
Product assumptions
app name: FogFrontier
Flutter / Dart for Android + iOS
real-world map
WoW/MMORPG-inspired fantasy presentation
offline-first architecture first
local JSON profile persistence first
future AWS community mode second
Current technical assumptions
AppController is the main orchestrator
local profile is the source of truth in MVP
fog rendering is handled via custom painter overlay
progress tracking is based on reveal points + discovered cells
export currently uses JSON sharing
Current style assumptions
dark fantasy
bronze/gold accents
explorer/cartographer tone
not sci-fi
not flat bright casual map style
Current roadmap assumptions
first finish local single-player feel
then improve visuals
then friend sharing/import
then backend collaborative mode