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
    existingCompany  = [[dataStoreContext executeFetchRequest:companyFetchRequest error:&error] lastObject];
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
    }
}

#pragma mark - Events Data Related

// Add an Event along with a parent company to the Event Data Store
- (void)insertEventWithDate:(NSDate *)eventDate relatedDetails:(NSString *)eventRelatedDetails relatedDate:(NSDate *)eventRelatedDate type:(NSString *)eventType certainty:(NSString *)eventCertainty listedCompany:(NSString *)listedCompanyTicker
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the parent listed company for the event by doing a case insensitive query on the company ticker
    NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
    [companyFetchRequest setEntity:companyEntity];
    NSPredicate *companyPredicate = [NSPredicate predicateWithFormat:@"ticker =[c] %@",listedCompanyTicker];
    [companyFetchRequest setPredicate:companyPredicate];
    NSError *error;
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
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

#pragma mark - Methods to call Company Data Source APIs

// Get a list of all companies and their tickers.
- (void)getAllCompaniesFromApi
{
    // To get all the companies use the metadata call of the Zacks Earnings Announcements (ZEA) database using
    // the following API: www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA&per_page=300&page=1&auth_token=Mq-sCZjPwiJNcsTkUyoQ
    
    // The API endpoint URL
    NSString *endpointURL = @"https://www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA";
    
    // Set no of messages being returned per page to 300
    NSInteger noOfCompaniesPerPage = 300;
    // Set no of results pages to 1
    NSInteger noOfPages = 1;
    // Set page no to 1
    NSInteger pageNo = 1;

    
    // Retrieve first page to get no of pages and then keep retrieving till you get all pages.
    while (pageNo <= noOfPages) {
        
        // Append no of messages per page to the endpoint URL &per_page=300&page=1
        endpointURL = [NSString stringWithFormat:@"%@&per_page=%ld",endpointURL,(long)noOfCompaniesPerPage];
        
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
        
        // Process the response
        if (error == nil)
        {
            // Process the response that contains the first page of companies.
            // Get back total no of pages of companies in the response.
            noOfPages = [self processCompaniesResponse:responseData];
            
        } else {
            NSLog(@"ERROR: Could not get companies data from the API Data Source. Error description: %@",error.description);
        }
        
        ++pageNo;
        endpointURL = @"https://www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA";
    }
    
    // Add or Update the Company Data Sync status to SeedSyncDone.
    [self upsertUserWithCompanySyncStatus:@"FullSyncDone"];
}

// Parse the companies API response and return total no of pages of companies in it.
// Before returning call on to formatting and adding companies data to the core data store.
- (NSInteger)processCompaniesResponse:(NSData *)response {
    
    NSError *error;
    
    // Set no of results pages to 1
    NSInteger noOfPages = 1;
    
    // Here's the format of the companies query response
    // {
    //   "total_count":7439,
    //   "current_page":1,
    //   "per_page":300,
    //   "docs":[
    //        {
    //          "id":15533777,
    //          "source_id":12930,
    //          "source_code":"ZEA",
    //          "code":"AVD",
    //          "name":"Earnings Announcement Dates for American Vanguard Corp. (AVD)",
    
    // Get the response into a parsed object
    NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:response
                                                                   options:kNilOptions
                                                                     error:&error];
    
    // Call on to formatting and adding companies data to the core data store.
    [self formatAddCompanies:parsedResponse];
    
    // Get the total no of companies from the parsed response
    NSString *parsedNoOfCompanies = [parsedResponse objectForKey:@"total_count"];
    NSInteger noOfCompanies = [parsedNoOfCompanies integerValue];
    
    // Get the no of companies per page from the parsed response
    NSString *parsedNoOfCompaniesPerPage = [parsedResponse objectForKey:@"per_page"];
    NSInteger noOfCompaniesPerPage = [parsedNoOfCompaniesPerPage integerValue];
    
    // Compute total no of pages of companies;
    if ((noOfCompanies == 0)||(noOfCompaniesPerPage == 0)) {
        NSLog(@"ERROR: API Data Source returned an incorrect 0 value for either noOfCompanies or noOfCompaniesPerPage while getting all companies. Raw Response Data from the API was: %@",[[NSString alloc]initWithData:response encoding:NSUTF8StringEncoding]);
        //NSLog(@"The raw response from the API is:%@", responseDataStr);
    } else
    {
        NSLog(@"No Of Companies: %ld and No of Companies Per Page: %ld", (long)noOfCompanies, (long)noOfCompaniesPerPage);
        noOfPages = (noOfCompanies/noOfCompaniesPerPage) + 1;
        if ((noOfCompanies%noOfCompaniesPerPage)== 0){
            -- noOfPages;
        }
    }
    
    return noOfPages;
}

