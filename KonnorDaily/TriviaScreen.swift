import GameKit
import SwiftUI
import UIKit

enum GameCenterStore {
    static let triviaBestStreakLeaderboardID = "formerdawgs.trivia.best_streak"

    static func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            guard let viewController else { return }
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .rootViewController?
                .present(viewController, animated: true)
        }
    }

    static func reportBestStreak(_ value: Int) {
        submit(score: value, leaderboardIDs: [triviaBestStreakLeaderboardID])
    }

    private static func submit(score: Int, leaderboardIDs: [String]) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: leaderboardIDs
        ) { error in
            if let error {
                print("Game Center score report failed: \(error.localizedDescription)")
            }
        }
    }
}

struct TriviaScreen: View {
    @AppStorage("triviaAnsweredDays", store: SharedAppGroup.defaults) private var answeredDaysStorage = ""
    @AppStorage("triviaCorrectDays", store: SharedAppGroup.defaults) private var correctDaysStorage = ""
    @AppStorage("triviaCurrentStreak", store: SharedAppGroup.defaults) private var currentStreak = 0
    @AppStorage("triviaBestStreak", store: SharedAppGroup.defaults) private var bestStreak = 0
    @AppStorage("triviaLastCorrectDay", store: SharedAppGroup.defaults) private var lastCorrectDay = ""
    @AppStorage("triviaUnlockedBadges", store: SharedAppGroup.defaults) private var unlockedBadgesStorage = ""
    @AppStorage("triviaLastAnswerDay", store: SharedAppGroup.defaults) private var lastAnswerDay = ""
    @AppStorage("triviaLastAnswerQuestionID", store: SharedAppGroup.defaults) private var lastAnswerQuestionID = 0
    @AppStorage("triviaLastAnswerChoice", store: SharedAppGroup.defaults) private var lastAnswerChoice = ""

    @State private var selectedQuestionID = TriviaCatalog.dailyQuestion(for: Date()).id
    @State private var selectedChoice: String?
    @State private var newlyUnlocked: [TriviaBadge] = []
    @State private var showBadgeToast = false
    @State private var showFireworks = false
    @State private var fireworksSeed = 0
    @State private var showHeadsUp = false

