//
//  Metal+Extensions.swift
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

import Metal
import MetalPerformanceShaders

extension MTLRenderPipelineDescriptor {
    convenience init(
        vertexFunction: String,
        fragmentFunction: String,
        pixelFormat: MTLPixelFormat,
        library: MTLLibrary
    ) {
        self.init()
        self.colorAttachments[0].pixelFormat = pixelFormat
        self.colorAttachments[0].isBlendingEnabled = true
        self.colorAttachments[0].rgbBlendOperation = .add
        self.colorAttachments[0].alphaBlendOperation = .add
        self.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        self.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        self.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        self.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        self.vertexFunction = library.makeFunction(name: vertexFunction)!
        self.fragmentFunction = library.makeFunction(name: fragmentFunction)!
    }
}

extension MTLTexture {
    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
    
    var size: MTLSize {
        MTLSize(width: width, height: height, depth: depth)
    }
    
    var descriptor: MTLTextureDescriptor {
        let output = MTLTextureDescriptor()
        
        output.width = width
        output.height = height
        output.depth = depth
        output.arrayLength = arrayLength
        output.storageMode = storageMode
        output.cpuCacheMode = cpuCacheMode
        output.usage = usage
        output.textureType = textureType
        output.sampleCount = sampleCount
        output.mipmapLevelCount = mipmapLevelCount
        output.pixelFormat = pixelFormat
        output.allowGPUOptimizedContents = allowGPUOptimizedContents

        return output
    }
    
    var temporaryTextureDescriptor: MTLTextureDescriptor {
        let descriptor = self.descriptor
        descriptor.storageMode = .private
        return descriptor
    }
}

extension MTLRenderCommandEncoder {
    func set<T>(vertexValue: inout T, index: Int) {
        setVertexBytes(&vertexValue, length: MemoryLayout<T>.stride, index: index)
    }
    
    func set<T>(fragmentValue: inout T, index: Int) {
        setFragmentBytes(&fragmentValue, length: MemoryLayout<T>.stride, index: index)
    }
}

extension MTLRenderPassDescriptor {
    convenience init(texture: MTLTexture) {
        self.init()

        let descriptor = MTLRenderPassColorAttachmentDescriptor()
        descriptor.texture = texture
        descriptor.loadAction = .clear
        descriptor.storeAction = .store
        descriptor.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        colorAttachments[0] = descriptor
    }
}

extension MTLTextureDescriptor {
    static func texture2DDescriptor(
        pixelFormat: MTLPixelFormat,
        size: CGSize,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]
    ) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = usage
        return descriptor
    }
}

extension MPSTemporaryImage {
    convenience init(
        commandBuffer: MTLCommandBuffer,
        pixelFormat: MTLPixelFormat = .bgra8Unorm,
        size: CGSize
    ) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, size: size)
        descriptor.storageMode = .private
        self.init(commandBuffer: commandBuffer, textureDescriptor: descriptor)
    }
}

extension MTLComputeCommandEncoder {
    func set<T>(value: inout T, index: Int) {
        setBytes(&value, length: MemoryLayout<T>.stride, index: index)
    }
    
    func dispatch2d(state: MTLComputePipelineState, size: MTLSize) {
        if device.supports(feature: .nonUniformThreadgroups) {
            dispatch2d(state: state, exactly: size)
        }
        else {
            dispatch2d(state: state, covering: size)
        }
    }
    
    func dispatch2d(state: MTLComputePipelineState,
                    covering size: MTLSize,
                    threadgroupSize: MTLSize? = nil) {
        let tgSize = threadgroupSize ?? state.max2dThreadgroupSize
        
        let count = MTLSize(width: (size.width + tgSize.width - 1) / tgSize.width,
                            height: (size.height + tgSize.height - 1) / tgSize.height,
                            depth: 1)
        
        self.setComputePipelineState(state)
        self.dispatchThreadgroups(count, threadsPerThreadgroup: tgSize)
    }
    
    func dispatch2d(state: MTLComputePipelineState,
                    exactly size: MTLSize,
                    threadgroupSize: MTLSize? = nil) {
        let tgSize = threadgroupSize ?? state.max2dThreadgroupSize
        
        self.setComputePipelineState(state)
        self.dispatchThreads(size, threadsPerThreadgroup: tgSize)
    }
    
    func set(textures: [MTLTexture]) {
        setTextures(textures, range: textures.indices)
    }
}

public enum Feature {
    case nonUniformThreadgroups
    case readWriteTextures(MTLPixelFormat)
}

public extension MTLDevice {
    func supports(feature: Feature) -> Bool {
        switch feature {
        case .nonUniformThreadgroups:
            #if targetEnvironment(macCatalyst)
            return self.supportsFamily(.common3)
            #elseif os(iOS)
            return self.supportsFeatureSet(.iOS_GPUFamily4_v1)
            #elseif os(macOS)
            return self.supportsFeatureSet(.macOS_GPUFamily1_v3)
            #endif
            
        case let .readWriteTextures(pixelFormat):
            let tierOneSupportedPixelFormats: Set<MTLPixelFormat> = [
                .r32Float, .r32Uint, .r32Sint
            ]
            let tierTwoSupportedPixelFormats: Set<MTLPixelFormat> = tierOneSupportedPixelFormats.union([
                .rgba32Float, .rgba32Uint, .rgba32Sint, .rgba16Float,
                .rgba16Uint, .rgba16Sint, .rgba8Unorm, .rgba8Uint,
                .rgba8Sint, .r16Float, .r16Uint, .r16Sint,
                .r8Unorm, .r8Uint, .r8Sint
            ])
            
            switch self.readWriteTextureSupport {
            case .tier1: return tierOneSupportedPixelFormats.contains(pixelFormat)
            case .tier2: return tierTwoSupportedPixelFormats.contains(pixelFormat)
            case .tierNone: return false
            @unknown default: return false
            }
        }
    }
}

public extension MTLComputePipelineState {
    var max2dThreadgroupSize: MTLSize {
        let width = self.threadExecutionWidth
        let height = self.maxTotalThreadsPerThreadgroup / width
    
        return MTLSize(width: width, height: height, depth: 1)
    }
}
