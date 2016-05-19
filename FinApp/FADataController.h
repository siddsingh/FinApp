//
//  FADataController.h
//  FinApp
//
//  Class to interact with the core data store. Each thread should have it's own
//  FADataController that creates a new managed object context that talks to the
//  single data store.
//
//  Created by Sidd Singh on 3/2/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FADataStore;
@class NSFetchedResultsController;
@class NSManagedObjectContext;
@class EventHistory;
@class Event;

@interface FADataController : NSObject

#pragma mark - Data Store related

// A single persistent data store for this app.
@property (strong,nonatomic) FADataStore *appDataStore;

// Managed Object Context to interact with Data Store.
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

// Controller containing results of queries to Core Data
@property (strong, nonatomic) NSFetchedResultsController *resultsController;

#pragma mark - Company Data Related

// Add company details to the company data store. Current design is that a company
// is uniquely identified by it's ticker. Thus this method creates the company with
// it's details only if the ticker doesn't exist.
- (void)insertUniqueCompanyWithTicker:(NSString *)companyTicker name:(NSString *)companyName;

// Get all Companies. Returns a results controller with identities of all Companies recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllCompanies;

// Get company ticker using company name. Assumption is that there is only one record per company name and ticker.
- (NSString *)getTickerForName:(NSString *)companyName;

#pragma mark - Events Data Related

// Upsert an Event along with a parent company to the Event Data Store i.e. If the specified event type for that particular company exists, update it. If not insert it.
- (void)upsertEventWithDate:(NSDate *)eventDate relatedDetails:(NSString *)eventRelatedDetails relatedDate:(NSDate *)eventRelatedDate type:(NSString *)eventType certainty:(NSString *)eventCertainty listedCompany:(NSString *)listedCompanyTicker estimatedEps:(NSNumber *)eventEstEps priorEndDate:(NSDate *)eventPriorEndDate actualEpsPrior:(NSNumber *)eventActualEpsPrior;

// Get all Events. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllEvents;

// Get all future events including today. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllFutureEvents;

// Get all future earnings events including today. Returns a results controller with identities of all earnings Events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllFutureEarningsEvents;

// Get all future economic events including today. Returns a results controller with identities of all economic events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllFutureEconEvents;

// Get all future product events including today. Returns a results controller with identities of all product events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
// NOTE: If there is a new type of product event like launch or conference added, add that here as well.
- (NSFetchedResultsController *)getAllFutureProductEvents;

// Search and return all future events that match the search text dpending on the display event type. Note this is different from the type field on the event data object: 0. All (all eventTypes) 1. "Earnings" (Quarterly Earnings) 2. "Economic" (Economic Event) 3. "Product" (Product Event).NOTE: If there is a new type of product event like launch or conference added, add that here as well.
// Returns a results controller with identities of all events recorded, but no more than batchSize (currently set to 15) objects’ data will be fetched from the data store at a time.
- (NSFetchedResultsController *)searchEventsFor:(NSString *)searchText eventDisplayType:(NSString *)eventType;

// Search and return all companies that match the search text on "ticker" and "name" fields for the Company.
// Returns a results controller with identities of all companies recorded, but no more than batchSize (currently set
// to 15) objects’ data will be fetched from the data store at a time.
- (NSFetchedResultsController *)searchCompaniesFor:(NSString *)searchText;

// Get the date for an Event given the Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (NSDate *)getDateForEventOfType:(NSString *)eventType eventTicker:(NSString *)eventCompanyTicker;

// Get Event Details for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (Event *)getEventForParentEventTicker:(NSString *)eventCompanyTicker andEventType:(NSString *)eventType;

// Check to see if a single economic event exists in the event data store and return accordingly. Typically used to
// check if economic events types have been synced or not.
- (BOOL)doesEconEventExist;

// Check to see an event of a certain type exists for a given company ticker. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (BOOL)doesEventExistForParentEventTicker:(NSString *)eventCompanyTicker andEventType:(NSString *)eventType;

