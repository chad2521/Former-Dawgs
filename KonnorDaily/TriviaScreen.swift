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
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(
            value,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [triviaBestStreakLeaderboardID]
        ) { error in
            if let error {
                print("Game Center streak report failed: \(error.localizedDescription)")
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
    @AppStorage("triviaPracticeCategory", store: SharedAppGroup.defaults) private var practiceCategoryStorage = ""
    @State private var selectedQuestionID = TriviaCatalog.dailyQuestion(for: Date()).id
    @State private var selectedChoice: String?
    @State private var isShowingDailyQuestion = true

    private var practiceCategory: String? {
        practiceCategoryStorage.isEmpty ? nil : practiceCategoryStorage
    }

    private var answeredDays: Set<String> {
        Set(answeredDaysStorage.split(separator: ",").map(String.init))
    }

    private var correctDays: Set<String> {
        Set(correctDaysStorage.split(separator: ",").map(String.init))
    }

    private var todayKey: String {
        Self.dayKey(for: Date())
    }

    private var displayedCurrentStreak: Int {
        let yesterday = Self.dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        return lastCorrectDay == todayKey || lastCorrectDay == yesterday ? currentStreak : 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BrandHeader(isLandscape: false, isWidePortrait: false)

                    TriviaProgressCard(
                        currentStreak: displayedCurrentStreak,
                        bestStreak: bestStreak,
                        totalAnswered: answeredDays.count,
                        totalCorrect: correctDays.count,
                        completedToday: answeredDays.contains(todayKey)
                    )

                    TriviaQuestionCard(
                        question: TriviaCatalog.instance(for: TriviaCatalog.question(for: selectedQuestionID) ?? TriviaCatalog.fallback),
                        selectedChoice: $selectedChoice,
                        isDailyQuestion: isShowingDailyQuestion,
                        shareSummary: shareSummary,
                        recordAnswer: recordAnswerIfDaily,
                        resetToDailyQuestion: showDailyTrivia,
                        loadPracticeQuestion: loadPracticeQuestion
                    )

                    TriviaPracticeCard(
                        category: Binding(
                            get: { practiceCategory },
                            set: { practiceCategoryStorage = $0 ?? "" }
                        ),
                        loadPracticeQuestion: loadPracticeQuestion
                    )
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Former Dawgs")
        }
        .onAppear { showDailyTrivia() }
        .task { GameCenterStore.authenticate() }
    }

    private func showDailyTrivia() {
        selectedQuestionID = TriviaCatalog.dailyQuestion(for: Date()).id
        selectedChoice = nil
        isShowingDailyQuestion = true
    }

    private func loadPracticeQuestion() {
        let next = TriviaCatalog.randomQuestion(in: practiceCategory, excluding: selectedQuestionID)
        selectedQuestionID = next.id
        selectedChoice = nil
        isShowingDailyQuestion = false
    }

    private func recordAnswerIfDaily(_ isCorrect: Bool) {
        guard isShowingDailyQuestion else { return }
        var answered = answeredDays
        guard !answered.contains(todayKey) else { return }

        answered.insert(todayKey)
        answeredDaysStorage = answered.sorted().joined(separator: ",")

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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                StatTile(label: "Streak", value: String(currentStreak))
                StatTile(label: "Best", value: String(bestStreak))
                StatTile(label: "Answered", value: String(totalAnswered))
                StatTile(label: "Correct", value: String(totalCorrect))
            }

            Text(completedToday ? "Today's trivia is complete." : "Answer today's question to keep your streak alive.")
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
        }
    }
}

struct TriviaQuestionCard: View {
    let question: TriviaQuestionInstance
    @Binding var selectedChoice: String?
    let isDailyQuestion: Bool
    let shareSummary: String
    let recordAnswer: (Bool) -> Void
    let resetToDailyQuestion: () -> Void
    let loadPracticeQuestion: () -> Void

    private var correctAnswer: String { question.question.answer }
    private var displayedCorrectAnswer: String { normalizedTriviaText(correctAnswer) }
    private var hasAnswered: Bool { selectedChoice != nil }
    private var answeredCorrectly: Bool { selectedChoice == correctAnswer }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: isDailyQuestion ? "Bulldog Daily Trivia" : "Practice Question", systemImage: "questionmark.bubble.fill")

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
                            if selectedChoice == choice {
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

                HStack(spacing: 10) {
                    if !isDailyQuestion {
                        Button("Today's Question") { resetToDailyQuestion() }
                            .buttonStyle(.borderedProminent)
                    }
                    Button(isDailyQuestion ? "Practice More" : "Next Practice") {
                        loadPracticeQuestion()
                    }
                    .buttonStyle(.bordered)
                    if hasAnswered {
                        ShareLink(item: shareSummary) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
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
        if selectedChoice == choice { return Color.red.opacity(0.14) }
        return Color(.secondarySystemGroupedBackground)
    }

    private func normalizedTriviaText(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

struct TriviaPracticeCard: View {
    @Binding var category: String?
    let loadPracticeQuestion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Practice Mode", systemImage: "dial.high.fill")

            HStack {
                Text("Category")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("All Categories") { category = nil }
                    Divider()
                    ForEach(TriviaCatalog.categories, id: \.self) { name in
                        Button(name) { category = name }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(category ?? "All Categories")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.msMaroonText)
                }
            }

            Button { loadPracticeQuestion() } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Pull a Practice Question")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.msMaroon.opacity(0.12))
                .foregroundStyle(Color.msMaroonText)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("Practice questions don't affect your daily streak.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
