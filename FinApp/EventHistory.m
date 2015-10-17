//
//  EventHistory.m
//  FinApp
//
//  Created by Sidd Singh on 10/13/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "EventHistory.h"
#import "Event.h"

@implementation EventHistory

// Date for the previous event of the same type as the parent event.
@dynamic previous1Date;

// Indicator if this previous event 1 is "Estimated" based on an algorithm or "Confirmed"
// to be on the day it actually happened. Idea is as the user uses this app, we confirm these events.
@dynamic previous1Status;

// Date related to the previous event.
// 1. "Quarterly Earnings" would have the end date of the previous fiscal quarter
// that was reported.
@dynamic previous1RelatedDate;

// Stock price on the previous event 1 date.
// NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
@dynamic previous1Price;

// Stock price on previous 1 related event date.
// NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
@dynamic previous1RelatedPrice;

// Current stock price which right now is yesterday's price
@dynamic currentPrice;

// Parent event for which this is the history.
@dynamic parentEvent;

@end
