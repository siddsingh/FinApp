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
// "FullSyncDone" means the full set of company information has been added to
// the company data store.
@dynamic companySyncStatus;

// Date when the last company data sync was performed
@dynamic companySyncDate;

@end
