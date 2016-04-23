//
//  FADataStore.m
//  FinApp
//
//  Class that sets up a single data store. Each thread should have it's own
//  FADataController that creates a new managed object context that talks to a
//  single persistent store coordinator in this single persistent store.
//
//  Created by Sidd Singh on 2/25/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "FADataStore.h"

@implementation FADataStore

static FADataStore *sharedInstance;

// Implement this class as a Singleton to create a single data store accessible
// from anywhere in the app.
+ (void)initialize
{
    
    static BOOL exists = NO;
    
    // If a data store doesn't already exist
    if(!exists)
    {
        exists = YES;
        sharedInstance= [[FADataStore alloc] init];
    }
}

// Create and/or return the single shared data store
+(FADataStore *)sharedStore {
    
    return sharedInstance;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"FinApp" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"FinApp.sqlite"];
    
    // TO DO: COMMENT FOR PRE SEEDING DB: When preseeding we don't want to use the existing db. We want a new one created.
    // Check to see if a sqlite db already exists. If not, find the path to the preloaded DB and use that.
    // Post ios7 you need to add the code for copying the sqlite-wal and sqlite-shm files as well if you decide to generate the preseeded file with wal journalling on. Currently we switch that off while generating the preseeded db.
    if (![[NSFileManager defaultManager] fileExistsAtPath:[storeURL path]]) {
        // Copy the .sqlite file
        NSURL *preloadURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"FinApp" ofType:@"sqlite"]];
        NSError* err = nil;
        if (![[NSFileManager defaultManager] copyItemAtURL:preloadURL toURL:storeURL error:&err]) {
            NSLog(@"ERROR: Could not copy the Preloaded SQL Database .sqlite file for use because:%@",err.description);
        }
    }
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    // TO DO: UNCOMMENT FOR PRE SEEDING DB: Setting WAL off for SQLite so that we don't have to worry about copying the WAL and SHM files. note: you need to set the options in the next instruction from nil to walOffOptions.
    //NSDictionary *walOffOptions = @{ NSSQLitePragmasOption : @{@"journal_mode" : @"DELETE"} };
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    // TO DO: UNCOMMENT FOR PRE SEEDING DB: We want to know the path where the files are generated
    //NSLog(@"SQLite Database Location: %@",[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory  inDomains:NSUserDomainMask] lastObject]);
    
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}


@end
