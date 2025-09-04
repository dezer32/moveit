import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Stack

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MoveIt")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Core Data Models

@objc(PhaseTransition)
public class PhaseTransition: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var fromPhase: String
    @NSManaged public var toPhase: String
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date?
    @NSManaged public var duration: Double
    @NSManaged public var wasPaused: Bool
    @NSManaged public var pauseDuration: Double
}

@objc(DailyStatistics)
public class DailyStatistics: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var sittingDuration: Double
    @NSManaged public var standingDuration: Double
    @NSManaged public var pausedDuration: Double
    @NSManaged public var numberOfTransitions: Int32
    @NSManaged public var lastUpdated: Date
}

// MARK: - Statistics Service

class StatisticsService: ObservableObject {
    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    @Published var currentTransition: PhaseTransition?
    @Published var todayStatistics: DailyStatistics?
    
    private var pauseStartTime: Date?
    private var totalPauseDuration: TimeInterval = 0
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        loadOrCreateTodayStatistics()
    }
    
    // MARK: - Phase Transition Tracking
    
    func startTransition(from: Phase, to: Phase) {
        // End current transition if exists
        if let current = currentTransition {
            endTransition(current)
        }
        
        // Create new transition
        let transition = PhaseTransition(context: context)
        transition.id = UUID()
        transition.fromPhase = from.rawValue
        transition.toPhase = to.rawValue
        transition.startDate = Date()
        transition.wasPaused = false
        transition.pauseDuration = 0
        
        currentTransition = transition
        totalPauseDuration = 0
        pauseStartTime = nil
        
        // Update daily statistics
        updateDailyStatistics(incrementTransitions: true)
        
        persistenceController.save()
    }
    
    func endTransition(_ transition: PhaseTransition? = nil) {
        let transitionToEnd = transition ?? currentTransition
        guard let transitionToEnd = transitionToEnd else { return }
        
        // If paused, add final pause duration
        if let pauseStart = pauseStartTime {
            totalPauseDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        
        transitionToEnd.endDate = Date()
        transitionToEnd.duration = transitionToEnd.endDate!.timeIntervalSince(transitionToEnd.startDate)
        transitionToEnd.pauseDuration = totalPauseDuration
        transitionToEnd.wasPaused = totalPauseDuration > 0
        
        // Update daily statistics with final duration
        updateDailyStatistics(transition: transitionToEnd)
        
        if transition == nil {
            currentTransition = nil
        }
        
        persistenceController.save()
    }
    
    func pauseTransition() {
        guard currentTransition != nil else { return }
        pauseStartTime = Date()
    }
    
    func resumeTransition() {
        guard let pauseStart = pauseStartTime else { return }
        totalPauseDuration += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        
        if let current = currentTransition {
            current.pauseDuration = totalPauseDuration
            current.wasPaused = true
        }
    }
    
    // MARK: - Daily Statistics
    
    private func loadOrCreateTodayStatistics() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let request = NSFetchRequest<DailyStatistics>(entityName: "DailyStatistics")
        request.predicate = NSPredicate(format: "date >= %@", startOfDay as NSDate)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                todayStatistics = existing
            } else {
                createTodayStatistics()
            }
        } catch {
            print("Error fetching today's statistics: \(error)")
            createTodayStatistics()
        }
    }
    
    private func createTodayStatistics() {
        let stats = DailyStatistics(context: context)
        stats.id = UUID()
        stats.date = Calendar.current.startOfDay(for: Date())
        stats.sittingDuration = 0
        stats.standingDuration = 0
        stats.pausedDuration = 0
        stats.numberOfTransitions = 0
        stats.lastUpdated = Date()
        
        todayStatistics = stats
        persistenceController.save()
    }
    
    private func updateDailyStatistics(transition: PhaseTransition? = nil, incrementTransitions: Bool = false) {
        guard let stats = todayStatistics else {
            loadOrCreateTodayStatistics()
            return
        }
        
        if let transition = transition {
            let activeDuration = transition.duration - transition.pauseDuration
            
            // Record time for the phase we were IN (toPhase)
            // When transition is created: from=sitting, to=standing means we're IN standing phase
            // When this transition ends, we record time for the standing phase (toPhase)
            switch transition.toPhase {
            case Phase.sitting.rawValue:
                stats.sittingDuration += activeDuration
            case Phase.standing.rawValue:
                stats.standingDuration += activeDuration
            default:
                break
            }
            
            stats.pausedDuration += transition.pauseDuration
        }
        
        if incrementTransitions {
            stats.numberOfTransitions += 1
        }
        
        stats.lastUpdated = Date()
        persistenceController.save()
    }
    
    // MARK: - Statistics Queries
    
    func getStatistics(for date: Date) -> DailyStatistics? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request = NSFetchRequest<DailyStatistics>(entityName: "DailyStatistics")
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", 
                                       startOfDay as NSDate, 
                                       endOfDay as NSDate)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching statistics for date: \(error)")
            return nil
        }
    }
    
    func getWeeklyStatistics() -> [DailyStatistics] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        let request = NSFetchRequest<DailyStatistics>(entityName: "DailyStatistics")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", 
                                       startDate as NSDate, 
                                       endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching weekly statistics: \(error)")
            return []
        }
    }
    
    func getMonthlyStatistics() -> [DailyStatistics] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -1, to: endDate)!
        
        let request = NSFetchRequest<DailyStatistics>(entityName: "DailyStatistics")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", 
                                       startDate as NSDate, 
                                       endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching monthly statistics: \(error)")
            return []
        }
    }
    
    func getAllTransitions(for date: Date) -> [PhaseTransition] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request = NSFetchRequest<PhaseTransition>(entityName: "PhaseTransition")
        request.predicate = NSPredicate(format: "startDate >= %@ AND startDate < %@", 
                                       startOfDay as NSDate, 
                                       endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching transitions: \(error)")
            return []
        }
    }
    
    // MARK: - Aggregated Statistics
    
    func calculateAverageDaily(for period: Int = 7) -> (sitting: TimeInterval, standing: TimeInterval) {
        let stats = getStatisticsForLastDays(period)
        
        guard !stats.isEmpty else { return (0, 0) }
        
        let totalSitting = stats.reduce(0) { $0 + $1.sittingDuration }
        let totalStanding = stats.reduce(0) { $0 + $1.standingDuration }
        
        let count = Double(stats.count)
        return (totalSitting / count, totalStanding / count)
    }
    
    private func getStatisticsForLastDays(_ days: Int) -> [DailyStatistics] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let request = NSFetchRequest<DailyStatistics>(entityName: "DailyStatistics")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", 
                                       startDate as NSDate, 
                                       endDate as NSDate)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching statistics for last \(days) days: \(error)")
            return []
        }
    }
    
    // MARK: - Data Cleanup
    
    func cleanupOldData(olderThan days: Int = 365) {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date())!
        
        // Delete old transitions
        let transitionRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PhaseTransition")
        transitionRequest.predicate = NSPredicate(format: "startDate < %@", cutoffDate as NSDate)
        
        let deleteTransitionsRequest = NSBatchDeleteRequest(fetchRequest: transitionRequest)
        
        // Delete old daily statistics
        let statsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DailyStatistics")
        statsRequest.predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)
        
        let deleteStatsRequest = NSBatchDeleteRequest(fetchRequest: statsRequest)
        
        do {
            try context.execute(deleteTransitionsRequest)
            try context.execute(deleteStatsRequest)
            persistenceController.save()
        } catch {
            print("Error cleaning up old data: \(error)")
        }
    }
    
    func resetAllStatistics() {
        // Delete all transitions
        let transitionRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PhaseTransition")
        let deleteTransitionsRequest = NSBatchDeleteRequest(fetchRequest: transitionRequest)
        
        // Delete all daily statistics
        let statsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DailyStatistics")
        let deleteStatsRequest = NSBatchDeleteRequest(fetchRequest: statsRequest)
        
        do {
            // Execute deletion requests
            try context.execute(deleteTransitionsRequest)
            try context.execute(deleteStatsRequest)
            
            // Reset current transition
            currentTransition = nil
            todayStatistics = nil
            
            // Save changes
            persistenceController.save()
            
            // Create fresh today's statistics
            createTodayStatistics()
        } catch {
            print("Error resetting all statistics: \(error)")
        }
    }
}

