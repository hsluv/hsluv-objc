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
 #    double(M_XYZ_RGB);
 #    double(M_RGB_XYZ);
 #    double(refX);
 #    double(refY);
 #    double(refZ);
 #    double(refU);
 #    double(refV);
 #    double(lab_k);
 #    double(lab_e);
 #*/

#define NO_POINT (vector_double2){FLT_MAX, FLT_MAX}
#define NO_SEGMENT (vector_double2x2){NO_POINT, NO_POINT}

static vector_double3 mR = { 3.2409699419045214,   -1.5373831775700935, -0.49861076029300328}; // R
static vector_double3 mG = {-0.96924363628087983,   1.8759675015077207,  0.041555057407175613}; // G
static vector_double3 mB = { 0.055630079696993609, -0.20397695888897657, 1.0569715142428786}; // B

static vector_double3 m_invX = {0.41239079926595948,  0.35758433938387796, 0.18048078840183429}; // X
static vector_double3 m_invY = {0.21263900587151036,  0.71516867876775593, 0.072192315360733715}; // Y
static vector_double3 m_invZ = {0.019330818715591851, 0.11919477979462599, 0.95053215224966058}; // Z

//Constants
static double refU = 0.19783000664283681;
static double refV = 0.468319994938791;

// CIE LUV constants
static double kappa = 903.2962962962963;
static double epsilon = 0.0088564516790356308;

// For a given lightness, return a list of 6 lines in slope-intercept
// form that represent the bounds in CIELUV, stepping over which will
// push a value out of the RGB gamut
vector_double2 *getBounds(double l) {
    double sub1 = pow(l + 16, 3) / 1560896;
    double sub2 = sub1 > epsilon ? sub1 : (l / kappa);
    
    vector_double2 *ret = malloc(sizeof(vector_double2)*6);
    
    for (int channel=0; channel<3; channel++) {
        
        vector_double3 mdouble3;
        switch(channel) {
            case 0: mdouble3 = mR;
                break;
            case 1: mdouble3 = mG;
                break;
            case 2: mdouble3 = mB;
                break;
            default: mdouble3 = (vector_double3){0, 0, 0};
                break;
        }
        
        double m1 = mdouble3[0];
        double m2 = mdouble3[1];
        double m3 = mdouble3[2];
        
        for (int t=0; t <= 1; t++) {
            double top1 = (284517 * m1 - 94839 * m3) * sub2;
            double top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * l * sub2 -  769860 * t * l;
            double bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452 * t;
            
            vector_double2 double3 = {top1 / bottom, top2 / bottom};
            
            unsigned lineNumber = channel * 2 + t;
            ret[lineNumber] = double3;
            
        }
    }
    return ret;
}

double lengthOfRayUntilIntersect(double theta, vector_double2 line) {
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
    double m1 = line.x;
    double b1 = line.y;
    double len = b1 / (sin(theta) - m1 * cos(theta));
    //    if (len < 0) {
    //        return 0;
    //    }
    return len;
}

double intersectLineLine(vector_double2 line1, vector_double2 line2) {
    return (line1.y - line2.y) / (line2.x - line1.x);
}

// For given lightness, returns the maximum chroma. Keeping the chroma value
// below this number will ensure that for any hue, the color is within the RGB
// gamut.
double maxSafeChromaForL(double l)  {
    double minLength = FLT_MAX;
    vector_double2 *bounds = getBounds(l);
    for (unsigned i = 0; i < 6; i++) {
        vector_double2 bounddouble3 = bounds[i];
        
        double m1 = bounddouble3.x;
        double b1 = bounddouble3.y;
        
        // x where line intersects with perpendicular running though (0, 0)
        vector_double2 line2 = (vector_double2){-1 / m1, 0};
        double x = intersectLineLine(bounddouble3, line2);
        double dist = vector_length((vector_double2){x, b1 + x * m1}); // distanceFromPole
        if (dist >= 0) {
            if (dist < minLength) {
                minLength = dist;
            }
        }
    }
    free(bounds);
    return minLength;
}

// For a given lightness and hue, return the maximum chroma that fits in
// the RGB gamut.
double maxChromaForLH(double l, double h) {
    double hrad = h / 360 * M_PI * 2;
    double minLength = FLT_MAX;
    vector_double2 *bounds = getBounds(l);
    for (unsigned i = 0; i < 6; i++) {
        vector_double2 linedouble3 = bounds[i];
        double l = lengthOfRayUntilIntersect(hrad, linedouble3);
        if (l >= 0)  {
            if (l < minLength) {
                minLength = l;
            }
        }
    }
    free(bounds);
    return minLength;
}

