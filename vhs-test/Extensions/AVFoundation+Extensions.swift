//
//  AVFoundation+Extensions.swift
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

import AVFoundation

extension AVVideoCompositionLayerInstruction {
    func transform(at time: CMTime) -> CGAffineTransform {
        var start = CGAffineTransform.identity
        var end = CGAffineTransform.identity
        var timeRange = CMTimeRange()
        getTransformRamp(for: time, start: &start, end: &end, timeRange: &timeRange)
        return start
    }
}

extension CMPersistentTrackID {
    static let video: CMPersistentTrackID = 1
    static let audio: CMPersistentTrackID = 2
}
