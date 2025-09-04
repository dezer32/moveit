import Foundation

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
        TimeFormatter.adaptiveDuration(sittingTime)
    }
    
    var formattedStandingTime: String {
        TimeFormatter.adaptiveDuration(standingTime)
    }
}