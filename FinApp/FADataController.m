//
//  FADataController.m
//  FinApp
//
//  Class to interact with the core data store. Each thread should have it's own
//  FADataController that creates a new managed object context that talks to the
//  single data store.
//
//  Created by Sidd Singh on 3/2/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "FADataController.h"
#import "FADataStore.h"
#import "Company.h"
#import "Event.h"
#import "User.h"
#import "Action.h"
#import "EventHistory.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>

@interface FADataController ()

// Send a notification that the list of messages has changed (updated)
- (void)sendEventsChangeNotification;

// Send a notification to the events list controller with a message that should be shown to the user
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents;

// Send a notification that a queued reminder associated with an event should be created, since the event date has been confirmed. Send an array of information {eventType,companyTicker,eventDateText} that will be needed by receiver to complete this action.
- (void)sendCreateReminderNotificationWithEventInformation:(NSArray *)eventInfo;

@end

@implementation FADataController

// Private variable: Flag to see if any event was updated
bool eventsUpdated = NO;

#pragma mark - Data Store related

// Managed Object Context to interact with Data Store.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    // Get the single persistent store for this application.
    self.appDataStore = [FADataStore sharedStore];
    
    if ([self.appDataStore persistentStoreCoordinator] != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:0];
        [_managedObjectContext setPersistentStoreCoordinator:[self.appDataStore persistentStoreCoordinator]];
    }
    
    return _managedObjectContext;
}

#pragma mark - Company Data Related

// Add company details to the company data store. Current design is that a company
// is uniquely identified by it's ticker. Thus this method creates the company with
// it's details only if the ticker doesn't exist.
- (void)insertUniqueCompanyWithTicker:(NSString *)companyTicker name:(NSString *)companyName
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the Company exists by doing a case insensitive query on companyTicker
    NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
    NSPredicate *companyPredicate = [NSPredicate predicateWithFormat:@"ticker =[c] %@",companyTicker];
    [companyFetchRequest setEntity:companyEntity];
    [companyFetchRequest setPredicate:companyPredicate];
    NSError *error;
    Company *existingCompany = nil;
    NSArray *fetchedCompanies = [dataStoreContext executeFetchRequest:companyFetchRequest error:&error];
    existingCompany  = [fetchedCompanies lastObject];
    if (fetchedCompanies.count > 1) {
        NSLog(@"SEVERE_WARNING: Found %ld(more than 1) duplicate tickers for %@ when inserting a company to the Data Store",(long)fetchedCompanies.count,companyTicker);
    }
    if (error) {
        NSLog(@"ERROR: Getting a company from data store, to check uniqueness when inserting, failed: %@",error.description);
    }
    
    // If the Company does not exist, insert it
    if (!existingCompany) {
        Company *company = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
        company.ticker = companyTicker;
        company.name = companyName;
        // Insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Saving a company that is unique, to the data store, failed: %@",error.description);
        }
        // TO DO: Delete Later.
        else {
            
        }
    }
    // TO DO: Delete Later
    else {

    }
}

// Get all Companies. Returns a results controller with identities of all Companies recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllCompanies
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get all companies
    NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
    [companyFetchRequest setEntity:companyEntity];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"ticker" ascending:YES];
    [companyFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [companyFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:companyFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all companies from data store failed: %@",error.description);
    }
    // TO DO: Delete Later.
    else {

    }
    
    return self.resultsController;
}

// Get company ticker using company name. Assumption is that there is only one record per company name and ticker.
- (NSString *)getTickerForName:(NSString *)companyName
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get company record by doing a case insensitive query on company name
    NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
    NSPredicate *companyPredicate = [NSPredicate predicateWithFormat:@"name =[c] %@",companyName];
    [companyFetchRequest setEntity:companyEntity];
    [companyFetchRequest setPredicate:companyPredicate];
    NSError *error;
    Company *existingCompany = nil;
    NSArray *fetchedCompanies = [dataStoreContext executeFetchRequest:companyFetchRequest error:&error];
    existingCompany  = [fetchedCompanies lastObject];
    if (fetchedCompanies.count > 1) {
        NSLog(@"SEVERE_WARNING: Found %ld(more than 1) duplicate tickers for %@ when getting a ticker using company name from the Data Store",(long)fetchedCompanies.count,companyName);
    }
    if (error) {
        NSLog(@"ERROR: Getting a company ticker using company name from data store failed: %@",error.description);
    }

    // Return Company Ticker
    return existingCompany.ticker;
}

// Delete a company given a ticker
- (void)deleteCompanyWithTicker:(NSString *)companyTicker
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the Company exists by doing a case insensitive query on companyTicker
    NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
    NSPredicate *companyPredicate = [NSPredicate predicateWithFormat:@"ticker =[c] %@",companyTicker];
    [companyFetchRequest setEntity:companyEntity];
    [companyFetchRequest setPredicate:companyPredicate];
    NSError *error;
    NSArray *fetchedCompanies = [dataStoreContext executeFetchRequest:companyFetchRequest error:&error];
    
    if (fetchedCompanies.count > 1) {
        NSLog(@"SEVERE_WARNING: Found %ld(more than 1) duplicate tickers for %@ when trying to delete the company from the datastore",(long)fetchedCompanies.count,companyTicker);
    }
    if (fetchedCompanies.count == 0) {
        NSLog(@"INFO ONLY: Did not find company for ticker %@ when trying to delete the company from the datastore",companyTicker);
    }
    if (error) {
        NSLog(@"ERROR: Fetching a company, with ticker %@ to delete from data store, failed: %@",companyTicker,error.description);
    }
    
    // Delete all following actions
    for (NSManagedObject *company in fetchedCompanies) {
        
        [dataStoreContext deleteObject:company];
    }
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
    
    // Delete before shipping v4.3
    //NSLog(@"DONE COMITTING DELETE OF BBRY TICKER COMPANY");
}

#pragma mark - Events Data Related

// Upsert an Event along with a parent company to the Event Data Store i.e. If the specified event type for that particular company exists, update it. If not insert it.
- (void)upsertEventWithDate:(NSDate *)eventDate relatedDetails:(NSString *)eventRelatedDetails relatedDate:(NSDate *)eventRelatedDate type:(NSString *)eventType certainty:(NSString *)eventCertainty listedCompany:(NSString *)listedCompanyTicker estimatedEps:(NSNumber *)eventEstEps priorEndDate:(NSDate *)eventPriorEndDate actualEpsPrior:(NSNumber *)eventActualEpsPrior
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event exists by doing a case insensitive query on parent company Ticker and event type.
    // TO DO: Current assumption is that an event is uniquely identified by the combination of above 2 fields. This might need to change in the future.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // If event is of type price change set type filter to be more generic depending on the type of price change event
    // "50.12% up today" "50.12% down today" "10.12% down 30 days" "30.12% down ytd"
    NSPredicate *eventPredicate = nil;
    // For daily change event - % up today
    if ([eventType containsString:@"% up today"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",listedCompanyTicker,@"% up today"];
    }
    // For daily change event - % down today
    if ([eventType containsString:@"% down today"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",listedCompanyTicker,@"% down today"];
    }
    // For 30 days change event - % down 30 days
    else if ([eventType containsString:@"% down 30 days"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",listedCompanyTicker,@"% down 30 days"];
    }
    // For 30 days change event - % up 30 days
    else if ([eventType containsString:@"% up 30 days"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",listedCompanyTicker,@"% up 30 days"];
    }
    // For year to date change event - % down ytd
    else if ([eventType containsString:@"% down ytd"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",listedCompanyTicker,@"% down ytd"];
    }
    // For year to date change event - % up ytd
    else if ([eventType containsString:@"% up ytd"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",listedCompanyTicker,@"% up ytd"];
    }
    // For 52 week High event
    else if ([eventType containsString:@"52 Week High"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",listedCompanyTicker,@"52 Week High"];
    }
    // For 52 week Low event
    else if ([eventType containsString:@"52 Week Low"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",listedCompanyTicker,@"52 Week Low"];
    }
    // If not a price change event, it's an exact match to the type string
    else {
       eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type =[c] %@",listedCompanyTicker,eventType];
    }
    
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    Event *existingEvent = nil;
    existingEvent  = [[dataStoreContext executeFetchRequest:eventFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting an event from data store, to check uniqueness when upserting, failed: %@",error.description);
    }
    
    // If the event does not exist, insert it
    if (!existingEvent) {
        
        // Get the parent listed company for the event by doing a case insensitive query on the company ticker
        NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
        [companyFetchRequest setEntity:companyEntity];
        NSPredicate *companyPredicate = [NSPredicate predicateWithFormat:@"ticker =[c] %@",listedCompanyTicker];
        [companyFetchRequest setPredicate:companyPredicate];
        Company *parentCompany = nil;
        parentCompany  = [[dataStoreContext executeFetchRequest:companyFetchRequest error:&error] lastObject];
        if (error) {
            NSLog(@"ERROR: Getting a parent listed company, for inserting an associated event from data store failed: %@",error.description);
        }
        
        // Insert the event with the parent listed company
        Event *event = [NSEntityDescription insertNewObjectForEntityForName:@"Event" inManagedObjectContext:dataStoreContext];
        event.type = eventType;
        event.date = eventDate;
        event.relatedDetails = eventRelatedDetails;
        event.relatedDate = eventRelatedDate;
        event.certainty = eventCertainty;
        event.listedCompany = parentCompany;
        event.estimatedEps = eventEstEps;
        event.priorEndDate = eventPriorEndDate;
        event.actualEpsPrior = eventActualEpsPrior;
    }
    
    // If the event exists update it
    else {
        
        // Don't need to update type and company as these are the unique identifiers
        existingEvent.date = eventDate;
        existingEvent.relatedDetails = eventRelatedDetails;
        existingEvent.relatedDate = eventRelatedDate;
        existingEvent.certainty = eventCertainty;
        existingEvent.estimatedEps = eventEstEps;
        existingEvent.priorEndDate = eventPriorEndDate;
        existingEvent.actualEpsPrior = eventActualEpsPrior;
    }
    
    // Perform the insert
    if (![dataStoreContext save:&error]) {
        NSLog(@"ERROR: Saving event of type: %@ and with ticker:%@ to data store failed: %@",eventType,listedCompanyTicker,error.description);
    }
}

// Get all Events. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get all events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all events from data store failed: %@",error.description);
    }
    // TO DO: Delete. Currently for debugging only
    else {

    }
    
    return self.resultsController;
}

// Get all future events including today. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
// NOTE: Thid does not get the price change events as they are only available as following events.
- (NSFetchedResultsController *)getAllFutureEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type =[c] %@ OR listedCompany.ticker contains %@ OR type contains[cd] %@ OR type contains[cd] %@)", todaysDate, @"Quarterly Earnings", @"ECONOMY_", @"Launch", @"Conference"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future events, except price change events, from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get all future events including today. The included product events will only be the ones that have very high impact
- (NSFetchedResultsController *)getAllFutureEventsWithProductEventsOfVeryHighImpact
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type =[c] %@ OR listedCompany.ticker contains %@ OR type contains[cd] %@ OR type contains[cd] %@) AND ((NOT ((relatedEventHistory.previous1Status contains[cd] %@) OR (relatedEventHistory.previous1Status contains[cd] %@) OR (relatedEventHistory.previous1Status contains[cd] %@))) OR (relatedEventHistory.previous1Status contains[cd] %@))", todaysDate, @"Quarterly Earnings", @"ECONOMY_", @"Launch", @"Conference", @"High_", @"Medium_", @"Low_", @"Very High_"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future events, except price change events, from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}


// Get all future following events including today. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
// NOTE: This gets the price change events as well since they are available as following events.
- (NSFetchedResultsController *)getAllFollowingFutureEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter
    // Including price change events
    //NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND ((ANY actions.type == %@) OR (ANY actions.type == %@))", todaysDate, @"OSReminder", @"PriceChange"];
    // Excluding price change events
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (ANY actions.type == %@)", todaysDate, @"OSReminder"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future following events, not including price change events, from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Check if the given ticker is being followed.
- (BOOL)isBeingFollowed:(NSString *)tickerToCheck
{
    BOOL beingFollowed = NO;
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"(listedCompany.ticker =[c] %@) AND ((ANY actions.type == %@) OR (ANY actions.type == %@))", tickerToCheck, @"OSReminder", @"PriceChange"];
    [eventFetchRequest setPredicate:datePredicate];
    
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Checking for if a ticker is being followed, failed: %@",error.description);
    }
    // If any event exists that means this ticker is being followed, return true.
    if (events.count >= 1) {
        beingFollowed = YES;
    }
    
    // else return false
    return beingFollowed;
}

// Get all future earnings events including today. Returns a results controller with identities of all earnings Events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllFutureEarningsEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter for date and event type
    // Searching for events of type "Quarterly Earnings"
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND type =[c] %@", todaysDate, @"Quarterly Earnings"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future earnings events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get all future following earnings events including today. Returns a results controller with identities of all earnings Events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllFollowingFutureEarningsEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter for date and event type
    // Searching for events of type "Quarterly Earnings"
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND type =[c] %@ AND (ANY actions.type == %@)", todaysDate, @"Quarterly Earnings", @"OSReminder"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future earnings events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get all future economic events including today. Returns a results controller with identities of all economic events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllFutureEconEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter for date and event type
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND listedCompany.ticker contains %@", todaysDate, @"ECONOMY_"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get all future cryptocurrency events including today. Returns a results controller with identities of all crypto events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllFutureCryptoEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter for date and event type
    // FOR BTC - Add any new crypto currency here to make it show up in the Crypto section
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@)", todaysDate, @"BTC", @"ETHR", @"BCH$", @"XRP"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get all following future economic events including today. Returns a results controller with identities of all economic events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
// Currently this is empty as we haven't figured out how to follow Econ Events
- (NSFetchedResultsController *)getAllFollowingFutureEconEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter for date and event type
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND listedCompany.ticker contains %@ AND (ANY actions.type == %@)", todaysDate, @"ECONOMY_", @"OSReminder"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get all following future crypto events including today. Returns a results controller with identities of all crypto events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
// Currently this is empty as we haven't figured out how to follow Econ Events
- (NSFetchedResultsController *)getAllFollowingFutureCryptoEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter for date and event type
    // FOR BTC: Add any new cryptocurrencies here.
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@) AND (ANY actions.type == %@)", todaysDate, @"BTC", @"ETHR", @"BCH$", @"XRP", @"OSReminder"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get all future product events including today (minus the Crypto events). Returns a results controller with identities of all product events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
// NOTE: If there is a new type of product event like launch or conference added, add that here as well.
- (NSFetchedResultsController *)getAllFutureProductEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the event and date filter
    
    // Old way which includes crypto events
    //NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type contains[cd] %@ OR type contains[cd] %@)", todaysDate, @"Launch", @"Conference"];
    
    // New way does not include crypto.
    // NOTE: If there is a new type of product event like launch or conference added, add that here as well
    // FOR BTC - Add any new crypto currency here to make it show up in the Crypto section
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type contains[cd] %@ OR type contains[cd] %@) AND (listedCompany.ticker !=[c] %@ AND listedCompany.ticker !=[c] %@ AND listedCompany.ticker !=[c] %@ AND listedCompany.ticker !=[c] %@)", todaysDate, @"Launch", @"Conference", @"BTC", @"ETHR", @"BCH$", @"XRP"];
    
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future events, minus crypto, from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// This is actually the next 7 days
- (NSFetchedResultsController *)getPastProductEventsIncludingNext7Days
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Add 7 days
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = 7;
    NSDate *weekDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:todaysDate options:0];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the event and date filter
    // NOTE: If there is a new type of product event like launch or conference added, add that here as well
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date <= %@ AND (type contains[cd] %@ OR type contains[cd] %@)", weekDate, @"Launch", @"Conference"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all product events including today tomorrow from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get no events. Currently this returns empty i.e. no events
- (NSFetchedResultsController *)getNoEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the event and date filter
    // NOTE: If there is a new type of product event like launch or conference added, add that here as well
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type contains[cd] %@ OR type contains[cd] %@)", todaysDate, @"EventTypeNotDefined", @"EventTypeNotDefined"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all trending events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Get all product events for a given ticker since a given date
- (NSFetchedResultsController *)getAllProductEventsForTicker:(NSString *)parentTicker since:(NSDate *)startingDate
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *sinceDate = [self setTimeToMidnightLastNightOnDate:startingDate];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the event and date filter
    // NOTE: This includes conferences If there is a new type of product event like launch or conference added, add that here as well
    // NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type contains[cd] %@ OR type contains[cd] %@) AND (listedCompany.ticker =[c] %@)", sinceDate, @"Launch", @"Conference", parentTicker];
    // NOTE: This does not include conferences. If there is a new type of product event like launch or conference added, add that here as well
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type contains[cd] %@) AND (listedCompany.ticker =[c] %@)", sinceDate, @"Launch", parentTicker];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all product events, since a particular date, for ticker:%@ from data store failed: %@",parentTicker, error.description);
    }
    
    return self.resultsController;
}

// Get all future product events including today for a given ticker
- (NSArray *)getAllFutureProductEventsForTicker:(NSString *)parentTicker
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the event and date filter
    // NOTE: If there is a new type of product event like launch or conference added, add that here as well
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type contains[cd] %@ OR type contains[cd] %@) AND (listedCompany.ticker =[c] %@)", todaysDate, @"Launch", @"Conference", parentTicker];
    [eventFetchRequest setPredicate:datePredicate];
    
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting all future product events for ticker:%@ from data store failed: %@",parentTicker, error.description);
    }
    
    return events;
}

// Get all following future product events including today. Returns a results controller with identities of all product events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
// NOTE: If there is a new type of product event like launch or conference added, add that here as well.
- (NSFetchedResultsController *)getAllFollowingFutureProductEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the event and date filter
    // NOTE: If there is a new type of product event like launch or conference added, add that here as well
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (type contains[cd] %@ OR type contains[cd] %@) AND (ANY actions.type == %@)", todaysDate, @"Launch", @"Conference", @"OSReminder"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all future events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

