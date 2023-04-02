//
//  MTLContext.swift
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

import Metal
import CoreImage

public final class MTLContext {
    enum Error: Swift.Error {
        case noFunction(name: String)
        case noDeviceOrCommandQueue
    }

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let library: MTLLibrary
    public let textureCache: CVMetalTextureCache
    public private(set) lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [.cacheIntermediates: NSNumber(false),
                                               .outputPremultiplied: NSNumber(true),
                                               CIContextOption.useSoftwareRenderer: NSNumber(false),
                                               .workingColorSpace: NSNull()]
        
        return CIContext(mtlCommandQueue: commandQueue, options: options)
    }()

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw Error.noDeviceOrCommandQueue
        }
        let library = try device.makeDefaultLibrary(bundle: .main)
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        self.textureCache = try CVMetalTextureCache.textureCache(device: device)
    }
    
    func renderPipelineState(pixelFormat: MTLPixelFormat, prefix: String?) throws -> MTLRenderPipelineState {
        let prefix = prefix ?? String(describing: self)
        let descriptor = MTLRenderPipelineDescriptor(
            vertexFunction: "\(prefix)_vertexFunction",
            fragmentFunction: "\(prefix)_fragmentFunction",
            pixelFormat: pixelFormat,
            library: library
        )
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}

extension MTLContext {
    func makeComputePipelineState(functionName: String) throws -> MTLComputePipelineState {
        guard let function = library.makeFunction(name: functionName) else {
            throw Error.noFunction(name: functionName)
        }
        return try device.makeComputePipelineState(function: function)
    }
}