// MARK: - Statistics View Model Extension

extension StatisticsService {
    struct StatisticsSummary {
        let totalSitting: TimeInterval
        let totalStanding: TimeInterval
        let totalPaused: TimeInterval
        let transitions: Int
        let averageSitting: TimeInterval
        let averageStanding: TimeInterval
        
        var productivityScore: Double {
            let total = totalSitting + totalStanding
            guard total > 0 else { return 0 }
            let activeTime = total - totalPaused
            return (activeTime / total) * 100
        }
        
        var balanceScore: Double {
            let total = totalSitting + totalStanding
            guard total > 0 else { return 50 }
            let standingRatio = totalStanding / total
            return min(standingRatio * 200, 100) // Ideal is 50% standing
        }
    }
    
    func generateSummary(for period: StatsPeriod) -> StatisticsSummary {
        let stats: [DailyStatistics]
        
        switch period {
        case .today:
            stats = todayStatistics != nil ? [todayStatistics!] : []
        case .week:
            stats = getWeeklyStatistics()
        case .month:
            stats = getMonthlyStatistics()
        }
        
        let totalSitting = stats.reduce(0) { $0 + $1.sittingDuration }
        let totalStanding = stats.reduce(0) { $0 + $1.standingDuration }
        let totalPaused = stats.reduce(0) { $0 + $1.pausedDuration }
        let transitions = stats.reduce(0) { $0 + Int($1.numberOfTransitions) }
        
        let days = max(stats.count, 1)
        
        return StatisticsSummary(
            totalSitting: totalSitting,
            totalStanding: totalStanding,
            totalPaused: totalPaused,
            transitions: transitions,
            averageSitting: totalSitting / Double(days),
            averageStanding: totalStanding / Double(days)
        )
    }
}

enum StatsPeriod: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
}