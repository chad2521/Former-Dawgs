import AVFoundation
import CoreMotion
import SwiftUI
import UIKit

// MARK: - Deck

enum HeadsUpSport: String, CaseIterable, Identifiable {
    case all
    case formerDawgs
    case omaha
    case football
    case baseball
    case basketball
    case traditions
    case olympicsAndMore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Sports"
        case .formerDawgs: "Former Dawgs"
        case .omaha: "Omaha & Records"
        case .football: "Football"
        case .baseball: "Baseball"
        case .basketball: "Basketball"
        case .traditions: "Traditions"
        case .olympicsAndMore: "More Sports"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "sportscourt.fill"
        case .formerDawgs: "person.3.fill"
        case .omaha: "trophy.fill"
        case .football: "football.fill"
        case .baseball: "baseball.fill"
        case .basketball: "basketball.fill"
        case .traditions: "bell.fill"
        case .olympicsAndMore: "medal.fill"
        }
    }
}

struct HeadsUpCard: Identifiable, Hashable {
    let id: Int
    let sport: HeadsUpSport
    /// Short phrase shown on screen (Heads Up style — names & short clues, not full questions).
    let text: String
}

enum HeadsUpCatalog {
    static let cards: [HeadsUpCard] = {
        var id = 0
        func card(_ sport: HeadsUpSport, _ text: String) -> HeadsUpCard {
            defer { id += 1 }
            return HeadsUpCard(id: id, sport: sport, text: text)
        }

        var list: [HeadsUpCard] = []

        // Former Dawgs / Diamond Dawgs
        let formerDawgs = [
            "Will Clark", "Rafael Palmeiro", "Jeff Brantley", "Bobby Thigpen",
            "Jonathan Papelbon", "Mitch Moreland", "Adam Frazier", "Hunter Renfroe",
            "Brandon Woodruff", "Nathaniel Lowe", "Brent Rooker", "Jake Mangum",
            "Jordan Westburg", "Justin Foscue", "Dakota Hudson", "Chris Stratton",
            "Kendall Graveman", "Paul Maholm", "Buck Showalter", "Tyler Moore",
            "Ed Easley", "Logan Tanner", "Landon Sims", "Will Bednar",
            "Tanner Allen", "Rowdey Jordan", "Brad Cumbest", "Kamren James",
            "Dakota Jordan", "Jurrangelo Cijntje", "Konnor Griffin", "Hunter Hines",
            "Colton Ledbetter", "Connor Hujsak", "Amani Larry", "Luke Hancock"
        ]
        list += formerDawgs.map { card(.formerDawgs, $0) }

        // Omaha / records / championship moments
        let omaha = [
            "2021 National Champs", "Omaha Dogpile", "College World Series",
            "Vanderbilt Finals", "Will Bednar Game 3", "Landon Sims Closing",
            "Tanner Allen Catch", "Brad Cumbest Triple", "Rowdey Jordan Leadoff",
            "Dudy Noble Roar", "Left Field Lounge Party", "The Dude at Night",
            "Jake Mangum Hits Record", "Will Clark in Omaha", "Palmeiro and Clark",
            "Bobby Thigpen Saves", "Thunder and Lightning", "Super Regional Host",
            "Regional Dogpile", "Maroon Omaha Jersey", "Dakota Jordan Home Run",
            "Hunter Hines Moonshot", "Diamond Dawgs", "State to the Show",
            "Rally Banana", "Omaha Bound", "CWS Finals", "Game Three"
        ]
        list += omaha.map { card(.omaha, $0) }

        // Football
        let football = [
            "Dak Prescott", "John Bond", "Jackie Sherrill", "Dan Mullen", "Mike Leach",
            "Zach Arnett", "Jeffery Simmons", "Fletcher Cox", "Chris Jones", "Will Rogers",
            "Nick Fitzgerald", "K.J. Costello", "Anthony Dixon", "Jeremiah Johnson",
            "Davis Wade Stadium", "The Junction", "Egg Bowl", "Hail State",
            "SEC West", "Bulldog Stadium", "Maroon Out", "Cowbell Yell",
            "2014 #1 Ranking", "Sugar Bowl", "Liberty Bowl", "TaxSlayer Bowl",
            "Joe Moorhead", "Greg Knox", "Kylin Hill", "Osirus Mitchell",
            "Emmanuel Forbes", "Emmanuel Archibong", "J.T. Gray", "Gabe Myles",
            "Chris Relf", "Vick Ballard", "Benardrick McKinney", "Darius Slay",
            "Charles Cross", "Johnthan Banks", "Josh Robinson", "Fred Smoot",
            "Walt Harris", "Pig Prather", "Randy Thomas", "Tommy Stevens",
            "Dillon Johnson", "Aeris Williams", "State vs. Auburn 2014",
            "Goal Line Stand", "More Cowbell", "Maroon Helmet"
        ]
        list += football.map { card(.football, $0) }

        // Baseball
        let baseball = [
            "Dudy Noble Field", "Polk-DeMent Stadium", "Ron Polk", "Chris Lemonis",
            "John Cohen", "2021 National Champs", "College World Series",
            "Will Bednar", "Landon Sims", "Tanner Allen", "Konnor Griffin",
            "Left Field Lounge", "Super Bulldogs", "SEC Baseball",
            "Vanderbilt Sweep", "Omaha", "Baseball Maroon", "The Dude",
            "Houston Harding", "Jackson Fristoe", "Rowdey Jordan", "Logan Tanner",
            "Kamren James", "Jurrangelo Cijntje", "Dakota Jordan", "Hunter Hines",
            "NCAA Regional", "Super Regional", "Diamond Dawgs", "State to the Show",
            "First-Round Draft Pick", "Switch-Pitcher", "Friday Night Starter",
            "Closer Entrance", "Walk-Off Single", "Grand Slam", "Warning Track",
            "RBI Double", "Throwing Error", "Hit-and-Run", "Bullpen Cart",
            "Maroon Monkeys", "Pitcher Fielding Practice", "Omaha Chant",
            "SEC Tournament Hoover", "Rally Cap", "Bunt Defense", "Two-Way Player",
            "Pitch Clock", "Dinger", "Dude Effect"
        ]
        list += baseball.map { card(.baseball, $0) }

        // Basketball
        let basketball = [
            "Bailey Howell", "Rick Stansbury", "Ben Howland", "Chris Jans",
            "Humphrey Coliseum", "The Hump", "Jarred Godfrey", "Tolu Smith",
            "Iverson Molinar", "Quinndary Weatherspoon", "Dee Bost", "Jamont Gordon",
            "Jarvis Varnado", "SEC Tournament", "NIT Champions", "Maroon Madness",
            "Gary Crowton", "Women's Basketball", "Vic Schaefer", "Lady Bulldogs",
            "Sheryl Swoopes Visits", "The Jungle", "Free Throw", "Three-Point Line",
            "Final Four Run", "Morgan William", "Teaira McCowan", "Victoria Vivians",
            "Schaefer Defense", "Humphrey Roar", "No-Call Charge", "Buzzer Beater",
            "Pick and Roll", "Full-Court Press", "Paint Touch", "Sixth Man",
            "Student Section", "White Out", "SEC Home Win"
        ]
        list += basketball.map { card(.basketball, $0) }

        // Traditions / campus / all-sports identity
        let traditions = [
            "Cowbell", "Hail State", "Maroon & White", "Bulldogs",
            "Bully", "Starkville", "The Junction", "Cowbell Yell",
            "Maroon Friday", "Egg Bowl Trophy", "M-State", "Land Grant",
            "Aggie Days", "The Drill Field", "Chapel of Memories",
            "Famous Maroon Band", "Dawg Pound", "Stand Up and Cheer",
            "From the Desk of…", "I Am State", "Hail Dear Ole State",
            "Left Field Lounge", "The Sound of Cowbells", "SEC",
            "True Maroon", "Hail State Rewards", "Clanga", "Ring Responsibly",
            "Bully's Birthday", "Dawg Walk", "Cristil Method", "Starkvegas",
            "Cowbell Handle", "Script State", "More Cowbell Saturday",
            "The Dude", "Hail State Hoops", "Maroon Memories"
        ]
        list += traditions.map { card(.traditions, $0) }

        // More sports
        let more = [
            "Softball", "Nusz Park", "Track & Field", "Cross Country",
            "Tennis", "Golf", "Volleyball", "Soccer",
            "Swimming & Diving", "McCarthy Gym", "Sanderson Center",
            "Olympic Sports", "All-American", "NCAA Champion",
            "Bulldog Club", "AD", "Hail State Fight Song",
            "Women's Tennis", "Men's Golf", "SEC Network",
            "NCAA Tournament", "SEC Champion", "Road Match",
            "Penalty Kick", "Match Point", "Relay Split", "Personal Best",
            "Pole Vault", "Long Jump", "Ace Serve", "Eagle Putt",
            "Clean Sheet", "Bulldog Invitational", "Postseason Berth"
        ]
        list += more.map { card(.olympicsAndMore, $0) }

        return list
    }()

