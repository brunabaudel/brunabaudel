import SwiftUI
import UIKit

/// Binds a temporary export file to `.sheet(item:)` so the share sheet only
/// presents once the URL exists (avoids an empty first presentation).
struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
