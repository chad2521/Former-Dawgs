import Foundation
import ActivityKit

enum SharedAppGroup {
    static let identifier = "group.com.cwdawg.formerdawgs.shared"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

enum CloudSyncStore {
    static let triviaTodayPromptKey = "triviaTodayPrompt"
    static let triviaTodayChoicesKey = "triviaTodayChoices"
    static let triviaTodayAnswerKey = "triviaTodayAnswer"
    static let triviaTodayCategoryKey = "triviaTodayCategory"

    private static let keys = [
        "favoritePlayerIDs",
        "selectedPlayerID",
        "appearanceMode",
        "triviaAnsweredDays",
        "triviaCorrectDays",
        "triviaCurrentStreak",
        "triviaBestStreak",
        "triviaLastCorrectDay",
        "triviaPracticeCategory"
    ]

    private static var externalObserver: NSObjectProtocol?

    static func startObserving() {
        guard externalObserver == nil else { return }
        externalObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in
            syncFromCloud()
        }
    }

    static func syncFromCloud() {
        let cloud = NSUbiquitousKeyValueStore.default
        cloud.synchronize()

        for key in keys {
            if let value = cloud.object(forKey: key) {
                SharedAppGroup.defaults.set(value, forKey: key)
            }
        }
    }

    static func syncToCloud() {
        let defaults = SharedAppGroup.defaults
        let cloud = NSUbiquitousKeyValueStore.default

        for key in keys {
            if let value = defaults.object(forKey: key) {
                cloud.set(value, forKey: key)
            }
        }

        cloud.synchronize()
    }

    static func pushTodayTrivia(prompt: String, choices: [String], answer: String, category: String) {
        let cloud = NSUbiquitousKeyValueStore.default
        cloud.set(prompt, forKey: triviaTodayPromptKey)
        cloud.set(choices.joined(separator: "\u{1F}"), forKey: triviaTodayChoicesKey)
        cloud.set(answer, forKey: triviaTodayAnswerKey)
        cloud.set(category, forKey: triviaTodayCategoryKey)
        cloud.synchronize()
    }
}

enum PlayerKind: String, CaseIterable {
    case hitter
    case pitcher
}

struct PlayerCatalogEntry: Identifiable, Hashable {
    let id: Int
    let displayName: String
    let role: String
    let msuYears: String
    let kind: PlayerKind
    let isMinorLeaguer: Bool
    let preferredSportID: Int?
    let teamLogoCode: String?
}

enum PlayerCatalog {
    static let players: [PlayerCatalogEntry] = rawPlayers.sorted {
        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
    }

    static let fallback = players[0]

    static func player(for id: Int) -> PlayerCatalogEntry {
        players.first { $0.id == id } ?? fallback
    }

    private static let rawPlayers: [PlayerCatalogEntry] = [
        major(id: 641585, displayName: "J.P. France", role: "RHP", msuYears: "2018", kind: .pitcher, teamLogoCode: "hou"),
        major(id: 624428, displayName: "Adam Frazier", role: "2B/OF", msuYears: "2011-13", kind: .hitter, teamLogoCode: "laa"),
        major(id: 669372, displayName: "J.T. Ginn", role: "RHP", msuYears: "2019-20", kind: .pitcher, teamLogoCode: "ath"),
        major(id: 663993, displayName: "Nathaniel Lowe", role: "1B", msuYears: "2016", kind: .hitter, teamLogoCode: "wsh"),
        major(id: 663968, displayName: "Jake Mangum", role: "OF", msuYears: "2016-19", kind: .hitter, teamLogoCode: "pit"),
        major(id: 667670, displayName: "Brent Rooker", role: "OF/DH", msuYears: "2015-17", kind: .hitter, teamLogoCode: "ath"),
        major(id: 676059, displayName: "Jordan Westburg", role: "INF", msuYears: "2018-20", kind: .hitter, teamLogoCode: "bal"),
        major(id: 605540, displayName: "Brandon Woodruff", role: "RHP", msuYears: "2012-14", kind: .pitcher, teamLogoCode: "mil"),
        minor(id: 687218, displayName: "Will Bednar", role: "RHP", msuYears: "2020-21", kind: .pitcher, sportID: 12, teamLogoCode: "sf"),
        minor(id: 672021, displayName: "Eric Cerantola", role: "RHP", msuYears: "2019-21", kind: .pitcher, sportID: 11, teamLogoCode: "kc"),
        minor(id: 679822, displayName: "Justin Foscue", role: "1B", msuYears: "2018-20", kind: .hitter, sportID: 11, teamLogoCode: "tex"),
        minor(id: 687268, displayName: "K.C. Hunt", role: "RHP", msuYears: "2021-22", kind: .pitcher, sportID: 11, teamLogoCode: "mil"),
        minor(id: 807742, displayName: "Colton Ledbetter", role: "OF", msuYears: "2023", kind: .hitter, sportID: 11, teamLogoCode: "tb"),
        minor(id: 802418, displayName: "Colby Holcombe", role: "RHP", msuYears: "2023-24", kind: .pitcher, sportID: 13, teamLogoCode: "tor"),
        minor(id: 663455, displayName: "Konnor Pilkington", role: "LHP", msuYears: "2016-18", kind: .pitcher, sportID: 11, teamLogoCode: "wsh"),
        minor(id: 681003, displayName: "Andrew Walling", role: "LHP", msuYears: "2022", kind: .pitcher, sportID: 12, teamLogoCode: "kc"),
        minor(id: 701388, displayName: "Jurrangelo Cijntje", role: "RHP", msuYears: "2023-24", kind: .pitcher, sportID: 11, teamLogoCode: "sea"),
        minor(id: 824620, displayName: "Tyson Hardin", role: "RHP", msuYears: "2023-24", kind: .pitcher, sportID: 12, teamLogoCode: "mil"),
        minor(id: 806060, displayName: "Luke Dotson", role: "LHP", msuYears: "2024-25", kind: .pitcher, sportID: 14, teamLogoCode: "ari"),
        minor(id: 824624, displayName: "Brooks Auger", role: "RHP", msuYears: "2022-24", kind: .pitcher, sportID: 13, teamLogoCode: "lad"),
        minor(id: 699613, displayName: "Houston Harding", role: "LHP", msuYears: "2020-21", kind: .pitcher, sportID: 11, teamLogoCode: "atl"),
        minor(id: 702309, displayName: "Hunter Hines", role: "1B", msuYears: "2022-25", kind: .hitter, sportID: 13, teamLogoCode: "wsh"),
        minor(id: 690977, displayName: "Jackson Fristoe", role: "RHP", msuYears: "2021-22", kind: .pitcher, sportID: 13, teamLogoCode: "nyy"),
        minor(id: 687553, displayName: "Kamren James", role: "SS", msuYears: "2020-22", kind: .hitter, sportID: 12, teamLogoCode: "tb"),
        minor(id: 695704, displayName: "Karson Ligon", role: "RHP", msuYears: "2025", kind: .pitcher, sportID: 16, teamLogoCode: "tor"),
        minor(id: 702296, displayName: "Nate Dohm", role: "RHP", msuYears: "2022-24", kind: .pitcher, sportID: 13, teamLogoCode: "stl"),
        minor(id: 802699, displayName: "Nate Williams", role: "RHP", msuYears: "2025", kind: .pitcher, sportID: 13, teamLogoCode: "chc"),
        minor(id: 702574, displayName: "David Mershon", role: "SS", msuYears: "2023-24", kind: .hitter, sportID: 12, teamLogoCode: "laa"),
        minor(id: 683085, displayName: "Landon Sims", role: "RHP", msuYears: "2020-22", kind: .pitcher, sportID: 11, teamLogoCode: "ari"),
        minor(id: 694696, displayName: "Cade Smith", role: "RHP", msuYears: "2021-23", kind: .pitcher, sportID: 12, teamLogoCode: "cle"),
        minor(id: 824615, displayName: "Connor Hujsak", role: "OF", msuYears: "2023-24", kind: .hitter, sportID: 13, teamLogoCode: "tb"),
        minor(id: 702607, displayName: "Dakota Jordan", role: "OF", msuYears: "2023-24", kind: .hitter, sportID: 12, teamLogoCode: "sf"),
        minor(id: 804905, displayName: "Evan Siary", role: "RHP", msuYears: "2025", kind: .pitcher, sportID: 13, teamLogoCode: "tex"),
        minor(id: 809131, displayName: "Jacob Pruitt", role: "RHP", msuYears: "2025", kind: .pitcher, sportID: 14, teamLogoCode: "phi"),
        minor(id: 695560, displayName: "Pico Kohn", role: "LHP", msuYears: "2022, 2024-25", kind: .pitcher, sportID: 12, teamLogoCode: "nyy"),
        minor(id: 699980, displayName: "Preston Johnson", role: "RHP", msuYears: "2021-22", kind: .pitcher, sportID: 12, teamLogoCode: "min"),
        minor(id: 691004, displayName: "Aaron Nixon", role: "RHP", msuYears: "2023", kind: .pitcher, sportID: 12, teamLogoCode: "ath"),
        minor(id: 807575, displayName: "Cam Schuelke", role: "RHP", msuYears: "2024", kind: .pitcher, sportID: 12, teamLogoCode: "chc"),
        minor(id: 683091, displayName: "Logan Tanner", role: "C", msuYears: "2020-22", kind: .hitter, sportID: 13, teamLogoCode: "cin")
    ]

    private static func major(id: Int, displayName: String, role: String, msuYears: String, kind: PlayerKind, teamLogoCode: String?) -> PlayerCatalogEntry {
        PlayerCatalogEntry(id: id, displayName: displayName, role: role, msuYears: msuYears, kind: kind, isMinorLeaguer: false, preferredSportID: nil, teamLogoCode: teamLogoCode)
    }

    private static func minor(id: Int, displayName: String, role: String, msuYears: String, kind: PlayerKind, sportID: Int, teamLogoCode: String?) -> PlayerCatalogEntry {
        PlayerCatalogEntry(id: id, displayName: displayName, role: role, msuYears: msuYears, kind: kind, isMinorLeaguer: true, preferredSportID: sportID, teamLogoCode: teamLogoCode)
    }
}

struct PlayerProfile: Decodable {
    let people: [Person]

    struct Person: Decodable {
        let id: Int
        let fullName: String
        let primaryNumber: String?
        let currentTeam: Team?
        let primaryPosition: Position?
        let batSide: Side?
        let pitchHand: Side?
        let height: String?
        let weight: Int?
    }
}

struct PlayerStatsResponse: Decodable {
    let stats: [StatsGroup]

    struct StatsGroup: Decodable {
        let splits: [Split]
    }

    struct Split: Decodable {
        let stat: BaseballStat
        let team: Team?
        let league: League?
        let sport: Sport?
        let season: String?
    }
}

struct Team: Decodable {
    let id: Int
    let name: String
}

struct Position: Decodable {
    let abbreviation: String
}

struct Side: Decodable {
    let code: String
}

struct League: Decodable {
    let name: String
}

struct Sport: Decodable {
    let abbreviation: String?
}

struct BaseballStat: Decodable {
    let summary: String?
    let gamesPlayed: Int?
    let atBats: Int?
    let runs: Int?
    let hits: Int?
    let doubles: Int?
    let triples: Int?
    let homeRuns: Int?
    let rbi: Int?
    let stolenBases: Int?
    let avg: String?
    let obp: String?
    let slg: String?
    let ops: String?
    let wins: Int?
    let losses: Int?
    let saves: Int?
    let gamesStarted: Int?
    let inningsPitched: String?
    let strikeOuts: Int?
    let baseOnBalls: Int?
    let era: String?
    let whip: String?
}

struct TodayGame: Hashable {
    enum State: Hashable {
        case scheduled
        case live
        case final
    }

    let state: State
    let opponentName: String
    let isHome: Bool
    let startTime: Date?
    let homeScore: Int?
    let awayScore: Int?
    let inningText: String?

    var headline: String {
        let prefix = isHome ? "vs" : "@"
        return "\(prefix) \(opponentName)"
    }

    var statusText: String {
        switch state {
        case .scheduled:
            guard let startTime else { return "Today" }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: startTime)
        case .live:
            let score = formatScore()
            if let inningText, !inningText.isEmpty {
                return "\(score) • \(inningText)"
            }
            return score
        case .final:
            return "Final \(formatScore())"
        }
    }

    private func formatScore() -> String {
        let home = homeScore ?? 0
        let away = awayScore ?? 0
        return isHome ? "\(home)-\(away)" : "\(away)-\(home)"
    }
}

struct ScheduleResponse: Decodable {
    let dates: [DateBlock]

    struct DateBlock: Decodable {
        let date: String?
        let games: [Game]
    }

    struct Game: Decodable {
        let gameDate: String?
        let status: GameStatus?
        let teams: GameTeams
        let linescore: Linescore?
    }

    struct GameStatus: Decodable {
        let abstractGameState: String?
        let detailedState: String?
    }

    struct GameTeams: Decodable {
        let away: GameSide
        let home: GameSide
    }

    struct GameSide: Decodable {
        let score: Int?
        let team: Team
    }

    struct Linescore: Decodable {
        let currentInning: Int?
        let inningHalf: String?
    }
}

struct PlayerDashboard {
    let catalogEntry: PlayerCatalogEntry
    let profile: PlayerProfile.Person
    let seasonStat: PlayerStatsResponse.Split?
    let stories: [Story]
    let gameLogs: [GameLogEntry]
    let videos: [HighlightVideo]
    let todayGame: TodayGame?

    var resolvedSportID: Int? {
        guard let sport = seasonStat?.sport?.abbreviation?.uppercased() else {
            return catalogEntry.preferredSportID
        }

        switch sport {
        case "MLB":
            return nil
        case "AAA":
            return 11
        case "AA":
            return 12
        case "A+":
            return 13
        case "A":
            return 14
        case "RK", "ROK":
            return 16
        default:
            return catalogEntry.preferredSportID
        }
    }

    var resolvedIsMinorLeaguer: Bool {
        resolvedSportID != nil
    }

    var resolvedTeamLogoCode: String? {
        if let currentTeamID = profile.currentTeam?.id,
           let liveCode = TeamLogoCatalog.code(for: currentTeamID) {
            return liveCode
        }

        return catalogEntry.teamLogoCode
    }

    var name: String {
        profile.fullName
    }

    var teamLine: String {
        let team = profile.currentTeam?.name ?? "Professional Baseball"
        let number = profile.primaryNumber.map { "#\($0)" } ?? ""
        let position = profile.primaryPosition?.abbreviation ?? catalogEntry.role
        return [number, position, team].filter { !$0.isEmpty }.joined(separator: " | ")
    }

    var msuLine: String {
        return "Mississippi State \(catalogEntry.msuYears)"
    }
}

struct Story: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let source: String
    let publishedText: String
    let url: URL
}

struct HighlightVideo: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let source: String
    let publishedText: String
    let url: URL
}

struct GameLogResponse: Decodable {
    let stats: [StatsGroup]

    struct StatsGroup: Decodable {
        let splits: [Split]
    }

    struct Split: Decodable {
        let date: String?
        let isHome: Bool?
        let opponent: Team?
        let stat: BaseballStat
    }
}

struct GameLogEntry: Identifiable, Hashable {
    let id = UUID()
    let dateText: String
    let opponentText: String
    let line: String
    let homeRuns: Int?
    let hits: Int?
    let rbi: Int?
    let inningsPitched: Double?
    let strikeOuts: Int?
    let walks: Int?
}

