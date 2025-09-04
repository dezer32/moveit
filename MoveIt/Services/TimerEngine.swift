import Foundation
import Combine
import SwiftUI

extension Notification.Name {
    static let phaseCompleted = Notification.Name("phaseCompleted")
}

class TimerEngine: ObservableObject {
    @Published var currentPhase: Phase = .inactive
    @Published var phaseStartTime: Date?
    @Published var remainingTime: TimeInterval = 0
    @Published var isPaused: Bool = false
    
    private var timerCancellable: AnyCancellable?
    private var pausedAt: Date?
    private var totalPausedTime: TimeInterval = 0
    private var schedule: Schedule
    
    var progress: Double {
        guard currentPhase == .sitting || currentPhase == .standing else { return 0 }
        let totalDuration = currentPhase == .sitting ? schedule.sittingDuration : schedule.standingDuration
        guard totalDuration > 0 else { return 0 }
        let elapsed = totalDuration - remainingTime
        return min(max(elapsed / totalDuration, 0), 1.0)
    }
    
    var formattedRemainingTime: String {
        TimeFormatter.durationAsTimer(remainingTime)
    }
    
    init(schedule: Schedule) {
        self.schedule = schedule
    }
    
    func start(phase: Phase) {
        stop()
        currentPhase = phase
        phaseStartTime = Date()
        isPaused = false
        totalPausedTime = 0
        pausedAt = nil
        
        let totalDuration = phase == .sitting ? schedule.sittingDuration : schedule.standingDuration
        remainingTime = totalDuration
        
        startTimer()
    }
    
    private func startTimer() {
        timerCancellable?.cancel()
        
        // Use Combine timer which works better with SwiftUI
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    func pause() {
        guard !isPaused, currentPhase != .inactive else { return }
        isPaused = true
        pausedAt = Date()
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    func resume() {
        guard isPaused, currentPhase != .inactive else { return }
        
        if let pausedAt = pausedAt {
            totalPausedTime += Date().timeIntervalSince(pausedAt)
        }
        
        isPaused = false
        self.pausedAt = nil
        
        startTimer()
    }
    
    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        currentPhase = .inactive
        phaseStartTime = nil
        remainingTime = 0
        isPaused = false
        totalPausedTime = 0
        pausedAt = nil
    }
    
    func skip() {
        let nextPhase: Phase = currentPhase == .sitting ? .standing : .sitting
        start(phase: nextPhase)
    }
    
    func updateSchedule(_ schedule: Schedule) {
        self.schedule = schedule
    }
    
    private func tick() {
        guard !isPaused, let startTime = phaseStartTime else { return }
        
        let totalDuration = currentPhase == .sitting ? schedule.sittingDuration : schedule.standingDuration
        let currentPausedTime = pausedAt != nil ? Date().timeIntervalSince(pausedAt!) : 0
        let totalElapsed = Date().timeIntervalSince(startTime) - totalPausedTime - currentPausedTime
        
        remainingTime = max(0, totalDuration - totalElapsed)
        
        if remainingTime <= 0 {
            phaseComplete()
        }
    }
    
    private func phaseComplete() {
        // Stop the timer completely
        timerCancellable?.cancel()
        timerCancellable = nil
        
        // Post notification about phase completion
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .phaseCompleted, object: self.currentPhase)
        }
    }
}