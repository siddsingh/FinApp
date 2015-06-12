//
//  FAEventsViewController.m
//  FinApp
//
//  Class that manages the view showing upcoming events.
//
//  Created by Sidd Singh on 12/18/14.
//  Copyright (c) 2014 Sidd Singh. All rights reserved.
//

#import "FAEventsViewController.h"
#import "FAEventsTableViewCell.h"
#import "FADataController.h"
#import "Event.h"
#import "Company.h"

@interface FAEventsViewController ()

// Get all companies from API. Typically called in a background thread
- (void)getAllCompaniesFromApiInBackground;

// Validate search text entered
- (BOOL) searchTextValid:(NSString *)text;

@end

@implementation FAEventsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    // Get a primary data controller that you will use later
    self.primaryDataController = [[FADataController alloc] init];
    
    // NSLog(@"TTTTTTTTTTTTTThe CompanySyncStatus is:%@ and EventSyncStatus is:%@",[self.primaryDataController getCompanySyncStatus],[self.primaryDataController getEventSyncStatus]);
    
    // Seed the company data, the very first time, to get the user started.
    if ([[self.primaryDataController getCompanySyncStatus] isEqualToString:@"NoSyncPerformed"]) {
        [self.primaryDataController performCompanySeedSyncLocally];
    }
    
    // Seed the events data, the very first time, to get the user started.
    if ([[self.primaryDataController getEventSyncStatus] isEqualToString:@"NoSyncPerformed"]) {
        [self.primaryDataController performEventSeedSyncRemotely];
    }
    
    // If the initial company data has been seeded, perform the full company data sync from the API
    // in the background
    if ([[self.primaryDataController getCompanySyncStatus] isEqualToString:@"SeedSyncDone"]) {
        [self performSelectorInBackground:@selector(getAllCompaniesFromApiInBackground) withObject:nil];
        // TO DO: Ideally, you only want to update the status after the full background fetch has succeeded
        [self.primaryDataController upsertUserWithCompanySyncStatus:@"FullSyncDone"];
    }
    
    // TO DO: Delete Later. Add Three Companies, Apple, Tesla, Electronic Arts
    // [self.eventDataController insertUniqueCompanyWithTicker:@"AAPL" name:@"Apple"];
    //[self.eventDataController insertUniqueCompanyWithTicker:@"TSLA" name:@"Tesla"];
    //[self.eventDataController insertUniqueCompanyWithTicker:@"EA" name:@"Electronic Arts"];
    
    // TO DO: Uncomment later and make it a background process
    //[self getAllCompaniesFromApiInBackground];
    //[self.primaryDataController getAllEventsFromApiWithTicker:@"CRM"];
    
    // Set the Filter Specified flag to false, indicating that no search filter has been specified
    self.filterSpecified = NO;
    
    // Set the filter type to None_Specified, meaning no filter has been specified.
    self.filterType = [NSString stringWithFormat:@"None_Specified"];
    
    //Query all events as that is the default view first shown
    self.eventResultsController = [self.primaryDataController getAllEvents];
    NSLog(@"Data Setup and Query done in viewdidload");
    
    // TO DO: Temporaray Data Setup for testing. Erase later
    
    // Add an event each for the three Companies
   /* [self.eventDataController insertEventWithDate:[NSDate date] details:@"Q1 Earnings Call" type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"AAPL"];
    [self.eventDataController insertEventWithDate:[NSDate date] details:@"Q2 Earnings Call" type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"TSLA"];
    [self.eventDataController insertEventWithDate:[NSDate date] details:@"Q3 Earnings Call" type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"EA"]; */
    
    // TO DO: Testing refresh of event data. Delete later
    [self.primaryDataController updateEventsFromRemoteIfNeeded];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Events List Table

// Return number of sections in the events list table view
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSLog(@"Number of sections in table view returned");
    // There's only one section for now
    return 1;
    
    
}