struct FormerDawgsHomeSummary {
    let hottestHitter: PlayerDashboard?
    let hottestPitcher: PlayerDashboard?
    let latestPromotion: HomeStoryHighlight?
    let latestHeadline: HomeStoryHighlight?
    let weeklyHitterLeaders: [HomeLeaderboardEntry]
    let weeklyPitcherLeaders: [HomeLeaderboardEntry]
    let transactionTimeline: [HomeStoryHighlight]
    let favoritesWatchlist: [PlayerDashboard]
    let comparisonOptions: [PlayerDashboard]
    let todaySummary: TodayPerformanceSummary
    let todaysActivePlayers: [PlayerDashboard]
}

struct HomeStoryHighlight: Identifiable {
    let id = UUID()
    let player: PlayerCatalogEntry
    let story: Story
}

struct HomeLeaderboardEntry: Identifiable {
    let id = UUID()
    let dashboard: PlayerDashboard
    let score: Double
    let scoreText: String
    let detailText: String
}

struct TodayPerformanceSummary {
    let activePlayers: [PlayerDashboard]
    let homeredToday: [PlayerDashboard]
    let pitchedToday: [PlayerDashboard]
    let multiHitToday: [PlayerDashboard]
}

enum TeamLogoCatalog {
    private static let codesByTeamID: [Int: String] = [
        108: "laa",
        109: "ari",
        110: "bal",
        111: "bos",
        112: "chc",
        113: "cin",
        114: "cle",
        115: "col",
        116: "det",
        117: "hou",
        118: "kc",
        119: "lad",
        120: "wsh",
        121: "nym",
        133: "ath",
        134: "pit",
        135: "sd",
        136: "sea",
        137: "sf",
        138: "stl",
        139: "tb",
        140: "tex",
        141: "tor",
        142: "min",
        143: "phi",
        144: "atl",
        145: "chw",
        146: "mia",
        147: "nyy",
        158: "mil"
    ]

    static func code(for teamID: Int) -> String? {
        codesByTeamID[teamID]
    }
}

enum PlayerRuntimeStore {
    private static let sportIDKey = "playerRuntimeSportIDs"
    private static let minorStatusKey = "playerRuntimeMinorStatus"
    private static let teamLogoCodeKey = "playerRuntimeTeamLogoCodes"
    private static let todayGameKey = "playerRuntimeTodayGameDates"
    private static let todaysDawgsSnapshotKey = "todaysDawgsSnapshot"

    private static var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func saveOverride(for dashboard: PlayerDashboard) {
        let playerID = String(dashboard.catalogEntry.id)
        let defaults = SharedAppGroup.defaults

        var sportIDs = defaults.dictionary(forKey: sportIDKey) as? [String: Int] ?? [:]
        sportIDs[playerID] = dashboard.resolvedSportID ?? 0
        defaults.set(sportIDs, forKey: sportIDKey)

        var minorStatuses = defaults.dictionary(forKey: minorStatusKey) as? [String: Bool] ?? [:]
        minorStatuses[playerID] = dashboard.resolvedIsMinorLeaguer
        defaults.set(minorStatuses, forKey: minorStatusKey)

        var teamLogoCodes = defaults.dictionary(forKey: teamLogoCodeKey) as? [String: String] ?? [:]
        if let resolvedTeamLogoCode = dashboard.resolvedTeamLogoCode {
            teamLogoCodes[playerID] = resolvedTeamLogoCode
        } else {
            teamLogoCodes.removeValue(forKey: playerID)
        }
        defaults.set(teamLogoCodes, forKey: teamLogoCodeKey)

        var todayDates = defaults.dictionary(forKey: todayGameKey) as? [String: String] ?? [:]
        if dashboard.todayGame != nil {
            todayDates[playerID] = todayDateString
        } else {
            todayDates.removeValue(forKey: playerID)
        }
        defaults.set(todayDates, forKey: todayGameKey)
    }

    static func playersWithGameToday() -> Set<Int> {
        let defaults = SharedAppGroup.defaults
        guard let map = defaults.dictionary(forKey: todayGameKey) as? [String: String] else {
            return []
        }
        let today = todayDateString
        return Set(map.compactMap { key, value in
            value == today ? Int(key) : nil
        })
    }

    static func sportID(for playerID: Int) -> Int?? {
        let values = SharedAppGroup.defaults.dictionary(forKey: sportIDKey) as? [String: Int]
        guard let value = values?[String(playerID)] else {
            return nil
        }

        return value == 0 ? .some(nil) : .some(value)
    }

    static func isMinorLeaguer(for playerID: Int) -> Bool? {
        let values = SharedAppGroup.defaults.dictionary(forKey: minorStatusKey) as? [String: Bool]
        return values?[String(playerID)]
    }

    static func teamLogoCode(for playerID: Int) -> String? {
        let values = SharedAppGroup.defaults.dictionary(forKey: teamLogoCodeKey) as? [String: String]
        return values?[String(playerID)]
    }

    static func saveTodaysDawgsSnapshot(from dashboards: [PlayerDashboard]) {
        let snapshot = TodaysDawgsSnapshot(
            generatedAt: Date(),
            players: dashboards
                .filter { $0.todayGame != nil }
                .sorted {
                    $0.catalogEntry.displayName.localizedCaseInsensitiveCompare($1.catalogEntry.displayName) == .orderedAscending
                }
                .map(TodaysDawgSnapshotPlayer.init)
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        SharedAppGroup.defaults.set(data, forKey: todaysDawgsSnapshotKey)
    }

    static func loadTodaysDawgsSnapshot() -> TodaysDawgsSnapshot {
        guard let data = SharedAppGroup.defaults.data(forKey: todaysDawgsSnapshotKey),
              let snapshot = try? JSONDecoder().decode(TodaysDawgsSnapshot.self, from: data) else {
            return TodaysDawgsSnapshot(generatedAt: nil, players: [])
        }
        return snapshot
    }
}

struct DawgLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var statusLabel: String
        var headlineText: String
        var scoreText: String
        var inningText: String?
        var lineText: String?
    }

    let playerID: Int
    let playerName: String
    let teamLogoCode: String?
    let role: String
}

struct TodaysDawgsSnapshot: Codable, Hashable {
    let generatedAt: Date?
    let players: [TodaysDawgSnapshotPlayer]

    var headline: String {
        switch players.count {
        case 0:
            return "No Dawgs on deck yet"
        case 1:
            return "1 Dawg active today"
        default:
            return "\(players.count) Dawgs active today"
        }
    }
}

struct TodaysDawgSnapshotPlayer: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let role: String
    let teamName: String
    let gameHeadline: String
    let statusText: String
    let isLive: Bool

    init(dashboard: PlayerDashboard) {
        id = dashboard.catalogEntry.id
        name = dashboard.catalogEntry.displayName
        role = dashboard.catalogEntry.role
        teamName = dashboard.profile.currentTeam?.name ?? "Professional Baseball"
        gameHeadline = dashboard.todayGame?.headline ?? "Today"
        statusText = dashboard.todayGame?.statusText ?? "Scheduled"
        isLive = dashboard.todayGame?.state == .live
    }
}

struct TriviaQuestion: Identifiable, Hashable {
    let id: Int
    let category: String
    let prompt: String
    let answer: String
    let choices: [String]?

    init(id: Int, category: String, prompt: String, answer: String, choices: [String]? = nil) {
        self.id = id
        self.category = category
        self.prompt = prompt
        self.answer = answer
        self.choices = choices
    }
}

struct TriviaQuestionInstance: Identifiable, Hashable {
    let question: TriviaQuestion
    let choices: [String]

    var id: Int { question.id }
}

