import SwiftUI
import UserNotifications
import Combine
import Foundation
import AppKit

// MARK: - Domain Models

enum Phase: String, CaseIterable, Codable {
    case sitting = "Sitting"
    case standing = "Standing"
    case paused = "Paused"
    case inactive = "Inactive"
    
    var icon: String {
        switch self {
        case .sitting: return "chair.fill"
        case .standing: return "figure.stand"
        case .paused: return "pause.circle.fill"
        case .inactive: return "moon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .sitting: return .blue
        case .standing: return .green
        case .paused: return .orange
        case .inactive: return .gray
        }
    }
}

struct SessionRecord: Codable, Identifiable {
    var id: UUID
    var phase: String
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval
    
    init(phase: Phase, startDate: Date = Date()) {
        self.id = UUID()
        self.phase = phase.rawValue
        self.startDate = startDate
        self.duration = 0
    }
    
    mutating func end() {
        endDate = Date()
        duration = endDate!.timeIntervalSince(startDate)
    }
}

struct Schedule: Codable {
    var sittingDuration: TimeInterval = 30 * 60 // 30 minutes
    var standingDuration: TimeInterval = 15 * 60 // 15 minutes
    var notificationsEnabled: Bool = true
    var soundEnabled: Bool = true
    var workStartTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    var workEndTime: Date = Calendar.current.date(from: DateComponents(hour: 18, minute: 0))!
    var autoStart: Bool = true
    
    var formattedSittingDuration: String {
        formatDuration(sittingDuration)
    }
    
    var formattedStandingDuration: String {
        formatDuration(standingDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}

// MARK: - Services

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
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
        NotificationCenter.default.post(name: .phaseCompleted, object: currentPhase)
        skip()
    }
}

extension Notification.Name {
    static let phaseCompleted = Notification.Name("phaseCompleted")
}

class NotificationService: ObservableObject {
    @Published var permissionGranted = false
    
    init() {
        checkPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.permissionGranted = granted
            }
        }
    }
    
    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func schedulePhaseNotification(for phase: Phase, in seconds: TimeInterval) {
        guard permissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "MoveIt Reminder"
        
        switch phase {
        case .sitting:
            content.body = "Time to sit down and continue working! 💺"
        case .standing:
            content.body = "Time to stand up and stretch! 🚶"
        default:
            return
        }
        
        content.sound = .default
        content.categoryIdentifier = "PHASE_CHANGE"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "phase_change_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - View Models

class PhaseManager: ObservableObject {
    @Published var timerEngine: TimerEngine
    @Published var schedule: Schedule {
        didSet {
            saveSchedule()
            timerEngine.updateSchedule(schedule)
        }
    }
    @Published var todayStats: DailyStats = DailyStats()
    @Published var sessions: [SessionRecord] = []
    
    private let notificationService = NotificationService()
    private var cancellables = Set<AnyCancellable>()
    private var currentSessionIndex: Int?
    
    init() {
        let loadedSchedule = Self.loadSchedule()
        self.schedule = loadedSchedule
        self.timerEngine = TimerEngine(schedule: loadedSchedule)
        self.sessions = Self.loadSessions()
        
        setupObservers()
        loadTodayStats()
    }
    
    private func setupObservers() {
        // Forward inner ObservableObject changes so SwiftUI updates when timer ticks
        timerEngine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                // Update stats with current session time
                self?.updateLiveStats()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .phaseCompleted)
            .sink { notification in
                if let phase = notification.object as? Phase {
                    self.handlePhaseCompleted(phase)
                }
            }
            .store(in: &cancellables)
        
        timerEngine.$currentPhase
            .sink { phase in
                if phase == .sitting || phase == .standing {
                    self.scheduleNextNotification(for: phase)
                }
            }
            .store(in: &cancellables)
    }
    
    func startSession(phase: Phase) {
        // End current session if exists
        if let index = currentSessionIndex, index < sessions.count {
            sessions[index].end()
        }
        
        timerEngine.start(phase: phase)
        
        // Create new session
        let session = SessionRecord(phase: phase)
        sessions.append(session)
        currentSessionIndex = sessions.count - 1
        saveSessions()
    }
    
    func pauseSession() {
        timerEngine.pause()
    }
    
    func resumeSession() {
        timerEngine.resume()
    }
    
    func skipPhase() {
        // End current session before skipping
        if let index = currentSessionIndex, index < sessions.count {
            sessions[index].end()
            saveSessions()
            loadTodayStats()
        }
        timerEngine.skip()
    }
    
    func stopSession() {
        // End current session
        if let index = currentSessionIndex, index < sessions.count {
            sessions[index].end()
            saveSessions()
            loadTodayStats()
        }
        currentSessionIndex = nil
        timerEngine.stop()
        notificationService.cancelAllNotifications()
    }
    
    private func handlePhaseCompleted(_ phase: Phase) {
        // End the completed session
        if let index = currentSessionIndex, index < sessions.count {
            sessions[index].end()
            saveSessions()
            loadTodayStats()
        }
        
        if schedule.notificationsEnabled {
            let nextPhase: Phase = phase == .sitting ? .standing : .sitting
            notificationService.schedulePhaseNotification(for: nextPhase, in: 0)
        }
    }
    
    private func scheduleNextNotification(for phase: Phase) {
        guard schedule.notificationsEnabled else { return }
        
        let duration = phase == .sitting ? schedule.sittingDuration : schedule.standingDuration
        notificationService.schedulePhaseNotification(for: phase == .sitting ? .standing : .sitting, in: duration)
    }
    
    private func updateLiveStats() {
        guard timerEngine.currentPhase != .inactive else { return }
        
        // Load completed sessions stats
        loadTodayStats()
        
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
    
    private func loadTodayStats() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let todaySessions = sessions.filter { 
            $0.startDate >= startOfDay && $0.endDate != nil 
        }
        
        todayStats.sittingTime = todaySessions
            .filter { $0.phase == Phase.sitting.rawValue }
            .reduce(0) { $0 + $1.duration }
        
        todayStats.standingTime = todaySessions
            .filter { $0.phase == Phase.standing.rawValue }
            .reduce(0) { $0 + $1.duration }
    }
    
    private static func loadSessions() -> [SessionRecord] {
        if let data = UserDefaults.standard.data(forKey: "sessions"),
           let sessions = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            return sessions
        }
        return []
    }
    
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "sessions")
        }
        loadTodayStats()
    }
    
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

