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
#import "Action.h"
#import "Company.h"

// Note: Currently, the listed company ticker and event type, together represent the event uniquely.
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

// End date of previously reported quarter for now. or fiscal year later.
@dynamic priorEndDate;

// Indicator if this event is "Confirmed" or "Estimated" or "Unknown"
@dynamic certainty;

// Estimated EPS for the upcoming event
@dynamic estimatedEps;

// Actual EPS for the previously reported quarter for now. or fiscal year later.
@dynamic actualEpsPrior;

// Actions associated with the event
@dynamic actions;

// Company associated with this event
@dynamic listedCompany;

// Event history related to this event
@dynamic relatedEventHistory;

@end

