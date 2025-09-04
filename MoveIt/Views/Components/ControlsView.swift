import SwiftUI

struct ControlsView: View {
    @ObservedObject var coordinator: PhaseCoordinator
    
    var body: some View {
        VStack(spacing: 8) {
            if coordinator.timerEngine.currentPhase == .inactive {
                Button(action: { coordinator.startSession(phase: .sitting) }) {
                    Label("Start Working", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else {
                Button(action: { coordinator.stopSession() }) {
                    Label("Stop Session", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
}