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
@class Action, Company;

// Note: Currently, the listed company ticker and event type, together represent the event uniquely.
@interface Event : NSManagedObject

// Date on which the event takes place
@property (nonatomic, retain) NSDate * date;

// The type of event
// 1. "Quarterly Earnings"
// 2. "Fed Meeting" (Economic Event)
@property (nonatomic, retain) NSString * type;

// Details related to the event, based on event type
// 1. "Quarterly Earnings" would have timing information "After Market Close",
// "Before Market Open, "During Market Trading", "Unknown".
//  2. Economic Event like "Fed Meeting" would contain the weblink to get more details.
@property (nonatomic, retain) NSString * relatedDetails;

// Date related to the event.
// 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
// to be reported.
// Economic event like "Fed Meeting" would have the date of the event.
@property (nonatomic, retain) NSDate * relatedDate;

// For "Quarterly Earnings" end date of previously reported quarter for now. or fiscal year later.
@property (nonatomic, retain) NSDate * priorEndDate;

// For Quarterly Earnings, Indicator if this event is "Confirmed" or "Estimated" or "Unknown".
// For Economic events like "Fed Meeting" contains the string representing the period to which the event applies.
@property (nonatomic, retain) NSString * certainty;

// Estimated EPS for the upcoming event
@property (nonatomic, retain) NSNumber * estimatedEps;

// Actual EPS for the previously reported quarter for now. or fiscal year later
@property (nonatomic, retain) NSNumber * actualEpsPrior;

// Actions associated with the event
@property (nonatomic, retain) NSSet *actions;

// Company associated with this event
@property (nonatomic, retain) Company *listedCompany;

// Event history related to this event
@property (nonatomic, retain) NSManagedObject *relatedEventHistory;

@end

@interface Event (CoreDataGeneratedAccessors)

- (void)addActionsObject:(Action *)value;
- (void)removeActionsObject:(Action *)value;
- (void)addActions:(NSSet *)values;
- (void)removeActions:(NSSet *)values;

@end
