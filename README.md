# mapOKU (Flutter)

**Freedom to move, for everyone.** Community-powered accessibility mapping for
OKU (persons with disabilities) and everyone who moves through the city.
Supporting SDG 11 — Sustainable Cities.

This is the Flutter hackathon build of mapOKU. It keeps the same concept, logo
and features as the original web app (map, obstacles, rewards) and applies an
Apple-inspired design language.

The Routes screen is a **real-world 3D pedestrian and OKU wayfinding demo for
Sime Darby Property**, built on **MapLibre GL** (`maplibre_gl`) so it runs on
Android, iOS and web from one codebase — no API key and no WebView.

## Sime Darby Property 3D demo

A branded top bar (deep red `#E31837`, charcoal `#1E1E1E`, white) switches
between three flagship hubs at their **real Malaysian coordinates**. Selecting
a hub `flyTo`s that location and rebuilds the routing graph:

| Hub | Category | Center (lng, lat) | Focus area |
| --- | --- | --- | --- |
| **SJCC / SJ7** | Integrated Transit-Oriented Development (Selangor) | `101.5878, 3.0833` | Subang Jaya LRT/KTM Station → SJCC Retail Hub |
| **City of Elmina** | Township (Selangor) | `101.5135, 3.1842` | Elmina Central Park → Elmina Lakeside Mall |
| **KL East** | Integrated Development (Kuala Lumpur) | `101.7294, 3.2248` | KL East Mall → The Ridge & Park Residence |

Pin A / Pin B use the requested real positions, e.g. SJCC:

- **Pin A** `Subang Jaya LRT/KTM Station (SJ7)` — `101.5861, 3.0845`
- **Pin B** `SJCC Retail Hub / East Lobby` — `101.5902, 3.0825`

Each hub is pre-configured with a pedestrian / OKU graph whose edges carry
**dense street-following geometry (3-6 waypoints each, 10-15 per route)**, so
routes curve along real roads and walkways instead of running as straight
diagonals.

### Real 3D street map

- tilted vector map — `pitch: 60`, `bearing: -20`, `zoom: 17`
- free **OpenFreeMap "bright"** tiles (`https://tiles.openfreemap.org/styles/bright`),
  which look like OpenStreetMap — **no API key required**
- a `fill-extrusion` **3D building** layer over the style's existing
  `openmaptiles` / `building` source, light grey `#d9e2ec` walls at
  `fill-extrusion-opacity: 0.75` so routes stay readable
- the active route is drawn as an elevated 3D path: a wide drop shadow, a dark
  casing, an **emerald `#10b981`** core for OKU-safe routes (**red `#ef4444`**
  when the route uses stairs), plus **animated marching direction dashes**
- the route not currently selected is drawn as a faint grey dashed reference
- **mapOKU markers**: a black teardrop **Pin A** badge and an orange/brown
  **Pin B** badge, plus compact floating badges for key accessibility nodes
  (`Covered Link Bridge`, `OKU Drop-off Zone`, …) with a covered-walkway icon
- tap any node (or map badge) to see whether it is step-free and covered

### Quick Demo Scenarios (for judges)

- **Route mode toggle** — Standard Pedestrian vs OKU / Wheelchair, kept in sync
  with the search card's accessibility dropdown. The A* path is recalculated
  live; wheelchair mode treats stairs as impassable and prefers covered
  (weather-protected) walkways.
- **Simulate Construction / Blocked Path** — drops a hazard marker on the
  active walkway, removes that edge from the graph and re-routes the glowing
  path around it in real time.
- **Live metrics card** — township name and category, distance (m), estimated
  walk time, accessibility score (100% step-free) and covered-walkway %.
  Distances are computed from the real geodesic length of the drawn route.

### Full-screen map layout (Google Maps style)

The map is edge-to-edge and **every control floats above it**, so the map is
never re-laid-out and can never stretch or leave blank space when cards open
or close (in Flutter a `Positioned.fill` map in a `Stack` never resizes — the
equivalent of calling `map.resize()` on every toggle, for free).

- **Floating top pills** — the `SJCC / SJ7`, `City of Elmina` and `KL East`
  hubs are floating rounded pills over the top of the map. The
  `SIME DARBY PROPERTY` banner sits above them in a rounded card and collapses
  to a small red-dot toggle button, leaving the map unobstructed.
- **Collapsible bottom sheet** — the black "PLAN AN ACCESSIBLE TRIP" card is a
  floating sheet with a **drag handle pill** and a **`✕` button**. Minimising
  it slides it down (300 ms ease) leaving a **52 px bar** visible. The button
  becomes `🔼` to bring it back.
- **Auto-collapse on map interaction** — panning / zooming / tilting the map
  itself minimises the sheet. Programmatic camera moves (hub fly-to, recentre)
  are excluded, so the sheet does not collapse on its own.
