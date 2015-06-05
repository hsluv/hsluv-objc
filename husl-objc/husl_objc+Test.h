//
//  husl_objc+Test.h
//  husl-objc
//
//  Created by Roger on 5/6/15.
//  Copyright (c) 2015 Roger Tallada. All rights reserved.
//

#ifndef husl_objc_husl_objc_Test_h
#define husl_objc_husl_objc_Test_h

// Exposed for testing purposes only:
typedef struct tuple {
    CGFloat a, b, c;
} Tuple;

Tuple rgbToXyz(Tuple rgb);
Tuple xyzToLuv(Tuple xyz);
Tuple luvToLch(Tuple luv);
Tuple lchToHusl(Tuple lch);
Tuple lchToHuslp(Tuple lch);

#endif