// Search and return all future events that match the search text dpending on the display event type. Note this is different from the type field on the event data object: 0. All (all eventTypes) 1. "Earnings" (Quarterly Earnings) 2. "Economic" (Economic Event) 3. "Product" (Product Event).NOTE: If there is a new type of product event like launch or conference added, add that here as well. 4. "Crypto" (Crypto Currency event)
// Returns a results controller with identities of all events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the data store at a time.
- (NSFetchedResultsController *)searchEventsFor:(NSString *)searchText eventDisplayType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Add 7 days
    //NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    //NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    //differenceDayComponents.day = 7;
    //NSDate *weekDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:todaysDate options:0];
    
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    
    // Sort descriptor
    NSSortDescriptor *sortField;
    
    [eventFetchRequest setFetchBatchSize:15];
    
    // Setup the filtering based on the event type
    NSPredicate *searchPredicate = nil;
    
    // Check to see if the event type is "All". Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all events
    if ([eventType caseInsensitiveCompare:@"All"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (date >= %@) AND (NOT ((type contains[cd] %@) OR (type contains[cd] %@)))", searchText, searchText, searchText, todaysDate, @"% up", @"% down"];
        //searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (date >= %@)", searchText, searchText, searchText, todaysDate];
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    // Check to see if the event display type is "Home". Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all events, Exclude product events with impact other than Very High.
    if ([eventType caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (date >= %@) AND (NOT ((type contains[cd] %@) OR (type contains[cd] %@) OR (type contains[cd] %@))) AND ((NOT ((relatedEventHistory.previous1Status contains[cd] %@) OR (relatedEventHistory.previous1Status contains[cd] %@) OR (relatedEventHistory.previous1Status contains[cd] %@))) OR (relatedEventHistory.previous1Status contains[cd] %@))", searchText, searchText, searchText, todaysDate, @"% up", @"% down", @"52 Week", @"High_", @"Medium_", @"Low_", @"Very High_"];
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    // Check to see if the event type is "Earnings". Search on "ticker" or "name" fields for the listed Company for earnings events
    if ([eventType caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@) AND (type =[c] %@) AND (date >= %@)", searchText, searchText, @"Quarterly Earnings", todaysDate];
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    // Check to see if the event type is "Economic". Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
    if ([eventType caseInsensitiveCompare:@"Economic"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (listedCompany.ticker contains %@) AND (date >= %@)", searchText, searchText, searchText, @"ECONOMY_", todaysDate];
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    // Check to see if the event type is "Crypto". Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
    if ([eventType caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        // FOR BTC: Add any new cryptocurrencies here as well.
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@ OR listedCompany.ticker =[c] %@) AND (date >= %@)", searchText, searchText, searchText, @"BTC", @"ETHR", @"BCH$", @"XRP", todaysDate];
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    // Check to see if the event type is "Product". Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all product events
    if ([eventType caseInsensitiveCompare:@"Product"] == NSOrderedSame) {
        
        // Old way included crypto events and sorting was different.
        // Case and Diacractic Insensitive Filtering
        //searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (type contains[cd] %@ OR type contains[cd] %@) AND (date <= %@)", searchText, searchText, searchText, @"Launch", @"Conference", weekDate];
        //sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
        
        // New way does not include crypto events and only allows future events.
        // FOR BTC - Add any new crypto currency here to make it show up in the Crypto section
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (type contains[cd] %@ OR type contains[cd] %@) AND (date >= %@) AND (listedCompany.ticker !=[c] %@ AND listedCompany.ticker !=[c] %@ AND listedCompany.ticker !=[c] %@ AND listedCompany.ticker !=[c] %@)", searchText, searchText, searchText, @"Launch", @"Conference", todaysDate, @"BTC", @"ETHR", @"BCH$", @"XRP"];
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    [eventFetchRequest setPredicate:searchPredicate];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Searching for events of type: %@ with search text: %@,from data store,failed: %@", eventType, searchText, error.description);
    }
    
    return self.resultsController;
}

// Search and return all following future events that match the search text depending on the display event type. Note this is different from the type field on the event data object: 0. All (all eventTypes) 1. "Earnings" (Quarterly Earnings) 2. "Economic" (Economic Event) 3. "Product" (Product Event).NOTE: If there is a new type of product event like launch or conference added, add that here as well.
// Returns a results controller with identities of all events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the data store at a time.
- (NSFetchedResultsController *)searchFollowingEventsFor:(NSString *)searchText eventDisplayType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    // Sort with the closest event first
    NSSortDescriptor *sortField = nil;
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    
    // Setup the filtering based on the event type
    NSPredicate *searchPredicate = nil;
    
    // Check to see if the event type is "All". Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all events
    if ([eventType caseInsensitiveCompare:@"All"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        // Price change events included
        //searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (date >= %@) AND ((ANY actions.type == %@) OR (ANY actions.type == %@))", searchText, searchText, searchText, todaysDate, @"OSReminder", @"PriceChange"];
        // Price change events excluded
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (date >= %@) AND (ANY actions.type == %@)", searchText, searchText, searchText, todaysDate, @"OSReminder"];
        // Sort with the closest event first
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    // Check to see if the event type is "Earnings". Search on "ticker" or "name" fields for the listed Company for earnings events
    if ([eventType caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@) AND (type =[c] %@) AND (date >= %@) AND (ANY actions.type == %@)", searchText, searchText, @"Quarterly Earnings", todaysDate, @"OSReminder"];
        // Sort with the closest event first
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    // Check to see if the event type is "Economic". Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
    if ([eventType caseInsensitiveCompare:@"Economic"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (listedCompany.ticker contains %@) AND (date >= %@) AND (ANY actions.type == %@)", searchText, searchText, searchText, @"ECONOMY_", todaysDate, @"OSReminder"];
        // Sort with the closest event first
        sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    }
    
    // Check to see if the event type is "Price". Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all events
    if ([eventType caseInsensitiveCompare:@"Price"] == NSOrderedSame) {
        // Case and Diacractic Insensitive Filtering
        // Price change events including 52 week
        searchPredicate = [NSPredicate predicateWithFormat:@"(listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@ OR type contains[cd] %@) AND (ANY actions.type == %@)", searchText, searchText, searchText, @"PriceChange"];
        // Sort with the closest event first
        sortField = [[NSSortDescriptor alloc] initWithKey:@"listedCompany.ticker" ascending:YES];
    }
    
    [eventFetchRequest setPredicate:searchPredicate];
    
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    
    [eventFetchRequest setFetchBatchSize:15];
    
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Searching for following events of type: %@ with search text: %@,from data store,failed: %@", eventType, searchText, error.description);
    }
    
    return self.resultsController;
}

// Search and return all companies that match the search text on "ticker" and "name" fields for the Company.
// Returns a results controller with identities of all companies recorded, but no more than batchSize (currently set
// to 15) objects’ data will be fetched from the data store at a time.
- (NSFetchedResultsController *)searchCompaniesFor:(NSString *)searchText
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
    [companyFetchRequest setEntity:companyEntity];
    
    // Case and Diacractic Insensitive Filtering
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"name contains[cd] %@ OR ticker contains[cd] %@", searchText, searchText];
    [companyFetchRequest setPredicate:searchPredicate];
    
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    [companyFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    
    [companyFetchRequest setFetchBatchSize:15];
    
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:companyFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Searching for companies with the following name and ticker search text: %@ from data store failed: %@",searchText, error.description);
    }
    
    return self.resultsController;
}

// Get the date for an Event given the Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (NSDate *)getDateForEventOfType:(NSString *)eventType eventTicker:(NSString *)eventCompanyTicker
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // TO DO: Current assumption is that an event is uniquely identified by the combination of above 2 fields. This might need to change in the future.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type =[c] %@",eventCompanyTicker, eventType];
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    Event *existingEvent = nil;
    existingEvent  = [[dataStoreContext executeFetchRequest:eventFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting an event from data store, for it's date, failed: %@",error.description);
    }
    
    // If the event exists, return it's date
    if (existingEvent) {
        
        return existingEvent.date;
    }
    
    // If the event does not exist, return nil, indicating an error has occurred and log the error.
    else {
        
        NSLog(@"ERROR: Could not return date for event ticker %@ and event type %@ because the event was not found in the data store", eventCompanyTicker,eventType);
        return nil;
    }
}

// Get Event Details for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (Event *)getEventForParentEventTicker:(NSString *)eventCompanyTicker andEventType:(NSString *)eventType {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // TO DO: Current assumption is that an event is uniquely identified by the combination of above 2 fields. This might need to change in the future.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type =[c] %@",eventCompanyTicker, eventType];
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    Event *existingEvent = nil;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting an event from data store failed: %@",error.description);
    }
    if (events.count > 1) {
        NSLog(@"ERROR: Found more than 1 event for ticker:%@ and event type:%@ in the Event Data Store", eventCompanyTicker, eventType);
    }
    // If the event exists, return it.
    if (events) {
        
        existingEvent = [events lastObject];
    }
    // If the event does not exist, return nil, indicating an error has occurred and log the error.
    else {
        
        NSLog(@"ERROR: Could not return date for event ticker %@ and event type %@ because the event was not found in the data store", eventCompanyTicker,eventType);
    }
    
    return existingEvent;
}

// Get all events for the given event Company Ticker.
- (NSArray *)getAllEventsForParentEventTicker:(NSString *)eventCompanyTicker {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the events by doing a case insensitive query on parent company Ticker.
    NSFetchRequest *eventsFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventsPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@",eventCompanyTicker];
    [eventsFetchRequest setEntity:eventEntity];
    [eventsFetchRequest setPredicate:eventsPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventsFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting all event for ticker: %@ from data store failed: %@",eventCompanyTicker,error.description);
    }
    
    return events;
}

// Get all economic events of a given type (e.g. Jobs Report)
- (NSArray *)getAllEconEventsOfType:(NSString *)eventType {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the events by doing a case insensitive query on event type.
    NSFetchRequest *eventsFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventsPredicate = [NSPredicate predicateWithFormat:@"type contains[cd] %@",eventType];
    [eventsFetchRequest setEntity:eventEntity];
    [eventsFetchRequest setPredicate:eventsPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventsFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting all econ events of type: %@ from data store failed: %@",eventType,error.description);
    }
    
    return events;
}

// Check to see an event of a certain type exists for a given company ticker. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (BOOL)doesEventExistForParentEventTicker:(NSString *)eventCompanyTicker andEventType:(NSString *)eventType {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL exists = NO;
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // TO DO: Current assumption is that an event is uniquely identified by the combination of above 2 fields. This might need to change in the future.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type =[c] %@",eventCompanyTicker, eventType];
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting an event of a particular type, while checking for it's existence, from data store failed: %@",error.description);
    }
    if (events.count > 1) {
        NSLog(@"ERROR: Found more than 1 event for ticker:%@ and event type:%@ in the Event Data Store", eventCompanyTicker, eventType);
    }
    // If the event exists, return true.
    if (events.count >= 1) {
        exists = YES;
    }
    
    // else return false
    return exists;
}

// Check to see if a single economic event exists in the event data store and return accordingly. Typically used to
// check if economic events types have been synced or not.
- (BOOL)doesEconEventExist
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL exists = NO;
    
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Searching for ticker of type "ECONOMY_FOMC" that identifies the agency that puts out the fed meeting
    NSPredicate *eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@",@"ECONOMY_FOMC"];
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Retrieving Fed meeting event, to check if it exists, from event data store failed: %@",error.description);
    }
    if (events.count >= 1) {
        exists = YES;
    }
    
    return exists;
}

// Check to see if more than the 15 synced events of type quarterly earnings exist in the data store and return accordingly. Typically used to check if trending ticker events have been synced or not.
- (BOOL)doTrendingTickerEventsExist
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL exists = YES;
    
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Searching for events of type "Quarterly Earnings"
    NSPredicate *eventPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@",@"Quarterly Earnings"];
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Retrieving events of type Quarterly Earnings, to check if Trending ticker events exist, from event data store failed: %@",error.description);
    }
    // Fresh install
    if (events.count == 15) {
        exists = YES;
    }
    
    // Upgrade, less than 10 events added by user
    if (events.count < 15) {
        exists = NO;
    }
    
    return exists;
}

// Delete all events that contain "FIFA 18" as these have somehow gotten into a bad state in the DB. This is a one time thing.
- (void)deleteAllFIFA18Events
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // For price change events the event type is a fuzzy match.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    
    // Filter for daily events
    NSPredicate *eventPredicate = nil;
    eventPredicate = [NSPredicate predicateWithFormat:@"type contains %@",@"FIFA 18"];
    
    // Fetch all the specific events
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting the FIFA 18 events, while trying to delete all of them, from data store failed: %@",error.description);
    }
    
    // Delete all the FIFA events
    for (NSManagedObject *fifaEvent in events) {
        
        [dataStoreContext deleteObject:fifaEvent];
    }
    
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
}

// Delete all BBRY events since ticker has changed from BBRY to BB
- (void)deleteAllBBRYEvents {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the events by doing a case insensitive query on parent company Ticker.
    NSFetchRequest *eventsFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventsPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@",@"BBRY"];
    [eventsFetchRequest setEntity:eventEntity];
    [eventsFetchRequest setPredicate:eventsPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventsFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting all BBRY events for deletion from data store failed: %@",error.description);
    }
    
    // Delete all the FIFA events
    for (NSManagedObject *bbryEvent in events) {
        
        [dataStoreContext deleteObject:bbryEvent];
    }
    
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
    
    // Delete before shipping v4.3
    //NSLog(@"DONE COMITTING DELETE OF BBRY EVENTS");
}

// Delete all events where parent event ticker is empty. Need this to clear out some BBRY events since ticker has changed from BBRY to BB
- (void)deleteAllEmptyTickerEvents {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the events by doing a case insensitive query on parent company Ticker.
    NSFetchRequest *eventsFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventsPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker == NULL"];
    [eventsFetchRequest setEntity:eventEntity];
    [eventsFetchRequest setPredicate:eventsPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventsFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting all events with empty ticker for deletion from data store failed: %@",error.description);
    }
    
    // Delete all the FIFA events
    for (NSManagedObject *noTickerEvent in events) {
        // Delete before shipping v4.3
        //NSLog(@"KILLING A NO TICKER EVENT:%@",noTickerEvent.description);
        [dataStoreContext deleteObject:noTickerEvent];
    }
    
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
    
    // Delete before shipping v4.3
    //NSLog(@"DONE COMITTING DELETE OF NULL EVENTS");
}


#pragma mark - Event History related Methods

// Add history associated with an event to the EventHistory Data Store given the previous event 1 date, status, related date, current date, previous event 1 date stock price, previous event 1 related date stock price, current (right now yesterday's) stock price, Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (void)insertHistoryWithPreviousEvent1Date:(NSDate *)previousEv1Date previousEvent1Status:(NSString *)previousEv1Status previousEvent1RelatedDate:(NSDate *)previousEv1RelatedDate currentDate:(NSDate *)currDate previousEvent1Price:(NSNumber *)previousEv1Price previousEvent1RelatedPrice:(NSNumber *)previousEv1RelatedPrice currentPrice:(NSNumber *)currentEvPrice parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event exists by doing a case insensitive query on parent company Ticker and event type.
    // TO DO: Current assumption is that an event is uniquely identified by the combination of above 2 fields. This might need to change in the future.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type =[c] %@",eventTicker, eventType];
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    Event *existingEvent = nil;
    existingEvent  = [[dataStoreContext executeFetchRequest:eventFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting an event from data store, to insert associated history, failed: %@",error.description);
    }
    
    // If the event exists, insert the history associated with it
    if (existingEvent) {
        
        // Insert the history associated with the event
        EventHistory *history = [NSEntityDescription insertNewObjectForEntityForName:@"EventHistory" inManagedObjectContext:dataStoreContext];
        history.previous1Date = previousEv1Date;
        history.previous1Status = previousEv1Status;
        history.previous1RelatedDate = previousEv1RelatedDate;
        history.currentDate = currDate;
        history.previous1Price = previousEv1Price;
        history.previous1RelatedPrice = previousEv1RelatedPrice;
        history.currentPrice = currentEvPrice;
        history.parentEvent = existingEvent;
        
        // Perform the insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Saving event history to data store failed: %@",error.description);
        }
        // TO DO: Delete later. Currently for testing
        else {

        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not insert event history into data store because the parent event was not found in the data store");
    }
}

