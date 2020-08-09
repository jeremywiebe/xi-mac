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
import Metal

class MetalAtlas: Atlas {
    var texture: MTLTexture!

    init(withDevice device: MTLDevice) {
        super.init()

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: false)

        self.texture = device.makeTexture(descriptor: descriptor)
    }

    override func writeGlyphToTexture(origin: AtlasPoint, size: AtlasSize, data: [uint8]) {
        var pixels = data
        self.texture.replace(region: MTLRegionMake2D(origin.x, origin.y, size.width, size.height),
                             mipmapLevel: 0,
                             withBytes: &pixels,
                             bytesPerRow: size.width * 4)
    }
}
