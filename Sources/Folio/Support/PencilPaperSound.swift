import AVFoundation
import Foundation
import UIKit

/// Plays short paper-scratch samples when an Apple Pencil contacts the sheet.
@MainActor
final class PencilPaperSound {
    static let shared = PencilPaperSound()

    private var scratchPlayers: [AVAudioPlayer] = []
    private var tapPlayer: AVAudioPlayer?
    private var dragPlayer: AVAudioPlayer?
    private var lastScratchTime: TimeInterval = 0
    private var lastLocation: CGPoint?
    private var isConfigured = false
    private(set) var pencilRecentlyActive = false
    private var activeResetWork: DispatchWorkItem?

    private init() {}

    func prepare() {
        guard !isConfigured else { return }
        isConfigured = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        scratchPlayers = ["pencil-scratch-a", "pencil-scratch-b", "pencil-scratch-c"]
            .compactMap { makePlayer(named: $0, volume: 0.38) }
        tapPlayer = makePlayer(named: "pencil-tap", volume: 0.45)
        dragPlayer = makePlayer(named: "pencil-drag", volume: 0.22)
        dragPlayer?.numberOfLoops = -1
    }

    func pencilBegan(at point: CGPoint, force: CGFloat) {
        prepare()
        markPencilActive()
        lastLocation = point
        tapPlayer?.currentTime = 0
        tapPlayer?.volume = Float(min(0.55, 0.28 + force * 0.35))
        tapPlayer?.play()
    }

    func pencilMoved(to point: CGPoint, force: CGFloat, timestamp: TimeInterval) {
        prepare()
        markPencilActive()
        defer { lastLocation = point }

        let distance: CGFloat
        if let last = lastLocation {
            distance = hypot(point.x - last.x, point.y - last.y)
        } else {
            distance = 0
        }

        if distance > 0.8 {
            if dragPlayer?.isPlaying != true {
                dragPlayer?.volume = Float(min(0.32, 0.12 + force * 0.25))
                dragPlayer?.play()
            } else {
                dragPlayer?.volume = Float(min(0.32, 0.12 + force * 0.25))
            }
        }

        guard timestamp - lastScratchTime > 0.045, distance > 1.6 else { return }
        lastScratchTime = timestamp
        guard let player = scratchPlayers.randomElement() else { return }
        player.currentTime = 0
        player.volume = Float(min(0.5, 0.18 + min(distance, 18) / 40 + force * 0.2))
        player.enableRate = true
        player.rate = Float(0.9 + min(distance, 24) / 80)
        player.play()
    }

    func pencilEnded() {
        fadeOutDrag()
        lastLocation = nil
        scheduleActiveClear()
    }

    func pencilCancelled() {
        fadeOutDrag()
        lastLocation = nil
        scheduleActiveClear()
    }

    /// Soft grain when Scribble inserts text and we recently saw the pencil.
    func scribbleTick() {
        guard pencilRecentlyActive else { return }
        prepare()
        guard let player = scratchPlayers.randomElement() else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastScratchTime > 0.06 else { return }
        lastScratchTime = now
        player.currentTime = 0
        player.volume = 0.22
        player.play()
    }

    private func markPencilActive() {
        pencilRecentlyActive = true
        activeResetWork?.cancel()
    }

    private func scheduleActiveClear() {
        activeResetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pencilRecentlyActive = false
        }
        activeResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func fadeOutDrag() {
        guard let drag = dragPlayer, drag.isPlaying else { return }
        drag.stop()
        drag.currentTime = 0
    }

    private func makePlayer(named name: String, volume: Float) -> AVAudioPlayer? {
        let url =
            Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
        guard let url else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        player?.volume = volume
        return player
    }
}

/// UITextView that keeps Scribble/typing working while sounding pencil-on-paper.
final class PaperInkTextView: UITextView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handlePencil(touches, phase: .began, event: event)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handlePencil(touches, phase: .moved, event: event)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.contains(where: { $0.type == .pencil }) {
            PencilPaperSound.shared.pencilEnded()
        }
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.contains(where: { $0.type == .pencil }) {
            PencilPaperSound.shared.pencilCancelled()
        }
        super.touchesCancelled(touches, with: event)
    }

    private enum Phase { case began, moved }

    private func handlePencil(_ touches: Set<UITouch>, phase: Phase, event: UIEvent?) {
        for touch in touches where touch.type == .pencil {
            let force = touch.maximumPossibleForce > 0
                ? touch.force / touch.maximumPossibleForce
                : 0.35
            switch phase {
            case .began:
                PencilPaperSound.shared.pencilBegan(at: touch.location(in: self), force: force)
            case .moved:
                let samples = event?.coalescedTouches(for: touch) ?? [touch]
                for sample in samples {
                    PencilPaperSound.shared.pencilMoved(
                        to: sample.location(in: self),
                        force: force,
                        timestamp: sample.timestamp
                    )
                }
            }
        }
    }
}

struct PaperInkEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont
    var textColor: UIColor
    var minHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> PaperInkTextView {
        PencilPaperSound.shared.prepare()
        let view = PaperInkTextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 4, left: -4, bottom: 4, right: -4)
        view.textContainer.lineFragmentPadding = 0
        view.font = font
        view.textColor = textColor
        view.tintColor = UIColor(FolioTheme.sealRed)
        view.keyboardDismissMode = .interactive
        view.alwaysBounceVertical = true
        view.isScrollEnabled = true
        view.allowsEditingTextAttributes = false
        // Scribble on the paper sheet.
        view.autocorrectionType = .yes
        return view
    }

    func updateUIView(_ uiView: PaperInkTextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = font
        uiView.textColor = textColor
        context.coordinator.text = $text
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PaperInkTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(minHeight, fitting.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        private var lastCount = 0

        init(text: Binding<String>) {
            self.text = text
            self.lastCount = text.wrappedValue.count
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            let count = textView.text.count
            if abs(count - lastCount) > 0 {
                PencilPaperSound.shared.scribbleTick()
            }
            lastCount = count
        }
    }
}
