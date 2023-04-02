import Foundation
import UIKit
import AVFoundation

class PlayerView: UIView {

    // Override the property to make AVPlayerLayer the view's backing layer.
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    
    // The associated player object.
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

final class ViewController: UIViewController {
    
    private lazy var playerItem: AVPlayerItem = {
        let composition = makeComposition()
        let videoComposition = makeVideoComposition(for: composition)

        let playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = videoComposition
        return playerItem
    }()
    
    private lazy var player: AVQueuePlayer = {
        let player = AVQueuePlayer()
        return player
    }()
    
    private lazy var looper: AVPlayerLooper = {
        let looper = AVPlayerLooper(player: player, templateItem: playerItem)
        return looper
    }()
    
    private lazy var playerView: PlayerView = {
        let playerView = PlayerView()
        playerView.player = player
        return playerView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(playerView)
        
        let exportAction = UIAction(title: "Export") { [weak self] _ in
            self?.export()
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Export", primaryAction: exportAction, menu: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        _ = looper
        player.play()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerView.frame = view.safeAreaBounds
    }
    
    private func makeComposition() -> AVComposition {
        let videoURL = Bundle.main.url(forResource: "original", withExtension: "MOV")!
        let asset = AVURLAsset(url: videoURL)
        let sourceVideoTrack = asset.tracks(withMediaType: .video).first!
        let sourceAudioTrack = asset.tracks(withMediaType: .audio).first

        let composition = AVMutableComposition()
        
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: .video)!
        
        try! videoTrack.insertTimeRange(sourceVideoTrack.timeRange, of: sourceVideoTrack, at: .invalid)
        videoTrack.preferredTransform = sourceVideoTrack.preferredTransform
        
        if let sourceAudioTrack,
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: .audio) {
            try! audioTrack.insertTimeRange(sourceAudioTrack.timeRange, of: sourceAudioTrack, at: .invalid)
        }

        return composition
    }
    
    private func makeVideoComposition(for composition: AVComposition) -> AVVideoComposition {
        let videoTrack = composition.tracks(withMediaType: .video)[0]

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = composition.tracks(withMediaType: .video)[0].timeRange
        instruction.layerInstructions = [layerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.customVideoCompositorClass = VideoCompositor.self
        videoComposition.renderSize = CGSize(width: 480, height: 640)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 60)
        
        return videoComposition
    }
    
    private func export() {
        let composition = makeComposition()
        let videoComposition = makeVideoComposition(for: composition)
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("video.mp4")
        try? FileManager.default.removeItem(at: url)
        let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
        exportSession.videoComposition = videoComposition
        exportSession.outputFileType = .mp4
        exportSession.outputURL = url
        
        exportSession.exportAsynchronously { [weak self] in
            guard let self else {
                return
            }
            switch exportSession.status {
            case .completed:
                DispatchQueue.main.async {
                    self.share(url: url)
                }
            default:
                print(Self.self, #function, exportSession.error)
            }
        }
    }
    
    private func share(url: URL) {
        let shareController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(shareController, animated: true)
    }
}
