import AppIntents
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class IntentRouter {
    static let shared = IntentRouter()

    var pendingTab: AppTab?
    var pendingPlayerID: Int?
    /// When true, Tonight should open on the ballpark map (players playing tonight).
    var pendingTonightMap: Bool = false

    private init() {}

    func requestTab(_ tab: AppTab) {
        pendingTab = tab
    }

    /// Jump to Tonight → Map of every Dawg ballpark tonight.
    func requestTonightMap() {
        pendingTonightMap = true
        pendingTab = .tonight
    }

    func requestPlayer(_ id: Int) {
        pendingPlayerID = id
        pendingTab = .player
    }

    func consume() -> (tab: AppTab?, playerID: Int?, openTonightMap: Bool) {
        let result = (pendingTab, pendingPlayerID, pendingTonightMap)
        pendingTab = nil
        pendingPlayerID = nil
        pendingTonightMap = false
        return result
    }

    /// Consume only the Tonight map flag (tab may already be applied).
    func consumeTonightMapRequest() -> Bool {
        let value = pendingTonightMap
        pendingTonightMap = false
        return value
    }
}

struct FormerDawgEntity: AppEntity, Identifiable {
    let id: Int
    let displayName: String
    let role: String
    let msuYears: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Former Dawg")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: "\(role) • State \(msuYears)"
        )
    }

    static var defaultQuery = FormerDawgQuery()

    init(_ entry: PlayerCatalogEntry) {
        self.id = entry.id
        self.displayName = entry.displayName
        self.role = entry.role
        self.msuYears = entry.msuYears
    }
}

struct FormerDawgQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [FormerDawgEntity] {
        identifiers.compactMap { id in
            PlayerCatalog.players.first { $0.id == id }.map(FormerDawgEntity.init)
        }
    }

    func suggestedEntities() async throws -> [FormerDawgEntity] {
        PlayerCatalog.players.map(FormerDawgEntity.init)
    }
}

struct OpenTodayTriviaIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today's Trivia"
    static var description = IntentDescription("Jump straight to today's Bulldog baseball trivia question.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.requestTab(.trivia)
        return .result()
    }
}


struct OpenFormerDawgIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Former Dawg"
    static var description = IntentDescription("Open a Mississippi State alum's pro dashboard.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Player", description: "The Former Dawg to open.")
    var dawg: FormerDawgEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.requestPlayer(dawg.id)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$dawg)")
    }
}

struct ActiveDawgsTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Active Former Dawgs Today"
    static var description = IntentDescription("Returns the list of Former Dawgs with a game today.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[FormerDawgEntity]> & ProvidesDialog {
        let activeIDs = PlayerRuntimeStore.playersWithGameToday()
        let entries = PlayerCatalog.players
            .filter { activeIDs.contains($0.id) }
            .map(FormerDawgEntity.init)

        let dialog: IntentDialog
        switch entries.count {
        case 0:
            dialog = "No Former Dawgs are scheduled today."
        case 1:
            dialog = "\(entries[0].displayName) has a game today."
        default:
            dialog = "\(entries.count) Former Dawgs have games today."
        }

        return .result(value: entries, dialog: dialog)
    }
}

struct FormerDawgsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTodayTriviaIntent(),
            phrases: [
                "Open today's \(.applicationName) trivia",
                "Show today's Bulldog trivia in \(.applicationName)"
            ],
            shortTitle: "Today's Trivia",
            systemImageName: "questionmark.bubble.fill"
        )
        AppShortcut(
            intent: OpenFormerDawgIntent(),
            phrases: [
                "Open a Former Dawg in \(.applicationName)",
                "Show \(\.$dawg) in \(.applicationName)"
            ],
            shortTitle: "Open Former Dawg",
            systemImageName: "person.fill"
        )
        AppShortcut(
            intent: ActiveDawgsTodayIntent(),
            phrases: [
                "Which Former Dawgs are playing today in \(.applicationName)",
                "\(.applicationName) active Bulldogs today"
            ],
            shortTitle: "Active Today",
            systemImageName: "baseball.fill"
        )
    }
}
