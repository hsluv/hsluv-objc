//
//  husl_objc.h
//  husl-objc
//
//  Created by Roger on 4/6/15.
//  Copyright (c) 2015 Alexei Boronine, Roger Tallada. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#ifndef husl_objc_h
#define husl_objc_h

// Accepts red, green and blue values between 0 and 1, returns the color in hex format, as in "#012C4A"
NSString *rgbToHex(CGFloat red, CGFloat green, CGFloat blue);

// Accepts an hex color, as in "#012C4A", and stores its red, green and blue components with values between 0 and 1.
BOOL hexToRgb(NSString *hex, CGFloat *red, CGFloat *green, CGFloat *blue);


void huslToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue);
void rgbToHusl(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness);
void huslpToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue);
void rgbToHuslp(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness);

#endif