//
//  AppDelegate.m
//  FinApp
//
//  Created by Sidd Singh on 10/8/14.
//  Copyright (c) 2014 Sidd Singh. All rights reserved.
//

#import "AppDelegate.h"
#import "FADataController.h"
#import "Reachability.h"

@interface AppDelegate ()

// Refresh events that are likely to be updated, from API. Typically called in a background thread.
- (void)refreshEventsIfNeededFromApiInBackground;

// Redo fetching of company data from the API, in case the full sync of company data had failed. Typically called in a background thread.
- (void)refreshCompanyInfoIfNeededFromApiInBackground;

// Send a notification that the list of messages has changed (updated)
- (void)sendEventsChangeNotification;

// Send a notification that the list of events has changed (updated)
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents;

// Check if there is internet connectivity
- (BOOL) checkForInternetConnectivity;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Override point for customization after application launch.
    
    // Set the status bar text color to white. This is done in conjunction with setting View controller-based status bar appearance property to NO in Info.plist. To revert delete that property and remove this line.
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     NSLog(@"******************************************App Entered Background Fired****************************************");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    // Check for connectivity. If yes, sync data from remote data source
    if ([self checkForInternetConnectivity]) {
        
        // If this hasn't already been done, seed the events data, the very first time, to get the user started.
        FADataController *eventSeedSyncController = [[FADataController alloc] init];
        if ([[eventSeedSyncController getEventSyncStatus] isEqualToString:@"NoSyncPerformed"]) {
            [eventSeedSyncController performEventSeedSyncRemotely];
            [self sendEventsChangeNotification];
        }
        // If seed sync has already been done, check and refresh any events from the API that are likely to have updated information
        else {
            [self performSelectorInBackground:@selector(refreshEventsIfNeededFromApiInBackground) withObject:nil];
        }
        
        // If the full sync of company data has failed, retry it
        [self performSelectorInBackground:@selector(refreshCompanyInfoIfNeededFromApiInBackground) withObject:nil];
    }
    // If not, show error message
    else {
        
        [self sendUserMessageCreatedNotificationWithMessage:@"Hmm! Unable to get data. Check Connection and retry."];
    }
    
    NSLog(@"******************************************Active State Fired****************************************");
}

- (void)applicationWillTerminate:(UIApplication *)application {
    
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    // [self saveContext];
    
    NSLog(@"APPLICATION WILL TERMINATE FIRED");
    
    // Create a new generic Data Controller
    FADataController *genericDataController = [[FADataController alloc] init];
    
    // Check to see if all the company data has been synced before terminating. This is done by checking if 25 pages of information
    // have been processed.
    // TO DO: Currently this is hardcoded to 25 as 25 pages worth of companies (7375 companies at 300 per page) were available as of July 15, 2105. When you change this, change the hard coded value in getAllCompaniesFromApi in FADataController.
    if ([[genericDataController getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&[[genericDataController getCompanySyncedUptoPage] integerValue] < 25)
    {
        [genericDataController upsertUserWithCompanySyncStatus:@"FullSyncAttemptedButFailed" syncedPageNo:[genericDataController getCompanySyncedUptoPage]];
    }
    NSLog(@"**************Company Sync Status is:%@ and synced page is:%ld",[genericDataController getCompanySyncStatus],[[genericDataController getCompanySyncedUptoPage] longValue]);
    NSLog(@"******************************************App Termination Fired****************************************");
}

#pragma mark - State Refresh

// Refresh events that are likely to be updated, from API. Typically called in a background thread.
- (void)refreshEventsIfNeededFromApiInBackground
{
    // Create a new FADataController so that this thread has its own MOC
    FADataController *eventDataController = [[FADataController alloc] init];
    
    [eventDataController updateEventsFromRemoteIfNeeded];
}

// Redo fetching of company data from the API, in case the full sync of company data had failed or not started. Typically called in a background thread.
- (void)refreshCompanyInfoIfNeededFromApiInBackground
{
    // Create a new FADataController so that this thread has its own MOC
    FADataController *companyDataController = [[FADataController alloc] init];
    
    NSLog(@"******************************************About to Processed the Get All Companies from API in the background since last sync was incomplete**************************************** with Company sync status:%@",[companyDataController getCompanySyncStatus]);
    
    if ([[companyDataController getCompanySyncStatus] isEqualToString:@"SeedSyncDone"]||[[companyDataController getCompanySyncStatus] isEqualToString:@"FullSyncAttemptedButFailed"]) {
        [companyDataController getAllCompaniesFromApi];
         NSLog(@"******************************************Processed the Get All Companies from API in the background since last sync was incomplete****************************************");
    }
}

#pragma mark - Notifications

// Send a notification that the list of events has changed (updated)
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"UserMessageCreated" object:msgContents];
    NSLog(@"NOTIFICATION FIRED: With User Message: %@",msgContents);
}

#pragma mark - Connectivity Methods

// Check if there is internet connectivity
- (BOOL) checkForInternetConnectivity {
    
    // Get internet access status
    Reachability *internetReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus internetStatus = [internetReachability currentReachabilityStatus];
    
    // If there is no internet access
    if (internetStatus == NotReachable) {
        return NO;
    }
    // If there is internet access
    else {
        return YES;
    }
}

#pragma mark - Notifications

// Send a notification that the list of events has changed (updated)
- (void)sendEventsChangeNotification {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
}


#pragma mark - Core Data stack

/* Not needed since our achitecture uses a Data Controller and Data Store to manage core data storage and retrieval. These mehtods are implemented in there.
 
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.siddsingh.FinApp" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"FinApp" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    // Create the coordinator and store
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"FinApp.sqlite"];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
} */

@end
