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

@interface FADataController ()

// Send a notification that the list of messages has changed (updated)
- (void)sendEventsChangeNotification;

// Send a notification that the list of events has changed (updated)
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents;

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

// Upsert an Event along with a parent company to the Event Data Store i.e. If the specified event type for that particular company exists, update it. If not insert it.
- (void)upsertEventWithDate:(NSDate *)eventDate relatedDetails:(NSString *)eventRelatedDetails relatedDate:(NSDate *)eventRelatedDate type:(NSString *)eventType certainty:(NSString *)eventCertainty listedCompany:(NSString *)listedCompanyTicker
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
    }
    
    // If the event exists update it
    else {
        
        // Don't need to update type and company as these are the unique identifiers
        existingEvent.date = eventDate;
        existingEvent.relatedDetails = eventRelatedDetails;
        existingEvent.relatedDate = eventRelatedDate;
        existingEvent.certainty = eventCertainty;
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

#pragma mark - Methods to call Company Data Source APIs

// Get a list of all companies and their tickers. The logic here takes care of determining from which point
// should the companies be fetched. It's smart enough to not do a full sync every time.
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
    
    // Check to see if No Sync or a Seed Data Sync has been performed for company information.
    // In either of these scenarios, attempt a full sync from page 1 of the company API response.
    if ([[self getCompanySyncStatus] isEqualToString:@"NoSyncPerformed"]||[[self getCompanySyncStatus] isEqualToString:@"SeedSyncDone"]) {
        
        // Set the company sync status to "FullSyncStarted" and no page has been currently synced.
        [self upsertUserWithCompanySyncStatus:@"FullSyncStarted" syncedPageNo:[NSNumber numberWithInteger: 0]];
    }
    // Else, if any pages were successfully synced attempt a new sync from the company API page No after the one that was last successfully synced
    else if (([[self getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]||[[self getCompanySyncStatus] isEqualToString:@"FullSyncAttemptedButFailed"])&&[[self getCompanySyncedUptoPage] integerValue] != 0) {
        
        pageNo = ([[self getCompanySyncedUptoPage] integerValue] + 1);
        // TO DO: Currently this is hardcoded to 25 as 25 pages worth of companies (7375 companies at 300 per page) were available as of July 15, 2105. When you change this, change the hard coded value below and in applicationWillTerminate in AppDelegate as well.
        noOfPages = 25;
        
        NSLog(@"**************Entered the get all companies background thread with page No to start from:%ld", (long)pageNo);
    }
    
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
        
         NSLog(@"******************************************Made request to get company data with page number:%@**************",endpointURL);
        
        // Process the response
        if (error == nil)
        {
            // Process the response that contains the first page of companies.
            // Get back total no of pages of companies in the response.
            noOfPages = [self processCompaniesResponse:responseData];
            
            // Keep the company sync status to "FullSyncStarted" but update the page number of the API response to the page that just finished.
            [self upsertUserWithCompanySyncStatus:@"FullSyncStarted" syncedPageNo:[NSNumber numberWithInteger: pageNo]];
            
        }
        else
        {
            // If there is an error set the company sync status to "FullSyncAttemptedButFailed", meaning a full company sync was attempted but failed before it could complete
            [self upsertUserWithCompanySyncStatus:@"FullSyncAttemptedButFailed" syncedPageNo:[NSNumber numberWithInteger:(pageNo-1)]];
            NSLog(@"ERROR: Could not get companies data from the API Data Source. Error description: %@",error.description);
        }
        
        ++pageNo;
        endpointURL = @"https://www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA";
        NSLog(@"Page Number is:%ld and NoOfPages is:%ld",(long)pageNo,(long)noOfPages);
    }
    
    // Add or Update the Company Data Sync status to SeedSyncDone. Check that all pages have been processed before doing so.
    // TO DO: Currently this is hardcoded to 25 as 25 pages worth of companies (7375 companies at 300 per page) were available as of July 15, 2105. When you change this, change the hard coded value above and in applicationWillTerminate in AppDelegate as well.
    if ([[self getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&((pageNo-1) >= 25))
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
    
    // DELETE: Use this endpoint for testing an incorrect API response.
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
        NSLog(@"The endpoint being called for getting company information is:%@",endpointURL);
        NSLog(@"The API response for getting company information is:%@",[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]);
        // Process the response that contains the events for the company.
        [self processEventsResponse:responseData forTicker:companyTicker];
            
    } else {
        // Log error to console
        NSLog(@"ERROR: Could not get events data from the API Data Source. Error description: %@",error.description);
        
        // Show user an error message
        [self sendUserMessageCreatedNotificationWithMessage:@"Unable to get events. Check Connection."];
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
    
    NSLog(@"The parsed data set is:%@",parsedDataSets.description);
    
    // Check to make sure that the correct response has come back. e.g. If you get an error message response from the API,
    // then you don't want to process the data and enter as events.
    // If response is not correct, show the user an error message
    if (parsedDataSets == NULL)
    {
        [self sendUserMessageCreatedNotificationWithMessage:@"Unable to get events. Try again later."];
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
        
        // Insert events data into the data store
        [self upsertEventWithDate:eventDate relatedDetails:eventDetails relatedDate:relatedDate type:eventType certainty:certaintyStr listedCompany:ticker];
    }
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
    [self upsertUserWithCompanySyncStatus:@"SeedSyncDone" syncedPageNo:[NSNumber numberWithInteger: 0]];
}

// Add the most basic set of most used events to the event data store. This is fetched from the data source
// API based on the set of companies that are included in the Company Seed Sync.
- (void)performEventSeedSyncRemotely {
    
    // Add the events for the 20 most used companies to the events database.
    // TO DO: CAPABILITY: Expand to include at least 50 most used companies.
   // [self getAllEventsFromApiWithTicker:@"AAPL"];
    [self getAllEventsFromApiWithTicker:@"TSLA"];
    // TO DO: Commenting to not expire the API test limits. Uncomment when ready to finally test for shipping.
   // [self getAllEventsFromApiWithTicker:@"EA"];
    [self getAllEventsFromApiWithTicker:@"CRM"];
   /* [self getAllEventsFromApiWithTicker:@"NFLX"];
    [self getAllEventsFromApiWithTicker:@"FB"];
    [self getAllEventsFromApiWithTicker:@"EA"];
    [self getAllEventsFromApiWithTicker:@"MSFT"];
    [self getAllEventsFromApiWithTicker:@"TWTR"];
    [self getAllEventsFromApiWithTicker:@"TGT"];
    [self getAllEventsFromApiWithTicker:@"QCOM"];
    [self getAllEventsFromApiWithTicker:@"NKE"]; */
    
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

@end

