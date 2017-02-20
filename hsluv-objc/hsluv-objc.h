//
//  hsluv_objc.h
//  hsluv-objc
//
//  Created by Roger Tallada on 4/6/15.
//  Copyright (c) 2015 Alexei Boronine
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#ifndef hsluv_objc_h
#define hsluv_objc_h

// Accepts red, green and blue values between 0 and 1, returns the color in hex format, as in "#012C4A"
NSString *rgbToHex(CGFloat red, CGFloat green, CGFloat blue);

// Accepts an hex color, as in "#012C4A", and stores its red, green and blue components with values between 0 and 1.
BOOL hexToRgb(NSString *hex, CGFloat *red, CGFloat *green, CGFloat *blue);

// Hue is a value between 0 and 360, saturation and lightness between 0 and 100. Stores the RGB in values between 0 and 1.
void hsluvToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue);

// Red, green and blue values between 0 and 1, stores the hsluv components with hue between 0 and 360, saturation and lightness between 0 and 100.
void rgbToHsluv(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness);

// Hue is a value between 0 and 360, saturation and lightness between 0 and 100. Stores the RGB in values between 0 and 1.
void hpluvToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue);

// Red, green and blue values between 0 and 1, stores the hpluv components with hue between 0 and 360, saturation and lightness between 0 and 100.
void rgbToHpluv(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness);

#endif