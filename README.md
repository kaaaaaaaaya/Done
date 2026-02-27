# TaskManagement

A macOS desktop routine tracker.  
Track daily checks, remaining tasks, streaks, and calendar history.

**Features**
- Add / delete routines and mark completion
- Today summary (done / remaining)
- Streaks with start/end dates
- Calendar visualization (missed days included)
- Customizable opacity, background color, and window behavior

**Requirements**
- macOS 13+
- Xcode 15+ or Swift 5.9+

**Run (Xcode)**
1. Open `Package.swift` in Xcode
2. Run the `TaskManagement` target

**Build App (Xcode)**
1. Open `Package.swift` in Xcode
2. `Product > Archive`
3. In Organizer: `Distribute App` → `Copy App`
4. Move the exported `.app` into `Applications`

**Run (SwiftPM)**
```bash
swift run
```

**Settings**
- `Opacity`: Window transparency
- `Window`: Normal / Always on top
- `Background`: Window background color
- `Enable streak history`: Toggle history & calendar
- `Reset window position`: Reset to top-left

**Data Storage**
- Local only
- Path: `~/Library/Application Support/TaskManagement/routines.json`

**Notes**
- Disabling streak history hides the calendar and streak UI
