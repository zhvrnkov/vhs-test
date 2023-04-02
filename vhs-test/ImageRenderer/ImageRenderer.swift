//
//  ImageRenderer.swift
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

import Foundation
import Metal
import simd

final class ImageRenderer {
    struct Input {
        let texture: MTLTexture
        let renderTargetSize: CGSize
        let displayTransform: CGAffineTransform
    }

    var rect: CGRect = .zero
    var transform: CGAffineTransform = .identity

    private let renderPipelineState: MTLRenderPipelineState
    private let context: MTLContext

    init(context: MTLContext, pixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        renderPipelineState = try context.renderPipelineState(pixelFormat: pixelFormat, prefix: "ImageRenderer")
        self.context = context
    }
    
    func render(encoder: MTLRenderCommandEncoder, input: Input) throws {
        let displayTransform = input.displayTransform
        var uvTransform = displayTransform.translationRemoved.matrix
        
        var (viewTransform, uvTransform2) = makeTransforms(
            rect: rect,
            renderTargetSize: input.renderTargetSize,
            imageSize: input.texture.cgSize.applying(displayTransform).abs,
            transform: transform
        )
        
        uvTransform = uvTransform * uvTransform2
        
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.set(vertexValue: &viewTransform, index: 0)
        encoder.set(vertexValue: &uvTransform, index: 1)
        
        encoder.setFragmentTexture(input.texture, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    private func makeTransforms(
        rect: CGRect,
        renderTargetSize: CGSize,
        imageSize: CGSize,
        transform: CGAffineTransform
    ) -> (viewTransform: matrix_float3x3, uvTransform: matrix_float3x3) {
        let bounds2rect: matrix_float3x3 = {
            let sx = Float(rect.width / renderTargetSize.width)
            let sy = Float(rect.height / renderTargetSize.height)
            let ix = vector_float3(sx, 0, 0)
            let iy = vector_float3(0, sy, 0)
            
            let tx = Float(rect.midX / renderTargetSize.width) * 2.0 - 1.0
            let ty = Float(rect.midY / renderTargetSize.height) * 2.0 - 1.0
            let iz = vector_float3(tx, -ty, 1)
            return matrix_float3x3(ix, iy, iz)
        }()
        
        let rect2image: matrix_float3x3 = {
            let imageAspectRatio = Float(imageSize.height / imageSize.width)
            let rectAspectRatio = Float(rect.height / rect.width)

            let sy = rectAspectRatio / imageAspectRatio
            let sx = Float(1.0) // imageAspectRatio / rectAspectRatio

            let ix = vector_float3(sx, 0, 0)
            let iy = vector_float3(0, sy, 0)
            let iz = vector_float3(0, 0, 1)
            
            return matrix_float3x3(ix, iy, iz)
        }()

        let equalAspectRatioSpace: matrix_float3x3 = {
            let ix = vector_float3(max(Float(renderTargetSize.width / renderTargetSize.height), 1), 0, 0)
            let iy = vector_float3(0, max(Float(renderTargetSize.height / renderTargetSize.width), 1), 0)
            let iz = vector_float3(0, 0, 1)
            return matrix_float3x3(ix, iy, iz)
        }()
        
        var translation = bounds2rect
        translation[0] = vector_float3(1, 0, 0)
        translation[1] = vector_float3(0, 1, 0)

        return (
            translation * equalAspectRatioSpace.inverse * transform.matrix * equalAspectRatioSpace * translation.inverse * bounds2rect,
            rect2image
        )
    }
}
