//
//  VHSEffect.swift
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

import Foundation
import Metal
import MetalPerformanceShaders
import CoreMedia

final class VHSEffect {
    
    enum Error: Swift.Error {
        case noComputeEncoder
    }
    
    var time: CMTime = .zero

    private let context: MTLContext
    
    private let pipelineState: MTLComputePipelineState
    
    init(context: MTLContext) throws {
        self.context = context
        self.pipelineState = try context.makeComputePipelineState(functionName: "vhs")
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture
    ) throws {
        let vhsDestinationImage = MPSTemporaryImage(commandBuffer: commandBuffer, textureDescriptor: destinationTexture.temporaryTextureDescriptor)
        defer {
            vhsDestinationImage.readCount = 0
        }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.noComputeEncoder
        }
        
        var seconds = Float(time.seconds)
        encoder.set(value: &seconds, index: 0)
        encoder.set(textures: [sourceTexture, vhsDestinationImage.texture])
        encoder.dispatch2d(state: pipelineState, size: destinationTexture.size)

        encoder.endEncoding()

        let blur = MPSImageGaussianBlur(device: context.device, sigma: 1.25)
        blur.encode(commandBuffer: commandBuffer, sourceTexture: vhsDestinationImage.texture, destinationTexture: destinationTexture)
    }
}
