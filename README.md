# mapOKU iOS (Flutter)

iOS front end for mapOKU, following the web build in
github.com/unforgettablyz/mapoku. Same palette and the same three sections:
Routes, Report, Rewards.

The demo is set in three Sime Darby Property hubs, with the same real
coordinates and landmarks as the team's MapLibre build: SJCC / SJ7 (Subang
Jaya), City of Elmina (Shah Alam) and KL East (Kuala Lumpur). Switch between
them with the chips at the top of the map. The data lives in
`lib/data/sime_darby_demo.dart`.

## Install into your existing `mapoku` Flutter project

From Terminal, with `mapoku_flutter.zip` in your Downloads:

```bash
cd ~/mapoku
rm -rf lib test/widget_test.dart
unzip -o ~/Downloads/mapoku_flutter.zip -d .
flutter pub get
open -a Simulator
flutter run -d iphone
```

This replaces `lib/` and `pubspec.yaml`, adds `assets/images/`, and removes
the starter test (it refers to the template's `MyApp`). Your `ios/` folder and
Xcode signing are untouched.

The app needs three entries in `ios/Runner/Info.plist`, inside the top
`<dict>`. Without them iOS closes the app when it asks for the camera,
photos or location.

```xml
<key>NSCameraUsageDescription</key>
<string>mapOKU uses the camera to photograph obstacles you report.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>mapOKU lets you attach a photo of an obstacle from your library.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>mapOKU uses your location to pin the obstacles you report.</string>
```

In the Simulator, the camera and phone calls don't work. Use "Choose from
library" for photos. For GPS, pick a location in the Simulator menu under
Features › Location (Custom Location, e.g. 3.0845, 101.5861, the SJ7 station in Subang Jaya).

### Launch screen (optional, once)

Before Flutter starts, iOS shows its own launch screen for a split second,
which is plain white by default. To make it match the app (cream background
with the logo), run once:

```bash
dart run flutter_native_splash:create
```

### App icon (once)

To put the mapOKU logo on the home screen instead of the Flutter icon:

```bash
dart run flutter_launcher_icons
```

### Android

The same code runs on Android. Add these to
`android/app/src/main/AndroidManifest.xml`, just above `<application`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<queries>
    <intent>
        <action android:name="android.intent.action.DIAL"/>
        <data android:scheme="tel"/>
    </intent>
</queries>
```

## Where things are

| Path | What it is |
|------|------------|
| `lib/main.dart` | App entry, tab bar, which repository is used |
| `lib/app/theme.dart` | Colours, type sizes, corner radii |
| `lib/data/models.dart` | Data shapes with `fromJson` |
| `lib/data/repository.dart` | Backend interface + demo data |
| `lib/data/sime_darby_demo.dart` | Township hubs, routes and obstacles |
| `lib/state/` | Tabs, points/rewards, profile, reports, Routes flow |
| `lib/screens/routes/` | Map, route sheet, navigation |
| `lib/screens/report/` | Community feed, My reports, report details, new report form |
| `lib/screens/splash/` | Opening screen with logo and tagline |
| `lib/screens/profile/` | Accessibility needs, route preferences, emergency contacts |
| `lib/screens/rewards/` | Balance, ways to earn, redeem, vouchers, history |
| `API_CONTRACT.md` | Endpoints for the backend developer |

## Map tiles

The map uses OpenStreetMap's public tile server, like the web build. That's
fine for development and demos. For a public release, switch the
`urlTemplate` in `route_map.dart` and `new_report_screen.dart` to a tile
provider with a usage plan (e.g. MapTiler, Stadia, Thunderforest).
