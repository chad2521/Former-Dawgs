import WidgetKit
import SwiftUI
import ActivityKit

struct TodaysDawgsEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaysDawgsSnapshot
}

struct TodaysDawgsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaysDawgsEntry {
        TodaysDawgsEntry(
            date: Date(),
            snapshot: TodaysDawgsSnapshot(
                generatedAt: Date(),
                players: [
                    TodaysDawgSnapshotPlayer(
                        id: 1,
                        name: "Jake Mangum",
                        role: "OF",
                        teamName: "Pittsburgh Pirates",
                        gameHeadline: "vs Braves",
                        statusText: "6:40 PM",
                        isLive: false
                    )
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaysDawgsEntry) -> Void) {
        completion(TodaysDawgsEntry(date: Date(), snapshot: PlayerRuntimeStore.loadTodaysDawgsSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysDawgsEntry>) -> Void) {
        let now = Date()
        let entry = TodaysDawgsEntry(date: now, snapshot: PlayerRuntimeStore.loadTodaysDawgsSnapshot())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60 * 20))))
    }
}

extension TodaysDawgSnapshotPlayer {
    init(id: Int, name: String, role: String, teamName: String, gameHeadline: String, statusText: String, isLive: Bool) {
        self.id = id
        self.name = name
        self.role = role
        self.teamName = teamName
        self.gameHeadline = gameHeadline
        self.statusText = statusText
        self.isLive = isLive
    }
}

struct TodaysDawgsWidgetEntryView: View {
    let entry: TodaysDawgsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        case .systemMedium:
            mediumBody
        case .systemLarge, .systemExtraLarge:
            largeBody
        case .accessoryInline:
            Text(entry.snapshot.headline)
        case .accessoryRectangular:
            accessoryRectangularBody
        case .accessoryCircular:
            ZStack {
                Circle().fill(Color(red: 0.40, green: 0.10, blue: 0.16))
                Text("\(entry.snapshot.players.count)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
        @unknown default:
            mediumBody
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "baseball.diamond.bases")
            Text("Today's Dawgs")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
            if entry.snapshot.players.contains(where: \.isLive) {
                Text("Live")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.28))
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(.white)
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text(entry.snapshot.headline)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
            if let first = entry.snapshot.players.first {
                Text(first.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Text(entry.snapshot.headline)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("Open Former Dawgs for the live board")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(entry.snapshot.players.prefix(3)) { player in
                    playerRow(player)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(entry.snapshot.headline)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.snapshot.players.prefix(6)) { player in
                    playerRow(player)
                }
                if entry.snapshot.players.isEmpty {
                    Text("Refresh the app home tab to publish today's schedule here.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today's Dawgs")
                .font(.caption2.weight(.bold))
            Text(entry.snapshot.headline)
                .font(.caption2)
                .lineLimit(2)
        }
        .containerBackground(.clear, for: .widget)
    }

    private func playerRow(_ player: TodaysDawgSnapshotPlayer) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(player.isLive ? Color.green : Color.white.opacity(0.56))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(player.gameHeadline) • \(player.statusText)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }
        }
    }

    private var maroonGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.40, green: 0.10, blue: 0.16), Color(red: 0.10, green: 0.10, blue: 0.11)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct TodaysDawgsWidget: Widget {
    let kind: String = "FormerDawgsTodaysDawgsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysDawgsProvider()) { entry in
            TodaysDawgsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Dawgs")
        .description("See which former Mississippi State players are active today.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryRectangular, .accessoryCircular
        ])
    }
}

struct FavoritePlayerEntry: TimelineEntry {
    let date: Date
    let snapshot: FavoritePlayerWidgetSnapshot
}

struct FavoritePlayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritePlayerEntry {
        FavoritePlayerEntry(
            date: Date(),
            snapshot: FavoritePlayerWidgetSnapshot(
                generatedAt: Date(),
                player: FavoritePlayerWidgetPlayer(
                    id: 1,
                    name: "Jake Mangum",
                    role: "OF",
                    teamLine: "OF | Pittsburgh Pirates",
                    levelLabel: "MLB",
                    primaryLine: "vs Braves",
                    detailLine: "6:40 PM",
                    isActiveToday: true
                )
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritePlayerEntry) -> Void) {
        completion(FavoritePlayerEntry(date: Date(), snapshot: PlayerRuntimeStore.loadFavoritePlayerSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritePlayerEntry>) -> Void) {
        let now = Date()
        let entry = FavoritePlayerEntry(date: now, snapshot: PlayerRuntimeStore.loadFavoritePlayerSnapshot())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60 * 30))))
    }
}

