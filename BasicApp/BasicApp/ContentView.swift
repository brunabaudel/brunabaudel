import SwiftUI

struct ContentView: View {
    @State private var tapCount = 0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Hello, iOS!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("A basic SwiftUI app")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Tap me") {
                tapCount += 1
            }
            .buttonStyle(.borderedProminent)

            if tapCount > 0 {
                Text("Tapped \(tapCount) time\(tapCount == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
