import SwiftUI

struct FooterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        HStack {
            Button(action: {
                // Dismiss the MenuBarExtra popup
                dismiss()
                // Open settings window after a small delay to ensure popup is dismissed
                DispatchQueue.main.async {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }) {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
    }
}