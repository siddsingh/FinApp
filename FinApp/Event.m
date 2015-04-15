//
//  Event.m
//  FinApp
//
//  Class represents Event object in the core data model.
//
//  Created by Sidd Singh on 2/18/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "Event.h"


@implementation Event

// Date on which the event takes place
@dynamic date;

// The type of event
// 1. "Quarterly Earnings"
@dynamic type;

// Details related to the event, based on event type
// 1. "Quarterly Earnings" would have timing information "After Market Close",
// "Before Market Open, "During Market Trading", "Unknown".
@dynamic relatedDetails;

// Date related to the event.
// 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
// to be reported
@dynamic relatedDate;

// Indicator if this event is "confirmed" or "speculated" or "unknown"
@dynamic certainty;

// Company associated with this event
@dynamic listedCompany;

@end
