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

@interface FADataController ()

// Send a notification that the list of messages has changed (updated)
- (void)sendEventsChangeNotification;

// Send a notification that the list of events has changed (updated)
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents;

// Send a notification that a queued reminder associated with an event should be created, since the event date has been confirmed. Send an array of information {eventType,companyTicker,eventDateText} that will be needed by receiver to complete this action.
- (void)sendCreateReminderNotificationWithEventInformation:(NSArray *)eventInfo;

@end

@implementation FADataController

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
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
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
            NSLog(@"Saved Unique Company with ticker %@",companyTicker);
        }
    }
    // TO DO: Delete Later
    else {
        NSLog(@"Found a duplicate of ticker %@",companyTicker);
    }
}

// Get all Companies. Returns a results controller with identities of all Companies recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllCompanies
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get all comapnies
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
    // TO DO: Delete. Currently for debugging only
    else {
        NSLog(@"Fetched a total of %ld companies from the data store.",self.resultsController.fetchedObjects.count);
    }
    
    return self.resultsController;
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
    // Case and Diacractic Insensitive Filtering
    NSPredicate *eventPredicate = [NSPredicate predicateWithFormat:@" listedCompany.ticker =[c] %@ AND type =[c] %@",listedCompanyTicker, eventType];
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
        
        NSLog(@"Updating company ticker is:%@ and company confirmed is:%@",existingEvent.listedCompany.ticker,existingEvent.certainty);
    }
    
    // Perform the insert
    if (![dataStoreContext save:&error]) {
        NSLog(@"ERROR: Saving event to data store failed: %@",error.description);
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
        NSLog(@"Fetched all events at the db level");
    }
    
    return self.resultsController;
}

// Search and return all events that match the search text on "ticker" and "name" fields for the listed Company.
// Returns a results controller with identities of all events recorded, but no more than batchSize (currently set to 15)
// objects’ data will be fetched from the data store at a time.
- (NSFetchedResultsController *)searchEventsFor:(NSString *)searchText
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    
    // Case and Diacractic Insensitive Filtering
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"listedCompany.name contains[cd] %@ OR listedCompany.ticker contains[cd] %@", searchText, searchText];
    [eventFetchRequest setPredicate:searchPredicate];
    
    // TO DO: Should it be ascending or descending to get the latest first ?
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    
    [eventFetchRequest setFetchBatchSize:15];
    
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Searching for events with the following name and ticker search text: %@ from data store failed: %@",searchText, error.description);
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
    
    // TO DO: Should it be ascending or descending to get the latest first ?
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
            NSLog(@"Inserted history for ticker:%@ with previous event date:%@ with previous event status:%@ and previous related event:%@ and current date:%@ and previous event price:%@ and previous related event price:%@ and current price:%@",existingEvent.listedCompany.ticker,history.previous1Date,history.previous1Status,history.previous1RelatedDate,history.currentDate,[history.previous1Price stringValue],history.previous1RelatedPrice,history.currentPrice);
        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not insert event history into data store because the parent event was not found in the data store");
    }
}

