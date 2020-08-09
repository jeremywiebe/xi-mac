// Copyright 2019 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Cocoa

extension NSColor {
    static func fromArgb(_ argb: UInt32) -> NSColor {
        return NSColor(red: CGFloat((argb >> 16) & 0xff) * 1.0/255,
                       green: CGFloat((argb >> 8) & 0xff) * 1.0/255,
                       blue: CGFloat(argb & 0xff) * 1.0/255,
                       alpha: CGFloat((argb >> 24) & 0xff) * 1.0/255)
    }

    /// Convert color to ARGB format. Note: we should do less conversion
    /// back and forth to NSColor; this is a convenience so we don't have
    /// to change as much code.
    func toArgb() -> UInt32 {
        let ciColor = CIColor(color: self)!
        let a = UInt32(round(ciColor.alpha * 255.0))
        let r = UInt32(round(ciColor.red * 255.0))
        let g = UInt32(round(ciColor.green * 255.0))
        let b = UInt32(round(ciColor.blue * 255.0))
        return (a << 24) | (r << 16) | (g << 8) | b
    }

    func asClearColor() -> MTLClearColor {
        let srgbColor = self.usingColorSpace(NSColorSpace.sRGB)!
        return MTLClearColor(red: Double(srgbColor.redComponent),
                             green: Double(srgbColor.greenComponent),
                             blue: Double(srgbColor.blueComponent),
                             alpha: Double(srgbColor.alphaComponent))
    }
}