// Update non price related history, not including current date, associated with an event to the EventHistory Data Store given the previous event 1 date, status, related date, current date, Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
-(void)updateEventHistoryWithPreviousEvent1Date:(NSDate *)previousEv1Date previousEvent1Status:(NSString *)previousEv1Status previousEvent1RelatedDate:(NSDate *)previousEv1RelatedDate parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event history exists by doing a case insensitive query on the parent Event Company Ticker and Event Type.
    NSFetchRequest *historyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *historyEntity = [NSEntityDescription entityForName:@"EventHistory" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *historyPredicate = [NSPredicate predicateWithFormat:@"parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",eventTicker, eventType];
    [historyFetchRequest setEntity:historyEntity];
    [historyFetchRequest setPredicate:historyPredicate];
    NSError *error;
    EventHistory *existingHistory = nil;
    existingHistory  = [[dataStoreContext executeFetchRequest:historyFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting event history from data store, to update non price related data, failed: %@",error.description);
    }
    
    // If the event history exists update with given prices
    if (existingHistory) {
        
        // Only update the non price attributes, except the current date, leaving the others untouched
        existingHistory.previous1Date = previousEv1Date;
        existingHistory.previous1Status = previousEv1Status;
        existingHistory.previous1RelatedDate = previousEv1RelatedDate;
                
        // Perform the insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Saving event history, when updating the non price data, to data store failed: %@",error.description);
        }
        // TO DO: Delete later. Currently for testing
        else {

        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not update event history no price data in data store for event ticker %@ and event type %@ because the history was not found in the data store", eventTicker,eventType);
    }
}

// Update event history prices with the given previous event 1 date (prior quarterly earnings) stock price, previous event 1 related date (prior quarter end) stock price, current (right now yesterday's) stock price for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (void)updateEventHistoryWithPreviousEvent1Price:(NSNumber *)previousEv1Price previousEvent1RelatedPrice:(NSNumber *)previousEv1RelatedPrice currentPrice:(NSNumber *)currentEvPrice parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event history exists by doing a case insensitive query on the parent Event Company Ticker and Event Type.
    NSFetchRequest *historyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *historyEntity = [NSEntityDescription entityForName:@"EventHistory" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *historyPredicate = [NSPredicate predicateWithFormat:@"parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",eventTicker, eventType];
    [historyFetchRequest setEntity:historyEntity];
    [historyFetchRequest setPredicate:historyPredicate];
    NSError *error;
    EventHistory *existingHistory = nil;
    existingHistory  = [[dataStoreContext executeFetchRequest:historyFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting event history from data store, to update prices, failed: %@",error.description);
    }
    
    // If the event history exists update with given prices
    if (existingHistory) {
        
        // Only update the price attributes, leaving the others untouched
        existingHistory.previous1Price = previousEv1Price;
        existingHistory.previous1RelatedPrice = previousEv1RelatedPrice;
        existingHistory.currentPrice = currentEvPrice;
        
        // Perform the insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Saving event history to data store failed: %@",error.description);
        }
        // TO DO: Delete later. Currently for testing
        else {

        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not update event history prices in data store for event ticker %@ and event type %@ because the history was not found in the data store", eventTicker,eventType);
    }
}

// Update event history prices with the given previous event 1 date (30 days ago) stock price, previous event 1 related date (start of the year) stock price but no current stock price for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (void)updateEventHistoryWithPreviousEvent1Price:(NSNumber *)previousEv1Price previousEvent1RelatedPrice:(NSNumber *)previousEv1RelatedPrice parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event history exists by doing a case insensitive query on the parent Event Company Ticker and Event Type.
    NSFetchRequest *historyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *historyEntity = [NSEntityDescription entityForName:@"EventHistory" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *historyPredicate = [NSPredicate predicateWithFormat:@"parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",eventTicker, eventType];
    [historyFetchRequest setEntity:historyEntity];
    [historyFetchRequest setPredicate:historyPredicate];
    NSError *error;
    EventHistory *existingHistory = nil;
    existingHistory  = [[dataStoreContext executeFetchRequest:historyFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting event history from data store, to update prices, failed: %@",error.description);
    }
    
    // If the event history exists update with given prices
    if (existingHistory) {
        
        // Only update the price attributes, leaving the others untouched
        existingHistory.previous1Price = previousEv1Price;
        existingHistory.previous1RelatedPrice = previousEv1RelatedPrice;
        
        // Perform the insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Saving event history to data store failed: %@",error.description);
        }
        // TO DO: Delete later. Currently for testing
        else {
            
        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not update event history prices in data store for event ticker %@ and event type %@ because the history was not found in the data store", eventTicker,eventType);
    }
}

// Update event history with the current date
- (void)updateEventHistoryWithCurrentDate:(NSDate *)currDate parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event history exists by doing a case insensitive query on the parent Event Company Ticker and Event Type.
    NSFetchRequest *historyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *historyEntity = [NSEntityDescription entityForName:@"EventHistory" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *historyPredicate = [NSPredicate predicateWithFormat:@"parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",eventTicker, eventType];
    [historyFetchRequest setEntity:historyEntity];
    [historyFetchRequest setPredicate:historyPredicate];
    NSError *error;
    EventHistory *existingHistory = nil;
    existingHistory  = [[dataStoreContext executeFetchRequest:historyFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting event history from data store, to update current date, failed: %@",error.description);
    }
    
    // If the event history exists update with the current date
    if (existingHistory) {
        
        existingHistory.currentDate = currDate;
        
        // Perform the insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Updating current date on event history to data store failed: %@",error.description);
        }
        // TO DO: Delete later. Currently for testing
        else {

        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not update event history current date in data store for event ticker %@ and event type %@ because the history was not found in the data store", eventTicker,eventType);
    }
}

// Update event history with the current price
- (void)updateEventHistoryWithCurrentPrice:(NSNumber *)currPrice parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event history exists by doing a case insensitive query on the parent Event Company Ticker and Event Type.
    NSFetchRequest *historyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *historyEntity = [NSEntityDescription entityForName:@"EventHistory" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *historyPredicate = [NSPredicate predicateWithFormat:@"parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",eventTicker, eventType];
    [historyFetchRequest setEntity:historyEntity];
    [historyFetchRequest setPredicate:historyPredicate];
    NSError *error;
    EventHistory *existingHistory = nil;
    existingHistory  = [[dataStoreContext executeFetchRequest:historyFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting event history from data store, to update current date and price, failed: %@",error.description);
    }
    
    // If the event history exists update with the current date
    if (existingHistory) {
        
        existingHistory.currentPrice = currPrice;
        
        // Perform the insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Updating current date and price on event history to data store failed: %@",error.description);
        }
        // TO DO: Delete later. Currently for testing
        else {
            
        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not update event history current date and price in data store for event ticker %@ and event type %@ because the history was not found in the data store", eventTicker,eventType);
    }
}

// Get Event History for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (EventHistory *)getEventHistoryForParentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event history exists by doing a case insensitive query on the parent Event Company Ticker and Event Type.
    NSFetchRequest *historyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *historyEntity = [NSEntityDescription entityForName:@"EventHistory" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *historyPredicate = [NSPredicate predicateWithFormat:@"parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",eventTicker, eventType];
    [historyFetchRequest setEntity:historyEntity];
    [historyFetchRequest setPredicate:historyPredicate];
    NSError *error;
    EventHistory *existingHistory = nil;
    NSArray *eventHistories = [dataStoreContext executeFetchRequest:historyFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting event history from data store failed: %@",error.description);
    }
    if (eventHistories.count > 1) {
        NSLog(@"ERROR: Found more than 1 event history for ticker:%@ and event type:%@ in the Event History Data Store", eventTicker, eventType);
    }
    // If the event history exists return it
    if (eventHistories) {
        existingHistory = [eventHistories lastObject];
    }
    
    return existingHistory;
}

// Check to see if Event History exists for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (BOOL)doesEventHistoryExistForParentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL exists = NO;
    
    // Check to see if the event history exists by doing a case insensitive query on the parent Event Company Ticker and Event Type.
    NSFetchRequest *historyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *historyEntity = [NSEntityDescription entityForName:@"EventHistory" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *historyPredicate = [NSPredicate predicateWithFormat:@"parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",eventTicker, eventType];
    [historyFetchRequest setEntity:historyEntity];
    [historyFetchRequest setPredicate:historyPredicate];
    NSError *error;
    NSArray *eventHistories = [dataStoreContext executeFetchRequest:historyFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Retrieving event history, to check if it exists, from data store failed: %@",error.description);
    }
    if (eventHistories.count > 1) {
        NSLog(@"ERROR: Found more than 1 event history for ticker:%@ and event type:%@ in the Event History Data Store", eventTicker, eventType);
        exists = YES;
    }
    if (eventHistories.count == 1) {
        exists = YES;
    }
    
    return exists;
}

#pragma mark - Methods to call Company Data Source APIs

// Get a list of all companies and their tickers. The logic here takes care of determining from which point
// should the companies be fetched. It's smart enough to not do a full sync every time.
- (void)getAllCompaniesFromApi
{
    // To get all the companies use the metadata call of the Zacks Earnings Announcements (ZEA) database using
    // the following API: www.quandl.com/api/v3/datasets.json?database_code=ZEA&per_page=100&sort_by=id&page=1&auth_token=Mq-sCZjPwiJNcsTkUyoQ
    
    // The API endpoint URL
    NSString *endpointURL = @"https://www.quandl.com/api/v3/datasets.json?database_code=ZEA";
    
    // Set no of messages being returned per page to 100
    NSInteger noOfCompaniesPerPage = 100;
    // Set no of results pages to 1
    NSInteger noOfPages = 1;
    //  Temporary Storage for noOfPages
    NSInteger noOfPagesTemp = 1;
    // Set page no to 1
    NSInteger pageNo = 1;
    
    // Check to see if No Sync or a Seed Data Sync has been performed for company information.
    // In either of these scenarios, attempt a full sync from page 1 of the company API response.
    if ([[self getCompanySyncStatus] isEqualToString:@"NoSyncPerformed"]||[[self getCompanySyncStatus] isEqualToString:@"SeedSyncDone"]) {
        
        // Set the company sync status to "FullSyncStarted" and no page has been currently synced.
        [self upsertUserWithCompanySyncStatus:@"FullSyncStarted" syncedPageNo:[NSNumber numberWithInteger: 0]];
    }
    // Else, if any pages were successfully synced attempt a new sync from the company API page No after the one that was last successfully synced
    else if (([[self getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]||[[self getCompanySyncStatus] isEqualToString:@"FullSyncAttemptedButFailed"])&&[[self getCompanySyncedUptoPage] integerValue] != 0) {
        
        pageNo = ([[self getCompanySyncedUptoPage] integerValue] + 1);
        noOfPages = [[self getTotalNoOfCompanyPagesToSync] integerValue];
        
        // TO DO: For testing, comment before shipping
        // TO DO: Comment before shipping v2.7
        //NSLog(@"**************Entered the get all companies background thread with page No to start from:%ld", (long)pageNo);
    }
    
    // Retrieve first page to get no of pages and then keep retrieving till you get all pages.
    while (pageNo <= noOfPages) {
        
        // Append no of messages per page to the endpoint URL &per_page=300&page=1
        endpointURL = [NSString stringWithFormat:@"%@&per_page=%ld",endpointURL,(long)noOfCompaniesPerPage];
        
        // Append the &sort_by=id
        endpointURL = [NSString stringWithFormat:@"%@&sort_by=id",endpointURL];
        
        // Append page number to the API endpoint URL
        endpointURL = [NSString stringWithFormat:@"%@&page=%ld",endpointURL,(long)pageNo];
        
        // Append auth token to the call
        endpointURL = [NSString stringWithFormat:@"%@&auth_token=Mq-sCZjPwiJNcsTkUyoQ",endpointURL];
        
        NSError * error = nil;
        NSURLResponse *response = nil;
        
        // Make the call synchronously
        NSMutableURLRequest *companiesRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
        NSData *responseData = [self sendSynchronousRequest:companiesRequest returningResponse:&response error:&error];

        // TO DO: For testing, comment before shipping
        //NSLog(@"******************************************Made request to get company data with page number:%@**************",endpointURL);
        
        // Process the response
        if (error == nil)
        {
            // Process the response that contains the first page of companies.
            
            // TO DO: UNCOMMENT FOR PRE SEEDING DB:
            // If it's not already been entered, enter the total no of pages of companies to sync in the user data store. This should only be done once.
            /*noOfPagesTemp = [self processCompaniesResponse:responseData];
            if ([[self getTotalNoOfCompanyPagesToSync] integerValue] == -1) {
                [self updateUserWithTotalNoOfCompanyPagesToSync:[NSNumber numberWithInteger: noOfPagesTemp]];
            }*/
            // TO DO: COMMENT FOR PRE SEEDING DB:
            // Enter the total no of pages of companies to sync, each time a page response is processed.
            noOfPagesTemp = [self processCompaniesResponse:responseData];
            [self updateUserWithTotalNoOfCompanyPagesToSync:[NSNumber numberWithInteger: noOfPagesTemp]];
            
            // TO DO: Optimize to not hit the db everytime.
            // Get back total no of pages of companies in the response.
            noOfPages = [[self getTotalNoOfCompanyPagesToSync] integerValue];
            
            // Keep the company sync status to "FullSyncStarted" but update the page number of the API response to the page that just finished.
            [self upsertUserWithCompanySyncStatus:@"FullSyncStarted" syncedPageNo:[NSNumber numberWithInteger: pageNo]];
            
        }
        else
        {
            // If there is an error set the company sync status to "FullSyncAttemptedButFailed", meaning a full company sync was attempted but failed before it could complete
            [self upsertUserWithCompanySyncStatus:@"FullSyncAttemptedButFailed" syncedPageNo:[NSNumber numberWithInteger:(pageNo-1)]];
            NSLog(@"ERROR: Could not get companies data from the API Data Source. Error description: %@",error.description);
            
            // Show message to user to retry
            [self sendUserMessageCreatedNotificationWithMessage:@"Oops! Click Home button then Knotifi to refresh Tickers."];
            
            // TO DO: Test this, break out of this loop if say the connection timed out.
            break;
        }
        // TO DO: Solidify later when implementing incremental company sync: Checking if the call for a page of company data has failed (currently indicated by no of pages = 0)
        if (noOfPagesTemp != 0) {
            ++pageNo;
        }
        endpointURL = @"https://www.quandl.com/api/v3/datasets.json?database_code=ZEA";
        // TO DO: For testing, comment before shipping
        //NSLog(@"Page Number is:%ld and NoOfPages is:%ld",(long)pageNo,(long)noOfPages);
    }
    
    // Add or Update the Company Data Sync status to SeedSyncDone. Check that all pages have been processed before doing so.
    if ([[self getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&((pageNo-1) >= [[self getTotalNoOfCompanyPagesToSync] integerValue]))
    {
        [self upsertUserWithCompanySyncStatus:@"FullSyncDone" syncedPageNo:[NSNumber numberWithInteger:(pageNo-1)]];
        // TO DO: For testing, comment before shipping
        //NSLog(@"Set status to fullsyncdone");
    }
}

// Update the list of companies and their tickers, to include newer companies that have been added since the initial seeded DB. Whenever this is called, the logic here figures out how much needs to be synced. It relies on getAllCompaniesFromApi to do the actual sync. TO DO: Change this logic to go 2 pages behind what is the current total # of pages (74 as of April 8, 2016) after doing a fresh preseed.
- (void)getIncrementalCompaniesFromApi
{
    // Get the current total number of company pages that are synced (76 in the preseeded database) and sync from two pages before that page (74) till the newest page if there are more, to capture newly added companies. Do this only if the prior sync has completed successfully.
    if ([[self getCompanySyncStatus] isEqualToString:@"FullSyncDone"]) {
        
        // Set Currently Synced Upto Page
        NSInteger pageNoCurrentlySynced = 1;
        // 1 less than where you want to start the sync since actual sync starts after what has been synced. This will start the sync 3 pages before currently set expected to be 74
        pageNoCurrentlySynced = ([[self getCompanySyncedUptoPage] integerValue] - 4);
        
        // Set Company Sync Status to In Progress
        [self upsertUserWithCompanySyncStatus:@"FullSyncStarted" syncedPageNo:[NSNumber numberWithInteger:pageNoCurrentlySynced]];
        
        // TO DO: For testing, comment before shipping
        //NSLog(@"Set the status to FullSyncStarted. About to call getAllCompanies");
    }
    
    // Call the original companies sync method to start the incremental sync
    [self getAllCompaniesFromApi];
}

// Parse the companies API response and return total no of pages of companies in it.
// Before returning call on to formatting and adding companies data to the core data store.
- (NSInteger)processCompaniesResponse:(NSData *)response {
    
    NSError *error;
    
    // Set no of results pages to 1
    NSInteger noOfPages = 1;
    
    /* Here's the format of the v3 API response
     {
     "datasets":[
     {
     "id":15532344,
     "dataset_code":"CLDT",
     "database_code":"ZEA",
     "name":"Earnings Announcement Dates for Chatham Lodging Trust (CLDT)"
     }
     {......
     }]
     "meta":{
     "per_page":100,
     "query":"",
     "current_page":1,
     "prev_page":null,
     "total_pages":75,
     "total_count":7404,
     "next_page":2,
     "current_first_item":1,
     "current_last_item":100
     }
     }
    */
    
    // Get the response into a parsed object
    NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:response
                                                                   options:kNilOptions
                                                                     error:&error];
    
    // Call on to formatting and adding companies data to the core data store.
    [self formatAddCompanies:parsedResponse];
    
    // Get total no of pages of company data
    NSDictionary *metaInformation = [parsedResponse objectForKey:@"meta"];
    noOfPages = [[metaInformation objectForKey:@"total_pages"] integerValue];
    
    // TO DO: For testing, comment before shipping
    //NSLog(@"Total Number of pages dynamically computed: %ld ", (long)noOfPages);
    return noOfPages;
}

// Parse the list of companies and their tickers, format them and add them to the core data message store.
- (void)formatAddCompanies:(NSDictionary *)parsedResponse {
    
    /* Here's the format of the v3 API response
     {
     "datasets":[
     {
     "id":15532344,
     "dataset_code":"CLDT",
     "database_code":"ZEA",
     "name":"Earnings Announcement Dates for Chatham Lodging Trust (CLDT)"
     },
     {......
     }]
     "meta":{
     "per_page":100,
     "query":"",
     "current_page":1,
     "prev_page":null,
     "total_pages":75,
     "total_count":7404,
     "next_page":2,
     "current_first_item":1,
     "current_last_item":100
     }
     }
    */
    
    // Get the list of companies first from the overall response
    NSArray *parsedCompanies = [parsedResponse objectForKey:@"datasets"];
    
    // Then loop through the companies, get the appropriate fields and insert them into the data store
    for (NSDictionary *company in parsedCompanies) {
        
        // Get the company ticker and company name string
        NSString *companyTicker = [company objectForKey:@"dataset_code"];
        // Replace underscore in certain ticker names with . e.g.GRP_U -> GRP.U
        companyTicker = [companyTicker stringByReplacingOccurrencesOfString:@"_" withString:@"."];
        NSString *companyNameString = [company objectForKey:@"name"];
        // TO DO: For testing, comment before shipping
        //NSLog(@"Company Ticker to be entered in db is: %@ and Company Name String is: %@",companyTicker, companyNameString);
        
        // Extract the company name from the company name string
        NSRange forString = [companyNameString rangeOfString:@"for"];
        NSString *endTickerString = [NSString stringWithFormat:@"(%@)",companyTicker];
        NSRange endTicker = [companyNameString rangeOfString:endTickerString];
        NSRange companyNameRange = NSMakeRange(forString.location + 4, (endTicker.location - forString.location) - 5);
        NSString *companyName = [companyNameString substringWithRange:companyNameRange];
        // If there is a period at the end, remove it
        if ([companyName length] > 0) {
            if([companyName hasSuffix:@"."])
            {
                companyName = [companyName substringToIndex:[companyName length]-1];
            }
        }
        // TO DO: For testing, comment before shipping
        //NSLog(@"Company Name to be entered in db is: %@", companyName);
        
        // Add company ticker and name into the data store
        [self insertUniqueCompanyWithTicker:companyTicker name:companyName];
    }
}

#pragma mark - Methods to call Company Event Data Source APIs

// Get the event details for a company given it's ticker. NOTE: This is somewhat of a misnomer as this call only fetches the earnings event details not others like product events.
- (void)getAllEventsFromApiWithTicker:(NSString *)companyTicker
{
    // Get the event details for a company given it's ticker. Call the following API:
    // www.quandl.com/api/v3/datasets/ZEA/AAPL.json?auth_token=Mq-sCZjPwiJNcsTkUyoQ
    
    // The API endpoint URL
    NSString *endpointURL = @"https://www.quandl.com/api/v3/datasets/ZEA";
        
    // Append ticker for the company to the API endpoint URL
    // Format the ticker e.g. for V.HSR replace with V_HSR as this is how the API expects it
    NSString *formattedCompanyTicker  = [companyTicker stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    endpointURL = [NSString stringWithFormat:@"%@/%@.json",endpointURL,formattedCompanyTicker];
        
    // Append auth token to the call
    endpointURL = [NSString stringWithFormat:@"%@?auth_token=Mq-sCZjPwiJNcsTkUyoQ",endpointURL];
    
    // TO DO: DELETE: Use this endpoint for testing an incorrect API response.
    // NSString *endpointURL = @"https://www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA&per_page=300&page=1&auth_token=Mq-sCZjPwiJNcsTkUyoQ";
    
    // For the ticker HSBC use a custom URL where you are manually updating the json, since ZEA doesn't really track HSBC
    if ([companyTicker caseInsensitiveCompare:@"HSBC"] == NSOrderedSame) {
        endpointURL = @"https://gist.github.com/siddsingh/714f8c3897d644a66e116b633202b73e/raw/HSBC_Earnings.json";
    }
        
    NSError * error = nil;
    NSURLResponse *response = nil;
        
    // Make the call synchronously
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [self sendSynchronousRequest:eventsRequest returningResponse:&response error:&error];
    // Process the response
    if (error == nil)
    {
        // Process the response that contains the events for the company.
        [self processEventsResponse:responseData forTicker:companyTicker];
            
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get events data from the API Data Source. Error description: %@",error.description);
        
        // Show user an error message
        [self sendUserMessageCreatedNotificationWithMessage:@"Unable to fetch. Check Connection."];
    }
}

// Parse the events API response and add the following events information to the data store:
// 1. Quarterly Earnings
- (void)processEventsResponse:(NSData *)response forTicker:(NSString *)ticker {
    
    NSError *error;
    
    // For Quarterly Earnings event, we get the following pieces of information from the API response:
    // a) Date on which the event takes place
    // b) Details related to the event. "Quarterly Earnings" would have timing information
    // "After Market Close", "Before Market Open, "During Market Trading", "Unknown".
    // c) Date related to the event. "Quarterly Earnings" would have the end date of the next fiscal
    // quarter to be reported
    // d) Indicator if this event is "confirmed" or "speculated" or "unknown"
    //   {
    //   "dataset":{
    //  "data":[
    //     [
    //       "2015-04-09",
    //        20140930.0,
    //   Date related to the event
    //        20150331.0,
    //   Estimated EPS for the event
    //        2.13,
    //   Date on which the event takes place
    //        20150427.0,
    //        20150728.0,
    //        20151019.0,
    //        0.0,
    // Indicator if this event is "confirmed" or "speculated" or "unknown"
    // 1 (Company confirmed), 2 (Estimated based on algorithm) or 3 (Unknown)
    //        1.0,
    // Details related to the event
    // 1 (After market close), 2 (Before the open), 3 (During market trading) or 4 (Unknown)
    //        1.0,
    // Actual EPS for previously reported quarter
    //        3.06,
    // End date of previously reported quarter
    //        20141231.0,
    //        1.66,
    //        20140331.0
    //      ]
    //         ]
    // }
    
    // Get the response into a parsed object
    NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:response
                                                                   options:kNilOptions
                                                                     error:&error];
    
    // Get the overall Data Set from the response
    NSDictionary *parsedDataSet = [parsedResponse objectForKey:@"dataset"];
    
    // Get the list of data slices from the overall data set
    NSArray *parsedDataSets = [parsedDataSet objectForKey:@"data"];
    
    // TO DO: Delete Later. For testing purposes
    //NSLog(@"The parsed data set is:%@",parsedDataSets.description);
    
    // Check to make sure that the correct response has come back. e.g. If you get an error message response from the API,
    // then you don't want to process the data and enter as events.
    // If response is not correct, show the user an error message
    if (parsedDataSets == NULL)
    {
        [self sendUserMessageCreatedNotificationWithMessage:@"Unable to fetch. Try again later."];
    }
    // Else process response to enter event
    else
    {
        // Get the list and details of events which is essentially the first and only data set from the list of data sets
        NSArray *parsedEventsList = [parsedDataSets objectAtIndex:0];
        
        // Next get the different pices of information for the events depending on their position in the list and details of events
        
        // Set the type of event. Currently support:
        // 1) "Quarterly Earnings"
        NSString *eventType = @"Quarterly Earnings";
        //NSLog(@"The event type is: %@",eventType);
        
        // Get the date on which the event takes place which is the 5th item
        //NSLog(@"The date on which the event takes place: %@",[parsedEventsList objectAtIndex:4]);
        NSString *eventDateStr =  [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:4]];
        // Convert from string to Date
        NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
        [eventDateFormatter setDateFormat:@"yyyyMMdd"];
        NSDate *eventDate = [eventDateFormatter dateFromString:eventDateStr];
        //NSLog(@"The date on which the event takes place formatted as a Date: %@",eventDate);
        
        
        // Get Details related to the event which is the 10th item
        // For Quarterly Earnings: 1 (After Market Close), 2 (Before Market Open), 3 (During Market Trading) or 4 (Unknown)
        //NSLog(@"The timing details related to the event: %@",[parsedEventsList objectAtIndex:9]);
        NSString *eventDetails = [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:9]];
        // Convert to human understandable string
        if ([eventDetails isEqualToString:@"1"]) {
            eventDetails = [NSString stringWithFormat:@"After Market Close"];
        }
        if ([eventDetails isEqualToString:@"2"]) {
            eventDetails = [NSString stringWithFormat:@"Before Market Open"];
        }
        if ([eventDetails isEqualToString:@"3"]) {
            eventDetails = [NSString stringWithFormat:@"During Market Trading"];
        }
        if ([eventDetails isEqualToString:@"4"]) {
            eventDetails = [NSString stringWithFormat:@"Unknown"];
        }
        //NSLog(@"The timing details related to the event formatted: %@",eventDetails);
        
        
        // Get the Date related to the event which is the 3rd item
        // 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
        // to be reported
        // TO DO: For optimizing later: Can't I just reuse the event date formatter
        //NSLog(@"The quarter end date related to the event: %@",[parsedEventsList objectAtIndex:2]);
        NSString *relatedDateStr =  [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:2]];
        // Convert from string to Date
        NSDateFormatter *relatedDateFormatter = [[NSDateFormatter alloc] init];
        [relatedDateFormatter setDateFormat:@"yyyyMMdd"];
        NSDate *relatedDate = [relatedDateFormatter dateFromString:relatedDateStr];
        //NSLog(@"The quarter end date related to the event formatted as a Date: %@",relatedDate);
        
        // Get the end date of the previously reported quarter which is the 12th item
        NSString *priorEndDateStr =  [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:11]];
        NSDate *priorEndDate = [relatedDateFormatter dateFromString:priorEndDateStr];
        
        // Get the Estimated EPS for the event, which is the 4th item
        NSString *estimatedEps=  [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:3]];
        // Convert from string to number
        NSNumberFormatter *epsFormatter = [[NSNumberFormatter alloc] init];
        epsFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        NSNumber *estEpsNumber = [epsFormatter numberFromString:estimatedEps];
        
        // Get Actual EPS for previously reported quarter which is the 11th item
        NSString *actualPriorEps=  [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:10]];
        NSNumber *actualPriorEpsNumber = [epsFormatter numberFromString:actualPriorEps];
        
        // Get Indicator if this event is "Confirmed" or "Estimated" or "Unknown" which is the 9th item
        // 1 (Company confirmed), 2 (Estimated based on algorithm) or 3 (Unknown)
        //NSLog(@"The confirmation indicator for this event: %@",[parsedEventsList objectAtIndex:8]);
        NSString *certaintyStr = [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:8]];
        // Convert to human understandable string
        if ([certaintyStr isEqualToString:@"1"]) {
            certaintyStr = [NSString stringWithFormat:@"Confirmed"];
        }
        if ([certaintyStr isEqualToString:@"2"]) {
            certaintyStr = [NSString stringWithFormat:@"Estimated"];
        }
        if ([certaintyStr isEqualToString:@"3"]) {
            certaintyStr = [NSString stringWithFormat:@"Unknown"];
        }
        
        // Upsert events data into the data store
        [self upsertEventWithDate:eventDate relatedDetails:eventDetails relatedDate:relatedDate type:eventType certainty:certaintyStr listedCompany:ticker estimatedEps:estEpsNumber priorEndDate:priorEndDate actualEpsPrior:actualPriorEpsNumber];
        //NSLog(@"After updating event for ticker:%@ the event current quarter end date is:%@ and prior quarter end date is:%@",ticker, relatedDate,priorEndDate);
        
        // If this event just went from estimated to confirmed and there is a queued reminder to be created for it, fire a notification to create the reminder.
        // Similarly if this event just went from confirmed to confirmed and there is a created reminder that exists for it, fire a notification to create a new reminder.
        // TO DO: Optimize to not make this datastore call, when the user gets events for a ticker for the first time.
        if (([certaintyStr isEqualToString:@"Confirmed"]&&[self doesQueuedReminderActionExistForEventWithTicker:ticker eventType:eventType])||([certaintyStr isEqualToString:@"Confirmed"]&&[self doesReminderActionExistForEventWithTicker:ticker eventType:eventType])) {
            
            // Create array that contains {eventType,companyTicker,eventDateText} to pass on to the notification
            NSString *notifEventType = [NSString stringWithFormat: @"%@", eventType];
            NSString *notifCompanyTicker = [NSString stringWithFormat: @"%@", ticker];
            // Format the eventDateText to include the timing details
            // Show the event date
            NSDateFormatter *notifEventDateFormatter = [[NSDateFormatter alloc] init];
            [notifEventDateFormatter setDateFormat:@"EEEE MMMM dd"];
            NSString *notifEventDateTxt = [notifEventDateFormatter stringFromDate:eventDate];
            NSString *notifEventTimeString = eventDetails;
            // Append related details (timing information) to the event date if it's known
            if (![notifEventTimeString isEqualToString:@"Unknown"]) {
                //Format "After Market Close","Before Market Open", "During Market Trading" to be "After Close" & "Before Open" & "During Open"
                if ([notifEventTimeString isEqualToString:@"After Market Close"]) {
                    notifEventTimeString = [NSString stringWithFormat:@"After Close"];
                }
                if ([notifEventTimeString isEqualToString:@"Before Market Open"]) {
                    notifEventTimeString = [NSString stringWithFormat:@"Before Open"];
                }
                if ([notifEventTimeString isEqualToString:@"During Market Trading"]) {
                    notifEventTimeString = [NSString stringWithFormat:@"While Open"];
                }
                notifEventDateTxt = [NSString stringWithFormat:@"%@ %@ ",notifEventDateTxt,notifEventTimeString];
            }
            
            // Fire the notification, passing on the necessary information
            [self sendCreateReminderNotificationWithEventInformation:@[notifEventType, notifCompanyTicker, notifEventDateTxt]];
        }
        
        // If this event just went from confirmed to estimated and there is a created reminder that exists for it, set it's status to
        // Queued to indicate that a new rimder needs to be created for the next earnings call, when it gets confirmed.
        if ([certaintyStr isEqualToString:@"Estimated"]&&[self doesReminderActionExistForEventWithTicker:ticker eventType:eventType]) {
            
            [self updateActionWithStatus:@"Queued" type:@"OSReminder" eventTicker:ticker eventType:eventType];
        }
    }
}

#pragma mark - Methods to call Company names and tickers from local files

// Get all company tickers and names from local code, which currently is hard coded here and write them to the data store. This is the one place you need add new tickers, including product ones.
// NOTE!!!!!!!!Add a any new tickers here as we won't be syncing from file anymore.
- (void)getAllTickersAndNamesFromLocalCode {
    
    // Please make sure to add any new cryptocurrencies or newer tickers with product events to FADataController->updateEventsFromRemoteIfNeeded as well to make sure they are always present before prod events are synced.
    // FOR BTC: First add all the tickers for cryptocurrencies just to be sure these are in the db.
    [self insertUniqueCompanyWithTicker:@"BTC" name:@"Bitcoin"];
    [self insertUniqueCompanyWithTicker:@"ETHR" name:@"Ethereum"];
    [self insertUniqueCompanyWithTicker:@"BCH$" name:@"Bitcoin Cash"];
    [self insertUniqueCompanyWithTicker:@"XRP" name:@"Ripple"];
    
    // Also add newer ones with product events first
    [self insertUniqueCompanyWithTicker:@"BB" name:@"Blackberry"];
    [self insertUniqueCompanyWithTicker:@"FIT" name:@"Fitbit"];
    [self insertUniqueCompanyWithTicker:@"GOOGL" name:@"Google"];
    [self insertUniqueCompanyWithTicker:@"GPRO" name:@"Go Pro"];
    [self insertUniqueCompanyWithTicker:@"NTDOY" name:@"Nintendo"];
    [self insertUniqueCompanyWithTicker:@"SNAP" name:@"Snap Inc"];
    [self insertUniqueCompanyWithTicker:@"ROKU" name:@"Roku"];
    
    // First add the new tickers since 11/19/2016 manually
    [self insertUniqueCompanyWithTicker:@"MULE" name:@"MuleSoft Inc"];
    [self insertUniqueCompanyWithTicker:@"NTNX" name:@"Nutanix Inc"];
    [self insertUniqueCompanyWithTicker:@"GOOS" name:@"Canada Goose Holdings"];
    [self insertUniqueCompanyWithTicker:@"JILL" name:@"J.Jill"];
    [self insertUniqueCompanyWithTicker:@"AYX" name:@"Alteryx"];
    [self insertUniqueCompanyWithTicker:@"OKTA" name:@"Okta"];
    [self insertUniqueCompanyWithTicker:@"YEXT" name:@"Yext"];
    [self insertUniqueCompanyWithTicker:@"CLDR" name:@"Cloudera"];
    [self insertUniqueCompanyWithTicker:@"APRN" name:@"Blue Apron Holdings"];
    
    // Added these on 10/06/2017
    [self insertUniqueCompanyWithTicker:@"SWCH" name:@"Switch"];
    [self insertUniqueCompanyWithTicker:@"DCPH" name:@"Deciphera Pharmaceuticals"];
    [self insertUniqueCompanyWithTicker:@"RDFN" name:@"Redfin"];
    
    
    // Added these starting 11/09
    [self insertUniqueCompanyWithTicker:@"SNCR" name:@"Synchronoss Technologies"];
    [self insertUniqueCompanyWithTicker:@"SFIX" name:@"Stitch Fix"];
    
    // Missing
    [self insertUniqueCompanyWithTicker:@"TWLO" name:@"Twilio"];
    
    // TO DO: For testing, comment before shipping.Keeping it around for future pre seeding testing.
    // Delete before shipping v4.3
    //NSLog(@"Ended the background get incremental companies from local HARD CODE");
}

