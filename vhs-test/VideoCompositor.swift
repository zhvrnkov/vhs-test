//
//  VideoCompositor.swift
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

import Foundation
import AVFoundation
import CoreImage.CIFilterBuiltins
import UIKit
import MetalPerformanceShaders

final class VideoCompositor: NSObject, AVVideoCompositing {
    
    enum Error: Swift.Error {
        case noInput
        case wrongInstruction
        case noOutputPixelBuffer
        case noCommandBuffer
        case noRenderEncoder
        case unableToGenerateTextImage
    }
    
    lazy var sourcePixelBufferAttributes: [String : Any]? = requiredPixelBufferAttributesForRenderContext
    
    lazy var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,
        (kCVPixelBufferMetalCompatibilityKey as String): true
    ]
    
    private let context = try! MTLContext()
    private lazy var sourceFrameRenderer = try! ImageRenderer(context: context)
    private lazy var textFrameRenderer = try! ImageRenderer(context: context)
    
    private let dateFormatter = DateFormatter()
    private let baseDate = Date()
    private lazy var textGenerator: CIFilter & CIAttributedTextImageGenerator = {
        let filter = CIFilter.attributedTextImageGenerator()
        filter.setDefaults()
        filter.scaleFactor = 10.0
        return filter
    }()
    private lazy var attributes: [NSAttributedString.Key : Any] = {
        let font = UIFont(name: "VCR OSD Mono", size: 8.0)!
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black
        shadow.shadowBlurRadius = 5

        return [
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.clear,
            .font: font,
            .shadow: shadow,
        ]
    }()
    
    private lazy var vhsEffect = try! VHSEffect(context: context)

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        do {
            try process(request: request)
        }
        catch {
            request.finish(with: error)
        }
    }
    
    private func process(request: AVAsynchronousVideoCompositionRequest) throws {
        let (renderTargetPixelBuffer, renderTargetTexture) = try makeRenderTarget(request: request)
        let renderTargetSize = renderTargetTexture.cgSize

        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw Error.noCommandBuffer
        }

        setupRenderers(renderTargetSize: renderTargetSize)

        let (sourceTexture, sourceTransform) = try makeSourceTextureAndTransform(commandBuffer: commandBuffer, request: request)
        let (textImage, textTransform) = try makeTextTextureAndTransform(commandBuffer: commandBuffer, request: request)
        let originalSceneImage = MPSTemporaryImage(commandBuffer: commandBuffer, size: renderTargetSize)

        let encoder = try makeRenderCommandEncoder(commandBuffer: commandBuffer, for: originalSceneImage.texture)

        let sourceInput = ImageRenderer.Input(texture: sourceTexture, renderTargetSize: renderTargetSize, displayTransform: sourceTransform)
        try sourceFrameRenderer.render(encoder: encoder, input: sourceInput)
        
        let textInput = ImageRenderer.Input(texture: textImage.texture, renderTargetSize: renderTargetSize, displayTransform: textTransform)
        try textFrameRenderer.render(encoder: encoder, input: textInput)
        
        encoder.endEncoding()
        
        vhsEffect.time = request.compositionTime
        try vhsEffect.encode(
            commandBuffer: commandBuffer,
            sourceTexture: originalSceneImage.texture,
            destinationTexture: renderTargetTexture
        )
        
        textImage.readCount = 0
        originalSceneImage.readCount = 0

        commandBuffer.addCompletedHandler { _ in
            request.finish(withComposedVideoFrame: renderTargetPixelBuffer)
        }
        commandBuffer.commit()
    }
    
    private func makeRenderTarget(request: AVAsynchronousVideoCompositionRequest) throws -> (CVPixelBuffer, MTLTexture) {
        guard let renderTargetPixelBuffer = request.renderContext.newPixelBuffer() else {
            throw Error.noOutputPixelBuffer
        }
        return (renderTargetPixelBuffer, try context.textureCache.rgbaTexture(from: renderTargetPixelBuffer))
    }
    
    private func setupRenderers(renderTargetSize: CGSize) {
        sourceFrameRenderer.transform = .identity
        sourceFrameRenderer.rect = CGRect(origin: .zero, size: renderTargetSize)
        
        textFrameRenderer.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        textFrameRenderer.rect.size = CGSize(width: renderTargetSize.width, height: 82)
        textFrameRenderer.rect.center = CGPoint(
            x: textFrameRenderer.rect.height / 2.0 + 32,
            y: textFrameRenderer.rect.width / 2.0 + 48
        )
    }
    
    private func makeRenderCommandEncoder(
        commandBuffer: MTLCommandBuffer,
        for renderTargetTexture: MTLTexture
    ) throws -> MTLRenderCommandEncoder {
        let passDescriptor = MTLRenderPassDescriptor(texture: renderTargetTexture)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            throw Error.noRenderEncoder
        }
        return encoder
    }
    
    private func makeSourceTextureAndTransform(
        commandBuffer: MTLCommandBuffer,
        request: AVAsynchronousVideoCompositionRequest
    ) throws -> (MTLTexture, CGAffineTransform) {
        guard let instruction = request.videoCompositionInstruction as? AVVideoCompositionInstruction else {
            throw Error.wrongInstruction
        }
        guard let sourcePixelBuffer = request.sourceFrame(byTrackID: .video) else {
            throw Error.noInput
        }
        let sourceTexture = try context.textureCache.rgbaTexture(from: sourcePixelBuffer)
        
        let transform = instruction.layerInstructions.first {
            $0.trackID == .video
        }?.transform(at: request.compositionTime) ?? .identity
        
        return(sourceTexture, transform)
    }
    
    private func makeTextTextureAndTransform(
        commandBuffer: MTLCommandBuffer,
        request: AVAsynchronousVideoCompositionRequest
    ) throws -> (MPSTemporaryImage, CGAffineTransform) {
        let date = baseDate.addingTimeInterval(request.compositionTime.seconds)
        let firstLine: String = {
            dateFormatter.dateFormat = "aaa hh:mm:ss.S"
            return dateFormatter.string(from: date)
        }()
        let secondLine: String = {
            dateFormatter.dateFormat = "MMM.dd YYYY"
            return dateFormatter.string(from: date).uppercased()
        }()
        let string = "\(firstLine)\n\(secondLine)"
        let attributedString = NSAttributedString(string: string, attributes: attributes)
        
        textGenerator.text = attributedString
        guard let outputImage = textGenerator.outputImage else {
            throw Error.unableToGenerateTextImage
        }
        
        let textImage = MPSTemporaryImage(commandBuffer: commandBuffer, size: outputImage.extent.size)
        let textTexture = textImage.texture
        let ciContext = context.ciContext
        ciContext.render(
            outputImage,
            to: textTexture,
            commandBuffer: commandBuffer,
            bounds: outputImage.extent,
            colorSpace: outputImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        )
        
        return (textImage, CGAffineTransform(scaleX: 1.0, y: -1.0))
    }
}
