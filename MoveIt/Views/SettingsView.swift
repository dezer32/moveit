import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var coordinator: PhaseCoordinator
    @State private var schedule = Schedule()
    @State private var sittingMinutes: Double = 30
    @State private var standingMinutes: Double = 15
    @State private var snoozeMinutes: Double = 5
    @State private var showingResetAlert = false
    @State private var showingResetConfirmation = false
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
                    
                    VStack(alignment: .leading) {
                        Text("Snooze Duration: \(Int(snoozeMinutes)) minutes")
                        Slider(value: $snoozeMinutes, in: 1...30, step: 1)
                    }
                }
                
                Section("Automation") {
                    Toggle("Auto-start on launch", isOn: $schedule.autoStart)
                    Toggle("Ask before phase transitions", isOn: $schedule.askBeforeTransition)
                }
                
                Section("Data Management") {
                    HStack {
                        Text("Reset all statistics data")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            showingResetAlert = true
                        }) {
                            Label("Reset Statistics", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                    }
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
        .frame(width: 400, height: 450)
        .onAppear {
            loadSettings()
        }
        .alert("Reset All Statistics", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                coordinator.resetAllStatistics()
                showingResetConfirmation = true
            }
        } message: {
            Text("This will permanently delete all your session history and statistics. This action cannot be undone.")
        }
        .alert("Statistics Reset", isPresented: $showingResetConfirmation) {
            Button("OK") { }
        } message: {
            Text("All statistics have been successfully reset.")
        }
    }
    
    private func loadSettings() {
        schedule = coordinator.schedule
        sittingMinutes = Double(Int(schedule.sittingDuration) / 60)
        standingMinutes = Double(Int(schedule.standingDuration) / 60)
        snoozeMinutes = Double(Int(schedule.snoozeDuration) / 60)
    }
    
    private func saveSettings() {
        schedule.sittingDuration = sittingMinutes * 60
        schedule.standingDuration = standingMinutes * 60
        schedule.snoozeDuration = snoozeMinutes * 60
        
        // Update the coordinator's schedule
        coordinator.schedule = schedule
    }
}