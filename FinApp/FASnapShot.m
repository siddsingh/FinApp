//
//  FASnapShot.m
//  FinApp
//
//  Class to store changing data like High Impact Eevents, Trending Events, News Sources and others. Implement this class as a Singleton to create a single data store accessible from anywhere in the app.
//
//  Created by Sidd Singh on 5/21/17.
//  Copyright © 2017 Sidd Singh. All rights reserved.
//

#import "FASnapShot.h"
#import "FADataController.h"
#import "EventHistory.h"

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
        
        if ([description containsString:@"Very High Impact"]||[description containsString:@"High Impact"]) {
            // This is the event description
            //description = @"Very High Impact.Outcome determines key interest rates.";
            highImpact = YES;
        }
    }
    
    return highImpact;
}


@end
