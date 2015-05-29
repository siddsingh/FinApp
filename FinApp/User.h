//
//  User.h
//  FinApp
//
//  Class represents User object in the core data model.
//
//  Created by Sidd Singh on 5/1/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface User : NSManagedObject

// Represents the company data sync status for this user
// "SeedSyncDone" means the most basic set of company information has been added to
// the company data store.
// "NoSyncPerformed" means no company information has been added to the company data store.
// "FullSyncDone" means the full set of company information has been added to
// the company data store.
@property (nonatomic, retain) NSString * companySyncStatus;

// Date when the last company data sync was performed
@property (nonatomic, retain) NSDate * companySyncDate;

// Represents the event data sync status for this user
// "SeedSyncDone" means the most basic set of events information has been added to
// the event data store.
// "NoSyncPerformed" means no event information has been added to the event data store.
@property (nonatomic, retain) NSString * eventSyncStatus;

// Date when the last event data sync was performed
@property (nonatomic, retain) NSDate * eventSyncDate;

@end