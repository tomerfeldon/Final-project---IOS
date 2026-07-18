# RunTracker

A running tracker for iOS. Start a run, watch time and distance update live from
GPS, save it, and browse your history.

Built with UIKit + Storyboard, Swift, iOS 15+.

## Course requirements covered

| Requirement | Where |
|---|---|
| Table View + custom cell | `RunsListController`, `Views/RunCell.swift` |
| Firestore | `Services/RunStore.swift` - run history |
| Realtime Database | `Services/ActiveRunStore.swift` - live session |
| Dark Mode | Semantic colors throughout + `AccentGreen` color set |
| Screen rotation | Auto Layout + stack views; axis flips on the active run screen |
| Location | `Services/RunLocationTracker.swift` (`CLLocationManager`) |
| Timers | `ActiveRunController` (`Timer`, 1 Hz) |

## Setup

You need a Mac with Xcode. Follow these in order - **steps 2 and 3 must happen
before step 4**, or the downloaded plist will be missing its `DATABASE_URL` key
and the Realtime Database will fail at runtime with what looks like a code bug.

### Firebase console setup

1. Go to <https://console.firebase.google.com> → **Add project** → name it
   `RunTracker`. Google Analytics is not needed; turn it off.
2. **Build → Firestore Database → Create database** → start in **test mode** →
   pick a region close to you.
3. **Build → Realtime Database → Create database** → start in **test mode**.
   *(Do this before the next step.)*
4. Project overview → **Add app → iOS**. Bundle ID: `com.tomer.RunTracker`.
   Download `GoogleService-Info.plist`. Skip the rest of the console's wizard -
   the SDK setup is already done in this repo.

> Test mode leaves both databases open to the world and the rules expire after
> 30 days. That is fine for coursework. If reads suddenly start failing a month
> from now, this is why.

### Xcode project setup

5. **File → New → Project → iOS → App**
   - Product Name: `RunTracker`
   - Interface: **Storyboard**
   - Language: **Swift**
   - Bundle Identifier: must match step 4 (`com.tomer.RunTracker`)

   Then in the target's **General** tab, set **Minimum Deployments** to **iOS 15.0**.

6. **Delete the template's files first.** This repo ships its own versions of
   most of them, and leaving both in place gives you duplicate-symbol errors
   (`invalid redeclaration of 'AppDelegate'`). In the project navigator, select
   all of these and **Move to Trash**:

   - `AppDelegate.swift`
   - `SceneDelegate.swift`
   - `ViewController.swift`
   - `Main.storyboard`
   - `LaunchScreen.storyboard`
   - `Assets.xcassets`

   The `RunTracker` group should now be empty.

7. In Finder, open this repo's `RunTracker/` folder and select **everything
   inside it** - `AppDelegate.swift`, `SceneDelegate.swift`, `Assets.xcassets`,
   `Base.lproj`, `Controllers`, `Extensions`, `Model`, `Services`, `Views`.
   Drag that selection onto the empty `RunTracker` group in Xcode. In the sheet:
   - *Copy items if needed* - checked
   - *Create groups* - selected
   - *Add to targets: RunTracker* - checked

   Drag your real `GoogleService-Info.plist` in the same way. Do **not** rename
   `GoogleService-Info.SAMPLE.plist` - it is only there as a reference and
   Firebase ignores it.

   If the app builds but launches to a black screen, the storyboard did not make
   it into the target: select `Main.storyboard` and check *Target Membership* in
   the File inspector on the right.

8. **File → Add Package Dependencies** → paste
   `https://github.com/firebase/firebase-ios-sdk` → **Add Package**.
   When asked which products to add, check exactly these three:
   - `FirebaseCore`
   - `FirebaseFirestore`
   - `FirebaseDatabase`

   The first resolve downloads a lot and can take several minutes. If it fails,
   **File → Packages → Reset Package Caches** and retry.

9. Add the Info keys. Modern Xcode has no `Info.plist` file in the navigator -
   the keys live in the target's **Info** tab instead, which writes them into
   the generated `Info.plist` at build time. Go to **target → Info** and add:

   | Key | Value |
   |---|---|
   | `Privacy - Location When In Use Usage Description` | `RunTracker uses your location to measure the distance of your runs.` |

   (If your Xcode version *does* show an `Info.plist` file, add the same key
   there instead. The raw key name is `NSLocationWhenInUseUsageDescription`.)

10. **Target → General → Device Orientation**: enable **Portrait**,
    **Landscape Left**, and **Landscape Right** for iPhone.

11. Build and run.

## Firebase data structure

**Firestore** - permanent run history:

```
runs/
  <auto-id>/
    date: Timestamp
    distanceMeters: Double
    durationSeconds: Int
    averagePaceSecPerKm: Double
    startLat, startLng: Double
    endLat, endLng: Double
    note: String
```

Read with `addSnapshotListener`, so the list updates itself the moment a run is
saved - no manual refresh.

**Realtime Database** - the live session only, while a run is in progress:

```
activeRun/
  isActive: Bool
  elapsedSeconds: Int
  distanceMeters: Double
  startTimestamp: Double
```

Written every second, and removed with `removeValue()` when the run ends. On
launch, if `isActive` is true, the app offers to resume the run.

The split is the point: Firestore holds queryable records you keep, the Realtime
Database holds fast-changing throwaway state.

## Known limitations

- **No background location.** The app only requests "when in use", so tracking
  pauses if you leave the app mid-run. Continuous background tracking needs the
  Background Modes capability and an "always" permission prompt, which is beyond
  this project's scope.
- **Simulator GPS is synthetic.** For a moving distance, use
  **Features → Location → City Run** in the simulator. Real accuracy needs a
  physical device.
- **No authentication.** All runs live in one shared collection. Adding Firebase
  Auth and scoping runs per-user would be the natural next step.
