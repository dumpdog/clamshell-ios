# Clamshell: tiny games for your open iPhone Duo

A starter SwiftUI project for an iPhone Duo party game. Hold the Duo open
sideways like a handheld console: the game plays on the top half, your
thumbs tap the bottom half, and the hinge only moves in small tilts between
about 95° and 165°. Bite a burger with a thumb tap, drum left-right to pump a
balloon, tilt the top half to hold a drawbridge at an exact angle, open a book
slowly so a dragon doesn't wake up. Each game lasts 3 to 8 seconds, WarioWare
style, and they speed up as you go. A "Clip the last 15s" button turns any run
into a shareable video.

The first version made you close the phone fully to play. On a real Duo that
worked but wasn't practical, so the games were reworked for a comfortable
grip. Why, and what else was considered, is in
[`docs/rethink.html`](docs/rethink.html).

The full plan (idea scoring, architecture, milestones, monetization, launch)
is in [`docs/plan.html`](docs/plan.html). This README covers getting the code running.

## What's here

```
Clamshell.xcodeproj         Xcode project (folder-synced, so new files show up automatically)
project.yml                 XcodeGen fallback spec, if the .xcodeproj won't open
Clamshell/
  App/        ClamshellApp, RootView           app entry and phase routing
  Input/      HingeInput                       one fold signal: hinge, tilt, or slider
              MotionHingeProvider              "tilt mode" fake hinge for any iPhone
              DuoSupport                       ALL iPhone Duo–only API, behind DUO_SDK
  Engine/     MicroGame, GameSession           game protocol, catalog, run loop
  Games/      Chomp, Drawbridge, Balloon, Sneak
  UI/         GameStageView, HUDView, MenuView, GameOverView
  Services/   ClipRecorder (ReplayKit), GameCenterService, Haptics
```

## Setup (about 10 minutes)

1. **Get Xcode 27.1 or later.** It's needed for the iOS 27.1 SDK, the
   iPhone Duo simulator, and Device Hub.
2. **Open `Clamshell.xcodeproj`.** If Xcode can't open it (the project file
   was written by hand without a Mac to test on), run this instead:
   `brew install xcodegen && cd clamshell && xcodegen`, then open the
   generated project.
3. **Signing.** Select the Clamshell target, open *Signing & Capabilities*,
   choose your Team, and change the bundle ID from `com.example.clamshell`
   to your own.
4. **First build, without the Duo APIs.** Pick any iPhone simulator and run.
   On the menu, choose **Slider** and drag it to play. This checks the core
   loop before any new API is involved.
5. **Turn on the Duo APIs.** In *Build Settings > Swift Compiler - Custom
   Flags > Active Compilation Conditions*, add `DUO_SDK` to both Debug and
   Release. Build again.
   - If `onHingeChange` or `reservedRegions` doesn't compile, fix the calls
     in `Input/DuoSupport.swift`. Nothing else depends on those names. They
     come from Apple's iPhone Duo tech talks, not from SDK headers I could
     check.
6. **Run on the iPhone Duo simulator.** Open *Window > Device Hub*, pick
   iPhone Duo, and use its fold controls. The menu should say "Fold
   detected" and switch to **Fold** automatically.
7. **Run on your Duo.** Plug it in, trust the Mac, enable Developer Mode
   (*Settings > Privacy & Security > Developer Mode*), and run.

### Things to check on real hardware first

- **Grip band.** Hinge games only read angles between
  `HingeInput.gripLowAngle` (95°) and `gripHighAngle` (165°). The menu shows
  the live hinge angle in Fold mode, so hold the phone how it feels natural,
  read the number, and move the band around it. If the gauge moves
  backwards, flip the mapping in `HingeInput.hingeDidChange`.
- **Thumb taps.** `ThumbTouchLayer` reports every touch so two thumbs can
  alternate fast. Check that Balloon counts both thumbs when they overlap.
- **Update rate.** The game loop expects at least 30 hinge updates per
  second while the phone moves. If updates are slower, Chomp will feel
  laggy. Lower the smoothing in `HingeInput.ingest`, or interpolate.
- **Fold region coordinates.** `FoldRegions.frames(in:)` assumes the
  frames are in the GeometryReader's local space. If the jaws don't line up
  with the physical crease, convert them.

## Optional capabilities

- **Game Center.** Add the Game Center capability and create a leaderboard
  with the ID `clamshell.highscore` in App Store Connect. Until then,
  submits fail quietly.
- **Clips.** ReplayKit asks for permission the first time a run starts. Clip
  buffering doesn't work in the Simulator, so test it on a device.

## Adding a game

1. Create `Games/YourGame.swift` and write a `final class` that conforms to
   `MicroGame` (`verb`, `hint`, `duration`, `update`, `draw`).
2. Draw in the canonical stage: the fold always runs horizontally at
   `stage.foldY`. `GameStageView` rotates the canvas for the book pose.
   Read `frame.taps` (left or right thumb) for taps and `frame.openness`
   (0 to 1 across the grip band) for the hinge. Never ask for a full close.
3. Add `{ YourGame(difficulty: $0) }` to `MicroGameCatalog.factories`.

## Honest status

I wrote this without a Mac or a Swift compiler. The code follows current
SwiftUI, Observation, ReplayKit and GameKit APIs, but it has **never been
compiled**. Expect a few small fixes on the first build, most likely in
`DuoSupport.swift` and in the Liquid Glass button styles
(`.glass` / `.glassProminent`). If a style gives you trouble, swap in
`.bordered` / `.borderedProminent`.
