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

// The type of event
// 1. "Quarterly Earnings"
@property (nonatomic, retain) NSString * type;

// Details related to the event, based on event type
// 1. "Quarterly Earnings" would have timing information "After Market Close",
// "Before Market Open, "During Market Trading", "Unknown".
@property (nonatomic, retain) NSString * relatedDetails;

// Date related to the event.
// 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
// to be reported
@property (nonatomic, retain) NSDate * relatedDate;

// Indicator if this event is "Confirmed" or "Estimated" or "Unknown"
@property (nonatomic, retain) NSString * certainty;

// Company associated with this event
@property (nonatomic, retain) Company *listedCompany;

@end
