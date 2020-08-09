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

#include <metal_stdlib>
#include "ShaderDefinitions.h"

using namespace metal;

constexpr sampler s(coord::normalized,
                    s_address::clamp_to_edge,
                    t_address::clamp_to_edge,
                    filter::nearest);

struct VertexOut {
    float4 color;            // rgba
    float4 pos [[position]]; // x, y, z /* ignored */, w /* ignored */
    float2 uv;               // Atlas texture x, y
    int type;                // XIVertexType
};

struct DualSourceOutput
{
    float4 color     [[ color(0), index(0) ]];
    float4 alphaMask [[ color(0), index(1) ]];
};

//static float3 to_linear(float3 srgb) {
//    // 0 if srgb < 0.04045
//    float3 selection = step(0.04045, srgb);
//    float3 a = srgb / 12.92;
//    float3 b = pow((srgb + 0.055) / 1.055, 2.4);
//    // a for components where linear < 0.04045, b for others
//    return mix(a, b, selection);
//}

vertex VertexOut vertexShader(unsigned int vid [[vertex_id]],
                              const device Vertex *vertexArray [[buffer(XIVertexInputIndexVertices)]],
                              const device XiUniforms *uniforms [[buffer(XIVertexInputIndexUniform)]])
{
    // Get the data for the current vertex.
    Vertex in = vertexArray[vid];

    VertexOut out;

    out.type = in.type;

    out.pos = float4(0.0, 0.0, 0.0, 1.0);

    out.pos.xy = in.pos.xy * uniforms->screenScaleFactor + float2(-1.0 , 1.0);

    out.uv = in.uv.xy;
    // uv = uvOrigin + position * uvSize;

    // Pass the vertex color directly to the rasterizer
    // Normalize rgba values (0-255 => 0.0-1.0)
    float4 passColor = in.color * float4(1.0 / 255.0);

    // Transform sRGB to Linear (CIE XYZ)
    // STOPSHIP (jeremy): Figure out if we need to do this transform yet.
//    out.color.rgb = to_linear(passColor.rgb);
    out.color = passColor;

    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                         texture2d<float> glyphTexture [[texture(0)]])
{
    if (in.type == XIVertexTypeSolid) {
        return in.color;
    } else if (in.type == XIVertexTypeText) {
        float4 mask = glyphTexture.sample(s, in.uv.xy);
        float4 color = float4(in.color.rgb, 1.0 - mask.r * in.color.a);
        return color;
    } else {
        // Emoji
        // STOPSHIP (jeremy): Figure out emoji rendering (esp. inverse (dark background) colours)
        return in.color;
    }
}
