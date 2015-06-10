#husl-objc

Objective-C port of [HUSL](http://www.husl-colors.org).

##Which files are needed?

If you're using [CocoaPods](https://cocoapods.org) just add `pod 'husl-objc'` to your Podfile.

Otherwise, include this files in your project:

- husl-objc.h
- husl-objc+Tests.h
- husl-objc.c

##How to use

Include `husl-objc.h`, which defines the following functions:

~~~objective-c
// Accepts red, green and blue values between 0 and 1, returns the color in hex format, as in "#012C4A"
NSString *rgbToHex(CGFloat red, CGFloat green, CGFloat blue);

// Accepts an hex color, as in "#012C4A", and stores its red, green and blue components with values between 0 and 1.
BOOL hexToRgb(NSString *hex, CGFloat *red, CGFloat *green, CGFloat *blue);

// Hue is a value between 0 and 360, saturation and lightness between 0 and 100. Stores the RGB in values between 0 and 1.
void huslToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue);

// Red, green and blue values between 0 and 1, stores the husl components with hue between 0 and 360, saturation and lightness between 0 and 100.
void rgbToHusl(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness);

// Hue is a value between 0 and 360, saturation and lightness between 0 and 100. Stores the RGB in values between 0 and 1.
void huslpToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue);

// Red, green and blue values between 0 and 1, stores the huslp components with hue between 0 and 360, saturation and lightness between 0 and 100.
void rgbToHuslp(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness);
~~~