import Foundation

struct Schedule: Codable {
    var sittingDuration: TimeInterval = 30 * 60 // 30 minutes
    var standingDuration: TimeInterval = 15 * 60 // 15 minutes
    var notificationsEnabled: Bool = true
    var soundEnabled: Bool = true
    var workStartTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    var workEndTime: Date = Calendar.current.date(from: DateComponents(hour: 18, minute: 0))!
    var autoStart: Bool = true
    var askBeforeTransition: Bool = true
    var snoozeDuration: TimeInterval = 5 * 60 // Default 5 minutes snooze
    
    var formattedSittingDuration: String {
        TimeFormatter.durationInMinutes(sittingDuration)
    }
    
    var formattedStandingDuration: String {
        TimeFormatter.durationInMinutes(standingDuration)
    }
}