- **Controls clear the minimised bar** — the route legend sits bottom-left and
  the ⌖ re-centre button bottom-right, both offset by the collapsed bar height.
  While the sheet is expanded they hide, so they are never buried underneath it.
- The sheet is capped at 560 px wide and centred on tablets.

### mapOKU search card

Inside the bottom sheet, the original app's trip search is preserved:

- **From** — shows the active Pin A address, with a microphone affordance
- **To** — shows the active Pin B address, with magnifier + microphone affordances
- **Accessibility need** dropdown — `Wheelchair`, `Crutches / Elderly`,
  `Visual Impairment / Tactile`, `Standard Pedestrian`, wired to the route mode

## Features

- **Routes (3D)** — the Sime Darby Property hub demo described above.
- **Reports** — Community obstacle feed and your own reports. Confirm ("still
  there") or clear ("it's gone") reports, and submit a new obstacle with type,
  location, description and an optional photo.
- **Rewards** — Points wallet with a hardcoded catalogue that redeems real
  voucher codes, plus redemption history. Reporting an obstacle awards points.

## Hardcoded + real data

For a reliable demo the app blends both:

- **Hardcoded (always works offline):** route scenario, obstacle cluster,
  community feed, seeded "my reports", reward catalogue and starting points.
- **Real:** OpenStreetMap tiles, Nominatim geocoding, device location, and the
  mapOKU backend (health check, obstacle feed, login, obstacle submit/vote).
  The obstacle feed falls back to demo data when the backend is unreachable.

The rewards wallet is persisted locally with `shared_preferences` because the
backend does not yet expose a rewards endpoint.

## Project structure

```
lib/
├── main.dart                 # entry point
├── app.dart                  # root widget + MaterialApp
├── core/
│   ├── constants/            # colours (incl. Sime Darby brand), config
│   └── theme/                # Apple-inspired theme
├── data/demo_data.dart       # hardcoded demo data (rewards, reports)
├── models/                   # obstacle, report, reward models
├── services/                 # API, geocoding, location, rewards storage
├── state/                    # AppState (ChangeNotifier) + AppScope
├── screens/                  # shell, routes, reports, rewards
├── widgets/                  # shared cards, sheets, logo
└── features/sime_darby/
    ├── data/sime_darby_demo_data.dart      # 3 hubs: real coords + graphs
    ├── models/sime_darby_hub.dart          # nodes, edges (with geometry), hub
    ├── services/accessible_pathfinder.dart # A* OKU routing over real coords
    └── widgets/
        ├── sime_darby_map.dart             # MapLibre 3D street map + badges
        ├── sime_darby_selector.dart        # branded hub selector
        ├── route_search_panel.dart         # From / To / accessibility need
        ├── quick_demo_panel.dart           # judge controls
        └── route_metrics_card.dart         # live metrics
```

## Routing (A*)

`AccessiblePathfinder` runs A* over each hub's small pedestrian graph, whose
edges carry real street-following polylines:

- standard mode uses the shortest path (which is why it passes the stairs)
- accessible mode treats stairs as impassable and applies a **0.9× cost bonus**
  to covered walkways
- the simulated construction barrier removes an edge entirely
- the winning path concatenates each edge's geometry, and the metrics card
  reports the **real geodesic length** of that route

Because the authored edge weights are not proportional to the geometric
distance between nodes, the heuristic uses the cheapest "cost per metre" across
usable edges so the straight-line estimate stays a true lower bound and A*
remains optimal. Behaviour is locked down by
`test/accessible_pathfinder_test.dart`.

## Platform requirements (MapLibre)

- Flutter **3.29+**, Dart **3.7+**
- Android: API 21+, JDK 21 recommended for Gradle builds, `INTERNET` permission
- iOS: deployment target **13.0+** (already set)
- Web: a browser with **WebGL2** (Safari 15+)
- Internet access is required for OpenFreeMap vector tiles

## Design

Apple-inspired: one clear hierarchy, generous spacing, soft rounded surfaces,
restrained shadows so the map stays the hero, a single confident accent green,
large tap targets and strong contrast for accessibility.

mapOKU palette: `#346F4B` primary, `#1E2B22` forest, `#E7EFE9` mint, `#F0EEE7`
background, `#FBFAF7` surface, `#C27A45` accent.
Sime Darby Property: `#E31837` red, `#1E1E1E` charcoal, white.
Routes: `#10b981` emerald (OKU-safe), `#ef4444` red (stairs / obstacles).

## Run

```bash
flutter pub get
flutter run          # on a connected device / emulator
flutter run -d chrome  # quick web preview (WebGL2 required)
flutter analyze        # lint
flutter test           # routing + widget tests
```

## Notes

- The backend base URL is `https://map-oku-backend.vercel.app` (see
  `lib/core/constants/app_config.dart`), matching the web app.
- Location and photo permissions are declared for Android and iOS.
- The logo asset lives at `assets/images/mapoku2.png` (same logo as the web app).