//
//  FASnapShot.m
//  FinApp
//
//  Class to store changing data like High Impact Events, Trending Events, News Sources and others. Also stores things like a company's brand colors. Implement this class as a Singleton to create a single data store accessible from anywhere in the app.
//
//  Created by Sidd Singh on 5/21/17.
//  Copyright © 2017 Sidd Singh. All rights reserved.
//

#import "FASnapShot.h"
#import "FADataController.h"
#import "EventHistory.h"
#import <UIKit/UIKit.h>

@implementation FASnapShot

static FASnapShot *sharedInstance;

// Implement this class as a Singleton to create a single data store accessible
// from anywhere in the app.
+ (void)initialize
{
    
    static BOOL exists = NO;
    
    // If a SnapShot doesn't already exist
    if(!exists)
    {
        exists = YES;
        sharedInstance= [[FASnapShot alloc] init];
    }
}

// Create and/or return the single Snapshot
+(FASnapShot *)sharedSnapShot {
    
    return sharedInstance;
}

// Returns if that event is a High Impact event or not given the raw event type and parent ticker. Examples of high impact events: 1) High impact product launches like iPhone 8, Naples Chip as these either validate my investment thesis or help form a new one. 2) High impact econ events that help shed light on how the market is likely to play out. e.g. Interest rates are likely to go up. Financials will do well. GDP is a big number stocks will likely do well.3) Big name companies earnings like FANG or Apple whose earnings can impact overall market.
- (BOOL)isEventHighImpact:(NSString *)eventType eventParent:(NSString *)parentTicker
{
    BOOL highImpact = NO;
    FADataController *impactController = [[FADataController alloc] init];
    
    // If the event type is earnings, return true for big name companies earnings like FANG or Apple whose earnings can impact overall market
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        
        // Cramer's FANG
        /*if ([parentTicker containsString:@"FB"]) {
            highImpact = YES;
        }*/
        if ([parentTicker containsString:@"AMZN"]) {
            highImpact = YES;
        }
        if ([parentTicker containsString:@"NFLX"]) {
            highImpact = YES;
        }
        /*if ([parentTicker containsString:@"GOOG"]) {
            highImpact = YES;
        }*/
        
        // From Knotifi top 10
        if ([parentTicker containsString:@"BAC"]) {
            highImpact = YES;
        }
        /*if ([parentTicker containsString:@"BABA"]) {
            highImpact = YES;
        }*/
        if ([parentTicker containsString:@"LULU"]) {
            highImpact = YES;
        }
        /*if ([parentTicker containsString:@"TSLA"]) {
            highImpact = YES;
        }*/
        if ([parentTicker containsString:@"NKE"]) {
            highImpact = YES;
        }
        /*if ([parentTicker containsString:@"MSFT"]) {
            highImpact = YES;
        }*/
        if ([parentTicker containsString:@"BAC"]) {
            highImpact = YES;
        }
        
        // Curated by Sidd
        if ([parentTicker containsString:@"AAPL"]) {
            highImpact = YES;
        }
        if ([parentTicker containsString:@"JPM"]) {
            highImpact = YES;
        }
        if ([parentTicker containsString:@"GS"]) {
            highImpact = YES;
        }
        if ([parentTicker containsString:@"NVDA"]) {
            highImpact = YES;
        }
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        // This is the event description
        //description = @"Very High Impact.Outcome determines key interest rates.";
        highImpact = YES;
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        // This is the event description
        //description = @"Very High Impact.Reflects the health of the job market.";
        highImpact = YES;
    }
    
    // If event type is Product, the impact is stored in the event history data store, so fetch it from there.
    if ([eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        
        // Get event history that stores the following string for product events in it's previous1Status field: Impact_Impact Description_MoreInfoTitle_MoreInfoUrl
        EventHistory *eventHistoryForImpact = [impactController getEventHistoryForParentEventTicker:parentTicker parentEventType:eventType];
        
        // Parse out to construct the Impact Text.
        NSArray *impactComponents = [eventHistoryForImpact.previous1Status componentsSeparatedByString:@"_"];
        NSString *description = [NSString stringWithFormat:@"%@ Impact.%@",impactComponents[0],impactComponents[1]];
        
        if ([description containsString:@"Very High Impact"]) {
            // This is the event description
            //description = @"Very High Impact.Outcome determines key interest rates.";
            highImpact = YES;
        }
    }
    
    return highImpact;
}

