import MapKit
import SwiftUI

/// Real-world cinematic intro over Dudy Noble Field (Polk–DeMent Stadium), Starkville.
/// Note: Davis Wade (football) sits ~0.4 mi south — do NOT use those coords.
enum DudyNobleField {
    /// Baseball diamond center — Wikipedia / USGS landmark for Dudy Noble Field.
    /// 33°27′46″N 88°47′40″W → 33.4628, -88.7944
    static let coordinate = CLLocationCoordinate2D(latitude: 33.4628, longitude: -88.7944)
    static let name = "Dudy Noble Field"
    static let subtitle = "Polk–DeMent Stadium · Home of Bulldog Baseball"
}

/// Immersive 3D satellite flyover used as the Former Dawgs home landing.
struct StadiumFlyoverHero: View {
    var height: CGFloat = 480
    var tonightLiveCount: Int = 0
    var activeTodayCount: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Start looking in from left-field / outfield so the diamond and LF lounge read clearly.
    @State private var heading: Double = 135
    @State private var distance: Double = 720
    @State private var pitch: Double = 58
    @State private var titleVisible = false
    @State private var orbitTask: Task<Void, Never>?
    @State private var mapPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: DudyNobleField.coordinate,
            distance: 720,
            heading: 135,
            pitch: 58
        )
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            vignette
            brandingOverlay
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) {
                titleVisible = true
            }
            startOrbitIfNeeded()
        }
        .onDisappear {
            orbitTask?.cancel()
            orbitTask = nil
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flyover of Dudy Noble Field, home of Mississippi State baseball. Former Dawgs, State to the Show.")
    }

    private var mapLayer: some View {
        Map(position: $mapPosition) {
            Annotation(DudyNobleField.name, coordinate: DudyNobleField.coordinate, anchor: .bottom) {
                Image(systemName: "baseball.diamond.bases")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.msMaroon, in: Circle())
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .disabled(true)
    }

    private var vignette: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Color.clear, Color.msMaroon.opacity(0.5)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    private var brandingOverlay: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)

            Text("HAIL STATE")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.8))
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 12)

            Text("Former Dawgs")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 16)

            Text("State to the Show")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 12)

            Text(DudyNobleField.subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .opacity(titleVisible ? 1 : 0)

            HStack(spacing: 8) {
                if activeTodayCount > 0 {
                    heroChip("\(activeTodayCount) active today", systemImage: "calendar")
                }
                if tonightLiveCount > 0 {
                    heroChip("\(tonightLiveCount) LIVE", systemImage: "dot.radiowaves.left.and.right")
                }
                heroChip("Dudy Noble", systemImage: "mappin.and.ellipse")
            }
            .opacity(titleVisible ? 1 : 0)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    private func heroChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.white)
    }

    private func applyCamera() {
        mapPosition = .camera(
            MapCamera(
                centerCoordinate: DudyNobleField.coordinate,
                distance: distance,
                heading: heading,
                pitch: pitch
            )
        )
    }

    private func startOrbitIfNeeded() {
        orbitTask?.cancel()
        if reduceMotion {
            // Static elevated view of the baseball diamond (not the football bowl).
            heading = 145
            distance = 850
            pitch = 55
            applyCamera()
            return
        }

        applyCamera()
        orbitTask = Task { @MainActor in
            var t = 0.0
            while !Task.isCancelled {
                t += 0.02
                // Tight orbit around the diamond — stay close enough to read baseball layout.
                heading = (heading + 0.28).truncatingRemainder(dividingBy: 360)
                distance = 680 + sin(t * 0.5) * 90
                pitch = 54 + cos(t * 0.35) * 6
                applyCamera()
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }
}