    private var answeredDays: Set<String> {
        Set(answeredDaysStorage.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private var correctDays: Set<String> {
        Set(correctDaysStorage.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private var unlockedBadgeIDs: Set<String> {
        TriviaBadgeStore.unlocked(from: unlockedBadgesStorage)
    }

    private var todayKey: String {
        Self.dayKey(for: Date())
    }

    private var displayedCurrentStreak: Int {
        let yesterday = Self.dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        return lastCorrectDay == todayKey || lastCorrectDay == yesterday ? currentStreak : 0
    }

    private var currentQuestion: TriviaQuestionInstance {
        TriviaCatalog.instance(for: TriviaCatalog.question(for: selectedQuestionID) ?? TriviaCatalog.fallback)
    }

    private var dailyCompleted: Bool {
        answeredDays.contains(todayKey)
    }

    private var dailyLockedChoice: String? {
        guard dailyCompleted else { return nil }
        if lastAnswerDay == todayKey,
           lastAnswerQuestionID == selectedQuestionID,
           !lastAnswerChoice.isEmpty {
            return lastAnswerChoice
        }
        return selectedChoice ?? currentQuestion.question.answer
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BrandHeader(isLandscape: false, isWidePortrait: false)

                    HeadsUpLaunchCard(isPresented: $showHeadsUp)

                    TriviaQuestionCard(
                        title: "Bulldog Daily Trivia",
                        question: currentQuestion,
                        selectedChoice: $selectedChoice,
                        lockedChoice: dailyLockedChoice,
                        shareSummary: shareSummary,
                        allowsShare: true,
                        recordAnswer: { isCorrect in
                            guard !dailyCompleted else { return }
                            if isCorrect {
                                triggerCorrectFireworks()
                            }
                            recordAnswerIfDaily(isCorrect)
                        }
                    )

                    TriviaProgressCard(
                        currentStreak: displayedCurrentStreak,
                        bestStreak: bestStreak,
                        totalAnswered: answeredDays.count,
                        totalCorrect: correctDays.count,
                        completedToday: dailyCompleted
                    )

                    TriviaBadgesSection(unlockedIDs: unlockedBadgeIDs)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trivia")
            .overlay(alignment: .top) {
                if showBadgeToast, let badge = newlyUnlocked.first {
                    badgeToast(badge)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                if showFireworks {
                    MaroonFireworksView(seed: fireworksSeed)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35), value: showBadgeToast)
            .animation(.easeOut(duration: 0.2), value: showFireworks)
        }
        .onAppear {
            showDailyTrivia()
            refreshBadges()
        }
        .task { GameCenterStore.authenticate() }
        .fullScreenCover(isPresented: $showHeadsUp) {
            HeadsUpGameView()
        }
    }

    private func triggerCorrectFireworks() {
        fireworksSeed &+= 1
        showFireworks = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            await MainActor.run {
                showFireworks = false
            }
        }
    }

    private func badgeToast(_ badge: TriviaBadge) -> some View {
        HStack(spacing: 10) {
            Image(systemName: badge.systemImage)
            VStack(alignment: .leading, spacing: 2) {
                Text("Badge unlocked")
                    .font(.caption2.weight(.bold))
                Text(badge.title)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(Color.msMaroon)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
        .shadow(radius: 8, y: 4)
    }

    private func showDailyTrivia() {
        selectedQuestionID = TriviaCatalog.dailyQuestion(for: Date()).id
        if lastAnswerDay == todayKey,
           lastAnswerQuestionID == selectedQuestionID,
           !lastAnswerChoice.isEmpty {
            selectedChoice = lastAnswerChoice
        } else {
            selectedChoice = nil
        }
    }

    private func recordAnswerIfDaily(_ isCorrect: Bool) {
        var answered = answeredDays
        guard !answered.contains(todayKey) else { return }
        guard let selectedChoice else { return }

        answered.insert(todayKey)
        answeredDaysStorage = answered.sorted().joined(separator: ",")
        lastAnswerDay = todayKey
        lastAnswerQuestionID = selectedQuestionID
        lastAnswerChoice = selectedChoice

        if isCorrect {
            var correct = correctDays
            correct.insert(todayKey)
            correctDaysStorage = correct.sorted().joined(separator: ",")

            currentStreak = lastCorrectDay == Self.dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) ? currentStreak + 1 : 1
            bestStreak = max(bestStreak, currentStreak)
            lastCorrectDay = todayKey
            GameCenterStore.reportBestStreak(bestStreak)
        } else {
            currentStreak = 0
        }

        refreshBadges()
        CloudSyncStore.syncToCloud()
        DawgPushNotifier.shared.cancelTriviaReminder()
    }

    private func refreshBadges() {
        let newly = TriviaBadgeStore.evaluate(
            bestStreak: bestStreak,
            totalCorrect: correctDays.count,
            unlockedStorage: &unlockedBadgesStorage
        )
        if !newly.isEmpty {
            newlyUnlocked = newly
            showBadgeToast = true
            Task {
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                await MainActor.run { showBadgeToast = false }
            }
        }
        CloudSyncStore.syncToCloud()
    }

    private var shareSummary: String {
        let streak = displayedCurrentStreak
        let answered = answeredDays.count
        let correct = correctDays.count
        var lines = [
            "Bulldog Daily Trivia \u{1F415} \u{26BE}",
            "Streak: \(streak) day\(streak == 1 ? "" : "s") (best \(bestStreak))",
            "Career: \(correct)/\(answered) correct"
        ]
        if let choice = selectedChoice {
            let question = TriviaCatalog.question(for: selectedQuestionID) ?? TriviaCatalog.fallback
            let symbol = choice == question.answer ? "\u{2705}" : "\u{274C}"
            lines.append("Today: \(symbol)")
        }
        lines.append("Play along in Former Dawgs.")
        return lines.joined(separator: "\n")
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct TriviaProgressCard: View {
    let currentStreak: Int
    let bestStreak: Int
    let totalAnswered: Int
    let totalCorrect: Int
    let completedToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Former Dawgs IQ", systemImage: "brain.head.profile")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                StatTile(label: "Streak", value: String(currentStreak))
                StatTile(label: "Best", value: String(bestStreak))
                StatTile(label: "Correct", value: String(totalCorrect))
                StatTile(label: "Answered", value: String(totalAnswered))
            }

            Text(completedToday
                 ? "Today's trivia is complete. Come back tomorrow for a new question."
                 : "Answer today's question to keep your streak alive.")
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
        }
    }
}

struct TriviaBadgesSection: View {
    let unlockedIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Badges", systemImage: "rosette")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(TriviaBadge.allCases) { badge in
                    let unlocked = unlockedIDs.contains(badge.rawValue)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: badge.systemImage)
                                .foregroundStyle(unlocked ? Color.msMaroonText : .secondary)
                            Spacer()
                            if unlocked {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                        Text(badge.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(unlocked ? .primary : .secondary)
                        Text(badge.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .opacity(unlocked ? 1 : 0.55)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

struct TriviaQuestionCard: View {
    var title: String = "Bulldog Daily Trivia"
    let question: TriviaQuestionInstance
    @Binding var selectedChoice: String?
    var lockedChoice: String? = nil
    let shareSummary: String
    var allowsShare: Bool = true
    let recordAnswer: (Bool) -> Void

    private var correctAnswer: String { question.question.answer }
    private var displayedCorrectAnswer: String { normalizedTriviaText(correctAnswer) }
    private var effectiveChoice: String? { lockedChoice ?? selectedChoice }
    private var hasAnswered: Bool { effectiveChoice != nil }
    private var answeredCorrectly: Bool { effectiveChoice == correctAnswer }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: title, systemImage: "questionmark.bubble.fill")

            VStack(alignment: .leading, spacing: 12) {
                Text(question.question.category)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.msMaroonText)
                Text(question.question.prompt)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                ForEach(question.choices, id: \.self) { choice in
                    Button {
                        selectedChoice = choice
                        recordAnswer(choice == correctAnswer)
                    } label: {
                        HStack {
                            Text(normalizedTriviaText(choice))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if effectiveChoice == choice {
                                Image(systemName: answeredCorrectly ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(answeredCorrectly ? .green : .red)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(choiceBackground(for: choice))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(hasAnswered)
                }

                if hasAnswered {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(answeredCorrectly ? "Correct" : "Answer")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(answeredCorrectly ? .green : .secondary)
                        Text(displayedCorrectAnswer)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if hasAnswered && allowsShare {
                    ShareLink(item: shareSummary) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func choiceBackground(for choice: String) -> Color {
        guard hasAnswered else { return Color(.secondarySystemGroupedBackground) }
        if choice == correctAnswer { return Color.green.opacity(0.18) }
        if effectiveChoice == choice { return Color.red.opacity(0.14) }
        return Color(.secondarySystemGroupedBackground)
    }

    private func normalizedTriviaText(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

// MARK: - Maroon & white MSU fireworks

/// Full-screen particle fireworks in Mississippi State maroon and white.
struct MaroonFireworksView: View {
    let seed: Int
    @State private var startDate = Date()

    private static let maroon = Color.msMaroon
    private static let white = Color.white
    private static let softMaroon = Color(red: 0.62, green: 0.12, blue: 0.22)
    private static let cream = Color(red: 1.0, green: 0.97, blue: 0.95)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = max(0, timeline.date.timeIntervalSince(startDate))

                let bursts = Self.bursts(for: seed, in: size)
                for burst in bursts {
                    let localT = t - burst.delay
                    guard localT >= 0, localT < burst.lifetime else { continue }
                    drawBurst(context: context, burst: burst, localT: localT)
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black.opacity(0.12).ignoresSafeArea())
        .onAppear { startDate = Date() }
        .onChange(of: seed) { _, _ in startDate = Date() }
    }

    private func drawBurst(context: GraphicsContext, burst: FireworkBurst, localT: Double) {
        let progress = localT / burst.lifetime
        let expand = easeOut(min(progress * 1.35, 1.0))
        let fade = max(0, 1.0 - progress)

        // Bright core flash at the start
        if progress < 0.18 {
            let flash = 1.0 - (progress / 0.18)
            let coreSize = 10 + CGFloat(flash) * 28
            var core = context
            core.opacity = flash * 0.9
            core.fill(
                Path(ellipseIn: CGRect(
                    x: burst.origin.x - coreSize / 2,
                    y: burst.origin.y - coreSize / 2,
                    width: coreSize,
                    height: coreSize
                )),
                with: .color(burst.coreIsWhite ? Self.white : Self.softMaroon)
            )
        }

        for particle in burst.particles {
            let travel = expand * particle.distance
            let gravity = CGFloat(localT * localT) * 42 * particle.gravityScale
            let x = burst.origin.x + cos(particle.angle) * travel
            let y = burst.origin.y + sin(particle.angle) * travel + gravity
            let size = particle.size * CGFloat(fade * (0.55 + 0.45 * (1 - progress)))
            guard size > 0.4 else { continue }

            var particleContext = context
            particleContext.opacity = fade * particle.opacity

            let rect = CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
            particleContext.fill(Path(ellipseIn: rect), with: .color(particle.color))

            // Soft glow
            if particle.glows {
                var glow = context
                glow.opacity = fade * 0.28
                let glowSize = size * 2.4
                glow.fill(
                    Path(ellipseIn: CGRect(
                        x: x - glowSize / 2,
                        y: y - glowSize / 2,
                        width: glowSize,
                        height: glowSize
                    )),
                    with: .color(particle.color)
                )
            }

            // Sparkle trail near peak brightness
            if progress < 0.55 {
                let trail = travel * 0.18
                let tx = burst.origin.x + cos(particle.angle) * (travel - trail)
                let ty = burst.origin.y + sin(particle.angle) * (travel - trail) + gravity * 0.7
                var trailContext = context
                trailContext.opacity = fade * 0.35
                let trailSize = size * 0.45
                trailContext.fill(
                    Path(ellipseIn: CGRect(
                        x: tx - trailSize / 2,
                        y: ty - trailSize / 2,
                        width: trailSize,
                        height: trailSize
                    )),
                    with: .color(particle.color)
                )
            }
        }
    }

    private func easeOut(_ x: Double) -> CGFloat {
        CGFloat(1 - pow(1 - x, 3))
    }

    private static func bursts(for seed: Int, in size: CGSize) -> [FireworkBurst] {
        var rng = SeededGenerator(seed: UInt64(bitPattern: Int64(seed &+ 917_531)))
        let palette: [Color] = [maroon, white, softMaroon, cream, maroon, white]
        let count = 5
        return (0..<count).map { index in
            let origin = CGPoint(
                x: size.width * CGFloat(0.18 + Double.random(in: 0...0.64, using: &rng)),
                y: size.height * CGFloat(0.18 + Double.random(in: 0...0.42, using: &rng))
            )
            let particleCount = Int.random(in: 36...52, using: &rng)
            let particles: [FireworkParticle] = (0..<particleCount).map { p in
                let angle = (Double(p) / Double(particleCount)) * (.pi * 2)
                    + Double.random(in: -0.12...0.12, using: &rng)
                let color = palette[Int.random(in: 0..<palette.count, using: &rng)]
                return FireworkParticle(
                    angle: angle,
                    distance: CGFloat.random(in: 70...170, using: &rng),
                    size: CGFloat.random(in: 3.5...8.5, using: &rng),
                    opacity: Double.random(in: 0.75...1.0, using: &rng),
                    gravityScale: CGFloat.random(in: 0.7...1.25, using: &rng),
                    color: color,
                    glows: Bool.random(using: &rng)
                )
            }
            return FireworkBurst(
                origin: origin,
                delay: Double(index) * 0.22 + Double.random(in: 0...0.08, using: &rng),
                lifetime: Double.random(in: 1.35...1.75, using: &rng),
                particles: particles,
                coreIsWhite: index.isMultiple(of: 2)
            )
        }
    }
}

private struct FireworkBurst {
    let origin: CGPoint
    let delay: Double
    let lifetime: Double
    let particles: [FireworkParticle]
    let coreIsWhite: Bool
}

private struct FireworkParticle {
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let opacity: Double
    let gravityScale: CGFloat
    let color: Color
    let glows: Bool
}

/// Deterministic RNG so each fireworks celebration is stable across frames.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
