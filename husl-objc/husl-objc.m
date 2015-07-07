//
//  husl_objc.m
//  husl-objc
//
//  Created by Roger Tallada on 4/6/15.
//  Copyright (c) 2015 Alexei Boronine
//
// Implementation of husl translated from husl.coffee


#import <tgmath.h>
#import "husl-objc.h"
#import "husl-objc+Test.h"

#pragma mark Private funcions

/*
 # The math for most of this module was taken from:
 #
 #  * http://www.easyrgb.com
 #  * http://www.brucelindbloom.com
 #  * Wikipedia
 #
 
 
 # All numbers taken from math/bounds.wxm wxMaxima file:
 #
 #    fpprintprec: 16;
 #    CGFloat(M_XYZ_RGB);
 #    CGFloat(M_RGB_XYZ);
 #    CGFloat(refX);
 #    CGFloat(refY);
 #    CGFloat(refZ);
 #    CGFloat(refU);
 #    CGFloat(refV);
 #    CGFloat(lab_k);
 #    CGFloat(lab_e);
 #*/


// Tuple of 2 elements and helper macros to encapsulate tuples in an NSValue
typedef struct tuple2 {
    CGFloat a, b;
} Tuple2;

typedef struct matrix {
    Tuple a, b, c;
} Matrix;

// An struct to avoid creating objecs in getBounds. It will always contain 6 lines.
typedef struct lineBounds {
    Tuple2 line0, line1, line2, line3, line4, line5;
} LineBounds;

static Matrix m = {
    { 3.2409699419045214,   -1.5373831775700935, -0.49861076029300328}, // R
    {-0.96924363628087983,   1.8759675015077207,  0.041555057407175613}, // G
    { 0.055630079696993609, -0.20397695888897657, 1.0569715142428786} // B
};

static Matrix m_inv = {
    {0.41239079926595948,  0.35758433938387796, 0.18048078840183429}, // X
    {0.21263900587151036,  0.71516867876775593, 0.072192315360733715}, // Y
    {0.019330818715591851, 0.11919477979462599, 0.95053215224966058} // Z
};

Tuple matrixElement(Matrix m, NSUInteger i) {
    switch (i) {
        case 0:
            return m.a;
            break;
        case 1:
            return m.b;
            break;
        case 2:
            return m.c;
            break;
        default:
            break;
    }
    Tuple none;
    return none;
}

//Constants
CGFloat refU = 0.19783000664283681;
CGFloat refV = 0.468319994938791;

// CIE LUV constants
CGFloat kappa = 903.2962962962963;
CGFloat epsilon = 0.0088564516790356308;

// For a given lightness, return a list of 6 lines in slope-intercept
// form that represent the bounds in CIELUV, stepping over which will
// push a value out of the RGB gamut
LineBounds getBounds(CGFloat l) {
    CGFloat sub1 = pow(l + 16, 3) / 1560896;
    CGFloat sub2 = sub1 > epsilon ? sub1 : (l / kappa);
    
    LineBounds ret;
    
    for (int channel=0; channel<3; channel++) {
        Tuple mTuple = matrixElement(m, channel);
        
        CGFloat m1 = mTuple.a;
        CGFloat m2 = mTuple.b;
        CGFloat m3 = mTuple.c;
        
        for (int t=0; t <= 1; t++) {
            CGFloat top1 = (284517 * m1 - 94839 * m3) * sub2;
            CGFloat top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * l * sub2 -  769860 * t * l;
            CGFloat bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452 * t;
            
            Tuple2 tuple = {top1 / bottom, top2 / bottom};
            
            NSUInteger lineNumber = channel * 2 + t;
            switch (lineNumber) {
                case 0:
                    ret.line0 = tuple;
                    break;
                case 1:
                    ret.line1 = tuple;
                    break;
                case 2:
                    ret.line2 = tuple;
                    break;
                case 3:
                    ret.line3 = tuple;
                    break;
                case 4:
                    ret.line4 = tuple;
                    break;
                case 5:
                    ret.line5 = tuple;
                    break;
                    
                default:
                    break;
            }
        }
    }
    return ret;
}

CGFloat intersectLineLine(Tuple2 line1, Tuple2 line2) {
    return (line1.b - line2.b) / (line2.a - line1.a);
}

CGFloat distanceFromPole(CGPoint point) {
    return sqrt(pow(point.x, 2) + pow(point.y, 2));
}

