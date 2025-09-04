# MoveIt - Standing Desk Reminder App for macOS

A beautiful macOS menu bar app that helps you maintain a healthy work routine by reminding you when to sit and stand while working.

## Features

✅ **Smart Timer System**
- Configurable sitting/standing durations
- Pause/resume functionality
- Skip to next phase
- Wall-clock time reconciliation (handles sleep/wake)

✅ **Menu Bar Integration**
- Live countdown timer
- Current phase indicator with icons
- Quick controls dropdown

✅ **Daily Statistics**
- Track sitting vs standing time
- Visual progress bars
- Percentage breakdown

✅ **Notifications**
- Customizable reminders
- Sound alerts
- Permission handling

✅ **Settings**
- Adjust work intervals (5-60 min sitting, 5-30 min standing)
- Toggle notifications and sounds
- Auto-start option

✅ **Data Persistence**
- SwiftData integration
- Session history tracking
- Settings saved locally

## How to Build and Run

### Option 1: Using Xcode (Recommended)

1. Open `MoveIt.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities:
   - Click on the project in the navigator
   - Select the MoveIt target
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Select your Team from the dropdown
3. Build and run (⌘+R)

### Option 2: Manual Setup

If you encounter signing issues:

1. Remove entitlements temporarily:
   - Comment out the entitlements in Info.plist
   - Or use ad-hoc signing

2. Build from command line:
   ```bash
   xcodebuild -project MoveIt.xcodeproj -scheme MoveIt -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build
   ```

### Option 3: Create New Project

1. Open Xcode
2. Create new macOS app with SwiftUI
3. Replace the default `ContentView.swift` with `MoveItApp.swift`
4. Enable required capabilities:
   - App Sandbox
   - User Notifications

## Project Structure

```
MoveIt/
├── MoveItApp.swift          # Complete application in single file
├── Assets.xcassets/         # App icons and colors
├── Preview Content/         # SwiftUI preview assets
├── MoveIt.entitlements      # App permissions
└── Info.plist              # App configuration
```

## Architecture

The app follows MVVM architecture with clear separation:

- **Models**: `Phase`, `Session`, `Schedule`, `DailyStats`
- **Services**: `TimerEngine`, `NotificationService`
- **ViewModels**: `PhaseManager`
- **Views**: `MenuBarView`, `SettingsView`, and components

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9+

## Customization

The entire app is in `MoveItApp.swift` for easy modification:

- **Change default durations**: Modify `Schedule` struct defaults
- **Customize colors**: Update `Phase.color` computed property
- **Add features**: Extend `PhaseManager` with new functionality
- **Modify UI**: Update views in the Views section

## Widget Support (Future)

The project is prepared for widget extension:
- App Group configured: `group.com.yourcompany.MoveIt`
- Data sharing ready via SwiftData
- Widget placeholder in project structure

## Troubleshooting

**"Project damaged" error**: 
- Open in Xcode and let it repair the project
- Or create new project and copy the Swift file

**Signing issues**:
- Select your development team in Xcode
- Or use ad-hoc signing for testing

**Notifications not working**:
- Grant permission when prompted
- Check System Settings > Notifications > MoveIt

## License

This project is provided as-is for personal and commercial use.