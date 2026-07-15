import SwiftUI

/// The 11 semantic color roles every screen draws from. Color encodes meaning
/// app-wide: the warm accent (`pain`) always marks pain/symptoms, the cool
/// accent (`cycle`) always marks cycle/hormones — in every theme.
///
/// Screens read the active theme from the environment (`\.theme`) and never
/// hardcode a color. Hex values live only here, mirrored from
/// `docs/symptom-tracker-palettes.html`.
struct Theme: Equatable, Sendable, Identifiable {
    let id: String
    let name: String

    /// Screen background — low-luminance, dim-first.
    let base: Color
    /// Cards and elevated containers.
    let surface: Color
    /// Hairlines and control borders.
    let line: Color
    /// Primary text — soft off-white, never pure white.
    let text: Color
    /// Secondary text.
    let muted: Color
    /// Warm accent: pain / symptom.
    let pain: Color
    /// Dim fill behind pain-accented elements.
    let painDim: Color
    /// Text/icons placed on a `pain` background.
    let onPain: Color
    /// Cool accent: cycle / hormone.
    let cycle: Color
    /// Dim fill behind cycle-accented elements.
    let cycleDim: Color
    /// Confirmation / success.
    let ok: Color
}

extension Theme {
    /// The free default theme (business plan: never gated).
    static let plumEmber = Theme(
        id: "plum-ember",
        name: "Plum & Ember",
        base: Color(hex: 0x1A1620),
        surface: Color(hex: 0x241E2C),
        line: Color(hex: 0x3A3242),
        text: Color(hex: 0xEDE6F0),
        muted: Color(hex: 0xA99FB0),
        pain: Color(hex: 0xE89B8B),
        painDim: Color(hex: 0x2E2229),
        onPain: Color(hex: 0x2A1714),
        cycle: Color(hex: 0x9D8FC7),
        cycleDim: Color(hex: 0x241F33),
        ok: Color(hex: 0x8FB1A0)
    )

    static let tidewater = Theme(
        id: "tidewater",
        name: "Tidewater",
        base: Color(hex: 0x0F1E1C),
        surface: Color(hex: 0x173029),
        line: Color(hex: 0x294B42),
        text: Color(hex: 0xE4EFEA),
        muted: Color(hex: 0x92AAA1),
        pain: Color(hex: 0xE8B07A),
        painDim: Color(hex: 0x2E2415),
        onPain: Color(hex: 0x2E2113),
        cycle: Color(hex: 0x82B6C9),
        cycleDim: Color(hex: 0x16302F),
        ok: Color(hex: 0x8FB1A0)
    )

    static let nocturne = Theme(
        id: "nocturne",
        name: "Nocturne",
        base: Color(hex: 0x15131F),
        surface: Color(hex: 0x201D30),
        line: Color(hex: 0x332E47),
        text: Color(hex: 0xE9E6F2),
        muted: Color(hex: 0xA39EB8),
        pain: Color(hex: 0xE29AAD),
        painDim: Color(hex: 0x321F27),
        onPain: Color(hex: 0x2C1820),
        cycle: Color(hex: 0x8593D4),
        cycleDim: Color(hex: 0x1F2440),
        ok: Color(hex: 0x93B7A6)
    )

    static let ashSage = Theme(
        id: "ash-sage",
        name: "Ash & Sage",
        base: Color(hex: 0x16151A),
        surface: Color(hex: 0x201F26),
        line: Color(hex: 0x322F39),
        text: Color(hex: 0xEAE8EE),
        muted: Color(hex: 0x9E9AA6),
        pain: Color(hex: 0xD98A86),
        painDim: Color(hex: 0x321E1D),
        onPain: Color(hex: 0x2C1817),
        cycle: Color(hex: 0x9DB89E),
        cycleDim: Color(hex: 0x1E2A20),
        ok: Color(hex: 0x88B0A8)
    )

    /// The one light option.
    static let oatRose = Theme(
        id: "oat-rose",
        name: "Oat & Rose",
        base: Color(hex: 0xEFE8DD),
        surface: Color(hex: 0xF8F3EC),
        line: Color(hex: 0xDCD2C4),
        text: Color(hex: 0x3B332C),
        muted: Color(hex: 0x8A8074),
        pain: Color(hex: 0xC2607A),
        painDim: Color(hex: 0xF0DCE2),
        onPain: Color(hex: 0xFBF6F2),
        cycle: Color(hex: 0x5E8C84),
        cycleDim: Color(hex: 0xDCE7E3),
        ok: Color(hex: 0x6E9E8E)
    )

    static let mossClay = Theme(
        id: "moss-clay",
        name: "Moss & Clay",
        base: Color(hex: 0x181511),
        surface: Color(hex: 0x231F19),
        line: Color(hex: 0x38322A),
        text: Color(hex: 0xECE5DA),
        muted: Color(hex: 0xA79D8D),
        pain: Color(hex: 0xDB8662),
        painDim: Color(hex: 0x321D14),
        onPain: Color(hex: 0x2C1812),
        cycle: Color(hex: 0x9DAE79),
        cycleDim: Color(hex: 0x232A18),
        ok: Color(hex: 0x8FB39A)
    )

    static let all: [Theme] = [.plumEmber, .tidewater, .nocturne, .ashSage, .oatRose, .mossClay]
}

// MARK: - Environment injection

extension EnvironmentValues {
    @Entry var theme: Theme = .plumEmber
}

// MARK: - Hex construction (theme layer only)

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
