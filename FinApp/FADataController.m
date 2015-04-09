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
- (void)insertEventWithDate:(NSDate *)eventDate details:(NSString *)eventDetails type:(NSString *)eventType certainty:(NSString *)eventCertainty listedCompany:(NSString *)listedCompanyTicker
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
    event.date = eventDate;
    event.details = eventDetails;
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

#pragma mark - Methods to call Data Source APIs

// Get a list of all companies and their tickers.
- (void)getAllCompaniesFromApi
{
    // To get all the companies use the metadata call of the Zacks Earnings Announcements (ZEA) database using
    // the following API: www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA&per_page=300&page=1&auth_token=Mq-sCZjPwiJNcsTkUyoQ
    
    // The API endpoint URL
    NSString *endpointURL = @"http://www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA";
    
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
            noOfPages = [self processResponse:responseData];
            
        } else {
            NSLog(@"ERROR: Could not get companies data from the API Data Source. Error description: %@",error.description);
        }
        
        ++pageNo;
        endpointURL = @"http://www.quandl.com/api/v2/datasets.json?query=*&source_code=ZEA";
    }
}

// Parse the companies API response and return total no of pages of companies in it.
// Before returning call on to formatting and adding companies data to the core data store.
- (NSInteger)processResponse:(NSData *)response {
    
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
    }
}

@end













