import Foundation

struct DraftService {
    func fetchMSUPicks(year: Int) async throws -> [DraftPickResult] {
        let url = URL(string: "https://statsapi.mlb.com/api/v1/draft/\(year)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(DraftResponse.self, from: data)

        var results: [DraftPickResult] = []
        for round in response.drafts.rounds {
            for pick in round.picks {
                guard let person = pick.person, isMississippiState(pick.school?.name) else { continue }
                let kind: PlayerKind = isPitcher(pick) ? .pitcher : .hitter
                results.append(DraftPickResult(
                    id: person.id,
                    fullName: person.fullName,
                    role: pick.bestPositionAbbreviation(personPosition: person.primaryPosition),
                    kind: kind,
                    pickOverall: pick.pickNumber,
                    pickRound: round.round ?? pick.pickRound,
                    teamID: pick.team?.id,
                    teamName: pick.team?.name,
                    teamLogoCode: (pick.team?.id).flatMap(TeamLogoCatalog.code(for:)),
                    draftYear: year
                ))
            }
        }
        return results
    }

    func fetchMSUUndraftedFreeAgents(year: Int) async throws -> [DraftPickResult] {
        var results: [DraftPickResult] = []
        for candidate in UndraftedFreeAgentCandidate.watchlist(for: year) {
            guard let signedPlayer = try await fetchSignedPlayer(matching: candidate) else {
                continue
            }
            results.append(signedPlayer)
        }
        return results
    }

    private func fetchSignedPlayer(matching candidate: UndraftedFreeAgentCandidate) async throws -> DraftPickResult? {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/people/search")!
        components.queryItems = [
            URLQueryItem(name: "names", value: candidate.name),
            URLQueryItem(name: "hydrate", value: "currentTeam,education")
        ]
        guard let url = components.url else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PlayerSearchResponse.self, from: data)
        guard let person = response.people.first(where: { matches(candidate: candidate, person: $0) }) else {
            return nil
        }

        let teamID = person.currentTeam?.parentOrgId ?? person.currentTeam?.id
        return DraftPickResult(
            id: person.id,
            fullName: person.fullName,
            role: person.primaryPosition?.abbreviation ?? candidate.role,
            kind: person.primaryPosition.map(kind(for:)) ?? candidate.kind,
            pickOverall: nil,
            pickRound: "Free Agent",
            teamID: teamID,
            teamName: person.currentTeam?.name,
            teamLogoCode: teamID.flatMap(TeamLogoCatalog.code(for:)),
            draftYear: candidate.year
        )
    }

    private func matches(candidate: UndraftedFreeAgentCandidate, person: PlayerSearchResponse.Person) -> Bool {
        guard normalizedName(person.fullName) == normalizedName(candidate.name) else { return false }
        guard person.isPlayer != false else { return false }
        guard person.currentTeam != nil else { return false }
        guard person.active != false else { return false }

        if person.education?.colleges?.contains(where: { isMississippiState($0.name) }) == true {
            return true
        }

        if let draftYear = person.draftYear, draftYear < candidate.year - 1 {
            return false
        }
        if let lastPlayedDate = person.lastPlayedDate, lastPlayedDate.hasPrefix(String(candidate.year - 2)) {
            return false
        }

        return true
    }

    private func isMississippiState(_ name: String?) -> Bool {
        guard let name = name?.lowercased() else { return false }
        return name.contains("mississippi state")
    }

    private func isPitcher(_ pick: DraftResponse.Pick) -> Bool {
        let abbreviation = (pick.person?.primaryPosition?.abbreviation ?? "").uppercased()
        if abbreviation.contains("P") { return true }
        let type = (pick.person?.primaryPosition?.type ?? "").lowercased()
        return type.contains("pitcher")
    }

    private func kind(for position: PlayerSearchResponse.Position) -> PlayerKind {
        let abbreviation = position.abbreviation.uppercased()
        if abbreviation.contains("P") { return .pitcher }
        let type = position.type?.lowercased() ?? ""
        return type.contains("pitcher") ? .pitcher : .hitter
    }

