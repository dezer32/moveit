import Foundation

/// Centralized time formatting utility to eliminate code duplication
enum TimeFormatter {
    
    /// Formats duration as "MM min" (e.g., "30 min")
    /// - Parameter duration: Time interval in seconds
    /// - Returns: Formatted string like "30 min"
    static func durationInMinutes(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
    
    /// Formats duration as "MM:SS" (e.g., "05:42")
    /// - Parameter duration: Time interval in seconds
    /// - Returns: Formatted string like "05:42"
    static func durationAsTimer(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Formats duration adaptively based on length
    /// - Less than 1 minute: "42s"
    /// - Less than 1 hour: "5m"
    /// - 1 hour or more: "1h 30m"
    /// - Parameter duration: Time interval in seconds
    /// - Returns: Adaptively formatted string
    static func adaptiveDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Formats duration as hours and minutes if over an hour, otherwise minutes
    /// Used for longer durations in statistics
    /// - Parameter duration: Time interval in seconds
    /// - Returns: Formatted string like "2h 30m" or "45m"
    static func longDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Formats a percentage value
    /// - Parameter percentage: Value between 0 and 1
    /// - Returns: Formatted string like "75%"
    static func percentage(_ value: Double) -> String {
        return "\(Int(value * 100))%"
    }
}