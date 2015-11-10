//
//  EventHistory.h
//  FinApp
//
//  Created by Sidd Singh on 10/13/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Event;

@interface EventHistory : NSManagedObject

// Date for the previous event of the same type as the parent event.
@property (nonatomic, retain) NSDate * previous1Date;

// Indicator if this previous event 1 is "Estimated" based on an algorithm or "Confirmed"
// to be on the day it actually happened. Idea is as the user uses this app, we confirm these events.
@property (nonatomic, retain) NSString * previous1Status;

// Date related to the previous event.
// 1. "Quarterly Earnings" would have the end date of the previous fiscal quarter
// that was reported.
// NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
@property (nonatomic, retain) NSDate * previous1RelatedDate;

// Date which is considered to be the current date.
@property (nonatomic, retain) NSDate * currentDate;

// Stock price on the previous event 1 date.
// NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
@property (nonatomic, retain) NSNumber * previous1Price;

// Stock price on previous 1 related event date.
@property (nonatomic, retain) NSNumber * previous1RelatedPrice;

// Current stock price which right now is yesterday's price
@property (nonatomic, retain) NSNumber * currentPrice;

// Parent event for which this is the history.
@property (nonatomic, retain) Event *parentEvent;

@end