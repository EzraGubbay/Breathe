# Breathe — Agent Context

Standalone Apple Watch mindfulness app (SwiftUI + WatchKit + HealthKit).
Full product spec: `specs.md`. Target hardware: **Apple Watch SE 2nd Gen**
(small battery — every design decision below about haptics/sensors flows from that).

## Build / Test / Run

The `.xcodeproj` is **generated** — never hand-edit it. Source of truth is `project.yml`.

```sh
xcodegen generate                                # after adding/removing ANY file
xcodebuild -project Breathe.xcodeproj -scheme BreatheWatch \
  -destination 'platform=watchOS Simulator,name=Breathe SE2' build   # or: test

# Simulator (device type must stay SE 2nd gen — it's the target hardware):
xcrun simctl create "Breathe SE2" \
  "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-44mm-2nd-generation" \
  "com.apple.CoreSimulator.SimRuntime.watchOS-26-1"                  # once
xcrun simctl boot "Breathe SE2" && open -a Simulator
APP=$(find ~/Library/Developer/Xcode/DerivedData/Breathe-*/Build/Products/Debug-watchsimulator -maxdepth 1 -name "Breathe.app")
xcrun simctl install "Breathe SE2" "$APP"
xcrun simctl launch "Breathe SE2" com.ezragubbay.breathe.watchkitapp

# Logs (services log via os.Logger, subsystem com.ezragubbay.breathe):
xcrun simctl spawn "Breathe SE2" log show --last 5m --info \
  --predicate 'subsystem == "com.ezragubbay.breathe"' --style compact
```

**To verify behavior, run the XCUITest smoke tests** (`BreatheWatchUITests`) —
do NOT try to click the Simulator window with screen-coordinate tools
(cliclick/AppleScript); it is unreliable and was a dead end. `simctl` cannot
send taps. The UI tests drive the app by accessibility and cover: home list,
a full Resonance session including the HealthKit write ("Saved to Health"
assertion), and Wim Hof retention tap-to-advance.

## Architecture (all under `BreatheWatch/`)

- `Models/` — `SessionType` (5 protocols + capability flags like `usesBPM`,
  `tracksHRV`), `SessionConfiguration` (duration/BPM/rounds + picker choices),
  `BreathPhase` (`duration == nil` ⇒ open-ended, advances on tap).
- `Engine/ProtocolTimeline.swift` — **pure** config → `SessionPlan` mapping.
  `.timed(cycle:totalDuration:)` for Resonance/Box/Sigh/Meditation (empty cycle
  = unguided), `.sequence(phases:)` for Wim Hof. All protocol timing constants
  live here. Unit-tested in `BreatheWatchTests`.
- `Engine/BreathingEngine.swift` — walks the plan with ONE timer per phase
  transition (no tick loop — battery). Publishes `currentPhase`/`phaseStartDate`;
  views animate with `withAnimation(duration:)` off those, `TimelineView` for clocks.
- `Engine/SessionController.swift` — per-session orchestrator: engine + all
  services + `SessionSummary` production. The only place they're wired together.
- `Services/` — `HapticPlayer` (see battery rules), `WorkoutSessionManager`
  (sensor keep-alive), `ExtendedRuntimeManager`, `HealthKitService` (auth,
  mindful write, SDNN query), `MetricsCollector` (pure, unit-tested).
- `Views/` — `HomeView` → `ConfigView` → `SessionView` (fullScreenCover, hosts
  per-protocol visual from `Views/Visuals/`) → `SummaryView`.

## Non-negotiable constraints (SE 2nd Gen battery + Health integrity)

1. **Haptics are discrete transients only**, fired at phase starts
   (`.directionUp` inhale / `.directionDown` exhale). Never continuous or
   repeating haptics for the length of a breath. (specs.md §Haptic Engine
   Optimization)
2. **The workout is always discarded**: `WorkoutSessionManager.stop()` calls
   `builder.discardWorkout()` after `endCollection`. Never save it — saving
   pollutes Activity Rings and logs calories.
3. **No high-frequency timers.** The engine schedules one timer per phase;
   UI time displays use `TimelineView`.

## API corrections (specs.md originally had these wrong — since fixed there; do not "fix" code back)

- Mindful minutes = `HKCategorySample` of `HKCategoryTypeIdentifier.mindfulSession`
  with `HKCategoryValue.notApplicable.rawValue`. There is no
  `HKCategoryValueSleepAnalysis.mindfulSession`.
- Session context goes in **custom string metadata keys** (`SessionType`, `BPM`,
  `Rounds`) + `HKMetadataKeyExternalUUID`. `HKMetadataKeyWasUserEntered` is Bool-typed.
- `HKLiveWorkoutBuilder.beginCollection` needs **share auth for
  `HKObjectType.workoutType()`** even though we never save the workout
  (this bit us: "beginCollection failed: Not authorized").
- Mindfulness extended runtime = `WKBackgroundModes` value `self-care` in
  Info.plist; OS-capped at ~1h. The workout session is the real keep-alive for
  60+ min sessions.
- Live RR intervals aren't exposed to third-party watchOS apps; we use the live
  HR stream + post-session SDNN query (returns nil on simulator — expected;
  the simulator generates synthetic HR during workouts but never SDNN samples).

## Progress / State (update this section as work lands)

**2026-07-05 — v1 complete and verified on the SE 2nd gen simulator.**
- All 5 protocols implemented (Resonance, Box, Sigh, Wim Hof, Meditation) with
  config screens, visuals, haptics, summary.
- Unit tests (10) + UI smoke tests (3) green.
- Verified via logs: workout keep-alive starts, workout discarded, mindful
  sample saved with metadata, SDNN query runs, haptics fire only at phase
  boundaries at correct BPM spacing.
- NOT yet done: real-device testing (haptic feel, true battery drain, real HRV
  readings), app icon, complications, session history UI.
