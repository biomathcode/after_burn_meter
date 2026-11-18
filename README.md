# Afterburn

A native SwiftUI macOS app for exercise timing and experimental, camera-based
pulse recovery observations. It includes a local catalogue of 1,324 exercises,
workout planning, a first-run consent screen, baseline capture, set timers,
seated recovery checks, a recovery journal, export, and deletion controls.

Requires **Apple Silicon and macOS 14+**. SmartSpectra does not support Intel Macs.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the component/data-flow diagrams,
measurement policies, privacy boundaries, complete fresh-checkout setup,
signing, testing, packaging, and troubleshooting.

## Build and run

1. Install and open Xcode with a macOS 26+ SDK, accept its licence, and install its macOS components.
2. Install CMake 3.26+ and Python 3.12+ if needed: `brew install cmake python`.
3. Run `python3 scripts/build.py --team YOUR_TEAM_ID` from this directory on the first build.
   Later builds can use `python3 scripts/build.py` with the remembered local team.
4. Run `python3 scripts/run.py` to open the app and load `SMARTSPECTRA_API_KEY`
   from the development `.env`, without copying it into the app bundle.

The app uses **live camera measurements only**. There is no simulation mode
or generated pulse. A separate AVFoundation camera preview lets you check camera
access and framing without starting the SDK. Your signing team is remembered locally in
`.afterburn-local.json` (ignored by version control). The build script requires
an Apple Development team and signs the app and its bundled libraries.

The built app is at `build/live/Debug/Afterburn.app`. Open it through
`scripts/run.py` to load the development `.env` securely into the process.
Opening the bundle directly requires a key already saved in Settings/Keychain.

On **macOS 26+**, the camera stage and navigation use native Liquid Glass,
including `GlassEffectContainer` and glass button styles. macOS 14–15 use native
material fallbacks. Reduce Transparency uses solid control surfaces; Reduce
Motion disables moving celebrations and animated digits. The expand button
enters the Mac's actual full-screen mode rather than opening a larger sheet.

## Local development testing

To build and open the interface while the Apple signing key is locked:

```sh
python3 scripts/build.py --development
python3 scripts/run.py
```

This is an ad-hoc signed development build of the same live-only app. Choose
**Open camera** on the stage or in Settings to check the real camera feed. Camera
preview needs consent and macOS camera permission; it does not require an API
key or Apple Development signing. No audio or video recording is requested.

**Measure baseline** / **Test SmartSpectra** hands the camera over to the real
SDK, using the configured API key. SDK errors are shown rather than replaced
with generated readings. Presage requires Apple Development signing and Keychain
entitlements for SDK startup; an ad-hoc build is not a supported measurement
configuration, even if its camera preview or SDK start call succeeds.

## Enable live camera measurement

SmartSpectra's macOS SDK requires a real **Apple Development signing identity**
and the SDK's Keychain entitlements, even for file-based processing. Ad-hoc
signing is insufficient. No API key is hard-coded or bundled.

1. Add your Apple account under Xcode → Settings → Accounts.
2. Create an Apple Development certificate under Manage Certificates.
3. Build with your Team ID:

```sh
python3 scripts/build.py --team YOUR_TEAM_ID
python3 scripts/run.py
```

Alternatively, open `Afterburn.xcodeproj`, select the **Afterburn** target,
configure Signing & Capabilities → Team, and run. Enter your key in the app's
Settings; it is stored in macOS Keychain. You can select a camera in Settings.

`scripts/setup.py` downloads the official, pinned SmartSpectra **3.5.0** release
into `.vendor/` and generates the Xcode project with CMake. It does not install
the SDK globally. Builds use a separate `build/live` tree to avoid locks from older projects.
The generated project is available through the root
`Afterburn.xcodeproj` symlink. Pass `--team` to setup/build to preserve your team
when regenerating it.

## Signing troubleshooting

If macOS rejects the Mac login password, the login Keychain may still use an
older password. Unlock it locally in Keychain Access. Do not send passwords to
Codex. Do not reset/delete the Keychain just to get this app to sign; Apple
warns that resetting can remove saved credentials.

A visible certificate and Team ID do not prove that its private key can sign.
`errSecInternalComponent` or a signing authorization timeout is a build blocker,
not a reason to use fabricated vitals. The app fails visibly on unavailable
signing, credentials, permissions, or sensor input.

In Keychain Access, select **login → My Certificates** and expand the valid
**Apple Development** certificate to locate its private key. An expired
certificate with the same name is not usable. Authorize the signing prompt
locally with the password for that Keychain; after a password change or migration,
it may be an older Mac password rather than the current login password.

If that password is unavailable, a fresh macOS user account with its own login
Keychain is an alternative: sign into Xcode with the same Apple account and use
**Settings → Accounts → Manage Certificates → + → Apple Development** to create
a new signing identity. This creates a new private key; it does not recover or
move the inaccessible one. Keep the existing Keychain intact.

