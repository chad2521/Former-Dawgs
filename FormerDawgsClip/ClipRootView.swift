import StoreKit
import SwiftUI

struct ClipRootView: View {
    @StateObject private var model = ClipTonightModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.rows.isEmpty {
                    ProgressView("Loading tonight…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage, model.rows.isEmpty {
                    ContentUnavailableView(
                        "Couldn’t load games",
                        systemImage: "wifi.exclamationmark",
                        description: Text(error)
                    )
                } else if model.rows.isEmpty {
                    ContentUnavailableView(
                        "No Dawgs on the board",
                        systemImage: "sportscourt",
                        description: Text("Check back later tonight, or open the full app for the whole roster.")
                    )
                } else {
                    List {
                        if model.liveCount > 0 {
                            Section("Live now") {
                                ForEach(model.liveRows) { row in
                                    ClipGameRow(row: row)
                                }
                            }
                        }
                        if !model.upcomingRows.isEmpty {
                            Section("Up next") {
                                ForEach(model.upcomingRows) { row in
                                    ClipGameRow(row: row)
                                }
                            }
                        }
                        if !model.finalRows.isEmpty {
                            Section("Final") {
                                ForEach(model.finalRows) { row in
                                    ClipGameRow(row: row)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Former Dawgs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Text("Live scores for former Mississippi State players")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        guard let scene = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .first else { return }
                        let config = SKOverlay.AppClipConfiguration(position: .bottom)
                        let overlay = SKOverlay(configuration: config)
                        overlay.present(in: scene)
                    } label: {
                        Text("Get the full app")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.44, green: 0.04, blue: 0.12))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
    }
}

private struct ClipGameRow: View {
    let row: ClipGameRowModel

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: row.headshotURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Text(row.initials)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.44, green: 0.04, blue: 0.12))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(row.playerName)
                    .font(.subheadline.weight(.semibold))
                Text(row.headline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(row.status)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(row.state == .live ? Color.red : Color.primary)
                if let detail = row.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
