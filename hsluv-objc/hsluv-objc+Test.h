//
//  hsluv_objc+Test.h
//  hsluv-objc
//
//  Created by Roger Tallada on 4/6/15.
//  Copyright (c) 2015 Alexei Boronine
//

#ifndef hsluv_objc_hsluv_objc_Test_h
#define hsluv_objc_hsluv_objc_Test_h

// Exposed for testing purposes only:
typedef struct tuple {
    CGFloat a, b, c;
} Tuple;

Tuple rgbToXyz(Tuple rgb);
Tuple xyzToLuv(Tuple xyz);
Tuple luvToLch(Tuple luv);
Tuple lchToHsluv(Tuple lch);
Tuple lchToHpluv(Tuple lch);

#endif
