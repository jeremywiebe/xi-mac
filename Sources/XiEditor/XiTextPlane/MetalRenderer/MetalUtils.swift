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

func argbToFloat4(argb: UInt32) -> vector_float4 {
    return [
        Float((argb >> 16) & 0xff),
        Float((argb >> 8) & 0xff),
        Float(argb & 0xff),
        Float(argb >> 24)
    ]
}
