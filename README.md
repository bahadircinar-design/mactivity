# Folio

A note-taking app built to shine on **iPhone Duo** — compact capture on the outer display, a wide writing canvas when open, and a fold-aware split when Duo is partially folded.

## Why it fits Duo

| Pose | Experience |
| --- | --- |
| **Closed (5.4″ outer)** | Compact list + push navigation. Quick capture with **New Note** pinned in the trailing toolbar. |
| **Open (7.6″ inner)** | `ArrangementView` with `.split` — notes list beside the editor. |
| **Partially folded** | The arrangement (and `reservedRegions(kind: .division)`) keeps each pane entirely on one side of the crease. Book and tent poses both work. |
| **Tight toolbars** | `visibilityPriority(.high)` + `topBarPinnedTrailing` keep **New Note** visible longest, matching Apple’s Notes guidance for Duo. |

Multiple scenes are enabled so Folio can participate in Duo multitasking on the inner display.

## Requirements

- Xcode with the **iOS 27.1 SDK** (or later) for full Duo chrome (vertical bars on the inner display)
- iPhone Duo simulator or device, or any iOS 27 simulator to exercise compact / regular size classes

## Open and run

```bash
open Folio.xcodeproj
```

Select an **iPhone Duo** simulator (or iPhone 18 Pro for outer-style compact), then Run.

Set your Development Team under Signing & Capabilities if you deploy to a device.

## What’s inside

```
Sources/Folio/
  App/           FolioApp — SwiftData container
  Models/        Note + accent palette
  Views/         ArrangementView shell, list, editor, fold helpers
  Support/       Theme, first-launch sample notes
Resources/       Info.plist, assets, app icon
Folio.xcodeproj  iOS app target (iOS 27+)
```

Notes are stored on-device with **SwiftData**. No account, no network.

## Design notes

- Cool slate paper background with a quiet grain — brand mark uses a two-leaf fold glyph
- Serif titles for the page, system text for the body
- Accent stripe per note (ink, moss, dusk, copper, sea)
- Pose badge briefly labels Outer / Inner / Folded when the regular-width shell appears

## Duo checklist (from Apple’s prepare guide)

- [x] No `UIScreen.main` sizing
- [x] Layout from size classes + geometry / arrangement
- [x] Adapt to fold via `ArrangementView` and `reservedRegions`
- [x] Toolbar visibility priorities for primary actions
- [x] `UIApplicationSupportsMultipleScenes` enabled
- [x] Built against iOS 27 deployment target
