# ShapeSnap

A premium, minimalist iOS puzzle game inspired by "slide to complete the puzzle" verification — turned into a full standalone game. Drag, slide, rotate and flip pieces to complete the shape.

Built natively with **SwiftUI + SpriteKit**. No crypto theme, no pay-to-win.

## Features

- **600 story levels** across 10 worlds, each introducing a mechanic (rotation, mirrors, moving targets, gravity, locked pieces, teleporters, darkness, mixed gauntlet)
- **6 game modes**: Story, Time Attack (90s + time bonuses), Daily Challenge, Endless (procedural, scaling difficulty), Hardcore (move limits, no hints), Relax (no timer)
- **Boss levels** every 50 levels; **branching paths** (Calm vs. Master, 2× rewards) at the end of worlds 3, 5, 7 and 9
- **Special mechanics**: rotating boards, gravity physics, frozen/locked/invisible/magnetic/shape-shifting pieces, teleporters, mirror controls, darkness reveal, multi-layer
- **Scoring**: Perfect / Excellent / Good / Failed based on time, moves and placement accuracy; coins, stars, perfect-streak combos
- **Progression**: 6 unlockable themes, 12 achievements, perfect medals, daily login rewards (escalating 7-day cycle)
- **Game Center**: leaderboards (stars, time attack, endless, daily), achievements, friend challenges
- **Monetization (fair)**: optional rewarded ads (stubbed `AdsService`), Remove Ads IAP, cosmetic theme packs via StoreKit 2
- **Tech**: 60 FPS SpriteKit rendering, fully offline (levels generated deterministically on device), iCloud key-value sync, Core Haptics custom snap pattern, runtime-synthesized audio (zero bundled assets), light/dark mode, accessibility options (reduce motion, high contrast, larger touch targets, color-blind patterns)

## Project structure

```
ShapeSnap/
  App/        entry point
  Models/     levels, scoring, modes, progression, achievements, themes
  Levels/     deterministic seeded level generator + catalog (600 levels)
  Game/       SpriteKit scene, piece nodes, session/mode logic
  Services/   persistence, iCloud, Game Center, StoreKit, audio, haptics, daily rewards
  Views/      SwiftUI screens (home, worlds, gameplay HUD, shop, settings)
  Design/     shared styles
```

## Building

Requires macOS with Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open ShapeSnap.xcodeproj
```

Then build and run on an iOS 17+ simulator or device.

Game Center leaderboard/achievement IDs and StoreKit product IDs are defined in
`GameCenterService.swift` / `StoreService.swift` — create matching entries in App
Store Connect before release. `AdsService` is a no-op stub; wire your ad SDK behind
its interface.