// Get all company tickers and names from local files, which currently is a csv file and write them to the data store.
- (void)getAllTickersAndNamesFromLocalStorage
{
    // Get the company ticker and names file path
    NSString *tickersFilePath = [[NSBundle mainBundle] pathForResource:@"ZEA-datasets-codes_20161119" ofType:@"csv"];
    // TO DO: Delete Later
    //NSLog(@"Found the json file at: %@",tickersFilePath);
    
    // Parse the file contents
    // ***IMPORTANT: When using a new file search for " and remove the " and , in the string that contains names
    // e.g. "Ulta Salon, Cosmetics & Fragrance Inc" should be Ulta Salon Cosmetics & Fragrance Inc
    
    // Get the contents into a parsed object
    NSError *error;
    NSMutableArray *tickerStrs = [NSMutableArray array];
    NSMutableArray *nameStrs = [NSMutableArray array];
    
    NSString *tickersStr = [[NSString alloc] initWithContentsOfFile:tickersFilePath encoding:NSUTF8StringEncoding error:&error];
    NSArray* tickerRows = [tickersStr componentsSeparatedByString:@"\n"];
    for (NSString *tickerRow in tickerRows){
        
        if (![tickerRow isEqualToString:@""] ) {
            NSArray* tickerColumns = [tickerRow componentsSeparatedByString:@","];
            [tickerStrs addObject:tickerColumns[0]];
            [nameStrs addObject:tickerColumns[1]];
        }
    }
    
    // Loop through the tickers and add the tickers and names to the database
    int tickerIndex = 0;
    NSString *companyTicker = nil;
    NSString *companyNameString = nil;
    NSRange forString;
    NSString *endTickerString = nil;
    NSRange endTicker;
    NSRange companyNameRange;
    NSString *companyName = nil;
    
    for (NSString *tickerStr in tickerStrs) {
        
        // Get the company ticker and company name string
        companyTicker = tickerStr;
        // Strip out ZEA/
        companyTicker = [companyTicker stringByReplacingOccurrencesOfString:@"ZEA/" withString:@""];
        // Replace underscore in certain ticker names with . e.g.GRP_U -> GRP.U
        companyTicker = [companyTicker stringByReplacingOccurrencesOfString:@"_" withString:@"."];

        companyNameString = [nameStrs objectAtIndex:tickerIndex];
        
        // Extract the company name from the company name string
        forString = [companyNameString rangeOfString:@"for"];
        endTickerString = [NSString stringWithFormat:@"(%@)",companyTicker];
        endTicker = [companyNameString rangeOfString:endTickerString];
        companyNameRange = NSMakeRange(forString.location + 4, (endTicker.location - forString.location) - 5);
        companyName = [companyNameString substringWithRange:companyNameRange];
        // If there is a period at the end, remove it
        if ([companyName length] > 0) {
            if([companyName hasSuffix:@"."])
            {
                companyName = [companyName substringToIndex:[companyName length]-1];
            }
        }
        
        // Add company ticker and name into the data store
        [self insertUniqueCompanyWithTicker:companyTicker name:companyName];
        
        ++tickerIndex;
    }
    
    // Some cleanup
    // There are two tickers with the same company name T.BB and BBRY -> Blackberry Ltd This is messing up the app, so setting T.BB to say Blackberry Ltd Old
    [self deleteCompanyWithTicker:@"T.BB"];
    
}

#pragma mark - Methods to call Economic Events Data Sources

