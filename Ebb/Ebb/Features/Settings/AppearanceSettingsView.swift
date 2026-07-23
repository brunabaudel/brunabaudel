import SwiftUI

/// Settings → Appearance theme picker (`symptom-tracker-theme-picker.html`).
struct AppearanceSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(ThemePreferences.self) private var themePreferences
    @Environment(EntitlementsService.self) private var entitlements

    @State private var showPaywall = false
    @State private var lockedThemeName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pick a theme — the whole app re-skins. Symptoms always stay warm, your cycle always stays cool.")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Text("THEME")
                    .font(.caption2.monospaced())
                    .tracking(1.8)
                    .foregroundStyle(theme.muted.opacity(0.8))
                    .padding(.top, 22)
                    .padding(.bottom, 13)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                    ForEach(Theme.all) { candidate in
                        themeTile(candidate)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(theme.base)
        .foregroundStyle(theme.text)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            EbbPlusPaywallSheet()
        }
        .alert("Ebb+ theme", isPresented: showLockedThemeAlert) {
            Button("Unlock Ebb+") { showPaywall = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let lockedThemeName {
                Text("\(lockedThemeName) is part of Ebb+. Plum & Ember stays free forever.")
            }
        }
    }

    private var showLockedThemeAlert: Binding<Bool> {
        Binding(
            get: { lockedThemeName != nil },
            set: { if !$0 { lockedThemeName = nil } }
        )
    }

    private func themeTile(_ candidate: Theme) -> some View {
        let isSelected = themePreferences.selectedThemeID == candidate.id
        let isLocked = !themePreferences.canUse(candidate, isEbbPlus: entitlements.isEbbPlus)

        return Button {
            if themePreferences.select(candidate, isEbbPlus: entitlements.isEbbPlus) {
                return
            }
            lockedThemeName = candidate.name
        } label: {
            VStack(spacing: 9) {
                themePreviewBand(candidate)
                HStack {
                    Text(candidate.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.muted)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.onPain)
                            .frame(width: 17, height: 17)
                            .background(theme.pain, in: Circle())
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(9)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? theme.pain : theme.line, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(candidate.name)\(isLocked ? ", locked" : isSelected ? ", selected" : "")")
    }

    private func themePreviewBand(_ candidate: Theme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("LUTEAL")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(candidate.cycle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay {
                        Capsule().strokeBorder(candidate.cycle, lineWidth: 1)
                    }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(candidate.pain).frame(width: 9, height: 9)
                    Circle().fill(candidate.cycle).frame(width: 9, height: 9)
                }
            }
            Spacer(minLength: 0)
            Text("Aa")
                .font(.system(.body, design: .serif))
                .foregroundStyle(candidate.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(candidate.base, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(candidate.line, lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
    .environment(\.theme, .nocturne)
    .environment(ThemePreferences())
    .environment(EntitlementsService(previewIsEbbPlus: false, listenForUpdates: false))
}
