import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: PhaseCoordinator
    @State private var selectedSnoozeTime: Int = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(coordinator: coordinator)
            Divider()
            
            if coordinator.timerEngine.currentPhase != .inactive {
                ActiveSessionView(coordinator: coordinator)
                Divider()
            }
            
            StatsView(stats: coordinator.todayStats)
            Divider()
            
            ControlsView(coordinator: coordinator)
            Divider()
            
            FooterView()
        }
        .padding()
        .frame(width: 280)
        .alert("Phase Complete", isPresented: .constant(coordinator.isShowingConfirmation)) {
            if let pending = coordinator.pendingTransition {
                Button("Continue to \(pending.toPhase.rawValue)") {
                    coordinator.confirmTransition()
                }
                
                Button("Snooze 5 min") {
                    coordinator.snoozeTransition(duration: 5 * 60)
                }
                
                Button("Snooze 10 min") {
                    coordinator.snoozeTransition(duration: 10 * 60)
                }
                
                Button("Pause", role: .cancel) {
                    coordinator.cancelTransition()
                }
            }
        } message: {
            if let pending = coordinator.pendingTransition {
                Text("Your \(pending.fromPhase.rawValue) phase is complete. Ready to switch to \(pending.toPhase.rawValue)?")
            }
        }
    }
}