CGFloat lengthOfRayUntilIntersect(CGFloat theta, Tuple2 line) {
    // theta  -- angle of ray starting at (0, 0)
    // m, b   -- slope and intercept of line
    // x1, y1 -- coordinates of intersection
    // len    -- length of ray until it intersects with line
    //
    // b + m * x1        = y1
    // len              >= 0
    // len * cos(theta)  = x1
    // len * sin(theta)  = y1
    //
    //
    // b + m * (len * cos(theta)) = len * sin(theta)
    // b = len * sin(hrad) - m * len * cos(theta)
    // b = len * (sin(hrad) - m * cos(hrad))
    // len = b / (sin(hrad) - m * cos(hrad))
    //
    CGFloat m1 = line.a;
    CGFloat b1 = line.b;
    CGFloat len = b1 / (sin(theta) - m1 * cos(theta));
    //    if (len < 0) {
    //        return 0;
    //    }
    return len;
}

Tuple2 lineBoundAtIndex(LineBounds bounds, NSUInteger i) {
    Tuple2 tuple;
    switch (i) {
        case 0:
            tuple = bounds.line0;
            break;
        case 1:
            tuple = bounds.line1;
            break;
        case 2:
            tuple = bounds.line2;
            break;
        case 3:
            tuple = bounds.line3;
            break;
        case 4:
            tuple = bounds.line4;
            break;
        case 5:
            tuple = bounds.line5;
            break;
            
        default:
            break;
    }
    return tuple;
}

// For given lightness, returns the maximum chroma. Keeping the chroma value
// below this number will ensure that for any hue, the color is within the RGB
// gamut.
CGFloat maxSafeChromaForL(CGFloat l)  {
    CGFloat minLength = CGFLOAT_MAX;
    LineBounds bounds = getBounds(l);
    for (NSUInteger i = 0; i < 6; i++) {
        Tuple2 boundTuple = lineBoundAtIndex(bounds, i);

        CGFloat m1 = boundTuple.a;
        CGFloat b1 = boundTuple.b;

        // x where line intersects with perpendicular running though (0, 0)
        Tuple2 line2 = {-1 / m1, 0};
        CGFloat x = intersectLineLine(boundTuple, line2);
        CGFloat distance = distanceFromPole(CGPointMake(x, b1 + x * m1));
        if (distance >= 0) {
            if (distance < minLength) {
                minLength = distance;
            }
        }
    }
    return minLength;
}

// For a given lightness and hue, return the maximum chroma that fits in
// the RGB gamut.
CGFloat maxChromaForLH(CGFloat l, CGFloat h) {
    CGFloat hrad = h / 360 * M_PI * 2;
    CGFloat minLength = CGFLOAT_MAX;
    LineBounds bounds = getBounds(l);
    for (NSUInteger i = 0; i < 6; i++) {
        Tuple2 lineTuple = lineBoundAtIndex(bounds, i);
        CGFloat l = lengthOfRayUntilIntersect(hrad, lineTuple);
        if (l >= 0)  {
            if (l < minLength) {
                minLength = l;
            }
        }
    }
    return minLength;
}



CGFloat tupleDotProduct(Tuple t1, Tuple t2) {
    CGFloat ret = 0.0;
    for (NSUInteger i = 0; i < 3; i++) {
        switch (i) {
            case 0:
                ret += t1.a * t2.a;
                break;
            case 1:
                ret += t1.b * t2.b;
                break;
            case 2:
                ret += t1.c * t2.c;
                break;
            default:
                break;
        }
    }
    return ret;
}

// Used for rgb conversions
CGFloat fromLinear(CGFloat c) {
    if (c <= 0.0031308) {
        return 12.92 * c;
    }
    else {
        return 1.055 * pow(c, 1 / 2.4) - 0.055;
    }
}

CGFloat toLinear(CGFloat c) {
    CGFloat a = 0.055;
    if (c > 0.04045) {
        return pow((c + a) / (1 + a), 2.4);
    }
    else {
        return c / 12.92;
    }
}

#pragma mark Conversion functions

Tuple xyzToRgb(Tuple xyz) {
    CGFloat r = fromLinear(tupleDotProduct(m.a, xyz));
    CGFloat g = fromLinear(tupleDotProduct(m.b, xyz));
    CGFloat b = fromLinear(tupleDotProduct(m.c, xyz));
    
    Tuple rgb = {r, g, b};
    return rgb;
}

