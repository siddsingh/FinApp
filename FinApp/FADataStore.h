//
//  FADataStore.h
//  FinApp
//
//  Class that sets up a single data store. Each thread should have it's own
//  FADataController that creates a new managed object context that talks to a
//  single persistent store coordinator in this single persistent store.
//
//  Created by Sidd Singh on 2/25/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface FADataStore : NSObject

// Create and/or return the single shared data store
+ (FADataStore *) sharedStore;

// Core Data Store object model
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;

// Store Coordinator for Core Data Store
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory;

@end