    static func deck(for sport: HeadsUpSport) -> [HeadsUpCard] {
        let base: [HeadsUpCard]
        switch sport {
        case .all:
            base = cards
        default:
            base = cards.filter { $0.sport == sport }
        }
        return base.shuffled()
    }
}

// MARK: - Game model

enum HeadsUpPhase: Equatable {
    case setup
    case countdown(Int)
    case playing
    case results
}

struct HeadsUpResult: Identifiable, Hashable {
    let id = UUID()
    let card: HeadsUpCard
    let correct: Bool
}

@MainActor
@Observable
final class HeadsUpViewModel {
    var sport: HeadsUpSport = .all
    var durationSeconds: Int = 60
    var phase: HeadsUpPhase = .setup
    var deck: [HeadsUpCard] = []
    var index: Int = 0
    var timeRemaining: Int = 60
    var results: [HeadsUpResult] = []
    var statusFlash: String? // "CORRECT" / "PASS"
    var statusIsCorrect: Bool = false

    private var timerTask: Task<Void, Never>?
    private var cooldownUntil: Date = .distantPast

    var currentCard: HeadsUpCard? {
        guard index < deck.count else { return nil }
        return deck[index]
    }

    var correctCount: Int { results.filter(\.correct).count }
    var passCount: Int { results.filter { !$0.correct }.count }