// Parse the list of companies and their tickers, format them and add them to the core data message store.
- (void)formatAddCompanies:(NSDictionary *)parsedResponse {
    
    // Here's the format of the companies query response
    // {
    //   "total_count":7439,
    //   "current_page":1,
    //   "per_page":300,
    //   "docs":[
    //        {
    //          "id":15533777,
    //          "source_id":12930,
    //          "source_code":"ZEA",
    //          "code":"AVD",
    //          "name":"Earnings Announcement Dates for American Vanguard Corp. (AVD)",
    
    // Get the list of companies first from the overall response
    NSArray *parsedCompanies = [parsedResponse objectForKey:@"docs"];
    
    // Then loop through the companies, get the appropriate fields and insert them into the data store
    for (NSDictionary *company in parsedCompanies) {
        
        // Get the company ticker and company name string
        NSString *companyTicker = [company objectForKey:@"code"];
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
    // www.quandl.com/api/v1/datasets/ZEA/AAPL.json?auth_token=Mq-sCZjPwiJNcsTkUyoQ
    
    // The API endpoint URL
    NSString *endpointURL = @"https://www.quandl.com/api/v1/datasets/ZEA";
        
    // Append ticker for the company to the API endpoint URL
    endpointURL = [NSString stringWithFormat:@"%@/%@.json",endpointURL,companyTicker];
        
    // Append auth token to the call
    endpointURL = [NSString stringWithFormat:@"%@?auth_token=Mq-sCZjPwiJNcsTkUyoQ",endpointURL];
        
    NSError * error = nil;
    NSURLResponse *response = nil;
        
    // Make the call synchronously
    NSMutableURLRequest *eventsRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpointURL]];
    NSData *responseData = [NSURLConnection sendSynchronousRequest:eventsRequest returningResponse:&response
                                                                 error:&error];
        
    // Process the response
    if (error == nil)
    {
        // Process the response that contains the events for the company.
        [self processEventsResponse:responseData forTicker:companyTicker];
            
    } else {
        NSLog(@"ERROR: Could not get events data from the API Data Source. Error description: %@",error.description);
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
    
    // Get the response into a parsed object
    NSDictionary *parsedResponse = [NSJSONSerialization JSONObjectWithData:response
                                                                   options:kNilOptions
                                                                     error:&error];
    
    // Get the list of data sets first from the overall response
    NSArray *parsedDataSets = [parsedResponse objectForKey:@"data"];
    
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
    // For Quarterly Earnings: 1 (After market closes), 2 (Before market opens), 3 (During market trading) or 4 (Unknown)
    NSLog(@"The timing details related to the event: %@",[parsedEventsList objectAtIndex:9]);
    NSString *eventDetails = [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:9]];
    // Convert to human understandable string
    if ([eventDetails isEqualToString:@"1"]) {
        eventDetails = [NSString stringWithFormat:@"After market closes"];
    }
    if ([eventDetails isEqualToString:@"2"]) {
        eventDetails = [NSString stringWithFormat:@"Before market opens"];
    }
    if ([eventDetails isEqualToString:@"3"]) {
        eventDetails = [NSString stringWithFormat:@"During market trading"];
    }
    if ([eventDetails isEqualToString:@"4"]) {
        eventDetails = [NSString stringWithFormat:@"Unknown"];
    }
    NSLog(@"The timing details related to the event formatted: %@",eventDetails);
    
    
    // Get the Date related to the event which is the 3rd item
    // 1. "Quarterly Earnings" would have the end date of the next fiscal quarter
    // to be reported
    NSLog(@"The quarter end date related to the event: %@",[parsedEventsList objectAtIndex:2]);
    NSString *relatedDateStr =  [NSString stringWithFormat: @"%@", [parsedEventsList objectAtIndex:2]];
    // Convert from string to Date
    NSDateFormatter *relatedDateFormatter = [[NSDateFormatter alloc] init];
    [relatedDateFormatter setDateFormat:@"yyyyMMdd"];
    NSDate *relatedDate = [relatedDateFormatter dateFromString:relatedDateStr];
    NSLog(@"The quarter end date related to the event formatted as a Date: %@",relatedDate);
    
    // Get Indicator if this event is "confirmed" or "speculated" or "unknown" which is the 9th item
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
    
    // Insert events data into the data store
    [self insertEventWithDate:eventDate relatedDetails:eventDetails relatedDate:relatedDate type:eventType certainty:certaintyStr listedCompany:ticker];
}

