import SwiftUI

struct ContentView: View {
    @State private var model = WatchModel()
    @State private var selectedChoice: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    streakCard
                    triviaCard
                    favoritesCard
                }
                .padding(.horizontal, 2)
            }
            .navigationTitle("Dawgs")
            .onAppear { model.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Former Dawgs")
                .font(.headline.weight(.bold))
            Text("Mississippi State baseball at a glance")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakCard: some View {
        WatchCard {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle().fill(.maroonGradient)
                    Text("\(model.currentStreak)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Day streak")
                        .font(.subheadline.weight(.semibold))
                    Text("Best: \(model.bestStreak)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var triviaCard: some View {
        WatchCard {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Label("Daily Trivia", systemImage: "questionmark.bubble.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !model.todayCategory.isEmpty {
                        Text(model.todayCategory)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(model.todayPrompt.isEmpty ? "Open the iPhone app to load today's question." : model.todayPrompt)
                    .font(.caption.weight(.semibold))
                    .lineLimit(4)

                ForEach(model.todayChoices, id: \.self) { choice in
                    Button {
                        selectedChoice = choice
                    } label: {
                        HStack {
                            Text(choice.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
                                .font(.caption2.weight(.medium))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if selectedChoice == choice {
                                Image(systemName: choice == model.todayAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(choice == model.todayAnswer ? .green : .red)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(choiceBackground(for: choice))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedChoice != nil)
                }
            }
        }
    }

    private var favoritesCard: some View {
        WatchCard {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.favoriteCount) favorite\(model.favoriteCount == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                    Text("Synced from iPhone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func choiceBackground(for choice: String) -> Color {
        guard let selected = selectedChoice else {
            return Color.white.opacity(0.08)
        }
        if choice == model.todayAnswer { return Color.green.opacity(0.22) }
        if choice == selected { return Color.red.opacity(0.18) }
        return Color.white.opacity(0.08)
    }
}

@MainActor
@Observable
final class WatchModel {
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var favoriteCount: Int = 0
    var todayPrompt: String = ""
    var todayChoices: [String] = []
    var todayAnswer: String = ""
    var todayCategory: String = ""

    private let cloud = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        cloud.synchronize()
        currentStreak = Int(cloud.longLong(forKey: "triviaCurrentStreak"))
        bestStreak = Int(cloud.longLong(forKey: "triviaBestStreak"))
        let favCsv = cloud.string(forKey: "favoritePlayerIDs") ?? ""
        favoriteCount = favCsv.split(separator: ",").compactMap { Int($0) }.count

        todayPrompt = cloud.string(forKey: "triviaTodayPrompt") ?? ""
        todayAnswer = cloud.string(forKey: "triviaTodayAnswer") ?? ""
        todayCategory = cloud.string(forKey: "triviaTodayCategory") ?? ""
        let raw = cloud.string(forKey: "triviaTodayChoices") ?? ""
        todayChoices = raw.split(separator: "\u{1F}").map(String.init)
    }
}

struct WatchCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension ShapeStyle where Self == LinearGradient {
    static var maroonGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.40, green: 0.10, blue: 0.16), Color(red: 0.14, green: 0.13, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    ContentView()
}
