//
//  Company.h
//  FinApp
//
//  Class represents Company object in the core data model.
//
//  Created by Sidd Singh on 2/18/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Event;

@interface Company : NSManagedObject


// Name of the company.
// For economic events this is the name of agency that puts out the event.
@property (nonatomic, retain) NSString * name;

// Ticker for the company
// For economic events it follows the format ECONOMY_<agency abbreviation> e.g. ECONOMY_FOMC.
@property (nonatomic, retain) NSString * ticker;

// Set of events associated with the company
@property (nonatomic, retain) NSSet *events;

@end

@interface Company (CoreDataGeneratedAccessors)

- (void)addEventsObject:(Event *)value;
- (void)removeEventsObject:(Event *)value;
- (void)addEvents:(NSSet *)values;
- (void)removeEvents:(NSSet *)values;

@end
