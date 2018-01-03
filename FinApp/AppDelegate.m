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
#import <FBSDKCoreKit/FBSDKCoreKit.h>

@interface AppDelegate ()

// Refresh events that are likely to be updated, from API. Typically called in a background thread.
- (void)refreshEventsIfNeededFromApiInBackgroundWithDataController:(FADataController *)existingDC;

// Redo fetching of company data from the API, in case the full sync of company data had failed. Typically called in a background thread.
- (void)refreshCompanyInfoIfNeededFromApiInBackground;

// Kick off a background task to add any new companies that might have been added.
- (void)doCompanyUpdateInBackground;

// Send a notification that the list of messages has changed (updated)
- (void)sendEventsChangeNotification;

// Check if there is internet connectivity
- (BOOL) checkForInternetConnectivity;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Override point for customization after application launch.
    
    // Remove the 1 pixel bottom border line from navigation Controller top bar.
    [[UINavigationBar appearance] setBackgroundImage:[UIImage new] forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[UIImage new]];
    
    // TRACKING EVENT: SETUP: Adding the FB SDK
    // TO DO: Disabling to not track development events. Enable before shipping.
    [[FBSDKApplicationDelegate sharedInstance] application:application
                             didFinishLaunchingWithOptions:launchOptions];

     
    // Check to see if application version 4.2 has been used by the user at least once. If not show tutorial and do the data updates. The format for key represents app store version 4_1 and the final internal build being shipped. Lagging build number by 1.
    // *****************IMPORTANT*********************************************************************** If you are changing this, also change applicationbecameactive and tutorialDonePressed button on FATutorialViewController as that makes more sense.
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"V4_3_2_UsedOnce"])
    {
        // Show tutorial
        [self configViewControllerWithName:@"FATutorialViewController"];
        
        FADataController *econEventDataController = [[FADataController alloc] init];
        
        // Delete all entries in the action table to reset state so that any user is starting with a clean slate for following.Don't need to do this reset anymore as most of the people who were going to upgrade have probably already done so and are using following which we don't want to wipeout.
        //[econEventDataController deleteAllEventActions];
        
        // Sync the 2018 econ events
        [econEventDataController getAllEconomicEventsFromLocalStorage];
        
        // Delete the FIFA 18 events as there are duplicates that have somehow got in. No longer need to do this as people are likely to have upgraded killing these anyway.
        //[econEventDataController deleteAllFIFA18Events];
        
        // Delete all events from a past version that currently don't have any Ticker as the BBRY change to BB might have created some of these.
        [econEventDataController deleteAllEmptyTickerEvents];
        
        // Delete all BBRY events as ticker has changed from BBRY to BB.
        [econEventDataController deleteAllBBRYEvents];
        
        // Delete the BBRY ticker
        [econEventDataController deleteCompanyWithTicker:@"BBRY"];
        
        // Add newer company tickers from hard code. This gets all the newer added prod event tickers as well.
        [econEventDataController getAllTickersAndNamesFromLocalCode];
        
            // Add new tickers + Refresh existing events and get product events
            // Async processing of non ui tasks should not be done on the main thread.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
                
                // Create a new FADataController so that this thread has its own MOC
                FADataController *eventDataController = [[FADataController alloc] init];
                
                // Add newer company tickers from hard code. This gets all the newer added prod event tickers as well.
                [eventDataController getAllTickersAndNamesFromLocalCode];
                
                if ([self checkForInternetConnectivity]) {
                    // TO DO: Testing. Delete before shipping v4.3
                    //NSLog(@"Kicking off refresh of events");
                [self refreshEventsIfNeededFromApiInBackgroundWithDataController:eventDataController];
                }
            });
        
        // Update the list of companies in a background task. Don't need to do this anymore as we are getting most of the tickers in the updatefromlocalcode. See in the future if you want to bring this back.
       /* __block UIBackgroundTaskIdentifier backgroundFetchTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"backgroundIncrementalCompaniesFetch" expirationHandler:^{
            
            // Stopped or ending the task outright.
            [[UIApplication sharedApplication] endBackgroundTask:backgroundFetchTask];
            backgroundFetchTask = UIBackgroundTaskInvalid;
        }];
        // Start the long-running task and return immediately.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            // TO DO: For testing, comment before shipping.Keeping it around for future pre seeding testing.
            // Delete before shipping v4.3
            NSLog(@"About to start the background get incremental companies from local file");
            
            // Create a new FADataController so that this thread has its own MOC
            FADataController *tickerBkgrndDataController = [[FADataController alloc] init];
            
            // Sync all the tickers to make sure you get the latest ones.
            [tickerBkgrndDataController getAllTickersAndNamesFromLocalStorage];
            
            // TO DO: For testing, comment before shipping.Keeping it around for future pre seeding testing.
            // Delete before shipping v4.3
            NSLog(@"Ended the background get incremental companies from local file");
            
            [[UIApplication sharedApplication] endBackgroundTask:backgroundFetchTask];
            backgroundFetchTask = UIBackgroundTaskInvalid;
        }); */
    }
    // If yes
    else {
        [self configViewControllerWithName:@"FAEventsNavController"];
    }
    
    // TO DO: Testing. Delete before shipping v4.3
    //NSLog(@"Did finish launching with options");
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    // Check for connectivity. If yes, sync data from remote data source
    if ([self checkForInternetConnectivity]) {
        
        // Refresh events, sync product events after upgrade is done
        // Async processing of non ui tasks should not be done on the main thread.
        // *****************IMPORTANT*********************************************************************** If you are changing this, also change applicationfinishedlaunching and tutorialDonePressed button on FATutorialViewController.
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"V4_3_2_UsedOnce"])
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
                
                // TO DO: Testing. Delete before shipping v4.3
                //NSLog(@"Kicking of refresh of events");
                
                // Create a new FADataController so that this thread has its own MOC
                FADataController *eventDataController = [[FADataController alloc] init];
                
                [self refreshEventsIfNeededFromApiInBackgroundWithDataController:eventDataController];
            });
        }
        
        // TO DO: Delete Later, Testing only
        //NSLog(@"Application did become active called");
        
        // TRACKING EVENT: App Launch: Application was launched.
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents activateApp];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    // [self saveContext];
    
    // Check to see if all the company data has been synced before terminating. This is done by checking if all pages of information
    // have been processed. Using the total number of company pages to sync from user data store.
    // TO DO: OPTIONAL UNCOMMENT FOR PRE SEEDING DB: Commenting out since we don't want to do a company/event sync due to preseeded data.
    // Create a new generic Data Controller
    /*FADataController *genericDataController = [[FADataController alloc] init];
    if ([[genericDataController getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&[[genericDataController getCompanySyncedUptoPage] integerValue] < [[genericDataController getTotalNoOfCompanyPagesToSync] integerValue])
    {
        [genericDataController upsertUserWithCompanySyncStatus:@"FullSyncAttemptedButFailed" syncedPageNo:[genericDataController getCompanySyncedUptoPage]];
    }
    NSLog(@"**************Company Sync Status is:%@ and synced page is:%ld",[genericDataController getCompanySyncStatus],[[genericDataController getCompanySyncedUptoPage] longValue]); */
}

