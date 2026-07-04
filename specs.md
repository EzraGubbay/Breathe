# System Specification: Advanced Custom Mindfulness Apple Watch App

## 1. Project Overview & Target Hardware
You are an autonomous AI developer tasked with building a standalone Apple Watch application (watchOS) using SwiftUI, WatchKit, and HealthKit. 

**Target Device constraints:** Apple Watch SE 2nd Generation. 
*Hardware limitation to respect:* The SE 2nd Gen has a smaller battery compared to Ultra models. Continuous sensor reads and extended haptic feedback engines must be heavily optimized to prevent severe battery drain during long sessions.

## 2. Declarative Feature Set: Session Presets
The application revolves around 5 core respiratory and meditation protocols. The UI must allow configuration of these variables prior to session launch.

### A. Resonance Breathing
* **Description:** Coherent breathing to maximize heart rate variability and align respiratory sinus arrhythmia.
* **Configuration:** * Time Selection (e.g., 5, 10, 20, 60+ minutes).
    * Breaths Per Minute (BPM) Selection (typically between 4.0 and 7.0 BPM).
* **Vital Metric Tracking:** Must explicitly trigger and track **Heart Rate Variability (HRV)**. 
* **Haptics/Visuals:** Smooth, continuous expanding/contracting visuals. Gentle inhale/exhale haptic prompts.

### B. Box Breathing
* **Description:** Tactical breathing to down-regulate the nervous system (Inhale, Hold, Exhale, Hold).
* **Configuration:** Time Selection.
* **Haptics/Visuals:** Square or segmented visual loop. Distinct haptics for phase transitions (inhale vs. hold vs. exhale).

### C. Physiological Sigh
* **Description:** Double-inhale followed by an extended exhale to rapidly offload carbon dioxide and reduce autonomic arousal.
* **Configuration:** Time Selection.
* **Vital Metric Tracking:** Must track metrics reflecting an acute reduction in stress states. (Implementation detail: Track and calculate the delta in resting heart rate from minute 1 to the final minute, and monitor real-time RR intervals if accessible to infer acute parasympathetic rebound).
* **Haptics/Visuals:** Two rapid haptic taps (double inhale), followed by a long, slowly decaying haptic (extended exhale).

### D. Wim Hof Breathing
* **Description:** Intense hyperventilation followed by extended breath retention.
* **Configuration:** **Round Selection** (e.g., 3, 4, or 5 rounds) instead of total time.
* **Flow Logic:** Each round consists of:
    1.  Hyperventilation phase (~30-40 rapid breaths).
    2.  Breath retention (Hold on exhale) – requires a user tap to advance when they need to breathe.
    3.  Recovery breath (15-second hold on inhale).
* **Haptics/Visuals:** High-energy visual pacing for hyperventilation. Timer display for the retention phase.

### E. Meditation (Generic)
* **Description:** Unstructured or lightly structured mindfulness sessions.
* **Configuration:** Time Selection and BPM Selection (optional, can be set to 0 for unguided/silent).
* **Haptics/Visuals:** Minimalist. Only interval chimes/haptics if configured.

## 3. Implementation Instructions & Architecture Guidelines

### Core Challenge: Background Execution & Extended Runtimes
To bypass the standard 5-minute suspension limit of watchOS:
1.  **Extended Runtime Session:** Implement `WKExtendedRuntimeSession` with the mindfulness ("self-care") session type, declared via the `WKBackgroundModes` Info.plist array (value `self-care`). This prevents the app from suspending when the wrist drops. *Note:* watchOS caps this session type at ~1 hour; for 60+ minute sessions the concurrent `HKWorkoutSession` (below) is what actually keeps the app alive.
2.  **Sensor Keep-Alive:** To achieve continuous, high-frequency biomarker data (especially for HRV and RR intervals during Resonance/Sigh sessions), initiate an `HKWorkoutSession` under the hood, with `activityType = .mindAndBody` and an `HKLiveWorkoutBuilder` for the live heart rate stream.
    * *Crucial Workaround:* Start the workout to keep the optical heart rate sensor continuously firing, then **discard** it at session end (`builder.discardWorkout()` after `endCollection`) instead of saving — no active calories are logged and the user's Activity Rings are never polluted.
    * *Authorization gotcha:* `HKLiveWorkoutBuilder.beginCollection` requires **share** authorization for `HKObjectType.workoutType()` even though the workout is never saved — request it alongside the mindful-session share permission.
    * *RR intervals:* live beat-to-beat RR intervals are not directly exposed to third-party apps on watchOS; the implementation uses the live heart rate stream plus a post-session SDNN query as the closest available signal.

### HealthKit Integration & Metadata Tagging
1.  **Mindful Minutes:** At the termination of any session, calculate the total active time and write an `HKCategorySample` of type `HKCategoryTypeIdentifier.mindfulSession` with value `HKCategoryValue.notApplicable.rawValue` to the `HKHealthStore`. (Mindful sessions have no meaningful category value; the sample's start/end dates carry the duration.)
2.  **Rich Metadata Injection:** When writing the sample, append a metadata dictionary. HealthKit permits arbitrary **custom string keys** alongside the framework-defined ones — use them so the session context is preserved in Apple Health:
    * `[HKMetadataKeyExternalUUID: "session_id"]`
    * Custom keys `SessionType` (e.g., "WimHof", "Resonance"), `BPM`, and `Rounds` as strings. (`HKMetadataKeyWasUserEntered` is a Bool-typed key and must not be used for this.)
3.  **HRV Extraction:** For the Resonance sessions, Apple Health normally calculates HRV (SDNN) periodically in the background. To force a read or calculate acute changes, capture the live heart rate stream and query `HKQuantityTypeIdentifier.heartRateVariabilitySDNN` immediately following the session.

### Haptic Engine Optimization (SE 2nd Gen)
* Do not use continuous haptic vibration (like standard Taptic Engine rumble), as this will decimate the SE's battery.
* Use discrete haptic transients via `WKInterfaceDevice.current().play(.directionUp)` and `play(.directionDown)` to signal the *start* of the inhale and exhale, allowing the user to pace themselves without needing the haptic motor to run the entire length of the breath.
