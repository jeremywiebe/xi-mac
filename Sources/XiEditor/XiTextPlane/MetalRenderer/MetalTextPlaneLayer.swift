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
import MetalKit
import simd

class MetalTextPlaneLayer: CAMetalLayer, TextPlaneLayer {
    weak var textDelegate: TextPlaneDelegate?
    let fps = Fps()
    var last: Double = 0
    var count = 0

    let commandQueue: MTLCommandQueue

    lazy var renderer: MetalRenderer = {
        return MetalRenderer(layer: self, commandQueue: self.commandQueue)
    }()

    required override init() {
        let device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device!.makeCommandQueue()!

        super.init()

        self.device = device
        self.pixelFormat = .bgra8Unorm
        self.isOpaque = true
        self.framebufferOnly = true
    }

    override var delegate: CALayerDelegate? {
        get { return super.delegate }
        set(newValue) { super.delegate = newValue }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported!")
    }

    var previousFrame : FpsTimer?

    override func display() {
        // We have to capture the FPS rate of successive draw calls.  This isn't
        // great because we will have an artificially low FPS if nothing is
        // happening and when things are happening it will by capped to VSync
        // since this only gets called when something needs to be redrawn (no
        // way to measure how much we exceed the refresh rate by).  This is
        // needed because the OpenGL rendering is deferred & when it actually
        // gets committed is out of our control (timing this method alone will
        // yield millions of FPS).
        previousFrame = nil
        previousFrame = fps.startRender()
        renderer.beginDraw(size: frame.size, scale: contentsScale)
        textDelegate?.render(renderer, dirtyRect: frame)
        renderer.endDraw()
    }
}
