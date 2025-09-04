import SwiftUI

struct ActiveSessionView: View {
    @ObservedObject var coordinator: PhaseCoordinator
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: coordinator.timerEngine.progress)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(coordinator.timerEngine.currentPhase.color)
            
            HStack(spacing: 12) {
                if coordinator.timerEngine.isPaused {
                    Button(action: { coordinator.resumeSession() }) {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Button(action: { coordinator.pauseSession() }) {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                
                Button(action: { coordinator.skipPhase() }) {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}