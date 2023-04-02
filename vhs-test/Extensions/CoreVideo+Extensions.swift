//
//  CoreVideo+Extensions.swift
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

import Foundation
import CoreVideo

public extension CVPixelBuffer {
    var width: Int {
        CVPixelBufferGetWidth(self)
    }
    
    var height: Int {
        CVPixelBufferGetHeight(self)
    }
    
    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

public extension CVMetalTextureCache {
    
    enum Error: Swift.Error {
        case badStatus
        case nilTexture
        case initializationError(status: CVReturn)
    }
    
    static func textureCache(device: MTLDevice) throws -> CVMetalTextureCache {
        var metalTextureCache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(nil, nil, device, nil, &metalTextureCache)
        guard let metalTextureCache = metalTextureCache else {
            throw Error.initializationError(status: status)
        }
        return metalTextureCache
    }
    
    func rgbaTexture(from pixelBuffer: CVPixelBuffer) throws -> MTLTexture {
        return try texture(from: pixelBuffer, pixelFormat: MTLPixelFormat.bgra8Unorm)
    }
    
    func grayscaleTexture(from pixelBuffer: CVPixelBuffer) throws -> MTLTexture {
        return try texture(from: pixelBuffer, pixelFormat: .r8Unorm)
    }
    
    func texture(from pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat) throws -> MTLTexture {
        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            self,
            pixelBuffer,
            nil,
            pixelFormat,
            pixelBuffer.width,
            pixelBuffer.height,
            0,
            &cvTexture
        )
        guard result == kCVReturnSuccess,
              let cvTexture = cvTexture else {
            throw Error.badStatus
        }
        guard let texture = CVMetalTextureGetTexture(cvTexture) else {
            throw Error.nilTexture
        }
        return texture
    }
}