enum TriviaCatalog {
    static let questions: [TriviaQuestion] = [
        TriviaQuestion(id: 1, category: "Championships", prompt: "What year did Mississippi State win its first NCAA baseball national championship?", answer: "2021.", choices: ["2021.", "2019.", "2018.", "2023."]),
        TriviaQuestion(id: 2, category: "Championships", prompt: "Which head coach guided Mississippi State to the 2021 national championship?", answer: "Chris Lemonis.", choices: ["Chris Lemonis.", "John Cohen.", "Ron Polk.", "Brian O'Connor."]),
        TriviaQuestion(id: 3, category: "Championships", prompt: "Which opponent did Mississippi State sweep in the 2021 College World Series Finals?", answer: "Vanderbilt.", choices: ["Vanderbilt.", "Texas.", "NC State.", "Stanford."]),
        TriviaQuestion(id: 4, category: "Championships", prompt: "What was the score of the deciding Game 3 of the 2021 CWS Finals?", answer: "9-0.", choices: ["9-0.", "5-2.", "7-3.", "4-2."]),
        TriviaQuestion(id: 5, category: "Championships", prompt: "How many College World Series appearances has Mississippi State made?", answer: "12.", choices: ["12.", "10.", "14.", "8."]),
        TriviaQuestion(id: 6, category: "Championships", prompt: "How many SEC regular-season championships has Mississippi State won?", answer: "11.", choices: ["11.", "7.", "9.", "13."]),
        TriviaQuestion(id: 7, category: "Championships", prompt: "When did Mississippi State win its most recent SEC regular-season title?", answer: "2016.", choices: ["2016.", "2018.", "2021.", "2013."]),
        TriviaQuestion(id: 8, category: "Championships", prompt: "How many SEC Tournament championships does Mississippi State own?", answer: "7.", choices: ["7.", "5.", "9.", "11."]),
        TriviaQuestion(id: 9, category: "Championships", prompt: "What was the most recent year Mississippi State won the SEC Tournament?", answer: "2012.", choices: ["2012.", "2016.", "2021.", "2010."]),
        TriviaQuestion(id: 10, category: "Championships", prompt: "How many total NCAA Tournament appearances has Mississippi State made?", answer: "41.", choices: ["41.", "35.", "45.", "30."]),
        TriviaQuestion(id: 11, category: "Championships", prompt: "In which year did Mississippi State make its first College World Series appearance?", answer: "1971.", choices: ["1971.", "1965.", "1979.", "1981."]),
        TriviaQuestion(id: 12, category: "Championships", prompt: "Who pitched the deciding Game 3 win over Vanderbilt in the 2021 CWS Finals?", answer: "Will Bednar.", choices: ["Will Bednar.", "Christian MacLeod.", "Houston Harding.", "Preston Johnson."]),
        TriviaQuestion(id: 13, category: "Championships", prompt: "Who closed out the 2021 CWS clincher for Mississippi State?", answer: "Landon Sims.", choices: ["Landon Sims.", "KC Hunt.", "Cade Smith.", "Jackson Fristoe."]),
        TriviaQuestion(id: 14, category: "Championships", prompt: "Who was the SEC Player of the Year for the 2021 national championship team?", answer: "Tanner Allen.", choices: ["Tanner Allen.", "Rowdey Jordan.", "Logan Tanner.", "Kamren James."]),
        TriviaQuestion(id: 15, category: "Championships", prompt: "In what year did the Bulldogs first host an NCAA Regional?", answer: "1979.", choices: ["1979.", "1985.", "1971.", "1990."]),
        TriviaQuestion(id: 16, category: "Championships", prompt: "How many NCAA Super Regional appearances does Mississippi State own?", answer: "10.", choices: ["10.", "7.", "12.", "8."]),
        TriviaQuestion(id: 17, category: "Championships", prompt: "What was the last year Mississippi State hosted an NCAA Super Regional?", answer: "2021.", choices: ["2021.", "2019.", "2018.", "2016."]),
        TriviaQuestion(id: 18, category: "Championships", prompt: "Mississippi State reached the CWS Finals in 2013 but lost to which opponent?", answer: "UCLA.", choices: ["UCLA.", "Vanderbilt.", "North Carolina.", "Oregon State."]),
        TriviaQuestion(id: 19, category: "Championships", prompt: "Which year was Mississippi State the CWS national runner-up?", answer: "2013.", choices: ["2013.", "1985.", "1997.", "2018."]),
        TriviaQuestion(id: 20, category: "Championships", prompt: "Who coached Mississippi State during the 2013 CWS Finals run?", answer: "John Cohen.", choices: ["John Cohen.", "Ron Polk.", "Chris Lemonis.", "Andy Cannizaro."]),
        TriviaQuestion(id: 21, category: "Championships", prompt: "Which Bulldog hit the home run in the Game 3 win at Charlottesville to send State to Omaha in 2013?", answer: "Hunter Renfroe.", choices: ["Hunter Renfroe.", "Adam Frazier.", "Wes Rea.", "C.T. Bradford."]),
        TriviaQuestion(id: 22, category: "Championships", prompt: "What was the final score when Mississippi State clinched its 2018 CWS opener?", answer: "1-0.", choices: ["1-0.", "3-2.", "4-1.", "2-0."]),
        TriviaQuestion(id: 23, category: "Championships", prompt: "Whose walk-off RBI single beat Washington 1-0 in the 2018 CWS opener?", answer: "Elijah MacNamee.", choices: ["Elijah MacNamee.", "Jake Mangum.", "Jordan Westburg.", "Hunter Stovall."]),
        TriviaQuestion(id: 24, category: "Championships", prompt: "How many runs did Mississippi State plate in the 2018 CWS win over North Carolina?", answer: "12.", choices: ["12.", "8.", "10.", "14."]),
        TriviaQuestion(id: 25, category: "Championships", prompt: "Which Bulldog recorded seven RBIs in the 2018 CWS rout of North Carolina?", answer: "Jordan Westburg.", choices: ["Jordan Westburg.", "Jake Mangum.", "Hunter Stovall.", "Luke Alexander."]),
        TriviaQuestion(id: 26, category: "Championships", prompt: "Who was the interim head coach during the 2018 CWS run?", answer: "Gary Henderson.", choices: ["Gary Henderson.", "Andy Cannizaro.", "John Cohen.", "Chris Lemonis."]),
        TriviaQuestion(id: 27, category: "Championships", prompt: "What award did Gary Henderson win after the 2018 season?", answer: "National Coach of the Year.", choices: ["National Coach of the Year.", "ABCA Coach of the Year.", "SEC Coach of the Year.", "Pat Dye Award."]),
        TriviaQuestion(id: 28, category: "Championships", prompt: "Which Bulldog walk-off hero is famous for the 2018 NCAA Tallahassee Regional comeback?", answer: "Elijah MacNamee.", choices: ["Elijah MacNamee.", "Hunter Stovall.", "Jake Mangum.", "Jordan Westburg."]),
        TriviaQuestion(id: 29, category: "Championships", prompt: "How many wins did the 2019 Mississippi State team rack up?", answer: "52.", choices: ["52.", "44.", "39.", "47."]),
        TriviaQuestion(id: 30, category: "Championships", prompt: "Mississippi State's 2019 super regional opponent at Tallahassee in 2018 was which team?", answer: "Florida State.", choices: ["Florida State.", "Stanford.", "Vanderbilt.", "Louisville."]),
        TriviaQuestion(id: 31, category: "Championships", prompt: "Which year did Mississippi State first appear in the SEC Tournament?", answer: "1981.", choices: ["1981.", "1979.", "1985.", "1977."]),
        TriviaQuestion(id: 32, category: "Championships", prompt: "In how many decades has Mississippi State reached the College World Series?", answer: "Six.", choices: ["Six.", "Five.", "Four.", "Seven."]),
        TriviaQuestion(id: 33, category: "Championships", prompt: "Mississippi State is one of how many programs to reach the CWS in six consecutive decades?", answer: "Four.", choices: ["Four.", "Three.", "Five.", "Two."]),
        TriviaQuestion(id: 34, category: "Championships", prompt: "What was the score of the 2021 super regional clincher over Notre Dame?", answer: "11-7.", choices: ["11-7.", "5-3.", "9-4.", "7-2."]),
        TriviaQuestion(id: 35, category: "Championships", prompt: "Whose walk-off three-run homer beat Notre Dame in the 2021 super regional?", answer: "Tanner Allen.", choices: ["Tanner Allen.", "Logan Tanner.", "Kamren James.", "Rowdey Jordan."]),
        TriviaQuestion(id: 36, category: "Championships", prompt: "How many wins did Will Bednar finish 2021 with?", answer: "9.", choices: ["9.", "7.", "11.", "12."]),
        TriviaQuestion(id: 37, category: "Championships", prompt: "Which conference does Mississippi State compete in?", answer: "Southeastern Conference.", choices: ["Southeastern Conference.", "ACC.", "Big 12.", "American Athletic Conference."]),
        TriviaQuestion(id: 38, category: "Championships", prompt: "When did Mississippi State become a charter member of the SEC?", answer: "1933.", choices: ["1933.", "1900.", "1921.", "1948."]),
        TriviaQuestion(id: 39, category: "Championships", prompt: "Which Bulldog walked off Auburn 5-4 in the 2019 CWS opener?", answer: "Elijah MacNamee.", choices: ["Elijah MacNamee.", "Jake Mangum.", "Jordan Westburg.", "Marshall Gilbert."]),
        TriviaQuestion(id: 40, category: "Championships", prompt: "Which Bulldog homered against Vanderbilt in the 2019 CWS?", answer: "Marshall Gilbert.", choices: ["Marshall Gilbert.", "Tanner Allen.", "Justin Foscue.", "Rowdey Jordan."]),
        TriviaQuestion(id: 41, category: "Legends", prompt: "Which Mississippi State legend won the 1985 Golden Spikes Award?", answer: "Will Clark.", choices: ["Will Clark.", "Rafael Palmeiro.", "Jeff Brantley.", "Bobby Thigpen."]),
        TriviaQuestion(id: 42, category: "Legends", prompt: "What pick was Will Clark in the 1985 MLB Draft?", answer: "Second overall.", choices: ["Second overall.", "First overall.", "Fifth overall.", "Eighth overall."]),
        TriviaQuestion(id: 43, category: "Legends", prompt: "Will Clark was drafted by which MLB franchise in 1985?", answer: "San Francisco Giants.", choices: ["San Francisco Giants.", "Chicago Cubs.", "Texas Rangers.", "Boston Red Sox."]),
        TriviaQuestion(id: 44, category: "Legends", prompt: "Which Bulldog slugger won the SEC Triple Crown in 1984?", answer: "Rafael Palmeiro.", choices: ["Rafael Palmeiro.", "Will Clark.", "Brent Rooker.", "Tommy Raffo."]),
        TriviaQuestion(id: 45, category: "Legends", prompt: "What nickname is given to the Will Clark-Rafael Palmeiro Bulldog tandem?", answer: "Thunder and Lightning.", choices: ["Thunder and Lightning.", "The Bash Brothers.", "Maroon Mashers.", "Boom and Bang."]),
        TriviaQuestion(id: 46, category: "Legends", prompt: "How many career major-league home runs did Rafael Palmeiro finish with?", answer: "569.", choices: ["569.", "473.", "634.", "512."]),
        TriviaQuestion(id: 47, category: "Legends", prompt: "How many career hits did Rafael Palmeiro finish with in the majors?", answer: "3,020.", choices: ["3,020.", "2,890.", "3,142.", "2,758."]),
        TriviaQuestion(id: 48, category: "Legends", prompt: "Rafael Palmeiro was a how many-time MLB All-Star?", answer: "Four-time.", choices: ["Four-time.", "Three-time.", "Six-time.", "Two-time."]),
        TriviaQuestion(id: 49, category: "Legends", prompt: "Rafael Palmeiro won how many Gold Gloves at first base?", answer: "Three.", choices: ["Three.", "Two.", "Four.", "One."]),
        TriviaQuestion(id: 50, category: "Legends", prompt: "Which Bulldog legend pitched for the Boston Red Sox and went 21-10 as a rookie in 1945?", answer: "Boo Ferriss.", choices: ["Boo Ferriss.", "Bunn Hearn.", "Willie Mitchell.", "Buddy Myer."]),
        TriviaQuestion(id: 51, category: "Legends", prompt: "Boo Ferriss made how many MLB All-Star teams?", answer: "Two.", choices: ["Two.", "One.", "Three.", "Four."]),
        TriviaQuestion(id: 52, category: "Legends", prompt: "Which Bulldog won the 1990 Rolaids Relief Man Award with a record 57 saves?", answer: "Bobby Thigpen.", choices: ["Bobby Thigpen.", "Jonathan Papelbon.", "Jay Powell.", "Jeff Brantley."]),
        TriviaQuestion(id: 53, category: "Legends", prompt: "How many saves did Bobby Thigpen record in his record 1990 season?", answer: "57.", choices: ["57.", "46.", "62.", "51."]),
        TriviaQuestion(id: 54, category: "Legends", prompt: "Which Bulldog right-hander finished his MLB career with 368 saves, ninth all-time?", answer: "Jonathan Papelbon.", choices: ["Jonathan Papelbon.", "Bobby Thigpen.", "Jay Powell.", "Brandon Woodruff."]),
        TriviaQuestion(id: 55, category: "Legends", prompt: "Jonathan Papelbon won the 2007 World Series with which team?", answer: "Boston Red Sox.", choices: ["Boston Red Sox.", "Philadelphia Phillies.", "Washington Nationals.", "Chicago Cubs."]),
        TriviaQuestion(id: 56, category: "Legends", prompt: "Which Bulldog pitcher made his MLB debut with San Francisco in 1989 and was a 1990 All-Star?", answer: "Jeff Brantley.", choices: ["Jeff Brantley.", "Bobby Thigpen.", "Carlton Loewer.", "Eric DuBose."]),
        TriviaQuestion(id: 57, category: "Legends", prompt: "Which Mississippi State outfielder won the 1980 World Series with the Phillies?", answer: "Del Unser.", choices: ["Del Unser.", "Jim Howarth.", "Hunter Renfroe.", "Mitch Moreland."]),
        TriviaQuestion(id: 58, category: "Legends", prompt: "Buddy Myer won which American League batting title?", answer: "1935.", choices: ["1935.", "1928.", "1937.", "1939."]),
        TriviaQuestion(id: 59, category: "Legends", prompt: "Buddy Myer hit what batting average to win his 1935 AL title?", answer: ".349.", choices: [".349.", ".321.", ".362.", ".308."]),
        TriviaQuestion(id: 60, category: "Legends", prompt: "Hugh Critz won a World Series ring in 1933 with which team?", answer: "New York Giants.", choices: ["New York Giants.", "New York Yankees.", "Philadelphia Athletics.", "St. Louis Cardinals."]),
        TriviaQuestion(id: 61, category: "Legends", prompt: "Which Mississippi State left-hander was the 1992 #3 overall MLB Draft pick?", answer: "B.J. Wallace.", choices: ["B.J. Wallace.", "Paul Maholm.", "Eric DuBose.", "Carlton Loewer."]),
        TriviaQuestion(id: 62, category: "Legends", prompt: "Which Bulldog right-hander was the 1993 #19 overall draft pick by the Orioles?", answer: "Jay Powell.", choices: ["Jay Powell.", "Pete Young.", "Carlton Loewer.", "Bobby Reed."]),
        TriviaQuestion(id: 63, category: "Legends", prompt: "Jay Powell won a World Series in 1997 with which team?", answer: "Florida Marlins.", choices: ["Florida Marlins.", "Houston Astros.", "Atlanta Braves.", "Texas Rangers."]),
        TriviaQuestion(id: 64, category: "Legends", prompt: "Brent Rooker won the SEC Triple Crown in which season?", answer: "2017.", choices: ["2017.", "2018.", "2016.", "2019."]),
        TriviaQuestion(id: 65, category: "Legends", prompt: "What batting average did Brent Rooker post during his 2017 SEC Triple Crown season?", answer: ".387.", choices: [".387.", ".408.", ".347.", ".365."]),
        TriviaQuestion(id: 66, category: "Legends", prompt: "Brent Rooker is now an MLB All-Star with which franchise?", answer: "Athletics.", choices: ["Athletics.", "Mariners.", "Rangers.", "Cardinals."]),
        TriviaQuestion(id: 67, category: "Legends", prompt: "Brandon Woodruff is a two-time All-Star with which MLB team?", answer: "Milwaukee Brewers.", choices: ["Milwaukee Brewers.", "Cincinnati Reds.", "Texas Rangers.", "Chicago Cubs."]),
        TriviaQuestion(id: 68, category: "Legends", prompt: "Brandon Woodruff famously hit a home run off which Dodgers ace in the 2018 NLCS?", answer: "Clayton Kershaw.", choices: ["Clayton Kershaw.", "Walker Buehler.", "Hyun-Jin Ryu.", "Rich Hill."]),
        TriviaQuestion(id: 69, category: "Legends", prompt: "Nathaniel Lowe won the Gold Glove at first base in which season?", answer: "2023.", choices: ["2023.", "2022.", "2024.", "2021."]),
        TriviaQuestion(id: 70, category: "Legends", prompt: "Nathaniel Lowe won the 2023 World Series with which team?", answer: "Texas Rangers.", choices: ["Texas Rangers.", "Tampa Bay Rays.", "Washington Nationals.", "Boston Red Sox."]),
        TriviaQuestion(id: 71, category: "Legends", prompt: "Jake Mangum recorded how many career hits at Mississippi State?", answer: "383.", choices: ["383.", "356.", "401.", "342."]),
        TriviaQuestion(id: 72, category: "Legends", prompt: "Jake Mangum's career hits total set what kind of record?", answer: "An SEC career hits record.", choices: ["An SEC career hits record.", "An NCAA career hits record.", "A Mississippi State career walks record.", "A career stolen-base record."]),
        TriviaQuestion(id: 73, category: "Legends", prompt: "Jake Mangum made his MLB debut in 2025 with which franchise?", answer: "Tampa Bay Rays.", choices: ["Tampa Bay Rays.", "Pittsburgh Pirates.", "Texas Rangers.", "New York Mets."]),
        TriviaQuestion(id: 74, category: "Legends", prompt: "Which Bulldog won the 2007 Johnny Bench Award?", answer: "Ed Easley.", choices: ["Ed Easley.", "Logan Tanner.", "Mitch Moreland.", "Hunter Renfroe."]),
        TriviaQuestion(id: 75, category: "Legends", prompt: "Which Mississippi State right-hander was the 2013 #13 overall draft pick?", answer: "Hunter Renfroe.", choices: ["Hunter Renfroe.", "Chris Stratton.", "Adam Frazier.", "Brandon Woodruff."]),
        TriviaQuestion(id: 76, category: "Coaches", prompt: "Who is Mississippi State's 19th head baseball coach, hired in 2025?", answer: "Brian O'Connor.", choices: ["Brian O'Connor.", "Chris Lemonis.", "Kevin McMullan.", "John Cohen."]),
        TriviaQuestion(id: 77, category: "Coaches", prompt: "Brian O'Connor previously won a national championship at which school?", answer: "Virginia.", choices: ["Virginia.", "Notre Dame.", "Creighton.", "South Carolina."]),
        TriviaQuestion(id: 78, category: "Coaches", prompt: "Which year did Brian O'Connor win his national championship at Virginia?", answer: "2015.", choices: ["2015.", "2014.", "2017.", "2018."]),
        TriviaQuestion(id: 79, category: "Coaches", prompt: "How many College World Series appearances has Brian O'Connor coached in?", answer: "Seven.", choices: ["Seven.", "Five.", "Eight.", "Six."]),
        TriviaQuestion(id: 80, category: "Coaches", prompt: "Brian O'Connor entered Starkville with what career win total?", answer: "917.", choices: ["917.", "850.", "975.", "888."]),
        TriviaQuestion(id: 81, category: "Coaches", prompt: "Who serves as Mississippi State's associate head coach under Brian O'Connor?", answer: "Kevin McMullan.", choices: ["Kevin McMullan.", "Justin Parker.", "Matt Kirby.", "Mike Roberts."]),
        TriviaQuestion(id: 82, category: "Coaches", prompt: "Kevin McMullan previously coached at which school?", answer: "Virginia.", choices: ["Virginia.", "East Carolina.", "St. John's.", "Notre Dame."]),
        TriviaQuestion(id: 83, category: "Coaches", prompt: "Who is Mississippi State's third-year assistant coach entering 2026?", answer: "Justin Parker.", choices: ["Justin Parker.", "Matt Kirby.", "Kevin McMullan.", "Mike Roberts."]),
        TriviaQuestion(id: 84, category: "Coaches", prompt: "Justin Parker played college baseball at which school?", answer: "Wright State.", choices: ["Wright State.", "Notre Dame.", "Virginia.", "William & Mary."]),
        TriviaQuestion(id: 85, category: "Coaches", prompt: "Which assistant coach joined Brian O'Connor's MSU staff after attending William & Mary?", answer: "Matt Kirby.", choices: ["Matt Kirby.", "Justin Parker.", "Kevin McMullan.", "Travis Reifsnider."]),
        TriviaQuestion(id: 86, category: "Coaches", prompt: "Who is Mississippi State's strength and conditioning coach?", answer: "Scott Shipman.", choices: ["Scott Shipman.", "Jason Wire.", "Mike Roberts.", "Justin Weiss."]),
        TriviaQuestion(id: 87, category: "Coaches", prompt: "Who is the Director of Player Development and Scouting at MSU baseball?", answer: "Mike Roberts.", choices: ["Mike Roberts.", "Justin Weiss.", "Jonathan French.", "Travis Reifsnider."]),
        TriviaQuestion(id: 88, category: "Coaches", prompt: "Who coached Mississippi State to the 2021 national title?", answer: "Chris Lemonis.", choices: ["Chris Lemonis.", "John Cohen.", "Andy Cannizaro.", "Ron Polk."]),
        TriviaQuestion(id: 89, category: "Coaches", prompt: "Who coached the Bulldogs to the SEC regular-season title in 2016?", answer: "John Cohen.", choices: ["John Cohen.", "Chris Lemonis.", "Ron Polk.", "Andy Cannizaro."]),
        TriviaQuestion(id: 90, category: "Coaches", prompt: "Which head coach is often called the Godfather of SEC Baseball?", answer: "Ron Polk.", choices: ["Ron Polk.", "Dudy Noble.", "Pat McMahon.", "Paul Gregory."]),
        TriviaQuestion(id: 91, category: "Coaches", prompt: "Ron Polk was inducted into the ABCA Hall of Fame in which year?", answer: "1995.", choices: ["1995.", "1985.", "2008.", "2002."]),
        TriviaQuestion(id: 92, category: "Coaches", prompt: "Which Bulldog coach earned ABCA Hall of Fame honors with a 267-201-9 record from 1920-47?", answer: "Dudy Noble.", choices: ["Dudy Noble.", "Paul Gregory.", "Ron Polk.", "Pat McMahon."]),
        TriviaQuestion(id: 93, category: "Coaches", prompt: "Paul Gregory won how many SEC titles as MSU head coach?", answer: "Four.", choices: ["Four.", "Three.", "Two.", "Five."]),
        TriviaQuestion(id: 94, category: "Coaches", prompt: "Which MSU coach guided the program through the 1998 College World Series?", answer: "Pat McMahon.", choices: ["Pat McMahon.", "Ron Polk.", "John Cohen.", "Andy Cannizaro."]),
        TriviaQuestion(id: 95, category: "Coaches", prompt: "What college did Brian O'Connor graduate from in 1993?", answer: "Creighton.", choices: ["Creighton.", "Notre Dame.", "Virginia.", "Indiana University of Pennsylvania."]),
        TriviaQuestion(id: 96, category: "Coaches", prompt: "Which assistant coaching role did Brian O'Connor hold at Notre Dame from 2001-03?", answer: "Associate Head Coach.", choices: ["Associate Head Coach.", "Pitching Coach.", "Hitting Coach.", "Recruiting Coordinator."]),
        TriviaQuestion(id: 97, category: "Coaches", prompt: "Kevin McMullan was named National Assistant Coach of the Year in how many seasons?", answer: "Two.", choices: ["Two.", "One.", "Three.", "Four."]),
        TriviaQuestion(id: 98, category: "Dudy Noble", prompt: "What is the full name of Mississippi State's baseball stadium?", answer: "Dudy Noble Field, Polk-DeMent Stadium.", choices: ["Dudy Noble Field, Polk-DeMent Stadium.", "Polk Field.", "Dudy Noble Park.", "DeMent Diamond."]),
        TriviaQuestion(id: 99, category: "Dudy Noble", prompt: "Roughly how many fans does Dudy Noble Field seat?", answer: "15,000+.", choices: ["15,000+.", "8,000.", "20,000.", "11,500."]),
        TriviaQuestion(id: 100, category: "Dudy Noble", prompt: "Dudy Noble Field is known as the what of college baseball?", answer: "The Carnegie Hall of College Baseball.", choices: ["The Carnegie Hall of College Baseball.", "Diamond Dome.", "The Maroon Stadium.", "Cathedral of College Baseball."]),
        TriviaQuestion(id: 101, category: "Dudy Noble", prompt: "What iconic outfield tailgate area gives The Dude its character?", answer: "The Left Field Lounge.", choices: ["The Left Field Lounge.", "The Maroon Patio.", "The Dawg Deck.", "The Outfield Bleachers."]),
        TriviaQuestion(id: 102, category: "Dudy Noble", prompt: "How many permanent Left Field Lounge rigs encircle the outfield at The Dude?", answer: "96.", choices: ["96.", "120.", "75.", "48."]),
        TriviaQuestion(id: 103, category: "Dudy Noble", prompt: "What was the cost of Dudy Noble Field's 2017-19 renovation?", answer: "$68 million.", choices: ["$68 million.", "$35 million.", "$92 million.", "$120 million."]),
        TriviaQuestion(id: 104, category: "Dudy Noble", prompt: "What is the all-time on-campus attendance record set at Dudy Noble Field?", answer: "16,423.", choices: ["16,423.", "14,891.", "18,201.", "11,094."]),
        TriviaQuestion(id: 105, category: "Dudy Noble", prompt: "Mississippi State's record on-campus crowd attended a game against which opponent on April 15, 2023?", answer: "Ole Miss.", choices: ["Ole Miss.", "Alabama.", "LSU.", "Vanderbilt."]),
        TriviaQuestion(id: 106, category: "Dudy Noble", prompt: "Dudy Noble Field was renamed Polk-DeMent Stadium on what date?", answer: "April 27, 1998.", choices: ["April 27, 1998.", "March 15, 1990.", "May 5, 2000.", "April 27, 2008."]),
        TriviaQuestion(id: 107, category: "Dudy Noble", prompt: "The current site of Dudy Noble Field opened in what year?", answer: "1967.", choices: ["1967.", "1955.", "1972.", "1985."]),
        TriviaQuestion(id: 108, category: "Dudy Noble", prompt: "What was the original on-campus baseball field at Mississippi State called?", answer: "Hardy Field.", choices: ["Hardy Field.", "Polk Field.", "Noble Field.", "Davis Field."]),
        TriviaQuestion(id: 109, category: "Dudy Noble", prompt: "Where did Mississippi State play home games in 1965-66 between Hardy Field and Dudy Noble Field?", answer: "Redbird Park.", choices: ["Redbird Park.", "AutoZone Park.", "Trustmark Park.", "Smith-Wills Stadium."]),
        TriviaQuestion(id: 110, category: "Dudy Noble", prompt: "What is the indoor practice facility adjacent to Dudy Noble Field called?", answer: "The Palmeiro Center.", choices: ["The Palmeiro Center.", "The Clark Center.", "The Diamond Dome.", "The Polk Pavilion."]),
        TriviaQuestion(id: 111, category: "Dudy Noble", prompt: "Who provided the lead gift to build the Palmeiro Center?", answer: "Rafael Palmeiro and his wife Lynne.", choices: ["Rafael Palmeiro and his wife Lynne.", "Will Clark.", "John Grisham.", "Jay Powell."]),
        TriviaQuestion(id: 112, category: "Dudy Noble", prompt: "Which best-selling author and MSU alum funded the indoor batting tunnel in 1993?", answer: "John Grisham.", choices: ["John Grisham.", "James Patterson.", "Stephen King.", "Greg Iles."]),
        TriviaQuestion(id: 113, category: "Dudy Noble", prompt: "Dudy Noble Field's scoreboard installed in 2017 measures roughly how many feet wide?", answer: "43.", choices: ["43.", "30.", "55.", "60."]),
        TriviaQuestion(id: 114, category: "Dudy Noble", prompt: "Mississippi State's left-field foul line is how many feet from home plate?", answer: "330.", choices: ["330.", "340.", "320.", "305."]),
        TriviaQuestion(id: 115, category: "Dudy Noble", prompt: "What is the center-field distance at Dudy Noble Field?", answer: "400.", choices: ["400.", "390.", "410.", "385."]),
        TriviaQuestion(id: 116, category: "Records", prompt: "Which Bulldog set the school single-season strikeouts record with 176 Ks in 2019?", answer: "Ethan Small.", choices: ["Ethan Small.", "Will Bednar.", "Eric DuBose.", "Dakota Hudson."]),
        TriviaQuestion(id: 117, category: "Records", prompt: "Bruce Castoria set Mississippi State's single-season home run record in 1981 with how many?", answer: "29.", choices: ["29.", "22.", "25.", "31."]),
        TriviaQuestion(id: 118, category: "Records", prompt: "Which Bulldog led the SEC in batting average as a freshman in 2016?", answer: "Jake Mangum.", choices: ["Jake Mangum.", "Brent Rooker.", "Justin Foscue.", "Nathaniel Lowe."]),
        TriviaQuestion(id: 119, category: "Records", prompt: "Jake Mangum hit what batting average to win the 2016 SEC batting title?", answer: ".408.", choices: [".408.", ".351.", ".362.", ".390."]),
        TriviaQuestion(id: 120, category: "Records", prompt: "Which legendary Bulldog batted .459 to lead the team in 1977?", answer: "Nat Showalter.", choices: ["Nat Showalter.", "Mike Kelley.", "Rafael Palmeiro.", "Will Clark."]),
        TriviaQuestion(id: 121, category: "Records", prompt: "Will Clark hit what batting average during his 1985 Golden Spikes season?", answer: ".420.", choices: [".420.", ".410.", ".383.", ".405."]),
        TriviaQuestion(id: 122, category: "Records", prompt: "Frank Montgomery posted what record-low ERA in 1962?", answer: "0.68.", choices: ["0.68.", "1.07.", "1.46.", "0.85."]),
        TriviaQuestion(id: 123, category: "Records", prompt: "Which Bulldog won 18 games in 1985 to set a single-season record?", answer: "Jeff Brantley.", choices: ["Jeff Brantley.", "Ken Kurtz.", "Don Mundie.", "Bobby Reed."]),
        TriviaQuestion(id: 124, category: "Records", prompt: "Jonathan Holder set Mississippi State's single-season saves record in 2013 with how many?", answer: "21.", choices: ["21.", "14.", "18.", "12."]),
        TriviaQuestion(id: 125, category: "Records", prompt: "Adam Frazier set the MSU single-season at-bat record in 2013 with how many ABs?", answer: "304.", choices: ["304.", "278.", "289.", "295."]),
        TriviaQuestion(id: 126, category: "Records", prompt: "Jake Mangum led NCAA Division I in hits during which season?", answer: "2019.", choices: ["2019.", "2018.", "2017.", "2016."]),
        TriviaQuestion(id: 127, category: "Records", prompt: "Wes Rea owns Mississippi State's career putouts record at first base with how many?", answer: "2,209.", choices: ["2,209.", "1,857.", "2,012.", "2,374."]),
        TriviaQuestion(id: 128, category: "Records", prompt: "Which Bulldog catcher logged 1,280 career putouts behind the plate?", answer: "Logan Tanner.", choices: ["Logan Tanner.", "Dustin Skelton.", "Ed Easley.", "Jack Kruger."]),
        TriviaQuestion(id: 129, category: "Records", prompt: "Jake Mangum holds the career outfield putouts record with how many?", answer: "556.", choices: ["556.", "498.", "412.", "601."]),
        TriviaQuestion(id: 130, category: "Records", prompt: "Mississippi State's single-game runs record is how many, set vs. Jackson State on April 29, 1988?", answer: "32.", choices: ["32.", "27.", "29.", "34."]),
        TriviaQuestion(id: 131, category: "Records", prompt: "Mississippi State's single-game strikeouts (offensive) record was tied at 30 vs. which SEC foe in 1989?", answer: "Kentucky.", choices: ["Kentucky.", "Alabama.", "Auburn.", "LSU."]),
        TriviaQuestion(id: 132, category: "Records", prompt: "Mississippi State set its single-game stolen bases record of 11 vs. Georgia in which year?", answer: "1988.", choices: ["1988.", "1990.", "1983.", "1979."]),
        TriviaQuestion(id: 133, category: "Records", prompt: "Mississippi State's single-season win total record is 56, achieved in which year?", answer: "1985.", choices: ["1985.", "1989.", "1979.", "2019."]),
        TriviaQuestion(id: 134, category: "Records", prompt: "What single-season home run record did the 2025 Bulldogs set?", answer: "103 home runs.", choices: ["103 home runs.", "97 home runs.", "85 home runs.", "120 home runs."]),
        TriviaQuestion(id: 135, category: "Records", prompt: "Mississippi State's single-season strikeouts record by pitchers (817) was set in what year?", answer: "2021.", choices: ["2021.", "2019.", "1997.", "2024."]),
        TriviaQuestion(id: 136, category: "Records", prompt: "Which Bulldog set the single-season triples record with how many three-baggers in 1979?", answer: "33.", choices: ["33.", "26.", "24.", "21."]),
        TriviaQuestion(id: 137, category: "Records", prompt: "Which Bulldog led the team in strikeouts with 145 in 1992?", answer: "B.J. Wallace.", choices: ["B.J. Wallace.", "Gary Rath.", "Eric DuBose.", "Carlton Loewer."]),
        TriviaQuestion(id: 138, category: "Records", prompt: "Eric DuBose's 174 strikeouts came in which season?", answer: "1996.", choices: ["1996.", "1997.", "1995.", "1998."]),
        TriviaQuestion(id: 139, category: "Records", prompt: "Whose Mississippi State pitching season included a 0.81 ERA in 2014?", answer: "Jacob Lindgren.", choices: ["Jacob Lindgren.", "Jonathan Holder.", "Ross Mitchell.", "Trevor Fitts."]),
        TriviaQuestion(id: 140, category: "Records", prompt: "Ross Mitchell went how many wins and losses in 2013?", answer: "13-0.", choices: ["13-0.", "11-2.", "10-3.", "12-1."]),
        TriviaQuestion(id: 141, category: "Records", prompt: "Which Bulldog led MSU in home runs in 2024 with 20?", answer: "Dakota Jordan.", choices: ["Dakota Jordan.", "Hunter Hines.", "David Mershon.", "Ace Reese."]),
        TriviaQuestion(id: 142, category: "Records", prompt: "Mississippi State's 2025 SEC Newcomer of the Year hit how many home runs?", answer: "21.", choices: ["21.", "18.", "25.", "16."]),
        TriviaQuestion(id: 143, category: "Records", prompt: "Pico Kohn led the team in strikeouts in 2025 with how many?", answer: "114.", choices: ["114.", "92.", "133.", "98."]),
        TriviaQuestion(id: 144, category: "Records", prompt: "Ace Reese led the Bulldogs in hits in 2025 with how many?", answer: "80.", choices: ["80.", "92.", "74.", "65."]),
        TriviaQuestion(id: 145, category: "Records", prompt: "Mississippi State's single-season runs record (633) was set in what year?", answer: "1997.", choices: ["1997.", "1989.", "1985.", "1999."]),
        TriviaQuestion(id: 146, category: "Awards", prompt: "Which Bulldog won the 2017 Ferriss Trophy?", answer: "Brent Rooker.", choices: ["Brent Rooker.", "Jake Mangum.", "Hunter Renfroe.", "Dakota Hudson."]),
        TriviaQuestion(id: 147, category: "Awards", prompt: "The Ferriss Trophy honors the top collegiate baseball player from which state?", answer: "Mississippi.", choices: ["Mississippi.", "Alabama.", "Tennessee.", "Louisiana."]),
        TriviaQuestion(id: 148, category: "Awards", prompt: "How many times has Jake Mangum won the Ferriss Trophy?", answer: "Twice.", choices: ["Twice.", "Once.", "Three times.", "Four times."]),
        TriviaQuestion(id: 149, category: "Awards", prompt: "Which Bulldog won the 2024 Ferriss Trophy?", answer: "Dakota Jordan.", choices: ["Dakota Jordan.", "David Mershon.", "Hunter Hines.", "Khal Stephen."]),
        TriviaQuestion(id: 150, category: "Awards", prompt: "Which Bulldog won the Ferriss Trophy in 2012?", answer: "Chris Stratton.", choices: ["Chris Stratton.", "Adam Frazier.", "Hunter Renfroe.", "Jonathan Holder."]),
        TriviaQuestion(id: 151, category: "Awards", prompt: "Brent Rooker won which national hitting award in 2017?", answer: "Collegiate Baseball National Player of the Year.", choices: ["Collegiate Baseball National Player of the Year.", "Golden Spikes Award.", "Dick Howser Trophy.", "Wallace Award."]),
        TriviaQuestion(id: 152, category: "Awards", prompt: "Tanner Allen won the ABCA National Player of the Year in which year?", answer: "2021.", choices: ["2021.", "2019.", "2017.", "2024."]),
        TriviaQuestion(id: 153, category: "Awards", prompt: "Ethan Small was named ABCA National Pitcher of the Year in which year?", answer: "2019.", choices: ["2019.", "2018.", "2020.", "2021."]),
        TriviaQuestion(id: 154, category: "Awards", prompt: "Which Bulldog was Perfect Game National Pitcher of the Year in 2012?", answer: "Chris Stratton.", choices: ["Chris Stratton.", "Jonathan Holder.", "Kendall Graveman.", "Jacob Lindgren."]),
        TriviaQuestion(id: 155, category: "Awards", prompt: "JT Ginn was named Collegiate Baseball National Co-Freshman of the Year in what year?", answer: "2019.", choices: ["2019.", "2018.", "2017.", "2020."]),
        TriviaQuestion(id: 156, category: "Awards", prompt: "Christian MacLeod was named National Co-Freshman of the Year in which season?", answer: "2020.", choices: ["2020.", "2019.", "2021.", "2018."]),
        TriviaQuestion(id: 157, category: "Awards", prompt: "Which Bulldog hitter was named SEC Freshman of the Year in 2016?", answer: "Jake Mangum.", choices: ["Jake Mangum.", "Brent Rooker.", "Justin Foscue.", "Adam Frazier."]),
        TriviaQuestion(id: 158, category: "Awards", prompt: "Which Bulldog was the SEC Newcomer of the Year in 2025?", answer: "Ace Reese.", choices: ["Ace Reese.", "Aidan Teel.", "Ace Stallman.", "Reed Stallman."]),
        TriviaQuestion(id: 159, category: "Awards", prompt: "Which Bulldog won the 2019 Senior CLASS Award?", answer: "Jake Mangum.", choices: ["Jake Mangum.", "Tanner Allen.", "Ethan Small.", "Scotty Dubrule."]),
        TriviaQuestion(id: 160, category: "Awards", prompt: "Who is the first MSU player to win an ABCA Gold Glove?", answer: "Jake Mangum.", choices: ["Jake Mangum.", "Wes Rea.", "Adam Frazier.", "Brett Pirtle."]),
        TriviaQuestion(id: 161, category: "Awards", prompt: "Which 2024 Bulldog SS was a Brooks Wallace Award finalist?", answer: "David Mershon.", choices: ["David Mershon.", "Kamren James.", "Ryan Gridley.", "Adam Frazier."]),
        TriviaQuestion(id: 162, category: "Awards", prompt: "Adam Frazier was a Brooks Wallace Award semifinalist in which season?", answer: "2013.", choices: ["2013.", "2012.", "2014.", "2011."]),
        TriviaQuestion(id: 163, category: "Awards", prompt: "Which Bulldog was a Gregg Olson Award semifinalist in 2014?", answer: "Jacob Lindgren.", choices: ["Jacob Lindgren.", "Jonathan Holder.", "Ross Mitchell.", "Cole Gordon."]),
        TriviaQuestion(id: 164, category: "Awards", prompt: "Which Bulldog catcher won the 2007 Johnny Bench Award?", answer: "Ed Easley.", choices: ["Ed Easley.", "Logan Tanner.", "Andrew Raymond.", "Dustin Skelton."]),
        TriviaQuestion(id: 165, category: "Awards", prompt: "Which Bulldog was the 1985 ABCA National Coach of the Year?", answer: "Ron Polk.", choices: ["Ron Polk.", "Dudy Noble.", "Paul Gregory.", "Pat McMahon."]),
        TriviaQuestion(id: 166, category: "Awards", prompt: "Gary Henderson won the NCBWA National Coach of the Year in what year?", answer: "2018.", choices: ["2018.", "2017.", "2019.", "2016."]),
        TriviaQuestion(id: 167, category: "Awards", prompt: "Chris Lemonis was the 2021 National Coach of the Year by which publication first?", answer: "ABCA.", choices: ["ABCA.", "Baseball America.", "NCBWA.", "D1Baseball."]),
        TriviaQuestion(id: 168, category: "Awards", prompt: "Will Clark was inducted into the National College Baseball Hall of Fame in which year?", answer: "2006.", choices: ["2006.", "2009.", "2014.", "2003."]),
        TriviaQuestion(id: 169, category: "Awards", prompt: "Rafael Palmeiro entered the National College Baseball Hall of Fame in which year?", answer: "2009.", choices: ["2009.", "2006.", "2012.", "2014."]),
        TriviaQuestion(id: 170, category: "Awards", prompt: "Will Clark entered the Omaha College Baseball Hall of Fame in which year?", answer: "2014.", choices: ["2014.", "2008.", "2012.", "2018."]),
        TriviaQuestion(id: 171, category: "Awards", prompt: "Which Bulldog finished as a 2017 Dick Howser Trophy Finalist?", answer: "Brent Rooker.", choices: ["Brent Rooker.", "Jake Mangum.", "Tanner Allen.", "Dakota Hudson."]),
        TriviaQuestion(id: 172, category: "Awards", prompt: "Which Bulldog earned a 2025 Dick Howser Trophy semifinalist nod?", answer: "Ace Reese.", choices: ["Ace Reese.", "Noah Sullivan.", "Hunter Hines.", "Charlie Foster."]),
        TriviaQuestion(id: 173, category: "Awards", prompt: "What award did Noah Sullivan win as 2025 CSC Academic All-American of the Year?", answer: "Academic All-American of the Year.", choices: ["Academic All-American of the Year.", "Senior CLASS Award.", "Brooks Wallace Award.", "Gregg Olson Award."]),
        TriviaQuestion(id: 174, category: "Awards", prompt: "Which Bulldog was an All-American as a freshman in 1983?", answer: "Rafael Palmeiro.", choices: ["Rafael Palmeiro.", "Will Clark.", "Jeff Brantley.", "Pete Young."]),
        TriviaQuestion(id: 175, category: "Awards", prompt: "Which Bulldog was a consensus First Team All-American in 1984 and 1985?", answer: "Rafael Palmeiro.", choices: ["Rafael Palmeiro.", "Will Clark.", "Jeff Brantley.", "Bobby Thigpen."]),
        TriviaQuestion(id: 176, category: "Awards", prompt: "Brent Rooker was a unanimous First Team All-American in which year?", answer: "2017.", choices: ["2017.", "2016.", "2018.", "2015."]),
        TriviaQuestion(id: 177, category: "Awards", prompt: "Which Bulldog third baseman was a 2025 NCBWA First Team All-American?", answer: "Ace Reese.", choices: ["Ace Reese.", "Hunter Hines.", "Noah Sullivan.", "David Mershon."]),
        TriviaQuestion(id: 178, category: "State to Show", prompt: "Which Bulldog right-hander pitched in the Astros organization beginning in 2023?", answer: "J.P. France.", choices: ["J.P. France.", "Brandon Woodruff.", "Chris Stratton.", "Cade Smith."]),
        TriviaQuestion(id: 179, category: "State to Show", prompt: "Which Bulldog catcher debuted with the Yankees and made his MLB debut in 2007?", answer: "Ed Easley.", choices: ["Ed Easley.", "Logan Tanner.", "Craig Tatum.", "Jack Kruger."]),
        TriviaQuestion(id: 180, category: "State to Show", prompt: "Which Bulldog right-hander pitched his MLB debut on May 30, 2016, with the Giants?", answer: "Chris Stratton.", choices: ["Chris Stratton.", "Hunter Renfroe.", "Brandon Woodruff.", "Jonathan Holder."]),
        TriviaQuestion(id: 181, category: "State to Show", prompt: "Which Bulldog made his MLB debut for Texas on April 5, 2024?", answer: "Justin Foscue.", choices: ["Justin Foscue.", "Jordan Westburg.", "JT Ginn.", "Dakota Jordan."]),
        TriviaQuestion(id: 182, category: "State to Show", prompt: "Jordan Westburg made his MLB debut for the Orioles in which year?", answer: "2023.", choices: ["2023.", "2022.", "2024.", "2021."]),
        TriviaQuestion(id: 183, category: "State to Show", prompt: "How many career hits did Will Clark finish with in the MLB? (a Hall of Famer note)", answer: "2,176.", choices: ["2,176.", "2,500.", "1,952.", "2,304."]),
        TriviaQuestion(id: 184, category: "State to Show", prompt: "How many All-Star selections did Will Clark earn?", answer: "Six.", choices: ["Six.", "Four.", "Three.", "Eight."]),
        TriviaQuestion(id: 185, category: "State to Show", prompt: "Buddy Myer played his entire 17-year MLB career mostly for which team?", answer: "Washington Senators.", choices: ["Washington Senators.", "Cleveland Indians.", "Detroit Tigers.", "Boston Red Sox."]),
        TriviaQuestion(id: 186, category: "State to Show", prompt: "Hugh Critz played for the Reds, Giants, and which other team?", answer: "None - only those two.", choices: ["None - only those two.", "Cardinals.", "Yankees.", "Dodgers."]),
        TriviaQuestion(id: 187, category: "State to Show", prompt: "Buck Showalter managed which team to the 2022 NL Manager of the Year award?", answer: "New York Mets.", choices: ["New York Mets.", "Baltimore Orioles.", "Arizona Diamondbacks.", "New York Yankees."]),
        TriviaQuestion(id: 188, category: "State to Show", prompt: "Which Bulldog made the 2023 All-Star team while with the A's?", answer: "Brent Rooker.", choices: ["Brent Rooker.", "Brandon Woodruff.", "Mitch Moreland.", "Jordan Westburg."]),
        TriviaQuestion(id: 189, category: "State to Show", prompt: "Which Bulldog plays third base in the majors for Tampa Bay Rays as of 2025?", answer: "Jake Mangum.", choices: ["Jake Mangum.", "Mitch Moreland.", "Brent Rooker.", "Adam Frazier."]),
        TriviaQuestion(id: 190, category: "State to Show", prompt: "Mitch Moreland won the Gold Glove in which year?", answer: "2016.", choices: ["2016.", "2014.", "2018.", "2012."]),
        TriviaQuestion(id: 191, category: "State to Show", prompt: "How many MLB seasons did Mitch Moreland play?", answer: "12.", choices: ["12.", "10.", "14.", "8."]),
        TriviaQuestion(id: 192, category: "State to Show", prompt: "Which Bulldog right-hander started for the Padres after the 2013 draft?", answer: "Hunter Renfroe.", choices: ["Hunter Renfroe.", "Chris Stratton.", "Brandon Woodruff.", "Connor Powers."]),
        TriviaQuestion(id: 193, category: "State to Show", prompt: "Brandon Woodruff debuted with Milwaukee in which year?", answer: "2017.", choices: ["2017.", "2016.", "2018.", "2015."]),
        TriviaQuestion(id: 194, category: "State to Show", prompt: "Nathaniel Lowe spent his early MLB career with which franchise?", answer: "Tampa Bay Rays.", choices: ["Tampa Bay Rays.", "Texas Rangers.", "Washington Nationals.", "Boston Red Sox."]),
        TriviaQuestion(id: 195, category: "State to Show", prompt: "How many MLB All-Star selections does Jonathan Papelbon have?", answer: "Six.", choices: ["Six.", "Four.", "Five.", "Three."]),
        TriviaQuestion(id: 196, category: "State to Show", prompt: "Adam Frazier played at Mississippi State during which years?", answer: "2011-13.", choices: ["2011-13.", "2012-14.", "2010-12.", "2013-15."]),
        TriviaQuestion(id: 197, category: "State to Show", prompt: "Adam Frazier won the Pirates' Heart and Hustle Award in 2017 and which other year?", answer: "2021.", choices: ["2021.", "2019.", "2018.", "2020."]),
        TriviaQuestion(id: 198, category: "State to Show", prompt: "Jake Mangum's MLB debut came on March 30 of which year?", answer: "2025.", choices: ["2025.", "2024.", "2023.", "2026."]),
        TriviaQuestion(id: 199, category: "State to Show", prompt: "Which Bulldog became the first MLB player to record 4 hits and 2 stolen bases in his first two games?", answer: "Jake Mangum.", choices: ["Jake Mangum.", "Justin Foscue.", "Jordan Westburg.", "Brent Rooker."]),
        TriviaQuestion(id: 200, category: "State to Show", prompt: "Mississippi State has produced how many MLB All-Star players according to the 2026 media guide?", answer: "13.", choices: ["13.", "10.", "16.", "8."]),
        TriviaQuestion(id: 201, category: "State to Show", prompt: "Ken Tatum finished how many runner-up in 1969 AL Rookie of the Year voting?", answer: "Fourth.", choices: ["Fourth.", "Second.", "Third.", "Fifth."]),
        TriviaQuestion(id: 202, category: "State to Show", prompt: "Sammy Ellis was a 1965 MLB All-Star with which team?", answer: "Cincinnati Reds.", choices: ["Cincinnati Reds.", "Cleveland Indians.", "California Angels.", "Boston Red Sox."]),
        TriviaQuestion(id: 203, category: "State to Show", prompt: "Del Unser played 15 MLB seasons; he debuted with which team?", answer: "Washington Senators.", choices: ["Washington Senators.", "Philadelphia Phillies.", "New York Mets.", "Montreal Expos."]),
        TriviaQuestion(id: 204, category: "State to Show", prompt: "Boo Ferriss finished his rookie year with how many wins?", answer: "21.", choices: ["21.", "25.", "17.", "23."]),
        TriviaQuestion(id: 205, category: "State to Show", prompt: "Carlton Loewer was selected in what round in the 1994 MLB Draft?", answer: "First round.", choices: ["First round.", "Second round.", "Third round.", "Fourth round."]),
        TriviaQuestion(id: 206, category: "State to Show", prompt: "Paul Maholm pitched for which team in his MLB debut on June 20, 2005?", answer: "Pittsburgh Pirates.", choices: ["Pittsburgh Pirates.", "Chicago Cubs.", "Atlanta Braves.", "Los Angeles Dodgers."]),
        TriviaQuestion(id: 207, category: "State to Show", prompt: "Paul Maholm logged how many MLB career wins?", answer: "77.", choices: ["77.", "65.", "92.", "100."]),
        TriviaQuestion(id: 208, category: "State to Show", prompt: "Which Bulldog made an MLB All-Star team in 2024 with Baltimore?", answer: "Jordan Westburg.", choices: ["Jordan Westburg.", "Adam Frazier.", "Brent Rooker.", "Mitch Moreland."]),
        TriviaQuestion(id: 209, category: "State to Show", prompt: "Chris Stratton played for how many MLB teams over his career through 2025?", answer: "Seven or more.", choices: ["Seven or more.", "Three.", "Five.", "Two."]),
        TriviaQuestion(id: 210, category: "State to Show", prompt: "Kendall Graveman made his MLB debut for which team?", answer: "Toronto Blue Jays.", choices: ["Toronto Blue Jays.", "Oakland Athletics.", "Seattle Mariners.", "Chicago White Sox."]),
        TriviaQuestion(id: 211, category: "State to Show", prompt: "Dakota Hudson finished what place in 2019 NL Rookie of the Year voting?", answer: "Fourth.", choices: ["Fourth.", "Second.", "Third.", "First."]),
        TriviaQuestion(id: 212, category: "State to Show", prompt: "Jurrangelo Cijntje was selected with what pick in the 2024 MLB Draft?", answer: "15th overall.", choices: ["15th overall.", "10th overall.", "20th overall.", "5th overall."]),
        TriviaQuestion(id: 213, category: "State to Show", prompt: "Khal Stephen was a 2024 draft pick by which franchise?", answer: "Toronto Blue Jays.", choices: ["Toronto Blue Jays.", "Tampa Bay Rays.", "Baltimore Orioles.", "New York Mets."]),
        TriviaQuestion(id: 214, category: "State to Show", prompt: "Which Bulldog made his MLB debut on August 21, 2024 against Tampa Bay?", answer: "JT Ginn.", choices: ["JT Ginn.", "Justin Foscue.", "Jake Mangum.", "Konnor Pilkington."]),
        TriviaQuestion(id: 215, category: "State to Show", prompt: "What team did Konnor Pilkington pitch for in 2025?", answer: "Washington Nationals.", choices: ["Washington Nationals.", "Cleveland Guardians.", "Chicago White Sox.", "Texas Rangers."]),
        TriviaQuestion(id: 216, category: "State to Show", prompt: "Which Bulldog managed in MLB and went 1726-1665?", answer: "Buck Showalter.", choices: ["Buck Showalter.", "Ron Polk.", "Alex Grammas.", "Pat McMahon."]),
        TriviaQuestion(id: 217, category: "State to Show", prompt: "Alex Grammas earned a World Series ring as an assistant coach with which team in 1975?", answer: "Cincinnati Reds.", choices: ["Cincinnati Reds.", "Detroit Tigers.", "Pittsburgh Pirates.", "Milwaukee Brewers."]),
        TriviaQuestion(id: 218, category: "State to Show", prompt: "Willie Mitchell pitched 11 MLB seasons mostly for which team?", answer: "Cleveland.", choices: ["Cleveland.", "Detroit.", "Boston.", "New York Yankees."]),
        TriviaQuestion(id: 219, category: "State to Show", prompt: "Bobby Thigpen finished No. 4 in 1990 AL Cy Young voting and how many in MVP?", answer: "No. 5.", choices: ["No. 5.", "No. 2.", "No. 1.", "No. 10."]),
        TriviaQuestion(id: 220, category: "State to Show", prompt: "Jacob Lindgren made his MLB debut with which team?", answer: "New York Yankees.", choices: ["New York Yankees.", "Boston Red Sox.", "Texas Rangers.", "Detroit Tigers."]),
        TriviaQuestion(id: 221, category: "State to Show", prompt: "Which Bulldog catcher made his MLB debut on May 6, 2021?", answer: "Jack Kruger.", choices: ["Jack Kruger.", "Logan Tanner.", "Craig Tatum.", "Ed Easley."]),
        TriviaQuestion(id: 222, category: "State to Show", prompt: "Cade Smith made his MLB debut with which team after being drafted by the Yankees?", answer: "Cleveland.", choices: ["Cleveland.", "New York Yankees.", "Texas Rangers.", "Toronto Blue Jays."]),
        TriviaQuestion(id: 223, category: "State to Show", prompt: "How many career major league saves does Bobby Thigpen own?", answer: "201.", choices: ["201.", "186.", "237.", "175."]),
        TriviaQuestion(id: 224, category: "State to Show", prompt: "Jeff Brantley earned his MLB All-Star nod in which season?", answer: "1990.", choices: ["1990.", "1988.", "1992.", "1989."]),
        TriviaQuestion(id: 225, category: "State to Show", prompt: "Eight members of which Mississippi State team have reached the MLB level?", answer: "2012.", choices: ["2012.", "2013.", "2019.", "2010."]),
        TriviaQuestion(id: 226, category: "Draft", prompt: "How many all-time MLB draft picks has Mississippi State produced through 2025?", answer: "241.", choices: ["241.", "200.", "265.", "189."]),
        TriviaQuestion(id: 227, category: "Draft", prompt: "Mississippi State has had how many first-round MLB draft picks?", answer: "20.", choices: ["20.", "15.", "25.", "12."]),
        TriviaQuestion(id: 228, category: "Draft", prompt: "In what years did MSU set a school record of 11 players drafted in a single draft?", answer: "2016, 2019, 2024.", choices: ["2016, 2019, 2024.", "2014, 2017, 2021.", "2013, 2018, 2023.", "2015, 2020, 2022."]),
        TriviaQuestion(id: 229, category: "Draft", prompt: "Which Bulldog was the highest MLB draft pick in school history?", answer: "Will Clark - 2nd overall (1985).", choices: ["Will Clark - 2nd overall (1985).", "Rafael Palmeiro - 22nd overall (1985).", "B.J. Wallace - 3rd overall (1992).", "Hunter Renfroe - 13th overall (2013)."]),
        TriviaQuestion(id: 230, category: "Draft", prompt: "Justin Foscue was selected by the Texas Rangers in what year?", answer: "2020.", choices: ["2020.", "2021.", "2019.", "2022."]),
        TriviaQuestion(id: 231, category: "Draft", prompt: "Jordan Westburg was selected at what pick in 2020?", answer: "Comp A, pick 30.", choices: ["Comp A, pick 30.", "First round, pick 5.", "Second round, pick 35.", "Compensatory, pick 40."]),
        TriviaQuestion(id: 232, category: "Draft", prompt: "Will Bednar was drafted 14th overall by which team in 2021?", answer: "San Francisco Giants.", choices: ["San Francisco Giants.", "New York Mets.", "Boston Red Sox.", "Toronto Blue Jays."]),
        TriviaQuestion(id: 233, category: "Draft", prompt: "How many MLB pitchers has MSU had drafted over the past two drafts (2024-25)?", answer: "14.", choices: ["14.", "10.", "18.", "20."]),
        TriviaQuestion(id: 234, category: "Draft", prompt: "Mississippi State's 20 first-round picks rank where nationally?", answer: "11th.", choices: ["11th.", "Top 5.", "Top 15.", "Top 20."]),
        TriviaQuestion(id: 235, category: "Draft", prompt: "Since 2012, MSU has had how many first-round draft selections?", answer: "10.", choices: ["10.", "8.", "12.", "15."]),
        TriviaQuestion(id: 236, category: "Draft", prompt: "How many of Mississippi State's 248 all-time draftees turned down pro ball to return to State?", answer: "63.", choices: ["63.", "47.", "85.", "32."]),
        TriviaQuestion(id: 237, category: "Draft", prompt: "Jake Mangum returned to Mississippi State after being drafted in how many drafts?", answer: "Two.", choices: ["Two.", "One.", "Three.", "Four."]),
        TriviaQuestion(id: 238, category: "Draft", prompt: "Which Bulldog was the 2017 11th round pick by Oakland?", answer: "Ryan Gridley.", choices: ["Ryan Gridley.", "Brent Rooker.", "Jake Mangum.", "Konnor Pilkington."]),
        TriviaQuestion(id: 239, category: "Draft", prompt: "Which Bulldog was a 2022 Comp A pick by Arizona?", answer: "Landon Sims.", choices: ["Landon Sims.", "Logan Tanner.", "Will Bednar.", "Tanner Allen."]),
        TriviaQuestion(id: 240, category: "Draft", prompt: "Logan Tanner was drafted at what round by Cincinnati in 2022?", answer: "Second.", choices: ["Second.", "First.", "Third.", "Fourth."]),
        TriviaQuestion(id: 241, category: "Draft", prompt: "Hunter Renfroe was selected at what pick in 2013?", answer: "13th overall.", choices: ["13th overall.", "20th overall.", "5th overall.", "25th overall."]),
        TriviaQuestion(id: 242, category: "Draft", prompt: "Chris Stratton was selected at what pick by the Giants in 2012?", answer: "20th overall.", choices: ["20th overall.", "10th overall.", "30th overall.", "15th overall."]),
        TriviaQuestion(id: 243, category: "Draft", prompt: "Dakota Hudson went in the compensatory first round to which team in 2016?", answer: "St. Louis Cardinals.", choices: ["St. Louis Cardinals.", "Texas Rangers.", "Tampa Bay Rays.", "New York Yankees."]),
        TriviaQuestion(id: 244, category: "Draft", prompt: "Ethan Small was drafted in what round in 2019?", answer: "First round, pick 28.", choices: ["First round, pick 28.", "First round, pick 14.", "Second round, pick 55.", "Compensatory pick 35."]),
        TriviaQuestion(id: 245, category: "Draft", prompt: "Mississippi State's 1985 draft saw how many first-round picks?", answer: "Two.", choices: ["Two.", "One.", "Three.", "Four."]),
        TriviaQuestion(id: 246, category: "Draft", prompt: "Eric DuBose was selected first round (#21) by which team in 1997?", answer: "Oakland Athletics.", choices: ["Oakland Athletics.", "Texas Rangers.", "New York Yankees.", "Boston Red Sox."]),
        TriviaQuestion(id: 247, category: "Draft", prompt: "Matt Ginter was drafted first round by which team in 1999?", answer: "Chicago White Sox.", choices: ["Chicago White Sox.", "Cleveland Indians.", "New York Mets.", "Detroit Tigers."]),
        TriviaQuestion(id: 248, category: "Draft", prompt: "Jay Powell was drafted by which team in the 1993 first round?", answer: "Baltimore Orioles.", choices: ["Baltimore Orioles.", "Florida Marlins.", "Texas Rangers.", "Washington Senators."]),
        TriviaQuestion(id: 249, category: "Draft", prompt: "B.J. Wallace was drafted by which franchise with the No. 3 pick in 1992?", answer: "Washington (Expos).", choices: ["Washington (Expos).", "Houston Astros.", "New York Mets.", "Baltimore Orioles."]),
        TriviaQuestion(id: 250, category: "Draft", prompt: "Mississippi State's 2024 draft included how many players drafted?", answer: "11.", choices: ["11.", "9.", "13.", "7."]),
        TriviaQuestion(id: 251, category: "Draft", prompt: "Mississippi State's 2025 draft included how many players drafted?", answer: "Seven.", choices: ["Seven.", "Six.", "Eight.", "Five."]),
        TriviaQuestion(id: 252, category: "Draft", prompt: "Pico Kohn was drafted in 2025 by which team?", answer: "New York Yankees.", choices: ["New York Yankees.", "New York Mets.", "Texas Rangers.", "Pittsburgh Pirates."]),
        TriviaQuestion(id: 253, category: "Draft", prompt: "Hunter Hines was drafted in 2025 by which team?", answer: "Washington Nationals.", choices: ["Washington Nationals.", "Boston Red Sox.", "Tampa Bay Rays.", "Texas Rangers."]),
        TriviaQuestion(id: 254, category: "Seasons", prompt: "What was Mississippi State's overall record in 2025?", answer: "36-23.", choices: ["36-23.", "40-23.", "32-25.", "44-20."]),
        TriviaQuestion(id: 255, category: "Seasons", prompt: "What was MSU's overall record during the 2021 championship season?", answer: "50-18.", choices: ["50-18.", "46-15.", "52-15.", "48-19."]),
        TriviaQuestion(id: 256, category: "Seasons", prompt: "In 2019, the Bulldogs finished with what overall record?", answer: "52-15.", choices: ["52-15.", "48-17.", "44-22.", "50-18."]),
        TriviaQuestion(id: 257, category: "Seasons", prompt: "Mississippi State's 2013 team finished how many games over .500?", answer: "31.", choices: ["31.", "27.", "35.", "22."]),
        TriviaQuestion(id: 258, category: "Seasons", prompt: "Mississippi State's all-time program win total entering 2026 is approximately what?", answer: "2,883.", choices: ["2,883.", "2,500.", "3,000.", "2,750."]),
        TriviaQuestion(id: 259, category: "Seasons", prompt: "What year did Mississippi State first play baseball as a varsity sport?", answer: "1885.", choices: ["1885.", "1890.", "1900.", "1875."]),
        TriviaQuestion(id: 260, category: "Seasons", prompt: "What is Mississippi State's all-time SEC winning percentage?", answer: ".533.", choices: [".533.", ".500.", ".550.", ".620."]),
        TriviaQuestion(id: 261, category: "Seasons", prompt: "Mississippi State's first SEC tournament title came in which year?", answer: "1979.", choices: ["1979.", "1985.", "1981.", "1976."]),
        TriviaQuestion(id: 262, category: "Seasons", prompt: "Mississippi State's 2012 SEC Tournament championship came under which coach?", answer: "John Cohen.", choices: ["John Cohen.", "Ron Polk.", "Andy Cannizaro.", "Pat McMahon."]),
        TriviaQuestion(id: 263, category: "Seasons", prompt: "In 2016, who was the Mississippi State coach when they won the SEC regular-season title?", answer: "John Cohen.", choices: ["John Cohen.", "Andy Cannizaro.", "Chris Lemonis.", "Pat McMahon."]),
        TriviaQuestion(id: 264, category: "Seasons", prompt: "Which Bulldog led the team in batting average in 2024?", answer: "Dakota Jordan.", choices: ["Dakota Jordan.", "David Mershon.", "Hunter Hines.", "Slate Alford."]),
        TriviaQuestion(id: 265, category: "Seasons", prompt: "Which Bulldog led the team in batting average in 2023?", answer: "Colton Ledbetter.", choices: ["Colton Ledbetter.", "Hunter Hines.", "Slate Alford.", "Amani Larry."]),
        TriviaQuestion(id: 266, category: "Seasons", prompt: "What batting average did Ace Reese hit in 2025?", answer: ".352.", choices: [".352.", ".380.", ".321.", ".301."]),
        TriviaQuestion(id: 267, category: "Seasons", prompt: "How many wins did Mississippi State post in 2024?", answer: "40.", choices: ["40.", "36.", "44.", "32."]),
        TriviaQuestion(id: 268, category: "Seasons", prompt: "How many SEC wins did the 2025 Bulldogs finish with?", answer: "15.", choices: ["15.", "12.", "18.", "20."]),
        TriviaQuestion(id: 269, category: "Seasons", prompt: "Which year did Mississippi State have its first 40-win season under Ron Polk?", answer: "1976.", choices: ["1976.", "1979.", "1978.", "1985."]),
        TriviaQuestion(id: 270, category: "Seasons", prompt: "How many runs did MSU score in 2019 to break the .315 batting mark?", answer: "530.", choices: ["530.", "498.", "555.", "612."]),
        TriviaQuestion(id: 271, category: "Seasons", prompt: "What was Mississippi State's overall record in 2018?", answer: "39-29.", choices: ["39-29.", "44-25.", "36-31.", "42-22."]),
        TriviaQuestion(id: 272, category: "Seasons", prompt: "In 2025, Mississippi State played which postseason regional?", answer: "Tallahassee.", choices: ["Tallahassee.", "Hattiesburg.", "Auburn.", "Starkville."]),
        TriviaQuestion(id: 273, category: "Seasons", prompt: "Mississippi State's 2025 SEC Tournament showed what result?", answer: "0-1.", choices: ["0-1.", "1-2.", "2-1.", "3-2."]),
        TriviaQuestion(id: 274, category: "Seasons", prompt: "The 2026 schedule will be Mississippi State's how many-th season of baseball?", answer: "135th.", choices: ["135th.", "125th.", "145th.", "140th."]),
        TriviaQuestion(id: 275, category: "Seasons", prompt: "What was MSU's all-time program winning percentage entering 2026?", answer: ".628.", choices: [".628.", ".575.", ".682.", ".510."]),
        TriviaQuestion(id: 276, category: "Seasons", prompt: "Who managed the Bulldogs to the 1998 College World Series?", answer: "Pat McMahon.", choices: ["Pat McMahon.", "Ron Polk.", "John Cohen.", "Chris Lemonis."]),
        TriviaQuestion(id: 277, category: "Seasons", prompt: "When did Ron Polk win his first SEC title at Mississippi State?", answer: "1979.", choices: ["1979.", "1985.", "1987.", "1976."]),
        TriviaQuestion(id: 278, category: "Seasons", prompt: "Ron Polk earned how many career wins total across all stops?", answer: "1,373.", choices: ["1,373.", "1,200.", "1,500.", "1,250."]),
        TriviaQuestion(id: 279, category: "Seasons", prompt: "Mississippi State's 2016 SEC regular-season title was secured with how many SEC wins?", answer: "21.", choices: ["21.", "18.", "23.", "19."]),
        TriviaQuestion(id: 280, category: "Seasons", prompt: "Mississippi State's 1989 team won how many games?", answer: "54.", choices: ["54.", "47.", "61.", "50."]),
        TriviaQuestion(id: 281, category: "Seasons", prompt: "Which Mississippi State season set the program record for runs scored (633)?", answer: "1997.", choices: ["1997.", "1989.", "1999.", "2019."]),
        TriviaQuestion(id: 282, category: "Seasons", prompt: "The Bulldogs led the SEC in batting average in 1999 with what mark?", answer: ".335.", choices: [".335.", ".325.", ".308.", ".347."]),
        TriviaQuestion(id: 283, category: "Seasons", prompt: "How many home runs did the 1989 Bulldogs hit (single-season record at the time)?", answer: "96.", choices: ["96.", "85.", "103.", "75."]),
        TriviaQuestion(id: 284, category: "Seasons", prompt: "Mississippi State's 1985 team finished with what record?", answer: "50-15.", choices: ["50-15.", "46-12.", "47-18.", "44-16."]),
        TriviaQuestion(id: 285, category: "Seasons", prompt: "Who managed the 2007 College World Series team?", answer: "Ron Polk.", choices: ["Ron Polk.", "John Cohen.", "Pat McMahon.", "Andy Cannizaro."]),
        TriviaQuestion(id: 286, category: "Seasons", prompt: "Mississippi State's 2007 CWS team beat which SEC team to earn a CWS berth?", answer: "Clemson.", choices: ["Clemson.", "Florida.", "Vanderbilt.", "Ole Miss."]),
        TriviaQuestion(id: 287, category: "Seasons", prompt: "What year did Ron Polk return as MSU's head coach for his second stint?", answer: "2002.", choices: ["2002.", "2000.", "1999.", "2004."]),
        TriviaQuestion(id: 288, category: "Seasons", prompt: "Which Bulldog led the team with 22 home runs in 1989?", answer: "Tommy Raffo.", choices: ["Tommy Raffo.", "Jody Hurst.", "Burke Masters.", "Pete Young."]),
        TriviaQuestion(id: 289, category: "Seasons", prompt: "Mississippi State posted what record in 2022?", answer: "26-30.", choices: ["26-30.", "30-25.", "34-22.", "22-32."]),
        TriviaQuestion(id: 290, category: "Seasons", prompt: "How many SEC wins did Mississippi State post in 2022?", answer: "8.", choices: ["8.", "10.", "12.", "6."]),
        TriviaQuestion(id: 291, category: "Seasons", prompt: "What was Mississippi State's overall record in 2023?", answer: "27-26.", choices: ["27-26.", "30-22.", "35-19.", "24-29."]),
        TriviaQuestion(id: 292, category: "Seasons", prompt: "Which Mississippi State team finished 39-19-1 in 1962?", answer: "Mississippi State's 1962 SEC champions.", choices: ["Mississippi State's 1962 SEC champions.", "1957 SEC champions.", "1964 NCAA Regional team.", "1955 conference team."]),
        TriviaQuestion(id: 293, category: "Seasons", prompt: "In 1953, who led MSU with 6 wins and a 3.20 ERA?", answer: "Curt Monroe.", choices: ["Curt Monroe.", "Floyd Johnson.", "Phil Brandon.", "Charlie Williams."]),
        TriviaQuestion(id: 294, category: "History", prompt: "Which Bulldog homered in the deciding Game 3 of the 2021 CWS Finals?", answer: "Logan Tanner.", choices: ["Logan Tanner.", "Tanner Allen.", "Kamren James.", "Rowdey Jordan."]),
        TriviaQuestion(id: 295, category: "History", prompt: "Which 1985 Bulldog future MLB closer began his Diamond Dawg career as a position player?", answer: "Bobby Thigpen.", choices: ["Bobby Thigpen.", "Jeff Brantley.", "Jay Powell.", "Pete Young."]),
        TriviaQuestion(id: 296, category: "History", prompt: "Which Bulldog was the 1991 SEC Pitcher of the Year? (Trick: SEC POY started in 2003 - this question is about MSU's first SEC POY)", answer: "Chris Stratton.", choices: ["Chris Stratton.", "Eric DuBose.", "Paul Maholm.", "B.J. Wallace."]),
        TriviaQuestion(id: 297, category: "History", prompt: "Which Bulldog two-way player was a 2025 Dick Howser Trophy semifinalist?", answer: "Noah Sullivan.", choices: ["Noah Sullivan.", "Ace Reese.", "Hunter Hines.", "Charlie Foster."]),
        TriviaQuestion(id: 298, category: "History", prompt: "Who is the only Bulldog to record 200+ MLB saves?", answer: "Bobby Thigpen.", choices: ["Bobby Thigpen.", "Jonathan Papelbon.", "Jay Powell.", "Jeff Brantley."]),
        TriviaQuestion(id: 299, category: "History", prompt: "Which Bulldog catcher set the single-season putouts record (685) in 2021?", answer: "Logan Tanner.", choices: ["Logan Tanner.", "Dustin Skelton.", "Ed Easley.", "Andrew Raymond."]),
        TriviaQuestion(id: 300, category: "History", prompt: "Who is Mississippi State's career home runs leader entering 2026? (notable program HR leader)", answer: "Rafael Palmeiro.", choices: ["Rafael Palmeiro.", "Will Clark.", "Brent Rooker.", "Bruce Castoria."]),
        TriviaQuestion(id: 301, category: "History", prompt: "Which Bulldog OF was inducted into the MSU Sports Hall of Fame in 2020?", answer: "Bobby Thigpen.", choices: ["Bobby Thigpen.", "Jeff Brantley.", "Mark Gillaspie.", "Mike Kelley."]),
        TriviaQuestion(id: 302, category: "History", prompt: "Tommy Raffo entered the MSU Sports Hall of Fame in what year?", answer: "2025.", choices: ["2025.", "2018.", "2020.", "2022."]),
        TriviaQuestion(id: 303, category: "History", prompt: "Which Bulldog hit the Game 6 grand slam for MSU vs. Vanderbilt in the 2021 CWS Finals?", answer: "Kamren James.", choices: ["Kamren James.", "Tanner Allen.", "Rowdey Jordan.", "Brad Cumbest."]),
        TriviaQuestion(id: 304, category: "History", prompt: "Which Bulldog tossed 10 innings vs. Tulsa in the 1971 CWS?", answer: "Jerry Thompson.", choices: ["Jerry Thompson.", "Mike Proffitt.", "Brantley Jones.", "Bruce Irvin."]),
        TriviaQuestion(id: 305, category: "History", prompt: "Frank Montgomery struck out how many in 1962 to lead MSU?", answer: "102.", choices: ["102.", "88.", "94.", "115."]),
        TriviaQuestion(id: 306, category: "History", prompt: "Who managed Mississippi State's 1962 SEC championship team?", answer: "Paul Gregory.", choices: ["Paul Gregory.", "Dudy Noble.", "Ron Polk.", "Pat McMahon."]),
        TriviaQuestion(id: 307, category: "History", prompt: "Who is the all-time hits leader at Mississippi State (career)?", answer: "Jake Mangum.", choices: ["Jake Mangum.", "Adam Frazier.", "Rafael Palmeiro.", "Will Clark."]),
        TriviaQuestion(id: 308, category: "History", prompt: "Bobby Thigpen recorded how many saves at MSU in 1985?", answer: "Seven.", choices: ["Seven.", "Five.", "Nine.", "Ten."]),
        TriviaQuestion(id: 309, category: "History", prompt: "Who is the all-time career stolen bases leader at MSU? (notable)", answer: "Mike Kelley.", choices: ["Mike Kelley.", "Jake Mangum.", "Bobby Croswell.", "Jacob Robson."]),
        TriviaQuestion(id: 310, category: "History", prompt: "Which Bulldog third baseman led the SEC with 11 home runs in 1971?", answer: "Phil Still.", choices: ["Phil Still.", "Bobby Croswell.", "Ted Milton.", "Donnie Davis."]),
        TriviaQuestion(id: 311, category: "History", prompt: "Will Clark set the single-season runs scored record before being broken by whom in 1991?", answer: "Rafael Palmeiro.", choices: ["Rafael Palmeiro.", "Tommy Raffo.", "Pete Young.", "Steve Hegan."]),
        TriviaQuestion(id: 312, category: "History", prompt: "Sammy Ellis pitched at MSU in what year?", answer: "1961.", choices: ["1961.", "1962.", "1960.", "1963."]),
        TriviaQuestion(id: 313, category: "History", prompt: "Buddy Myer played his college baseball at MSU in what years?", answer: "1922-24.", choices: ["1922-24.", "1925-27.", "1920-22.", "1923-25."]),
        TriviaQuestion(id: 314, category: "History", prompt: "Which Bulldog third baseman led the SEC in walks in 1995?", answer: "Brian Clark.", choices: ["Brian Clark.", "Adam Piatt.", "Drew Williams.", "Rex Buckner."]),
        TriviaQuestion(id: 315, category: "History", prompt: "Which Bulldog was the 2007 Ferriss Trophy winner?", answer: "Ed Easley.", choices: ["Ed Easley.", "Mitch Moreland.", "Jeffrey Rea.", "Thomas Berkery."]),
        TriviaQuestion(id: 316, category: "History", prompt: "Mitch Moreland's Mississippi State career spanned which years?", answer: "2005-07.", choices: ["2005-07.", "2006-08.", "2004-06.", "2007-09."]),
        TriviaQuestion(id: 317, category: "History", prompt: "Who is the only Bulldog to hit 4-for-4 with multiple steals in his first two MLB career games?", answer: "Jake Mangum.", choices: ["Jake Mangum.", "Adam Frazier.", "Brent Rooker.", "Justin Foscue."]),
        TriviaQuestion(id: 318, category: "History", prompt: "Which Bulldog finished 4th in 1945 AL MVP voting?", answer: "Boo Ferriss.", choices: ["Boo Ferriss.", "Buddy Myer.", "Hugh Critz.", "Fred Walters."]),
        TriviaQuestion(id: 319, category: "History", prompt: "Boo Ferriss's MSU career years were?", answer: "1941-42.", choices: ["1941-42.", "1943-44.", "1940-41.", "1942-43."]),
        TriviaQuestion(id: 320, category: "History", prompt: "Which Bulldog won the 1985 SEC Player of the Week three times before SEC POY existed?", answer: "Will Clark.", choices: ["Will Clark.", "Rafael Palmeiro.", "Jeff Brantley.", "Bobby Thigpen."]),
        TriviaQuestion(id: 321, category: "History", prompt: "Phil Still's career years at Mississippi State were?", answer: "1968-71.", choices: ["1968-71.", "1969-71.", "1970-72.", "1967-70."]),
        TriviaQuestion(id: 322, category: "History", prompt: "Which Bulldog hit the only home run in MSU's 1971 CWS run?", answer: "Phil Still.", choices: ["Phil Still.", "Bobby Croswell.", "Ted Milton.", "Donnie Davis."]),
        TriviaQuestion(id: 323, category: "History", prompt: "Will Clark's MSU career years were?", answer: "1983-85.", choices: ["1983-85.", "1984-86.", "1982-84.", "1985-87."]),
        TriviaQuestion(id: 324, category: "History", prompt: "Rafael Palmeiro and Will Clark were teammates at MSU for how many seasons?", answer: "Three.", choices: ["Three.", "Two.", "Four.", "One."]),
        TriviaQuestion(id: 325, category: "History", prompt: "Which Bulldog set the freshman batting average record at .459 in 1977?", answer: "Nat Showalter.", choices: ["Nat Showalter.", "Mike Kelley.", "Del Bender.", "Russ Aldrich."]),
        TriviaQuestion(id: 326, category: "Misc", prompt: "Mississippi State's mascot nickname for baseball is?", answer: "Diamond Dawgs.", choices: ["Diamond Dawgs.", "Maroon Nine.", "Bulldog Bats.", "Dudy Dogs."]),
        TriviaQuestion(id: 327, category: "Misc", prompt: "What is Mississippi State's school nickname?", answer: "Bulldogs.", choices: ["Bulldogs.", "Tigers.", "Rebels.", "Gators."]),
        TriviaQuestion(id: 328, category: "Misc", prompt: "Mississippi State's school colors are?", answer: "Maroon and White.", choices: ["Maroon and White.", "Red and Black.", "Gold and Maroon.", "Maroon and Gold."]),
        TriviaQuestion(id: 329, category: "Misc", prompt: "Mississippi State University is located in?", answer: "Starkville, Mississippi.", choices: ["Starkville, Mississippi.", "Oxford, Mississippi.", "Hattiesburg, Mississippi.", "Jackson, Mississippi."]),
        TriviaQuestion(id: 330, category: "Misc", prompt: "What is Mississippi State's logo/mark commonly known as on uniforms?", answer: "M over S.", choices: ["M over S.", "Bulldog head.", "Cowbell logo.", "Diamond M."]),
        TriviaQuestion(id: 331, category: "Misc", prompt: "Approximately how many students attend Mississippi State?", answer: "23,563.", choices: ["23,563.", "18,000.", "30,000.", "26,500."]),
        TriviaQuestion(id: 332, category: "Misc", prompt: "Who is Mississippi State's president?", answer: "Dr. Mark E. Keenum.", choices: ["Dr. Mark E. Keenum.", "Zac Selmon.", "Dr. Brent Fountain.", "Logan Lowery."]),
        TriviaQuestion(id: 333, category: "Misc", prompt: "Who is Mississippi State's Athletic Director?", answer: "Zac Selmon.", choices: ["Zac Selmon.", "John Cohen.", "Greg Byrne.", "Larry Templeton."]),
        TriviaQuestion(id: 334, category: "Misc", prompt: "Mississippi State was founded in what year?", answer: "1878.", choices: ["1878.", "1865.", "1890.", "1855."]),
        TriviaQuestion(id: 335, category: "Misc", prompt: "What is Mississippi State's NCAA Faculty Athletics Rep?", answer: "Dr. Brent Fountain.", choices: ["Dr. Brent Fountain.", "Dr. Mark Keenum.", "Logan Lowery.", "Zac Selmon."]),
        TriviaQuestion(id: 336, category: "Misc", prompt: "Mississippi State's primary baseball communications contact is?", answer: "Logan Lowery.", choices: ["Logan Lowery.", "Caly Haskins.", "Emma Claire Markham.", "Justin Armistead."]),
        TriviaQuestion(id: 337, category: "Misc", prompt: "The 2026 Mississippi State University Baseball Record Book was compiled and edited by?", answer: "Logan Lowery and Caly Haskins.", choices: ["Logan Lowery and Caly Haskins.", "Justin Armistead and Mike Roberts.", "Brian O'Connor and Logan Lowery.", "Caly Haskins and Justin Weiss."]),
        TriviaQuestion(id: 338, category: "Misc", prompt: "Who is the Mississippi State Operations Coordinator?", answer: "Justin Weiss.", choices: ["Justin Weiss.", "Mike Roberts.", "Jonathan French.", "Travis Reifsnider."]),
        TriviaQuestion(id: 339, category: "Misc", prompt: "Mississippi State's athletic trainer for baseball is?", answer: "Jason Wire.", choices: ["Jason Wire.", "Scott Shipman.", "Justin Weiss.", "Mike Roberts."]),
        TriviaQuestion(id: 340, category: "Misc", prompt: "Brian O'Connor's wife's name is?", answer: "Cindy.", choices: ["Cindy.", "Sandra.", "Lynne.", "Maggie."]),
        TriviaQuestion(id: 341, category: "Misc", prompt: "Kevin McMullan's son currently plays baseball at which college?", answer: "Liberty.", choices: ["Liberty.", "Virginia.", "Mississippi State.", "South Carolina."]),
        TriviaQuestion(id: 342, category: "Misc", prompt: "Brian O'Connor is from which city?", answer: "Council Bluffs, Iowa.", choices: ["Council Bluffs, Iowa.", "Omaha, Nebraska.", "Lincoln, Nebraska.", "Des Moines, Iowa."]),
        TriviaQuestion(id: 343, category: "Misc", prompt: "Brian O'Connor was hired at MSU on what date?", answer: "June 1, 2025.", choices: ["June 1, 2025.", "June 15, 2024.", "May 30, 2025.", "July 1, 2025."]),
        TriviaQuestion(id: 344, category: "Misc", prompt: "Mississippi State's official baseball website domain is?", answer: "HailState.com/baseball.", choices: ["HailState.com/baseball.", "MSUBulldogs.com.", "msstate.edu/sports.", "StarkvilleSports.com."]),
        TriviaQuestion(id: 345, category: "Misc", prompt: "The MSU baseball social-media handle is?", answer: "@HailStateBB.", choices: ["@HailStateBB.", "@MSUBaseball.", "@MSStateDawgs.", "@DiamondDawgs."]),
        TriviaQuestion(id: 346, category: "Misc", prompt: "Who was MSU's 2025 Newsom Award winner?", answer: "Aaron Downs.", choices: ["Aaron Downs.", "Ace Reese.", "Ross Highfill.", "Noah Sullivan."]),
        TriviaQuestion(id: 347, category: "Misc", prompt: "MSU's 2024 Newsom Award winner was?", answer: "Evan Siary.", choices: ["Evan Siary.", "Brooks Auger.", "David Mershon.", "Dakota Jordan."]),
        TriviaQuestion(id: 348, category: "CWS", prompt: "Mississippi State's single-game CWS RBI record of 7 was set by which Bulldog?", answer: "Jordan Westburg.", choices: ["Jordan Westburg.", "Tanner Allen.", "Jake Mangum.", "Brad Cumbest."]),
        TriviaQuestion(id: 349, category: "CWS", prompt: "Whose two-run triple beat Texas 2-1 to open the 2021 CWS?", answer: "Brad Cumbest.", choices: ["Brad Cumbest.", "Tanner Allen.", "Logan Tanner.", "Rowdey Jordan."]),
        TriviaQuestion(id: 350, category: "CWS", prompt: "Mississippi State played its first CWS Finals game in what year?", answer: "2013.", choices: ["2013.", "2021.", "2018.", "1985."]),
        TriviaQuestion(id: 351, category: "CWS", prompt: "Who pitched 10 innings vs. Tulsa in MSU's first-ever CWS game?", answer: "Jerry Thompson.", choices: ["Jerry Thompson.", "Mike Proffitt.", "Bruce Irvin.", "Brantley Jones."]),
        TriviaQuestion(id: 352, category: "CWS", prompt: "Mississippi State's leading CWS career hitter is widely considered to be?", answer: "Will Clark.", choices: ["Will Clark.", "Rafael Palmeiro.", "Tanner Allen.", "Jordan Westburg."]),
        TriviaQuestion(id: 353, category: "CWS", prompt: "Will Clark went 3-for-4 in MSU's 12-3 1985 CWS opener against which team?", answer: "Oklahoma State.", choices: ["Oklahoma State.", "Texas.", "Arkansas.", "Miami."]),
        TriviaQuestion(id: 354, category: "CWS", prompt: "Mississippi State's 2018 CWS run included a 1-0 win over which team?", answer: "Washington.", choices: ["Washington.", "Florida.", "North Carolina.", "Oregon State."]),
        TriviaQuestion(id: 355, category: "CWS", prompt: "Whose CWS season included a 12-0 win over UNC in 2018?", answer: "Mississippi State's 2018 Bulldogs.", choices: ["Mississippi State's 2018 Bulldogs.", "2019 Bulldogs.", "2013 Bulldogs.", "1985 Bulldogs."]),
        TriviaQuestion(id: 356, category: "CWS", prompt: "Which Bulldog homered in the 12-2 win over UNC in 2018?", answer: "Jordan Westburg.", choices: ["Jordan Westburg.", "Hunter Stovall.", "Jake Mangum.", "Luke Alexander."]),
        TriviaQuestion(id: 357, category: "CWS", prompt: "Who was Mississippi State's winning pitcher in the 12-2 rout of UNC in 2018?", answer: "Konnor Pilkington.", choices: ["Konnor Pilkington.", "Ethan Small.", "JT Ginn.", "Cole Gordon."]),
        TriviaQuestion(id: 358, category: "CWS", prompt: "Mississippi State's first CWS win in program history came over which team?", answer: "Cal State Fullerton.", choices: ["Cal State Fullerton.", "Tulsa.", "BYU.", "Texas."]),
        TriviaQuestion(id: 359, category: "CWS", prompt: "What year did Mississippi State first win an NCAA Super Regional?", answer: "2007.", choices: ["2007.", "2013.", "1985.", "1997."]),
        TriviaQuestion(id: 360, category: "CWS", prompt: "Mississippi State's 2013 super regional was played at?", answer: "Charlottesville, Virginia.", choices: ["Charlottesville, Virginia.", "Tallahassee, Florida.", "Baton Rouge, Louisiana.", "Starkville, Mississippi."]),
        TriviaQuestion(id: 361, category: "CWS", prompt: "Mississippi State's 2007 CWS opponent in Game 1 was?", answer: "North Carolina.", choices: ["North Carolina.", "Louisville.", "UC Irvine.", "Oregon State."]),
        TriviaQuestion(id: 362, category: "CWS", prompt: "Mitch Moreland homered against which CWS opponent in 2007?", answer: "North Carolina.", choices: ["North Carolina.", "Louisville.", "Cal State Fullerton.", "Rice."]),
        TriviaQuestion(id: 363, category: "CWS", prompt: "Mississippi State's 1985 CWS finish was a tie for what place?", answer: "Third.", choices: ["Third.", "Second.", "Fourth.", "Fifth."]),
        TriviaQuestion(id: 364, category: "CWS", prompt: "Will Clark hit how many home runs at the 1985 CWS?", answer: "Three.", choices: ["Three.", "Two.", "Four.", "One."]),
        TriviaQuestion(id: 365, category: "CWS", prompt: "Which Bulldog hit two doubles in MSU's 5-4 win over Arkansas at the 1985 CWS?", answer: "Will Clark.", choices: ["Will Clark.", "Rafael Palmeiro.", "Bobby Thigpen.", "Dan Van Cleve."])
    ]

