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
    private var parameters: VHSParameters = DefaultVHSParameters() {
        didSet {
            blurKernel = makeBlurKernel()
        }
    }
    private lazy var blurKernel = makeBlurKernel()
    
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
        encoder.set(value: &parameters, index: 1)
        encoder.set(textures: [sourceTexture, vhsDestinationImage.texture])
        encoder.dispatch2d(state: pipelineState, size: destinationTexture.size)

        encoder.endEncoding()

        blurKernel.encode(
            commandBuffer: commandBuffer,
            sourceTexture: vhsDestinationImage.texture,
            destinationTexture: destinationTexture
        )
    }
    
    private func makeBlurKernel() -> MPSUnaryImageKernel {
        let blur = MPSImageGaussianBlur(device: context.device, sigma: parameters.blurSigma)
        blur.edgeMode = .clamp
        return blur
    }
}
