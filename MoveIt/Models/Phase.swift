import SwiftUI

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