#pragma mark - Data Syncing Related

// Add the most basic set of most used company information to the company data store. This is done locally.
- (void)performCompanySeedSyncLocally {
    
    // Add the 20 most used company tickers and name to the company database.
    // TO DO: CAPABILITY: Expand to include at least 50 most used companies.
    // TO DO: OPTIMIZATION: Since the seed sync will be done when the company data store is empty, add a write to store without checking for duplicates method.
    // TO DO: TEST: How do you handle different kinds of shares like GOOGLE
    [self insertUniqueCompanyWithTicker:@"AAPL" name:@"Apple Inc"];
    [self insertUniqueCompanyWithTicker:@"TSLA" name:@"Tesla Motors Inc"];
    [self insertUniqueCompanyWithTicker:@"EA" name:@"Electronic Arts Inc"];
    [self insertUniqueCompanyWithTicker:@"CRM" name:@"Salesforce.com Inc"];
    [self insertUniqueCompanyWithTicker:@"NFLX" name:@"Netflix Inc"];
    [self insertUniqueCompanyWithTicker:@"FB" name:@"Facebook Inc"];
    [self insertUniqueCompanyWithTicker:@"EA" name:@"Electronic Arts Inc"];
    [self insertUniqueCompanyWithTicker:@"MSFT" name:@"Microsoft Corp"];
    [self insertUniqueCompanyWithTicker:@"TWTR" name:@"Twitter Inc"];
    [self insertUniqueCompanyWithTicker:@"TGT" name:@"Target Corp"];
    [self insertUniqueCompanyWithTicker:@"QCOM" name:@"Qualcomm Inc"];
    [self insertUniqueCompanyWithTicker:@"NKE" name:@"Nike Inc"];
    
    // Add or Update the Company Data Sync status to SeedSyncDone.
    [self upsertUserWithCompanySyncStatus:@"SeedSyncDone"];
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

// Add company data sync status to the user data store. Current design is that the user object is created
// when a company data sync is done. Thus this method creates the user with the given status if it
// doesn't exist or updates the user with the new status if the user exists.
- (void)upsertUserWithCompanySyncStatus:(NSString *)syncStatus
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
    }
    
    // If the user exists
    else {
        existingUser.companySyncStatus = syncStatus;
        existingUser.companySyncDate = [NSDate date];
    }
    
    // Update the user
    if (![dataStoreContext save:&error]) {
        NSLog(@"ERROR: Saving user company data sync status to data store failed: %@",error.description);
    }
}

@end













