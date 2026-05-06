import SwiftUI

struct StatsView: View {
    @Bindable var stats: BreakStatistics
    @State private var selectedRange: Range = .today

    enum Range: String, CaseIterable, Identifiable {
        case today, week, month
        var id: Self { self }
        var label: String {
            switch self {
            case .today: return "Today"
            case .week:  return "Week"
            case .month: return "Month"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 14)
            cardGrid
                .padding(.bottom, 12)
            rhythmCard
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 18, leading: 22, bottom: 22, trailing: 22))
        .frame(minWidth: 720, minHeight: 560)
        .background(Color.laPaper)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(LAFont.displayM)
                    .foregroundStyle(Color.laInk)
                Text(headerDateLine).laCaps()
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(Range.allCases) { range in
                    Button(range.label) {
                        if range == .today { selectedRange = range }
                        // Week / Month show no data this pass — buttons exist but inert.
                    }
                    .buttonStyle(selectedRange == range ? .paperPrimary : .paper)
                    .disabled(range != .today)
                    .opacity(range != .today ? 0.5 : 1.0)
                }
            }
        }
    }

    private var headerDateLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE · MMM d · 'so far'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    // MARK: - Card grid

    private var cardGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        return LazyVGrid(columns: columns, spacing: 10) {
            statCard(
                key: "Breaks taken",
                value: "\(stats.breaksTaken)",
                subtitle: "of \(stats.breaksDue) due",
                big: true
            )
            statCard(
                key: "Screen time",
                value: formatHM(stats.screenTimeSeconds),
                subtitle: "today",
                big: true
            )
            statCard(
                key: "Longest streak",
                value: "—",
                subtitle: "back-to-back",
                big: false
            )
            statCard(
                key: "Skipped",
                value: "\(stats.breaksSkipped)",
                subtitle: skipRateSubtitle,
                big: false
            )
            statCard(
                key: "Snoozed",
                value: "\(stats.breaksSnoozed)",
                subtitle: "",
                big: false
            )
            statCard(
                key: "Smart-paused",
                value: formatHM(stats.smartPausedSeconds),
                subtitle: "",
                big: false
            )
        }
    }

    @ViewBuilder
    private func statCard(key: String, value: String, subtitle: String, big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key).laCaps()
            Text(value)
                .font(big ? LAFont.monoXL : LAFont.monoL)
                .foregroundStyle(Color.laInk)
                .padding(.top, 2)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(LAFont.bodyXS)
                    .foregroundStyle(Color.laInk2)
                    .padding(.top, 2)
            }
        }
        .padding(LASpacing.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LARadius.lg, style: .continuous)
                .fill(Color.laPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LARadius.lg, style: .continuous)
                .stroke(Color.laInk4, lineWidth: 1)
        )
        .gridCellColumns(big ? 2 : 1)
    }

    // MARK: - Rhythm card (24h bar chart)

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's rhythm")
                    .font(LAFont.bodyL.weight(.semibold))
                    .foregroundStyle(Color.laInk)
                Spacer()
                Text("Screen time per hour").laCaps()
            }
            barChart
                .frame(height: 90)
            // Hour labels
            HStack {
                Text("12a").font(LAFont.monoS).foregroundStyle(Color.laInk3)
                Spacer()
                Text("6a").font(LAFont.monoS).foregroundStyle(Color.laInk3)
                Spacer()
                Text("noon").font(LAFont.monoS).foregroundStyle(Color.laInk3)
                Spacer()
                Text("6p").font(LAFont.monoS).foregroundStyle(Color.laInk3)
                Spacer()
                Text("12a").font(LAFont.monoS).foregroundStyle(Color.laInk3)
            }
            .padding(.top, 4)
        }
        .padding(LASpacing.sp4)
        .background(
            RoundedRectangle(cornerRadius: LARadius.lg, style: .continuous)
                .fill(Color.laPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LARadius.lg, style: .continuous)
                .stroke(Color.laInk4, lineWidth: 1)
        )
    }

    private var barChart: some View {
        let buckets = stats.hourlyScreenTime
        let maxValue = max(1, buckets.max() ?? 1)
        let currentHour = Calendar.current.component(.hour, from: Date())
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<24, id: \.self) { i in
                let value = buckets[i]
                let fraction = value / maxValue
                let isCurrent = i == currentHour
                ZStack(alignment: .top) {
                    if isCurrent {
                        // "NOW" label above the bar
                        Text("Now")
                            .laCaps()
                            .foregroundStyle(Color.laAccent)
                            .fixedSize()
                            .offset(y: -16)
                    }
                    Rectangle()
                        .fill(barColor(value: value, max: maxValue, isCurrent: isCurrent))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .frame(height: max(value > 0 ? 2 : 0, 90 * fraction))
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barColor(value: TimeInterval, max: TimeInterval, isCurrent: Bool) -> Color {
        guard value > 0 else { return .clear }
        if isCurrent { return .laAccent }
        let fraction = value / max
        if fraction > 0.7 { return .laInk }
        if fraction > 0.4 { return .laInk2 }
        return .laInk4
    }

    // MARK: - Helpers

    /// Format a `TimeInterval` (seconds) as `Xh Ym`. If under 1 hour, returns `Xm`.
    private func formatHM(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }	

    private var skipRateSubtitle: String {
        guard stats.breaksDue > 0 else { return "" }
        let pct = Int(round(Double(stats.breaksSkipped) / Double(stats.breaksDue) * 100))
        return "\(pct)% skip rate"
    }
}
