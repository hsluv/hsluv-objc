//
//  husl_objc.h
//  husl-objc
//
//  Created by Roger on 4/6/15.
//  Copyright (c) 2015 Roger Tallada. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#ifndef husl_objc_h
#define husl_objc_h

// Exposed for testing purposes only:
typedef struct tuple {
    CGFloat a, b, c;
} Tuple;


// Public functions
NSString *rgbToHex(CGFloat red, CGFloat green, CGFloat blue);
BOOL hexToRgb(NSString *hex, CGFloat *red, CGFloat *green, CGFloat *blue);
void huslToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue);
void rgbToHusl(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness);
void huslpToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue);
void rgbToHuslp(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness);

// Exposed for testing purposes only:
Tuple rgbToXyz(Tuple rgb);
Tuple xyzToLuv(Tuple xyz);
Tuple luvToLch(Tuple luv);
Tuple lchToHusl(Tuple lch);
Tuple lchToHuslp(Tuple lch);

#endif