import Foundation

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
        major(id: 804606, displayName: "Konnor Griffin", role: "SS", msuYears: "Pittsburgh Pirates", kind: .hitter, teamLogoCode: "pit"),
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
        minor(id: 828098, displayName: "JoJo Parker", role: "SS", msuYears: "Purvis, MS | Jacob Parker at State", kind: .hitter, sportID: 14, teamLogoCode: "tor"),
        minor(id: 683085, displayName: "Landon Sims", role: "RHP", msuYears: "2020-22", kind: .pitcher, sportID: 11, teamLogoCode: "ari"),
        minor(id: 694696, displayName: "Cade Smith", role: "RHP", msuYears: "2021-23", kind: .pitcher, sportID: 12, teamLogoCode: "cle"),
        minor(id: 824615, displayName: "Connor Hujsak", role: "OF", msuYears: "2023-24", kind: .hitter, sportID: 13, teamLogoCode: "tb"),
        minor(id: 702607, displayName: "Dakota Jordan", role: "OF", msuYears: "2023-24", kind: .hitter, sportID: 12, teamLogoCode: "sf"),
        minor(id: 804905, displayName: "Evan Siary", role: "RHP", msuYears: "2025", kind: .pitcher, sportID: 13, teamLogoCode: "tex"),
        minor(id: 809131, displayName: "Jacob Pruitt", role: "RHP", msuYears: "2025", kind: .pitcher, sportID: 14, teamLogoCode: "phi"),
        minor(id: 695560, displayName: "Pico Kohn", role: "LHP", msuYears: "2022, 2024-25", kind: .pitcher, sportID: 12, teamLogoCode: "nyy"),
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

struct PlayerDashboard {
    let catalogEntry: PlayerCatalogEntry
    let profile: PlayerProfile.Person
    let seasonStat: PlayerStatsResponse.Split?
    let stories: [Story]
    let gameLogs: [GameLogEntry]
    let videos: [HighlightVideo]

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
        if catalogEntry.id == 804606 || catalogEntry.id == 828098 {
            return catalogEntry.msuYears
        }

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
}

struct FormerDawgsHomeSummary {
    let hottestHitter: PlayerDashboard?
    let hottestPitcher: PlayerDashboard?
    let latestPromotion: HomeStoryHighlight?
    let latestHeadline: HomeStoryHighlight?
    let todaysActivePlayers: [PlayerDashboard]
}

struct HomeStoryHighlight: Identifiable {
    let id = UUID()
    let player: PlayerCatalogEntry
    let story: Story
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

    static func saveOverride(for dashboard: PlayerDashboard) {
        let playerID = String(dashboard.catalogEntry.id)
        let defaults = UserDefaults.standard

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
    }

    static func sportID(for playerID: Int) -> Int?? {
        let values = UserDefaults.standard.dictionary(forKey: sportIDKey) as? [String: Int]
        guard let value = values?[String(playerID)] else {
            return nil
        }

        return value == 0 ? .some(nil) : .some(value)
    }

    static func isMinorLeaguer(for playerID: Int) -> Bool? {
        let values = UserDefaults.standard.dictionary(forKey: minorStatusKey) as? [String: Bool]
        return values?[String(playerID)]
    }

    static func teamLogoCode(for playerID: Int) -> String? {
        let values = UserDefaults.standard.dictionary(forKey: teamLogoCodeKey) as? [String: String]
        return values?[String(playerID)]
    }
}
