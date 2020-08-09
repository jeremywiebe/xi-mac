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

import Cocoa
import Metal

// STOPSHIP (jeremy): Implement instanced rendering like GlRenderer does!
// http://metalbyexample.com/instanced-rendering/

class MetalRenderer: Renderer {
    let atlas: MetalAtlas
    let layer: MetalTextPlaneLayer
    let pipelineState: MTLRenderPipelineState

    let commandQueue: MTLCommandQueue

    var dpiScale: CGFloat = 0
    var drawable: CAMetalDrawable?
    var descriptor: MTLRenderPassDescriptor?
    var commandBuffer: MTLCommandBuffer?
    var commandEncoder: MTLRenderCommandEncoder?

    var clearColor: NSColor?

    var uniformBuffer: MTLBuffer

    /// The renderer's font cache. Useful for building text lines.
    var fontCache: FontCache {
        return atlas.fontCache
    }

    init(layer: MetalTextPlaneLayer, commandQueue: MTLCommandQueue) {
        self.layer = layer
        self.atlas = MetalAtlas(withDevice: layer.device!)
        self.commandQueue = commandQueue

        do {
            self.pipelineState = try MetalRenderer.buildRenderPipeline(forLayer: layer)
        } catch {
            fatalError("Unable to compile render pipeline state: \(error)")
        }

        self.uniformBuffer = (self.layer.device?.makeBuffer(
            length: MemoryLayout<XiUniforms>.stride,
            options: []
        ))!
        self.uniformBuffer.label = "Uniform Buffer"
    }

    // - MARK: Metal setup

    // Create our custom rendering pipeline, which loads shaders using `device`, and outputs to the format of `metalKitView`
    class func buildRenderPipeline(forLayer layer: CAMetalLayer) throws -> MTLRenderPipelineState {
        guard let device = layer.device else {
            fatalError("Cannot build render pipeline. CAMetalLayer has no associated device.")
        }

        // Create a new pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        let library = device.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat

        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one

        // Compile the configured pipeline descriptor to a pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    // - MARK: Renderer protocol

    func beginDraw(size: CGSize, scale: CGFloat) {
        self.dpiScale = scale
        guard let drawable = layer.nextDrawable() else {
            return
        }

        self.drawable = drawable
        let texture = drawable.texture

        self.descriptor = MTLRenderPassDescriptor()
        self.descriptor?.colorAttachments[0].texture = texture
        self.descriptor?.colorAttachments[0].loadAction = .clear
        self.descriptor?.colorAttachments[0].storeAction = .store
        if let color = self.clearColor {
            self.descriptor?.colorAttachments[0].clearColor = color.asClearColor()
        }

        self.commandBuffer = commandQueue.makeCommandBuffer()
        self.commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: self.descriptor!)

        self.commandEncoder?.setRenderPipelineState(self.pipelineState)

        var uniforms = XiUniforms(
            screenScaleFactor: SIMD2<Float>(Float(2.0 / self.layer.bounds.width),
                                      Float(-2.0 / self.layer.bounds.height))
        )
        self.commandEncoder?.setVertexBytes(&uniforms,
                                            length: MemoryLayout<SIMD2<Float>>.stride,
                                            index: Int(XIVertexInputIndexUniform.rawValue))

        // Provide the Atlas texture to the shaders
        self.commandEncoder?.setFragmentTexture(atlas.texture, index: 0)
    }

    func endDraw() {
        self.commandEncoder?.endEncoding()

        self.commandBuffer?.present(self.drawable!)
        self.commandBuffer?.commit()

        self.drawable = nil // Do we need @autorelease pool here?
    }

    func clear(_ color: NSColor) {
        self.clearColor = color
    }

    func drawSolidRect(x: GLfloat, y: GLfloat, width: GLfloat, height: GLfloat, argb: UInt32) {
        let solid = Int32(XIVertexTypeSolid.rawValue)
        let fgColor = argbToFloats(argb: argb)
        let vertices = [
            /* T1 */
            Vertex(color: fgColor, pos: [x, y], uv: [0, 0], type: solid),
            Vertex(color: fgColor, pos: [x + width, y], uv: [0, 0], type: solid),
            Vertex(color: fgColor, pos: [x + width, y + height], uv: [0, 0], type: solid),
            /* T2 */
            Vertex(color: fgColor, pos: [x + width, y + height], uv: [0, 0], type: solid),
            Vertex(color: fgColor, pos: [x, y + height], uv: [0, 0], type: solid),
            Vertex(color: fgColor, pos: [x, y], uv: [0, 0], type: solid)]

        let buffer = self.layer.device?.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: []
        )

        self.commandEncoder?.setVertexBuffer(buffer, offset: 0, index: Int(XIVertexInputIndexVertices.rawValue))

