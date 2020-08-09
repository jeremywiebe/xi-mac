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

#ifndef ShaderDefinitions_h
#define ShaderDefinitions_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs
// match Metal API buffer set calls.
typedef enum XIVertexInputIndex
{
    XIVertexInputIndexVertices = 0,
    XIVertexInputIndexUniform  = 1
} XIVertexInputIndex;

typedef enum XiVertexType {
    XIVertexTypeSolid = 0,
    XIVertexTypeText = 1,
    XIVertexTypeEmoji = 2
} XIVertexType;

struct Vertex {
    vector_float4 color;
    vector_float2 pos;
    vector_float2 uv;
    int type;            // XiVertexType
};

typedef struct
{
    vector_float2 screenScaleFactor;
} XiUniforms;

#endif /* ShaderDefinitions_h */
