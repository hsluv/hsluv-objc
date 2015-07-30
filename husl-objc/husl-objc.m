//
//  husl_objc.m
//  husl-objc
//
//  Created by Roger Tallada on 4/6/15.
//  Copyright (c) 2015 Alexei Boronine
//
// Implementation of husl translated from husl.coffee


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

#define NO_POINT (vector_float2){FLT_MAX, FLT_MAX}
#define NO_SEGMENT (vector_float2x2){NO_POINT, NO_POINT}

typedef struct LineBounds {
    vector_float2 a, b, c, d, e, f;
} LineBounds;

static vector_float3 mR = { 3.2409699419045214,   -1.5373831775700935, -0.49861076029300328}; // R
static vector_float3 mG = {-0.96924363628087983,   1.8759675015077207,  0.041555057407175613}; // G
static vector_float3 mB = { 0.055630079696993609, -0.20397695888897657, 1.0569715142428786}; // B

static vector_float3 m_invX = {0.41239079926595948,  0.35758433938387796, 0.18048078840183429}; // X
static vector_float3 m_invY = {0.21263900587151036,  0.71516867876775593, 0.072192315360733715}; // Y
static vector_float3 m_invZ = {0.019330818715591851, 0.11919477979462599, 0.95053215224966058}; // Z

//Constants
static float refU = 0.19783000664283681;
static float refV = 0.468319994938791;

// CIE LUV constants
static float kappa = 903.2962962962963;
static float epsilon = 0.0088564516790356308;

// For a given lightness, return a list of 6 lines in slope-intercept
// form that represent the bounds in CIELUV, stepping over which will
// push a value out of the RGB gamut
LineBounds getBounds(float l) {
    float sub1 = pow(l + 16, 3) / 1560896;
    float sub2 = sub1 > epsilon ? sub1 : (l / kappa);
    
    LineBounds ret;
    
    for (int channel=0; channel<3; channel++) {
        
        vector_float3 mfloat3;
        switch(channel) {
            case 0: mfloat3 = mR;
                break;
            case 1: mfloat3 = mG;
                break;
            case 2: mfloat3 = mB;
                break;
            default: mfloat3 = (vector_float3){0, 0, 0};
                break;
        }
        
        float m1 = mfloat3[0];
        float m2 = mfloat3[1];
        float m3 = mfloat3[2];
        
        for (int t=0; t <= 1; t++) {
            float top1 = (284517 * m1 - 94839 * m3) * sub2;
            float top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * l * sub2 -  769860 * t * l;
            float bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452 * t;
            
            vector_float2 float3 = {top1 / bottom, top2 / bottom};
            
            unsigned lineNumber = channel * 2 + t;
            switch(lineNumber) {
                case 0: ret.a = float3;
                    break;
                case 1: ret.b = float3;
                    break;
                case 2: ret.c = float3;
                    break;
                case 3: ret.d = float3;
                    break;
                case 4: ret.e = float3;
                    break;
                case 5: ret.f = float3;
                    break;
                default:
                    break;
            }
        }
    }
    return ret;
}

float lengthOfRayUntilIntersect(float theta, vector_float2 line) {
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
    float m1 = line.x;
    float b1 = line.y;
    float len = b1 / (sin(theta) - m1 * cos(theta));
    //    if (len < 0) {
    //        return 0;
    //    }
    return len;
}

float intersectLineLine(vector_float2 line1, vector_float2 line2) {
    return (line1.y - line2.y) / (line2.x - line1.x);
}

float distanceFromPole(vector_float2 point) {
    return sqrt(pow(point.x, 2) + pow(point.y, 2));
}

vector_float2 lineAtIndex(LineBounds bounds, unsigned index) {
    switch(index) {
        case 0: return bounds.a;
            break;
        case 1: return bounds.b;
            break;
        case 2: return bounds.c;
            break;
        case 3: return bounds.d;
            break;
        case 4: return bounds.e;
            break;
        case 5: return bounds.f;
            break;
        default:
            break;
    }
    return (vector_float2){0,0}; // Should never get here.
}