// Check to see if more than the 5 seed synced events of type quarterly earnings exist in the data store and return accordingly. Typically used to check if trending ticker events have been synced or not.
- (BOOL)doTrendingTickerEventsExist;

#pragma mark - Event History related Methods

// Add history associated with an event to the EventHistory Data Store given the previous event 1 date, status, related date, current date, previous event 1 date stock price, previous event 1 related date stock price, current (right now yesterday's) stock price, Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (void)insertHistoryWithPreviousEvent1Date:(NSDate *)previousEv1Date previousEvent1Status:(NSString *)previousEv1Status previousEvent1RelatedDate:(NSDate *)previousEv1RelatedDate currentDate:(NSDate *)currDate previousEvent1Price:(NSNumber *)previousEv1Price previousEvent1RelatedPrice:(NSNumber *)previousEv1RelatedPrice currentPrice:(NSNumber *)currentEvPrice parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType;

// Update non price related history, except current date, associated with an event to the EventHistory Data Store given the previous event 1 date, status, related date, current date, Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
-(void)updateEventHistoryWithPreviousEvent1Date:(NSDate *)previousEv1Date previousEvent1Status:(NSString *)previousEv1Status previousEvent1RelatedDate:(NSDate *)previousEv1RelatedDate parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType;

// Update event history prices with the given previous event 1 date (prior quarterly earnings) stock price, previous event 1 related date (prior quarter end) stock price, current (right now yesterday's) stock price for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (void)updateEventHistoryWithPreviousEvent1Price:(NSNumber *)previousEv1Price previousEvent1RelatedPrice:(NSNumber *)previousEv1RelatedPrice currentPrice:(NSNumber *)currentEvPrice parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType;

// Update event history with the current date
- (void)updateEventHistoryWithCurrentDate:(NSDate *)currDate parentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType;

// Get Event History for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (EventHistory *)getEventHistoryForParentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType;

// Check to see if Event History exists for the given Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (BOOL)doesEventHistoryExistForParentEventTicker:(NSString *)eventTicker parentEventType:(NSString *)eventType;

#pragma mark - Methods to call Company Data Source APIs

// Get a list of all companies and their tickers.
- (void)getAllCompaniesFromApi;

// Update the list of companies and their tickers, to include newer companies that have been added since the initial seeded DB. Whenever this is called, the logic here figures out hoe much needs to be synced. It relies on getAllCompaniesFromApi to do the actual sync.
- (void)getIncrementalCompaniesFromApi;

#pragma mark - Methods to call Company Event Data Source APIs

// Get the event details for a company given it's ticker. NOTE: This is somewhat of a misnomer as this call only fetches the earnings event details not others like product events.
- (void)getAllEventsFromApiWithTicker:(NSString *)companyTicker;

#pragma mark - Methods to call Economic Events Data Sources

// Get all the economic events and details from local storage, which currently is a json file and write them to the data store.
- (void)getAllEconomicEventsFromLocalStorage;

#pragma mark - Methods for Product Events Data

// Get all the product events and details from the data source APIs
- (void)getAllProductEventsFromApi;

// Check to see if 1) product events have been synced initially. 2) If there are new entries for product events on the server side. In either of these cases return true
// NOTE: If there is a new type of product event like launch or conference is added, add that here as well
- (BOOL)doProductEventsNeedToBeAddedRefreshed;

#pragma mark - Methods to call Company Stock Data Source APIs

// Get the historical and current stock prices for a company given it's ticker and the event type for which the historical data is being asked for. Currently only supported event type is Quarterly Earnings. Also, the listed company ticker and event type, together represent the event uniquely. Finally, the most current stock price that we have is yesterday.
- (void)getStockPricesFromApiForTicker:(NSString *)companyTicker companyEventType:(NSString *)eventType fromDateInclusive:(NSDate *)fromDate toDateInclusive:(NSDate *)toDate;

#pragma mark - Data Syncing Related

// Add the most basic set of most used company information to the company data store. This is done in a batch.
- (void)performBatchedCompanySeedSyncLocally;

