import AVFoundation
import SceneKit
import SwiftUI
import UIKit

// MARK: - Screen

struct CowbellScreen: View {
    @State private var ringToken = 0
    @State private var showHint = true
    @State private var lastRingAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    CowbellSceneView(ringToken: ringToken)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 8)

                    controls
                        .padding(20)
                }

                ShakeDetectorView {
                    ring(reason: "shake")
                }
                .frame(width: 0, height: 0)
            }
            .navigationTitle("Cowbell")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                CowbellAudio.shared.prepare()
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.95, blue: 0.96),
                Color(red: 0.88, green: 0.88, blue: 0.90),
                Color(red: 0.78, green: 0.78, blue: 0.82)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("HAIL STATE")
                .font(.caption.weight(.heavy))
                .tracking(3)
                .foregroundStyle(Color.msMaroon.opacity(0.85))
            Text("The Cowbell")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.15, green: 0.12, blue: 0.12))
            Text(showHint ? "Shake your phone — or tap RING IT" : "Official look · wood handle · State script")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: showHint)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Button {
                ring(reason: "tap")
            } label: {
                Label("RING IT", systemImage: "bell.fill")
                    .font(.title3.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.msMaroon, Color(red: 0.55, green: 0.08, blue: 0.16)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .foregroundStyle(.white)
                    .shadow(color: Color.msMaroon.opacity(0.45), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 1.0), trigger: ringToken)

            Text("Shake hard · volume up · Hail State")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func ring(reason: String) {
        if let last = lastRingAt, Date().timeIntervalSince(last) < 0.12 { return }
        lastRingAt = Date()
        ringToken &+= 1
        showHint = false
        CowbellAudio.shared.playLoud()
        if !reduceMotion {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }
    }
}

// MARK: - 3D Scene

struct CowbellSceneView: UIViewRepresentable {
    var ringToken: Int

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = CowbellSceneBuilder.makeScene()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        context.coordinator.sceneView = view
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if context.coordinator.lastRingToken != ringToken {
            context.coordinator.lastRingToken = ringToken
            CowbellSceneBuilder.animateRing(in: uiView.scene)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var sceneView: SCNView?
        var lastRingToken = 0
    }
}

/// Matches the classic MSU souvenir cowbell:
/// brushed silver trapezoid body, short chrome stem, wood handle, “State” script face.
enum CowbellSceneBuilder {
    static let bellName = "cowbell"
    static let clapperName = "clapper"
    static let swingName = "swingPivot"