// Get all the economic events and details from local storage, which currently is a json file and write them to the data store.
- (void)getAllEconomicEventsFromLocalStorage
{
    // Get the economic events file path
    NSString *eventsFilePath = [[NSBundle mainBundle] pathForResource:@"EconomicEvents_2018" ofType:@"json"];
    // TO DO: Delete Later
    //NSLog(@"Found the json file at: %@",eventsFilePath);
    
    // Parse the economic events file contents
    
    // Get the contents into a parsed object
    NSError *error;
    NSString *eventsJsonStr = [[NSString alloc] initWithContentsOfFile:eventsFilePath encoding:NSUTF8StringEncoding error:&error];
    NSDictionary *parsedContents = [NSJSONSerialization JSONObjectWithData:[eventsJsonStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
    
    // Loop through the parsed object to get the various economic events and their details
    // Get the list of events first
    NSArray *parsedEvents = [parsedContents objectForKey:@"eventSets"];
    
    for (NSDictionary *event in parsedEvents) {
        
        // Get the event name
        NSString *eventName = [event objectForKey:@"name"];
        // TO DO: Delete Later
        //NSLog(@"The event name: %@", eventName);
        
        // Get the event identifier
        NSString *eventId = [event objectForKey:@"identifier"];
        // TO DO: Delete Later
        //NSLog(@"The event identifier: %@", eventId);
        
        // Get the agency that puts out the event
        NSString *eventAgency = [event objectForKey:@"agency"];
        // TO DO: Delete Later
        //NSLog(@"The event agency: %@", eventAgency);
        
        // Insert the ticker and name for the event in the company data store
        [self insertUniqueCompanyWithTicker:eventId name:eventAgency];
        
        // Get the short description for the event. Currently hardcoded. Use it later.
        //NSString *eventDesc = [event objectForKey:@"shortDescription"];
        // TO DO: Delete Later
        //NSLog(@"The event short description: %@", eventDesc);
        
        // Get the URL for getting more info on the event
        NSString *eventMoreInfoUrl = [event objectForKey:@"moreInfoUrl"];
        // TO DO: Delete Later
        //NSLog(@"The event more info Url: %@", eventMoreInfoUrl);
        
        // Get the array of upcoming dates
        NSArray *eventInstances = [event objectForKey:@"instances"];
        
        // Get the individual upcoming instances like Jan Fed Meeting, Mar Fed Meeting, etc and the
        // dates for each
        for (NSDictionary *eventInstance in eventInstances) {
            
            // Get Related Period to form unique event name for each instance of the Fed Meeting by prepending it to event name.
            NSString *eventRelatedInfo = [eventInstance objectForKey:@"relatedPeriod"];
            NSString *uniqueName = [NSString stringWithFormat:@"%@ %@", eventRelatedInfo, eventName];
            // TO DO: Delete Later
            //NSLog(@"The event unique name is: %@", uniqueName);
            
            // Get the date for the event instance
            NSNumber *eventDateAsNum = [eventInstance objectForKey:@"date"];
            // TO DO: Delete Later
            //NSLog(@"The date on which the event takes place: %@", eventDateAsNum);
            NSString *eventDateStr =  [NSString stringWithFormat: @"%@", eventDateAsNum];
            NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
            [eventDateFormatter setDateFormat:@"yyyyMMdd"];
            NSDate *eventDate = [eventDateFormatter dateFromString:eventDateStr];
            // TO DO: Delete Later
            //NSLog(@"The date on which the event takes place formatted as a Date: %@",eventDate);
            
            // Insert each instance into the events datastore
            [self upsertEventWithDate:eventDate relatedDetails:eventMoreInfoUrl relatedDate:nil type:uniqueName certainty:eventRelatedInfo listedCompany:eventId estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
        }
    }
}

#pragma mark - Methods for Product Events Data

// Get all the product events and details from the data source APIs
- (void)getAllProductEventsFromApi
{
    // TO DO: Delete this later as we are getting this from the cloud now
    // Get the product events file path
   /* NSString *eventsFilePath = [[NSBundle mainBundle] pathForResource:@"ProductEvents_2016_Local" ofType:@"json"];
    // TO DO: Delete Later
    NSLog(@"Found the json file at: %@",eventsFilePath);
    
    // Parse the product events file contents
     This is the current JSON structure of the response
     "productEvents":[
     {
     "ticker":"AAPL",
     "name":"iPhone 7",
     "type":"Product_Launch",
     "date":20160915,
     "time":"NA",
     "impact":"Very High",
     "impactDescription":"About 62% of Apple's revenues.",
     "moreInfoTitle":"iPhone 7 Roundup on Mac Rumors",
     "moreInfoUrl":"http://www.macrumors.com/roundup/iphone-7/",
     "updatedOn":20160510,
     "confidence":0.5,
     "approved":1.0
     },
    
    // Get the contents into a parsed object
    NSError *error;
    NSString *eventsJsonStr = [[NSString alloc] initWithContentsOfFile:eventsFilePath encoding:NSUTF8StringEncoding error:&error];
    NSDictionary *parsedContents = [NSJSONSerialization JSONObjectWithData:[eventsJsonStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error]; */
    
    // Get all the product events and their details from the Knotifi Data Platform. Call the following API:
    // 104.197.243.153/productevent/
    /* This is the current JSON structure of the response
     "responseData":[
     {
     "impact":"Very High",
     "confidence":0.5,
     "name":"iPhone 7",
     "exactTimeLabel":"12:00:00 AM ET",
     "ticker":"AAPL",
     "moreInfoTitle":"iPhone 7 Roundup on Mac Rumors",
     "approved":true,
     "updated":"2016-05-10",
     "impactDescription":"The iPhone is about 62% of Apple's revenue.",
     "date":"2016-09-15",
     "exactTime":"2016-09-15T00:00:00 US/Eastern",
     "type":"Product_Launch",
     "id":1,
     "moreInfoUrl":"http://www.macrumors.com/roundup/iphone-7"
     }, */
    
    // The API endpoint URL  http://104.155.142.172/
    // Old endpoint URL
    // NSString *endpointURL = @"http://104.197.243.153/productevent/";
    NSString *endpointURL = @"http://104.155.142.172/productevent/";
    NSError * error = nil;
    NSURLResponse *response = nil;
    
    // Make the call synchronously
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [self sendSynchronousRequest:eventsRequest returningResponse:&response error:&error];
    
    // Process the response
    if (error == nil)
    {
        // TO DO: Delete Later, for testing
        //NSLog(@"The endpoint being called for getting product events information is:%@",endpointURL);
        //NSLog(@"The API response for getting product events information is:%@",[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]);
        
        // Process the response that contains the events for the company.
        // Get the response into a parsed object
        NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:responseData
                                                                       options:kNilOptions
                                                                         error:&error];
        
        // Loop through the parsed object to get the various product events and their details
        // Get the list of events first
        NSArray *parsedEvents = [parsedResponse objectForKey:@"responseData"];
        
        for (NSDictionary *event in parsedEvents) {
            
            // Get the ticker for the event's parent company
            NSString *parentTicker = [event objectForKey:@"ticker"];
            // TO DO: Delete Later
            //NSLog(@"The event parent company is: %@", parentTicker);
            
            // Get the event raw name e.g. iPhone 7
            NSString *eventName = [event objectForKey:@"name"];
            // TO DO: Delete Later
            //NSLog(@"The event raw name is: %@", eventName);
            
            // Get the event type
            NSString *eventType = [event objectForKey:@"type"];
            // TO DO: Delete Later
            //NSLog(@"The event type is: %@", eventType);
            
            // Construct the formatted event name from raw name and event type e.g. iPhone 7 Launch
            NSArray *typeComponents = [eventType componentsSeparatedByString:@"_"];
            eventName = [eventName stringByAppendingString:@" "];
            eventName = [eventName stringByAppendingString:typeComponents.lastObject];
            // TO DO: Delete Later
            //NSLog(@"The event formatted name is: %@", eventName);
            
            // Get the event date
            NSString *eventDateStr =  [event objectForKey:@"date"];
            NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
            [eventDateFormatter setDateFormat:@"yyyy-MM-dd"];
            NSDate *eventDate = [eventDateFormatter dateFromString:eventDateStr];
            // TO DO: Delete Later
            //NSLog(@"The date on which the event takes place formatted as a Date: %@",eventDate);
            
            // Get the time label
            NSString *timeLabel = [event objectForKey:@"exactTimeLabel"];
            // TO DO: Delete Later
            //NSLog(@"The event time label is: %@", timeLabel);
            
            // TO DO: Fix when you add a new table in the data model for event characteristics.
            // For Product Events, we overload a field in Event History called previous1Status to store a string representing Impact, Impact Description, More Info Title and More Info Url i.e. (Impact_Impact Description_MoreInfoTitle_MoreInfoUrl)
            NSString *eventAddtlInfo = [NSString stringWithFormat:@"%@_%@_%@_%@", [event objectForKey:@"impact"], [event objectForKey:@"impactDescription"], [event objectForKey:@"moreInfoTitle"], [event objectForKey:@"moreInfoUrl"]];
            // TO DO: Delete Later
            //NSLog(@"The event addtl info with Impact, Impact Description, More Info Title and More Info Url is: %@", eventAddtlInfo);
            
            // Get the updated on date
            NSString *updatedOnDateStr = [event objectForKey:@"updated"];
            NSDate *updatedOnDate = [eventDateFormatter dateFromString:updatedOnDateStr];
            // TO DO: Delete Later
            //NSLog(@"The updated on date formatted as a Date: %@",updatedOnDate);
            
            // Construct if the event is "Estimated" or "Confirmed" based on confidence value
            // Currently, keeping it simple, if the confidence is 0.5 it's estimated, if it's 1.0 it's confirmed.
            NSString *confidenceStr = [NSString stringWithFormat: @"%@", [event objectForKey:@"confidence"]];
            if ([confidenceStr isEqualToString:@"0.5"]) {
                confidenceStr = @"Estimated";
            }
            if ([confidenceStr isEqualToString:@"1"]) {
                confidenceStr = @"Confirmed";
            }
            // TO DO: Delete Later
            //NSLog(@"The confidence string is: %@",confidenceStr);
            
            // Check if this event is approved or not. Only if approved it will be added to local data store.
            // Before updating, check if the earnings event for that company exists. If not, sync it.
            BOOL approved = [[event objectForKey:@"approved"] boolValue];
            // FOR BTC & ETHR & BCH$ & XRP event addition, add the condition that is the event is BTC or ETHR, sync it even if it is not approved. This is to ensure that only folks that have upgraded to this version get the events, older ones don't since the events in the db are not approved. It's probably safe to mark the events of these types as approved in the DB after about 2 mos after the release of this version. Follow this process for any new product event types.
            // Old way where we only respect approved.
            //if(approved) {
            if((approved)||([parentTicker caseInsensitiveCompare:@"BTC"] == NSOrderedSame)||([parentTicker caseInsensitiveCompare:@"ETHR"] == NSOrderedSame)||([parentTicker caseInsensitiveCompare:@"BCH$"] == NSOrderedSame)||([parentTicker caseInsensitiveCompare:@"XRP"] == NSOrderedSame))  {
                
                // Check if earnings event exists for this ticker. If not fetch it, since we don't want a company that has only a product event and no earnings event.
                // FOR BTC or ETHR or BCH$ or XRP, Check if BTC or ETHR and don't fetch quarterly earnings,if so.
                if (!(([parentTicker caseInsensitiveCompare:@"BTC"] == NSOrderedSame)||([parentTicker caseInsensitiveCompare:@"ETHR"] == NSOrderedSame)||([parentTicker caseInsensitiveCompare:@"BCH$"] == NSOrderedSame)||([parentTicker caseInsensitiveCompare:@"XRP"] == NSOrderedSame))) {
                    if(![self doesEventExistForParentEventTicker:parentTicker andEventType:@"Quarterly Earnings"]) {
                        // TO DO: Delete before shipping v4.3
                        //NSLog(@"About to fetch earnings for ticker:%@",parentTicker);
                        [self getAllEventsFromApiWithTicker:parentTicker];
                    }
                }
                // Insert each instance into the events datastore
                [self upsertEventWithDate:eventDate relatedDetails:timeLabel relatedDate:updatedOnDate type:eventName certainty:confidenceStr listedCompany:parentTicker estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
                
                // TO DO: Fix when you add a new table in the data model for event characteristics.
                // For Product Events, we overload a field in Event History called previous1Status to store a string representing Impact, Impact Description, More Info Title and More Info Url i.e. (Impact_Impact Description_MoreInfoTitle_MoreInfoUrl)
                [self insertHistoryWithPreviousEvent1Date:nil previousEvent1Status:eventAddtlInfo previousEvent1RelatedDate:nil currentDate:nil previousEvent1Price:nil previousEvent1RelatedPrice:nil currentPrice:nil parentEventTicker:parentTicker parentEventType:eventName];
                
                // If the ticker is being followed and there is no queued reminder for this event, it means it's a new event. Create a queued reminder for it even if it's confirmed, since in the very next step it will create the reminder. Also this ensures that the event is added to the following list.
                if ([self isBeingFollowed:parentTicker]&&(![self doesReminderActionExistForSpecificEvent:eventName])) {
                    [self insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:parentTicker eventType:eventName];
                }
                
                // If this product event just went from estimated to confirmed and there is a queued reminder to be created for it, and the event is not in the past, fire a notification to create the reminder.
                if ([confidenceStr isEqualToString:@"Confirmed"]&&[self doesQueuedReminderActionExistForEventWithTicker:parentTicker eventType:eventName]&&([self calculateDistanceFromEventDate:eventDate] <= 0)) {
                    //TO DO: For testing, delete before shipping v 2.5
                    //NSLog(@"This product event just went from estimated to confirmed:%@ %@ with status string:%@",parentTicker,eventName,confidenceStr);
                    // Create array that contains {eventType,companyTicker,eventDateText} to pass on to the notification
                    NSString *notifEventType = [NSString stringWithFormat: @"%@", eventName];
                    NSString *notifCompanyTicker = [NSString stringWithFormat: @"%@", parentTicker];
                    // Format the eventDateText to include the timing details
                    // Show the event date
                    NSDateFormatter *notifEventDateFormatter = [[NSDateFormatter alloc] init];
                    [notifEventDateFormatter setDateFormat:@"EEEE MMMM dd"];
                    NSString *notifEventDateTxt = [notifEventDateFormatter stringFromDate:eventDate];
                    NSString *notifEventTimeString = timeLabel;
                    // Append timing information to the event date if it's known
                    notifEventDateTxt = [NSString stringWithFormat:@"%@ %@ ",notifEventDateTxt,notifEventTimeString];
                    
                    // Fire the notification, passing on the necessary information
                    [self sendCreateReminderNotificationWithEventInformation:@[notifEventType, notifCompanyTicker, notifEventDateTxt]];
                }
                
            } else {
                // TO DO: Delete Later
                //NSLog(@"This entry is NOT APPROVED");
            }
        }
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get product events data from the API Data Source. Error description: %@",error.description);
    }
}

// Check to see if 1) product events have been synced initially. 2) If there are new entries for product events on the server side. In either of these cases return true
// NOTE: If there is a new type of product event like launch or conference is added, add that here as well
// *****NOTE*****Currently always returning true since we have not implemented update logic
- (BOOL)doProductEventsNeedToBeAddedRefreshed
{
    // Check if product events are present in the local db
    /*NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL needed = NO;
    
    // Get all events of type product events.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the event type filter.
    // NOTE: If there is a new type of product event like launch or conference is added, add that here as well
    NSPredicate *typePredicate = [NSPredicate predicateWithFormat:@"type contains[cd] %@ OR type contains[cd] %@", @"Launch", @"Conference"];
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:typePredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting events, while checking for product events existence, from data store failed: %@",error.description);
    }
    // If the events do not exist, return yes
    if (events.count == 0) {
        needed = YES;
    }
    
    // TO DO: Uncomment Before shipping v2.5 if server side work here is ready.
    // Code for when you are adding server side check for new additions to the server side events.
    // Call API to see if true, false if there are new approved events added.
    //   Parse API response
    //   If true, set needed = YES;
    
    return needed;*/
    
    return YES;
}

// Wrapper method to get product events from the API. Currently fetches all product events.
- (void)syncProductEventsWrapper {
    
    // Show busy
    dispatch_async(dispatch_get_main_queue(), ^{
        // TO DO: Delete Later
        //NSLog(@"About to start busy spinner");
        [[NSNotificationCenter defaultCenter]postNotificationName:@"StartBusySpinner" object:self];
    });
    
    [self getAllProductEventsFromApi];
    
    // Stop Busy
    dispatch_async(dispatch_get_main_queue(), ^{
        // TO DO: Delete Later.
        //NSLog(@"About to stop busy spinner");
        [self sendEventsChangeNotification];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"StopBusySpinner" object:self];
    });
}


#pragma mark - Methods for Price Change Data

// Get all the price change events and details from the data source APIs. This is the new version that uses the same data source as used for getting prices elsewhere.
- (void)getAllPriceChangeEventsFromApiNew
{
    // Call the Price change data source API to get the price change events. The API is:
    // marketdata.websol.barchart.com/getQuote.json?key=9d040a74abe6d5df65a38df9b4253809&symbols=UA,FB,GPRO
    
    // First construct the string for all the tickers that are being tracked. This is basically all the tickers for whom we have quarterly earnings events, since earnings events is the superset of tickers that have events.
    NSFetchedResultsController *eventsController = [self getAllFutureEarningsEvents];
    NSArray *fetchedEvents = [eventsController fetchedObjects];
    NSMutableString *tickersToFetch = [NSMutableString stringWithString:@""];
    for (Event *fetchedEvent in fetchedEvents) {
        
        [tickersToFetch appendString:fetchedEvent.listedCompany.ticker];
        [tickersToFetch appendString:@","];
    }
    [tickersToFetch deleteCharactersInRange:NSMakeRange([tickersToFetch length]-1, 1)];
    
    // Construct the API URL to call
    NSString *endpointURL = @"http://marketdata.websol.barchart.com/getQuote.json?key=9d040a74abe6d5df65a38df9b4253809&symbols=";
    NSString *addtlFields = @"&fields=fiftyTwoWkHigh,fiftyTwoWkHighDate,fiftyTwoWkLow,fiftyTwoWkLowDate";
    endpointURL = [NSString stringWithFormat:@"%@%@%@",endpointURL,tickersToFetch,addtlFields];
    
    NSURLResponse *response = nil;
    
    // Make the call synchronously
    NSError *error;
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [self sendSynchronousRequest:eventsRequest returningResponse:&response error:&error];
    
    // This is the API response
    /* {
     "status":{
     "code":200,
     "message":"Success."
     },
     "results":[
     {
     "symbol":"UA",
     "exchange":"BATS",
     "name":"Under Armour",
     "dayCode":"3",
     "serverTimestamp":"2016-11-06T09:18:17-06:00",
     "mode":"i",
     "lastPrice":30.8,
     "tradeTimestamp":"2016-11-03T00:00:00-05:00",
     "netChange":30.8,
     "percentChange":0,
     "unitCode":null,
     "open":0,
     "high":0,
     "low":0,
     "close":"",
     "flag":"",
     "volume":0
     },*/
    
    // Process the response
    if (error == nil)
    {
        // Process the response that contains the price information for the company
        NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:responseData
                                                                       options:kNilOptions
                                                                         error:&error];
        
        // Get the list of data slices from the overall data set
        NSArray *parsedDataSets = [parsedResponse objectForKey:@"results"];
        
        // TO DO: Delete Later before shipping v2.7
        //NSLog(@"The parsed quote response data set is:%@",parsedDataSets.description);
        
        // Check to make sure that the correct response has come back. e.g. If you get an error message response from the API,
        // then you don't want to process the data and enter as historical prices.
        // If response is not correct, show the user an error message
        if ([parsedDataSets.description isEqualToString:@"<null>"])
        {
            // TO DO: Ideally show user an error message but currently for simplicity we want to keep this transparent to the user.
            // TO DO: Delete Later before shipping v2.7
            //NSLog(@"Trapping the current price error");
            
        }
        // Else process response to enter historical prices
        else
        {
            NSNumber *percentChangeSinceYest = [[NSNumber alloc] initWithFloat:0.0];
            NSNumber *currPrice = [[NSNumber alloc] initWithFloat:0.0];
            NSString *currPriceStr = nil;
            NSString *specificEventType = nil;
            NSString *companySymbol = nil;
            NSString *percentChangeSinceYestStr = nil;
            // Set the event date to today by default
            NSDate *eventDate = [NSDate date];
            NSString *eventDateStr = nil;
            NSArray *dateComponents;
            NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
            [eventDateFormatter setDateFormat:@"yyyy-MM-dd"];
            // TO DO: Use later when you want to work with times as well
            //[eventDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss-HH:mm"];
            
            // Iterate through price array within the parsed data set, which only contains one dictionary.
            for (NSDictionary *parsedDetailsList in parsedDataSets) {
                
                // Check if that ticker price is not null. If it is continue without processing it.The commented line might be a better way but couldn't test it hence going with the old way.
                // if ([parsedDetailsList objectForKey:@"netChange"] == (id)[NSNull null])
                if ([[NSString stringWithFormat:@"%@",[parsedDetailsList objectForKey:@"mode"]] containsString:@"null"])
                {
                    continue;
                }
                ////// Get daily price change
                
                // Get the company ticker
                companySymbol = [parsedDetailsList objectForKey:@"symbol"];
                
                // Get the last trade date
                dateComponents = [[parsedDetailsList objectForKey:@"tradeTimestamp"] componentsSeparatedByString:@"T"];
                eventDateStr =  [NSString stringWithFormat: @"%@", dateComponents[0]];
                // Convert from string to Date
                eventDate = [eventDateFormatter dateFromString:eventDateStr];
                //NSLog(@"The date on which the event takes place formatted as a Date: %@",eventDate);
            
                // Get percentage changed since yesterday
                percentChangeSinceYest = [NSNumber numberWithDouble:[[parsedDetailsList objectForKey:@"percentChange"] doubleValue]];
                
                // Get a string representation for the change
                percentChangeSinceYestStr = [NSString stringWithFormat:@"%.02f",[percentChangeSinceYest doubleValue]];
                
                // Get current price
                currPrice = [NSNumber numberWithDouble:[[parsedDetailsList objectForKey:@"lastPrice"] doubleValue]];
                // Format the current price string
                currPriceStr = [NSString stringWithFormat:@"%.02f",[currPrice doubleValue]];
                
                // Get whatever the daily price change is
                if([percentChangeSinceYest doubleValue] >= 0.0) {
                    
                    specificEventType = [NSString stringWithFormat:@"+%@%% up today $%@",percentChangeSinceYestStr,currPriceStr];
                    // Insert into the events datastore
                    // Note the upsert logic takes care of matching the generic piece of the event type to uniquely identify this event ensuring there's only one instance of this.
                    [self upsertEventWithDate:eventDate relatedDetails:nil relatedDate:nil type:specificEventType certainty:nil listedCompany:companySymbol estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
                    // Check to see if a reminder action has already been created for the quarterly earnings event for this ticker, which means this ticker is already being followed. In which case add a "PriceChange" action type to indicate this is a followed event.
                    // TO DO: Hardcoding this for now to be quarterly earnings
                    if ([self doesReminderActionExistForEventWithTicker:companySymbol eventType:@"Quarterly Earnings"]){
                        [self insertActionOfType:@"PriceChange" status:@"Queued" eventTicker:companySymbol eventType:specificEventType];
                    }
                }
                if([percentChangeSinceYest doubleValue] < 0.0) {
                    
                    percentChangeSinceYestStr = [percentChangeSinceYestStr substringFromIndex:1];
                    specificEventType = [NSString stringWithFormat:@"-%@%% down today $%@",percentChangeSinceYestStr,currPriceStr];
                    // Insert into the events datastore
                    // Note the upsert logic takes care of matching the generic piece of the event type to uniquely identify this event ensuring there's only one instance of this.
                    [self upsertEventWithDate:eventDate relatedDetails:nil relatedDate:nil type:specificEventType certainty:nil listedCompany:companySymbol estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
                    // Check to see if a reminder action has already been created for the quarterly earnings event for this ticker, which means this ticker is already being followed. In which case add a "PriceChange" action type to indicate this is a followed event.
                    // TO DO: Hardcoding this for now to be quarterly earnings
                    if ([self doesReminderActionExistForEventWithTicker:companySymbol eventType:@"Quarterly Earnings"]){
                        [self insertActionOfType:@"PriceChange" status:@"Queued" eventTicker:companySymbol eventType:specificEventType];
                    }
                }
                
                ////// Get 52 week highs
                NSString *hiLoEventStr = nil;
                NSNumber *hiLoPrice = [[NSNumber alloc] initWithFloat:0.0];
                
                eventDateStr = [parsedDetailsList objectForKey:@"fiftyTwoWkHighDate"];
                eventDate = [eventDateFormatter dateFromString:eventDateStr];
                hiLoPrice = [NSNumber numberWithDouble:[[parsedDetailsList objectForKey:@"fiftyTwoWkHigh"] doubleValue]];
                hiLoEventStr = [NSString stringWithFormat:@"%.02f",[hiLoPrice doubleValue]];
                
                specificEventType = [NSString stringWithFormat:@"52 Week High $%@",hiLoEventStr];
                [self upsertEventWithDate:eventDate relatedDetails:nil relatedDate:nil type:specificEventType certainty:nil listedCompany:companySymbol estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
                // Check to see if a reminder action has already been created for the quarterly earnings event for this ticker, which means this ticker is already being followed. In which case add a "PriceChange" action type to indicate this is a followed event.
                // TO DO: Hardcoding this for now to be quarterly earnings
                if ([self doesReminderActionExistForEventWithTicker:companySymbol eventType:@"Quarterly Earnings"]){
                    [self insertActionOfType:@"PriceChange" status:@"Queued" eventTicker:companySymbol eventType:specificEventType];
                }
                
                ////// Get 52 week lows
                
                eventDateStr = [parsedDetailsList objectForKey:@"fiftyTwoWkLowDate"];
                eventDate = [eventDateFormatter dateFromString:eventDateStr];
                hiLoPrice = [NSNumber numberWithDouble:[[parsedDetailsList objectForKey:@"fiftyTwoWkLow"] doubleValue]];
                hiLoEventStr = [NSString stringWithFormat:@"%.02f",[hiLoPrice doubleValue]];
                
                specificEventType = [NSString stringWithFormat:@"52 Week Low $%@",hiLoEventStr];
                [self upsertEventWithDate:eventDate relatedDetails:nil relatedDate:nil type:specificEventType certainty:nil listedCompany:companySymbol estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
                // Check to see if a reminder action has already been created for the quarterly earnings event for this ticker, which means this ticker is already being followed. In which case add a "PriceChange" action type to indicate this is a followed event.
                // TO DO: Hardcoding this for now to be quarterly earnings
                if ([self doesReminderActionExistForEventWithTicker:companySymbol eventType:@"Quarterly Earnings"]){
                    [self insertActionOfType:@"PriceChange" status:@"Queued" eventTicker:companySymbol eventType:specificEventType];
                }
            }
        }
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get price events data from the API Data Source in the new way as used in the client. Error description: %@",error.description);
    }
}

// Get all the price change events and details from the data source APIs. This is the old data source that we don't use anymore
- (void)getAllPriceChangeEventsFromApi
{
    // Call the Price change data source API to get the price change events. The API is:
    // 104.197.243.153/ticker/prices/MSFT,AAPL,GM,BABA,UA,TSLA,GOOGL,SQ,EA,FB,GPRO,ANET,SNE,ATVI,BOX,LULU,ORCL,NKE,BAC/changes

    // First construct the string for all the tickers that are being tracked. This is basically all the tickers for whom we have quarterly earnings events, since earnings events is the superset of tickers that have events.
    NSFetchedResultsController *eventsController = [self getAllFutureEarningsEvents];
    NSArray *fetchedEvents = [eventsController fetchedObjects];
    NSMutableString *tickersToFetch = [NSMutableString stringWithString:@""];
    for (Event *fetchedEvent in fetchedEvents) {
        
        [tickersToFetch appendString:fetchedEvent.listedCompany.ticker];
        [tickersToFetch appendString:@","];
    }
    [tickersToFetch deleteCharactersInRange:NSMakeRange([tickersToFetch length]-1, 1)];
    
    // Construct the API URL to call
    NSString *endpointURL = @"http://104.197.243.153/ticker/prices/";
    endpointURL = [NSString stringWithFormat:@"%@%@/changes",endpointURL,tickersToFetch];
    NSURLResponse *response = nil;
    
    // Make the call synchronously
    NSError *error;
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [self sendSynchronousRequest:eventsRequest returningResponse:&response error:&error];
    
    /* This is the current JSON structure of the response
     "responseData" : -{
     "BABA" : -{
     "alert_ytd" : true,
     "last" : 102.38,
     "alert_30days" : false,
     "change_1day" : -0.39,
     "change_30days" : -1.98,
     "30_day_threshold" : 10,
     "change_ytd" : 33.5,
     "last_date" : 2016-10-27T00:00:00,
     "ytd_day_threshold" : 20,
     "1_day_threshold" : 5,
     "1_day_ago" : 102.78,
     "alert_1day" : false,
     "30_days_ago" : 104.45,
     "start_of_year" : 76.69
     },
     "BOX" : -{
     "alert_ytd" : false,
     "last" : 14.53,
     "alert_30days" : false,
     "change_1day" : -1.22,
     "change_30days" : -2.22,
     "30_day_threshold" : 10,
     "change_ytd" : 1.18,
     "last_date" : 2016-10-27T00:00:00,
     "ytd_day_threshold" : 20,
     "1_day_threshold" : 5,
     "1_day_ago" : 14.71,
     "alert_1day" : false,
     "30_days_ago" : 14.86,
     "start_of_year" : 14.36
     }, */
    
    // Process the response
    if (error == nil)
    {
        // TO DO: Delete Later, for testing
        //NSLog(@"The endpoint being called for getting product events information is:%@",endpointURL);
        //NSLog(@"The API response for getting product events information is:%@",[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]);
        
        // Process the response that contains the events for the company.
        // Get the response into a parsed object
        NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:responseData
                                                                       options:kNilOptions
                                                                         error:&error];
        NSDictionary *parsedEvents = [parsedResponse objectForKey:@"responseData"];
        
        // Loop through the parsed events
        NSDictionary *event = nil;
        for(id key in parsedEvents) {
            
            // Get the ticker for the event's parent company
            NSString *parentTicker = key;
            // TO DO: Delete Later
            NSLog(@"The event parent company is: %@", parentTicker);
            
            // Get the event/s associated with the ticker
            event = [parsedEvents objectForKey:key];
            
            // Get the 1d alarm status
            BOOL dailyAlarm = [[event objectForKey:@"alert_1day"] boolValue];
            // TO DO: Delete Later
            NSLog(@"The 1d alarm status is: %d", dailyAlarm);
            // Get the 1d change string
            NSString *dailyChangeStr = [NSString stringWithFormat: @"%@", [event objectForKey:@"change_1day"]];
            // TO DO: Delete Later
            NSLog(@"The 1d change is: %@%%", dailyChangeStr);
            
            // Get the 30 days alarm status
            BOOL thirtyAlarm = [[event objectForKey:@"alert_30days"] boolValue];
            // TO DO: Delete Later
            NSLog(@"The 30 days alarm status is: %d", thirtyAlarm);
            // Get the 30 days change string
            NSString *thirtyChangeStr = [NSString stringWithFormat: @"%@", [event objectForKey:@"change_30days"]];
            // TO DO: Delete Later
            NSLog(@"The 30 days change is: %@%%", thirtyChangeStr);
            
            // Get the ytd alarm status
            BOOL ytdAlarm = [[event objectForKey:@"alert_ytd"] boolValue];
            // TO DO: Delete Later
            NSLog(@"The ytd alarm status is: %d", ytdAlarm);
            // Get the ytd change string
            NSString *ytdChangeStr = [NSString stringWithFormat: @"%@", [event objectForKey:@"change_ytd"]];
            // TO DO: Delete Later
            NSLog(@"The ytd alarm status is: %@%%", ytdChangeStr);
            
            // Check if any of the alarms are true. If yes, add them to the events db as a price change event
            NSDate *todaysDate = [NSDate date];
            NSString *specificEventType = nil;
            
            // If daily alarm is true, add it to the db
            if(dailyAlarm) {
                
                // Construct the event type string which is generic in the following section % down today but preceded by specific %
                if ([dailyChangeStr containsString:@"-"]) {
                    dailyChangeStr = [dailyChangeStr substringFromIndex:1];
                    specificEventType = [NSString stringWithFormat:@"%@%% down today",dailyChangeStr];
                } else {
                    specificEventType = [NSString stringWithFormat:@"%@%% up today",dailyChangeStr];
                }
                
                // Insert into the events datastore
                // Note the upsert logic takes care of matching the generic piece of the event type to uniquely identify this event ensuring there's only one instance of this.
                [self upsertEventWithDate:todaysDate relatedDetails:nil relatedDate:nil type:specificEventType certainty:nil listedCompany:parentTicker estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
            }
            
            // If 30 days alarm is true, add it to the db if the following conditions are met: a) There hasn't been a 30 days alarm of the same type in the last 7 days. This is to ensure we are only triggering the 30 days price change a max of 4 times in a month.
            if(thirtyAlarm) {
                
                
                // Construct the event type string which is generic in the following section % down 30 days but preceded by specific %
                if ([thirtyChangeStr containsString:@"-"]) {
                    thirtyChangeStr = [thirtyChangeStr substringFromIndex:1];
                    specificEventType = [NSString stringWithFormat:@"%@%% down 30 days",thirtyChangeStr];
                } else {
                    specificEventType = [NSString stringWithFormat:@"%@%% up 30 days",thirtyChangeStr];
                }
                      
                if (![self doesPriceChangeEventExistFor:parentTicker parentEventType:specificEventType]) {
                    // Insert into the events datastore
                    // Note the upsert logic takes care of matching the generic piece of the event type to uniquely identify this event ensuring there's only one instance of this.
                    [self upsertEventWithDate:todaysDate relatedDetails:nil relatedDate:nil type:specificEventType certainty:nil listedCompany:parentTicker estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
                }
            }

            // If ytd alarm is true, add it to the db if the following conditions are met: a) There hasn't been a ytd alarm of the same type in the last 15 days. This is to ensure we are only triggering the ytd price change a max of 2 times in a month.
            if(ytdAlarm) {
                
                
                // Construct the event type string which is generic in the following section % down ytd but preceded by specific %
                if ([ytdChangeStr containsString:@"-"]) {
                    ytdChangeStr = [ytdChangeStr substringFromIndex:1];
                    specificEventType = [NSString stringWithFormat:@"%@%% down ytd",ytdChangeStr];
                } else {
                    specificEventType = [NSString stringWithFormat:@"%@%% up ytd",ytdChangeStr];
                }
                
                if (![self doesPriceChangeEventExistFor:parentTicker parentEventType:specificEventType]) {
                    // Insert into the events datastore
                    // Note the upsert logic takes care of matching the generic piece of the event type to uniquely identify this event ensuring there's only one instance of this.
                    [self upsertEventWithDate:todaysDate relatedDetails:nil relatedDate:nil type:specificEventType certainty:nil listedCompany:parentTicker estimatedEps:nil priorEndDate:nil actualEpsPrior:nil];
                }
            }
        }
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get price events data from the API Data Source. Error description: %@",error.description);
    }
}

// Return if a 30 day or ytd price change alarm already exists. For the 30 days alarm to already exist the following conditions should be met: a) There's been a 30 days alarm of the same type in the last 7 days. This is to ensure we are only triggering the 30 days price change a max of 4 times in a month. For ytd the conditions are: a) There has been a ytd alarm in the last 15 days
- (BOOL)doesPriceChangeEventExistFor:(NSString *)eventTicker parentEventType:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL exists = NO;
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // For price change events the event type is a fuzzy match.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventPredicate = nil;
    // For 30 days change event - % down 30 days
    if ([eventType containsString:@"% down 30 days"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",eventTicker,@"% down 30 days"];
    }
    // For 30 days change event - % up 30 days
    else if ([eventType containsString:@"% up 30 days"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",eventTicker,@"% up 30 days"];
    }
    // For year to date change event - % down ytd
    else if ([eventType containsString:@"% down ytd"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",eventTicker,@"% down ytd"];
    }
    // For year to date change event - % up ytd
    else if ([eventType containsString:@"% up ytd"]) {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type contains %@",eventTicker,@"% up ytd"];
    }
    // If not a price change event, it's an exact match to the type string
    else {
        eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type =[c] %@",eventTicker,eventType];
    }

    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting a price change event, while checking for it's existence, from data store failed: %@",error.description);
    }
    if (events.count > 1) {
        NSLog(@"ERROR: Found more than 1 price change event for ticker:%@ and event type:%@ in the Event Data Store", eventTicker, eventType);
    }
    // If the event exists, check for conditions and set return value accordingly.
    if (events.count >= 1) {
        
        Event *existingEvent = nil;
        existingEvent  = events[0];
        
        // For 30 days change events check to see if this event was under 7 days ago and if yes return true
        if ([eventType containsString:@"30 days"]) {
            
            if([self calculateDistanceFromEventDate:existingEvent.date] < 7) {
                exists = YES;
            }
        }
        
        // For ytd change events check to see if this event was under 15 days ago and if yes return true
        if ([eventType containsString:@"ytd"]) {
                   
            if([self calculateDistanceFromEventDate:existingEvent.date] < 15) {
                exists = YES;
            }
        }
    }
    
    // else return false
    return exists;
}

// Delete all daily change events from the db
- (void)deleteAllDailyPriceChangeEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // For price change events the event type is a fuzzy match.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    
    // Filter for daily events
    NSPredicate *eventPredicate = nil;
    eventPredicate = [NSPredicate predicateWithFormat:@"type contains %@ AND type contains %@",@"%",@"today"];
    
    // Fetch all the daily events
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting a daily price change event, while trying to delete all of them, from data store failed: %@",error.description);
    }
    
    // Delete all the daily events
    for (NSManagedObject *dailyEvent in events) {
        
        [dataStoreContext deleteObject:dailyEvent];
    }
    
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
}

// Delete all 52 wk events from the db
- (void)deleteAll52WkEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // For price change events the event type is a fuzzy match.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    
    // Filter for daily events
    NSPredicate *eventPredicate = nil;
    eventPredicate = [NSPredicate predicateWithFormat:@"(type contains %@) OR (type contains %@)",@"52 Week High",@"52 Week Low"];
    
    // Fetch all the daily events
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting a daily price change event, while trying to delete all of them, from data store failed: %@",error.description);
    }
    
    // Delete all the daily events
    for (NSManagedObject *dailyEvent in events) {
        
        [dataStoreContext deleteObject:dailyEvent];
    }
    
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
}

// Get all price change events. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllPriceChangeEventsForFollowedStocks
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    //NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all future events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    // Set the filter. Get price change events with date clause
    //NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND (ANY actions.type == %@)", todaysDate, @"PriceChange"];
    // Set the filter. Get price change events with no date clause
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"(ANY actions.type == %@)", @"PriceChange"];
    [eventFetchRequest setPredicate:datePredicate];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"listedCompany.ticker" ascending:YES];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all price change events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}


// Get the date on which the events were last synced
- (NSDate *)getDailyPriceEventSyncDate {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [NSDate date];
    
    // Subtract 7 days
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = -7;
    NSDate *weekAgoDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:todaysDate options:0];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // For price change events the event type is a fuzzy match.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    
    // Filter for daily events
    NSPredicate *eventPredicate = nil;
    eventPredicate = [NSPredicate predicateWithFormat:@"type contains %@ AND type contains %@",@"%",@"today"];
    
    // Fetch all the daily events
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    NSArray *events = [dataStoreContext executeFetchRequest:eventFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting daily price change events, while trying to get their sync date, from data store failed: %@",error.description);
    }
    
    if (events.count == 0) {
        return weekAgoDate;
        
    } else {
        Event *fetchedEvent = [events lastObject];
        return fetchedEvent.date;
    }
}

// Wrapper method to get price change events from the API for all followed stocks
- (void)getPriceChangeEventsForFollowingStocksWrapper {
    
    // Show busy
    dispatch_async(dispatch_get_main_queue(), ^{
        // TO DO: Delete Later
        //NSLog(@"About to start busy spinner");
        [[NSNotificationCenter defaultCenter]postNotificationName:@"StartBusySpinner" object:self];
    });
    
    // Get latest snapshot of price change events
    [self getAllPriceChangeEventsFromApiNew];
    
    // Stop Busy
    dispatch_async(dispatch_get_main_queue(), ^{
        // TO DO: Delete Later.
        //NSLog(@"About to stop busy spinner");
        [self sendEventsChangeNotification];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"StopBusySpinner" object:self];
    });
    
    // TRACKING EVENT: Explicitly track Price fetch events
    // TO DO: Disabling to not track development events. Enable before shipping.
    [FBSDKAppEvents logEvent:@"Price Fetched"
                  parameters:@{ @"Event Type" : @"Daily Price" } ];
}

