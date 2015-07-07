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

#define getTupleFromNSValue(value,tuple) [value getValue:&tuple]
#define nsvalueFromTuple(tuple,objCType) [NSValue value:&tuple withObjCType:objCType]

static NSArray *m; //lazy initialization
static NSArray *m_inv;

//Constants
// Hard-coded D65 standard illuminant
CGFloat refX = 0.95045592705167;
CGFloat refY = 1.0;
CGFloat refZ = 1.089057750759878;

CGFloat refU = 0.19783000664283;
CGFloat refV = 0.46831999493879;

// CIE LUV constants
CGFloat kappa = 903.2962962;
CGFloat epsilon = 0.0088564516;

void setM() {
    if (!m) {
        Tuple R = {3.240969941904521, -1.537383177570093, -0.498610760293};
        Tuple G = {-0.96924363628087, 1.87596750150772, 0.041555057407175};
        Tuple B = {0.055630079696993, -0.20397695888897, 1.056971514242878};
        m = @[nsvalueFromTuple(R, @encode(Tuple)),
              nsvalueFromTuple(G, @encode(Tuple)),
              nsvalueFromTuple(B, @encode(Tuple))];
    }
}

void setM_inv() {
    if (!m_inv) {
        Tuple X = {0.41239079926595, 0.35758433938387, 0.18048078840183};
        Tuple Y = {0.21263900587151, 0.71516867876775, 0.072192315360733};
        Tuple Z = {0.019330818715591, 0.11919477979462, 0.95053215224966};
        m_inv = @[nsvalueFromTuple(X, @encode(Tuple)),
                  nsvalueFromTuple(Y, @encode(Tuple)),
                  nsvalueFromTuple(Z, @encode(Tuple))];
    }
}

