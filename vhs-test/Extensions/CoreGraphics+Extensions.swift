//
//  CoreGraphics+Extensions.swift
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

import Foundation
import simd

extension CGAffineTransform {
    var translationRemoved: CGAffineTransform {
        var copy = self
        copy.tx = 0
        copy.ty = 0
        return copy
    }
    
    var scaleRemoved: CGAffineTransform {
        var copy = self
        copy.a.normalize()
        copy.b.normalize()
        copy.c.normalize()
        copy.d.normalize()
        return copy
    }
    
    var ix: vector_float3 {
        vector_float3(Float(a), Float(b), 0)
    }
    
    var iy: vector_float3 {
        vector_float3(Float(c), Float(d), 0)
    }
    
    var iz: vector_float3 {
        vector_float3(Float(tx), Float(ty), 1)
    }
    
    var matrix: matrix_float3x3 {
        matrix_float3x3(ix, iy, iz)
    }
}

extension FloatingPoint {
    var normalized: Self {
        guard isZero == false else {
            return 0
        }
        return self / magnitude
    }
    
    mutating func normalize() {
        if isZero {
            self = 0
        }
        else {
            self /= magnitude
        }
    }
}

extension CGSize {
    var abs: CGSize {
        return CGSize(width: width.magnitude, height: height.magnitude)
    }
}

extension CGRect {
    var center: CGPoint {
        get {
            return CGPoint(x: midX, y: midY)
        }
        set {
            origin.x = newValue.x - size.width / 2.0
            origin.y = newValue.y - size.height / 2.0
        }
    }
}
