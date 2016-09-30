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
// For Estimated product events, date is a best guess early, mid or late in a month. Early would be 5th of the month. Middle would be 15th. Late would be 25th.
// For Price change events this is the date the event was logged
@property (nonatomic, retain) NSDate * date;

// The type of event
// 1. "Quarterly Earnings"
// 2. "Jan Fed Meeting", "Feb Fed Meeting" (Economic Event)
// 3. "iPhone 7 Launch" (Product Event)
// 4. "+ 5.12% today" "- 5.12% today" "+ 10.12% past 30 days" "+ 30.12% year to date" (Price Change events)
@property (nonatomic, retain) NSString * type;

// Details related to the event, based on event type
// 1. "Quarterly Earnings" would have timing information "After Market Close",
// "Before Market Open, "During Market Trading", "Unknown".
//  2. Economic Event like "Jan Fed Meeting" would contain the weblink to get more details.
// 3. Product Events like "iPhone 7 Launch" have timing information for the event.
// 4. Price change events don't have any details currently.
@property (nonatomic, retain) NSString * relatedDetails;

// Date related to the event.
// 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
// to be reported.
// For Product Events, this field is currently being used to store the last updated date for the event
@property (nonatomic, retain) NSDate * relatedDate;

// For "Quarterly Earnings" end date of previously reported quarter for now. or fiscal year later.
@property (nonatomic, retain) NSDate * priorEndDate;

// For Quarterly Earnings, Indicator if this event is "Confirmed" or "Estimated" or "Unknown".
// For Economic events like "Fed Meeting" contains the string representing the period to which the event applies.
// For Product Events like "iPhone 7 Launch" the event is "Estimated" till it's "Confirmed"
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