// Get the brand background color for given ticker
- (UIColor *)getBrandBkgrndColorForCompany:(NSString *)ticker {
    
    //Default Darkish whitish gray
    UIColor *colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    
    if ([ticker caseInsensitiveCompare:@"SNE"] == NSOrderedSame) {
        // black
        colorToReturn = [UIColor colorWithRed:23.0f/255.0f green:110.0f/255.0f blue:201.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"NVDA"] == NSOrderedSame) {
        // Greenish
        colorToReturn = [UIColor colorWithRed:118.0f/255.0f green:185.0f/255.0f blue:7.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"NFLX"] == NSOrderedSame) {
        // black
        colorToReturn = [UIColor blackColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"AAPL"] == NSOrderedSame) {
        // black
        colorToReturn = [UIColor blackColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"AMD"] == NSOrderedSame) {
        // Darkish Blackish Gray
        colorToReturn = [UIColor colorWithRed:71.0f/255.0f green:71.0f/255.0f blue:71.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"VIA"] == NSOrderedSame) {
        // Cloudy Blue
        colorToReturn = [UIColor colorWithRed:76.0f/255.0f green:181.0f/255.0f blue:233.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"NTDOY"] == NSOrderedSame) {
        // Reddish
        colorToReturn = [UIColor colorWithRed:232.0f/255.0f green:62.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"TSLA"] == NSOrderedSame) {
        // Reddish
        colorToReturn = [UIColor colorWithRed:183.0f/255.0f green:61.0f/255.0f blue:65.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"TWX"] == NSOrderedSame) {
        // Slightly dark whitish gray
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"NOK"] == NSOrderedSame) {
        // Darkish Blue
        colorToReturn = [UIColor colorWithRed:57.0f/255.0f green:96.0f/255.0f blue:171.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ATVI"] == NSOrderedSame) {
        // Dark Gray for the old activision blizzard logo
        colorToReturn = [UIColor colorWithRed:57.0f/255.0f green:57.0f/255.0f blue:57.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"EA"] == NSOrderedSame) {
        // Slightly dark whitish gray
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"FIT"] == NSOrderedSame) {
        // Tealish blue
        colorToReturn = [UIColor colorWithRed:81.0f/255.0f green:177.0f/255.0f blue:185.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"MSFT"] == NSOrderedSame) {
        // Cloud Blue
        colorToReturn = [UIColor colorWithRed:62.0f/255.0f green:165.0f/255.0f blue:240.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"AMZN"] == NSOrderedSame) {
        // Dark Blue almost black
        colorToReturn = [UIColor colorWithRed:35.0f/255.0f green:47.0f/255.0f blue:62.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"VZ"] == NSOrderedSame) {
        // Slightly dark whitish gray
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"T"] == NSOrderedSame) {
        // Cloudish Blue
        colorToReturn = [UIColor colorWithRed:62.0f/255.0f green:159.0f/255.0f blue:220.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"GOOGL"] == NSOrderedSame) {
        // Google green
        colorToReturn = [UIColor colorWithRed:81.0f/255.0f green:160.0f/255.0f blue:72.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"NKE"] == NSOrderedSame) {
        // Orangish
        //colorToReturn = [UIColor colorWithRed:236.0f/255.0f green:123.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        // Neon Yellow
        colorToReturn = [UIColor colorWithRed:193.0f/255.0f green:244.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"SNAP"] == NSOrderedSame) {
        // Snapchat Yellow
        colorToReturn = [UIColor colorWithRed:254.0f/255.0f green:247.0f/255.0f blue:49.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"FB"] == NSOrderedSame) {
        // Facebook Blue
        colorToReturn = [UIColor colorWithRed:59.0f/255.0f green:89.0f/255.0f blue:152.0f/255.0f alpha:1.0f];
    }
    
    return colorToReturn;
}

// Get the brand text color for given ticker
- (UIColor *)getBrandTextColorForCompany:(NSString *)ticker {
    
    //Default black color
    UIColor *colorToReturn = [UIColor blackColor];
    
    if ([ticker caseInsensitiveCompare:@"SNE"] == NSOrderedSame) {
        // white
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"NVDA"] == NSOrderedSame) {
        // white
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"NFLX"] == NSOrderedSame) {
        // red
        colorToReturn = [UIColor redColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"AAPL"] == NSOrderedSame) {
        // white
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"AMD"] == NSOrderedSame) {
        // Orangish Red
        colorToReturn = [UIColor colorWithRed:235.0f/255.0f green:85.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"VIA"] == NSOrderedSame) {
        // White color
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"NTDOY"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"TSLA"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"TWX"] == NSOrderedSame) {
        // Darkish blue
        colorToReturn = [UIColor colorWithRed:18.0f/255.0f green:78.0f/255.0f blue:136.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"NOK"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"ATVI"] == NSOrderedSame) {
        // Cloud blue for the old activision blizzard logo
        colorToReturn = [UIColor colorWithRed:39.0f/255.0f green:143.0f/255.0f blue:251.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"EA"] == NSOrderedSame) {
        // Darkish blue
        colorToReturn = [UIColor colorWithRed:203.0f/255.0f green:53.0f/255.0f blue:43.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"FIT"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"MSFT"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"AMZN"] == NSOrderedSame) {
        // Yellow
        colorToReturn = [UIColor colorWithRed:241.0f/255.0f green:152.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"VZ"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor redColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"T"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"GOOGL"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"NKE"] == NSOrderedSame) {
        // Black
        colorToReturn = [UIColor blackColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"SNAP"] == NSOrderedSame) {
        // Black
        colorToReturn = [UIColor blackColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"FB"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    return colorToReturn;
}


@end
