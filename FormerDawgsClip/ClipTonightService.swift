import Foundation

struct ClipTonightService {
    func loadTonight() async throws -> [ClipGameRowModel] {
        try await withThrowingTaskGroup(of: ClipGameRowModel?.self) { group in
            for player in ClipRoster.players {
                group.addTask {
                    await self.row(for: player)
                }
            }
            var collected: [ClipGameRowModel] = []
            for try await item in group {
                if let item { collected.append(item) }
            }
            return collected.sorted { lhs, rhs in
                let order: [ClipGameState: Int] = [.live: 0, .scheduled: 1, .final: 2]
                let left = order[lhs.state, default: 9]
                let right = order[rhs.state, default: 9]
                if left != right { return left < right }
                return (lhs.startTime ?? .distantFuture) < (rhs.startTime ?? .distantFuture)
            }
        }
    }

    private func row(for player: ClipPlayer) async -> ClipGameRowModel? {
        do {
            let profile = try await fetchProfile(playerID: player.id)
            guard let teamID = profile.currentTeamID else { return nil }
            guard let game = try await fetchTodayGame(teamID: teamID) else { return nil }
            let initials = player.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
            return ClipGameRowModel(
                id: player.id,
                playerName: player.name,
                initials: initials.uppercased(),
                headline: game.headline,
                status: game.statusText,
                detail: game.inningText,
                state: game.state,
                startTime: game.startTime
            )
        } catch {
            return nil
        }
    }

    private func fetchProfile(playerID: Int) async throws -> Profile {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/people/\(playerID)")!
        components.queryItems = [URLQueryItem(name: "hydrate", value: "currentTeam")]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(PeopleResponse.self, from: data)
        guard let person = decoded.people.first else {
            throw URLError(.badServerResponse)
        }
        return Profile(currentTeamID: person.currentTeam?.id)
    }

    private func fetchTodayGame(teamID: Int) async throws -> TodayClipGame? {
        let day = DateFormatter.clipDay.string(from: Date())
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/schedule")!
        components.queryItems = [
            URLQueryItem(name: "sportId", value: "1,11,12,13,14,16"),
            URLQueryItem(name: "teamId", value: String(teamID)),
            URLQueryItem(name: "date", value: day),
            URLQueryItem(name: "hydrate", value: "linescore,team")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(ScheduleResponse.self, from: data)
        guard let game = decoded.dates.first?.games.first else { return nil }

        let homeID = game.teams.home.team?.id
        let isHome = homeID == teamID
        let opponent = isHome ? (game.teams.away.team?.name ?? "Opponent") : (game.teams.home.team?.name ?? "Opponent")
        let state = Self.mapState(game.status?.abstractGameState)
        let start = game.gameDate.flatMap { ISO8601DateFormatter().date(from: $0) }
        var inning: String?
        if let linescore = game.linescore {
            let half = linescore.inningHalf ?? ""
            if let num = linescore.currentInning {
                inning = "\(half)\(num)".trimmingCharacters(in: .whitespaces)
            }
        }
        return TodayClipGame(
            state: state,
            opponentName: opponent,
            isHome: isHome,
            startTime: start,
            homeScore: game.teams.home.score,
            awayScore: game.teams.away.score,
            inningText: inning
        )
    }

    private static func mapState(_ abstract: String?) -> ClipGameState {
        switch abstract?.lowercased() {
        case "live": return .live
        case "final": return .final
        default: return .scheduled
        }
    }
}

private struct Profile {
    let currentTeamID: Int?
}

private struct TodayClipGame {
    let state: ClipGameState
    let opponentName: String
    let isHome: Bool
    let startTime: Date?
    let homeScore: Int?
    let awayScore: Int?
    let inningText: String?

    var headline: String {
        (isHome ? "vs " : "@ ") + opponentName
    }

    var statusText: String {
        switch state {
        case .scheduled:
            guard let startTime else { return "Today" }
            return DateFormatter.clipTime.string(from: startTime)
        case .live:
            let score = scoreLine
            if let inningText, !inningText.isEmpty {
                return "\(score) • \(inningText)"
            }
            return score
        case .final:
            return "Final \(scoreLine)"
        }
    }

    private var scoreLine: String {
        let home = homeScore ?? 0
        let away = awayScore ?? 0
        return isHome ? "\(home)-\(away)" : "\(away)-\(home)"
    }
}

private struct PeopleResponse: Decodable {
    let people: [Person]
    struct Person: Decodable {
        let currentTeam: Team?
    }
    struct Team: Decodable {
        let id: Int?
    }
}

private struct ScheduleResponse: Decodable {
    let dates: [DateBlock]
    struct DateBlock: Decodable {
        let games: [Game]
    }
    struct Game: Decodable {
        let gameDate: String?
        let status: Status?
        let teams: Teams
        let linescore: Linescore?
    }
    struct Status: Decodable {
        let abstractGameState: String?
    }
    struct Teams: Decodable {
        let home: Side
        let away: Side
    }
    struct Side: Decodable {
        let score: Int?
        let team: Team?
    }
    struct Team: Decodable {
        let id: Int?
        let name: String?
    }
    struct Linescore: Decodable {
        let currentInning: Int?
        let inningHalf: String?
    }
}

private extension DateFormatter {
    static let clipDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let clipTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
