#!/usr/bin/env python3
"""
Script to update Xcode project with new Swift files
"""

import os
import uuid
import plistlib

def generate_file_references():
    """Generate file references for all Swift files in the refactored structure"""
    
    swift_files = {
        # Models
        "Models/Phase.swift": "Phase.swift",
        "Models/Schedule.swift": "Schedule.swift", 
        "Models/SessionRecord.swift": "SessionRecord.swift",
        "Models/PendingTransition.swift": "PendingTransition.swift",
        "Models/DailyStats.swift": "DailyStats.swift",
        
        # Services
        "Services/TimerEngine.swift": "TimerEngine.swift",
        "Services/SessionManager.swift": "SessionManager.swift",
        "Services/TransitionManager.swift": "TransitionManager.swift",
        "Services/NotificationService.swift": "NotificationService.swift",
        
        # ViewModels
        "ViewModels/PhaseCoordinator.swift": "PhaseCoordinator.swift",
        
        # Views
        "Views/MenuBarView.swift": "MenuBarView.swift",
        "Views/SettingsView.swift": "SettingsView.swift",
        "Views/Components/HeaderView.swift": "HeaderView.swift",
        "Views/Components/ActiveSessionView.swift": "ActiveSessionView.swift",
        "Views/Components/StatsView.swift": "StatsView.swift",
        "Views/Components/ControlsView.swift": "ControlsView.swift",
        "Views/Components/FooterView.swift": "FooterView.swift",
        
        # Utilities
        "Utilities/TimeFormatter.swift": "TimeFormatter.swift",
    }
    
    print("New Swift files to add to Xcode project:")
    print("=" * 50)
    
    for path, name in swift_files.items():
        full_path = f"MoveIt/{path}"
        if os.path.exists(f"/Users/vladislav_k/Code/Personal/MoveIt/{full_path}"):
            print(f"✅ {full_path}")
        else:
            print(f"❌ {full_path} - NOT FOUND")
    
    print("\n" + "=" * 50)
    print("\nTo add these files to Xcode:")
    print("1. Open MoveIt.xcodeproj in Xcode")
    print("2. Right-click on the MoveIt folder in the project navigator")
    print("3. Select 'Add Files to MoveIt...'")
    print("4. Navigate to each folder (Models, Services, etc.) and add all .swift files")
    print("5. Make sure 'Copy items if needed' is UNCHECKED")
    print("6. Make sure 'Add to targets: MoveIt' is CHECKED")
    print("\nAlternatively, drag and drop the folders into Xcode project navigator")

if __name__ == "__main__":
    generate_file_references()