// Wrapper method to get price details for an event
- (NSString *)getPriceDetailsForEventOfType:(NSString *)cellEventType withTicker:(NSString *)cellCompanyTicker {
    
    // Show busy
    dispatch_async(dispatch_get_main_queue(), ^{
        // TO DO: Delete Later
        //NSLog(@"About to start busy spinner");
        [[NSNotificationCenter defaultCenter]postNotificationName:@"StartBusySpinner" object:self];
    });
    
    // Get and Set all the price details.
    // Get the database level (not display level) event type based on the display type.
    // Earnings -> Quarterly Earnings, Fed Meeting -> Jan Fed Meeting, Jobs Report -> Jan Jobs Report and so on.
    NSString *currPriceAndChangeStr = @"NA";
    NSString *eventType = cellEventType;
    
    // If Quarterly Earnings or price change event or product event get the historical data for display in the details
    // We basically use the quarterly earnings event history to keep track of the stock prices for price change events since there cannot be a price change event for a ticker that we don't have the quarterly earnings for. Same with product event
    if ([eventType isEqualToString:@"Quarterly Earnings"]||[eventType containsString:@"% up"]||[eventType containsString:@"% down"]||[eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        
        // Get the ticker for the Quarterly Earnings
        NSString *eventTicker = cellCompanyTicker;
        
        // Since we  use the quarterly earnings event history to keep track of the stock prices for price change events, use the Quarterly Earnings as the event type, even for price change events
        eventType = @"Quarterly Earnings";
        
        // Add whatever history related data you have in the event data store to the event history data store, if it's not already been added before
        // Get today's date
        NSDate *todaysDate = [NSDate date];
        
        // If Event history doesn't exist insert it
        if (![self doesEventHistoryExistForParentEventTicker:eventTicker parentEventType:eventType])
        {
            // Insert history, with previous event 1 date being the market open date 30 days ago and previous event 1 related date being the market open date at the beginning of the year.
            // NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
            NSNumber *emptyPlaceholder = [[NSNumber alloc] initWithFloat:999999.9];
            // To Do: Delete when shipping v2.9
            //NSLog(@"The 30 days ago date when inserting history is:%@",[self scrubDateToNotBeWeekendOrHoliday:[self computeDate30DaysAgoFrom:todaysDate]]);
            [self insertHistoryWithPreviousEvent1Date:[self scrubDateToNotBeWeekendOrHoliday:[self computeDate30DaysAgoFrom:todaysDate]] previousEvent1Status:@"Estimated" previousEvent1RelatedDate:[self computeMarketStartDateOfTheYearFrom:todaysDate] currentDate:todaysDate previousEvent1Price:emptyPlaceholder previousEvent1RelatedPrice:emptyPlaceholder currentPrice:emptyPlaceholder parentEventTicker:eventTicker parentEventType:eventType];
        }
        // Else update the non price related data, not including current date, on the event history from the event. We don't include the current date as current date is set only once a day which is when the user first accesses the event.
        else
        {
            [self updateEventHistoryWithPreviousEvent1Date:[self scrubDateToNotBeWeekendOrHoliday:[self computeDate30DaysAgoFrom:todaysDate]] previousEvent1Status:@"Estimated" previousEvent1RelatedDate:[self computeMarketStartDateOfTheYearFrom:todaysDate] parentEventTicker:eventTicker parentEventType:eventType];
        }
        
        // Call price API, in the main thread, to refresh the price history
        // Check to see if the current date on which the price history was fetched is today or not in addition to if it was fetched at all. If today, fetch only current price. If not, then fetch both historical and current price
        EventHistory *selectedEventHistory = [self getEventHistoryForParentEventTicker:eventTicker parentEventType:eventType];
        // Set a value indicating that a value is not available. Currently a Not Available value
        // is represented by 999999.9
        double notAvailable = 999999.9f;
        double prev1PriceDbl = [[selectedEventHistory previous1Price] doubleValue];
        double prev1RelatedPriceDbl = [[selectedEventHistory previous1RelatedPrice] doubleValue];
        double currentPriceDbl = [[selectedEventHistory currentPrice] doubleValue];
        NSDateFormatter *checkDateFormatter = [[NSDateFormatter alloc] init];
        [checkDateFormatter setDateFormat:@"yyyy-MM-dd"];
        // Format historical and now current dates to local time zone comparison
        NSString *currentDateInHistory = [checkDateFormatter stringFromDate:selectedEventHistory.currentDate];
        NSString *currentDateNow = [checkDateFormatter stringFromDate:todaysDate];
        if ((prev1PriceDbl == notAvailable)||(prev1RelatedPriceDbl == notAvailable)||(currentPriceDbl == notAvailable)||([currentDateInHistory caseInsensitiveCompare:currentDateNow] != NSOrderedSame))
        {
            currPriceAndChangeStr = [self getPricesWithCompanyTicker:eventTicker eventType:eventType historyFetch:YES];
            // Current date is set only once a day which is when the user first accesses the event.
            [self updateEventHistoryWithCurrentDate:todaysDate parentEventTicker:eventTicker parentEventType:eventType];
        } else {
            currPriceAndChangeStr = [self getPricesWithCompanyTicker:eventTicker eventType:eventType historyFetch:NO];
        }
    }
    
    // Stop Busy
    dispatch_async(dispatch_get_main_queue(), ^{
        // TO DO: Delete Later.
        //NSLog(@"About to stop busy spinner");
        [self sendEventsChangeNotification];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"StopBusySpinner" object:self];
    });
    
    return currPriceAndChangeStr;
}

// Get stock prices for company given a ticker and event type (event info). Executes in the main thread.
- (NSString *)getPricesWithCompanyTicker:(NSString *)ticker eventType:(NSString *)type historyFetch:(BOOL)fetchHistory;
{
    EventHistory *eventForPricesFetch = [self getEventHistoryForParentEventTicker:ticker parentEventType:type];
    NSString *currPriceAndChange = @"NA";
    
    // Get current price and set the global current price and change string to the value returned.
    currPriceAndChange = [self getCurrentStockPriceFromApiForTicker:ticker companyEventType:type];
    
    // TRACKING EVENT: Explicitly track Price fetch events
    // TO DO: Disabling to not track development events. Enable before shipping.
    [FBSDKAppEvents logEvent:@"Price Fetched"
                  parameters:@{ @"Event Type" : @"Daily Price" } ];
    
    // Get historical prices if needed
    if(fetchHistory) {
        
        // See which one is before in time, the ytd date or 30 days ago date and set from date to that.
        if ([(eventForPricesFetch.previous1Date) timeIntervalSinceDate:(eventForPricesFetch.previous1RelatedDate)] > 0) {
            
            [self getStockPricesFromApiForTicker:ticker companyEventType:type fromDateInclusive:eventForPricesFetch.previous1RelatedDate toDateInclusive:eventForPricesFetch.currentDate];
            
            // TRACKING EVENT: Explicitly track Price fetch events
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"Price Fetched"
                          parameters:@{ @"Event Type" : @"Price History" } ];
        } else {
            
            [self getStockPricesFromApiForTicker:ticker companyEventType:type fromDateInclusive:eventForPricesFetch.previous1Date toDateInclusive:eventForPricesFetch.currentDate];
            
            // TRACKING EVENT: Explicitly track Price fetch events
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"Price Fetched"
                          parameters:@{ @"Event Type" : @"Price History" } ];
        }
    }

    return currPriceAndChange;
}

#pragma mark - Methods to call Company Stock Data Source APIs

// Get the historical stock prices for a company given it's ticker and the event type for which the historical data is being asked for. Currently only supported event type is Quarterly Earnings. Also, the listed company ticker and event type, together represent the event uniquely. Finally, the most current stock price that we have is yesterday.
- (void)getStockPricesFromApiForTicker:(NSString *)companyTicker companyEventType:(NSString *)eventType fromDateInclusive:(NSDate *)fromDate toDateInclusive:(NSDate *)toDate {
    
    // Get the event details for a company given it's ticker. Call the following API:
    // TO DO: Delete once the marketdata API has been live for a while
    // www.quandl.com/api/v3/datasets/WIKI/AAPL.json?auth_token=Mq-sCZjPwiJNcsTkUyoQ&start_date=2015-01-01&end_date=2015-01-10
    
    // The API endpoint URL
    /*NSString *endpointURL = @"https://www.quandl.com/api/v3/datasets/WIKI";
    
    // Append ticker for the company to the API endpoint URL
    // Format the ticker e.g. for V.HSR replace with V_HSR as this is how the API expects it
    NSString *formattedCompanyTicker  = [companyTicker stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    endpointURL = [NSString stringWithFormat:@"%@/%@.json",endpointURL,formattedCompanyTicker];
    
    // Append auth token to the call
    endpointURL = [NSString stringWithFormat:@"%@?auth_token=Mq-sCZjPwiJNcsTkUyoQ",endpointURL];
     
     // Append formatted start date and end date to the call
     // Note: The from date in the response is one day after the given from date in the call. Thus make the call with a day earlier. Thus subtract a day from the from date.
     NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
     NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
     differenceDayComponents.day = -1;
     NSDate *fromDateMinus1Day = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:fromDate options:0];
     NSDateFormatter *priceDateFormatter = [[NSDateFormatter alloc] init];
     [priceDateFormatter setDateFormat:@"yyyy-MM-dd"];
     NSString *fromDateInclusiveString = [priceDateFormatter stringFromDate:fromDateMinus1Day];
     NSString *toDateInclusiveString = [priceDateFormatter stringFromDate:toDate];
     endpointURL = [NSString stringWithFormat:@"%@&start_date=%@&end_date=%@",endpointURL,fromDateInclusiveString,toDateInclusiveString]; */
    
    // The API endpoint URL
    // marketdata.websol.barchart.com/getHistory.json?key=9d040a74abe6d5df65a38df9b4253809&symbol=AAPL&type=daily&startDate=20160331000000
    NSString *endpointURL = @"http://marketdata.websol.barchart.com/getHistory.json?key=9d040a74abe6d5df65a38df9b4253809";
    
    // Append Ticker
    // Format the ticker e.g. for V.HSR replace with V_HSR as this is how the API expects it
    NSString *formattedCompanyTicker  = [companyTicker stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    endpointURL = [NSString stringWithFormat:@"%@&symbol=%@",endpointURL,formattedCompanyTicker];
    
    // Append the formatted Start Date minus 7 days just to be safe
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = -7;
    NSDate *fromDateMinus1Day = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:fromDate options:0];
    NSDateFormatter *priceDateFormatter = [[NSDateFormatter alloc] init];
    [priceDateFormatter setDateFormat:@"yyyyMMdd"];
    NSString *fromDateInclusiveString = [priceDateFormatter stringFromDate:fromDateMinus1Day];
    endpointURL = [NSString stringWithFormat:@"%@&type=daily&startDate=%@000000",endpointURL,fromDateInclusiveString];
    
    NSError * error = nil;
    NSURLResponse *response = nil;
    
    // Make the call synchronously
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [self sendSynchronousRequest:eventsRequest returningResponse:&response error:&error];
    
    // Process the response
    if (error == nil)
    {
        // Process the response that contains the events for the company.
        [self processStockPricesResponse:responseData forTicker:companyTicker forEventType:eventType];
        
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get price data from the API Data Source. Error description: %@",error.description);
        
        // TO DO: Ideally show user an error message but currently for simplicity we want to keep this transparent to the user.
    }
}

// Parse the stock prices API response and add the historical prices to the event history.Currently recording only previous event 1 (prior quarterly earnings) date closing stock price, previous related event 1 (prior quarter end date closing price and current price (yesterday's closing price).NOTE: Yesterday's closing price is based on what the current date is on the history object.
- (void)processStockPricesResponse:(NSData *)response forTicker:(NSString *)ticker forEventType:(NSString *)type {
    
    NSError *error;
    
    /*
     This is the ticker API response. Please note:
     1) The from date in the response is one day after the given from date in the call. Thus make the call with a day earlier.
     2) Get the adjusted close price as the stock price for that day.
     Currently recording only previous event 1 (prior quarterly earnings) date closing stock price, previous related event 1 (prior quarter end date closing price and current price (yesterday's closing price).
     NOTE: Yesterday's closing price is based on what the current date is on the history object
     {
     "dataset":{
     "id":9775409,
     "dataset_code":"AAPL",
     "database_code":"WIKI",
     "name":"Apple Inc. (AAPL)",
     "description":"blahblah.....",
     "refreshed_at":"2015-10-16T21:46:47.729Z",
     "newest_available_date":"2015-10-16",
     "oldest_available_date":"1980-12-12",
     "column_names":[
     // Date for the corresponding stock price
     "Date",
     "Open",
     "High",
     "Low",
     "Close",
     "Volume",
     "Ex-Dividend",
     "Split Ratio",
     "Adj. Open",
     "Adj. High",
     "Adj. Low",
     // Stock price to get 12th item
     "Adj. Close",
     "Adj. Volume"
     ],
     "frequency":"daily",
     "type":"Time Series",
     "premium":false,
     "limit":null,
     "transform":null,
     "column_index":null,
     "start_date":"2013-06-30",
     "end_date":"2015-10-15",
     "data":[
     [
     "2015-10-15",
     110.93,
     112.1,
     110.49,
     111.8,
     37270444.0,
     0.0,
     1.0,
     110.93,
     112.1,
     110.49,
     111.8,
     37270444.0
     ],
     .....
     
     [
     "2013-07-01",
     402.69,
     412.27,
     401.22,
     409.22,
     13966200.0,
     0.0,
     1.0,
     54.95288588449,
     56.260215708358,
     54.752283082706,
     55.84399901078,
     97763400.0
     ]
     */
    /* TO DO: Delete later once the market data API has been live for a bit
    // Get the response into a parsed object
    NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:response
                                                                   options:kNilOptions
                                                                     error:&error];
    
    // Get the overall Data Set from the response
    NSDictionary *parsedDataSet = [parsedResponse objectForKey:@"dataset"];
    
    // Get the list of data slices from the overall data set
    NSArray *parsedDataSets = [parsedDataSet objectForKey:@"data"];
    
    // TO DO: Delete Later
    //NSLog(@"The parsed data set is:%@",parsedDataSets.description);
    
    // Check to make sure that the correct response has come back. e.g. If you get an error message response from the API,
    // then you don't want to process the data and enter as historical prices.
    // If response is not correct, show the user an error message
    if (parsedDataSets == NULL)
    {
        // TO DO: Ideally show user an error message but currently for simplicity we want to keep this transparent to the user.
        
    }
    // Else process response to enter historical prices
    else
    {
        EventHistory *historyForDates = nil;
        NSString *prevEvent1Date = nil;
        NSString *prevRelatedEvent1Date = nil;
        NSString *currentDate = nil;
        NSString *currentDateMinus1Day = nil;
        NSString *previousDayString = nil;
        NSDate *currentMinus1Date = nil;
        
        // NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
        NSNumber *emptyPlaceholder = [[NSNumber alloc] initWithFloat:999999.9];
        NSNumber *prevEvent1Price = emptyPlaceholder;
        NSNumber *prevRelatedEvent1Price = emptyPlaceholder;
        NSNumber *currentDateMinus1DayPrice = emptyPlaceholder;
        
        NSDateFormatter *priceDateFormatter = [[NSDateFormatter alloc] init];
        [priceDateFormatter setDateFormat:@"yyyy-MM-dd"];
        NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        NSDateFormatter *previousDayFormatter = [[NSDateFormatter alloc] init];
        [previousDayFormatter setDateFormat:@"EEE"];
        
        // Iterate through price/details arrays within the parsed data set
        for (NSArray *parsedDetailsList in parsedDataSets) {
            
            // Get the event history dates for which we want to record the stock prices
            // Currently recording only previous event 1 (prior quarterly earnings) date closing stock price, previous related event 1 (prior quarter end date closing price and current price (yesterday's closing price).
            historyForDates = [self getEventHistoryForParentEventTicker:ticker parentEventType:type];
            prevEvent1Date = [priceDateFormatter stringFromDate:historyForDates.previous1Date];
            prevRelatedEvent1Date = [priceDateFormatter stringFromDate:historyForDates.previous1RelatedDate];
            // Subtract 1 from the current day to get yesterday's date, since currently only yesterday's price data is available
            currentDate = [priceDateFormatter stringFromDate:historyForDates.currentDate];
            NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
            differenceDayComponents.day = -1;
            currentMinus1Date = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:historyForDates.currentDate options:0];
            
            // Get the prices for the various dates and write them to the history data store
            
            // If the details array contains the previousRelatedEvent1 date, get the split adjusted closing price, which is the 12th item in the array
            if ([parsedDetailsList containsObject:prevRelatedEvent1Date]) {
                prevRelatedEvent1Price = [NSNumber numberWithDouble:[[parsedDetailsList objectAtIndex:11] doubleValue]];
            }
            
            // If the details array contains the previousEvent1 date, get the split adjusted closing price, which is the 12th item in the array
            if ([parsedDetailsList containsObject:prevEvent1Date]) {
                prevEvent1Price = [NSNumber numberWithDouble:[[parsedDetailsList objectAtIndex:11] doubleValue]];
            }
            
            // If the details array contains the current date minus 1 day, get the split adjusted closing price, which is the 12th item in the array
            // Make sure the previous date doesn't fall on a Saturday, Sunday. In these cases move it to the previous Friday.
            previousDayString = [previousDayFormatter stringFromDate:currentMinus1Date];
            if ([previousDayString isEqualToString:@"Sat"]) {
                differenceDayComponents.day = -1;
                currentMinus1Date = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:currentMinus1Date options:0];
            }
            if ([previousDayString isEqualToString:@"Sun"]) {
                differenceDayComponents.day = -2;
                currentMinus1Date = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:currentMinus1Date options:0];
            }
            // Check for the adjusted previous day to see if it exists. Get the price if it does
            currentDateMinus1Day = [priceDateFormatter stringFromDate:currentMinus1Date];
            if ([parsedDetailsList containsObject:currentDateMinus1Day]) {
                currentDateMinus1DayPrice = [NSNumber numberWithDouble:[[parsedDetailsList objectAtIndex:11] doubleValue]];
            }
        }
        
        // Enter the historical prices to the database
        [self updateEventHistoryWithPreviousEvent1Price:prevEvent1Price previousEvent1RelatedPrice:prevRelatedEvent1Price currentPrice:currentDateMinus1DayPrice parentEventTicker:ticker parentEventType:type];
    } 
     */
    
    // New parsing for the Barchart on demand APIs
    // Response format is
    /*{
        "status" : -{
            "code" : 200,
            "message" : Success.
        },
        "results" : -[
                      -{
                          "symbol" : AAPL,
                          "timestamp" : 2016-03-31T00:00:00-04:00,
                          "tradingDay" : 2016-03-31,
                          "open" : 109.056,
                          "high" : 109.2349,
                          "low" : 108.2211,
                          "close" : 108.3304,
                          "volume" : 26046020,
                          "openInterest" : 
                      },
                      -{
                          "symbol" : AAPL,
                          "timestamp" : 2016-04-01T00:00:00-04:00,
                          "tradingDay" : 2016-04-01,
                          "open" : 108.1217,
                          "high" : 109.3343,
                          "low" : 107.5452,
                          "close" : 109.3244,
                          "volume" : 26031432,
                          "openInterest" : 
                      },
     */
    
    // Get the response into a parsed object
    NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:response
                                                                   options:kNilOptions
                                                                     error:&error];
    
    // Get the list of data slices from the overall data set
    NSArray *parsedDataSets = [parsedResponse objectForKey:@"results"];
    
    // Check to make sure that the correct response has come back. e.g. If you get an error message response from the API,
    // then you don't want to process the data and enter as historical prices.
    // If response is not correct, show the user an error message
    if ([parsedDataSets.description isEqualToString:@"<null>"])
    {
        // TO DO: Ideally show user an error message but currently for simplicity we want to keep this transparent to the user.
        // TO DO: Delete Later before shipping v2.7
        //NSLog(@"Trapping the historical price error");
        
    }
    // Else process response to enter historical prices
    else
    {
        EventHistory *historyForDates = nil;
        NSString *prevEvent1Date = nil;
        NSString *prevRelatedEvent1Date = nil;
        
        // NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
        NSNumber *emptyPlaceholder = [[NSNumber alloc] initWithFloat:999999.9];
        NSNumber *prevEvent1Price = emptyPlaceholder;
        NSNumber *prevRelatedEvent1Price = emptyPlaceholder;
        
        NSDateFormatter *priceDateFormatter = [[NSDateFormatter alloc] init];
        // Set the formatter to be GMT since dates are always GMT and formatters are defaulted to local timezone.
        [priceDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [priceDateFormatter setDateFormat:@"yyyy-MM-dd"];
        
        // Iterate through price/details arrays within the parsed data set
        for (NSDictionary *parsedDetailsList in parsedDataSets) {
            
            // Get the event history dates for which we want to record the stock prices
            // Currently recording only previous event 1 (30 days ago) date closing stock price, previous related event 1 (start of the year).
            historyForDates = [self getEventHistoryForParentEventTicker:ticker parentEventType:type];
            prevEvent1Date = [priceDateFormatter stringFromDate:historyForDates.previous1Date];
            prevRelatedEvent1Date = [priceDateFormatter stringFromDate:historyForDates.previous1RelatedDate];
            
            // Get the prices for the various dates and write them to the history data store
            
            // If the price details dictionary is for the previousRelatedEvent1 (start of year) date, get the price
            if ([[parsedDetailsList objectForKey:@"tradingDay"] caseInsensitiveCompare:prevRelatedEvent1Date] == NSOrderedSame) {
                prevRelatedEvent1Price = [NSNumber numberWithDouble:[[parsedDetailsList objectForKey:@"close"] doubleValue]];
            }
            
            // If the price details dictionary is for the previousEvent1 (30 days ago) date, get the price
            if ([[parsedDetailsList objectForKey:@"tradingDay"] caseInsensitiveCompare:prevEvent1Date] == NSOrderedSame) {
                prevEvent1Price = [NSNumber numberWithDouble:[[parsedDetailsList objectForKey:@"close"] doubleValue]];
            }
        }
        
        // Enter the historical prices to the database
        [self updateEventHistoryWithPreviousEvent1Price:prevEvent1Price previousEvent1RelatedPrice:prevRelatedEvent1Price parentEventTicker:ticker parentEventType:type];
    }
}

// Get the current stock price and write that to the event history. Also return a string with the following format currentprice_netchange_percentchange
- (NSString *)getCurrentStockPriceFromApiForTicker:(NSString *)companyTicker companyEventType:(NSString *)eventType {
    
    NSString *changeString = @"NA";
    
    // The API endpoint URL
    // marketdata.websol.barchart.com/getQuote.json?key=9d040a74abe6d5df65a38df9b4253809&symbols=AMD
    NSString *endpointURL = @"http://marketdata.websol.barchart.com/getQuote.json?key=9d040a74abe6d5df65a38df9b4253809";
    
    // Append Ticker
    // Format the ticker e.g. for V.HSR replace with V_HSR as this is how the API expects it
    NSString *formattedCompanyTicker  = [companyTicker stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    endpointURL = [NSString stringWithFormat:@"%@&symbols=%@",endpointURL,formattedCompanyTicker];
    
    NSError * error = nil;
    NSURLResponse *response = nil;
    
    // Make the call synchronously
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [self sendSynchronousRequest:eventsRequest returningResponse:&response error:&error];
    
    // Process the response
    if (error == nil)
    {
        // Process the response that contains the price information for the company
        NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:responseData
                                                                       options:kNilOptions
                                                                         error:&error];
        
        // Get the list of data slices from the overall data set
        NSArray *parsedDataSets = [parsedResponse objectForKey:@"results"];
        
        // TO DO: Delete Later before shipping v2.7
        //NSLog(@"The parsed quote response data set is:%@",parsedDataSets.description);
        
        // Check to make sure that the correct response has come back. e.g. If you get an error message response from the API,
        // then you don't want to process the data and enter as historical prices.
        // If response is not correct, show the user an error message
        if ([parsedDataSets.description isEqualToString:@"<null>"])
        {
            // TO DO: Ideally show user an error message but currently for simplicity we want to keep this transparent to the user.
            // TO DO: Delete Later before shipping v2.7
            //NSLog(@"Trapping the current price error");
            
        }
        // Else process response to enter historical prices
        else
        {
            
            // NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
            NSNumber *emptyPlaceholder = [[NSNumber alloc] initWithFloat:999999.9];
            NSNumber *currentPrice = emptyPlaceholder;
            
            // Iterate through price array within the parsed data set, which only contains one dictionary.
            for (NSDictionary *parsedDetailsList in parsedDataSets) {
                
                // Get the current price
                currentPrice = [NSNumber numberWithDouble:[[parsedDetailsList objectForKey:@"lastPrice"] doubleValue]];
                
                // Construct the change string i.e. netchange_percentchange
                NSString *currPrice = [NSString stringWithFormat:@"%.02f",[[parsedDetailsList objectForKey:@"lastPrice"] floatValue]];
                NSString *netChange = [NSString stringWithFormat:@"%.02f",[[parsedDetailsList objectForKey:@"netChange"] floatValue]];
                NSString *percentChange = [NSString stringWithFormat:@"%.02f",[[parsedDetailsList objectForKey:@"percentChange"] floatValue]];
                changeString = [NSString stringWithFormat:@"%@_%@_%@",currPrice,netChange,percentChange];
            }
            
            // Enter the current price into the event history table
            [self updateEventHistoryWithCurrentPrice:currentPrice parentEventTicker:companyTicker parentEventType:eventType];
        }
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get price data from the API Data Source. Error description: %@",error.description);
        // TO DO: Ideally show user an error message but currently for simplicity we want to keep this transparent to the user.
    }
    
    return changeString;
}

