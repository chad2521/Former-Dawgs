import MapKit
import SwiftUI

private enum TonightViewMode: String, CaseIterable, Identifiable {
    case scoreboard
    case week
    case map

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scoreboard: return "Tonight"
        case .week: return "Week"
        case .map: return "Map"
        }
    }
}

struct TonightScreen: View {
    var viewModel: HomeViewModel
    @AppStorage("favoritePlayerIDs", store: SharedAppGroup.defaults) private var favoritePlayerIDsStorage = ""
    @State private var viewMode: TonightViewMode = .scoreboard
    @State private var weekDays: [WeekDayGroup] = []
    @State private var isLoadingWeek = false
    @State private var weekError: String?
    @State private var router = IntentRouter.shared
    let onSelectPlayer: (PlayerCatalogEntry) -> Void

    private var favoriteIDs: Set<Int> {
        FavoritePlayerStore.ids(from: favoritePlayerIDsStorage)
    }

    private var scoreboard: [PlayerDashboard] {
        viewModel.summary?.tonightScoreboard ?? []
    }

    private var liveCount: Int {
        scoreboard.filter { $0.todayGame?.state == .live }.count
    }

    private var scheduledCount: Int {
        scoreboard.filter { $0.todayGame?.state == .scheduled }.count
    }

    private var finalCount: Int {
        scoreboard.filter { $0.todayGame?.state == .final }.count
    }

    private var mapPins: [TonightMapPin] {
        TonightMapPin.pins(from: scoreboard)
    }

    private var weekGameCount: Int {
        weekDays.reduce(0) { $0 + $1.entries.count }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewMode {
                case .scoreboard:
                    scoreboardScroll
                case .week:
                    weekScroll
                case .map:
                    TonightMapView(
                        pins: mapPins,
                        favoriteIDs: favoriteIDs,
                        isLoading: viewModel.isLoading && viewModel.summary == nil,
                        onSelectPlayer: onSelectPlayer
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewMode == .week ? "This Week" : "Tonight")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("View", selection: $viewMode) {
                        ForEach(TonightViewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refresh(forceRefresh: true)
                            if viewMode == .week {
                                await loadWeekSchedule(force: true)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading || isLoadingWeek)
                }
            }
        }
        .task {
            // Soft refresh when opening Tonight — reuse Home's cached roster when
            // fresh, only hit the network when needed (force via pull-to-refresh).
            await viewModel.refresh(forceRefresh: false)
            applyPendingMapRequest()
        }
        .onChange(of: router.pendingTonightMap) { _, wantsMap in
            if wantsMap {
                applyPendingMapRequest()
            }
        }
        .onAppear {
            applyPendingMapRequest()
        }
        .task(id: viewMode) {
            if viewMode == .week {
                await loadWeekSchedule(force: weekDays.isEmpty)
            }
        }
        .onChange(of: viewModel.summary?.comparisonOptions.count) { _, _ in
            if viewMode == .week {
                Task { await loadWeekSchedule(force: true) }
            }
        }
    }

    private func applyPendingMapRequest() {
        guard IntentRouter.shared.pendingTonightMap else { return }
        _ = IntentRouter.shared.consumeTonightMapRequest()
        viewMode = .map
    }

    private func loadWeekSchedule(force: Bool) async {
        guard force || weekDays.isEmpty else { return }
        let dashboards = viewModel.summary?.comparisonOptions ?? []
        guard !dashboards.isEmpty else {
            if !viewModel.isLoading {
                weekError = "Load Tonight first so team assignments are available."
            }
            return
        }
        isLoadingWeek = true
        weekError = nil
        weekDays = await PlayerService().fetchThisWeekSchedule(
            from: dashboards,
            favoriteIDs: favoriteIDs
        )
        isLoadingWeek = false
    }