// For a given lightness, return a list of 6 lines in slope-intercept
// form that represent the bounds in CIELUV, stepping over which will
// push a value out of the RGB gamut
NSArray * getBounds(CGFloat l) {
    CGFloat sub1 = pow(l + 16, 3) / 1560896;
    CGFloat sub2 = sub1 > epsilon ? sub1 : (l / kappa);
    NSMutableArray *ret = [NSMutableArray array];
    
    if (!m) {
        setM();
    }
    
    for (int channel=0; channel<3; channel++) {
        Tuple mTuple;
        getTupleFromNSValue((NSValue *)m[channel], mTuple);
        
        CGFloat m1 = mTuple.a;
        CGFloat m2 = mTuple.b;
        CGFloat m3 = mTuple.c;
        
        for (int t=0; t <= 1; t++) {
            CGFloat top1 = (284517 * m1 - 94839 * m3) * sub2;
            CGFloat top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * l * sub2 -  769860 * t * l;
            CGFloat bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452 * t;
            
            Tuple2 tuple = {top1 / bottom, top2 / bottom};
            NSValue *newValue = nsvalueFromTuple(tuple, @encode(Tuple2));
            [ret addObject:newValue];
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

// For given lightness, returns the maximum chroma. Keeping the chroma value
// below this number will ensure that for any hue, the color is within the RGB
// gamut.
CGFloat maxSafeChromaForL(CGFloat l)  {
    CGFloat minLength = CGFLOAT_MAX;
    NSArray *bounds = getBounds(l);
    for (NSValue *bound in bounds) {
        Tuple2 boundTuple;
        getTupleFromNSValue(bound, boundTuple);
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
    for (NSValue *line in getBounds(l)) {
        Tuple2 lineTuple;
        getTupleFromNSValue(line, lineTuple);
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
    if (!m) {
        setM();
    }
    Tuple m0, m1, m2;
    getTupleFromNSValue(m[0], m0);
    getTupleFromNSValue(m[1], m1);
    getTupleFromNSValue(m[2], m2);
    
    CGFloat r = fromLinear(tupleDotProduct(m0, xyz));
    CGFloat g = fromLinear(tupleDotProduct(m1, xyz));
    CGFloat b = fromLinear(tupleDotProduct(m2, xyz));
    
    Tuple rgb = {r, g, b};
    return rgb;
}

Tuple rgbToXyz(Tuple rgb) {
    Tuple rgbl = {toLinear(rgb.a), toLinear(rgb.b), toLinear(rgb.c)};
    if (!m_inv) {
        setM_inv();
    }
    Tuple m_inv0, m_inv1, m_inv2;
    getTupleFromNSValue(m_inv[0], m_inv0);
    getTupleFromNSValue(m_inv[1], m_inv1);
    getTupleFromNSValue(m_inv[2], m_inv2);
    
    CGFloat x = tupleDotProduct(m_inv0, rgbl);
    CGFloat y = tupleDotProduct(m_inv1, rgbl);
    CGFloat z = tupleDotProduct(m_inv2, rgbl);
    
    Tuple xyz = {x, y, z};
    return xyz;
}

// http://en.wikipedia.org/wiki/CIELUV
CGFloat yToL (CGFloat y) {
    CGFloat l;
    if (y <= epsilon) {
        l = (y / refY) * kappa;
    }
    else {
        l = 116.0 * pow((y / refY), 1.0/3.0) - 16.0;
    }
    return l;
}

CGFloat lToY (CGFloat l) {
    if (l <= 8) {
        return refY * l / kappa;
    }
    else {
        return refY * powl((l + 16) / 116, 3);
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
    CGFloat c = sqrt(pow(u, 2) + pow(v, 2));
    CGFloat hRad = atan2(v, u);
    CGFloat h = hRad * 360 / 2 / M_PI;
    if (h < 0) {
        h = 360 + h;
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

// Rounds number to a given number of decimal places
CGFloat roundPlaces(CGFloat num, NSUInteger places) {
    CGFloat n = pow(10, places);
    return round(num * n) / n;
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

// Represents rgb [0-1] values as [0-255] values. Errors out if value
// out of the range
Tuple rgbPrepare(Tuple tuple) {
    tuple.a = roundPlaces(tuple.a, 3);
    tuple.b = roundPlaces(tuple.b, 3);
    tuple.c = roundPlaces(tuple.c, 3);
    
    if (tuple.a < -0.0001 || tuple.a > 1.0001 ||
        tuple.b < -0.0001 || tuple.b > 1.0001 ||
        tuple.c < -0.0001 || tuple.c > 1.0001) {
        @throw @"Illegal rgb value";
    }
    
    tuple.a = round(255*checkBorders(tuple.a));
    tuple.b = round(255*checkBorders(tuple.b));
    tuple.c = round(255*checkBorders(tuple.c));
    
    return tuple;
}

BOOL hexToInt(NSString *hex, unsigned int *result) {
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    return [scanner scanHexInt:result];
}

#pragma mark husl
Tuple huslToLch(Tuple husl) {
    // Bad things happen when you reach a limit
    if (husl.c > 99.9999999) {
        Tuple lch = {100, 0, husl.a};
        return lch;
    }
    if (husl.c < 0.00000001) {
        Tuple lch = {0, 0, husl.a};
        return lch;
    }
    CGFloat max = maxChromaForLH(husl.c, husl.a);
    CGFloat c = max / 100 * husl.b;
    // I already tried this scaling function to improve the chroma
    // uniformity. It did not work very well.
    // C = Math.powf(S / 100,  1 / t) * max
    Tuple lch = {husl.c, c, husl.a};
    return lch;
}

Tuple lchToHusl(Tuple lch) {
    if (lch.a > 99.9999999) {
        Tuple husl = {lch.c, 0, 100};
        return husl;
    }
    if (lch.a < 0.00000001) {
        Tuple husl = {lch.c, 0, 0};
        return husl;
    }
    CGFloat max = maxChromaForLH(lch.a, lch.c);
    CGFloat s = lch.b / max * 100;
    Tuple husl = {lch.c, s, lch.a};
    return husl;
}

#pragma mark huslP
Tuple huslpToLch(Tuple huslp) {
    if (huslp.c > 99.9999999) {
        Tuple lch = {100, 0, huslp.a};
        return lch;
    }
    if (huslp.c < 0.00000001) {
        Tuple lch = {0, 0, huslp.a};
        return lch;
    }
    CGFloat max = maxSafeChromaForL(huslp.c);
    CGFloat c = max / 100 * huslp.b;
    Tuple lch = {huslp.c, c, huslp.a};
    return lch;
}

Tuple lchToHuslp(Tuple lch) {
    if (lch.a > 99.9999999) {
        Tuple huslp = {lch.c, 0, 100};
        return huslp;
    }
    if (lch.a < 0.00000001) {
        Tuple huslp = {lch.c, 0, 0};
        return huslp;
    }
    CGFloat max = maxSafeChromaForL(lch.a);
    CGFloat s = lch.b / max * 100;
    Tuple huslp = {lch.c, s, lch.a};
    return huslp;
}

#pragma mark Public functions

NSString *rgbToHex(CGFloat red, CGFloat green, CGFloat blue) {
    Tuple rgb = {red, green, blue};
    NSString *hex = @"#";
    Tuple tuple = rgbPrepare(rgb);
    NSString *R = [NSString stringWithFormat:@"%02X", (int)tuple.a];
    NSString *G = [NSString stringWithFormat:@"%02X", (int)tuple.b];
    NSString *B = [NSString stringWithFormat:@"%02X", (int)tuple.c];
    
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
