//
//  AIRMapWMSTile.m
//  AirMaps
//
//  Created by nizam on 10/28/18.
//  Copyright © 2018. All rights reserved.
//

#import "AIRMapWMSTile.h"
#import <React/UIView+React.h>
#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

@implementation AIRMapWMSTile
 
- (void)createTileOverlayAndRendererIfPossible
{
    if (!_urlTemplateSet) return;
    if (_tileCachePathSet || _maximumNativeZSet) {
        NSLog(@"tileCache new overlay dir %@", self.tileCachePath);
        NSLog(@"tileCache %d", _tileCachePathSet);
        NSLog(@"tileCache %d", _maximumNativeZSet);
        self.tileOverlay = [[AIRMapWMSTileCachedOverlay alloc] initWithURLTemplate:self.urlTemplate];
        _cachedOverlayCreated = YES;
        if (_tileCachePathSet) {
            NSURL *urlPath = [NSURL URLWithString:[self.tileCachePath stringByAppendingString:@"/"]];
            if (urlPath.fileURL) {
                self.tileOverlay.tileCachePath = urlPath;
            } else {
                NSURL *filePath = [NSURL fileURLWithPath:self.tileCachePath isDirectory:YES];
                self.tileOverlay.tileCachePath = filePath;
            }

            if (_tileCacheMaxAgeSet) {
                self.tileOverlay.tileCacheMaxAge = self.tileCacheMaxAge;
            }
        }
    } else {
        NSLog(@"tileCache normal overlay");
        self.tileOverlay = [[AIRMapWMSTileOverlay alloc] initWithURLTemplate:self.urlTemplate];
        _cachedOverlayCreated = NO;
    }

    [self updateProperties];

    self.renderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay:self.tileOverlay];
    if (_opacitySet) {
        self.renderer.alpha = self.opacity;
    }
}

@end


@implementation AIRMapWMSTileOverlay

- (id)initWithURLTemplate:(NSString *)URLTemplate 
{
    self = [super initWithURLTemplate:URLTemplate];
    return self;
}

- (NSURL *)URLForTilePath:(MKTileOverlayPath)path
{
   return [AIRMapWMSTileHelper URLForTilePath:path withURLTemplate:self.URLTemplate withTileSize:self.tileSize.width];
}

@end


@implementation AIRMapWMSTileCachedOverlay

- (id)initWithURLTemplate:(NSString *)URLTemplate 
{
    self = [super initWithURLTemplate:URLTemplate];
    return self;
}

- (NSURL *)URLForTilePath:(MKTileOverlayPath)path
{
   return [AIRMapWMSTileHelper URLForTilePath:path withURLTemplate:self.URLTemplate withTileSize:self.tileSize.width];
}

@end


@implementation AIRMapWMSTileHelper 
+ (NSURL *)URLForTilePath:(MKTileOverlayPath)path withURLTemplate:(NSString *)URLTemplate withTileSize:(NSInteger)tileSize
{
    int isUTM = 0;
    NSArray *bb = [self getBoundBox:path.x yAxis:path.y zoom:path.z isUTM:isUTM];
    NSMutableString *url = [URLTemplate mutableCopy];
    [url replaceOccurrencesOfString: @"{minX}" withString:[NSString stringWithFormat:@"%@", bb[0]] options:0 range:NSMakeRange(0, url.length)];
    [url replaceOccurrencesOfString: @"{minY}" withString:[NSString stringWithFormat:@"%@", bb[1]] options:0 range:NSMakeRange(0, url.length)];
    [url replaceOccurrencesOfString: @"{maxX}" withString:[NSString stringWithFormat:@"%@", bb[2]] options:0 range:NSMakeRange(0, url.length)];
    [url replaceOccurrencesOfString: @"{maxY}" withString:[NSString stringWithFormat:@"%@", bb[3]] options:0 range:NSMakeRange(0, url.length)];
    [url replaceOccurrencesOfString: @"{width}" withString:[NSString stringWithFormat:@"%d", (int)tileSize] options:0 range:NSMakeRange(0, url.length)];
    [url replaceOccurrencesOfString: @"{height}" withString:[NSString stringWithFormat:@"%d", (int)tileSize] options:0 range:NSMakeRange(0, url.length)];
    return [NSURL URLWithString:url];
}