    static func makeScene() -> SCNScene {
        let scene = SCNScene()

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 30
        cameraNode.camera?.wantsHDR = true
        cameraNode.position = SCNVector3(0.65, 0.55, 4.1)
        cameraNode.look(at: SCNVector3(0, 0.20, 0))
        scene.rootNode.addChildNode(cameraNode)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1_050
        key.light?.castsShadow = true
        key.eulerAngles = SCNVector3(-0.75, 0.55, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.intensity = 500
        fill.light?.color = UIColor(white: 0.98, alpha: 1)
        fill.position = SCNVector3(-1.8, 2.0, 2.2)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .omni
        rim.light?.intensity = 280
        rim.light?.color = UIColor(white: 0.9, alpha: 1)
        rim.position = SCNVector3(1.6, 0.6, -1.4)
        scene.rootNode.addChildNode(rim)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 220
        ambient.light?.color = UIColor(white: 0.7, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Soft studio ground (matches white product photo vibe)
        let floor = SCNFloor()
        floor.reflectivity = 0.05
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -1.35, 0)
        floorNode.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.92, alpha: 1)
        floorNode.geometry?.firstMaterial?.lightingModel = .physicallyBased
        floorNode.geometry?.firstMaterial?.roughness.contents = 0.9
        scene.rootNode.addChildNode(floorNode)

        let bellRoot = makeCowbellNode()
        bellRoot.name = bellName
        bellRoot.position = SCNVector3(0, -0.64, 0)
        scene.rootNode.addChildNode(bellRoot)

        let spin = SCNAction.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20))
        bellRoot.runAction(spin, forKey: "idleSpin")

        return scene
    }

    static func makeCowbellNode() -> SCNNode {
        let root = SCNNode()

        // Brushed silver / stainless look (not shiny gold brass)
        let silver = SCNMaterial()
        silver.lightingModel = .physicallyBased
        silver.metalness.contents = 1.0
        silver.roughness.contents = 0.38
        silver.diffuse.contents = UIColor(red: 0.78, green: 0.80, blue: 0.83, alpha: 1)
        silver.emission.contents = UIColor(white: 0.06, alpha: 1)
        silver.emission.intensity = 0.04

        let brightChrome = SCNMaterial()
        brightChrome.lightingModel = .physicallyBased
        brightChrome.metalness.contents = 1.0
        brightChrome.roughness.contents = 0.18
        brightChrome.diffuse.contents = UIColor(red: 0.85, green: 0.87, blue: 0.90, alpha: 1)

        // Light wood handle (maple / birch like the product photo)
        let wood = SCNMaterial()
        wood.lightingModel = .physicallyBased
        wood.metalness.contents = 0.0
        wood.roughness.contents = 0.72
        wood.diffuse.contents = UIColor(red: 0.78, green: 0.58, blue: 0.36, alpha: 1)

        let woodDark = SCNMaterial()
        woodDark.lightingModel = .physicallyBased
        woodDark.metalness.contents = 0.0
        woodDark.roughness.contents = 0.78
        woodDark.diffuse.contents = UIColor(red: 0.62, green: 0.42, blue: 0.24, alpha: 1)

        let swing = SCNNode()
        swing.name = swingName
        root.addChildNode(swing)

        // —— Trapezoid body: single solid shell (like the product photo) ——
        // Profile: narrow top, wide open bottom
        let profile = UIBezierPath()
        profile.move(to: CGPoint(x: -0.38, y: 0.62))
        profile.addLine(to: CGPoint(x: 0.38, y: 0.62))
        profile.addLine(to: CGPoint(x: 0.72, y: -0.75))
        profile.addLine(to: CGPoint(x: -0.72, y: -0.75))
        profile.close()
        profile.flatness = 0.002

        let bodyShape = SCNShape(path: profile, extrusionDepth: 0.74)
        bodyShape.chamferRadius = 0.025
        bodyShape.materials = [silver]
        let bodyNode = SCNNode(geometry: bodyShape)
        bodyNode.position = SCNVector3(0, 0.03, 0)
        swing.addChildNode(bodyNode)

        // Slight bevel lip at open bottom
        let lip = SCNBox(width: 1.48, height: 0.045, length: 0.80, chamferRadius: 0.018)
        lip.materials = [silver]
        let lipNode = SCNNode(geometry: lip)
        lipNode.position = SCNVector3(0, -0.73, 0)
        swing.addChildNode(lipNode)

        // Crown plate under the stem
        let crown = SCNBox(width: 0.86, height: 0.065, length: 0.76, chamferRadius: 0.012)
        crown.materials = [silver]
        let crownNode = SCNNode(geometry: crown)
        crownNode.position = SCNVector3(0, 0.66, 0)
        swing.addChildNode(crownNode)

        // Dark open mouth at the bottom without filling the whole front face.
        let mouth = SCNBox(width: 1.18, height: 0.055, length: 0.50, chamferRadius: 0.02)
        let mouthMat = SCNMaterial()
        mouthMat.diffuse.contents = UIColor(white: 0.16, alpha: 1)
        mouthMat.lightingModel = .physicallyBased
        mouthMat.metalness.contents = 0.35
        mouthMat.roughness.contents = 0.6
        mouth.materials = [mouthMat]
        let mouthNode = SCNNode(geometry: mouth)
        mouthNode.position = SCNVector3(0, -0.77, 0.02)
        swing.addChildNode(mouthNode)

        // Clapper
        let clapperMat = SCNMaterial()
        clapperMat.lightingModel = .physicallyBased
        clapperMat.metalness.contents = 1.0
        clapperMat.roughness.contents = 0.32
        clapperMat.diffuse.contents = UIColor(red: 0.72, green: 0.74, blue: 0.76, alpha: 1)

        let clapper = SCNSphere(radius: 0.10)
        clapper.materials = [clapperMat]
        let clapperNode = SCNNode(geometry: clapper)
        clapperNode.name = clapperName
        clapperNode.position = SCNVector3(0, -0.36, 0)
        swing.addChildNode(clapperNode)

        let wire = SCNCylinder(radius: 0.01, height: 0.42)
        wire.materials = [clapperMat]
        let wireNode = SCNNode(geometry: wire)
        wireNode.position = SCNVector3(0, -0.06, 0)
        swing.addChildNode(wireNode)

        // “State” script on the front face
        let logoPlane = SCNPlane(width: 0.78, height: 0.34)
        let logoMat = SCNMaterial()
        logoMat.lightingModel = .constant
        logoMat.isDoubleSided = true
        logoMat.transparencyMode = .aOne
        if let url = Bundle.main.url(forResource: "state_script", withExtension: "png")
            ?? Bundle.main.url(forResource: "state_script", withExtension: "png", subdirectory: "Resources"),
           let img = UIImage(contentsOfFile: url.path) {
            logoMat.diffuse.contents = img
        } else {
            // Fallback: SCNText
            logoMat.diffuse.contents = UIColor.clear
        }
        logoMat.transparent.contents = logoMat.diffuse.contents
        logoPlane.materials = [logoMat]
        let logoNode = SCNNode(geometry: logoPlane)
        // Sit on the front face of the trapezoid body
        logoNode.position = SCNVector3(0, -0.04, 0.395)
        logoNode.eulerAngles.x = -0.04
        swing.addChildNode(logoNode)

        // If texture missing, add SCNText fallback
        if logoMat.diffuse.contents is UIColor {
            let text = SCNText(string: "State", extrusionDepth: 0.02)
            text.font = UIFont(name: "SnellRoundhand-Bold", size: 0.28)
                ?? UIFont(name: "Georgia-Italic", size: 0.28)
                ?? UIFont.italicSystemFont(ofSize: 0.28)
            text.flatness = 0.1
            text.chamferRadius = 0.002
            let textMat = SCNMaterial()
            textMat.diffuse.contents = UIColor(white: 0.12, alpha: 1)
            textMat.lightingModel = .physicallyBased
            text.materials = [textMat]
            let textNode = SCNNode(geometry: text)
            // Center text
            let (minB, maxB) = textNode.boundingBox
            let tw = maxB.x - minB.x
            let th = maxB.y - minB.y
            textNode.pivot = SCNMatrix4MakeTranslation(minB.x + tw / 2, minB.y + th / 2, 0)
            textNode.position = SCNVector3(0, -0.04, 0.405)
            textNode.scale = SCNVector3(1, 1, 1)
            swing.addChildNode(textNode)

            // Swoosh under text
            let swoosh = SCNBox(width: 0.55, height: 0.025, length: 0.02, chamferRadius: 0.01)
            swoosh.materials = [textMat]
            let swooshNode = SCNNode(geometry: swoosh)
            swooshNode.position = SCNVector3(0.04, -0.20, 0.405)
            swooshNode.eulerAngles.z = -0.08
            swing.addChildNode(swooshNode)
        }

        // —— Short chrome stem (not the long bicycle shaft) ——
        let stem = SCNCylinder(radius: 0.06, height: 0.28)
        stem.materials = [brightChrome]
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, 0.82, 0)
        swing.addChildNode(stemNode)

        // Weld fillet at base of stem
        let fillet = SCNSphere(radius: 0.07)
        fillet.materials = [brightChrome]
        let filletNode = SCNNode(geometry: fillet)
        filletNode.position = SCNVector3(0, 0.69, 0)
        filletNode.scale = SCNVector3(1.1, 0.55, 1.1)
        swing.addChildNode(filletNode)

        // Shiny collar / ferrule where wood meets metal
        let collar = SCNCylinder(radius: 0.13, height: 0.13)
        collar.materials = [brightChrome]
        let collarNode = SCNNode(geometry: collar)
        collarNode.position = SCNVector3(0, 1.01, 0)
        swing.addChildNode(collarNode)

        let collarRing = SCNTorus(ringRadius: 0.13, pipeRadius: 0.012)
        collarRing.materials = [brightChrome]
        let collarRingNode = SCNNode(geometry: collarRing)
        collarRingNode.position = SCNVector3(0, 1.06, 0)
        collarRingNode.eulerAngles.x = .pi / 2
        swing.addChildNode(collarRingNode)

        // —— Wood handle (tapered, rounded top like the product photo) ——
        // Stacked tapered capsules approximate a turned wood handle
        let handleRoot = SCNNode()
        handleRoot.position = SCNVector3(0, 1.07, 0)

        // Lower wood section (thinner where it enters the collar)
        let woodLow = SCNCylinder(radius: 0.085, height: 0.24)
        woodLow.materials = [wood]
        let woodLowNode = SCNNode(geometry: woodLow)
        woodLowNode.position = SCNVector3(0, 0.12, 0)
        handleRoot.addChildNode(woodLowNode)

        // Main grip — slightly fatter mid
        let woodMid = SCNCylinder(radius: 0.125, height: 0.78)
        woodMid.materials = [wood]
        let woodMidNode = SCNNode(geometry: woodMid)
        woodMidNode.position = SCNVector3(0, 0.58, 0)
        woodMidNode.scale = SCNVector3(0.92, 1.0, 0.92)
        handleRoot.addChildNode(woodMidNode)

        // Upper bulge
        let woodTop = SCNSphere(radius: 0.13)
        woodTop.materials = [wood]
        let woodTopNode = SCNNode(geometry: woodTop)
        woodTopNode.position = SCNVector3(0, 1.00, 0)
        woodTopNode.scale = SCNVector3(0.9, 1.25, 0.9)
        handleRoot.addChildNode(woodTopNode)

        // Rounded end cap
        let woodCap = SCNSphere(radius: 0.12)
        woodCap.materials = [wood]
        let woodCapNode = SCNNode(geometry: woodCap)
        woodCapNode.position = SCNVector3(0, 1.12, 0)
        woodCapNode.scale = SCNVector3(0.86, 0.62, 0.86)
        handleRoot.addChildNode(woodCapNode)

        // Grain rings (subtle darker bands)
        for i in 0..<7 {
            let band = SCNTorus(ringRadius: 0.112, pipeRadius: 0.005)
            band.materials = [woodDark]
            let bandNode = SCNNode(geometry: band)
            bandNode.position = SCNVector3(0, 0.28 + Float(i) * 0.10, 0)
            bandNode.eulerAngles.x = .pi / 2
            bandNode.opacity = i.isMultiple(of: 2) ? 0.24 : 0.16
            handleRoot.addChildNode(bandNode)
        }

        swing.addChildNode(handleRoot)

        // Product-photo angle
        root.eulerAngles = SCNVector3(-0.08, 0.46, 0.04)
        return root
    }

    static func animateRing(in scene: SCNScene?) {
        guard let bell = scene?.rootNode.childNode(withName: bellName, recursively: true) else { return }
        let pivot = bell.childNode(withName: swingName, recursively: true) ?? bell
        pivot.removeAction(forKey: "ring")

        let kick = SCNAction.rotateBy(x: 0.55, y: 0, z: -0.18, duration: 0.04)
        let kick2 = SCNAction.rotateBy(x: -0.95, y: 0, z: 0.28, duration: 0.07)
        let kick3 = SCNAction.rotateBy(x: 0.55, y: 0, z: -0.15, duration: 0.08)
        let settle = SCNAction.rotateBy(x: -0.15, y: 0, z: 0.05, duration: 0.15)
        pivot.runAction(.sequence([kick, kick2, kick3, settle]), forKey: "ring")

        if let clapper = bell.childNode(withName: clapperName, recursively: true) {
            clapper.removeAction(forKey: "clap")
            let c1 = SCNAction.moveBy(x: 0.2, y: 0.04, z: 0, duration: 0.045)
            let c2 = SCNAction.moveBy(x: -0.38, y: -0.08, z: 0, duration: 0.07)
            let c3 = SCNAction.moveBy(x: 0.18, y: 0.04, z: 0, duration: 0.1)
            clapper.runAction(.sequence([c1, c2, c3]), forKey: "clap")
        }
    }
}