// Update non price related history, except current date, associated with an event to the EventHistory Data Store given the previous event 1 date, status, related date, current date, Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
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
            NSLog(@"Updated history for ticker:%@ with previous event date:%@ with previous event status:%@ and previous related event:%@ and current date:%@",existingHistory.parentEvent.listedCompany.ticker,existingHistory.previous1Date,existingHistory.previous1Status,existingHistory.previous1RelatedDate,existingHistory.currentDate);
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
            NSLog(@"Updated history for ticker:%@ with previous event date:%@ with previous event status:%@ and previous related event:%@ and previous event price:%@ and previous related event price:%@ and current price:%@ and current date:%@",existingHistory.parentEvent.listedCompany.ticker,existingHistory.previous1Date,existingHistory.previous1Status,existingHistory.previous1RelatedDate,[existingHistory.previous1Price stringValue],existingHistory.previous1RelatedPrice,existingHistory.currentPrice,existingHistory.currentDate);
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
            NSLog(@"Updated history for ticker:%@ with current date:%@", eventTicker, existingHistory.currentDate);
        }
    }
    
    // If the event does not exist, log an error message to the console
    else {
        
        NSLog(@"ERROR: Did not update event history current date in data store for event ticker %@ and event type %@ because the history was not found in the data store", eventTicker,eventType);
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
        // TO DO: Delete the hardcoded value. Currently this is hardcoded to 26 as 26 pages worth of companies (7517 companies at 300 per page) were available as of Sep 29, 2105. When you change this, change the hard coded value below and in applicationWillTerminate in AppDelegate as well.
        //noOfPages = 26;
        noOfPages = [[self getTotalNoOfCompanyPagesToSync] integerValue];
        
        NSLog(@"**************Entered the get all companies background thread with page No to start from:%ld", (long)pageNo);
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
        NSData *responseData = [NSURLConnection sendSynchronousRequest:companiesRequest returningResponse:&response
                                                                 error:&error];
        
         NSLog(@"******************************************Made request to get company data with page number:%@**************",endpointURL);
        
        // Process the response
        if (error == nil)
        {
            // Process the response that contains the first page of companies.
            // If it's not already been entered, enter the total no of pages of companies to sync in the user data store. This should only be done once.
            noOfPagesTemp = [self processCompaniesResponse:responseData];
            if ([[self getTotalNoOfCompanyPagesToSync] integerValue] == -1) {
                [self updateUserWithTotalNoOfCompanyPagesToSync:[NSNumber numberWithInteger: noOfPagesTemp]];
            }
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
        
        ++pageNo;
        endpointURL = @"https://www.quandl.com/api/v3/datasets.json?database_code=ZEA";
        NSLog(@"Page Number is:%ld and NoOfPages is:%ld",(long)pageNo,(long)noOfPages);
    }
    
    // Add or Update the Company Data Sync status to SeedSyncDone. Check that all pages have been processed before doing so.
    // TO DO: Currently this is hardcoded to 26 as 26 pages worth of companies (7517 companies at 300 per page) were available as of Sep 29, 2105. When you change this, change the hard coded value above and in applicationWillTerminate in AppDelegate as well.
    // TO DO: Delete Later as now getting the value of the total no of companies to sync from db.
    //if ([[self getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&((pageNo-1) >= 26))
    if ([[self getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&((pageNo-1) >= [[self getTotalNoOfCompanyPagesToSync] integerValue]))
    {
        [self upsertUserWithCompanySyncStatus:@"FullSyncDone" syncedPageNo:[NSNumber numberWithInteger:(pageNo-1)]];
    }
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
    
    NSLog(@"Total Number of pages dynamically computed: %ld ", (long)noOfPages);
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
    
    // Get the list of companies first from the overall response
    NSArray *parsedCompanies = [parsedResponse objectForKey:@"datasets"];
    
    // Then loop through the companies, get the appropriate fields and insert them into the data store
    for (NSDictionary *company in parsedCompanies) {
        
        // Get the company ticker and company name string
        NSString *companyTicker = [company objectForKey:@"dataset_code"];
        // Replace underscore in certain ticker names with . e.g.GRP_U -> GRP.U
        companyTicker = [companyTicker stringByReplacingOccurrencesOfString:@"_" withString:@"."];
        NSString *companyNameString = [company objectForKey:@"name"];
        NSLog(@"Company Ticker to be entered in db is: %@ and Company Name String is: %@",companyTicker, companyNameString);
        
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
        NSLog(@"Company Name to be entered in db is: %@", companyName);
        
        // Add company ticker and name into the data store
        [self insertUniqueCompanyWithTicker:companyTicker name:companyName];
    }
}

#pragma mark - Methods to call Company Event Data Source APIs

// Get the event details for a company given it's ticker.
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
        
    NSError * error = nil;
    NSURLResponse *response = nil;
        
    // Make the call synchronously
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [NSURLConnection sendSynchronousRequest:eventsRequest returningResponse:&response
                                                                 error:&error];
        
    // Process the response
    if (error == nil)
    {
        // TO DO: Delete Later, for testing
        //NSLog(@"The endpoint being called for getting company information is:%@",endpointURL);
        //NSLog(@"The API response for getting company information is:%@",[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]);
        // Process the response that contains the events for the company.
        [self processEventsResponse:responseData forTicker:companyTicker];
            
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get events data from the API Data Source. Error description: %@",error.description);
        
        // Show user an error message
        [self sendUserMessageCreatedNotificationWithMessage:@"Hmm! Unable to get events. Check Connection."];
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
    
    NSLog(@"The parsed data set is:%@",parsedDataSets.description);
    
    // Check to make sure that the correct response has come back. e.g. If you get an error message response from the API,
    // then you don't want to process the data and enter as events.
    // If response is not correct, show the user an error message
    if (parsedDataSets == NULL)
    {
        [self sendUserMessageCreatedNotificationWithMessage:@"Hmm! Unable to get events. Try again later."];
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
        NSLog(@"The event type is: %@",eventType);
        
        // Get the date on which the event takes place which is the 5th item
        NSLog(@"The date on which the event takes place: %@",[parsedEventsList objectAtIndex:4]);
        NSString *eventDateStr =  [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:4]];
        // Convert from string to Date
        NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
        [eventDateFormatter setDateFormat:@"yyyyMMdd"];
        NSDate *eventDate = [eventDateFormatter dateFromString:eventDateStr];
        NSLog(@"The date on which the event takes place formatted as a Date: %@",eventDate);
        
        
        // Get Details related to the event which is the 10th item
        // For Quarterly Earnings: 1 (After Market Close), 2 (Before Market Open), 3 (During Market Trading) or 4 (Unknown)
        NSLog(@"The timing details related to the event: %@",[parsedEventsList objectAtIndex:9]);
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
        NSLog(@"The timing details related to the event formatted: %@",eventDetails);
        
        
        // Get the Date related to the event which is the 3rd item
        // 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
        // to be reported
        // TO DO: For optimizing later: Can't I just reuse the event date formatter
        NSLog(@"The quarter end date related to the event: %@",[parsedEventsList objectAtIndex:2]);
        NSString *relatedDateStr =  [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:2]];
        // Convert from string to Date
        NSDateFormatter *relatedDateFormatter = [[NSDateFormatter alloc] init];
        [relatedDateFormatter setDateFormat:@"yyyyMMdd"];
        NSDate *relatedDate = [relatedDateFormatter dateFromString:relatedDateStr];
        NSLog(@"The quarter end date related to the event formatted as a Date: %@",relatedDate);
        
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
        NSLog(@"The confirmation indicator for this event: %@",[parsedEventsList objectAtIndex:8]);
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
        NSLog(@"The confirmation indicator for this event formatted: %@",certaintyStr);
        
        // Upsert events data into the data store
        [self upsertEventWithDate:eventDate relatedDetails:eventDetails relatedDate:relatedDate type:eventType certainty:certaintyStr listedCompany:ticker estimatedEps:estEpsNumber priorEndDate:priorEndDate actualEpsPrior:actualPriorEpsNumber];
        NSLog(@"After updating event for ticker:%@ the event current quarter end date is:%@ and prior quarter end date is:%@",ticker, relatedDate,priorEndDate);
        
        // If this event just went from estimated to confirmed and there is a queued reminder to be created for it, fire a notification to create the reminder.
        // TO DO: Optimize to not make this datastore call, when the user gets events for a ticker for the first time.
        if ([certaintyStr isEqualToString:@"Confirmed"]&&[self doesQueuedReminderActionExistForEventWithTicker:ticker eventType:eventType]) {
            
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

#pragma mark - Methods to call Company Stock Data Source APIs

// Get the historical and current stock prices for a company given it's ticker and the event type for which the historical data is being asked for. Currently only supported event type is Quarterly Earnings. Also, the listed company ticker and event type, together represent the event uniquely. Finally, the most current stock price that we have is yesterday.
- (void)getStockPricesFromApiForTicker:(NSString *)companyTicker companyEventType:(NSString *)eventType fromDateInclusive:(NSDate *)fromDate toDateInclusive:(NSDate *)toDate {
    
    // Get the event details for a company given it's ticker. Call the following API:
    // www.quandl.com/api/v3/datasets/WIKI/AAPL.json?auth_token=Mq-sCZjPwiJNcsTkUyoQ&start_date=2015-01-01&end_date=2015-01-10
    
    // The API endpoint URL
    NSString *endpointURL = @"https://www.quandl.com/api/v3/datasets/WIKI";
    
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
    endpointURL = [NSString stringWithFormat:@"%@&start_date=%@&end_date=%@",endpointURL,fromDateInclusiveString,toDateInclusiveString];
    
    NSError * error = nil;
    NSURLResponse *response = nil;
    
    // Make the call synchronously
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [NSURLConnection sendSynchronousRequest:eventsRequest returningResponse:&response
                                                             error:&error];
    
    // Process the response
    if (error == nil)
    {
        // TO DO: Delete Later, for testing
        NSLog(@"The endpoint being called for getting price information is:%@",endpointURL);
        //NSLog(@"The API response for getting company information is:%@",[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]);
        // Process the response that contains the events for the company.
        [self processStockPricesResponse:responseData forTicker:companyTicker forEventType:eventType];
        
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get price data from the API Data Source. Error description: %@",error.description);
        
        // Show user an error message
        [self sendUserMessageCreatedNotificationWithMessage:@"Hmm! Unable to get events. Check Connection."];
    }
}

// Parse the stock prices API response and add the historical and current prices to the event history.Currently recording only previous event 1 (prior quarterly earnings) date closing stock price, previous related event 1 (prior quarter end date closing price and current price (yesterday's closing price).NOTE: Yesterday's closing price is based on what the current date is on the history object.
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
        // TO DO: Replace with error message for the event detail screen
        [self sendUserMessageCreatedNotificationWithMessage:@"Hmm! Unable to get stock prices. Try again later."];
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
            
            // TO DO: Delete later.
            NSLog(@"The date for the stock price is:%@",[parsedDetailsList objectAtIndex:0]);
            
            // Get the event history dates for which we want to record the stock prices
            // Currently recording only previous event 1 (prior quarterly earnings) date closing stock price, previous related event 1 (prior quarter end date closing price and current price (yesterday's closing price).
            historyForDates = [self getEventHistoryForParentEventTicker:ticker parentEventType:type];
            NSLog(@"While processing the prices API response for ticker:%@ the event prior quarter end date is:%@",ticker, historyForDates.previous1RelatedDate);
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
                NSLog(@"Stock price for ticker:%@ previous related event date:%@ is:%@",ticker, prevRelatedEvent1Date,prevRelatedEvent1Price);
            }
            
            // If the details array contains the previousEvent1 date, get the split adjusted closing price, which is the 12th item in the array
            if ([parsedDetailsList containsObject:prevEvent1Date]) {
                prevEvent1Price = [NSNumber numberWithDouble:[[parsedDetailsList objectAtIndex:11] doubleValue]];
                NSLog(@"Stock price for ticker:%@ previous event date:%@ is:%@", ticker, prevEvent1Date,prevEvent1Price);
            }
            
            // If the details array contains the current date minus 1 day, get the split adjusted closing price, which is the 12th item in the array
            // Make sure the previous date doesn't fall on a Saturday, Sunday. In these cases move it to the previous Friday.
            previousDayString = [previousDayFormatter stringFromDate:currentMinus1Date];
            if ([previousDayString isEqualToString:@"Sat"]) {
                // TO DO: Delete right at the end before shipping. Will identify possible incorrect calculations.
                differenceDayComponents.day = -1;
                currentMinus1Date = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:currentMinus1Date options:0];
            }
            if ([previousDayString isEqualToString:@"Sun"]) {
                // TO DO: Delete right at the end before shipping. Will identify possible incorrect calculations.
                differenceDayComponents.day = -2;
                currentMinus1Date = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:currentMinus1Date options:0];
            }
            // Check for the adjusted previous day and get the price
            currentDateMinus1Day = [priceDateFormatter stringFromDate:currentMinus1Date];
            if ([parsedDetailsList containsObject:currentDateMinus1Day]) {
                currentDateMinus1DayPrice = [NSNumber numberWithDouble:[[parsedDetailsList objectAtIndex:11] doubleValue]];
                NSLog(@"Stock price for ticker:%@ yesterday's date:%@ is:%@",ticker, currentDateMinus1Day,currentDateMinus1DayPrice);
            }
        }
        
        // Enter the historical prices to the database
        [self updateEventHistoryWithPreviousEvent1Price:prevEvent1Price previousEvent1RelatedPrice:prevRelatedEvent1Price currentPrice:currentDateMinus1DayPrice parentEventTicker:ticker parentEventType:type];
    }
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
- (void)performEventSeedSyncRemotely {
    
    // Add the events for the 5 most used companies to the events database.
    [self getAllEventsFromApiWithTicker:@"AAPL"];
    [self getAllEventsFromApiWithTicker:@"FB"];
    [self getAllEventsFromApiWithTicker:@"MSFT"];
    [self getAllEventsFromApiWithTicker:@"BAC"];
    [self getAllEventsFromApiWithTicker:@"GM"];
    
    // Add or Update the Company Data Sync status to SeedSyncDone.
    [self updateUserWithEventSyncStatus:@"SeedSyncDone"];
}