        // And what to draw
        self.commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    func drawGlyphInstance(glyph: GlyphInstance, x0: Float, y0: Float) {
        /* TODO: Could this move up to base Renderer */
        var cachedGlyph = atlas.getGlyph(fr: glyph.fontRef, glyph: glyph.glyph, flags: glyph.flags, scale: dpiScale)
        if cachedGlyph == nil {
            // STOPSHIP (jeremy): In a Metal world... how do we flush the Atlas
            // and redraw? Do we need to? Can we just have an Atlas that has
            // all the characters we need?
            // Probably not. At a certain font size our Atlas would only be able
            // to hold a few characters. But in those cases you wouldn't have
            // very many of them on the screen, so maybe at a certain font
            // threshold we just bypass the Atlas?
//            flushDraw()
            atlas.flushCache()
            cachedGlyph = atlas.getGlyph(fr: glyph.fontRef, glyph: glyph.glyph, flags: glyph.flags, scale: dpiScale)
            if cachedGlyph == nil {
                print("glyph \(glyph) is not renderable")
                return
            }
        }
        /**** END OF TODO ****/

        let type = Int32(XIVertexTypeText.rawValue)

        let x = x0 + glyph.x + cachedGlyph!.xoff
        let y = y0 + glyph.y + cachedGlyph!.yoff
        let width = cachedGlyph!.width
        let height = cachedGlyph!.height

        let vertices = [
            Vertex(color: glyph.fgColor,
                   pos: [x, y],
                   uv: [cachedGlyph!.uvCoords[0],
                        cachedGlyph!.uvCoords[1]],
                   type: type),
            Vertex(color: glyph.fgColor,
                   pos: [x + width, y],
                   uv: [cachedGlyph!.uvCoords[0] + cachedGlyph!.uvCoords[2],
                        cachedGlyph!.uvCoords[1]],
                   type: type),
            Vertex(color: glyph.fgColor,
                   pos: [x + width, y + height],
                   uv: [cachedGlyph!.uvCoords[0] + cachedGlyph!.uvCoords[2],
                        cachedGlyph!.uvCoords[1] + cachedGlyph!.uvCoords[3]],
                   type: type),

            Vertex(color: glyph.fgColor,
                   pos: [x + width, y + height],
                   uv: [cachedGlyph!.uvCoords[0] + cachedGlyph!.uvCoords[2],
                        cachedGlyph!.uvCoords[1] + cachedGlyph!.uvCoords[3]],
                   type: type),
            Vertex(color: glyph.fgColor,
                   pos: [x, y + height],
                   uv: [cachedGlyph!.uvCoords[0],
                        cachedGlyph!.uvCoords[1] + cachedGlyph!.uvCoords[3]],
                   type: type),
            Vertex(color: glyph.fgColor,
                   pos: [x, y],
                   uv: [cachedGlyph!.uvCoords[0],
                        cachedGlyph!.uvCoords[1]],
                   type: type),
        ]

        let buffer = self.layer.device?.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: []
        )

        self.commandEncoder?.setVertexBuffer(buffer, offset: 0, index: Int(XIVertexInputIndexVertices.rawValue))

        // And what to draw
        self.commandEncoder?.drawPrimitives(type: .triangle,
                                            vertexStart: 0,
                                            vertexCount: vertices.count)

//
//        textInstances[textInstanceIx + 0] = x0 + glyph.x + cachedGlyph!.xoff
//        textInstances[textInstanceIx + 1] = y0 + glyph.y + cachedGlyph!.yoff
//        textInstances[textInstanceIx + 2] = cachedGlyph!.width
//        textInstances[textInstanceIx + 3] = cachedGlyph!.height
//        textInstances[textInstanceIx + 4] = glyph.fgColor.0
//        textInstances[textInstanceIx + 5] = glyph.fgColor.1
//        textInstances[textInstanceIx + 6] = glyph.fgColor.2
//        textInstances[textInstanceIx + 7] = glyph.fgColor.3
//        textInstances[textInstanceIx + 8] = cachedGlyph!.uvCoords[0]
//        textInstances[textInstanceIx + 9] = cachedGlyph!.uvCoords[1]
//        textInstances[textInstanceIx + 10] = cachedGlyph!.uvCoords[2]
//        textInstances[textInstanceIx + 11] = cachedGlyph!.uvCoords[3]
//        textInstanceIx += textInstanceSize
//        if textInstanceIx == maxTextInstances * textInstanceSize {
//            flushDraw()
//        }
    }

    func drawLine(line: TextLine, x0: Float, y0: Float) {
        for glyph in line.glyphs {
            drawGlyphInstance(glyph: glyph, x0: x0, y0: y0)
        }
    }

    func drawLineBg(line: TextLine, x0: GLfloat, yRange: Range<GLfloat>) {
        for bgRange in line.bgRanges {
            drawSolidRect(x: x0 + bgRange.range.lowerBound, y: yRange.lowerBound,
                          width: bgRange.range.upperBound - bgRange.range.lowerBound,
                          height: yRange.upperBound - yRange.lowerBound,
                          argb: bgRange.argb)
        }
    }

    func drawRectForRange(line: TextLine, x0: GLfloat, yRange: Range<GLfloat>, utf16Range: CountableRange<Int>, argb: UInt32) {}

    func drawLineDecorations(line: TextLine, x0: GLfloat, y0: GLfloat) {}
}
