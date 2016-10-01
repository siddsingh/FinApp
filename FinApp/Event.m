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
// For Estimated product events, date is a best guess early, mid or late in a month. Early would be 5th of the month. Middle would be 15th. Late would be 25th.
// For Price change events this is the date the event was logged
@dynamic date;

// The type of event
// 1. "Quarterly Earnings"
// 2. "Jan Fed Meeting", "Feb Fed Meeting" (Economic Event)
// 3. "iPhone 7 Launch" (Product Event)
// 4. "50.12% up today" "50.12% down today" "10.12% down 30 days" "30.12% down ytd" (Price Change events)
@dynamic type;

// Details related to the event, based on event type
// 1. "Quarterly Earnings" would have timing information "After Market Close",
// "Before Market Open, "During Market Trading", "Unknown".
//  2. Economic Event like "Fed Meeting" would contain the weblink to get more details.
// 3. Product Events like "iPhone 7 Launch" have timing information for the event.
// 4. Price change events don't have any details currently.
@dynamic relatedDetails;

// Date related to the event.
// 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
// to be reported.
// For Product Events, this field is currently being used to store the last updated date for the event
@dynamic relatedDate;

// For "Quarterly Earnings" end date of previously reported quarter for now. or fiscal year later.
@dynamic priorEndDate;

// For Quarterly Earnings, Indicator if this event is "Confirmed" or "Estimated" or "Unknown".
// For Economic events like "Fed Meeting" contains the string representing the period to which the event applies.
// For Product Events like "iPhone 7 Launch" the event is "Estimated" till it's "Confirmed"
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

