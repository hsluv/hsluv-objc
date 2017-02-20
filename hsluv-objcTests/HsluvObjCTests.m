//
//  HsluvObjCTests.m
//  hsluv-objc
//
//  Created by Roger Tallada on 4/6/15.
//  Copyright (c) 2015 Alexei Boronine
//

#import <XCTest/XCTest.h>
#import "hsluv-objc.h"
#import "hsluv-objc+Test.h"

@interface HsluvObjCTests : XCTestCase

@end

@implementation HsluvObjCTests

const NSString *kRgb = @"rgb";
const NSString *kXyz = @"xyz";
const NSString *kLuv = @"luv";
const NSString *kLch = @"lch";
const NSString *kHsluv = @"hsluv";
const NSString *kHpluv = @"hpluv";

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testHsluvConsistency {
    NSMutableArray *manySamples = [NSMutableArray array];
    
    [self processSamples:^(NSString *hex) {
        [manySamples addObject:hex];
    }];
    
    XCTAssert([self hexSamplesTester:manySamples usingPastelMode:NO], @"should convert between HSLuv and hex");
    XCTAssert([self hexSamplesTester:manySamples usingPastelMode:YES], @"should convert between HPLuv and hex");
}

- (void)testFitsWithinRGBRanges {
    CGFloat rgbRangeTolerance = 0.00000000001;
    
    for (CGFloat h = 0; h < 360; h = h + 5) {
        for (CGFloat s = 0; s < 100; s = s + 5) {
            for (CGFloat l = 0; l < 100; l = l + 5) {
                CGFloat r, g, b;
                hsluvToRgb(h, s, l, &r, &g, &b);
                XCTAssert(-rgbRangeTolerance <= r && r <= 1 + rgbRangeTolerance, @"HSLuv testFitsWithinRGBRanges");
                XCTAssert(-rgbRangeTolerance <= g && g <= 1 + rgbRangeTolerance, @"HSLuv testFitsWithinRGBRanges");
                XCTAssert(-rgbRangeTolerance <= b && b <= 1 + rgbRangeTolerance, @"HSLuv testFitsWithinRGBRanges");

                hpluvToRgb(h, s, l, &r, &g, &b);
                XCTAssert(-rgbRangeTolerance <= r && r <= 1 + rgbRangeTolerance, @"HPLuv testFitsWithinRGBRanges");
                XCTAssert(-rgbRangeTolerance <= g && g <= 1 + rgbRangeTolerance, @"HPLuv testFitsWithinRGBRanges");
                XCTAssert(-rgbRangeTolerance <= b && b <= 1 + rgbRangeTolerance, @"HPLuv testFitsWithinRGBRanges");
            }
        }
    }
}

