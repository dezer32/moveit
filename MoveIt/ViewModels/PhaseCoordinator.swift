import Foundation
import Combine
import SwiftUI

/// PhaseCoordinator acts as a facade, coordinating between different services
/// This replaces the old PhaseManager god object
@MainActor
class PhaseCoordinator: ObservableObject {
    // Services
    @Published var timerEngine: TimerEngine
    @Published var schedule: Schedule {
        didSet {
            saveSchedule()
            timerEngine.updateSchedule(schedule)
        }
    }
    
    private let sessionManager: SessionManager
    private let transitionManager: TransitionManager
    private let notificationService: NotificationService
    private let statisticsService: StatisticsService
    
    // Statistics
    @Published var todayStats: DailyStats = DailyStats()
    
    // Transition state
    var pendingTransition: PendingTransition? {
        transitionManager.pendingTransition
    }
    
    var isShowingConfirmation: Bool {
        transitionManager.isShowingConfirmation
    }
    
    // Private state
    private var cancellables = Set<AnyCancellable>()
    private var lastPhase: Phase = .inactive
    
    init() {
        // Load saved schedule
        let loadedSchedule = Self.loadSchedule()
        self.schedule = loadedSchedule
        
        // Initialize services
        self.timerEngine = TimerEngine(schedule: loadedSchedule)
        self.sessionManager = SessionManager()
        self.transitionManager = TransitionManager()
        self.notificationService = NotificationService()
        self.statisticsService = StatisticsService()
        
        setupObservers()
        setupNotificationHandlers()
        updateStatsFromSessions()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Forward timer changes
        timerEngine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.updateLiveStats()
            }
            .store(in: &cancellables)
        
        // Listen for phase completion
        NotificationCenter.default.publisher(for: .phaseCompleted)
            .sink { [weak self] notification in
                if let phase = notification.object as? Phase {
                    self?.handlePhaseCompleted(phase)
                }
            }
            .store(in: &cancellables)
        
        // Track phase changes for Core Data
        timerEngine.$currentPhase
            .sink { [weak self] phase in
                self?.handlePhaseChange(phase)
            }
            .store(in: &cancellables)
        
        // Update stats when sessions change
        sessionManager.sessionsPublisher
            .sink { [weak self] _ in
                self?.updateStatsFromSessions()
            }
            .store(in: &cancellables)
        