    func start() {
        deck = HeadsUpCatalog.deck(for: sport)
        index = 0
        results = []
        timeRemaining = durationSeconds
        statusFlash = nil
        phase = .countdown(3)
        runCountdown()
    }

    func quitToSetup() {
        timerTask?.cancel()
        timerTask = nil
        phase = .setup
        statusFlash = nil
    }

    func markCorrect() {
        resolve(correct: true)
    }

    func markPass() {
        resolve(correct: false)
    }

    private func resolve(correct: Bool) {
        guard phase == .playing, let card = currentCard else { return }
        guard Date() >= cooldownUntil else { return }
        cooldownUntil = Date().addingTimeInterval(0.85)

        results.append(HeadsUpResult(card: card, correct: correct))
        statusIsCorrect = correct
        statusFlash = correct ? "CORRECT!" : "PASS"
        HeadsUpHaptics.shared.bump(correct: correct)
        HeadsUpSound.shared.play(correct: correct)

        Task {
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                statusFlash = nil
                advance()
            }
        }
    }

    private func advance() {
        index += 1
        if index >= deck.count {
            // reshuffle extra deck mid-round if they burn through
            deck.append(contentsOf: HeadsUpCatalog.deck(for: sport))
        }
    }

    private func runCountdown() {
        timerTask?.cancel()
        timerTask = Task {
            for value in [3, 2, 1] {
                guard !Task.isCancelled else { return }
                phase = .countdown(value)
                HeadsUpHaptics.shared.tick()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            phase = .playing
            HeadsUpSound.shared.playStart()
            runGameTimer()
        }
    }

    private func runGameTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                timeRemaining -= 1
            }
            phase = .results
            HeadsUpSound.shared.playEnd()
            HeadsUpHaptics.shared.gameOver()
        }
    }
}