    static let fallback = questions[0]

    static func question(for id: Int) -> TriviaQuestion? {
        questions.first { $0.id == id }
    }

    static func dailyQuestion(for date: Date) -> TriviaQuestion {
        let dayIndex = (Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1) - 1
        return questions[dayIndex % questions.count]
    }

    static func randomQuestion(excluding id: Int) -> TriviaQuestion {
        let pool = questions.filter { $0.id != id }
        return pool.randomElement() ?? fallback
    }

    static let categories: [String] = {
        var seen = Set<String>()
        var ordered: [String] = []
        for question in questions where seen.insert(question.category).inserted {
            ordered.append(question.category)
        }
        return ordered.sorted()
    }()

    static func randomQuestion(in category: String?, excluding id: Int) -> TriviaQuestion {
        let pool: [TriviaQuestion]
        if let category {
            pool = questions.filter { $0.category == category && $0.id != id }
        } else {
            pool = questions.filter { $0.id != id }
        }
        return pool.randomElement() ?? randomQuestion(excluding: id)
    }

    static func instance(for question: TriviaQuestion) -> TriviaQuestionInstance {
        let orderedChoices = orderedChoices(for: question)
        return TriviaQuestionInstance(question: question, choices: finalChoices(from: orderedChoices, question: question))
    }

