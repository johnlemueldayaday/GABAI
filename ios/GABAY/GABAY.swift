import WidgetKit
import SwiftUI

// MARK: - Helpers

func formatPeso(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    return "₱" + (f.string(from: NSNumber(value: value)) ?? "0.00")
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
        SimpleEntry(date: Date(), safeToSpend: 4740.0, weekSpent: 100, weekBudget: 5000.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), safeToSpend: 4740.0, weekSpent: 100, weekBudget: 5000.0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let safeToSpend = userDefaults?.double(forKey: "safe_to_spend") ?? 0.0
        let weekSpent = userDefaults?.double(forKey: "week_spent") ?? 0.0
        let weekBudget = userDefaults?.double(forKey: "week_budget") ?? 1.0

        let entry = SimpleEntry(
            date: Date(),
            safeToSpend: safeToSpend,
            weekSpent: weekSpent,
            weekBudget: weekBudget
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
}

// MARK: - Safe to Spend views

struct SafeToSpendWidgetView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                Label("Safe to spend", systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(formatPeso(entry.safeToSpend))
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                ProgressView(value: entry.weekBudget > 0 ? min(entry.weekSpent / entry.weekBudget, 1.0) : 0)
                    .tint(.green)
                Text("spent this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        case .systemMedium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Safe to spend")
                        .font(.headline)
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
                        .tint(.green)
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
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12))
                    Text("Safe to spend")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(formatPeso(entry.safeToSpend))
                    .font(.system(size: 20, weight: .bold))

                let progress = entry.weekBudget > 0 ? entry.weekSpent / entry.weekBudget : 0
                ProgressView(value: min(progress, 1.0))
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.white)
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
            }
        default:
            Text("Unsupported")
        }
    }
}

// MARK: - Widget bundle

@main
struct GabayWidgets: WidgetBundle {
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