// Add the most basic set of most used events to the event data store. This is done locally and is dependent on the
// set of companies that are included in the Company Seed Sync.
// IMPORTANT: If you are changing the list or number of companies here, reconcile with doTrendingTickerEventsExist.
- (void)performEventSeedSyncRemotely;

// Add tickers and events for trending stocks.
- (void)performTrendingEventSyncRemotely;

// Update the existing events in the local data store, with latest information from the remote data source, if it's
// likely that the remote source has been updated. There are 2 scenarios where it's likely:
// 1. If the speculated date of an event is within 2 weeks of today, then we consider it likely that the event has been updated
// in the remote source. The likely event also needs to have a certainty of either "Estimated" or "Unknown" to qualify for the update.
// 2. If the confirmed date of the event is in the past.
- (void)updateEventsFromRemoteIfNeeded;

#pragma mark - User State Related

// Get the Company Data Sync Status for the one user in the data store. Returns the following values:
// "NoSyncPerformed" means there has been no company data has been added to the company data store
// "SeedSyncDone" means the most basic set of company information has been added to
// the company data store.
// "FullSyncDone" means the full set of company information has been added to
// the company data store.
- (NSString *)getCompanySyncStatus;

// Get the Page number to which the company data sync was completed, ranges from 0 to total no of pages in the company data API response.
- (NSNumber *)getCompanySyncedUptoPage;

// Get the total number of pages of company data that needs to be synced from the company data API response.
- (NSNumber *)getTotalNoOfCompanyPagesToSync;

// Get the Event Data Sync Status for the one user in the data store. Returns the following values:
// "SeedSyncDone" means the most basic set of events information has been added to the event data store.
// "NoSyncPerformed" means no event information has been added to the event data store.
- (NSString *)getEventSyncStatus;

// Get the date on which all the companies were last synced.
- (NSDate *)getCompanySyncDate;

// Add company data sync status to the user data store. Current design is that the user object is created
// when a company data sync is done. Thus this method creates the user with the given status if it
// doesn't exist or updates the user with the new status if the user exists.
// Additionally since the user object is created when the first company data sync is done, set the event sync
// status for the user to "NoSyncPerformed" when creating the user, not for the update.
// Synced Page number is the page to which the company data sync was completed, ranges from 0 to total no of pages in the company data API response
- (void)upsertUserWithCompanySyncStatus:(NSString *)syncStatus syncedPageNo: (NSNumber *)pageNo;

// Update the total number of company pages to be synced to the user data store. This method updates the user with the given number. If the user doesn't exist, it logs an error. Since the user is created the first time a company event sync is performed, CALL THIS METHOD AFTER THE UPSERT COMPANY SYNC STATUS METHOD IS CALLED AT LEAST ONCE.
- (void)updateUserWithTotalNoOfCompanyPagesToSync:(NSNumber *)noOfPages;

// Add events data sync status to the user data store. This method updates the user with the given events sync
// status. If the user doesn't exist, it logs an error. Since the user is created the first time a company
// event sync is performed, CALL THIS METHOD AFTER THE UPSERT COMPANY SYNC STATUS METHOD IS CALLED ONCE.
- (void)updateUserWithEventSyncStatus:(NSString *)syncStatus;

#pragma mark - Action Related

// Add an Action associated with an event to the Action Data Store given the Action Type, Action Status, Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (void)insertActionOfType:(NSString *)actionType status:(NSString *)actionStatus eventTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType;

// Check to see if a Queued Action associated with an event is present, in the Action Data Store, given the Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
// TO DO: Refactor this and the method above into one.
- (BOOL)doesQueuedReminderActionExistForEventWithTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType;

// Update an Action status in the Action Data Store given the Action Type, Event Company Ticker and Event Type, which uniquely identify the event.
- (void)updateActionWithStatus:(NSString *)actionStatus type:(NSString *)actionType eventTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType;

// Check to see if an Action associated with an event is present, in the Action Data Store, given the Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
// TO DO: Refactor here to add multiple types of actions.
- (BOOL)doesReminderActionExistForEventWithTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType;

@end