// MARK: - Loud audio

@MainActor
final class CowbellAudio {
    static let shared = CowbellAudio()

    private var players: [AVAudioPlayer] = []
    private var nextSlot = 0
    private let poolSize = 4

    private init() {}

    func prepare() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)
        } catch {}

        guard players.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "cowbell", withExtension: "wav")
                ?? Bundle.main.url(forResource: "cowbell", withExtension: "wav", subdirectory: "Resources") else {
            if let data = Self.synthesizeCowbellData() {
                for _ in 0..<poolSize {
                    if let player = try? AVAudioPlayer(data: data) {
                        player.prepareToPlay()
                        player.volume = 1.0
                        players.append(player)
                    }
                }
            }
            return
        }

        for _ in 0..<poolSize {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                player.volume = 1.0
                players.append(player)
            }
        }
    }

    func playLoud() {
        if players.isEmpty { prepare() }
        guard !players.isEmpty else { return }
        let player = players[nextSlot % players.count]
        nextSlot += 1
        player.volume = 1.0
        player.currentTime = 0
        player.play()

        if players.count > 1 {
            let layer = players[nextSlot % players.count]
            if !layer.isPlaying {
                layer.volume = 0.85
                layer.currentTime = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    layer.play()
                }
            }
        }
    }

    private static func synthesizeCowbellData() -> Data? {
        let sr = 44100
        let n = Int(Double(sr) * 1.0)
        var samples = [Float](repeating: 0, count: n)
        let partials: [(Float, Float, Float)] = [
            (780, 1.0, 9), (1085, 0.85, 8), (1450, 0.5, 12), (2100, 0.25, 16)
        ]
        for i in 0..<n {
            let t = Float(i) / Float(sr)
            var s: Float = exp(-t * 100) * (t < 0.003 ? 0.8 : 0)
            for (f, a, d) in partials {
                s += a * sin(2 * .pi * f * t) * exp(-t * d)
            }
            samples[i] = tanh(s * 1.5)
        }
        let peak = samples.map { abs($0) }.max() ?? 1
        var data = Data()
        func appendU32(_ v: UInt32) {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 4))
        }
        func appendU16(_ v: UInt16) {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        let dataSize = UInt32(n * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        appendU32(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendU32(16)
        appendU16(1)
        appendU16(1)
        appendU32(UInt32(sr))
        appendU32(UInt32(sr * 2))
        appendU16(2)
        appendU16(16)
        data.append(contentsOf: Array("data".utf8))
        appendU32(dataSize)
        for s in samples {
            var v = Int16((s / peak) * 32767).littleEndian
            data.append(Data(bytes: &v, count: 2))
        }
        return data
    }
}

// MARK: - Shake detection

struct ShakeDetectorView: UIViewControllerRepresentable {
    var onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

final class ShakeViewController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        onShake?()
    }
}
