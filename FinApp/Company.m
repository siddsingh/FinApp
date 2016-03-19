//
//  Company.m
//  FinApp
//
//  Class represents Company object in the core data model.
//
//  Created by Sidd Singh on 2/18/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "Company.h"
#import "Event.h"


@implementation Company

// Name of the company.
// For economic events this is the name of agency that puts out the event
@dynamic name;

// Ticker for the company
// For economic events it follows the format ECONOMY_<agency abbreviation> e.g. ECONOMY_FOMC.
@dynamic ticker;

// Set of events associated with the company
@dynamic events;

@end
