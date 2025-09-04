import Foundation

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