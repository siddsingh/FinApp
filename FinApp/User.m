//
//  User.m
//  FinApp
//
//  Class represents User object in the core data model.
//
//  Created by Sidd Singh on 5/1/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "User.h"


@implementation User

// Represents the company data sync status for this user
// "SeedSyncDone" means the most basic set of company information has been added to
// the company data store.
// "NoSyncPerformed" means no company information has been added to the company data store.
// "FullSyncDone" means the full set of company information has been added to
// the company data store.
// "FullSyncStarted" means a full company sync was started. The company page number gives the
// the last page of company information that was properly synced.
// "FullSyncAttemptedButFailed" means a full company sync was attempted but failed before it
// could complete
@dynamic companySyncStatus;

// Date when the last company data sync was performed
@dynamic companySyncDate;

// Page number to which the company data sync was completed, ranges from
// 0 to total no of pages in the company data API response
@dynamic companyPageNumber;

// Total number of pages of company data that needs to be synced from the company data API.
@dynamic companyTotalPages;

// Represents the event data sync status for this user
// "SeedSyncDone" means the most basic set of events information has been added to
// the event data store.
// "NoSyncPerformed" means no event information has been added to the event data store.
// "RefreshCheckDone" means a check to see if refreshed events data is available is done.
@dynamic eventSyncStatus;

// Date when the last event data sync was performed
@dynamic eventSyncDate;

@end