    private func normalizedName(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

struct DraftPickResult: Hashable {
    let id: Int
    let fullName: String
    let role: String
    let kind: PlayerKind
    let pickOverall: Int?
    let pickRound: String?
    let teamID: Int?
    let teamName: String?
    let teamLogoCode: String?
    let draftYear: Int
}

struct DraftResponse: Decodable {
    let drafts: Drafts

    struct Drafts: Decodable {
        let rounds: [Round]
    }

    struct Round: Decodable {
        let round: String?
        let picks: [Pick]
    }

    struct Pick: Decodable {
        let pickNumber: Int?
        let pickRound: String?
        let person: Person?
        let school: School?
        let team: Team?

        func bestPositionAbbreviation(personPosition: Person.Position?) -> String {
            if let abbreviation = personPosition?.abbreviation, !abbreviation.isEmpty {
                return abbreviation
            }
            return personPosition?.type ?? "Prospect"
        }
    }

    struct Person: Decodable {
        let id: Int
        let fullName: String
        let primaryPosition: Position?

        struct Position: Decodable {
            let abbreviation: String?
            let type: String?
        }
    }

    struct School: Decodable {
        let name: String?
    }
}

private struct UndraftedFreeAgentCandidate {
    let year: Int
    let name: String
    let role: String
    let kind: PlayerKind

    static func watchlist(for year: Int) -> [UndraftedFreeAgentCandidate] {
        recentCandidates.filter { $0.year == year }
    }

    private static let recentCandidates: [UndraftedFreeAgentCandidate] = [
        .init(year: 2026, name: "Aidan Teel", role: "OF", kind: .hitter),
        .init(year: 2026, name: "Reed Stallman", role: "1B/OF", kind: .hitter),
        .init(year: 2026, name: "Drew Wyers", role: "INF", kind: .hitter),
        .init(year: 2026, name: "Vytas Valincius", role: "OF", kind: .hitter),
        .init(year: 2026, name: "Noah Sullivan", role: "UTL/RHP", kind: .hitter),
        .init(year: 2026, name: "Kevin Milewski", role: "C", kind: .hitter),
        .init(year: 2026, name: "Jackson Owen", role: "C", kind: .hitter),
        .init(year: 2026, name: "Chris Billingsley Jr.", role: "RHP", kind: .pitcher),
        .init(year: 2026, name: "Maddox Webb", role: "RHP", kind: .pitcher),
        .init(year: 2026, name: "Jackson Logar", role: "RHP", kind: .pitcher),
        .init(year: 2026, name: "Peyton Fowler", role: "RHP", kind: .pitcher),
        .init(year: 2026, name: "Blake Bevis", role: "1B/OF", kind: .hitter),
        .init(year: 2026, name: "Gehrig Frei", role: "INF/OF", kind: .hitter),
        .init(year: 2026, name: "Ben Davis", role: "RHP", kind: .pitcher),
        .init(year: 2026, name: "Tyler Pitzer", role: "RHP", kind: .pitcher),
        .init(year: 2026, name: "Brendan Sweeney", role: "RHP", kind: .pitcher),
        .init(year: 2026, name: "Bryce Chance", role: "OF", kind: .hitter),
        .init(year: 2026, name: "JT Schnoor", role: "RHP", kind: .pitcher),
        .init(year: 2026, name: "Gatlin Sanders", role: "INF", kind: .hitter)
    ]
}

private struct PlayerSearchResponse: Decodable {
    let people: [Person]

    struct Person: Decodable {
        let id: Int
        let fullName: String
        let active: Bool?
        let currentTeam: SearchTeam?
        let primaryPosition: Position?
        let isPlayer: Bool?
        let draftYear: Int?
        let lastPlayedDate: String?
        let education: Education?
    }

    struct SearchTeam: Decodable {
        let id: Int
        let name: String
        let parentOrgId: Int?
    }

    struct Position: Decodable {
        let type: String?
        let abbreviation: String
    }

    struct Education: Decodable {
        let colleges: [School]?
    }

    struct School: Decodable {
        let name: String?
    }
}