// Used for rgb conversions
double fromLinear(double c) {
    if (c <= 0.0031308) {
        return 12.92 * c;
    }
    else {
        return 1.055 * pow(c, 1 / 2.4) - 0.055;
    }
}

double toLinear(double c) {
    double a = 0.055;
    if (c > 0.04045) {
        return pow((c + a) / (1 + a), 2.4);
    }
    else {
        return c / 12.92;
    }
}

// Conversion functions

vector_double3 xyzToRgb(vector_double3 xyz) {
    double r = fromLinear(vector_dot(mR, xyz));
    double g = fromLinear(vector_dot(mG, xyz));
    double b = fromLinear(vector_dot(mB, xyz));
    
    vector_double3 rgb = {r, g, b};
    return rgb;
}

//double dotProduct(vector_double3 m1, vector_double3 m2) {
//    double product = 0;
//    for (unsigned i = 0; i < 3; i++) {
//        product += m1[i] * m2[i];
//    }
//    return product == 0.0 ? 0.5 : product;
//}

vector_double3 rgbToXyz(vector_double3 rgb) {
    vector_double3 rgbl = {toLinear(rgb.x), toLinear(rgb.y), toLinear(rgb.z)};
    
    double x = vector_dot(m_invX, rgbl);
    double y = vector_dot(m_invY, rgbl);
    double z = vector_dot(m_invZ, rgbl);
    
    vector_double3 xyz = {x, y, z};
    return xyz;
}

// http://en.wikipedia.org/wiki/CIELUV
// In these formulas, Yn refers to the reference white point. We are using
// illuminant D65, so Yn (see refY in Maxima file) equals 1. The formula is
// simplified accordingly.
double yToL (double y) {
    double l;
    if (y <= epsilon) {
        l = y * kappa;
    }
    else {
        l = 116.0 * pow(y, 1.0/3.0) - 16.0;
    }
    return l;
}

double lToY (double l) {
    if (l <= 8) {
        return l / kappa;
    }
    else {
        return pow((l + 16) / 116, 3);
    }
}

vector_double3 xyzToLuv(vector_double3 xyz) {
    double varU = (4 * xyz.x) / (xyz.x + (15 * xyz.y) + (3 * xyz.z));
    double varV = (9 * xyz.y) / (xyz.x + (15 * xyz.y) + (3 * xyz.z));
    double l = yToL(xyz.y);
    // Black will create a divide-by-zero error
    if (l==0) {
        vector_double3 luv = {0, 0, 0};
        return luv;
    }
    double u = 13 * l * (varU - refU);
    double v = 13 * l * (varV - refV);
    vector_double3 luv = {l, u, v};
    return luv;
}

vector_double3 luvToXyz(vector_double3 luv) {
    // Black will create a divide-by-zero error
    if (luv.x == 0) {
        vector_double3 xyz = {0, 0, 0};
        return xyz;
    }
    double varU = luv.y / (13 * luv.x) + refU;
    double varV = luv.z / (13 * luv.x) + refV;
    double y = lToY(luv.x);
    double x = 0 - (9 * y * varU) / ((varU - 4) * varV - varU * varV);
    double z = (9 * y - (15 * varV * y) - (varV * x)) / (3 * varV);
    vector_double3 xyz = {x, y, z};
    return xyz;
}

vector_double3 luvToLch(vector_double3 luv) {
    double l = luv.x, u = luv.y, v = luv.z;
    vector_double2 uv = {u, v};
    double h, c = vector_length(uv);
    
    // Greys: disambiguate hue
    if (c < 0.00000001) {
        h = 0;
    }
    else {
        double hrad = atan2(v, u);
        h = hrad * 360 / 2 / M_PI;
        if (h < 0) {
            h = 360 + h;
        }
    }
    
    vector_double3 lch = {l, c, h};
    return lch;
}

vector_double3 lchToLuv(vector_double3 lch) {
    double hRad = lch.z / 360 * 2 * M_PI;
    double u = cos(hRad) * lch.y;
    double v = sin(hRad) * lch.y;
    vector_double3 luv = {lch.x, u, v};
    return luv;
}

// HUSL
vector_double3 huslToLch(vector_double3 husl) {
    double h = husl.x, s = husl.y, l = husl.z, c;
    
    // White and black: disambiguate chroma
    if (l > 99.9999999 || l < 0.00000001) {
        c = 0;
    }
    else {
        double max = maxChromaForLH(l, h);
        c = max / 100 * s;
    }
    // Greys: disambiguate hue
    if (s < 0.00000001) {
        h = 0;
    }
    vector_double3 lch = {l, c, h};
    return lch;
}

