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

#pragma mark - Events Data Related

// Upsert an Event along with a parent company to the Event Data Store i.e. If the specified event type for that particular company exists, update it. If not insert it.
- (void)upsertEventWithDate:(NSDate *)eventDate relatedDetails:(NSString *)eventRelatedDetails relatedDate:(NSDate *)eventRelatedDate type:(NSString *)eventType certainty:(NSString *)eventCertainty listedCompany:(NSString *)listedCompanyTicker;

// Get all Events. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllEvents;

// Search and return all events that match the search text on "ticker" and "name" fields for the listed Company.
// Returns a results controller with identities of all events recorded, but no more than batchSize (currently set to 15)
// objects’ data will be fetched from the data store at a time.
- (NSFetchedResultsController *)searchEventsFor:(NSString *)searchText;

// Search and return all companies that match the search text on "ticker" and "name" fields for the Company.
// Returns a results controller with identities of all companies recorded, but no more than batchSize (currently set
// to 15) objects’ data will be fetched from the data store at a time.
- (NSFetchedResultsController *)searchCompaniesFor:(NSString *)searchText;

// Get the date for an Event given the Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (NSDate *)getDateForEventOfType:(NSString *)eventType eventTicker:(NSString *)eventCompanyTicker;

#pragma mark - Methods to call Company Data Source APIs

// Get a list of all companies and their tickers. Current algorithm to do this is:
//
// 1. Use the metadata call of the Zacks Earnings Announcements (ZEA) database using the following API
// www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA&per_page=300&page=1
//
// 2. Use the following columns at the start to get the number of API calls to make to get all
// companies
// "total_count":7439,
// "current_page":1,
// "per_page":300,
//
// 3. On each page get the ticker and parse out the name using the following
// "code":"AVD",
// "name":"Earnings Announcement Dates for American Vanguard Corp. (AVD)"
// The logic here takes care of determining from which point should the companies be fetched.
// It's smart enough to not do a full sync every time.
- (void)getAllCompaniesFromApi;

#pragma mark - Methods to call Company Event Data Source APIs

// Get the event details for a company given it's ticker. Call the following API:
// www.quandl.com/api/v1/datasets/ZEA/AAPL.json?auth_token=Mq-sCZjPwiJNcsTkUyoQ
//
// Get the following types of events:
// 1. Quarterly Earnings: For this type we get the following pieces of information from the API response:
// a) Date on which the event takes place
// b) Details related to the event. "Quarterly Earnings" would have timing information
// "After Market Close", "Before Market Open, "During Market Trading", "Unknown".
// c) Date related to the event. "Quarterly Earnings" would have the end date of the next fiscal
// quarter to be reported
// d) Indicator if this event is "confirmed" or "speculated" or "unknown"
// {
//  "errors":{},
//  "id":15532680,
//  "source_code":"ZEA",....
//  "data":[
//     [
//       "2015-04-09",
//        20140930.0,
//   Date related to the event
//        20150331.0,
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
//        3.06,
//        20141231.0,
//        1.66,
//        20140331.0
//      ]
//         ]
// }
- (void)getAllEventsFromApiWithTicker:(NSString *)companyTicker;

#pragma mark - Data Syncing Related

// Add the most basic set of most used company information to the company data store. This is done locally
- (void)performCompanySeedSyncLocally;

// Add the most basic set of most used events to the event data store. This is done locally and is dependent on the
// set of companies that are included in the Company Seed Sync.
- (void)performEventSeedSyncRemotely;

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

// Get the Event Data Sync Status for the one user in the data store. Returns the following values:
// "SeedSyncDone" means the most basic set of events information has been added to the event data store.
// "NoSyncPerformed" means no event information has been added to the event data store.
- (NSString *)getEventSyncStatus;

// Add company data sync status to the user data store. Current design is that the user object is created
// when a company data sync is done. Thus this method creates the user with the given status if it
// doesn't exist or updates the user with the new status if the user exists.
// Additionally since the user object is created when the first company data sync is done, set the event sync
// status for the user to "NoSyncPerformed" when creating the user, not for the update.
// Synced Page number is the page to which the company data sync was completed, ranges from 0 to total no of pages in the company data API response
- (void)upsertUserWithCompanySyncStatus:(NSString *)syncStatus syncedPageNo: (NSNumber *)pageNo;

// Add events data sync status to the user data store. This method updates the user with the given events sync
// status. If the user doesn't exist, it logs an error. Since the user is created the first time a company
// event sync is performed, CALL THIS METHOD AFTER THE UPSERT COMPANY SYNC STATUS METHOD IS CALLED ONCE.
- (void)updateUserWithEventSyncStatus:(NSString *)syncStatus;

#pragma mark - Action Related

// Add an Action associated with an event to the Action Data Store given the Action Type, Action Status, Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
- (void)insertActionOfType:(NSString *)actionType status:(NSString *)actionStatus eventTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType;

// Update an Action status in the Action Data Store given the Action Type, Event Company Ticker and Event Type, which uniquely identify the event.
- (void)updateActionWithStatus:(NSString *)actionStatus type:(NSString *)actionType eventTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType;

// Check to see if an Action associated with an event is present, in the Action Data Store, given the Event Company Ticker and Event Type. Note: Currently, the listed company ticker and event type, together represent the event uniquely.
// TO DO: Refactor here to add multiple types of actions.
- (BOOL)doesReminderActionExistForEventWithTicker:(NSString *)eventCompanyTicker eventType:(NSString *)associatedEventType;

@end
