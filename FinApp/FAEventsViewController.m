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
    
    // Seed the company data, the very first time, to get the user started
    if ([[self.primaryDataController getCompanySyncStatus] isEqualToString:@"NoSyncPerformed"]) {
        [self.primaryDataController performCompanySeedSyncLocally];
    }
    
    // If the initial company data has been seeded, perform the full company data sync from the API
    // in the background
    if ([[self.primaryDataController getCompanySyncStatus] isEqualToString:@"SeedSyncDone"]) {
        [self performSelectorInBackground:@selector(getAllCompaniesFromApiInBackground) withObject:nil];
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
    
    //Query all events as that is the default view first shown
    self.eventResultsController = [self.primaryDataController getAllEvents];
    NSLog(@"Data Setup and Query done in viewdidload");
    
    // TO DO: Temporaray Data Setup for testing. Erase later
    
    // Add an event each for the three Companies
   /* [self.eventDataController insertEventWithDate:[NSDate date] details:@"Q1 Earnings Call" type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"AAPL"];
    [self.eventDataController insertEventWithDate:[NSDate date] details:@"Q2 Earnings Call" type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"TSLA"];
    [self.eventDataController insertEventWithDate:[NSDate date] details:@"Q3 Earnings Call" type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"EA"]; */
    
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
    
    // TO DO: Placeholder for testing
    //return 1;
    
    //NSLog(@"EventResultsController:::%@", self.eventResultsController);
    // NSArray *eventSection = [self.eventResultsController sections];
    //NSLog(@"EventSection:::%@", eventSection);
    NSLog(@"Number of rows in table view returned");
    // return 1;
    //return [eventSection count];
    id eventSection = [[self.eventResultsController sections] objectAtIndex:section];
    NSLog(@"**********Number of Events:%lu",(unsigned long)[eventSection numberOfObjects]);
    return [eventSection numberOfObjects];
}

// Return a cell configured to display a task or a task nav item
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Rendering a cell with indexpath");
    
    FAEventsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventCell" forIndexPath:indexPath];
    
    // Get event to display
    Event *eventAtIndex;
    eventAtIndex = [self.eventResultsController objectAtIndexPath:indexPath];
    
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
    
    return cell;
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
// fields on the company related to the event, for the search text entered.
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    
    // Validate search text entered. If valid
    if ([self searchTextValid:searchBar.text]) {
        
            
        // search the ticker and name fields on the company related to the events in the data store, for the
        // search text entered
        self.filteredEventsController = [self.primaryDataController searchAllEventsFor:searchBar.text];
            
        // Set the Filter Specified flag to true, indicating that a search filter has been specified
        self.filterSpecified = YES;
        
        // Search the from and content fields on messages in that category, in core data, for the search text entered.
        self.filteredMessagesController = [self.yamMsgDataController searchMessagesFor:searchBar.text inCategory:self.currentNavItemTitle];
        
        // Reload messages table
        [self.messagesTable reloadData];
    }
    
    [searchBar resignFirstResponder];
}

// Text in the search bar is changed
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    
    // Validate search text entered. If valid
    if ([self searchTextValid:searchBar.text]) {
        
        // If the messages navigation item is the default "All"
        if ([self.currentNavItemTitle isEqualToString:@"All"]) {
            
            // Search the from and content fields on all messages, in core data, for the search text entered.
            self.filteredMessagesController = [self.yamMsgDataController searchAllMessagesFor:searchBar.text];
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
        }
        // If the messages navigation item is a category
        else {
            
            // Search the from and content fields on messages in that category, in core data, for the search text entered.
            self.filteredMessagesController = [self.yamMsgDataController searchMessagesFor:searchBar.text inCategory:self.currentNavItemTitle];
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
        }
        
        // Reload messages table
        [self.messagesTable reloadData];
    }
}

// Validate search text entered
- (BOOL) searchTextValid:(NSString *)text {
    
    // If the entered category is empty
    if ([text isEqualToString:@""]) {
        return NO;
    }
    
    // If the length of text is 0
    if (text.length == 0) {
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
