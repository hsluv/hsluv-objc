[![Cocoapod compatible](https://img.shields.io/cocoapods/v/hsluv-objc.svg)](https://cocoapods.org/pods/hsluv-objc)
[![CI](https://github.com/hsluv/hsluv-objc/actions/workflows/ci.yml/badge.svg)](https://github.com/hsluv/hsluv-objc/actions/workflows/ci.yml)

#hsluv-objc

Objective-C port of [HSLuv](http://www.hsluv.org).

##Which files are needed?

If you're using [CocoaPods](https://cocoapods.org) just add `pod 'hsluv-objc'` to your Podfile.

Otherwise, include this files in your project:

- hsluv-objc.h
- hsluv-objc+Tests.h
- hsluv-objc.c

##How to use

Import `hsluv-objc.h`, which defines the following functions:

~~~objective-c
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
~~~