    private var weekScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BrandHeader(isLandscape: false, isWidePortrait: false)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "When the Dawgs Play", systemImage: "calendar")
                    Text(
                        weekGameCount == 0
                            ? "Next 7 days of former Bulldog games — favorites float to the top of each day."
                            : "\(weekGameCount) game\(weekGameCount == 1 ? "" : "s") over the next week · favorites first"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)

                    if !favoriteIDs.isEmpty {
                        let favGames = weekDays.flatMap(\.entries).filter(\.isFavorite).count
                        Label("\(favGames) favorite appearance\(favGames == 1 ? "" : "s")", systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.msMaroonText)
                    }
                }

                if isLoadingWeek && weekDays.isEmpty {
                    LoadingView()
                } else if let weekError, weekDays.isEmpty {
                    ErrorRetryView(message: weekError) {
                        Task {
                            await viewModel.refresh(forceRefresh: true)
                            await loadWeekSchedule(force: true)
                        }
                    }
                } else {
                    ForEach(weekDays) { day in
                        weekDaySection(day)
                    }
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.refresh(forceRefresh: true)
            await loadWeekSchedule(force: true)
        }
    }

    private func weekDaySection(_ day: WeekDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.dayTitle)
                    .font(.headline)
                Text(day.daySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(day.entries.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            if day.entries.isEmpty {
                Text("Off day for the State pipeline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(day.entries) { entry in
                    WeekScheduleRow(entry: entry) {
                        onSelectPlayer(entry.player)
                    }
                }
            }
        }
    }

    private var scoreboardScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BrandHeader(isLandscape: false, isWidePortrait: false)

                scoreboardHeader

                mapPromoCard

                if viewModel.isLoading, viewModel.summary == nil {
                    LoadingView()
                } else if scoreboard.isEmpty {
                    emptyState
                } else {
                    filterChips
                    ForEach(scoreboard, id: \.catalogEntry.id) { dashboard in
                        TonightGameRow(
                            dashboard: dashboard,
                            isFavorite: favoriteIDs.contains(dashboard.catalogEntry.id),
                            onSelect: { onSelectPlayer(dashboard.catalogEntry) },
                            onTrack: {
                                DawgLiveActivityManager.shared.startOrUpdate(for: dashboard)
                            }
                        )
                    }
                }

                if let error = viewModel.errorMessage {
                    ErrorRetryView(message: error) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .padding(20)
        }
        .refreshable { await viewModel.refresh(forceRefresh: true) }
    }

    private var mapPromoCard: some View {
        Button {
            viewMode = .map
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.msMaroon)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Where they play tonight")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(
                        mapPins.isEmpty
                            ? "Open the map once games post — every Dawg ballpark, one view."
                            : "\(mapPins.count) ballpark\(mapPins.count == 1 ? "" : "s") with Dawgs · tap to explore"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var scoreboardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Dawg Night Scoreboard", systemImage: "sportscourt.fill")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                StatTile(label: "Playing", value: String(scoreboard.count))
                StatTile(label: "Live", value: String(liveCount))
                StatTile(label: "Upcoming", value: String(scheduledCount))
                StatTile(label: "Final", value: String(finalCount))
            }

            Text(headerSubtitle)
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
        }
    }

    private var headerSubtitle: String {
        if scoreboard.isEmpty {
            return "Pull to refresh once first pitch windows open across the minors and majors."
        }
        if liveCount > 0 {
            return "\(liveCount) Dawg\(liveCount == 1 ? "" : "s") live right now — tap Track Live for the Lock Screen."
        }
        if scheduledCount > 0 {
            return "\(scheduledCount) game\(scheduledCount == 1 ? "" : "s") still on the docket tonight."
        }
        return "All of today's Dawg games are final."
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if liveCount > 0 {
                    Label("\(liveCount) Live", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                if !favoriteIDs.isEmpty {
                    let favPlaying = scoreboard.filter { favoriteIDs.contains($0.catalogEntry.id) }.count
                    if favPlaying > 0 {
                        Label("\(favPlaying) Favorites", systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.msMaroon.opacity(0.15))
                            .foregroundStyle(Color.msMaroonText)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No Dawgs on the board yet")
                .font(.headline)
            Text("When former Bulldogs have a scheduled or live game, they show up here with scores, first pitch times, and Live Activity tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Map

struct TonightMapPin: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let venueName: String
    let city: String?
    let players: [PlayerDashboard]

    var hasLive: Bool {
        players.contains { $0.todayGame?.state == .live }
    }

    var title: String {
        if players.count == 1 {
            return players[0].catalogEntry.displayName
        }
        return "\(players.count) Dawgs"
    }

    var subtitle: String {
        [venueName, city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func pins(from dashboards: [PlayerDashboard]) -> [TonightMapPin] {
        var buckets: [String: (coord: CLLocationCoordinate2D, venue: String, city: String?, players: [PlayerDashboard])] = [:]

        for dashboard in dashboards {
            guard let resolved = resolveCoordinate(for: dashboard) else { continue }
            let key = coordinateKey(resolved.coordinate)
            var bucket = buckets[key] ?? (resolved.coordinate, resolved.venueName, resolved.city, [])
            bucket.players.append(dashboard)
            if bucket.venue == "Ballpark", resolved.venueName != "Ballpark" {
                bucket.venue = resolved.venueName
            }
            if bucket.city == nil {
                bucket.city = resolved.city
            }
            buckets[key] = bucket
        }

        return buckets.map { key, value in
            TonightMapPin(
                id: key,
                coordinate: value.coord,
                venueName: value.venue,
                city: value.city,
                players: value.players.sorted {
                    $0.catalogEntry.displayName.localizedCaseInsensitiveCompare($1.catalogEntry.displayName) == .orderedAscending
                }
            )
        }
        .sorted { $0.venueName.localizedCaseInsensitiveCompare($1.venueName) == .orderedAscending }
    }

    private static func coordinateKey(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.3f,%.3f", coordinate.latitude, coordinate.longitude)
    }

    private static func resolveCoordinate(
        for dashboard: PlayerDashboard
    ) -> (coordinate: CLLocationCoordinate2D, venueName: String, city: String?)? {
        guard let game = dashboard.todayGame else { return nil }

        if let lat = game.latitude, let lon = game.longitude {
            return (
                CLLocationCoordinate2D(latitude: lat, longitude: lon),
                game.venueName ?? "Ballpark",
                game.venueCity
            )
        }

        if let homeTeamID = game.homeTeamID, let park = BallparkCatalog.park(forTeamID: homeTeamID) {
            return (
                CLLocationCoordinate2D(latitude: park.latitude, longitude: park.longitude),
                game.venueName ?? park.name,
                game.venueCity ?? park.city
            )
        }

        if game.isHome, let teamID = dashboard.profile.currentTeam?.id,
           let park = BallparkCatalog.park(forTeamID: teamID) {
            return (
                CLLocationCoordinate2D(latitude: park.latitude, longitude: park.longitude),
                game.venueName ?? park.name,
                game.venueCity ?? park.city
            )
        }

        return nil
    }
}

// Hashable for CLLocationCoordinate2D via pin identity only
extension TonightMapPin {
    static func == (lhs: TonightMapPin, rhs: TonightMapPin) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TonightMapView: View {
    let pins: [TonightMapPin]
    let favoriteIDs: Set<Int>
    let isLoading: Bool
    let onSelectPlayer: (PlayerCatalogEntry) -> Void

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 45)
        )
    )
    @State private var selectedPinID: String?
    @State private var didFitPins = false

    private var selectedPin: TonightMapPin? {
        pins.first { $0.id == selectedPinID }
    }

    var body: some View {
        VStack(spacing: 0) {
            mapHeader

            ZStack(alignment: .bottom) {
                Map(position: $position, selection: $selectedPinID) {
                    ForEach(pins) { pin in
                        Annotation(pin.title, coordinate: pin.coordinate, anchor: .bottom) {
                            TonightMapPinMarker(
                                pin: pin,
                                isSelected: selectedPinID == pin.id
                            )
                            .onTapGesture {
                                selectedPinID = pin.id
                            }
                        }
                        .tag(pin.id)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapPitchToggle()
                    MapScaleView()
                }

                if isLoading && pins.isEmpty {
                    ProgressView("Loading ballparks…")
                        .padding(14)
                        .background(.ultraThinMaterial, in: Capsule())
                } else if pins.isEmpty {
                    emptyMapCard
                        .padding()
                }

                if let selectedPin {
                    pinDetailCard(selectedPin)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35), value: selectedPinID)
        }
        .onAppear { fitMapToPinsIfNeeded() }
        .onChange(of: pins.map(\.id).joined(separator: "|")) { _, _ in
            didFitPins = false
            fitMapToPinsIfNeeded()
        }
    }

    private var mapHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Where They Play Tonight", systemImage: "map.fill")
            Text(
                pins.isEmpty
                    ? "Pins appear when Dawgs have a venue for today’s games."
                    : "\(pins.count) ballpark\(pins.count == 1 ? "" : "s") · \(pins.reduce(0) { $0 + $1.players.count }) player\(pins.reduce(0) { $0 + $1.players.count } == 1 ? "" : "s")"
            )
            .font(.caption)
            .foregroundStyle(Color.appSecondaryText)

            pinLegend
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    private var pinLegend: some View {
        HStack(spacing: 16) {
            legendItem(
                color: .red,
                title: "Live",
                detail: "Game in progress"
            )
            legendItem(
                color: .msMaroon,
                title: "Maroon",
                detail: "Scheduled or final"
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func legendItem(color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyMapCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.title2)
                .foregroundStyle(Color.msMaroonText)
            Text("No mappable games yet")
                .font(.headline)
            Text("Pull to refresh from Scoreboard once first pitch listings post. MLB parks and hydrated minor-league venues show up here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func pinDetailCard(_ pin: TonightMapPin) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.venueName)
                        .font(.headline)
                    if let city = pin.city, !city.isEmpty {
                        Text(city)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    selectedPinID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(pin.players, id: \.catalogEntry.id) { dashboard in
                Button {
                    onSelectPlayer(dashboard.catalogEntry)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stateColor(dashboard.todayGame?.state))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(dashboard.catalogEntry.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if favoriteIDs.contains(dashboard.catalogEntry.id) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.msMaroonText)
                                }
                            }
                            Text(dashboard.todayGame?.headline ?? dashboard.teamLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(dashboard.todayGame?.statusText ?? "—")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(stateColor(dashboard.todayGame?.state))

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private func stateColor(_ state: TodayGame.State?) -> Color {
        switch state {
        case .live: return .red
        case .final: return .secondary
        case .scheduled, .none: return Color.msMaroon
        }
    }

    private func fitMapToPinsIfNeeded() {
        guard !didFitPins, !pins.isEmpty else { return }
        didFitPins = true

        if pins.count == 1, let pin = pins.first {
            position = .region(
                MKCoordinateRegion(
                    center: pin.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
                )
            )
            return
        }

        let lats = pins.map(\.coordinate.latitude)
        let lons = pins.map(\.coordinate.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latDelta = max((maxLat - minLat) * 1.45, 4)
        let lonDelta = max((maxLon - minLon) * 1.45, 4)
        position = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        )
    }
}

private struct TonightMapPinMarker: View {
    let pin: TonightMapPin
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: isSelected ? 40 : 34, height: isSelected ? 40 : 34)
                Circle()
                    .fill(pin.hasLive ? Color.red : Color.msMaroon)
                    .frame(width: isSelected ? 32 : 26, height: isSelected ? 32 : 26)
                if pin.players.count > 1 {
                    Text("\(pin.players.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "baseball.fill")
                        .font(.system(size: isSelected ? 13 : 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            Triangle()
                .fill(pin.hasLive ? Color.red : Color.msMaroon)
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .animation(.spring(response: 0.28), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct TonightGameRow: View {
    let dashboard: PlayerDashboard
    let isFavorite: Bool
    let onSelect: () -> Void
    let onTrack: () -> Void

    private var game: TodayGame? { dashboard.todayGame }

    private var isTracking: Bool {
        DawgLiveActivityManager.shared.activeActivity(for: dashboard.catalogEntry.id) != nil
    }

    private var todayLine: String? {
        guard let log = dashboard.gameLogs.first else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: log.dateText),
              Calendar.current.isDateInToday(date) else {
            return nil
        }
        return log.line
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    stateBadge

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(dashboard.catalogEntry.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.msMaroonText)
                            }
                        }
                        Text(dashboard.teamLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let game {
                            Text(game.headline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        if let venue = game?.venueName {
                            Text(venue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(game?.statusText ?? "—")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(scoreColor)
                        if let todayLine {
                            Text(todayLine)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button(action: onSelect) {
                    Label("Player", systemImage: "person.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                if let game, game.state != .final {
                    Button(action: onTrack) {
                        Label(
                            isTracking ? "Tracking" : "Track Live",
                            systemImage: isTracking ? "dot.radiowaves.left.and.right" : "bell.badge.fill"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isTracking ? .gray : .msMaroon)
                    .disabled(isTracking)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(game?.state == .live ? Color.red.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
    }

    private var stateBadge: some View {
        Image(systemName: badgeIcon)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(badgeColor)
            .clipShape(Circle())
    }

    private var badgeIcon: String {
        switch game?.state {
        case .live: return "dot.radiowaves.left.and.right"
        case .final: return "flag.checkered"
        case .scheduled, .none: return "clock.fill"
        }
    }

    private var badgeColor: Color {
        switch game?.state {
        case .live: return .red
        case .final: return .gray
        case .scheduled, .none: return .blue
        }
    }

    private var scoreColor: Color {
        switch game?.state {
        case .live: return .red
        case .final: return .secondary
        case .scheduled, .none: return Color.msMaroonText
        }
    }
}

private struct WeekScheduleRow: View {
    let entry: WeekScheduleEntry
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                PlayerHeadshotImage(
                    url: entry.player.headshotURL,
                    initials: entry.player.initials,
                    accessibilityLabel: "\(entry.player.displayName) headshot",
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.player.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if entry.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                    Text("\(entry.player.role) · \(entry.player.levelLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.game.headline)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.msMaroonText)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.game.statusText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(statusColor)
                    if let venue = entry.game.venueName, !venue.isEmpty {
                        Text(venue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(entry.isFavorite ? Color.msMaroon.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch entry.game.state {
        case .live: return .red
        case .final: return .secondary
        case .scheduled: return Color.msMaroonText
        }
    }
}