    private static func finalChoices(from orderedChoices: [String], question: TriviaQuestion) -> [String] {
        let distractors = orderedChoices.filter { $0 != question.answer }
        let pool = ([question.answer] + distractors).uniqued().prefix(4).map { $0 }
        return pool.sorted { lhs, rhs in
            triviaChoiceSortKey(for: lhs, seed: question.id) < triviaChoiceSortKey(for: rhs, seed: question.id)
        }
    }

    private static func orderedChoices(for question: TriviaQuestion) -> [String] {
        if let choices = question.choices, choices.count >= 4 {
            return choices.uniqued().sorted { lhs, rhs in
                triviaChoiceSortKey(for: lhs, seed: question.id) < triviaChoiceSortKey(for: rhs, seed: question.id)
            }
        }

        let selectedDistractors = distractors(for: question)
        return ([question.answer] + selectedDistractors).uniqued()
            .sorted { lhs, rhs in
                triviaChoiceSortKey(for: lhs, seed: question.id) < triviaChoiceSortKey(for: rhs, seed: question.id)
            }
    }

    private static func triviaChoiceSortKey(for value: String, seed: Int) -> String {
        let rotated = value.dropFirst(min(seed % max(value.count, 1), value.count))
        return String(rotated) + value
    }

    private static func distractors(for question: TriviaQuestion) -> [String] {
        let prompt = question.prompt.lowercased()
        let answer = normalizedAnswer(question.answer)

        if prompt.contains("what year") || prompt.contains("what years") {
            if let yearSpecificDistractors = yearDistractors(for: answer) {
                return yearSpecificDistractors
            }
        }

        if let year = Int(answer) {
            return [year - 2, year - 1, year + 1, year + 2].map(String.init)
        }

        if let range = yearRange(from: answer) {
            return [
                "\(range.lowerBound - 1)-\(String((range.upperBound - 1) % 100).leftPaddedYearSuffix)",
                "\(range.lowerBound + 1)-\(String((range.upperBound + 1) % 100).leftPaddedYearSuffix)",
                "\(range.lowerBound - 2)-\(String((range.upperBound - 2) % 100).leftPaddedYearSuffix)",
                "\(range.lowerBound + 2)-\(String((range.upperBound + 2) % 100).leftPaddedYearSuffix)"
            ]
        }

        if positionChoices.contains(answer) {
            return positionChoices.filter { $0 != answer }
        }

        if baseballTermChoices[answer] != nil {
            return baseballTermChoices[answer]!.filter { $0 != answer }
        }

        if playerNameSet.contains(answer) {
            return rotatedChoices(from: Array(playerNameSet.subtracting([answer])).sorted(), seed: question.id)
        }

        if programFactChoices[answer] != nil {
            return programFactChoices[answer]!.filter { $0 != answer }
        }

        let distractors = questions
            .filter { $0.id != question.id && $0.answer != question.answer }
            .map { normalizedAnswer($0.answer) }
        return rotatedChoices(from: distractors, seed: question.id)
    }