// For given lightness, returns the maximum chroma. Keeping the chroma value
// below this number will ensure that for any hue, the color is within the RGB
// gamut.
float maxSafeChromaForL(float l)  {
    float minLength = FLT_MAX;
    LineBounds bounds = getBounds(l);
    for (unsigned i = 0; i < 6; i++) {
        vector_float2 boundfloat3 = lineAtIndex(bounds, i);
        
        float m1 = boundfloat3.x;
        float b1 = boundfloat3.y;
        
        // x where line intersects with perpendicular running though (0, 0)
        vector_float2 line2 = (vector_float2){-1 / m1, 0};
        float x = intersectLineLine(boundfloat3, line2);
        float dist = distanceFromPole((vector_float2){x, b1 + x * m1});
        if (dist >= 0) {
            if (dist < minLength) {
                minLength = dist;
            }
        }
    }
    return minLength;
}

// For a given lightness and hue, return the maximum chroma that fits in
// the RGB gamut.
float maxChromaForLH(float l, float h) {
    float hrad = h / 360 * M_PI * 2;
    float minLength = FLT_MAX;
    LineBounds bounds = getBounds(l);
    for (unsigned i = 0; i < 6; i++) {
        vector_float2 linefloat3 = lineAtIndex(bounds, i);
        float l = lengthOfRayUntilIntersect(hrad, linefloat3);
        if (l >= 0)  {
            if (l < minLength) {
                minLength = l;
            }
        }
    }
    return minLength;
}

// Used for rgb conversions
float fromLinear(float c) {
    if (c <= 0.0031308) {
        return 12.92 * c;
    }
    else {
        return 1.055 * pow(c, 1 / 2.4) - 0.055;
    }
}

float toLinear(float c) {
    float a = 0.055;
    if (c > 0.04045) {
        return pow((c + a) / (1 + a), 2.4);
    }
    else {
        return c / 12.92;
    }
}

// Conversion functions

vector_float3 xyzToRgb(vector_float3 xyz) {
    float r = fromLinear(vector_dot(mR, xyz));
    float g = fromLinear(vector_dot(mG, xyz));
    float b = fromLinear(vector_dot(mB, xyz));
    
    vector_float3 rgb = {r, g, b};
    return rgb;
}

//float dotProduct(vector_float3 m1, vector_float3 m2) {
//    float product = 0;
//    for (unsigned i = 0; i < 3; i++) {
//        product += m1[i] * m2[i];
//    }
//    return product == 0.0 ? 0.5 : product;
//}

vector_float3 rgbToXyz(vector_float3 rgb) {
    vector_float3 rgbl = {toLinear(rgb.x), toLinear(rgb.y), toLinear(rgb.z)};
    
    float x = vector_dot(m_invX, rgbl);
    float y = vector_dot(m_invY, rgbl);
    float z = vector_dot(m_invZ, rgbl);
    
    vector_float3 xyz = {x, y, z};
    return xyz;
}

// http://en.wikipedia.org/wiki/CIELUV
// In these formulas, Yn refers to the reference white point. We are using
// illuminant D65, so Yn (see refY in Maxima file) equals 1. The formula is
// simplified accordingly.
float yToL (float y) {
    float l;
    if (y <= epsilon) {
        l = y * kappa;
    }
    else {
        l = 116.0 * pow(y, 1.0/3.0) - 16.0;
    }
    return l;
}

float lToY (float l) {
    if (l <= 8) {
        return l / kappa;
    }
    else {
        return pow((l + 16) / 116, 3);
    }
}

vector_float3 xyzToLuv(vector_float3 xyz) {
    float varU = (4 * xyz.x) / (xyz.x + (15 * xyz.y) + (3 * xyz.z));
    float varV = (9 * xyz.y) / (xyz.x + (15 * xyz.y) + (3 * xyz.z));
    float l = yToL(xyz.y);
    // Black will create a divide-by-zero error
    if (l==0) {
        vector_float3 luv = {0, 0, 0};
        return luv;
    }
    float u = 13 * l * (varU - refU);
    float v = 13 * l * (varV - refV);
    vector_float3 luv = {l, u, v};
    return luv;
}

vector_float3 luvToXyz(vector_float3 luv) {
    // Black will create a divide-by-zero error
    if (luv.x == 0) {
        vector_float3 xyz = {0, 0, 0};
        return xyz;
    }
    float varU = luv.y / (13 * luv.x) + refU;
    float varV = luv.z / (13 * luv.x) + refV;
    float y = lToY(luv.x);
    float x = 0 - (9 * y * varU) / ((varU - 4) * varV - varU * varV);
    float z = (9 * y - (15 * varV * y) - (varV * x)) / (3 * varV);
    vector_float3 xyz = {x, y, z};
    return xyz;
}

