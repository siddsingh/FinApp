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

// Detailed description of the event e.g. "Q4 earnings call"
@dynamic details;

// The type of event e.g. "Quarterly Earnings Call"
@dynamic type;

// Indicator if this event is "confirmed" or "speculated"
@dynamic certainty;

// Company associated with this event
@dynamic listedCompany;

@end
