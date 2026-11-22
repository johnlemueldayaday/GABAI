import WidgetKit
import SwiftUI

// MARK: - Helpers

func formatPeso(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    let formatted = f.string(from: NSNumber(value: abs(value))) ?? "0.00"
    return value < 0 ? "-₱" + formatted : "₱" + formatted
}

func formatPesoWhole(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 0
    return "₱" + (f.string(from: NSNumber(value: value)) ?? "0")
}

@ViewBuilder
func widgetBackground<Content: View>(_ content: Content) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
        content.containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    } else {
        content.background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Timeline

struct Provider: TimelineProvider {
    let userDefaults = UserDefaults(suiteName: "group.com.johnlemueldayaday.gabay")

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), safeToSpend: 4740.0, weekSpent: 100, weekBudget: 5000.0, daysLeft: 13)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), safeToSpend: 4740.0, weekSpent: 100, weekBudget: 5000.0, daysLeft: 13)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let safeToSpend = userDefaults?.double(forKey: "safe_to_spend") ?? 0.0
        let weekSpent = userDefaults?.double(forKey: "week_spent") ?? 0.0
        let weekBudget = userDefaults?.double(forKey: "week_budget") ?? 1.0
        let daysLeft = userDefaults?.integer(forKey: "days_left") ?? 0

        let entry = SimpleEntry(
            date: Date(),
            safeToSpend: safeToSpend,
            weekSpent: weekSpent,
            weekBudget: weekBudget,
            daysLeft: daysLeft
        )

        // Ask iOS to refresh at the start of the next day.
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let safeToSpend: Double
    let weekSpent: Double
    let weekBudget: Double
    let daysLeft: Int
}

// MARK: - Safe to Spend views

struct SafeToSpendWidgetView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                Label(entry.safeToSpend <= 0 ? "Cut cost" : "Safe to spend",
                      systemImage: entry.safeToSpend <= 0 ? "arrow.down.right" : "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.safeToSpend <= 0 ? .red : .primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(formatPeso(entry.safeToSpend))
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                ProgressView(value: entry.weekBudget > 0 ? min(entry.weekSpent / entry.weekBudget, 1.0) : 0)
                    .tint(entry.safeToSpend <= 0 ? .red : .green)
                Text("\(formatPeso(entry.weekSpent)) spent this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        case .systemMedium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.safeToSpend <= 0 ? "Cut cost" : "Safe to spend")
                        .font(.headline)
                        .foregroundStyle(entry.safeToSpend <= 0 ? .red : .primary)
                    Text(formatPeso(entry.safeToSpend))
                        .font(.largeTitle.weight(.bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("Available this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly spending")
                        .font(.caption.weight(.semibold))
                    ProgressView(value: entry.weekBudget > 0 ? min(entry.weekSpent / entry.weekBudget, 1.0) : 0)
                        .tint(entry.safeToSpend <= 0 ? .red : .green)
                    Text("\(formatPesoWhole(entry.weekSpent)) of \(formatPesoWhole(entry.weekBudget))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 130, alignment: .leading)
            }
            .padding()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: entry.safeToSpend <= 0 ? "arrow.down.right" : "checkmark.shield.fill")
                        .font(.system(size: 12))
                    Text(entry.safeToSpend <= 0 ? "Cut cost" : "Safe to spend")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(entry.safeToSpend <= 0 ? .red : .primary)
                }

                Text(formatPeso(entry.safeToSpend))
                    .font(.system(size: 20, weight: .bold))

                Text("\(entry.daysLeft) \(entry.daysLeft == 1 ? "day" : "days") till next payday")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        case .accessoryCircular:
            Gauge(value: entry.weekBudget > 0 ? min(entry.weekSpent / entry.weekBudget, 1.0) : 0) {
                Text("₱")
            } currentValueLabel: {
                Text("\(Int(entry.safeToSpend))")
                    .font(.system(size: 10, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
        default:
            Text("Unsupported")
        }
    }
}

// MARK: - Weekly Budget view

struct WeeklyBudgetWidgetView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                Label("Weekly budget", systemImage: "chart.bar.fill")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(formatPesoWhole(entry.weekSpent))
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                ProgressView(value: entry.weekBudget > 0 ? min(entry.weekSpent / entry.weekBudget, 1.0) : 0)
                    .tint(.orange)
                Text("of \(formatPesoWhole(entry.weekBudget))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        case .systemMedium:
            VStack(alignment: .leading, spacing: 10) {
                Label("Weekly budget", systemImage: "chart.bar.fill")
                    .font(.headline)

                ProgressView(value: entry.weekBudget > 0 ? min(entry.weekSpent / entry.weekBudget, 1.0) : 0)
                    .tint(.orange)

                HStack {
                    Text("\(Int((entry.weekBudget > 0 ? entry.weekSpent / entry.weekBudget : 0) * 100))% used")
                    Spacer()
                    Text("\(formatPesoWhole(entry.weekSpent)) of \(formatPesoWhole(entry.weekBudget))")
                }
                .font(.caption)
                Text("\(formatPeso(entry.weekSpent)) spent this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12))
                    Text("Weekly Budget")
                        .font(.system(size: 12, weight: .semibold))
                }

                let progress = entry.weekBudget > 0 ? entry.weekSpent / entry.weekBudget : 0
                ProgressView(value: min(progress, 1.0))
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.white)

                HStack {
                    Text("\(Int(progress * 100))% used")
                        .font(.system(size: 10))
                    Spacer()
                    Text(formatPesoWhole(entry.weekSpent))
                        .font(.system(size: 10))
                }
                Text("\(formatPeso(entry.weekSpent)) spent this week")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        default:
            Text("Unsupported")
        }
    }
}

// MARK: - Widget bundle

@main
struct GabaiWidgets: WidgetBundle {
    var body: some Widget {
        SafeToSpendWidget()
        WeeklyBudgetWidget()
    }
}

struct SafeToSpendWidget: Widget {
    let kind: String = "SafeToSpendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            widgetBackground(SafeToSpendWidgetView(entry: entry))
        }
        .configurationDisplayName("Safe to Spend")
        .description("Shows your Safe to Spend amount.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct WeeklyBudgetWidget: Widget {
    let kind: String = "WeeklyBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            widgetBackground(WeeklyBudgetWidgetView(entry: entry))
        }
        .configurationDisplayName("Weekly Budget")
        .description("Track your weekly budget progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