Tuple rgbToXyz(Tuple rgb) {
    Tuple rgbl = {toLinear(rgb.a), toLinear(rgb.b), toLinear(rgb.c)};

    CGFloat x = tupleDotProduct(m_inv.a, rgbl);
    CGFloat y = tupleDotProduct(m_inv.b, rgbl);
    CGFloat z = tupleDotProduct(m_inv.c, rgbl);
    
    Tuple xyz = {x, y, z};
    return xyz;
}

// http://en.wikipedia.org/wiki/CIELUV
// In these formulas, Yn refers to the reference white point. We are using
// illuminant D65, so Yn (see refY in Maxima file) equals 1. The formula is
// simplified accordingly.
CGFloat yToL (CGFloat y) {
    CGFloat l;
    if (y <= epsilon) {
        l = y * kappa;
    }
    else {
        l = 116.0 * pow(y, 1.0/3.0) - 16.0;
    }
    return l;
}

CGFloat lToY (CGFloat l) {
    if (l <= 8) {
        return l / kappa;
    }
    else {
        return powl((l + 16) / 116, 3);
    }
}

Tuple xyzToLuv(Tuple xyz) {
    CGFloat varU = (4 * xyz.a) / (xyz.a + (15 * xyz.b) + (3 * xyz.c));
    CGFloat varV = (9 * xyz.b) / (xyz.a + (15 * xyz.b) + (3 * xyz.c));
    CGFloat l = yToL(xyz.b);
    // Black will create a divide-by-zero error
    if (l==0) {
        Tuple luv = {0, 0, 0};
        return luv;
    }
    CGFloat u = 13 * l * (varU - refU);
    CGFloat v = 13 * l * (varV - refV);
    Tuple luv = {l, u, v};
    return luv;
}

Tuple luvToXyz(Tuple luv) {
    // Black will create a divide-by-zero error
    if (luv.a == 0) {
        Tuple xyz = {0, 0, 0};
        return xyz;
    }
    CGFloat varU = luv.b / (13 * luv.a) + refU;
    CGFloat varV = luv.c / (13 * luv.a) + refV;
    CGFloat y = lToY(luv.a);
    CGFloat x = 0 - (9 * y * varU) / ((varU - 4) * varV - varU * varV);
    CGFloat z = (9 * y - (15 * varV * y) - (varV * x)) / (3 * varV);
    Tuple xyz = {x, y, z};
    return xyz;
}

Tuple luvToLch(Tuple luv) {
    CGFloat l = luv.a, u = luv.b, v = luv.c;
    CGFloat h, c = sqrt(pow(u, 2) + pow(v, 2));
    
    // Greys: disambiguate hue
    if (c < 0.00000001) {
        h = 0;
    }
    else {
        CGFloat hrad = atan2(v, u);
        h = hrad * 360 / 2 / M_PI;
        if (h < 0) {
            h = 360 + h;
        }
    }
    
    Tuple lch = {l, c, h};
    return lch;
}

Tuple lchToLuv(Tuple lch) {
    CGFloat hRad = lch.c / 360 * 2 * M_PI;
    CGFloat u = cos(hRad) * lch.b;
    CGFloat v = sin(hRad) * lch.b;
    Tuple luv = {lch.a, u, v};
    return luv;
}

CGFloat checkBorders(CGFloat channel) {
    if (channel < 0) {
        return 0;
    }
    if (channel > 1) {
        return 1;
    }
    return channel;
}

BOOL hexToInt(NSString *hex, unsigned int *result) {
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    return [scanner scanHexInt:result];
}

#pragma mark husl
Tuple huslToLch(Tuple husl) {
    CGFloat h = husl.a, s = husl.b, l = husl.c, c;

    // White and black: disambiguate chroma
    if (l > 99.9999999 || l < 0.00000001) {
        c = 0;
    }
    else {
        CGFloat max = maxChromaForLH(l, h);
        c = max / 100 * s;
    }
    // Greys: disambiguate hue
    if (s < 0.00000001) {
        h = 0;
    }
    Tuple lch = {l, c, h};
    return lch;
}

Tuple lchToHusl(Tuple lch) {
    CGFloat l = lch.a, c = lch.b, h = lch.c, s;

    // White and black: disambiguate saturation
    if (l > 99.9999999 || l < 0.00000001) {
        s = 0;
    }
    else {
        CGFloat max = maxChromaForLH(l, h);
        s = c / max * 100;
    }
    // Greys: disambiguate hue
    if (c < 0.00000001) {
        h = 0;
    }
    Tuple husl = {h, s, l};
    return husl;
}