#pragma mark - Data Syncing Related

// Add the most basic set of most used company information to the company data store. This is done in a batch.
- (void)performBatchedCompanySeedSyncLocally {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Add the 200 most used company tickers and name to the company database.
    
    // NYSE Most Active - Sep, Oct 2015
    Company *companyNyse1 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse1.ticker = @"BAC";
    companyNyse1.name = @"Bank Of America";
    Company *companyNyse2 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse2.ticker = @"RAD";
    companyNyse2.name = @"Rite Aid";
    Company *companyNyse3 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse3.ticker = @"FCX";
    companyNyse3.name = @"Freeport-McMoRan";
    Company *companyNyse4 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse4.ticker = @"GE";
    companyNyse4.name = @"General Electric";
    Company *companyNyse5 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse5.ticker = @"S";
    companyNyse5.name = @"Sprint";
    Company *companyNyse6 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse6.ticker = @"P";
    companyNyse6.name = @"Pandora Media";
    Company *companyNyse7 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse7.ticker = @"PFE";
    companyNyse7.name = @"Pfizer";
    Company *companyNyse8 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse8.ticker = @"BABA";
    companyNyse8.name = @"Alibaba Group Holding ADR";
    Company *companyNyse9 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse9.ticker = @"DOW";
    companyNyse9.name = @"Dow Chemical";
    Company *companyNyse10 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse10.ticker = @"F";
    companyNyse10.name = @"Ford Motor";
    Company *companyNyse11 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse11.ticker = @"T";
    companyNyse11.name = @"AT&T";
    Company *companyNyse12 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse12.ticker = @"AA";
    companyNyse12.name = @"Alcoa";
    Company *companyNyse13 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse13.ticker = @"MRK";
    companyNyse13.name = @"Merck&Co";
    Company *companyNyse14 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse14.ticker = @"ABX";
    companyNyse14.name = @"Barrick Gold";
    Company *companyNyse15 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse15.ticker = @"WFC";
    companyNyse15.name = @"Wells Fargo";
    Company *companyNyse16 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse16.ticker = @"HPQ";
    companyNyse16.name = @"Hewlett-Packard";
    Company *companyNyse17 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse17.ticker = @"ORCL";
    companyNyse17.name = @"Oracle";
    Company *companyNyse18 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse18.ticker = @"C";
    companyNyse18.name = @"Citigroup";
    Company *companyNyse19 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse19.ticker = @"SUNE";
    companyNyse19.name = @"SunEdison";
    Company *companyNyse20 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse20.ticker = @"GM";
    companyNyse20.name = @"General Motors";
    Company *companyNyse21 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse21.ticker = @"CHK";
    companyNyse21.name = @"Chesapeake Energy";
    Company *companyNyse22 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse22.ticker = @"JPM";
    companyNyse22.name = @"JPMorgan Chase";
    Company *companyNyse23 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse23.ticker = @"KO";
    companyNyse23.name = @"Coca-Cola";
    Company *companyNyse24 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse24.ticker = @"XRX";
    companyNyse24.name = @"Xerox";
    Company *companyNyse25 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse25.ticker = @"EMC";
    companyNyse25.name = @"EMC";
    Company *companyNyse26 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse26.ticker = @"VZ";
    companyNyse26.name = @"Verizon Communications, Inc";
    Company *companyNyse27 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse27.ticker = @"NKE";
    companyNyse27.name = @"Nike, Inc";
    Company *companyNyse28 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNyse28.ticker = @"SBUX";
    companyNyse28.name = @"Starbucks Corporation";
    
    
    // NASDAQ Most Active - Sep, Oct 2015
    Company *companyNasdaq1 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq1.ticker = @"AAPL";
    companyNasdaq1.name = @"Apple Inc";
    Company *companyNasdaq2 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq2.ticker = @"TSLA";
    companyNasdaq2.name = @"Tesla Motors Inc";
    Company *companyNasdaq3 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq3.ticker = @"EA";
    companyNasdaq3.name = @"Electronic Arts Inc";
    Company *companyNasdaq4 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq4.ticker = @"CRM";
    companyNasdaq4.name = @"Salesforce.com Inc";
    Company *companyNasdaq5 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq5.ticker = @"NFLX";
    companyNasdaq5.name = @"Netflix Inc";
    Company *companyNasdaq6 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq6.ticker = @"FB";
    companyNasdaq6.name = @"Facebook Inc";
    Company *companyNasdaq7 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq7.ticker = @"AMAT";
    companyNasdaq7.name = @"Applied Materials Inc";
    Company *companyNasdaq8 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq8.ticker = @"MSFT";
    companyNasdaq8.name = @"Microsoft Corp";
    Company *companyNasdaq9 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq9.ticker = @"TWTR";
    companyNasdaq9.name = @"Twitter Inc";
    Company *companyNasdaq10 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq10.ticker = @"QCOM";
    companyNasdaq10.name = @"Qualcomm Inc";
    Company *companyNasdaq11 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq11.ticker = @"INTC";
    companyNasdaq11.name = @"Intel Corp";
    Company *companyNasdaq12 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq12.ticker = @"CSCO";
    companyNasdaq12.name = @"Cisco Systems";
    Company *companyNasdaq13 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq13.ticker = @"SIRI";
    companyNasdaq13.name = @"Sirius XM Holdings Inc";
    Company *companyNasdaq14 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq14.ticker = @"FOXA";
    companyNasdaq14.name = @"Twenty-First Century Fox, Inc";
    Company *companyNasdaq15 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq15.ticker = @"MU";
    companyNasdaq15.name = @"Micron Technology, Inc";
    Company *companyNasdaq16 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq16.ticker = @"FTR";
    companyNasdaq16.name = @"Frontier Communications Corporation";
    Company *companyNasdaq17 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq17.ticker = @"SPLS";
    companyNasdaq17.name = @"Staples Inc";
    Company *companyNasdaq18 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq18.ticker = @"YHOO";
    companyNasdaq18.name = @"Yahoo! Inc";
    Company *companyNasdaq19 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq19.ticker = @"GILD";
    companyNasdaq19.name = @"Gilead Sciences, Inc";
    Company *companyNasdaq20 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq20.ticker = @"ODP";
    companyNasdaq20.name = @"Office Depot Inc";
    Company *companyNasdaq21 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq21.ticker = @"GPRO";
    companyNasdaq21.name = @"GoPro, Inc";
    Company *companyNasdaq22 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq22.ticker = @"CMCSA";
    companyNasdaq22.name = @"Comcast Corporation";
    Company *companyNasdaq23 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq23.ticker = @"PYPL";
    companyNasdaq23.name = @"PayPal Holdings, Inc";
    Company *companyNasdaq24 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq24.ticker = @"FIT";
    companyNasdaq24.name = @"Fitbit, Inc";
    Company *companyNasdaq25 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq25.ticker = @"GOOG";
    companyNasdaq25.name = @"Google, Inc";
    Company *companyNasdaq26 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyNasdaq26.ticker = @"AMZN";
    companyNasdaq26.name = @"Amazon.com, Inc";
    
    // DOW 30 Companies not covered above
    Company *companyDow1 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow1.ticker = @"MMM";
    companyDow1.name = @"3M";
    Company *companyDow2 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow2.ticker = @"AXP";
    companyDow2.name = @"American Express";
    Company *companyDow3 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow3.ticker = @"BA";
    companyDow3.name = @"Boeing";
    Company *companyDow4 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow4.ticker = @"CAT";
    companyDow4.name = @"Caterpillar";
    Company *companyDow5 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow5.ticker = @"CVX";
    companyDow5.name = @"Chevron";
    Company *companyDow6 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow6.ticker = @"DIS";
    companyDow6.name = @"Disney";
    Company *companyDow7 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow7.ticker = @"DD";
    companyDow7.name = @"DuPont Co";
    Company *companyDow8 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow8.ticker = @"XOM";
    companyDow8.name = @"Exxon Mobil";
    Company *companyDow9 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow9.ticker = @"GS";
    companyDow9.name = @"Goldman Sachs";
    Company *companyDow10 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow10.ticker = @"HD";
    companyDow10.name = @"Home Depot";
    Company *companyDow11 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow11.ticker = @"IBM";
    companyDow11.name = @"IBM";
    Company *companyDow12 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow12.ticker = @"JNJ";
    companyDow12.name = @"Johnson & Johnson";
    Company *companyDow13 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow13.ticker = @"MCD";
    companyDow13.name = @"McDonald's";
    Company *companyDow14 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow14.ticker = @"PG";
    companyDow14.name = @"Procter & Gamble";
    Company *companyDow15 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow15.ticker = @"TRV";
    companyDow15.name = @"Travelers Companies Inc";
    Company *companyDow16 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow16.ticker = @"UTX";
    companyDow16.name = @"United Technologies";
    Company *companyDow17 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow17.ticker = @"UNH";
    companyDow17.name = @" UnitedHealth";
    Company *companyDow18 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow18.ticker = @"V";
    companyDow18.name = @"Visa";
    Company *companyDow19 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyDow19.ticker = @"WMT";
    companyDow19.name = @"Walmart";
    
    // Others not covered above
    // TO DO: Add more as you come along
    Company *companyOther1 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyOther1.ticker = @"RUBI";
    companyOther1.name = @"Rubicon Project";
    Company *companyOther2 = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
    companyOther2.ticker = @"RT";
    companyOther2.name = @"Ruby Tuesday";
    
    // Insert
    NSError *error;
    if (![dataStoreContext save:&error]) {
        NSLog(@"ERROR: Batch Saving companies during seed sync failed: %@",error.description);
    } else {
        // Add or Update the Company Data Sync status to SeedSyncDone.
        [self upsertUserWithCompanySyncStatus:@"SeedSyncDone" syncedPageNo:[NSNumber numberWithInteger: 0]];
        // Set Total Number of Company Pages to -1, to indicate that the valid value has not yet been fetched
        [self updateUserWithTotalNoOfCompanyPagesToSync:[NSNumber numberWithInteger: -1]];
    }
}

// Add the most basic set of most used events to the event data store. This is fetched from the data source
// API based on the set of companies that are included in the Company Seed Sync.
// IMPORTANT: If you are changing the list or number of companies here, reconcile with doTrendingTickerEventsExist.
- (void)performEventSeedSyncRemotely {
    
    // Add the events for the 5 most used companies to the events database.
    [self getAllEventsFromApiWithTicker:@"AAPL"];
    [self getAllEventsFromApiWithTicker:@"FB"];
    [self getAllEventsFromApiWithTicker:@"MSFT"];
    [self getAllEventsFromApiWithTicker:@"BAC"];
    [self getAllEventsFromApiWithTicker:@"GM"];
    
    // Add trending tickers and their events.
    [self performTrendingEventSyncRemotely];
    
    // Add or Update the Company Data Sync status to SeedSyncDone.
    [self updateUserWithEventSyncStatus:@"SeedSyncDone"];
}

// Add tickers and events for trending stocks.
- (void)performTrendingEventSyncRemotely {
    
    // Add 5 trending company tickers and name to the company database.
    [self insertUniqueCompanyWithTicker:@"TSLA" name:@"Tesla Motors"];
    //[self insertUniqueCompanyWithTicker:@"GPRO" name:@"Go Pro"];
    [self insertUniqueCompanyWithTicker:@"BABA" name:@"Alibaba"];
    //[self insertUniqueCompanyWithTicker:@"ANET" name:@"Arista Networks"];
    [self insertUniqueCompanyWithTicker:@"LULU" name:@"Lululemon Athletica"];
    //[self insertUniqueCompanyWithTicker:@"BOX" name:@"Box,Inc"];
    [self insertUniqueCompanyWithTicker:@"SQ" name:@"Square"];
    //[self insertUniqueCompanyWithTicker:@"ORCL" name:@"Oracle"];
    [self insertUniqueCompanyWithTicker:@"NKE" name:@"Nike"];
    //[self insertUniqueCompanyWithTicker:@"UA" name:@"Under Armour Inc"];
    
    // Get events for these trending companies from the remote data source
    [self getAllEventsFromApiWithTicker:@"TSLA"];
    //[self getAllEventsFromApiWithTicker:@"GPRO"];
    [self getAllEventsFromApiWithTicker:@"BABA"];
    //[self getAllEventsFromApiWithTicker:@"ANET"];
    [self getAllEventsFromApiWithTicker:@"LULU"];
    //[self getAllEventsFromApiWithTicker:@"BOX"];
    [self getAllEventsFromApiWithTicker:@"SQ"];
    //[self getAllEventsFromApiWithTicker:@"ORCL"];
    [self getAllEventsFromApiWithTicker:@"NKE"];
    //[self getAllEventsFromApiWithTicker:@"UA"];
    
    eventsUpdated = YES;
}

// Update the existing events in the local data store, with latest information from the remote data source, if it's
// likely that the remote source has been updated. There are 2 scenarios where it's likely:
// 1. If the speculated date of an event is within 2 weeks of today, then we consider it likely that the event has been updated
// in the remote source. The likely event also needs to have a certainty of either "Estimated" or "Unknown" to qualify for the update.
// 2. If the confirmed date of the event is in the past.
// ADDITIONALLY: Add trending tickers only initially
// PLUS: Check to see if product events need to be added or refreshed. If yes, do that. Currently product events are being fetched whole each time.
- (void)updateEventsFromRemoteIfNeeded {
    
    eventsUpdated = NO;
    
    // Check to make sure that we haven't already requested an events refresh today
    // Get Today's Date
    NSDate *todaysDate = [NSDate date];
    // Get the event sync date
    NSDate *lastSyncDate = [self getEventSyncDate];
    // TO DO: Delete Later before shipping v2.5
    //NSLog(@"LAST EVENT SYNCED DATE AND TIME IS:%@",lastSyncDate);
    //NSLog(@"TODAY DATE AND TIME IS:%@",todaysDate);
    // Get the number of days between the 2 dates
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [gregorianCalendar components:NSCalendarUnitDay fromDate:lastSyncDate toDate:todaysDate options:0];
    NSInteger daysBetween = [components day];
    // Get the number of hours between the 2 dates
    NSDateComponents *hourComponents = [gregorianCalendar components:NSCalendarUnitHour fromDate:lastSyncDate toDate:todaysDate options:0];
    NSInteger hoursBetween = [hourComponents hour];
    // TO DO: Delete Later before shipping v4.3
    //NSLog(@"Days between LAST EVENT SYNC AND TODAY are: %ld",(long)daysBetween);
    //NSLog(@"Hours between LAST EVENT SYNC AND TODAY are: %d",(int)hoursBetween);

    // Uncomment this if you want it to sync only after 24 hours.
    //if((int)daysBetween > 0) {
    // TO DO: Sync every 2 hours or if it's an upgrade to force a sync when the user might have just synced under 2 hrs ago on the old version.
    if(((int)hoursBetween >= 2)||(![[NSUserDefaults standardUserDefaults] boolForKey:@"V4_3_2_Upgraded"])) {
        
        // Set that the user has upgraded so that it now respects the 2 hours sync.
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"V4_3_2_Upgraded"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // Get all events in the local data store.
        NSFetchedResultsController *eventResultsController = [self getAllEvents];
        
        // For every earnings event check if it's likely that the remote source has been updated. There are 2 scenarios where it's likely:
        // 1. If the speculated date of an event is within 31 days from today, then we consider it likely that the event has been updated
        // in the remote source. The likely event also needs to have a certainty of either "Estimated" or "Unknown" to qualify for the update.
        // 2. If the confirmed date of the event is in the past.
        // An earnings event that overall qualifies will be refetched from the remote data source and updated in the local data store.
        for (Event *localEvent in eventResultsController.fetchedObjects)
        {
            // Get the event's date
            NSDate *eventDate = localEvent.date;
            // Get the number of days between the 2 dates
            components = [gregorianCalendar components:NSCalendarUnitDay fromDate:todaysDate toDate:eventDate options:0];
            daysBetween = [components day];
            
            // Start the busy spinner at every iteration as we don't know which when will register.
            //if (!eventsUpdated) {
             // Start the busy spinner on the UI to indicate that a fetch is in progress. Any async UI element update has to happen in the main thread.
             dispatch_async(dispatch_get_main_queue(), ^{
             // TO DO: Delete before shipping v4.3
             //NSLog(@"About to start busy spinner");
             [[NSNotificationCenter defaultCenter]postNotificationName:@"StartBusySpinner" object:self];
             });
             //}
            
            // See if the event is Quarterly Earnings
            if ([localEvent.type isEqualToString:@"Quarterly Earnings"]) {
                
                // See if the event qualifies for the update. If it does, call the remote data source to update it.
                if ((([localEvent.certainty isEqualToString:@"Estimated"]||[localEvent.certainty isEqualToString:@"Unknown"])&&((int)daysBetween <= 31))||([localEvent.certainty isEqualToString:@"Confirmed"]&&((int)daysBetween < 0))){
                    
                    // TO DO: Delete before shipping v4.3
                    //NSLog(@"About to fetch earnings from initial non product sync for ticker:%@",localEvent.listedCompany.ticker);
                    
                    [self getAllEventsFromApiWithTicker:localEvent.listedCompany.ticker];
                    
                    //eventsUpdated = YES;
                }
            }
            
            eventsUpdated = YES;
        }
        
        // Check to see if trending ticker events exist already. If not add those
        // No longer needed as 15 earnings events, covering all of these, are already in the db.
        /*if (![self doTrendingTickerEventsExist]) {
            
            // TO DO: Delete Later before shipping v4.3
            NSLog(@"About to add trending ticker events from remote");
            [self performTrendingEventSyncRemotely];
        }*/
        
        // Check to see if product events need to be added or refreshed. If yes, do that.
        // *****NOTE*****Currently always returning true since we have not implemented update logic.
        if ([self doProductEventsNeedToBeAddedRefreshed]) {
            
            // Use the wrapper as it sets off a start busy spinner as well.
            // NOTE:!!!!!!!! the wrapper also stops the busy spinner so if we need to do additional stuff here like price change fetch modify accordingly.
            //[self getAllProductEventsFromApi];
            [self syncProductEventsWrapper];
        }
    
        // Fetch any price change events using the new API which gets it the sme way as in the client. Currently only getting daily price changes.
        // Delete the existing daily price change events from the db to not create duplicates
        //[self deleteAllDailyPriceChangeEvents];
        //[self getAllPriceChangeEventsFromApiNew];
        
        // TO DO: Delete Later
        //NSLog(@"Finished adding product events and price change events");
    
        // Setting events updated to true as new price events and new product events might be added. Later make sure
        // it's only getting set to true if truly new events have been added.
        eventsUpdated = YES;
    
        // Set events sync status to "RefreshCheckDone" means a check to see if refreshed events data is available is done. This also sets the event sync date to today.
        [self updateUserWithEventSyncStatus:@"RefreshCheckDone"];
        
        // Fire events change notification if any event was updated. Plus Stop the busy spinner on the UI to indicate that the fetch is complete.
        if (eventsUpdated) {
            
            // Any async UI element update has to happen in the main thread.
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendEventsChangeNotification];
                // TO DO: Delete before shipping v4.3
                //NSLog(@"About to stop busy spinner");
                [[NSNotificationCenter defaultCenter]postNotificationName:@"StopBusySpinner" object:self];
            });
        }
    }
    // Make sure you are always refreshing the first view to not show yesterday's events.
    else {
        // Any async UI element update has to happen in the main thread.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendEventsChangeNotification];
            // TO DO: Delete Later.
            //NSLog(@"About to stop busy spinner");
            [[NSNotificationCenter defaultCenter]postNotificationName:@"StopBusySpinner" object:self];
        });
    }
    // Get price changes every time
    /*else {
        // Start the busy spinner on the UI to indicate that a fetch is in progress. Any async UI element update has to happen in the main thread.
        dispatch_async(dispatch_get_main_queue(), ^{
            // TO DO: Delete Later
            //NSLog(@"About to start busy spinner");
            [[NSNotificationCenter defaultCenter]postNotificationName:@"StartBusySpinner" object:self];
        });
        
        // Check to see if product events need to be added or refreshed. If yes, do that.
        // *****NOTE*****Currently always returning true since we have not implemented update logic
        //if ([self doProductEventsNeedToBeAddedRefreshed]) {
            
            // TO DO: Delete Later
            //NSLog(@"About to add product events from Knotifi Data Platform");
            //[self getAllProductEventsFromApi];
        //}

        // Fetch any price change events using the new API which gets it the sme way as in the client. Currently only getting daily price changes.
        // Delete the existing daily price change events from the db to not create duplicates
        //[self deleteAllDailyPriceChangeEvents];
        //[self getAllPriceChangeEventsFromApiNew];
        
        // Fire events change notification if any event was updated. Plus Stop the busy spinner on the UI to indicate that the fetch is complete.
        // Any async UI element update has to happen in the main thread.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendEventsChangeNotification];
            // TO DO: Delete Later.
            //NSLog(@"About to stop busy spinner");
            [[NSNotificationCenter defaultCenter]postNotificationName:@"StopBusySpinner" object:self];
        });
    } */
}

#pragma mark - User State Related

// Get the Company Data Sync Status for the one user in the data store. Returns the following values:
// "NoSyncPerformed" means there has been no company data has been added to the company data store
// "SeedSyncDone" means the most basic set of company information has been added to
// the company data store.
// "FullSyncDone" means the full set of company information has been added to
// the company data store.
- (NSString *)getCompanySyncStatus {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    NSFetchRequest *statusFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [statusFetchRequest setEntity:userEntity];
    
    NSError *error;
    NSArray *fetchedUsers = [dataStoreContext executeFetchRequest:statusFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store failed: %@",error.description);
    }
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store");
    }
    
    // Compute and return the statuses
    if (fetchedUsers.count == 0) {
        return [NSString stringWithFormat:@"NoSyncPerformed"];
    }
    User *fetchedUser = [fetchedUsers lastObject];
    return fetchedUser.companySyncStatus;
}