#pragma mark - FB SDK Methods

// Needed to add the FB SDK
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation];
}

#pragma mark - State Setup Rfresh

// Refresh events that are likely to be updated, from API. Additionally also get the events for trending tickers initially. Check to see if product events need to be added or refreshed. If yes, do that. Currently product events are being fetched whole each time. Plus  Typically called in a background thread.
- (void)refreshEventsIfNeededFromApiInBackgroundWithDataController:(FADataController *)existingDC
{
    // TO DO: Uncomment for actual use. Comment for test data for event update testing.
    [existingDC updateEventsFromRemoteIfNeeded];
}

// Kick off a background task to add any new companies that might have been added.
- (void)doCompanyUpdateInBackground
{
    // Create a new FADataController so that this thread has its own MOC
    FADataController *companyUpdateDataController = [[FADataController alloc] init];
    
    // Get Today's Date
    NSDate *todaysDate = [NSDate date];
    
    // Get the last company sync date
    NSDate *lastCompanySyncDate = [companyUpdateDataController getCompanySyncDate];
    
    // Get the last event sync date
    NSDate *lastEventSyncDate = [companyUpdateDataController getEventSyncDate];
    
    // Get the number of days between the 2 company sync dates
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [gregorianCalendar components:NSCalendarUnitDay fromDate:lastCompanySyncDate toDate:todaysDate options:0];
    NSInteger daysBetween = [components day];
    
    // Get the number of days between the 2 event sync dates
    NSDateComponents *eventComponents = [gregorianCalendar components:NSCalendarUnitDay fromDate:lastEventSyncDate toDate:todaysDate options:0];
    NSInteger daysBetweenEventSyncs = [eventComponents day];
    
    // TO DO: For testing, comment before shipping. Keeping it around for future pre seeding testing.
    NSLog(@"Days since last company sync:%ld and syncstatus is:%@ and no of days since event sync are:%ld",(long)daysBetween,[companyUpdateDataController getCompanySyncStatus],(long)daysBetweenEventSyncs);
    
    // If it's been 45 days since the last company sync, do an incremental sync, only if the event sync for the day is done
    if (((int)daysBetween >= 45)&&((int)daysBetweenEventSyncs <= 0))
    {
        // Creating a task that continues to process in the background.
        __block UIBackgroundTaskIdentifier backgroundFetchTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"backgroundIncrementalCompaniesFetch" expirationHandler:^{
            
            // Stopped or ending the task outright.
            [[UIApplication sharedApplication] endBackgroundTask:backgroundFetchTask];
            backgroundFetchTask = UIBackgroundTaskInvalid;
        }];
        
        // Start the long-running task and return immediately.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            // TO DO: For testing, comment before shipping.Keeping it around for future pre seeding testing.
            //NSLog(@"About to start the background get incremental companies from API");
            
            // Create a new FADataController so that this thread has its own MOC
            FADataController *companyBkgrndDataController = [[FADataController alloc] init];
            
            [companyBkgrndDataController getIncrementalCompaniesFromApi];
            
            [[UIApplication sharedApplication] endBackgroundTask:backgroundFetchTask];
            backgroundFetchTask = UIBackgroundTaskInvalid;
        });
    }
}