- (double) convertY:(int) y Zoom:(int) zoom  {
    double scale = pow(2.0, zoom);
    double n = M_PI - (2.0 * M_PI * y ) / scale;
    return  atan(sinh(n)) * 180 / M_PI;
}

+ (NSString *) getDataFrom:(NSString *)url{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:url]];

    NSError *error = nil;
    NSHTTPURLResponse *responseCode = nil;

    NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];

    if([responseCode statusCode] != 200){
        NSLog(@"Error getting %@, HTTP status code %i", url, [responseCode statusCode]);
        return nil;
    }

    return [[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding];
}

+ (NSArray *)getBoundBox:(NSInteger)x yAxis:(NSInteger)y zoom:(NSInteger)zoom isUTM:(NSInteger)isUTM{
    double scale = pow(2.0, zoom);

    double x1 = x/scale * 360 - 180;
    double x2 = (x+1)/scale * 360 - 180;
    double y1 = [self convertY:(double)(y+1) Zoom:(double)zoom];
    double y2 = [self convertY:(double)(y) Zoom:(double)zoom];

    if (isUTM == 1){
        NSNumber *myX1DoubleNumber = [NSNumber numberWithDouble:x1];
        NSNumber *myY1DoubleNumber = [NSNumber numberWithDouble:y1];
        NSNumber *myX2DoubleNumber = [NSNumber numberWithDouble:x2];
        NSNumber *myY2DoubleNumber = [NSNumber numberWithDouble:y2];

        NSString *epsg3301url1 = @"https://epsg.io/trans?x={x}&y={y}&s_srs=3857&t_srs=3301";
        NSCharacterSet *numbers = [NSCharacterSet
                characterSetWithCharactersInString:@"0123456789."];

        epsg3301url1 = [epsg3301url1 stringByReplacingOccurrencesOfString:@"{x}" withString:[myX1DoubleNumber stringValue]];
        epsg3301url1 = [epsg3301url1 stringByReplacingOccurrencesOfString:@"{y}" withString:[myY1DoubleNumber stringValue]];
        NSString *utmStr1 = [self getDataFrom:epsg3301url1];
        NSArray *utmArray1 = [utmStr1 componentsSeparatedByString:@","];

        x2 = [[[utmArray1[0] componentsSeparatedByCharactersInSet:
                [numbers invertedSet]]
                componentsJoinedByString:@""] doubleValue];
        y1 = [[[utmArray1[1] componentsSeparatedByCharactersInSet:
                [numbers invertedSet]]
                componentsJoinedByString:@""] doubleValue];

        NSString *epsg3301url2 = @"https://epsg.io/trans?x={x}&y={y}&s_srs=4326&t_srs=3301";

        epsg3301url2 = [epsg3301url2 stringByReplacingOccurrencesOfString:@"{x}" withString:[myX2DoubleNumber stringValue]];
        epsg3301url2 = [epsg3301url2 stringByReplacingOccurrencesOfString:@"{y}" withString:[myY2DoubleNumber stringValue]];
        NSString *utmStr2 = [self getDataFrom:epsg3301url1];
        NSArray *utmArray2 = [utmStr2 componentsSeparatedByString:@","];

        x1 = [[[utmArray2[0] componentsSeparatedByCharactersInSet:
                [numbers invertedSet]]
                componentsJoinedByString:@""] doubleValue];
        y2 = [[[utmArray2[1] componentsSeparatedByCharactersInSet:
                [numbers invertedSet]]
                componentsJoinedByString:@""] doubleValue];
    }//x1x2y1y2 annab mingi vastuse...

    NSArray *result  =[[NSArray alloc] initWithObjects:
            [NSNumber numberWithDouble:x1 ],
            [NSNumber numberWithDouble:y1 ],
            [NSNumber numberWithDouble:x2 ],
            [NSNumber numberWithDouble:y2 ],
            nil];
    return result;
}

@end