vector_double3 lchToHusl(vector_double3 lch) {
    double l = lch.x, c = lch.y, h = lch.z, s;
    
    // White and black: disambiguate saturation
    if (l > 99.9999999 || l < 0.00000001) {
        s = 0;
    }
    else {
        double max = maxChromaForLH(l, h);
        s = c / max * 100;
    }
    // Greys: disambiguate hue
    if (c < 0.00000001) {
        h = 0;
    }
    vector_double3 husl = {h, s, l};
    return husl;
}

vector_double3 vectorHuslToRgb(vector_double3 husl) {
    vector_double3 rgb = xyzToRgb(luvToXyz(lchToLuv(huslToLch(husl))));
    return rgb;
}

vector_double3 vectorRgbToHusl(vector_double3 rgb) {
    vector_double3 husl = lchToHusl(luvToLch(xyzToLuv(rgbToXyz(rgb))));
    return husl;
}

#pragma mark huslP
vector_double3 huslpToLch(vector_double3 huslp) {
    double h = huslp.x, s = huslp.y, l = huslp.z, c;
    
    // White and black: disambiguate chroma
    if (l > 99.9999999 || l < 0.00000001) {
        c = 0;
    }
    else {
        double max = maxSafeChromaForL(l);
        c = max / 100 * s;
    }
    
    // Greys: disambiguate hue
    if (s < 0.00000001) {
        h = 0;
    }
    vector_double3 lch = {l, c, h};
    return lch;
}

vector_double3 lchToHuslp(vector_double3 lch) {
    double l = lch.x, c = lch.y, h = lch.z, s;
    
    // White and black: disambiguate saturation
    if (l > 99.9999999 || l < 0.00000001) {
        s = 0;
    }
    else {
        double max = maxSafeChromaForL(l);
        s = c / max * 100;
    }
    // Greys: disambiguate hue
    if (c < 0.00000001) {
        h = 0;
    }
    
    vector_double3 huslp = {h, s, l};
    return huslp;
}

vector_double3 vectorHuslpToRgb(vector_double3 huslp) {
    vector_double3 rgb = xyzToRgb(luvToXyz(lchToLuv(huslpToLch(huslp))));
    return rgb;
}

vector_double3 vectorRgbToHuslp(vector_double3 rgb) {
    vector_double3 huslp = lchToHuslp(luvToLch(xyzToLuv(rgbToXyz(rgb))));
    return huslp;
}

BOOL hexToInt(NSString *hex, unsigned int *result) {
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    return [scanner scanHexInt:result];
}

double roundTo6decimals(double channel) {
    double ch = round(channel * 1e6) / 1e6;
    if (ch < 0 || ch > 1) {
        @throw [NSString stringWithFormat:@"Illegal rgb value: %@", @(ch)];
    }
    return ch;
}

#pragma mark Public functions

NSString *rgbToHex(double red, double green, double blue) {
    NSString *hex = @"#";
    
    double r = roundTo6decimals(red);
    double g = roundTo6decimals(green);
    double b = roundTo6decimals(blue);
    
    NSString *R = [NSString stringWithFormat:@"%02X", (int)round(r * 255)];
    NSString *G = [NSString stringWithFormat:@"%02X", (int)round(g * 255)];
    NSString *B = [NSString stringWithFormat:@"%02X", (int)round(b * 255)];
    
    return [[[hex stringByAppendingString:R] stringByAppendingString:G] stringByAppendingString:B];
}

BOOL hexToRgb(NSString *hex, double *red, double *green, double *blue) {
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
        
        *red = (double)r / 255;
        *green = (double)g / 255;
        *blue = (double)b / 255;
        
        return YES;
    }
    return NO;
}

void huslToRgb(double hue, double saturation, double lightness, double *red, double *green, double *blue) {
    vector_double3 husl = {hue, saturation, lightness};
    
    vector_double3 rgb = vectorHuslToRgb(husl);
    
    *red = rgb.x;
    *green = rgb.y;
    *blue = rgb.z;
}

void rgbToHusl(double red, double green, double blue, double *hue, double *saturation, double *lightness) {
    vector_double3 rgb = {red, green, blue};
    vector_double3 husl = vectorRgbToHusl(rgb);
    *hue = husl.x;
    *saturation = husl.y;
    *lightness = husl.z;
}

void huslpToRgb(double hue, double saturation, double lightness, double *red, double *green, double *blue) {
    vector_double3 huslp = {hue, saturation, lightness};
    
    vector_double3 rgb = vectorHuslpToRgb(huslp);
    
    *red = rgb.x;
    *green = rgb.y;
    *blue = rgb.z;
}

void rgbToHuslp(double red, double green, double blue, double *hue, double *saturation, double *lightness) {
    vector_double3 rgb = {red, green, blue};
    
    vector_double3 huslp = vectorRgbToHuslp(rgb);
    
    *hue = huslp.x;
    *saturation = huslp.y;
    *lightness = huslp.z;
}
