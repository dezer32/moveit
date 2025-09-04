import Foundation
import UserNotifications
import SwiftUI

protocol NotificationHandling {
    var permissionGranted: Bool { get }
    func requestPermission()
    func schedulePhaseNotification(for phase: Phase, in seconds: TimeInterval)
    func sendTransitionNotification(from: Phase, to: Phase, soundEnabled: Bool)
    func cancelAllNotifications()
}

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate, NotificationHandling {
    @Published var permissionGranted = false
    
    // Notification identifiers
    static let categoryIdentifier = "moveit.phase"
    static let transitionActionId = "moveit.transition"
    static let continueActionId = "moveit.continue"
    static let snoozeActionId = "moveit.snooze"
    
    var onTransitionAction: (() -> Void)?
    var onContinueAction: (() -> Void)?
    var onSnoozeAction: ((TimeInterval) -> Void)?
    
    override init() {
        super.init()
        checkPermission()
        setupNotificationCategories()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func setupNotificationCategories() {
        // Create actions
        let transitionAction = UNNotificationAction(
            identifier: Self.transitionActionId,
            title: "Перейти к новому состоянию",
            options: [.foreground]
        )
        
        let continueAction = UNNotificationAction(
            identifier: Self.continueActionId,
            title: "Продолжить текущее состояние",
            options: []
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionId,
            title: "Отложить",
            options: []
        )
        
        // Create category
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [transitionAction, continueAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([category])
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
        content.categoryIdentifier = Self.categoryIdentifier
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "phase_change_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendTransitionNotification(from: Phase, to: Phase, soundEnabled: Bool) {
        guard permissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Switch!"
        content.body = "Your \(from.rawValue) phase is complete. Ready to switch to \(to.rawValue)?"
        content.sound = soundEnabled ? .default : nil
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["fromPhase": from.rawValue, "toPhase": to.rawValue]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "transition_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            switch response.actionIdentifier {
            case Self.transitionActionId:
                self?.onTransitionAction?()
            case Self.continueActionId:
                self?.onContinueAction?()
            case Self.snoozeActionId:
                self?.onSnoozeAction?(5 * 60) // Default 5 minute snooze
            default:
                break
            }
            
            completionHandler()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound])
    }
}