vector_float3 luvToLch(vector_float3 luv) {
    float l = luv.x, u = luv.y, v = luv.z;
    float h, c = sqrt(pow(u, 2) + pow(v, 2));
    
    // Greys: disambiguate hue
    if (c < 0.00000001) {
        h = 0;
    }
    else {
        float hrad = atan2(v, u);
        h = hrad * 360 / 2 / M_PI;
        if (h < 0) {
            h = 360 + h;
        }
    }
    
    vector_float3 lch = {l, c, h};
    return lch;
}

vector_float3 lchToLuv(vector_float3 lch) {
    float hRad = lch.z / 360 * 2 * M_PI;
    float u = cos(hRad) * lch.y;
    float v = sin(hRad) * lch.y;
    vector_float3 luv = {lch.x, u, v};
    return luv;
}

// HUSL
vector_float3 huslToLch(vector_float3 husl) {
    float h = husl.x, s = husl.y, l = husl.z, c;
    
    // White and black: disambiguate chroma
    if (l > 99.9999999 || l < 0.00000001) {
        c = 0;
    }
    else {
        float max = maxChromaForLH(l, h);
        c = max / 100 * s;
    }
    // Greys: disambiguate hue
    if (s < 0.00000001) {
        h = 0;
    }
    vector_float3 lch = {l, c, h};
    return lch;
}

vector_float3 lchToHusl(vector_float3 lch) {
    float l = lch.x, c = lch.y, h = lch.z, s;
    
    // White and black: disambiguate saturation
    if (l > 99.9999999 || l < 0.00000001) {
        s = 0;
    }
    else {
        float max = maxChromaForLH(l, h);
        s = c / max * 100;
    }
    // Greys: disambiguate hue
    if (c < 0.00000001) {
        h = 0;
    }
    vector_float3 husl = {h, s, l};
    return husl;
}

vector_float3 vectorHuslToRgb(vector_float3 husl) {
    vector_float3 rgb = xyzToRgb(luvToXyz(lchToLuv(huslToLch(husl))));
    return rgb;
}

vector_float3 vectorRgbToHusl(vector_float3 rgb) {
    vector_float3 husl = lchToHusl(luvToLch(xyzToLuv(rgbToXyz(rgb))));
    return husl;
}

#pragma mark huslP
vector_float3 huslpToLch(vector_float3 huslp) {
    float h = huslp.x, s = huslp.y, l = huslp.z, c;
    
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
    vector_float3 lch = {l, c, h};
    return lch;
}

vector_float3 lchToHuslp(vector_float3 lch) {
    float l = lch.x, c = lch.y, h = lch.z, s;
    
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
    
    vector_float3 huslp = {h, s, l};
    return huslp;
}

BOOL hexToInt(NSString *hex, unsigned int *result) {
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    return [scanner scanHexInt:result];
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
    
    NSString *R = [NSString stringWithFormat:@"%02X", (int)round(r * 255)];
    NSString *G = [NSString stringWithFormat:@"%02X", (int)round(g * 255)];
    NSString *B = [NSString stringWithFormat:@"%02X", (int)round(b * 255)];
    
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
    vector_float3 husl = {hue, saturation, lightness};
    
    vector_float3 rgb = vectorHuslToRgb(husl);
    
    *red = rgb.x;
    *green = rgb.y;
    *blue = rgb.z;
}

void rgbToHusl(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness) {
    vector_float3 rgb = {red, green, blue};
    vector_float3 husl = vectorRgbToHusl(rgb);
    *hue = husl.x;
    *saturation = husl.y;
    *lightness = husl.z;
}

void huslpToRgb(CGFloat hue, CGFloat saturation, CGFloat lightness, CGFloat *red, CGFloat *green, CGFloat *blue) {
    vector_float3 huslp = {hue, saturation, lightness};
    
    vector_float3 rgb = xyzToRgb(luvToXyz(lchToLuv(huslpToLch(huslp))));
    
    *red = rgb.x;
    *green = rgb.y;
    *blue = rgb.z;
}

void rgbToHuslp(CGFloat red, CGFloat green, CGFloat blue, CGFloat *hue, CGFloat *saturation, CGFloat *lightness) {
    vector_float3 rgb = {red, green, blue};
    
    vector_float3 huslp = lchToHuslp(luvToLch(xyzToLuv(rgbToXyz(rgb))));
    
    *hue = huslp.x;
    *saturation = huslp.y;
    *lightness = huslp.z;
}
