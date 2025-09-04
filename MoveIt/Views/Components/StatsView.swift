import SwiftUI

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