        // Forward transition manager changes
        transitionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Sync Core Data stats
        statisticsService.$todayStatistics
            .compactMap { $0 }
            .sink { [weak self] coreDataStats in
                self?.updateUIFromCoreDataStats(coreDataStats)
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationHandlers() {
        notificationService.onTransitionAction = { [weak self] in
            self?.transitionToNextPhase()
        }
        
        notificationService.onContinueAction = { [weak self] in
            self?.restartCurrentPhase()
        }
        
        notificationService.onSnoozeAction = { [weak self] duration in
            self?.snoozeTransition(duration: duration)
        }
    }
    
    // MARK: - Public Interface
    
    func startSession(phase: Phase) {
        sessionManager.startSession(phase: phase)
        timerEngine.start(phase: phase)
    }
    
    func pauseSession() {
        timerEngine.pause()
        statisticsService.pauseTransition()
    }
    
    func resumeSession() {
        timerEngine.resume()
        statisticsService.resumeTransition()
    }
    
    func skipPhase() {
        // Clear any pending transition
        transitionManager.cancelTransition()
        
        // End current session
        sessionManager.endCurrentSession()
        updateStatsFromSessions()
        
        // Switch to next phase
        timerEngine.skip()
        
        // Start new session
        let newPhase = timerEngine.currentPhase
        if newPhase == .sitting || newPhase == .standing {
            sessionManager.startSession(phase: newPhase)
        }
    }
    
    func stopSession() {
        // Clear any pending transition
        transitionManager.cancelTransition()
        
        // End current session
        sessionManager.endCurrentSession()
        updateStatsFromSessions()
        
        // Stop timer
        timerEngine.stop()
        notificationService.cancelAllNotifications()
    }
    
    func confirmTransition() {
        guard let pending = transitionManager.pendingTransition else { return }
        
        transitionManager.confirmTransition()
        
        // Perform the transition
        timerEngine.start(phase: pending.toPhase)
        sessionManager.startSession(phase: pending.toPhase)
        
        // Schedule notification for next phase
        if schedule.notificationsEnabled {
            scheduleNextNotification(for: pending.toPhase)
        }
    }
    
    func snoozeTransition(duration: TimeInterval = 5 * 60) {
        guard transitionManager.pendingTransition != nil else { return }
        
        transitionManager.snoozeTransition(duration: duration)
        timerEngine.pause()
        
        // Schedule a reminder after snooze
        if schedule.notificationsEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self = self else { return }
                if self.timerEngine.isPaused {
                    self.notificationService.schedulePhaseNotification(for: self.timerEngine.currentPhase, in: 0)
                }
            }
        }
    }
    
    func cancelTransition() {
        transitionManager.cancelTransition()
        timerEngine.pause()
    }
    
    func resetAllStatistics() {
        // Reset Core Data statistics
        statisticsService.resetAllStatistics()
        
        // Reset sessions
        sessionManager.resetSessions()
        
        // Reset today's stats
        todayStats = DailyStats()
        
        // Update stats from fresh data
        updateStatsFromSessions()
    }
    
    // MARK: - Private Methods
    
    private func handlePhaseCompleted(_ phase: Phase) {
        // End the completed session
        sessionManager.endCurrentSession()
        updateStatsFromSessions()
        
        // Handle transition
        let pendingTransition = transitionManager.handlePhaseCompleted(phase, askBeforeTransition: schedule.askBeforeTransition)
        
        if let pending = pendingTransition {
            if schedule.askBeforeTransition {
                // Cancel scheduled notifications
                notificationService.cancelAllNotifications()
                
                // Send actionable notification
                if schedule.notificationsEnabled {
                    notificationService.sendTransitionNotification(from: pending.fromPhase, to: pending.toPhase, soundEnabled: schedule.soundEnabled)
                }
            } else {
                // Auto-transition
                timerEngine.skip()
                sessionManager.startSession(phase: pending.toPhase)
                
                if schedule.notificationsEnabled {
                    notificationService.schedulePhaseNotification(for: pending.toPhase, in: 0)
                }
            }
        }
    }
    
    private func handlePhaseChange(_ phase: Phase) {
        // Track phase transitions in Core Data
        if lastPhase != phase && phase != .paused {
            if phase != .inactive && lastPhase != .inactive {
                statisticsService.startTransition(from: lastPhase, to: phase)
            } else if phase == .inactive && lastPhase != .inactive {
                statisticsService.endTransition()
            }
            lastPhase = phase
        }
        
        // Schedule notifications
        if phase == .sitting || phase == .standing {
            scheduleNextNotification(for: phase)
        }
    }
    
    private func scheduleNextNotification(for phase: Phase) {
        guard schedule.notificationsEnabled else { return }
        
        let duration = phase == .sitting ? schedule.sittingDuration : schedule.standingDuration
        notificationService.schedulePhaseNotification(for: phase == .sitting ? .standing : .sitting, in: duration)
    }
    
    private func transitionToNextPhase() {
        if transitionManager.pendingTransition != nil {
            confirmTransition()
        } else if timerEngine.currentPhase == .sitting || timerEngine.currentPhase == .standing {
            skipPhase()
        }
    }
    
    private func restartCurrentPhase() {
        transitionManager.cancelTransition()
        
        let currentPhase = timerEngine.currentPhase
        if currentPhase == .sitting || currentPhase == .standing {
            sessionManager.endCurrentSession()
            updateStatsFromSessions()
            
            timerEngine.start(phase: currentPhase)
            sessionManager.startSession(phase: currentPhase)
            
            if schedule.notificationsEnabled {
                scheduleNextNotification(for: currentPhase)
            }
        }
    }
    
    private func updateLiveStats() {
        guard timerEngine.currentPhase != .inactive else { return }
        
        updateStatsFromSessions()
        
        // Add current active session time
        if let startTime = timerEngine.phaseStartTime {
            let currentDuration = Date().timeIntervalSince(startTime)
            
            switch timerEngine.currentPhase {
            case .sitting:
                todayStats.sittingTime += currentDuration
            case .standing:
                todayStats.standingTime += currentDuration
            default:
                break
            }
        }
        
        todayStats.lastUpdated = Date()
    }
    
    private func updateStatsFromSessions() {
        let todaySessions = sessionManager.getTodaySessions()
        
        todayStats.sittingTime = todaySessions
            .filter { $0.phase == Phase.sitting.rawValue }
            .reduce(0) { $0 + $1.duration }
        
        todayStats.standingTime = todaySessions
            .filter { $0.phase == Phase.standing.rawValue }
            .reduce(0) { $0 + $1.duration }
        
        todayStats.lastUpdated = Date()
    }
    
    private func updateUIFromCoreDataStats(_ coreDataStats: DailyStatistics) {
        todayStats.sittingTime = coreDataStats.sittingDuration
        todayStats.standingTime = coreDataStats.standingDuration
        todayStats.lastUpdated = coreDataStats.lastUpdated
    }
    
    // MARK: - Persistence
    
    private static func loadSchedule() -> Schedule {
        if let data = UserDefaults.standard.data(forKey: "schedule"),
           let schedule = try? JSONDecoder().decode(Schedule.self, from: data) {
            return schedule
        }
        return Schedule()
    }
    
    private func saveSchedule() {
        if let data = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(data, forKey: "schedule")
        }
    }
}