    private static func yearDistractors(for answer: String) -> [String]? {
        if let year = Int(answer) {
            return [year - 2, year - 1, year + 1, year + 2].map(String.init)
        }

        if let range = yearRange(from: answer) {
            return [
                "\(range.lowerBound - 1)-\(String((range.upperBound - 1) % 100).leftPaddedYearSuffix)",
                "\(range.lowerBound + 1)-\(String((range.upperBound + 1) % 100).leftPaddedYearSuffix)",
                "\(range.lowerBound - 2)-\(String((range.upperBound - 2) % 100).leftPaddedYearSuffix)",
                "\(range.lowerBound + 2)-\(String((range.upperBound + 2) % 100).leftPaddedYearSuffix)"
            ]
        }

        if answer.contains(",") {
            let listDistractors = questions
                .map(\.answer)
                .map(normalizedAnswer(_:))
                .filter { $0 != answer && isYearLike($0) }
            return rotatedChoices(from: listDistractors, seed: answer.count)
        }

        let yearLikeDistractors = questions
            .map(\.answer)
            .map(normalizedAnswer(_:))
            .filter { $0 != answer && isYearLike($0) }
        guard !yearLikeDistractors.isEmpty else { return nil }
        return rotatedChoices(from: yearLikeDistractors, seed: answer.count)
    }

