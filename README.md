<div align="center">

#  RunTracker

**A running tracker for iOS. Start a run, watch time and distance climb live from GPS, save it, and browse your history.**

![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-blue)
![Language](https://img.shields.io/badge/Swift-orange)
![UI](https://img.shields.io/badge/UI-UIKit%20%2B%20Storyboard-lightgrey)
![Backend](https://img.shields.io/badge/backend-Firebase-ffca28)

[Features](#features) | [Getting started](#getting-started) | [How it works](#how-it-works) | [Requirements](#course-requirements)

</div>

RunTracker measures a run in real time from GPS, stores every finished run in
**Cloud Firestore**, and mirrors the in-progress session into the **Realtime
Database** so a run survives the app being closed. Built with **UIKit +
Storyboard**, **Swift**, targeting **iOS 15+**.

> [!NOTE]
> This is an iOS course final project. The scope is deliberately focused: a
> clean, working implementation of a real feature set rather than a large app.

## Features

- **Live run tracking** - elapsed time updated every second by a `Timer`, and
  cumulative distance from GPS with jitter and teleport filtering.
- **Start / Pause / Stop** - pause and resume freely; Stop asks before saving.
- **Permanent history** - finished runs are stored in Firestore and listed in a
  custom table cell (date, distance, duration, average pace).
- **Live listener** - the list updates itself the instant a run is saved,
  deleted, or edited, with no manual refresh.
- **Run details** - a full per-run breakdown, a map with start/finish pins, and
  an editable note saved back to Firestore.
- **Resume a run** - if the app is closed mid-run, it offers to pick the run
  back up on next launch, restored from the Realtime Database.
- **Light / Dark toggle** - a one-tap switch in the navigation bar, remembered
  between launches, on top of full system-appearance support.
- **Rotation** - every screen lays out correctly in portrait and landscape.

## Screens

| Screen | What it does |
|---|---|
| **My Runs** (`RunsListController`) | Run history, newest first. Tap for details, swipe to delete, tap **New Run** to start. A sun/moon button toggles light/dark. |
| **Active Run** (`ActiveRunController`) | Live time, distance, and pace. Start / Pause / Stop. Writes the live session to the Realtime Database every second. |
| **Run Details** (`RunDetailController`) | All stats for one run, a map of the route endpoints, and an editable note. |

## Tech stack

- **Language:** Swift
- **UI:** UIKit + Storyboard, Auto Layout (stack-view based)
- **Location:** Core Location (`CLLocationManager`)
- **Maps:** MapKit (`MKMapView`)
- **Backend:** Firebase (`FirebaseCore`, `FirebaseFirestore`, `FirebaseDatabase`)
- **Dependencies:** Swift Package Manager
- **Minimum iOS:** 15.0

## Project structure

```
RunTracker/
├── AppDelegate.swift            Firebase bootstrap + friendly missing-plist guard
├── SceneDelegate.swift          Window setup
├── Model/
│   ├── Run.swift                A saved run: dictionary round-trip + display formatting
│   └── ActiveRunSession.swift   The live in-progress session (Realtime DB payload)
├── Services/
│   ├── RunStore.swift           Firestore: listen / add / delete / update note
│   ├── ActiveRunStore.swift     Realtime DB: write tick / read / clear
│   └── RunLocationTracker.swift CLLocationManager wrapper -> filtered distance
├── Controllers/
│   ├── RunsListController.swift  Table view + theme toggle
│   ├── ActiveRunController.swift Timer + location + live session
│   ├── RunDetailController.swift Stats, map, note editing
│   └── SetupRequiredController.swift  Shown only if the plist is missing
├── Views/
│   └── RunCell.swift            Custom cell + RunCellDelegate protocol
├── Extensions/
│   └── Extensions.swift         Toast, formatting, validation, AppTheme
└── Base.lproj/
    ├── Main.storyboard
    └── LaunchScreen.storyboard
```

Each `Services/` class owns one database or sensor, keeping the controllers
focused on their screens. The custom cell talks to its controller through the
delegate/protocol pattern (`RunCellDelegate`).

## Getting started

You need a **Mac with Xcode**. The steps below have a hard ordering, so read the
callouts.

### 1. Firebase console

> [!IMPORTANT]
> Create **both** databases **before** you register the iOS app. The
> `DATABASE_URL` key is only written into `GoogleService-Info.plist` if the
> Realtime Database already exists, otherwise the app fails at runtime in a way
> that looks like a code bug.

1. **Add project** and name it `RunTracker` (Google Analytics not needed).
2. **Build > Firestore Database > Create database** > **test mode** > pick a region.
3. **Build > Realtime Database > Create database** > **test mode**.
4. **Add app > iOS**, bundle ID `com.tomer.RunTracker`, download
   `GoogleService-Info.plist`.

> [!NOTE]
> Test mode leaves both databases open and its rules expire after 30 days. That
> is fine for coursework. If reads start failing weeks later, this is why.

### 2. Xcode project

1. **File > New > Project > iOS > App.** Product Name `RunTracker`, Interface
   **Storyboard**, Language **Swift**, bundle ID `com.tomer.RunTracker`.
   Deployment target **iOS 15.0**.
2. **Delete the template files first**, this repo ships its own. Move to Trash:
   `AppDelegate.swift`, `SceneDelegate.swift`, `ViewController.swift`,
   `Main.storyboard`, `LaunchScreen.storyboard`, `Assets.xcassets`. Leaving them
   causes `invalid redeclaration` errors.
3. Drag this repo's `Model`, `Services`, `Controllers`, `Views`, `Extensions`,
   `Assets.xcassets`, and the two app-delegate files into the empty `RunTracker`
   group (*Copy items if needed*, *Create groups*, target checked).

   > [!WARNING]
   > Add the two storyboards as **individual files**, not by dragging the whole
   > `Base.lproj` folder. A new project already has a `Base.lproj`, and dragging
   > another one in creates a stray `Base 2.lproj` the app cannot find, giving a
   > runtime crash `Could not find a storyboard named 'Main'`. Drag
   > `Main.storyboard` and `LaunchScreen.storyboard` in on their own.

4. Drag in your real `GoogleService-Info.plist` (target checked). Do **not**
   rename `GoogleService-Info.SAMPLE.plist`, it is a reference only.
5. **File > Add Package Dependencies** > `https://github.com/firebase/firebase-ios-sdk`.
   Add exactly `FirebaseCore`, `FirebaseFirestore`, `FirebaseDatabase`.

   > [!IMPORTANT]
   > **On Xcode 16.2 or older,** Firebase 12.15+ needs a newer toolchain and
   > fails to resolve. In the Add Package dialog set the Dependency Rule to
   > **Up to Next Major Version** from **11.0.0** to pull a Firebase 11.x
   > release; the APIs used here are identical. Set every product except the
   > three above to **None** (the list scrolls, the three are below the
   > `FirebaseAnalytics*` entries).

6. **Target > Info** > add **Privacy - Location When In Use Usage Description**
   (`NSLocationWhenInUseUsageDescription`), e.g.
   `RunTracker uses your location to measure the distance of your runs.`
   Without it, iOS silently refuses the permission prompt.
7. **Target > General > Device Orientation:** enable Portrait, Landscape Left,
   and Landscape Right.
8. **Build and run.**

> [!TIP]
> The simulator's GPS is synthetic. To make distance move, choose
> **Features > Location > City Run** in the simulator, then press Start.

## How it works

The point of the project is using each database for what it is good at.

**Cloud Firestore** holds permanent, queryable run history:

```
runs/
  <auto-id>/
    date, distanceMeters, durationSeconds, averagePaceSecPerKm,
    startLat, startLng, endLat, endLng, note
```

Read with `addSnapshotListener`, so the list re-renders the moment anything
changes: no manual refresh, one source of truth.

**Realtime Database** holds the live session only, while a run is in progress:

```
activeRun/
  isActive, elapsedSeconds, distanceMeters, startTimestamp
```

Overwritten every second and removed with `removeValue()` when the run ends. On
launch, if `isActive` is `true`, the app offers to resume.

> A small, hot, throwaway value written many times a second is exactly what the
> Realtime Database is built for; durable records you keep and query are what
> Firestore is built for. That is why both are here.

Two details worth calling out:

- **The clock is derived from dates, not counted.** `Timer` makes no real-time
  guarantees, so elapsed time is `Date().timeIntervalSince(start)` on each tick.
  The timer only triggers a refresh; it is never the source of truth.
- **GPS is filtered.** Fixes that are inaccurate, stale, or imply an
  implausible speed (a signal glitch or a simulator teleport) are rejected, so
  standing still does not invent distance and a jump does not add kilometres.

## Course requirements

| Requirement | Where |
|---|---|
| Table View + custom cell | `RunsListController`, `Views/RunCell.swift` |
| Firestore | `Services/RunStore.swift` |
| Realtime Database | `Services/ActiveRunStore.swift` |
| Location | `Services/RunLocationTracker.swift` |
| Timers | `ActiveRunController` |
| Dark Mode | Semantic colors + `AccentGreen` color set + manual toggle (`AppTheme`) |
| Screen rotation | Auto Layout + stack views; the active-run stats reflow in landscape |
| Delegate pattern | `RunCellDelegate` between the cell and its controller |

## Known limitations

- **No background location.** The app requests "when in use" only, so tracking
  pauses if you leave it mid-run. Continuous tracking would need the Background
  Modes capability and an "always" prompt, beyond this project's scope.
- **No authentication.** All runs share one collection. Firebase Auth and
  per-user scoping would be the natural next step.
- **Simulator GPS is synthetic.** Real accuracy needs a physical device.