struct FavoritePlayerWidgetEntryView: View {
    let entry: FavoritePlayerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        case .systemMedium:
            mediumBody
        case .systemLarge, .systemExtraLarge:
            largeBody
        case .accessoryInline:
            Text(entry.snapshot.player?.name ?? "Pick a favorite Dawg")
        case .accessoryRectangular:
            accessoryRectangularBody
        case .accessoryCircular:
            Image(systemName: entry.snapshot.player?.isActiveToday == true ? "star.circle.fill" : "star.fill")
        @unknown default:
            mediumBody
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
            Text("Favorite Dawg")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
            if entry.snapshot.player?.isActiveToday == true {
                Text("Today")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.28))
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(.white)
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let player = entry.snapshot.player {
                Text(player.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(player.primaryLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
                Spacer(minLength: 0)
                Text(player.levelLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                emptyFavoriteText
            }
        }
        .padding(12)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                header
                if let player = entry.snapshot.player {
                    Text(player.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(player.teamLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(1)
                } else {
                    emptyFavoriteText
                }
            }

            Spacer(minLength: 0)

            if let player = entry.snapshot.player {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.primaryLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                    Text(player.detailLine)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let player = entry.snapshot.player {
                Text(player.name)
                    .font(.title.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(player.teamLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                Text(player.primaryLine)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(4)
                Text(player.detailLine)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
                Spacer(minLength: 0)
                Text(player.levelLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.74))
            } else {
                emptyFavoriteText
            }
        }
        .padding(14)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Favorite Dawg")
                .font(.caption2.weight(.bold))
            Text(entry.snapshot.player?.primaryLine ?? "Pick a favorite in the app")
                .font(.caption2)
                .lineLimit(2)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var emptyFavoriteText: some View {
        Text("Pick a favorite player in Former Dawgs.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(4)
    }

    private var maroonGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.40, green: 0.10, blue: 0.16), Color(red: 0.10, green: 0.10, blue: 0.11)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FavoritePlayerWidget: Widget {
    let kind: String = "FormerDawgsFavoritePlayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritePlayerProvider()) { entry in
            FavoritePlayerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Favorite Dawg")
        .description("Keep your top tracked former Mississippi State player on the Home Screen.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryRectangular, .accessoryCircular
        ])
    }
}

struct NewsEntry: TimelineEntry {
    let date: Date
    let snapshot: NewsWidgetSnapshot
}

struct NewsProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewsEntry {
        NewsEntry(
            date: Date(),
            snapshot: NewsWidgetSnapshot(
                generatedAt: Date(),
                stories: [
                    NewsWidgetStory(
                        id: "sample",
                        playerName: "Konnor Pilkington",
                        title: "Former Dawg earns a promotion",
                        source: "MiLB",
                        publishedText: "Today",
                        isPromotion: true
                    )
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NewsEntry) -> Void) {
        completion(NewsEntry(date: Date(), snapshot: PlayerRuntimeStore.loadNewsSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewsEntry>) -> Void) {
        let now = Date()
        let entry = NewsEntry(date: now, snapshot: PlayerRuntimeStore.loadNewsSnapshot())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60 * 45))))
    }
}

