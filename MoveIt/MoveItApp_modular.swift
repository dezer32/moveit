import SwiftUI

@main
struct MoveItApp: App {
    @StateObject private var coordinator = PhaseCoordinator()
    
    init() {
        // Configure appearance if needed
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: coordinator)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: coordinator.timerEngine.currentPhase.icon)
                if coordinator.timerEngine.currentPhase != .inactive {
                    Text(coordinator.timerEngine.formattedRemainingTime)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }
    }
}