struct DailyStats {
    var sittingTime: TimeInterval = 0
    var standingTime: TimeInterval = 0
    var lastUpdated: Date = Date()
    
    var totalTime: TimeInterval {
        sittingTime + standingTime
    }
    
    var sittingPercentage: Double {
        guard totalTime > 0 else { return 0.5 }
        return sittingTime / totalTime
    }
    
    var formattedSittingTime: String {
        formatTime(sittingTime)
    }
    
    var formattedStandingTime: String {
        formatTime(standingTime)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            // Show seconds only in the first minute
            return "\(seconds)s"
        }
    }
}

// MARK: - Views

struct MenuBarView: View {
    @ObservedObject var phaseManager: PhaseManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(phaseManager: phaseManager)
            Divider()
            
            if phaseManager.timerEngine.currentPhase != .inactive {
                ActiveSessionView(phaseManager: phaseManager)
                Divider()
            }
            
            StatsView(stats: phaseManager.todayStats)
            Divider()
            
            ControlsView(phaseManager: phaseManager)
            Divider()
            
            FooterView()
        }
        .padding()
        .frame(width: 280)
    }
}

struct HeaderView: View {
    @ObservedObject var phaseManager: PhaseManager
    
    var body: some View {
        HStack {
            Image(systemName: phaseManager.timerEngine.currentPhase.icon)
                .font(.title2)
                .foregroundColor(phaseManager.timerEngine.currentPhase.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("MoveIt")
                    .font(.headline)
                Text(phaseManager.timerEngine.currentPhase.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if phaseManager.timerEngine.currentPhase != .inactive {
                Text(phaseManager.timerEngine.formattedRemainingTime)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(phaseManager.timerEngine.currentPhase.color)
            }
        }
    }
}

struct ActiveSessionView: View {
    @ObservedObject var phaseManager: PhaseManager
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: phaseManager.timerEngine.progress)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(phaseManager.timerEngine.currentPhase.color)
            
            HStack(spacing: 12) {
                if phaseManager.timerEngine.isPaused {
                    Button(action: { phaseManager.resumeSession() }) {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Button(action: { phaseManager.pauseSession() }) {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                
                Button(action: { phaseManager.skipPhase() }) {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

struct StatsView: View {
    let stats: DailyStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Stats")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            HStack(spacing: 16) {
                StatItem(
                    icon: "chair.fill",
                    value: stats.formattedSittingTime,
                    color: .blue
                )
                
                StatItem(
                    icon: "figure.stand",
                    value: stats.formattedStandingTime,
                    color: .green
                )
            }
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * stats.sittingPercentage)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * (1 - stats.sittingPercentage))
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
    }
}

struct ControlsView: View {
    @ObservedObject var phaseManager: PhaseManager
    
    var body: some View {
        VStack(spacing: 8) {
            if phaseManager.timerEngine.currentPhase == .inactive {
                Button(action: { phaseManager.startSession(phase: .sitting) }) {
                    Label("Start Working", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else {
                Button(action: { phaseManager.stopSession() }) {
                    Label("Stop Session", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
}

struct FooterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        HStack {
            Button(action: {
                // Dismiss the MenuBarExtra popup
                dismiss()
                // Open settings window after a small delay to ensure popup is dismissed
                DispatchQueue.main.async {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }) {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var phaseManager: PhaseManager
    @State private var schedule = Schedule()
    @State private var sittingMinutes: Double = 30
    @State private var standingMinutes: Double = 15
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Form {
                Section("Work Schedule") {
                    VStack(alignment: .leading) {
                        Text("Sitting Duration: \(Int(sittingMinutes)) minutes")
                        Slider(value: $sittingMinutes, in: 5...60, step: 5)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Standing Duration: \(Int(standingMinutes)) minutes")
                        Slider(value: $standingMinutes, in: 5...30, step: 5)
                    }
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $schedule.notificationsEnabled)
                    Toggle("Enable Sound", isOn: $schedule.soundEnabled)
                }
                
                Section("Automation") {
                    Toggle("Auto-start on launch", isOn: $schedule.autoStart)
                }
            }
            .padding()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
        }
        .frame(width: 400, height: 400)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        schedule = phaseManager.schedule
        sittingMinutes = Double(Int(schedule.sittingDuration) / 60)
        standingMinutes = Double(Int(schedule.standingDuration) / 60)
    }
    
    private func saveSettings() {
        schedule.sittingDuration = sittingMinutes * 60
        schedule.standingDuration = standingMinutes * 60
        
        // Update the phaseManager's schedule
        phaseManager.schedule = schedule
    }
}

// MARK: - Main App

@main
struct MoveItApp: App {
    @StateObject private var phaseManager = PhaseManager()
    
    init() {
        // Configure appearance if needed
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(phaseManager: phaseManager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: phaseManager.timerEngine.currentPhase.icon)
                if phaseManager.timerEngine.currentPhase != .inactive {
                    Text(phaseManager.timerEngine.formattedRemainingTime)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(phaseManager)
        }
    }
}
