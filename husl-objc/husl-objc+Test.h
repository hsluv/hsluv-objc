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

vector_double3 rgbToXyz(vector_double3 rgb);
vector_double3 xyzToLuv(vector_double3 xyz);
vector_double3 luvToLch(vector_double3 luv);
vector_double3 lchToHusl(vector_double3 lch);
vector_double3 lchToHuslp(vector_double3 lch);

#endif
