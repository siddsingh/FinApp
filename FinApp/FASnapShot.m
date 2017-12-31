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
        colorToReturn = [UIColor blackColor];
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
        // Black bkgrnd for COD WW 2
        colorToReturn = [UIColor blackColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"EA"] == NSOrderedSame) {
        // Slightly dark whitish gray
        //colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
        // Dark Greenish almost black for Star Wars
        colorToReturn = [UIColor colorWithRed:4.0f/255.0f green:16.0f/255.0f blue:5.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"FIT"] == NSOrderedSame) {
        // Tealish blue
        colorToReturn = [UIColor colorWithRed:81.0f/255.0f green:177.0f/255.0f blue:185.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"MSFT"] == NSOrderedSame) {
        // Cloud Blue
        colorToReturn = [UIColor colorWithRed:34.0f/255.0f green:125.0f/255.0f blue:251.0f/255.0f alpha:1.0f];
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
        colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:63.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
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
    
    if ([ticker caseInsensitiveCompare:@"BTC"] == NSOrderedSame) {
        // Copper Penny
        //colorToReturn = [UIColor colorWithRed:192.0f/255.0f green:134.0f/255.0f blue:114.0f/255.0f alpha:1.0f];
        // Orangish
        colorToReturn = [UIColor colorWithRed:239.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ETHR"] == NSOrderedSame) {
        // Brownish Yellow
        //colorToReturn = [UIColor colorWithRed:200.0f/255.0f green:157.0f/255.0f blue:102.0f/255.0f alpha:1.0f];
        // Grayish Purple
        colorToReturn = [UIColor colorWithRed:111.0f/255.0f green:124.0f/255.0f blue:186.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BCH$"] == NSOrderedSame) {
        // Dark Greenish
        colorToReturn = [UIColor colorWithRed:81.0f/255.0f green:157.0f/255.0f blue:11.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"DIS"] == NSOrderedSame) {
        // Dark Puplish Blue
        colorToReturn = [UIColor colorWithRed:3.0f/255.0f green:40.0f/255.0f blue:148.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"INTC"] == NSOrderedSame) {
        // Grayish
        colorToReturn = [UIColor colorWithRed:82.0f/255.0f green:82.0f/255.0f blue:82.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"QCOM"] == NSOrderedSame) {
        // Dark Gray for SnapDragon
        colorToReturn = [UIColor colorWithRed:67.0f/255.0f green:68.0f/255.0f blue:68.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ECON"] == NSOrderedSame) {
        // Dark purple for econ
        colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:39.0f/255.0f blue:72.0f/255.0f alpha:1.0f];
    }
    
    // From details view ticker has the econ agency initials appended (e.g. ECONOMY_BEA) so return the color for those as well
    if (([ticker caseInsensitiveCompare:@"ECONOMY_BLS"] == NSOrderedSame)||([ticker caseInsensitiveCompare:@"ECONOMY_BEA"] == NSOrderedSame)||([ticker caseInsensitiveCompare:@"ECONOMY_TCB"] == NSOrderedSame)||([ticker caseInsensitiveCompare:@"ECONOMY_FOMC"] == NSOrderedSame)) {
        // Dark purple for econ
        colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:39.0f/255.0f blue:72.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"JPM"] == NSOrderedSame) {
        // Dark Ink Blue for Chase card
        colorToReturn = [UIColor colorWithRed:7.0f/255.0f green:25.0f/255.0f blue:48.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BAC"] == NSOrderedSame) {
        // Red from icon
        colorToReturn = [UIColor colorWithRed:197.0f/255.0f green:52.0f/255.0f blue:48.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BABA"] == NSOrderedSame) {
        // Dark Orange
        colorToReturn = [UIColor colorWithRed:202.0f/255.0f green:90.0f/255.0f blue:44.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"CMCSA"] == NSOrderedSame) {
        // DArk Tealish
        colorToReturn = [UIColor colorWithRed:13.0f/255.0f green:49.0f/255.0f blue:74.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"UA"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:14.0f/255.0f green:42.0f/255.0f blue:101.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"WFC"] == NSOrderedSame) {

        colorToReturn = [UIColor colorWithRed:188.0f/255.0f green:49.0f/255.0f blue:39.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"C"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:46.0f/255.0f green:135.0f/255.0f blue:208.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"TEAM"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:0.0f/255.0f green:82.0f/255.0f blue:204.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"GPRO"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:32.0f/255.0f green:32.0f/255.0f blue:32.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"GM"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:48.0f/255.0f green:67.0f/255.0f blue:118.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"TWTR"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:47.0f/255.0f green:135.0f/255.0f blue:202.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ANET"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:0.0f/255.0f green:40.0f/255.0f blue:89.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"SQ"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:94.0f/255.0f green:183.0f/255.0f blue:56.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"GRMN"] == NSOrderedSame) {
        // Default Grey
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"OKTA"] == NSOrderedSame) {
        // Default Grey
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"HSBC"] == NSOrderedSame) {
        // Default Grey
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BOX"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:1.0f/255.0f green:97.0f/255.0f blue:213.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ORCL"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:63.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"LULU"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:211.0f/255.0f green:56.0f/255.0f blue:48.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"TWLO"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:39.0f/255.0f green:63.0f/255.0f blue:91.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"CRM"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:172.0f/255.0f green:208.0f/255.0f blue:218.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"SBUX"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:55.0f/255.0f green:114.0f/255.0f blue:67.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"MU"] == NSOrderedSame) {
        // Default Grey
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"COUP"] == NSOrderedSame) {
        // Default Grey
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"V"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:24.0f/255.0f green:33.0f/255.0f blue:104.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"CSCO"] == NSOrderedSame) {
        // Default Grey
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"WMT"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:36.0f/255.0f green:121.0f/255.0f blue:201.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ADBE"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:63.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"CMG"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:69.0f/255.0f green:22.0f/255.0f blue:8.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"AMAT"] == NSOrderedSame) {
        // Default Grey
        colorToReturn = [UIColor colorWithRed:177.0f/255.0f green:177.0f/255.0f blue:177.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BIDU"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:45.0f/255.0f green:64.0f/255.0f blue:220.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"HD"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:236.0f/255.0f green:97.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"AAOI"] == NSOrderedSame) {
        // Black
        colorToReturn = [UIColor blackColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"ETFC"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:85.0f/255.0f green:61.0f/255.0f blue:136.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"AXP"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:48.0f/255.0f green:136.0f/255.0f blue:203.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BB"] == NSOrderedSame) {
        //
        colorToReturn = [UIColor colorWithRed:12.0f/255.0f green:16.0f/255.0f blue:75.0f/255.0f alpha:1.0f];
    }
    
    return colorToReturn;
}

// Get the brand text color for given ticker
- (UIColor *)getBrandTextColorForCompany:(NSString *)ticker {
    
    //Default black color
    UIColor *colorToReturn = [UIColor blackColor];
    
    if ([ticker caseInsensitiveCompare:@"SNE"] == NSOrderedSame) {
        // Bluish light for PS4 controller light
        colorToReturn = [UIColor colorWithRed:17.0f/255.0f green:104.0f/255.0f blue:232.0f/255.0f alpha:1.0f];
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
        // Gold Yellow for COD WW2
        colorToReturn = [UIColor colorWithRed:155.0f/255.0f green:141.0f/255.0f blue:41.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"EA"] == NSOrderedSame) {
        // Darkish blue
        //colorToReturn = [UIColor colorWithRed:203.0f/255.0f green:53.0f/255.0f blue:43.0f/255.0f alpha:1.0f];
        // Neon greenish for light saber from Star wars
        colorToReturn = [UIColor colorWithRed:102.0f/255.0f green:198.0f/255.0f blue:86.0f/255.0f alpha:1.0f];
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
    
    if ([ticker caseInsensitiveCompare:@"BTC"] == NSOrderedSame) {
        // Dark Brown for Copper Penny bkgrnd
        //colorToReturn = [UIColor colorWithRed:88.0f/255.0f green:47.0f/255.0f blue:26.0f/255.0f alpha:1.0f];
        // White for orangish bkgrnd
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"ETHR"] == NSOrderedSame) {
         // White for brownish Yellow Bkgrnd
        //colorToReturn = [UIColor whiteColor];
        // White for grayish lilac bkgrnd
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"BCH$"] == NSOrderedSame) {
        // White for brownish Yellow Bkgrnd
        //colorToReturn = [UIColor whiteColor];
        // White for greenish bkgrnd
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"DIS"] == NSOrderedSame) {
        // Whitw
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"INTC"] == NSOrderedSame) {
        // Neonish Blue for Nervana Processor
        colorToReturn = [UIColor colorWithRed:101.0f/255.0f green:217.0f/255.0f blue:217.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"QCOM"] == NSOrderedSame) {
        // Red for SnapDragon
        colorToReturn = [UIColor colorWithRed:235.0f/255.0f green:65.0f/255.0f blue:68.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ECON"] == NSOrderedSame) {
        // White for Econ
        colorToReturn = [UIColor whiteColor];
    }
    
    // From details view ticker has the econ agency initials appended (e.g. ECONOMY_BEA) so return the color for those as well
    if (([ticker caseInsensitiveCompare:@"ECONOMY_BLS"] == NSOrderedSame)||([ticker caseInsensitiveCompare:@"ECONOMY_BEA"] == NSOrderedSame)||([ticker caseInsensitiveCompare:@"ECONOMY_TCB"] == NSOrderedSame)||([ticker caseInsensitiveCompare:@"ECONOMY_FOMC"] == NSOrderedSame)) {
        // White for Econ
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"JPM"] == NSOrderedSame) {
        // Neon Blue for Chase card
        colorToReturn = [UIColor colorWithRed:83.0f/255.0f green:177.0f/255.0f blue:187.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BAC"] == NSOrderedSame) {
        // Blue from icon
        colorToReturn = [UIColor colorWithRed:152.0f/255.0f green:192.0f/255.0f blue:233.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BABA"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"CMCSA"] == NSOrderedSame) {
        // White
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"UA"] == NSOrderedSame) {
        // Bright yellow for Curry One
        colorToReturn = [UIColor colorWithRed:216.0f/255.0f green:173.0f/255.0f blue:47.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"WFC"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:248.0f/255.0f green:198.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"C"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"TEAM"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"GPRO"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:69.0f/255.0f green:174.0f/255.0f blue:238.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"GM"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor colorWithRed:171.0f/255.0f green:191.0f/255.0f blue:215.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"TWTR"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"ANET"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"SQ"] == NSOrderedSame) {
        // Blue for Curry One
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"GRMN"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:26.0f/255.0f green:114.0f/255.0f blue:205.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"OKTA"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:42.0f/255.0f green:125.0f/255.0f blue:193.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"HSBC"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:221.0f/255.0f green:59.0f/255.0f blue:48.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BOX"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"ORCL"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"LULU"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"TWLO"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"CRM"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:53.0f/255.0f green:144.0f/255.0f blue:209.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"SBUX"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"MU"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:34.0f/255.0f green:119.0f/255.0f blue:200.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"COUP"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:62.0f/255.0f green:159.0f/255.0f blue:223.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"V"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:245.0f/255.0f green:180.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"CSCO"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:34.0f/255.0f green:119.0f/255.0f blue:200.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"WMT"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:252.0f/255.0f green:221.0f/255.0f blue:89.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ADBE"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"CMG"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"AMAT"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:76.0f/255.0f green:156.0f/255.0f blue:190.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"BIDU"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"HD"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"AAOI"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:144.0f/255.0f green:111.0f/255.0f blue:222.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"ETFC"] == NSOrderedSame) {
        
        colorToReturn = [UIColor colorWithRed:163.0f/255.0f green:208.0f/255.0f blue:36.0f/255.0f alpha:1.0f];
    }
    
    if ([ticker caseInsensitiveCompare:@"AXP"] == NSOrderedSame) {
        
        colorToReturn = [UIColor whiteColor];
    }
    
    if ([ticker caseInsensitiveCompare:@"BB"] == NSOrderedSame) {
        //
        colorToReturn = [UIColor colorWithRed:132.0f/255.0f green:166.0f/255.0f blue:220.0f/255.0f alpha:1.0f];
    }
    
    return colorToReturn;
}


@end