// MARK: - Motion (tilt up = correct, tilt down = pass)

@MainActor
final class HeadsUpMotion: ObservableObject {
    private let manager = CMMotionManager()
    var onCorrect: (() -> Void)?
    var onPass: (() -> Void)?

    /// Armed after user holds phone to forehead in play orientation.
    private var baselineZ: Double?
    private var lastFire = Date.distantPast

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        baselineZ = nil
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handle(gravity: motion.gravity)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        baselineZ = nil
    }

    private func handle(gravity: CMAcceleration) {
        // With phone on forehead, screen faces outward.
        // Tilting so the screen faces more toward the sky → gravity.z increases → CORRECT
        // Tilting so the screen faces more toward the floor → gravity.z decreases → PASS
        let z = gravity.z
        if baselineZ == nil {
            // Capture neutral forehead hold after a beat of stability
            if abs(gravity.y) > 0.55 || abs(gravity.x) > 0.35 {
                baselineZ = z
            }
            return
        }

        let delta = z - (baselineZ ?? 0)
        let now = Date()
        guard now.timeIntervalSince(lastFire) > 0.9 else { return }

        // Thresholds tuned for forehead play
        if delta > 0.38 {
            lastFire = now
            baselineZ = z
            onCorrect?()
        } else if delta < -0.38 {
            lastFire = now
            baselineZ = z
            onPass?()
        }
    }
}

// MARK: - Haptics & sound

@MainActor
final class HeadsUpHaptics {
    static let shared = HeadsUpHaptics()
    private init() {}

    func tick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func bump(correct: Bool) {
        if correct {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
        }
    }

    func gameOver() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

@MainActor
final class HeadsUpSound {
    static let shared = HeadsUpSound()
    private var correctPlayer: AVAudioPlayer?
    private var passPlayer: AVAudioPlayer?
    private var startPlayer: AVAudioPlayer?

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }

    func play(correct: Bool) {
        // System short sounds via AudioServices as fallback — keep silent-friendly ambient
        // Soft synth blips not required; haptics carry most feedback.
        // Optional: reuse cowbell for correct at low volume
        if correct, let url = Bundle.main.url(forResource: "cowbell", withExtension: "wav") {
            correctPlayer = try? AVAudioPlayer(contentsOf: url)
            correctPlayer?.volume = 0.35
            correctPlayer?.play()
        }
    }

    func playStart() {}
    func playEnd() {}
}

// MARK: - UI

struct HeadsUpLaunchCard: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Heads Up", systemImage: "person.crop.rectangle.stack.fill")
                .font(.headline)

            Text("Hold the phone to your forehead. Friends give clues. Tilt up for correct, tilt down to pass.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                isPresented = true
            } label: {
                Label("Play Heads Up — All Sports", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.msMaroon)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.msMaroon.opacity(0.14), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.msMaroon.opacity(0.25), lineWidth: 1)
        )
    }
}