Setup references: [Presage macOS guide](https://smartspectra.presagetech.com/docs/cpp/macos/),
[Apple Keychain password guidance](https://support.apple.com/en-gb/guide/keychain-access/kyca2429/mac),
and [Xcode certificate management](https://help.apple.com/xcode/mac/current/en.lproj/dev154b28f09.html).

## Session flow

1. Review consent. Acceptance is saved per notice version; withdrawing consent
   stops capture and returns to onboarding. The macOS camera prompt is separate.
2. Open the stage’s session controls to choose a camera and edit your movements,
   sets, repetitions, and targets in one sheet. Add movements from the library.
   **Open camera** checks framing before you start a baseline.
3. Measure a fresh session baseline: at least 12 seconds of sensor warm-up,
   followed by 30 continuous seconds of valid pulse.
4. Start and finish a set manually. The camera is off during exercise. Pausing
   stops the exercise timer.
5. Sit facing the camera for recovery. Elapsed time starts at set completion;
   qualification starts only after warm-up and requires 15 continuous valid
   seconds within ±5 BPM of the baseline.
6. Continue manually to the next set. Results include their policy, SDK version,
   measurement gaps, data source, and outcome. An interval ended manually is
   never labelled as an observed return near baseline.

These are **experimental prototype rules**, not validated medical or exercise
prescriptions. Pulse recovery does not measure EPOC/calorie afterburn, muscle
healing, or readiness to start another set. SmartSpectra's repository documents
40–110 BPM while its newer pulse model card says 40–180 BPM. Until Presage
confirms the released model's range and post-exercise validity, this app
conservatively excludes readings outside **40–110 BPM** from qualification.
Confidence must be at least 90, stability must be true, validation must be OK,
and a sample must be fresh. A gap exceeding 3 seconds resets qualification.

The SDK reports averaged pulse with delay. The app records an **observed
interval**, including warm-up, confirmation, and measurement gaps; it does not
claim to identify the exact physiological baseline-crossing instant.

## Privacy and storage

- Consent is versioned in local preferences. Workouts and derived observations
  use local SwiftData storage. History can be exported as JSON or deleted.
- API keys use Keychain or the development process environment. `.env` files
  are ignored and are never copied by resource packaging.
- Legacy simulated records are excluded from history, export, and analysis; they
  are not silently relabelled as real measurements.
- The public cardio, breathing, and EDA bundles match Presage's macOS sample.
  All vitals shows pulse, breathing rate, RMSSD, SDNN, mean NN, Baevsky index,
  relative arterial waveform, chest/abdominal movement, and EDA Proxy. The
  additional signals remain in memory; saved recovery observations use pulse only.
  Each metric has its own warm-up, confidence/stability, and freshness state.
  Missing metrics remain unavailable rather than becoming zero readings.
  SDK telemetry and accumulated output are off.
  No recording output directory or LLM Insights callback is configured, and no
  Insights requests are made.
- Afterburn does not save raw camera images/video or request microphone access.
- The SDK still needs authenticated network access, device-related setup, and
  its persistent local cache/Keychain state. Its closed-source network behaviour
  has not been independently audited. A zero-egress/offline guarantee is not made.
- Camera callbacks copy borrowed buffers before returning and retain at most
  one pending preview frame. Start/stop work stays off the UI thread.
- Sleep, consent withdrawal, and termination interrupt active capture. Completed
  observations remain until the user deletes them.

Consent notice version 2 covers the added live vitals. Existing users review the
updated notice once. Baseline completion keeps measurement running so HRV can
fill its 60-second window; starting an exercise set stops capture as before.

The SDK diagnostics show its actual lifecycle, validation hint, accepted/blocked
frames, metric packets, and received pulse samples. Camera preview alone is not
treated as evidence of physiological measurement. An API key may omit metrics
it is not authorized to receive. Unavailable metrics (apnea, breathing amplitude,
respiratory line length, breathing baseline, inhale/exhale ratio) are not
requested. Experimental blood-pressure output is not used: the shipped header
identifies it as fixed stand-in output, not a measurement.

The integration guidance is installed as the official
`using-smartspectra` Codex skill from `Presage-Security/SmartSpectra`.

## Code layout

| Directory | Responsibility |
| --- | --- |
| `App/Views` | SwiftUI screens and chart components |
| `App/AppModel.swift` | Workout state machine and app actions |
| `App/Services` | SwiftData, Keychain, and sensor lifecycle |
| `App/Bridge` | Objective-C++ adapter around the vendor C++ API |
| `Sources/AfterburnCore` | Portable models and recovery qualification logic |
| `Tests/AfterburnCoreTests` | Baseline, signal quality, recovery, and persistence tests |
| `Resources` | Local exercise catalogue and notices |
| `scripts` | SDK setup, Xcode generation, runtime packaging, and development launch |

Run the core tests with:

```sh
swift test --scratch-path build/core-tests
```

## Distribution

The build bundles the SDK dylib, its FFmpeg runtime, graph/models, and all vendor
notices. Distribution requires your Developer ID signing, the necessary
entitlements, notarization, and confirmation of Presage's redistribution and
credential-provisioning terms. Do not ship a shared project API key.

The exercise catalogue's structure and English instruction text are MIT licensed;
see `Resources/EXERCISES-LICENSE.txt`. Gym Visual images and GIFs require a separate
licence and are deliberately excluded. Recovery analysis reports median/peak valid pulse, valid sample counts, signal
coverage, and the observed outcome using measured data only. Missing signal is
not interpolated across gaps or replaced with synthetic values.

SmartSpectra is proprietary; see the
bundled vendor notices and https://physiology.presagetech.com/tos.
