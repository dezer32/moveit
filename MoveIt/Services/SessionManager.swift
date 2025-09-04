import Foundation
import Combine

protocol SessionManaging {
    var sessions: [SessionRecord] { get }
    var currentSessionIndex: Int? { get }
    var sessionsPublisher: AnyPublisher<[SessionRecord], Never> { get }
    
    func startSession(phase: Phase)
    func endCurrentSession()
    func saveSessions()
    func loadSessions()
    func getTodaySessions() -> [SessionRecord]
    func resetSessions()
}

class SessionManager: ObservableObject, SessionManaging {
    @Published private(set) var sessions: [SessionRecord] = []
    private(set) var currentSessionIndex: Int?
    
    var sessionsPublisher: AnyPublisher<[SessionRecord], Never> {
        $sessions.eraseToAnyPublisher()
    }
    
    private let sessionKey = "sessions"
    
    init() {
        loadSessions()
    }
    
    func startSession(phase: Phase) {
        // End current session if exists
        endCurrentSession()
        
        // Create new session
        let session = SessionRecord(phase: phase)
        sessions.append(session)
        currentSessionIndex = sessions.count - 1
        saveSessions()
    }
    
    func endCurrentSession() {
        guard let index = currentSessionIndex,
              index < sessions.count else { return }
        
        sessions[index].end()
        saveSessions()
        currentSessionIndex = nil
    }
    
    func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }
    
    func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let loadedSessions = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            sessions = loadedSessions
        } else {
            sessions = []
        }
    }
    
    func getTodaySessions() -> [SessionRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        return sessions.filter {
            $0.startDate >= startOfDay && $0.endDate != nil
        }
    }
    
    func resetSessions() {
        sessions = []
        currentSessionIndex = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}