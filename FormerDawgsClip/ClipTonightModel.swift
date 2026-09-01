import Combine
import Foundation

struct ClipPlayer: Hashable, Identifiable {
    let id: Int
    let name: String
    let role: String
    let isPitcher: Bool
}

enum ClipRoster {
    static let players: [ClipPlayer] = [
        ClipPlayer(id: 641585, name: "J.P. France", role: "RHP", isPitcher: true),
        ClipPlayer(id: 624428, name: "Adam Frazier", role: "2B/OF", isPitcher: false),
        ClipPlayer(id: 669372, name: "J.T. Ginn", role: "RHP", isPitcher: true),
        ClipPlayer(id: 663993, name: "Nathaniel Lowe", role: "1B", isPitcher: false),
        ClipPlayer(id: 663968, name: "Jake Mangum", role: "OF", isPitcher: false),
        ClipPlayer(id: 667670, name: "Brent Rooker", role: "OF/DH", isPitcher: false),
        ClipPlayer(id: 676059, name: "Jordan Westburg", role: "INF", isPitcher: false),
        ClipPlayer(id: 605540, name: "Brandon Woodruff", role: "RHP", isPitcher: true),
        ClipPlayer(id: 687218, name: "Will Bednar", role: "RHP", isPitcher: true),
        ClipPlayer(id: 672021, name: "Eric Cerantola", role: "RHP", isPitcher: true),
        ClipPlayer(id: 679822, name: "Justin Foscue", role: "1B", isPitcher: false),
        ClipPlayer(id: 687268, name: "K.C. Hunt", role: "RHP", isPitcher: true),
        ClipPlayer(id: 807742, name: "Colton Ledbetter", role: "OF", isPitcher: false),
        ClipPlayer(id: 802418, name: "Colby Holcombe", role: "RHP", isPitcher: true),
        ClipPlayer(id: 663455, name: "Konnor Pilkington", role: "LHP", isPitcher: true),
        ClipPlayer(id: 681003, name: "Andrew Walling", role: "LHP", isPitcher: true),
        ClipPlayer(id: 701388, name: "Jurrangelo Cijntje", role: "RHP", isPitcher: true),
        ClipPlayer(id: 824620, name: "Tyson Hardin", role: "RHP", isPitcher: true),
        ClipPlayer(id: 806060, name: "Luke Dotson", role: "LHP", isPitcher: true),
        ClipPlayer(id: 824624, name: "Brooks Auger", role: "RHP", isPitcher: true),
        ClipPlayer(id: 699613, name: "Houston Harding", role: "LHP", isPitcher: true),
        ClipPlayer(id: 702309, name: "Hunter Hines", role: "1B", isPitcher: false),
        ClipPlayer(id: 690977, name: "Jackson Fristoe", role: "RHP", isPitcher: true),
        ClipPlayer(id: 687553, name: "Kamren James", role: "SS", isPitcher: false),
        ClipPlayer(id: 695704, name: "Karson Ligon", role: "RHP", isPitcher: true),
        ClipPlayer(id: 702296, name: "Nate Dohm", role: "RHP", isPitcher: true),
        ClipPlayer(id: 802699, name: "Nate Williams", role: "RHP", isPitcher: true),
        ClipPlayer(id: 702574, name: "David Mershon", role: "SS", isPitcher: false),
        ClipPlayer(id: 683085, name: "Landon Sims", role: "RHP", isPitcher: true),
        ClipPlayer(id: 694696, name: "Cade Smith", role: "RHP", isPitcher: true),
        ClipPlayer(id: 824615, name: "Connor Hujsak", role: "OF", isPitcher: false),
        ClipPlayer(id: 702607, name: "Dakota Jordan", role: "OF", isPitcher: false),
        ClipPlayer(id: 804905, name: "Evan Siary", role: "RHP", isPitcher: true),
        ClipPlayer(id: 809131, name: "Jacob Pruitt", role: "RHP", isPitcher: true),
        ClipPlayer(id: 695560, name: "Pico Kohn", role: "LHP", isPitcher: true),
        ClipPlayer(id: 699980, name: "Preston Johnson", role: "RHP", isPitcher: true),
        ClipPlayer(id: 691004, name: "Aaron Nixon", role: "RHP", isPitcher: true),
        ClipPlayer(id: 807575, name: "Cam Schuelke", role: "RHP", isPitcher: true),
        ClipPlayer(id: 683091, name: "Logan Tanner", role: "C", isPitcher: false),
    ]
}

enum ClipGameState: String {
    case scheduled
    case live
    case final
}

struct ClipGameRowModel: Identifiable {
    let id: Int
    let playerName: String
    let initials: String
    let headline: String
    let status: String
    let detail: String?
    let state: ClipGameState
    let startTime: Date?

    var headshotURL: URL? {
        URL(string: "https://midfield.mlbstatic.com/v1/people/\(id)/spots/240")
    }
}

@MainActor
final class ClipTonightModel: ObservableObject {
    @Published var rows: [ClipGameRowModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var liveRows: [ClipGameRowModel] { rows.filter { $0.state == .live } }
    var upcomingRows: [ClipGameRowModel] { rows.filter { $0.state == .scheduled } }
    var finalRows: [ClipGameRowModel] { rows.filter { $0.state == .final } }
    var liveCount: Int { liveRows.count }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rows = try await ClipTonightService().loadTonight()
            errorMessage = nil
        } catch {
            if rows.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}
