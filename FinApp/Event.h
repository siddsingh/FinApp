//
//  Event.h
//  FinApp
//
//  Class represents Event object in the core data model.
//
//  Created by Sidd Singh on 2/18/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
@class Company;


@interface Event : NSManagedObject

// Date on which the event takes place
@property (nonatomic, retain) NSDate * date;

// Detailed description of the event e.g. "Q4 earnings call"
@property (nonatomic, retain) NSString * details;

// The type of event e.g. "Quarterly Earnings Call"
@property (nonatomic, retain) NSString * type;

// Indicator if this event is "confirmed" or "speculated"
@property (nonatomic, retain) NSString * certainty;

// Company associated with this event
@property (nonatomic, retain) Company *listedCompany;

@end