// Update the existing events in the local data store, with latest information from the remote data source, if it's
// likely that the remote source has been updated. There are 2 scenarios where it's likely:
// 1. If the speculated date of an event is within 2 weeks of today, then we consider it likely that the event has been updated
// in the remote source. The likely event also needs to have a certainty of either "Estimated" or "Unknown" to qualify for the update.
// 2. If the confirmed date of the event is in the past.
- (void)updateEventsFromRemoteIfNeeded {
    
    NSLog(@"****************************Entered the method to updateevents**********************");
    
    // Flag to see if any event was updated
    BOOL eventsUpdated = NO;
    
    // Get all events in the local data store.
    NSFetchedResultsController *eventResultsController = [self getAllEvents];
    
    // For every event check if it's likely that the remote source has been updated. There are 2 scenarios where it's likely:
    // 1. If the speculated date of an event is within 31 days from today, then we consider it likely that the event has been updated
    // in the remote source. The likely event also needs to have a certainty of either "Estimated" or "Unknown" to qualify for the update.
    // 2. If the confirmed date of the event is in the past.
    // An event that overall qualifies will be refetched from the remote data source and updated in the local data store.
    for (Event *localEvent in eventResultsController.fetchedObjects)
    {
        NSLog(@"****************************Entered the loop for checking**********************");
        // Get Today's Date
        NSDate *todaysDate = [NSDate date];
        // Get the event's date
        NSDate *eventDate = localEvent.date;
        // Get the number of days between the 2 dates
        NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        NSDateComponents *components = [gregorianCalendar components:NSCalendarUnitDay fromDate:todaysDate toDate:eventDate options:0];
        NSInteger daysBetween = [components day];
        NSLog(@"****************************No of days for event for %@ is %ld",localEvent.listedCompany.ticker, daysBetween);
        
        // See if the event qualifies for the update. If it does, call the remote data source to update it.
        if ((([localEvent.certainty isEqualToString:@"Estimated"]||[localEvent.certainty isEqualToString:@"Unknown"])&&((int)daysBetween <= 31))||([localEvent.certainty isEqualToString:@"Confirmed"]&&((int)daysBetween < 0))){
            NSLog(@"****************************About to update an event**********************");
            [self getAllEventsFromApiWithTicker:localEvent.listedCompany.ticker]; 
            eventsUpdated = YES;
        }
    }
    
    // Fire events change notification if any event was updated
    if (eventsUpdated) {
        
        [self sendEventsChangeNotification];
    }
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

#pragma mark - Notifications

// Send a notification that the list of events has changed (updated)
- (void)sendEventsChangeNotification {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
}

// Send a notification that the list of events has changed (updated)
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"UserMessageCreated" object:msgContents];
    NSLog(@"NOTIFICATION FIRED: With User Message: %@",msgContents);
}

// Send a notification that a queued reminder associated with an event should be created, since the event date has been confirmed. Send an array of information {eventType,companyTicker,eventDateText} that will be needed by receiver to complete this action.
- (void)sendCreateReminderNotificationWithEventInformation:(NSArray *)eventInfo {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"CreateQueuedReminder" object:eventInfo];
    NSLog(@"NOTIFICATION FIRED FOR CREATING QUEUED REMINDER: For eventtype:%@ and eventticker:%@ and eventDateText:%@",[eventInfo objectAtIndex:0],[eventInfo objectAtIndex:1],[eventInfo objectAtIndex:2]);
}


@end

