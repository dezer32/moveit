import Foundation

struct PendingTransition {
    let fromPhase: Phase
    let toPhase: Phase
    let timestamp: Date
    
    init(from: Phase, to: Phase) {
        self.fromPhase = from
        self.toPhase = to
        self.timestamp = Date()
    }
}