// Return number of rows in the events list table view
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
     NSInteger numberOfRows = 0;
    
    // If a search filter has been applied return the number of events in the filtered list of events or companies,
    // depending on the type of filter
    if (self.filterSpecified) {
        
        // If the filter type is Match_Companies_Events, meaning a filter of matching companies with existing events
        // has been specified.
        if ([self.filterType isEqualToString:@"Match_Companies_Events"]) {
            id filteredEventSection = [[self.filteredResultsController sections] objectAtIndex:section];
            // TO DO: Testing Delete
            NSLog(@"**********Number of Events:%lu",(unsigned long)[filteredEventSection numberOfObjects]);
            numberOfRows = [filteredEventSection numberOfObjects];
        }
        
        // If the filter type is Match_Companies_NoEvents, meaning a filter of matching companies with no existing events
        // has been specified.
        if ([self.filterType isEqualToString:@"Match_Companies_NoEvents"]) {
            id filteredCompaniesSection = [[self.filteredResultsController sections] objectAtIndex:section];
            // TO DO: Testing Delete
            NSLog(@"**********Number of Companies:%lu",(unsigned long)[filteredCompaniesSection numberOfObjects]);
            numberOfRows = [filteredCompaniesSection numberOfObjects];
        }
    }
    
    // If not, show all events
    else {
        // Use all events results set
        id eventSection = [[self.eventResultsController sections] objectAtIndex:section];
        // TO DO: Testing Delete
        NSLog(@"**********Number of Events:%lu",(unsigned long)[eventSection numberOfObjects]);
        numberOfRows = [eventSection numberOfObjects];
    }

    return numberOfRows;
}

// Return a cell configured to display an event or a company with a fetch event
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Rendering a cell with indexpath");
    
    FAEventsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventCell" forIndexPath:indexPath];
    
    // Get event or company  to display
    Event *eventAtIndex;
    Company *companyAtIndex;
    
    // If a search filter has been applied, GET the matching companies with events or companies with the fetch events message
    // depending on the type of filter applied
    if (self.filterSpecified) {
        
        // If the filter type is Match_Companies_Events, meaning a filter of matching companies with existing events
        // has been specified.
        if ([self.filterType isEqualToString:@"Match_Companies_Events"]) {
            // Use filtered events results set
            eventAtIndex = [self.filteredResultsController objectAtIndexPath:indexPath];
        }
        
        // If the filter type is Match_Companies_NoEvents, meaning a filter of matching companies with no existing events
        // has been specified.
        if ([self.filterType isEqualToString:@"Match_Companies_NoEvents"]) {
            // Use filtered companies results set
            companyAtIndex = [self.filteredResultsController objectAtIndexPath:indexPath];
        }
    }
    // If no search filter
    else {
        eventAtIndex = [self.eventResultsController objectAtIndexPath:indexPath];
    }
    
    // Depending the type of search filter that has been applied, SHOW the matching companies with events or companies
    // with the fetch events message.
    if ([self.filterType isEqualToString:@"Match_Companies_NoEvents"]) {
        
        // Show the company ticker associated with the event
        [[cell  companyTicker] setText:companyAtIndex.ticker];
        
        // Show the company name associated with the event
        [[cell  companyName] setText:companyAtIndex.name];
        
        // Show the "Get Events" text in the event display area
        [[cell  eventDescription] setText:@"Get Events"];
        
        // Set the fetch state of the event cell to true
        // TO DO: Should you really be holding logic state at the cell level or should there
        // be a unique identifier for each event ?
        cell.eventRemoteFetch = YES;
        
        // Set all other fields to empty
        [[cell eventDate] setText:@" "];
        [[cell eventCertainty] setText:@" "];
    }
    else {
        
        // Show the company ticker associated with the event
        [[cell  companyTicker] setText:eventAtIndex.listedCompany.ticker];
        
        // Show the company name associated with the event
        [[cell  companyName] setText:eventAtIndex.listedCompany.name];
        
        // Show the event type
        [[cell  eventDescription] setText:eventAtIndex.type];
        
        // Show the event date
        NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
        //[eventDateFormatter setDateFormat:@"dd-MMMM-yyyy"];
        [eventDateFormatter setDateFormat:@"EEEE,MMMM dd,yyyy"];
        NSString *eventDateString = [eventDateFormatter stringFromDate:eventAtIndex.date];
        NSString *eventTimeString = eventAtIndex.relatedDetails;
        // Append related details (timing information) to the event date if it's known
        if (![eventTimeString isEqualToString:@"Unknown"]) {
            eventDateString = [NSString stringWithFormat:@"%@(%@)",eventDateString,eventTimeString];
        }
        [[cell eventDate] setText:eventDateString];
        
        // Show the certainty of the event
        [[cell eventCertainty] setText:eventAtIndex.certainty];
    } 
    
    return cell;
}

