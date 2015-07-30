//
//  husl_objc+Test.h
//  husl-objc
//
//  Created by Roger Tallada on 4/6/15.
//  Copyright (c) 2015 Alexei Boronine
//

#import <simd/simd.h>

#ifndef husl_objc_husl_objc_Test_h
#define husl_objc_husl_objc_Test_h

vector_float3 rgbToXyz(vector_float3 rgb);
vector_float3 xyzToLuv(vector_float3 xyz);
vector_float3 luvToLch(vector_float3 luv);
vector_float3 lchToHusl(vector_float3 lch);
vector_float3 lchToHuslp(vector_float3 lch);

#endif