struct NewsWidgetEntryView: View {
    let entry: NewsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        case .systemMedium:
            mediumBody
        case .systemLarge, .systemExtraLarge:
            largeBody
        case .accessoryInline:
            Text(entry.snapshot.headline)
        case .accessoryRectangular:
            accessoryRectangularBody
        case .accessoryCircular:
            Image(systemName: entry.snapshot.stories.first?.isPromotion == true ? "arrow.up.circle.fill" : "newspaper.fill")
        @unknown default:
            mediumBody
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "newspaper.fill")
            Text("Dawgs News")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
            if entry.snapshot.stories.first?.isPromotion == true {
                Text("Promotion")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(.white)
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let story = entry.snapshot.stories.first {
                Text(story.playerName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Text(story.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                Text([story.source, story.publishedText].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            } else {
                emptyNewsText
            }
        }
        .padding(12)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Text(entry.snapshot.headline)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(entry.snapshot.stories.prefix(3)) { story in
                    storyRow(story)
                }
                if entry.snapshot.stories.isEmpty {
                    emptyNewsText
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if entry.snapshot.stories.isEmpty {
                emptyNewsText
            } else {
                ForEach(entry.snapshot.stories.prefix(5)) { story in
                    storyRow(story)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Dawgs News")
                .font(.caption2.weight(.bold))
            Text(entry.snapshot.headline)
                .font(.caption2)
                .lineLimit(2)
        }
        .containerBackground(.clear, for: .widget)
    }

    private func storyRow(_ story: NewsWidgetStory) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: story.isPromotion ? "arrow.up.circle.fill" : "doc.text.fill")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
            VStack(alignment: .leading, spacing: 1) {
                Text(story.playerName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(story.title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(2)
            }
        }
    }

    private var emptyNewsText: some View {
        Text("Refresh the app home tab to publish recent headlines here.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(4)
    }

    private var maroonGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.40, green: 0.10, blue: 0.16), Color(red: 0.10, green: 0.10, blue: 0.11)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct NewsWidget: Widget {
    let kind: String = "FormerDawgsNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewsProvider()) { entry in
            NewsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dawgs News")
        .description("Track recent promotions, headlines, and transaction notes.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryRectangular, .accessoryCircular
        ])
    }
}

struct TriviaEntry: TimelineEntry {
    let date: Date
    let question: TriviaQuestion
    let choices: [String]
}

struct TriviaProvider: TimelineProvider {
    func placeholder(in context: Context) -> TriviaEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (TriviaEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TriviaEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        var entries: [TriviaEntry] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            entries.append(makeEntry(for: date))
        }

        let nextRefresh = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(60 * 60 * 12)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    private func makeEntry(for date: Date) -> TriviaEntry {
        let question = TriviaCatalog.dailyQuestion(for: date)
        let instance = TriviaCatalog.instance(for: question)
        return TriviaEntry(date: date, question: question, choices: instance.choices)
    }
}

struct FormerDawgsWidgetEntryView: View {
    var entry: TriviaProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        case .systemMedium:
            mediumBody
        case .systemLarge, .systemExtraLarge:
            largeBody
        case .accessoryRectangular:
            accessoryRectangularBody
        case .accessoryInline:
            Text(entry.question.prompt)
        case .accessoryCircular:
            Image(systemName: "questionmark.circle.fill")
        @unknown default:
            mediumBody
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "questionmark.bubble.fill")
            Text("Bulldog Trivia")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer()
            Text(entry.question.category)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
        }
        .foregroundStyle(.white)
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text(entry.question.prompt)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(6)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(10)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text(entry.question.prompt)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(4)
            Spacer(minLength: 0)
            Text("Tap to answer in the app")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(12)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(entry.question.prompt)
                .font(.headline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.choices.prefix(4), id: \.self) { choice in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "circle")
                            .font(.caption2)
                        Text(choice.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
                            .font(.caption.weight(.medium))
                            .lineLimit(2)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            Spacer(minLength: 0)
            Text("Tap to answer in the app")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(14)
        .containerBackground(maroonGradient, for: .widget)
    }

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Bulldog Trivia")
                .font(.caption2.weight(.bold))
            Text(entry.question.prompt)
                .font(.caption2)
                .lineLimit(3)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var maroonGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.40, green: 0.10, blue: 0.16), Color(red: 0.10, green: 0.10, blue: 0.11)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FormerDawgsWidget: Widget {
    let kind: String = "FormerDawgsTriviaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TriviaProvider()) { entry in
            FormerDawgsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Bulldog Daily Trivia")
        .description("A fresh Mississippi State baseball question every day.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryRectangular, .accessoryCircular
        ])
    }
}

struct DawgLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DawgLiveActivityAttributes.self) { context in
            DawgLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.07, green: 0.07, blue: 0.08))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.playerName, systemImage: "baseball.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.scoreText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.headlineText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if let lineText = context.state.lineText {
                            Text(lineText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "baseball.fill")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(context.state.scoreText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "baseball.fill")
                    .foregroundStyle(.white)
            }
            .keylineTint(Color(red: 0.40, green: 0.10, blue: 0.16))
        }
    }
}

struct DawgLiveActivityLockScreenView: View {
    let context: ActivityViewContext<DawgLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(context.attributes.playerName, systemImage: "baseball.fill")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                Spacer()
                Text(context.state.statusLabel)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
            }
            .foregroundStyle(.white)

            HStack(alignment: .firstTextBaseline) {
                Text(context.state.headlineText)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(context.state.scoreText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }

            if let inningText = context.state.inningText {
                Text(inningText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            if let lineText = context.state.lineText {
                Text(lineText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(14)
    }
}
