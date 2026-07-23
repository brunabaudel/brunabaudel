import Foundation
import UIKit

enum DoctorReportPDFRenderer {
    enum Error: Swift.Error, LocalizedError {
        case emptyReport

        var errorDescription: String? {
            switch self {
            case .emptyReport:
                "Add at least one migraine log before exporting."
            }
        }
    }

    private static let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    private static let margin: CGFloat = 48
    private static let contentWidth: CGFloat = pageRect.width - margin * 2

    static func makePDFData(report: DoctorReportEngine.Report) throws -> Data {
        guard report.hasEnoughData else { throw Error.emptyReport }

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            var cursorY = margin

            func beginPageIfNeeded(requiredHeight: CGFloat) {
                if cursorY + requiredHeight > pageRect.height - margin {
                    context.beginPage()
                    cursorY = margin
                }
            }

            context.beginPage()

            cursorY = drawHeader(report: report, at: cursorY)
            cursorY += 18
            cursorY = drawSummary(report: report, at: cursorY)
            cursorY += 20
            cursorY = drawStatsRow(report: report, at: cursorY)
            cursorY += 24
            cursorY = drawPhaseSection(report: report, at: cursorY, beginPageIfNeeded: beginPageIfNeeded)
            cursorY += 20
            cursorY = drawMetaSection(report: report, at: cursorY, beginPageIfNeeded: beginPageIfNeeded)
            cursorY += 22
            cursorY = drawTimelineSection(
                report: report,
                at: cursorY,
                context: context,
                beginPageIfNeeded: beginPageIfNeeded
            )
            cursorY += 24
            drawFooter(report: report, at: cursorY, beginPageIfNeeded: beginPageIfNeeded)
        }
    }

    static func makeTemporaryPDFFile(report: DoctorReportEngine.Report) throws -> URL {
        let data = try makePDFData(report: report)
        let stamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ebb-doctor-report-\(stamp).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Drawing

    private static func drawHeader(report: DoctorReportEngine.Report, at y: CGFloat) -> CGFloat {
        var cursor = y
        cursor = drawText(
            "Ebb · Migraine summary",
            at: cursor,
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: UIColor(white: 0.45, alpha: 1)
        )
        cursor += 6
        cursor = drawText(
            report.dateRangeLabel,
            at: cursor,
            font: .systemFont(ofSize: 22, weight: .bold),
            color: .black
        )
        return cursor
    }

    private static func drawSummary(report: DoctorReportEngine.Report, at y: CGFloat) -> CGFloat {
        drawParagraph(
            report.summaryLine,
            at: y,
            font: .systemFont(ofSize: 13, weight: .regular),
            color: UIColor(white: 0.15, alpha: 1)
        )
    }

    private static func drawStatsRow(report: DoctorReportEngine.Report, at y: CGFloat) -> CGFloat {
        let columns: [(String, String)] = [
            (
                DoctorReportEngine.formattedAverage(report.avgMigrainesPerCycle),
                "AVG / CYCLE"
            ),
            (
                DoctorReportEngine.formattedAverage(report.avgSeverity),
                "AVG SEVERITY"
            ),
            (
                report.lutealPercentage.map { "\($0)%" } ?? "—",
                "IN LUTEAL"
            ),
        ]

        let columnWidth = contentWidth / CGFloat(columns.count)
        var maxBottom = y

        for (index, column) in columns.enumerated() {
            let x = margin + columnWidth * CGFloat(index)
            let numberRect = CGRect(x: x, y: y, width: columnWidth - 8, height: 28)
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: index == 2 ? accentColor : UIColor.black,
            ]
            (column.0 as NSString).draw(in: numberRect, withAttributes: numberAttributes)

            let labelRect = CGRect(x: x, y: y + 30, width: columnWidth - 8, height: 14)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: UIColor(white: 0.5, alpha: 1),
                .kern: 0.6,
            ]
            (column.1 as NSString).draw(in: labelRect, withAttributes: labelAttributes)
            maxBottom = max(maxBottom, y + 44)
        }

        return maxBottom
    }

    private static func drawPhaseSection(
        report: DoctorReportEngine.Report,
        at y: CGFloat,
        beginPageIfNeeded: (CGFloat) -> Void
    ) -> CGFloat {
        beginPageIfNeeded(120)
        var cursor = drawSectionTitle("Migraines by cycle phase", at: y)
        cursor += 12

        guard !report.phaseCounts.isEmpty else {
            return drawParagraph("No cycle phase data available.", at: cursor, font: .systemFont(ofSize: 12))
        }

        for phaseCount in report.phaseCounts {
            beginPageIfNeeded(24)
            cursor = drawPhaseBar(phaseCount, at: cursor)
            cursor += 8
        }
        return cursor
    }

    private static func drawPhaseBar(_ phaseCount: DoctorReportEngine.PhaseCount, at y: CGFloat) -> CGFloat {
        let labelWidth: CGFloat = 88
        let countWidth: CGFloat = 24
        let barX = margin + labelWidth + 8
        let barWidth = contentWidth - labelWidth - countWidth - 8

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor(white: 0.2, alpha: 1),
        ]
        (phaseCount.phase.displayName as NSString).draw(
            in: CGRect(x: margin, y: y, width: labelWidth, height: 16),
            withAttributes: labelAttributes
        )

        let trackRect = CGRect(x: barX, y: y + 4, width: barWidth, height: 8)
        UIColor(white: 0.9, alpha: 1).setFill()
        UIBezierPath(roundedRect: trackRect, cornerRadius: 4).fill()

        let fillWidth = max(barWidth * phaseCount.fraction, phaseCount.count > 0 ? 8 : 0)
        let fillRect = CGRect(x: barX, y: y + 4, width: fillWidth, height: 8)
        accentColor.setFill()
        UIBezierPath(roundedRect: fillRect, cornerRadius: 4).fill()

        let countAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor(white: 0.45, alpha: 1),
        ]
        ("\(phaseCount.count)" as NSString).draw(
            in: CGRect(x: margin + contentWidth - countWidth, y: y, width: countWidth, height: 16),
            withAttributes: countAttributes
        )

        return y + 18
    }

    private static func drawMetaSection(
        report: DoctorReportEngine.Report,
        at y: CGFloat,
        beginPageIfNeeded: (CGFloat) -> Void
    ) -> CGFloat {
        beginPageIfNeeded(100)
        var cursor = y
        let lines = [
            ("Triggers", DoctorReportEngine.triggersLine(from: report.topTriggers)),
            ("Relief tried", DoctorReportEngine.reliefLine(from: report.reliefSummaries)),
            ("Aura", report.auraSummary),
            ("Cycle", report.cycleSummary),
        ]

        for (title, value) in lines {
            beginPageIfNeeded(28)
            cursor = drawMetaLine(title: title, value: value, at: cursor)
            cursor += 8
        }
        return cursor
    }

    private static func drawMetaLine(title: String, value: String, at y: CGFloat) -> CGFloat {
        let attributed = NSMutableAttributedString(
            string: "\(title) · ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
        )
        attributed.append(NSAttributedString(
            string: value,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor(white: 0.25, alpha: 1),
            ]
        ))

        let bounding = attributed.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        attributed.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: ceil(bounding.height)))
        return y + ceil(bounding.height)
    }

    private static func drawTimelineSection(
        report: DoctorReportEngine.Report,
        at y: CGFloat,
        context: UIGraphicsPDFRendererContext,
        beginPageIfNeeded: (CGFloat) -> Void
    ) -> CGFloat {
        beginPageIfNeeded(80)
        var cursor = drawSectionTitle("Cycle timeline", at: y)
        cursor += 10

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        for event in report.timelineEvents {
            beginPageIfNeeded(20)
            let phaseLabel = event.phase?.displayName ?? "—"
            let dayLabel = event.cycleDay.map { "day \($0)" } ?? "—"
            let severityLabel = event.severity.map(String.init) ?? "—"
            let line = "\(dateFormatter.string(from: event.date)) · \(phaseLabel) · \(dayLabel) · severity \(severityLabel)"
            cursor = drawText(
                line,
                at: cursor,
                font: .systemFont(ofSize: 10.5, weight: .regular),
                color: UIColor(white: 0.25, alpha: 1)
            )
            cursor += 4
        }

        return cursor
    }

    private static func drawFooter(
        report: DoctorReportEngine.Report,
        at y: CGFloat,
        beginPageIfNeeded: (CGFloat) -> Void
    ) {
        beginPageIfNeeded(70)
        var cursor = y
        cursor = drawParagraph(
            MedicalDisclaimer.shortLine,
            at: cursor,
            font: .systemFont(ofSize: 9.5, weight: .regular),
            color: UIColor(white: 0.45, alpha: 1)
        )
        cursor += 10
        let generated = DateFormatter.localizedString(from: .now, dateStyle: .medium, timeStyle: .short)
        let footnote = "Generated on-device · \(report.cycleCount) cycles · \(report.migraineCount) migraines · \(generated)"
        _ = drawText(
            footnote,
            at: cursor,
            font: .systemFont(ofSize: 9, weight: .regular),
            color: UIColor(white: 0.55, alpha: 1)
        )
    }

    private static func drawSectionTitle(_ title: String, at y: CGFloat) -> CGFloat {
        drawText(
            title,
            at: y,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: UIColor.black
        )
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        at y: CGFloat,
        font: UIFont,
        color: UIColor
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        (text as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: ceil(bounding.height)),
            withAttributes: attributes
        )
        return y + ceil(bounding.height)
    }

    @discardableResult
    private static func drawParagraph(
        _ text: String,
        at y: CGFloat,
        font: UIFont,
        color: UIColor = UIColor(white: 0.2, alpha: 1)
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        (text as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: ceil(bounding.height)),
            withAttributes: attributes
        )
        return y + ceil(bounding.height)
    }

    private static var accentColor: UIColor {
        UIColor(red: 0.72, green: 0.36, blue: 0.48, alpha: 1)
    }
}
