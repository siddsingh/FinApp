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
// 2. "Fed Meeting" (Economic Event)
@dynamic type;

// Details related to the event, based on event type
// 1. "Quarterly Earnings" would have timing information "After Market Close",
// "Before Market Open, "During Market Trading", "Unknown".
//  2. Economic Event like "Fed Meeting" would contain the weblink to get more details.
@dynamic relatedDetails;

// Date related to the event.
// 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
// to be reported.
// Economic event like "Fed Meeting" would have the date of the event.
@dynamic relatedDate;

// For "Quarterly Earnings" end date of previously reported quarter for now. or fiscal year later.
@dynamic priorEndDate;

// For Quarterly Earnings, Indicator if this event is "Confirmed" or "Estimated" or "Unknown".
// For Economic events like "Fed Meeting" contains the string representing the period to which the event applies.
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