    private static func rotatedChoices(from values: [String], seed: Int) -> [String] {
        guard !values.isEmpty else { return [] }
        let startIndex = seed % values.count
        return Array((values[startIndex...] + values[..<startIndex]).prefix(4))
    }

    private static func yearRange(from value: String) -> ClosedRange<Int>? {
        let parts = value.split(separator: "-")
        guard parts.count == 2,
              let start = Int(parts[0]),
              let endSuffix = Int(parts[1]) else {
            return nil
        }

        let century = (start / 100) * 100
        let fullEnd = century + endSuffix
        return start...fullEnd
    }

    private static func isYearLike(_ value: String) -> Bool {
        let trimmed = normalizedAnswer(value)
        guard trimmed.range(of: #"\d{4}"#, options: .regularExpression) != nil else {
            return false
        }

        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "-, "))
        return trimmed.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    private static func normalizedAnswer(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static let positionChoices = ["RHP", "LHP", "OF", "INF", "SS", "1B", "2B/OF", "C", "OF/DH"]

    private static let baseballTermChoices: [String: [String]] = [
        "Baseball": ["Baseball", "Football", "Basketball", "Softball"],
        "Major League Baseball": ["Major League Baseball", "Minor League Baseball", "Mississippi League Baseball", "Metro League Baseball"],
        "Minor League Baseball": ["Minor League Baseball", "Major League Baseball", "Midwest League Baseball", "National League Baseball"],
        "Right-handed pitcher": ["Right-handed pitcher", "Left-handed pitcher", "Relief hitter", "Right field player"],
        "Left-handed pitcher": ["Left-handed pitcher", "Right-handed pitcher", "Lead hitter position", "Left field player"],
        "Infielder": ["Infielder", "Outfielder", "Starting pitcher", "Catcher"],
        "Outfielder": ["Outfielder", "Infielder", "Closer", "Catcher"],
        "AVG": ["AVG", "ERA", "OPS", "RBI"],
        "OPS": ["OPS", "ERA", "WHIP", "OBP"],
        "ERA": ["ERA", "AVG", "OPS", "RBI"],
        "Mississippi State": ["Mississippi State", "Ole Miss", "LSU", "Arkansas"],
        "Bulldogs": ["Bulldogs", "Tigers", "Rebels", "Gators"],
        "Diamond Dawgs": ["Diamond Dawgs", "Bulldog Bats", "Maroon Nine", "Dudy Dogs"],
        "Starkville, Mississippi": ["Starkville, Mississippi", "Oxford, Mississippi", "Hattiesburg, Mississippi", "Birmingham, Alabama"],
        "The Southeastern Conference, or SEC": ["The Southeastern Conference, or SEC", "The Big 12", "The ACC", "The Sun Belt"],
        "Dudy Noble Field": ["Dudy Noble Field", "Swayze Field", "Baum-Walker Stadium", "Alex Box Stadium"],
        "The Left Field Lounge": ["The Left Field Lounge", "The Right Field Patio", "The Maroon Deck", "The Bulldog Terrace"]
    ]

    private static let programFactChoices: [String: [String]] = [
        "2021": ["2021", "2019", "2018", "2023"],
        "Jake Mangum": ["Jake Mangum", "Brent Rooker", "Jordan Westburg", "Adam Frazier"],
        "Chris Lemonis": ["Chris Lemonis", "Ron Polk", "John Cohen", "Mitch Moreland"],
        "Vanderbilt": ["Vanderbilt", "Texas", "Ole Miss", "LSU"]
    ]

    private static let playerNameSet: Set<String> = Set(PlayerCatalog.players.map(\.displayName))
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

private extension String {
    var leftPaddedYearSuffix: String {
        count == 1 ? "0\(self)" : self
    }
}

// MARK: - Extensions used across views

extension Optional where Wrapped == Int {
    var display: String {
        guard let self else { return "-" }
        return String(self)
    }
}

extension PlayerCatalogEntry {
    var fallbackLine: String {
        "Mississippi State \(msuYears)"
    }

    var teamLogoURL: URL? {
        let resolvedLogoCode = PlayerRuntimeStore.teamLogoCode(for: id) ?? teamLogoCode
        guard let resolvedLogoCode else { return nil }
        return URL(string: "https://a.espncdn.com/i/teamlogos/mlb/500/\(resolvedLogoCode).png")
    }

    var headshotURL: URL? {
        URL(string: "https://midfield.mlbstatic.com/v1/people/\(id)/spots/240")
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    var levelLabel: String {
        guard effectiveIsMinorLeaguer else { return "MLB" }
        switch effectiveSportID {
        case 11: return "Triple-A"
        case 12: return "Double-A"
        case 13: return "High-A"
        case 14: return "Single-A"
        case 16: return "Rookie"
        default: return "MiLB"
        }
    }

    var levelSortRank: Int {
        guard effectiveIsMinorLeaguer else { return 0 }
        switch effectiveSportID {
        case 11: return 1
        case 12: return 2
        case 13: return 3
        case 14: return 4
        case 16: return 5
        default: return 6
        }
    }

    var latestStateSeason: Int {
        let years = msuYears.matches(of: /20\d{2}/).compactMap { Int($0.output) }
        return years.max() ?? 0
    }

    var stateYearLabel: String {
        latestStateSeason > 0 ? String(latestStateSeason) : "State Years"
    }

    fileprivate var effectiveSportID: Int? {
        if let override = PlayerRuntimeStore.sportID(for: id) {
            return override
        }
        return preferredSportID
    }

    fileprivate var effectiveIsMinorLeaguer: Bool {
        PlayerRuntimeStore.isMinorLeaguer(for: id) ?? isMinorLeaguer
    }
}

extension GameLogEntry {
    private static let apiDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var formattedDate: String {
        guard let date = Self.apiDateFormatter.date(from: dateText) else {
            return dateText
        }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return Self.displayDateFormatter.string(from: date)
    }
}

enum FavoritePlayerStore {
    static func ids(from storage: String) -> Set<Int> {
        Set(storage.split(separator: ",").compactMap { Int($0) })
    }

    static func toggle(_ playerID: Int, in storage: inout String) {
        var ids = ids(from: storage)
        if ids.contains(playerID) {
            ids.remove(playerID)
        } else {
            ids.insert(playerID)
        }
        storage = ids.sorted().map(String.init).joined(separator: ",")
    }
}