- (void)testMatchesStableSnapshot {
    NSString *stableSnapshotFilename = @"snapshot-rev4";
    
    NSString *filePath =[[NSBundle bundleForClass:[self class]] pathForResource:stableSnapshotFilename ofType:@"json"];
    NSError *error;
    NSString* fileContents =[NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    
    BOOL matchesSnapshot = YES;
    if(error) {
        NSLog(@"Error reading file: %@",error.localizedDescription);
        matchesSnapshot = NO;
    }
    else {
        NSDictionary *stableSnapshot = (NSDictionary *)[NSJSONSerialization
                                                        JSONObjectWithData:[fileContents dataUsingEncoding:NSUTF8StringEncoding]
                                                        options:0 error:&error];
        if(error) {
            NSLog(@"Error parsing snapshot: %@",error.localizedDescription);
            matchesSnapshot = NO;
        }
        else {
            NSDictionary *snapshot = [self snapshot];
            
            for (NSString *hex in [stableSnapshot allKeys]) {
                NSDictionary *stableSample = (NSDictionary *)stableSnapshot[hex];
                NSDictionary *sample = (NSDictionary *)snapshot[[hex uppercaseString]];
                if (!sample) {
                    NSLog(@"Can't find the sample for %@", hex);
                    matchesSnapshot = NO;
                    break;
                }
                
                for (NSString *tag in [stableSample allKeys]) {
                    NSArray *stableComponents = (NSArray *)stableSample[tag];
                    NSArray *components = (NSArray *)sample[tag];
                    if (![self compareComponents:stableComponents with:components]) {
                        NSLog(@"The snapshots for %@ don't match at %@.", hex, tag);
                        matchesSnapshot = NO;
                        break;
                    }
                }
            }
        }
    }
    
    XCTAssert(matchesSnapshot, @"should match the stable snapshot");
}

#pragma mark Helper methods

- (BOOL)compareComponents:(NSArray *)tuple1 with:(NSArray *)tuple2 {
    CGFloat snapshotTolerance = 0.00000001;
    if (tuple1.count != tuple2.count || tuple1.count != 3) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < 3; i = i + 1) {
        CGFloat component1 = [(NSNumber *)tuple1[i] doubleValue];
        CGFloat component2 = [(NSNumber *)tuple2[i] doubleValue];
        CGFloat diff = fabs(component1 - component2);
        if (diff >= snapshotTolerance) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)hexSamplesTester:(NSArray *)manySamples usingPastelMode:(BOOL)pMode {
    BOOL hsluvToHexOk = YES;
    for (NSString *hex in manySamples) {
        CGFloat r, g, b;
        if (hexToRgb(hex, &r, &g, &b)) {
            CGFloat h, s, l;
            if (!pMode) {
                rgbToHsluv(r, g, b, &h, &s, &l);
                hsluvToRgb(h, s, l, &r, &g, &b);
            }
            else {
                rgbToHpluv(r, g, b, &h, &s, &l);
                hpluvToRgb(h, s, l, &r, &g, &b);
            }
            NSString *newHex = rgbToHex(r, g, b);
            if (![newHex isEqualToString:hex]) {
                hsluvToHexOk = NO;
                NSLog(@"%@ -> %@", hex, newHex);
                break;
            }
        }
        else {
            hsluvToHexOk = NO;
            break;
        }
    }
    return hsluvToHexOk;
}

- (void)processSamples:(void (^)(NSString *hex))function {
    NSArray *digits = @[@"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"A", @"B", @"C", @"D", @"E", @"F"];
    
    // Take 16 ^ 3 = 4096 samples
    for (NSString *r in digits) {
        for (NSString *g in digits) {
            for (NSString *b in digits) {
                NSString *hex = [NSString stringWithFormat:@"#%@%@%@%@%@%@", r, r, g, g, b, b];
                function(hex);
            }
        }
    }
}

- (NSArray *)tupleToArray:(Tuple) t {
    return @[@(t.a), @(t.b), @(t.c)];
}

- (NSDictionary *)snapshot {
    NSMutableDictionary *samples = [NSMutableDictionary dictionary];
    
    [self processSamples:^(NSString *hex) {
        CGFloat r, g, b;
        if (hexToRgb(hex, &r, &g, &b)) {
            Tuple xyz, luv, lch, hsluv, hpluv;
            Tuple rgb = {r, g, b};
            xyz = rgbToXyz(rgb);
            luv = xyzToLuv(xyz);
            lch = luvToLch(luv);
            hsluv = lchToHsluv(lch);
            hpluv = lchToHpluv(lch);

            NSMutableDictionary *sample = [NSMutableDictionary dictionary];
            sample[kRgb] = [self tupleToArray:rgb];
            sample[kXyz] = [self tupleToArray:xyz];
            sample[kLuv] = [self tupleToArray:luv];
            sample[kLch] = [self tupleToArray:lch];
            sample[kHsluv] = [self tupleToArray:hsluv];
            sample[kHpluv] = [self tupleToArray:hpluv];
            
            samples[hex] = sample;
        }
    }];
    
    return samples;
}


@end
