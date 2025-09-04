import SwiftUI

struct HeaderView: View {
    @ObservedObject var coordinator: PhaseCoordinator
    
    var body: some View {
        HStack {
            Image(systemName: coordinator.timerEngine.currentPhase.icon)
                .font(.title2)
                .foregroundColor(coordinator.timerEngine.currentPhase.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("MoveIt")
                    .font(.headline)
                Text(coordinator.timerEngine.currentPhase.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if coordinator.timerEngine.currentPhase != .inactive {
                Text(coordinator.timerEngine.formattedRemainingTime)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(coordinator.timerEngine.currentPhase.color)
            }
        }
    }
}