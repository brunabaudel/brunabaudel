import StoreKit
import SwiftUI

enum EbbPlusPlanID: String, CaseIterable, Identifiable {
    case annual
    case monthly
    case lifetime

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .annual: EbbPlusProductIDs.annual
        case .monthly: EbbPlusProductIDs.monthly
        case .lifetime: EbbPlusProductIDs.lifetime
        }
    }

    var title: String {
        switch self {
        case .annual: "Annual"
        case .monthly: "Monthly"
        case .lifetime: "Lifetime"
        }
    }

    var fallbackSubtitle: String {
        switch self {
        case .annual: "€24.99 / year"
        case .monthly: "billed monthly"
        case .lifetime: "pay once, yours forever"
        }
    }

    var isBestValue: Bool { self == .annual }
}

/// Ebb+ plan picker sheet (paywall frame B).
struct EbbPlusPlansSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementsService.self) private var entitlements

    @State private var selectedPlan: EbbPlusPlanID = .annual
    @State private var purchaseErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    badge
                    title
                    featureList
                    privacyLine
                    planPicker
                    purchaseButton
                    footnote
                    links
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(theme.muted)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await entitlements.loadProducts()
        }
    }

    private var badge: some View {
        Text("EBB+")
            .font(.caption2.monospaced())
            .tracking(2)
            .foregroundStyle(theme.pain)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(theme.pain, lineWidth: 1)
            }
            .padding(.top, 4)
    }

    private var title: some View {
        Text(attributedTitle)
            .font(.system(.title2, design: .serif))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 14)
    }

    private var attributedTitle: AttributedString {
        var result = AttributedString(
            "See what's behind your migraines — and bring it to your doctor."
        )
        if let range = result.range(of: "bring it to your doctor.") {
            result[range].foregroundColor = theme.pain
            result[range].inlinePresentationIntent = .emphasized
        }
        return result
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            planFeature("Patterns & predictions", detail: "triggers, luteal-risk forecast")
            planFeature("Doctor PDF export", detail: "your full summary, on demand")
            planFeature("Full history", detail: "every cycle, not just the last three")
            planFeature("All themes", detail: "six palettes, light & dark")
        }
        .padding(.top, 16)
    }

    private func planFeature(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("✓")
                .font(.footnote.weight(.bold))
                .foregroundStyle(theme.pain)
            Text(attributedFeature(title: title, detail: detail))
                .font(.footnote)
        }
    }

    private func attributedFeature(title: String, detail: String) -> AttributedString {
        var result = AttributedString("\(title) · \(detail)")
        if let titleRange = result.range(of: title) {
            result[titleRange].font = .footnote.weight(.semibold)
            result[titleRange].foregroundColor = theme.text
        }
        if let detailRange = result.range(of: detail) {
            result[detailRange].foregroundColor = theme.muted
        }
        return result
    }

    private var privacyLine: some View {
        Label {
            Text("Still 100% on your phone. Premium never changes that.")
                .font(.caption)
        } icon: {
            Image(systemName: "lock.fill")
        }
        .foregroundStyle(theme.cycle)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cycleDim, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.cycle.opacity(0.35), lineWidth: 1)
        }
        .padding(.top, 14)
    }

    private var planPicker: some View {
        VStack(spacing: 9) {
            ForEach(EbbPlusPlanID.allCases) { plan in
                planRow(plan)
            }
        }
        .padding(.top, 16)
    }

    private func planRow(_ plan: EbbPlusPlanID) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                    Text(planSubtitle(plan))
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(planPrice(plan))
                        .font(.subheadline.weight(.bold))
                    Text(planPriceSuffix(plan))
                        .font(.caption2)
                        .foregroundStyle(theme.muted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? theme.painDim.opacity(0.65) : theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? theme.pain : theme.line, lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .topLeading) {
                if plan.isBestValue {
                    Text("BEST VALUE · 7-DAY FREE TRIAL")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(theme.onPain)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(theme.pain, in: RoundedRectangle(cornerRadius: 6))
                        .offset(x: 14, y: -9)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func planSubtitle(_ plan: EbbPlusPlanID) -> String {
        product(for: plan)?.displayName ?? plan.fallbackSubtitle
    }

    private func planPrice(_ plan: EbbPlusPlanID) -> String {
        switch plan {
        case .annual:
            if let product = product(for: plan) {
                let monthly = product.price / 12
                return monthly.formatted(product.priceFormatStyle)
            }
            return "€2.08"
        case .monthly, .lifetime:
            if let product = product(for: plan) {
                return product.displayPrice
            }
            return fallbackPrice(plan)
        }
    }

    private func planPriceSuffix(_ plan: EbbPlusPlanID) -> String {
        switch plan {
        case .annual: "/ month"
        case .monthly: "/ month"
        case .lifetime: "one-time"
        }
    }

    private func fallbackPrice(_ plan: EbbPlusPlanID) -> String {
        switch plan {
        case .annual: "€2.08"
        case .monthly: "€3.99"
        case .lifetime: "€59.99"
        }
    }

    private var purchaseButton: some View {
        VStack(spacing: 9) {
            if entitlements.isLoadingProducts {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading plans…")
                        .font(.footnote)
                        .foregroundStyle(theme.muted)
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                Task { await purchaseSelectedPlan() }
            } label: {
                Group {
                    if entitlements.isPurchasing {
                        ProgressView()
                            .tint(theme.onPain)
                    } else {
                        Text(purchaseButtonTitle)
                            .font(.body.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.onPain)
            .background(theme.pain, in: RoundedRectangle(cornerRadius: 16))
            .disabled(entitlements.isPurchasing || entitlements.isLoadingProducts)

            if let purchaseErrorMessage {
                Text(purchaseErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.pain)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else if entitlements.productsDidLoad,
                      !entitlements.hasLoadedProducts,
                      let lastError = entitlements.lastErrorMessage {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(theme.pain)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else if let lastError = entitlements.lastErrorMessage,
                      purchaseErrorMessage == nil {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(theme.pain)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 16)
    }

    private var purchaseButtonTitle: String {
        selectedPlan == .annual ? "Start free trial" : "Continue with \(selectedPlan.title.lowercased())"
    }

    private var footnote: some View {
        Text(selectedPlan == .annual ? "Then €24.99/year · cancel anytime" : "Cancel anytime in Settings")
            .font(.caption)
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 9)
    }

    private var links: some View {
        HStack(spacing: 16) {
            Button("Restore") {
                Task { await restore() }
            }
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Link("Privacy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
        }
        .font(.caption)
        .foregroundStyle(theme.muted)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func product(for plan: EbbPlusPlanID) -> Product? {
        switch plan {
        case .annual: entitlements.annualProduct
        case .monthly: entitlements.monthlyProduct
        case .lifetime: entitlements.lifetimeProduct
        }
    }

    private func purchaseSelectedPlan() async {
        purchaseErrorMessage = nil

        if product(for: selectedPlan) == nil {
            await entitlements.loadProducts()
        }

        guard let product = product(for: selectedPlan) else {
            purchaseErrorMessage = entitlements.lastErrorMessage
                ?? StoreKitSetupHint.purchaseUnavailableMessage
            return
        }

        do {
            try await entitlements.purchase(product)
            if entitlements.isEbbPlus {
                dismiss()
            }
        } catch EntitlementsError.userCancelled {
            return
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        purchaseErrorMessage = nil
        do {
            try await entitlements.restorePurchases()
            if entitlements.isEbbPlus {
                dismiss()
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EbbPlusPlansSheet()
        .environment(\.theme, .plumEmber)
        .environment(EntitlementsService(previewIsEbbPlus: false, listenForUpdates: false))
}
