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

// Add an Event along with a parent company to the Event Data Store
- (void)insertEventWithDate:(NSDate *)eventDate details:(NSString *)eventDetails type:(NSString *)eventType certainty:(NSString *)eventCertainty listedCompany:(NSString *)listedCompanyTicker;

// Get all Events. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllEvents;

#pragma mark - Methods to call Data Source APIs

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
- (void)getAllCompaniesFromApi;

@end