#pragma mark huslP
Tuple huslpToLch(Tuple huslp) {
    CGFloat h = huslp.a, s = huslp.b, l = huslp.c, c;

    // White and black: disambiguate chroma
    if (l > 99.9999999 || l < 0.00000001) {
        c = 0;
    }
    else {
        CGFloat max = maxSafeChromaForL(l);
        c = max / 100 * s;
    }
    
    // Greys: disambiguate hue
    if (s < 0.00000001) {
        h = 0;
    }
    Tuple lch = {l, c, h};
    return lch;
}

Tuple lchToHuslp(Tuple lch) {
    CGFloat l = lch.a, c = lch.b, h = lch.c, s;

    // White and black: disambiguate saturation
    if (l > 99.9999999 || l < 0.00000001) {
        s = 0;
    }
    else {
        CGFloat max = maxSafeChromaForL(l);
        s = c / max * 100;
    }
    // Greys: disambiguate hue
    if (c < 0.00000001) {
        h = 0;
    }
    
    Tuple huslp = {h, s, l};
    return huslp;
}

CGFloat roundTo6decimals(CGFloat channel) {
    CGFloat ch = round(channel * 1e6) / 1e6;
    if (ch < 0 || ch > 1) {
        @throw [NSString stringWithFormat:@"Illegal rgb value: %@", @(ch)];
    }
    return ch;
}

#pragma mark Public functions

NSString *rgbToHex(CGFloat red, CGFloat green, CGFloat blue) {
    NSString *hex = @"#";
    
    CGFloat r = roundTo6decimals(red);
    CGFloat g = roundTo6decimals(green);
    CGFloat b = roundTo6decimals(blue);
    
    NSString *R = [NSString stringWithFormat:@"%02X", (int)(r * 255)];
    NSString *G = [NSString stringWithFormat:@"%02X", (int)(g * 255)];
    NSString *B = [NSString stringWithFormat:@"%02X", (int)(b * 255)];
    
    return [[[hex stringByAppendingString:R] stringByAppendingString:G] stringByAppendingString:B];
}

BOOL hexToRgb(NSString *hex, CGFloat *red, CGFloat *green, CGFloat *blue) {
    if ([hex length] >= 7) {
        if ([hex characterAtIndex:0] == '#') {
            hex = [hex substringFromIndex:1];
        }
        unsigned int r, g, b;
        
        NSString *redS = [hex substringToIndex:2];
        if (!hexToInt(redS, &r)) {
            return NO;
        }
        
        NSRange gRange = {2, 2};
        NSString *greenS = [hex substringWithRange:gRange];
        if (!hexToInt(greenS, &g)) {
            return NO;
        }
        
        NSRange bRange = {4, 2};
        NSString *blueS = [hex substringWithRange:bRange];
        if (!hexToInt(blueS, &b)) {
            return NO;
        }
        
        *red = (CGFloat)r / 255;
        *green = (CGFloat)g / 255;
        *blue = (CGFloat)b / 255;
        
        return YES;
    }
    return NO;
}

void huslToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue) {
    Tuple husl = {hue, saturation, lightness};
    
    Tuple rgb = xyzToRgb(luvToXyz(lchToLuv(huslToLch(husl))));
    
    *red = rgb.a;
    *green = rgb.b;
    *blue = rgb.c;
}

void rgbToHusl(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness) {
    Tuple rgb = {red, green, blue};
    
    Tuple husl = lchToHusl(luvToLch(xyzToLuv(rgbToXyz(rgb))));
    
    *hue = husl.a;
    *saturation = husl.b;
    *lightness = husl.c;
}

void huslpToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue) {
    Tuple huslp = {hue, saturation, lightness};
    
    Tuple rgb = xyzToRgb(luvToXyz(lchToLuv(huslpToLch(huslp))));
    
    *red = rgb.a;
    *green = rgb.b;
    *blue = rgb.c;
}

void rgbToHuslp(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness) {
    Tuple rgb = {red, green, blue};
    
    Tuple huslp = lchToHuslp(luvToLch(xyzToLuv(rgbToXyz(rgb))));
    
    *hue = huslp.a;
    *saturation = huslp.b;
    *lightness = huslp.c;
}