struct HeadsUpGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = HeadsUpViewModel()
    @StateObject private var motion = HeadsUpMotion()
    @State private var keepAwake = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.phase {
            case .setup:
                setupView
            case .countdown(let n):
                countdownView(n)
            case .playing:
                playingView
            case .results:
                resultsView
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            motion.stop()
            model.quitToSetup()
        }
        .onChange(of: model.phase) { _, phase in
            if phase == .playing {
                motion.onCorrect = { model.markCorrect() }
                motion.onPass = { model.markPass() }
                motion.start()
            } else {
                motion.stop()
            }
        }
    }

    private var setupView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("MSU Heads Up")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)

                    Text("Cover every sport — football, baseball, basketball, traditions, and more. One player guesses; everyone else shouts clues.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Deck")
                        .font(.headline)
                        .foregroundStyle(.white)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(HeadsUpSport.allCases) { sport in
                            Button {
                                model.sport = sport
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: sport.systemImage)
                                        .font(.title2)
                                    Text(sport.title)
                                        .font(.caption.weight(.bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    model.sport == sport
                                        ? Color.msMaroon
                                        : Color.white.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Round length")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Picker("Duration", selection: $model.durationSeconds) {
                        Text("45s").tag(45)
                        Text("60s").tag(60)
                        Text("90s").tag(90)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("How to play", systemImage: "info.circle.fill")
                            .font(.subheadline.weight(.bold))
                        Text("1. Hold the phone to your forehead, screen facing friends.\n2. They describe the word — you don’t read it.\n3. Tilt up / screen toward sky = Correct.\n4. Tilt down / screen toward floor = Pass.\n5. Or tap the buttons if tilt is awkward.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)

                    Button {
                        model.start()
                    } label: {
                        Text("Start Round")
                            .font(.title3.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.msMaroon)
                }
                .padding(24)
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func countdownView(_ n: Int) -> some View {
        VStack(spacing: 16) {
            Text("GET READY")
                .font(.caption.weight(.heavy))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.7))
            Text("\(n)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Phone to forehead")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.msMaroon)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.msMaroon.opacity(0.5), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var playingView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    model.statusFlash != nil
                        ? (model.statusIsCorrect ? Color.green.opacity(0.55) : Color.orange.opacity(0.5))
                        : Color.msMaroon,
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.2), value: model.statusFlash)

            VStack(spacing: 0) {
                HStack {
                    Button("End") {
                        model.phase = .results
                        motion.stop()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    Text("\(model.timeRemaining)s")
                        .font(.title2.weight(.black).monospacedDigit())
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(model.correctCount)✓")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                if let flash = model.statusFlash {
                    Text(flash)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else if let card = model.currentCard {
                    // Heads Up: rotate so text is upright for people facing the holder
                    Text(card.text)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .minimumScaleFactor(0.4)
                        .rotationEffect(.degrees(180))
                        .id(card.id)
                        .transition(.opacity)

                    Text(card.sport.title.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.top, 16)
                        .rotationEffect(.degrees(180))
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        model.markPass()
                    } label: {
                        Label("Pass", systemImage: "arrow.down.circle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }

                    Button {
                        model.markCorrect()
                    } label: {
                        Label("Got it", systemImage: "arrow.up.circle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(Color.msMaroon)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                Text("Tilt ↑ correct  ·  Tilt ↓ pass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 16)
            }
        }
    }

    private var resultsView: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Round over")
                            .font(.title.weight(.black))
                        Text("\(model.correctCount) correct · \(model.passCount) passed")
                            .font(.headline)
                            .foregroundStyle(Color.msMaroonText)
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Correct") {
                    let hits = model.results.filter(\.correct)
                    if hits.isEmpty {
                        Text("None this round — try again!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(hits) { item in
                            HStack {
                                Text(item.card.text)
                                Spacer()
                                Text(item.card.sport.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Passed") {
                    let misses = model.results.filter { !$0.correct }
                    if misses.isEmpty {
                        Text("Clean sweep 🔥")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(misses) { item in
                            HStack {
                                Text(item.card.text)
                                Spacer()
                                Text(item.card.sport.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        model.start()
                    } label: {
                        Text("Play Again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.msMaroon)

                    Button("Back to Setup") {
                        model.quitToSetup()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