// Get the Page number to which the company data sync was completed, ranges from 0 to total no of pages in the company data API response.
- (NSNumber *)getCompanySyncedUptoPage {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    NSFetchRequest *pageNoFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [pageNoFetchRequest setEntity:userEntity];
    
    NSError *error;
    NSArray *fetchedUsers = [dataStoreContext executeFetchRequest:pageNoFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store failed: %@",error.description);
    }
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store");
    }
    
    // Return the page number
    User *fetchedUser = [fetchedUsers lastObject];
    return fetchedUser.companyPageNumber;
}

// Get the total number of pages of company data that needs to be synced from the company data API response.
- (NSNumber *)getTotalNoOfCompanyPagesToSync {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    NSFetchRequest *noPagesFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [noPagesFetchRequest setEntity:userEntity];
    
    NSError *error;
    NSArray *fetchedUsers = [dataStoreContext executeFetchRequest:noPagesFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store, for getting total no of company pages to sync, failed: %@",error.description);
    }
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store, while getting total no of company pages to sync.");
    }
    
    // Return the page number
    User *fetchedUser = [fetchedUsers lastObject];
    return fetchedUser.companyTotalPages;
}

// Get the Event Data Sync Status for the one user in the data store. Returns the following values:
// "SeedSyncDone" means the most basic set of events information has been added to the event data store.
// "NoSyncPerformed" means no event information has been added to the event data store.
// "RefreshCheckDone" means a check to see if refreshed events data is available is done.
- (NSString *)getEventSyncStatus {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    NSFetchRequest *statusFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [statusFetchRequest setEntity:userEntity];
    
    NSError *error;
    NSArray *fetchedUsers = [dataStoreContext executeFetchRequest:statusFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store failed: %@",error.description);
    }
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store");
    }
    
    // Compute and return the statuses
    if (fetchedUsers.count == 0) {
        return [NSString stringWithFormat:@"NoSyncPerformed"];
    }
    User *fetchedUser = [fetchedUsers lastObject];
    return fetchedUser.eventSyncStatus;
}

// Get the date on which the events were last synced
- (NSDate *)getEventSyncDate {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    NSFetchRequest *statusFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [statusFetchRequest setEntity:userEntity];
    
    NSError *error;
    NSArray *fetchedUsers = [dataStoreContext executeFetchRequest:statusFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store failed: %@",error.description);
    }
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store");
    }
    
    User *fetchedUser = [fetchedUsers lastObject];
    return fetchedUser.eventSyncDate;
}


// Get the date on which the Company info was last completely synced
- (NSDate *)getCompanySyncDate {
    
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    NSFetchRequest *statusFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [statusFetchRequest setEntity:userEntity];
    
    NSError *error;
    NSArray *fetchedUsers = [dataStoreContext executeFetchRequest:statusFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store failed: %@",error.description);
    }
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store");
    }
    
    // Return the company sync date
    User *fetchedUser = [fetchedUsers lastObject];
    return fetchedUser.companySyncDate;
}

// Add company data sync status to the user data store. Current design is that the user object is created
// when a company data sync is done. Thus this method creates the user with the given status if it
// doesn't exist or updates the user with the new status if the user exists.
// Additionally since the user object is created when the first company data sync is done, set the event sync
// status for the user to "NoSyncPerformed" when creating the user, not for the update.
// Synced Page number is the page to which the company data sync was completed, ranges from 0 to total no of pages in the company data API response.
- (void)upsertUserWithCompanySyncStatus:(NSString *)syncStatus syncedPageNo: (NSNumber *)pageNo;
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the user object exists by querying for it
    NSFetchRequest *userFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [userFetchRequest setEntity:userEntity];
    NSError *error;
    User *existingUser = nil;
    NSArray *fetchedUsers= [dataStoreContext executeFetchRequest:userFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store failed: %@",error.description);
    }
    
    existingUser = [fetchedUsers lastObject];
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store");
    }
    
    // If the user does not exist
    else if (!existingUser) {
        User *user = [NSEntityDescription insertNewObjectForEntityForName:@"User" inManagedObjectContext:dataStoreContext];
        user.companySyncStatus = syncStatus;
        user.companySyncDate = [NSDate date];
        user.companyPageNumber = pageNo;
        user.eventSyncStatus = [NSString stringWithFormat:@"NoSyncPerformed"];
        user.eventSyncDate = [NSDate date];
    }
    
    // If the user exists
    else {
        existingUser.companySyncStatus = syncStatus;
        existingUser.companySyncDate = [NSDate date];
        existingUser.companyPageNumber = pageNo;
    }
    
    // Update the user
    if (![dataStoreContext save:&error]) {
        NSLog(@"ERROR: Saving user company data sync status to data store failed: %@",error.description);
    }
}

// Update the total number of company pages to be synced to the user data store. This method updates the user with the given number. If the user doesn't exist, it logs an error. Since the user is created the first time a company event sync is performed, CALL THIS METHOD AFTER THE UPSERT COMPANY SYNC STATUS METHOD IS CALLED AT LEAST ONCE.
- (void)updateUserWithTotalNoOfCompanyPagesToSync:(NSNumber *)noOfPages
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the user object exists by querying for it
    NSFetchRequest *userFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [userFetchRequest setEntity:userEntity];
    NSError *error;
    User *existingUser = nil;
    NSArray *fetchedUsers= [dataStoreContext executeFetchRequest:userFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store, for updating total number of company pages failed: %@",error.description);
    }
    
    existingUser = [fetchedUsers lastObject];
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store, when trying to update total number of company pages");
    }
    
    // If the user does not exist
    else if (!existingUser) {
        NSLog(@"SEVERE_WARNING: No user found for updating the total number of company pages. Make sure the update user with total company pages method is not called before the upsert company sync status method has been called at least once.");
    }
    
    // If the user exists
    else {
        // Update the total number of pages value.
        existingUser.companyTotalPages = noOfPages;
    }
    
    // Update the user
    if (![dataStoreContext save:&error]) {
        NSLog(@"ERROR: Updating user's total number of companies to fetch to data store failed: %@",error.description);
    }
}

// Add events data sync status to the user data store. This method updates the user with the given events sync
// status. If the user doesn't exist, it logs an error. Since the user is created the first time a company
// event sync is performed, CALL THIS METHOD AFTER THE UPSERT COMPANY SYNC STATUS METHOD IS CALLED AT LEAST ONCE.
- (void)updateUserWithEventSyncStatus:(NSString *)syncStatus
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the user object exists by querying for it
    NSFetchRequest *userFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *userEntity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:dataStoreContext];
    [userFetchRequest setEntity:userEntity];
    NSError *error;
    User *existingUser = nil;
    NSArray *fetchedUsers= [dataStoreContext executeFetchRequest:userFetchRequest error:&error];
    
    if (error) {
        NSLog(@"ERROR: Getting user from data store failed: %@",error.description);
    }
    
    existingUser = [fetchedUsers lastObject];
    if (fetchedUsers.count > 1) {
        NSLog(@"SEVERE_WARNING: Found more than 1 user objects in the User Data Store");
    }
    
    // If the user does not exist
    else if (!existingUser) {
        NSLog(@"SEVERE_WARNING: No user found for updating the event sync status. Make sure the event sync update method is not called before the upsert company sync status method has been called at least once.");
    }
    
    // If the user exists
    else {
        existingUser.eventSyncStatus = syncStatus;
        existingUser.eventSyncDate = [NSDate date];
    }
    
    // Update the user
    if (![dataStoreContext save:&error]) {
        NSLog(@"ERROR: Updating user event sync status to data store failed: %@",error.description);
    }
}

#pragma mark - Action Related

// Add an Action associated with an event to the Action Data Store given the Action Type, Action Status, Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (void)insertActionOfType:(NSString *)actionType status:(NSString *)actionStatus eventTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the event exists by doing a case insensitive query on parent company Ticker and event type.
    // TO DO: Current assumption is that an event is uniquely identified by the combination of above 2 fields. This might need to change in the future.
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventPredicate = [NSPredicate predicateWithFormat:@"listedCompany.ticker =[c] %@ AND type =[c] %@",eventCompanyTicker, associatedEventType];
    [eventFetchRequest setEntity:eventEntity];
    [eventFetchRequest setPredicate:eventPredicate];
    NSError *error;
    Event *existingEvent = nil;
    existingEvent  = [[dataStoreContext executeFetchRequest:eventFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting an event from data store, to insert an associated action, failed: %@",error.description);
    }
    
    // If the event exists, insert the action associated with it
    if (existingEvent) {
        
        // Insert the action associated with the event
        Action *action = [NSEntityDescription insertNewObjectForEntityForName:@"Action" inManagedObjectContext:dataStoreContext];
        action.type = actionType;
        action.status = actionStatus;
        action.parentEvent = existingEvent;
        
        // Perform the insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Saving action to data store failed: %@",error.description);
        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not insert an action into data store of type %@ and status %@ for event ticker %@ and event type %@ because the parent event was not found in the data store", actionType,actionStatus,eventCompanyTicker,associatedEventType);
    }
}

// Update an Action status in the Action Data Store given the Action Type, Event Company Ticker and Event Type, which uniquely identify the event.
- (void)updateActionWithStatus:(NSString *)actionStatus type:(NSString *)actionType eventTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the action exists by doing a case insensitive query on Action Type, Event Company Ticker and Event Type.
    NSFetchRequest *actionFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *actionEntity = [NSEntityDescription entityForName:@"Action" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *actionPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@ AND parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",actionType, eventCompanyTicker, associatedEventType];
    [actionFetchRequest setEntity:actionEntity];
    [actionFetchRequest setPredicate:actionPredicate];
    NSError *error;
    Action *existingAction = nil;
    existingAction  = [[dataStoreContext executeFetchRequest:actionFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting an action from data store, to update it's status, failed: %@",error.description);
    }
    
    // If the action exists update it's status does not exist, insert it
    if (existingAction) {
        
        // Don't need to update type and company as these are the unique identifiers
        existingAction.status = actionStatus;
        
        // Perform the insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Saving action to data store failed: %@",error.description);
        }
        
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not update an action status in data store of type %@ and new status %@ for event ticker %@ and event type %@ because the action was not found in the data store", actionType,actionStatus,eventCompanyTicker,associatedEventType);
    }
}

// Check to see if an Action associated with an event is present, in the Action Data Store, given the Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
// TO DO: Refactor here to add multiple types of actions.
- (BOOL)doesReminderActionExistForEventWithTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL exists = NO;
    
    // Check to see if the action exists by doing a case insensitive query on Action Type, Event Company Ticker and Event Type.
    NSFetchRequest *actionFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *actionEntity = [NSEntityDescription entityForName:@"Action" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *actionPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@ AND parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@",@"OSReminder", eventCompanyTicker, associatedEventType];
    [actionFetchRequest setEntity:actionEntity];
    [actionFetchRequest setPredicate:actionPredicate];
    NSError *error;
    NSArray *fetchedActions = [dataStoreContext executeFetchRequest:actionFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting an action from data store, to check if it exists for an associated event, failed: %@",error.description);
    }
    if (fetchedActions.count > 1) {
        NSLog(@"MEDIUM_WARNING: Found more than 1 action of the same type for a unique event in the Action Data Store");
        exists = YES;
    }
    if (fetchedActions.count == 1) {
        exists = YES;
    }
    
    return exists;
}

// Check to see if an Action associated with an event is present, in the Action Data Store, given the full event type (e.g. Feb Jobs Report).
- (BOOL)doesReminderActionExistForSpecificEvent:(NSString *)eventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL exists = NO;
    Action *action1 = nil;
    Action *action2 = nil;
    
    // Check to see if the action exists by doing a case insensitive query on Action Type and Event Type.
    NSFetchRequest *actionFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *actionEntity = [NSEntityDescription entityForName:@"Action" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *actionPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@ AND parentEvent.type =[c] %@",@"OSReminder", eventType];
    [actionFetchRequest setEntity:actionEntity];
    [actionFetchRequest setPredicate:actionPredicate];
    NSError *error;
    NSArray *fetchedActions = [dataStoreContext executeFetchRequest:actionFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting an action from data store, to check if it exists for an associated event, failed: %@",error.description);
    }
    if (fetchedActions.count > 1) {
        action1 = fetchedActions[0];
        action2 = fetchedActions[1];
        NSLog(@"MEDIUM_WARNING: Found more than 1 action of event type %@ action type 1 %@ action type 2 %@ ticker1 %@ ticker2 %@ for a unique event in the Action Data Store. Ignore for Econ events.", eventType, action1.type, action2.type, action1.parentEvent.listedCompany.ticker,action2.parentEvent.listedCompany.ticker);
        exists = YES;
    }
    if (fetchedActions.count == 1) {
        exists = YES;
    }
    
    return exists;
}

// Check to see if a Queued Action associated with an event is present, in the Action Data Store, given the Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
// TO DO: Refactor this and the method above into one.
- (BOOL)doesQueuedReminderActionExistForEventWithTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    BOOL exists = NO;
    
    // Check to see if the action exists by doing a case insensitive query on Action Type, Action Status, Event Company Ticker and Event Type.
    NSFetchRequest *actionFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *actionEntity = [NSEntityDescription entityForName:@"Action" inManagedObjectContext:dataStoreContext];
    // Case and Diacractic Insensitive Filtering
    NSPredicate *actionPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@ AND status =[c] %@ AND parentEvent.listedCompany.ticker =[c] %@ AND parentEvent.type =[c] %@", @"OSReminder", @"Queued", eventCompanyTicker, associatedEventType];
    [actionFetchRequest setEntity:actionEntity];
    [actionFetchRequest setPredicate:actionPredicate];
    NSError *error;
    NSArray *fetchedActions = [dataStoreContext executeFetchRequest:actionFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting a queued action from data store, to check if it exists for an associated event, failed: %@",error.description);
    }
    if (fetchedActions.count > 1) {
        NSLog(@"MEDIUM_WARNING: Found more than 1 queued action of the same type for a unique event in the Action Data Store");
        exists = YES;
    }
    if (fetchedActions.count == 1) {
        exists = YES;
    }
    
    return exists;
}

// Delete all entries in the action table. Currently being used to reset state so that any user is starting with a clean slate for following.
- (void)deleteAllEventActions
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // For price change events the event type is a fuzzy match.
    NSFetchRequest *actionsFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *actionEntity = [NSEntityDescription entityForName:@"Action" inManagedObjectContext:dataStoreContext];
    
    // Fetch all actions
    [actionsFetchRequest setEntity:actionEntity];
    NSError *error;
    NSArray *actions = [dataStoreContext executeFetchRequest:actionsFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting all reminder actions, while trying to delete all of them, from data store failed: %@",error.description);
    }
    
    // Delete all actions
    for (NSManagedObject *action in actions) {
        
        [dataStoreContext deleteObject:action];
    }
    
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
}

// Delete all entries for a particular ticker in the actions store that indicate that the ticker is being followed so basically entries of the following type: "OSReminder" which means creating a reminder native to iOS. We have added another type called "PriceChange" which currently is used to indicate that a price change event is being followed. 
- (void)deleteFollowingEventActionsForTicker:(NSString *)ticker
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // For price change events the event type is a fuzzy match.
    NSFetchRequest *actionsFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *actionEntity = [NSEntityDescription entityForName:@"Action" inManagedObjectContext:dataStoreContext];
    
    // Filter based on ticker
    
    // Fetch all actions
    NSPredicate *actionsPredicate = [NSPredicate predicateWithFormat:@"(type =[c] %@ OR type =[c] %@) AND parentEvent.listedCompany.ticker =[c] %@", @"OSReminder", @"PriceChange", ticker];
    [actionsFetchRequest setEntity:actionEntity];
    [actionsFetchRequest setPredicate:actionsPredicate];
    NSError *error;
    NSArray *actions = [dataStoreContext executeFetchRequest:actionsFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting all following related event actions, while trying to delete all of them, from data store failed: %@",error.description);
    }
    
    // Delete all following actions
    for (NSManagedObject *action in actions) {
        
        [dataStoreContext deleteObject:action];
    }
    
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
}

// Delete all entries for a particular econ event type in the actions store that indicate that the ticker is being followed so basically entries of the following type: "OSReminder" which means creating a reminder native to iOS.
- (void)deleteFollowingEventActionsForEconEvent:(NSString *)type
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the event by doing a case insensitive query on parent company Ticker and event type.
    // For price change events the event type is a fuzzy match.
    NSFetchRequest *actionsFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *actionEntity = [NSEntityDescription entityForName:@"Action" inManagedObjectContext:dataStoreContext];
    
    NSPredicate *actionsPredicate;
    
    // Filter based on type
    if ([type containsString:@"Fed Meeting"]) {
        actionsPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@ AND parentEvent.type contains %@", @"OSReminder", @"Fed Meeting"];
    }
    if ([type containsString:@"Jobs Report"]) {
        actionsPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@ AND parentEvent.type contains %@", @"OSReminder", @"Jobs Report"];
    }
    if ([type containsString:@"Consumer Confidence"]) {
       actionsPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@ AND parentEvent.type contains %@", @"OSReminder", @"Consumer Confidence"];
    }
    if ([type containsString:@"GDP Release"]) {
       actionsPredicate = [NSPredicate predicateWithFormat:@"type =[c] %@ AND parentEvent.type contains %@", @"OSReminder", @"GDP Release"];
    }

    [actionsFetchRequest setEntity:actionEntity];
    [actionsFetchRequest setPredicate:actionsPredicate];
    NSError *error;
    NSArray *actions = [dataStoreContext executeFetchRequest:actionsFetchRequest error:&error];
    if (error) {
        NSLog(@"ERROR: Getting all following related econ event actions, while trying to delete all of them, from data store failed: %@",error.description);
    }
    
    // Delete all following actions
    for (NSManagedObject *action in actions) {
        
        [dataStoreContext deleteObject:action];
    }
    
    // Save managed object context to persist the delete.
    [dataStoreContext save:&error];
}

#pragma mark - Notifications

// Send a notification that the list of events has changed (updated)
- (void)sendEventsChangeNotification {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
}

// Send a notification to the events list controller with a message that should be shown to the user
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents {
    
    // Any async UI element update (navBar title gets updated) hs to happen in the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        // TO DO: Delete before shipping v4.3
        //NSLog(@"About to error message: %@ to the nav bar title",msgContents);
        [[NSNotificationCenter defaultCenter]postNotificationName:@"UserMessageCreated" object:msgContents];
    });
}

// Send a notification that a queued reminder associated with an event should be created, since the event date has been confirmed. Send an array of information {eventType,companyTicker,eventDateText} that will be needed by receiver to complete this action.
- (void)sendCreateReminderNotificationWithEventInformation:(NSArray *)eventInfo {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"CreateQueuedReminder" object:eventInfo];
}

#pragma mark - Utility Methods

// Format the given date to set the time on it to midnight last night. e.g. 03/21/2016 9:00 pm becomes 03/21/2016 12:00 am.
- (NSDate *)setTimeToMidnightLastNightOnDate:(NSDate *)dateToFormat
{
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponents = [aGregorianCalendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:dateToFormat];
    NSDate *formattedDate = [aGregorianCalendar dateFromComponents:dateComponents];
    
    return formattedDate;
}

// Calculate how many days is it from the given event date to today.
- (NSInteger)calculateDistanceFromEventDate:(NSDate *)eventDate
{
    // Calculate the number of days between event date and today's date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSUInteger unitFlags =  NSCalendarUnitDay;
    NSDateComponents *diffDateComponents = [aGregorianCalendar components:unitFlags fromDate:eventDate toDate:[NSDate date] options:0];
    NSInteger difference = [diffDateComponents day];
    
    return difference;
}

// Simulating a Synchronous Request using NSURLSession that doesn't support synchronous requests. Need this since NSURLRequest has been deprecated.
- (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error
{
    
    NSError __block *err = NULL;
    NSData __block *data;
    BOOL __block reqProcessed = false;
    NSURLResponse __block *resp;
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable _data, NSURLResponse * _Nullable _response, NSError * _Nullable _error) {
        resp = _response;
        err = _error;
        data = _data;
        reqProcessed = true;
    }] resume];
    
    while (!reqProcessed) {
        [NSThread sleepForTimeInterval:0];
    }
    
    *response = resp;
    *error = err;
    return data;
}

// Compute the unscrubbed date 30 days ago from today. Unscrubbed means it could be a weekend or a holiday.
- (NSDate *)computeDate30DaysAgoFrom:(NSDate *)startingDate
{
    // Subtract 30 days from start date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = -30;
    NSDate *returnDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:startingDate options:0];
    
    return returnDate;
}

// Make sure the date doesn't fall on a Friday, Saturday, Sunday. In these cases move it to the previous Friday for Saturday and following Monday for Sunday. TO DO LATER: Factor in holidays here.
- (NSDate *)scrubDateToNotBeWeekendOrHoliday:(NSDate *)dateToScrub
{
    // Make sure the date doesn't fall on a Friday, Saturday, Sunday. In these cases move it to the previous Friday for Saturday and following Monday for Sunday. TO DO LATER: Factor in holidays here.
    // Convert from string to Date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateFormatter *dayFormatter = [[NSDateFormatter alloc] init];
    [dayFormatter setDateFormat:@"EEE"];
    // Set the formatter to be GMT since dates are always GMT and formatters are defaulted to local timezone
    [dayFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    NSDate *scrubbedDate = dateToScrub;
    NSString *dayString = [dayFormatter stringFromDate:dateToScrub];
    
    if ([dayString isEqualToString:@"Sat"]) {
        differenceDayComponents.day = -1;
        scrubbedDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:dateToScrub options:0];
    }
    
    if ([dayString isEqualToString:@"Sun"]) {
        differenceDayComponents.day = 1;
        scrubbedDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:dateToScrub options:0];
    }
    
    return scrubbedDate;
}

// Compute the scrubbed first market day of the year for the given date. Currently it works only for 2016.
// TO DO: Change this for 2017 and so on and so forth
// TO DO Change for beginning of the year 2019: For 2017, the first market day will be 2 days later on Jan 3. So add 2 instead of 3 here. That's it. www.timeanddate.com/calendar/?year=2017&country=1
// FOR 2018: the first day the market is open is Tue Jan 2nd. So add 1 instead of 2.
- (NSDate *)computeMarketStartDateOfTheYearFrom:(NSDate *)givenDate
{
    // Compute the first date of the year from the given date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents * aCalComponents = [aGregorianCalendar components: NSCalendarUnitYear fromDate:givenDate];
    [aCalComponents setYear:[aCalComponents year]];
    NSDate *returnDate = [aGregorianCalendar dateFromComponents:aCalComponents];
    
    // For 2016, the first market open day was 3 days after, Jan 1 putting it at Jan 4.
    // TO DO: For 2017, the first market day will be 2 days later on Jan 3. So add 2 instead of 3 here. That's it. www.timeanddate.com/calendar/?year=2017&country=1
    // FOR 2018: the first day the market is open is Tue Jan 2nd. So add 1 instead of 2.
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = 1;
    returnDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:returnDate options:0];
    
    return returnDate;
}

@end