// When a row is selected on the events list table, check to see if that row has an event cell with remote fetch status
// set to true, meaning the event needs to be fetched from the remote Data Source. Additionally clear out the search context.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Check to see if the row selected has an event cell with remote fetch status set to true
    FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
    if (cell.eventRemoteFetch) {
        
        // Fetch the event for the related parent company
        NSLog(@"Fetching Event Data for ticker:%@",(cell.companyTicker).text);
        [self.primaryDataController getAllEventsFromApiWithTicker:(cell.companyTicker).text];
        
        // Force a search to capture the refreshed event
        [self searchBarSearchButtonClicked:self.eventsSearchBar];
        
        // Resign first responder from Search Bar
        [self.eventsSearchBar resignFirstResponder];
        
        // Reload Events list table
        [self.eventsListTable reloadData];
    }
}

#pragma mark - Data Source API

// Get all companies from API. Typically called in a background thread
- (void)getAllCompaniesFromApiInBackground
{
    // Create a new FADataController so that this thread has its own MOC
    FADataController *companiesDataController = [[FADataController alloc] init];
    
    [companiesDataController getAllCompaniesFromApi];
}

#pragma mark - Search Bar Delegate Methods, Related

// When Search button associated with the search bar is clicked, search the ticker and name
// fields on the company related to the event, for the search text entered. Display the events
// found. If there are no events, search for the same fields on the company to display the matching
// companies to prompt the user to fetch the events data for these companies.
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    
    NSLog(@"Search Button Clicked");
    
    // Validate search text entered. If valid
    if ([self searchTextValid:searchBar.text]) {
    
        // Search the ticker and name fields on the company related to the events in the data store, for the
        // search text entered
        self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text];
        // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
        // has been specified.
        self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
        
        // If no events are found, search for the name and ticker fields on the companies data store.
        if ([self.filteredResultsController fetchedObjects].count == 0) {
            self.filteredResultsController = [self.primaryDataController searchCompaniesFor:searchBar.text];
            // Set the filter type to Match_Companies_NoEvents, meaning a filter matching companies with no existing events
            // has been specified.
            self.filterType = [NSString stringWithFormat:@"Match_Companies_NoEvents"];
        }
            
        // Set the Filter Specified flag to true, indicating that a search filter has been specified
        self.filterSpecified = YES;
        
        // Reload messages table
        [self.eventsListTable reloadData];
    }
    
    [searchBar resignFirstResponder];
}

// When text in the search bar is changed, search the ticker and name fields on the company related to the event,
// for the search text entered. Display the events found. If there are no events, search for the same fields on the
// company to display the matching companies to prompt the user to fetch the events data for these companies.
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    
    // Validate search text entered to make sure it's not empty.
    // TO DO: When we are validating for more like special characters, etc, modify the else clause to not reset the search results table
    // to show all events as we only want to do that when the text is cleared.
    // If valid
    if ([self searchTextValid:searchBar.text]) {
        
        // Search the ticker and name fields on the company related to the events in the data store, for the
        // search text entered
        self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text];
        // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
        // has been specified.
        self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
        
        // If no events are found, search for the name and ticker fields on the companies data store.
        if ([self.filteredResultsController fetchedObjects].count == 0) {
            self.filteredResultsController = [self.primaryDataController searchCompaniesFor:searchBar.text];
            // Set the filter type to Match_Companies_NoEvents, meaning a filter matching companies with no existing events
            // has been specified.
            self.filterType = [NSString stringWithFormat:@"Match_Companies_NoEvents"];
        }
        
        // Set the Filter Specified flag to true, indicating that a search filter has been specified
        self.filterSpecified = YES;
        
        // Reload messages table
        [self.eventsListTable reloadData];
    }
    
    // If not valid
    else {
        
        //Query all events as that is the default view
        self.eventResultsController = [self.primaryDataController getAllEvents];
        
        // Set the Filter Specified flag to false, indicating that no search filter has been specified
        self.filterSpecified = NO;
        
        // Set the filter type to None_Specified i.e. no filter is specified
        self.filterType = [NSString stringWithFormat:@"None_Specified"];
        
        // Reload messages table
        [self.eventsListTable reloadData];
        
        // TO DO: In case you want to clear the search context
        [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
    }
}

// Validate search text entered. Currently only checking for if the search text is empty.
- (BOOL) searchTextValid:(NSString *)text {
    
    // If the entered category is empty
    if ([text isEqualToString:@""]||(text.length == 0)) {
        
        return NO;
    }
    
    return YES;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
