import Foundation
import Combine
import UserNotifications

protocol TransitionManaging {
    var pendingTransition: PendingTransition? { get }
    var isShowingConfirmation: Bool { get }
    
    func handlePhaseCompleted(_ phase: Phase, askBeforeTransition: Bool) -> PendingTransition?
    func confirmTransition()
    func cancelTransition()
    func snoozeTransition(duration: TimeInterval)
}

class TransitionManager: ObservableObject, TransitionManaging {
    @Published var pendingTransition: PendingTransition?
    @Published var isShowingConfirmation = false
    
    func handlePhaseCompleted(_ phase: Phase, askBeforeTransition: Bool) -> PendingTransition? {
        // Determine next phase
        let nextPhase: Phase = phase == .sitting ? .standing : .sitting
        
        // Check if we should ask for confirmation
        if askBeforeTransition {
            // Store pending transition
            pendingTransition = PendingTransition(from: phase, to: nextPhase)
            isShowingConfirmation = true
            return pendingTransition
        } else {
            // Auto-transition
            return PendingTransition(from: phase, to: nextPhase)
        }
    }
    
    func confirmTransition() {
        guard pendingTransition != nil else { return }
        
        // Clear pending state
        pendingTransition = nil
        isShowingConfirmation = false
    }
    
    func snoozeTransition(duration: TimeInterval = 5 * 60) {
        guard pendingTransition != nil else { return }
        
        // Clear pending state
        pendingTransition = nil
        isShowingConfirmation = false
    }
    
    func cancelTransition() {
        // Clear pending state
        pendingTransition = nil
        isShowingConfirmation = false
    }
}