// Redo fetching of company data from the API, in case the full sync of company data had failed or not started. Typically called in a background thread.
- (void)refreshCompanyInfoIfNeededFromApiInBackground
{
    // Create a new FADataController so that this thread has its own MOC
    FADataController *companyDataController = [[FADataController alloc] init];
    
    if ([[companyDataController getCompanySyncStatus] isEqualToString:@"SeedSyncDone"]||[[companyDataController getCompanySyncStatus] isEqualToString:@"FullSyncAttemptedButFailed"]) {
        
        // Get Companies
        // Creating a task that continues to process in the background.
        __block UIBackgroundTaskIdentifier backgroundFetchTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"backgroundCompaniesFetch" expirationHandler:^{
            
            // Clean up any unfinished task business before it's about to be terminated
            // In our case, check if all pages of companies data has been synced. If not, mark status to failed
            // so that another thread can pick up the completion on restart. Currently this is hardcoded to 26 as 26 pages worth of companies (7517 companies at 300 per page) were available as of Sep 29, 2105. When you change this, change the hard coded value in getAllCompaniesFromApi(2 places) in FADataController. Also change in Search Bar Began Editing in the Events View Controller.
            if ([[companyDataController getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&[[companyDataController getCompanySyncedUptoPage] integerValue] < [[companyDataController getTotalNoOfCompanyPagesToSync] integerValue])
            {
                [companyDataController upsertUserWithCompanySyncStatus:@"FullSyncAttemptedButFailed" syncedPageNo:[companyDataController getCompanySyncedUptoPage]];
            }
            
            // Stopped or ending the task outright.
            [[UIApplication sharedApplication] endBackgroundTask:backgroundFetchTask];
            backgroundFetchTask = UIBackgroundTaskInvalid;
        }];
        
        // Start the long-running task and return immediately.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [companyDataController getAllCompaniesFromApi];
            
            [[UIApplication sharedApplication] endBackgroundTask:backgroundFetchTask];
            backgroundFetchTask = UIBackgroundTaskInvalid;
        });
    }
}

#pragma mark - Notifications

// Send a notification that the list of events has changed (updated)
- (void)sendEventsChangeNotification {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
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

#pragma mark - View Controller Selection

// Configure view controller based on name
- (void) configViewControllerWithName:(NSString *)controllerStoryboardId
{
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:controllerStoryboardId];
    
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];
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
