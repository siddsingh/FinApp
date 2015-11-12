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
#import <stdlib.h>
#import "Reachability.h"
#import <UIKit/UIKit.h>
#import "FAEventDetailsViewController.h"
#import "EventHistory.h"

@interface FAEventsViewController ()

// Get all companies from API. Typically called in a background thread
- (void)getAllCompaniesFromApiInBackground;

// Validate search text entered
- (BOOL) searchTextValid:(NSString *)text;

// Get events for company given a ticker. Typically called in a background thread.
- (void)getAllEventsFromApiInBackgroundWithTicker:(NSString *)ticker;

// Get stock prices for company given a ticker and event type (event info). Executes in the main thread.
- (void)getPricesWithCompanyTicker:(NSString *)ticker eventType:(NSString *)type dataController:(FADataController *)specificDataController;

// Send a notification to the events list controller with a message that should be shown to the user
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents;

// Return a color scheme from darker to lighter based on rwo number with darker on top. Currently returning a dark gray scheme.
- (UIColor *)getColorForIndexPath:(NSIndexPath *)indexPath;

// Compute the likely date for the previous event based on current event type (currently only Quarterly), previous event related date (e.g. quarter end related to the quarterly earnings), current event date and current event related date.
- (NSDate *)computePreviousEventDateWithCurrentEventType:(NSString *)currentType currentEventDate:(NSDate *)currentDate currentEventRelatedDate:(NSDate *)currentRelatedDate previousEventRelatedDate:(NSDate *)previousRelatedDate;

// Check if there is internet connectivity
- (BOOL) checkForInternetConnectivity;

@end

@implementation FAEventsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    // Visual styling setup
    
    // Make the message bar fully transparent so that it's invisible to the user
    self.messageBar.alpha = 0.0;
    
    // Show today's date in the navigation bar header.
    NSDateFormatter *todayDateFormatter = [[NSDateFormatter alloc] init];
    [todayDateFormatter setDateFormat:@"EEE MMMM dd"];
    [self.navigationController.navigationBar.topItem setTitle:[todayDateFormatter stringFromDate:[NSDate date]]];
    
    // Change the color of the events search bar placeholder text and text entered to be white.
    [self.eventsSearchBar setBackgroundImage:[UIImage new]];
    UITextField *eventSearchBarInputFld = [self.eventsSearchBar valueForKey:@"_searchField"];
    [eventSearchBarInputFld setValue:[UIColor whiteColor] forKeyPath:@"_placeholderLabel.textColor"];
    eventSearchBarInputFld.textColor = [UIColor whiteColor];
    // TO DO: Finally decide between this currently set blue or purple color.
    //eventSearchBarInputFld.backgroundColor = [UIColor colorWithRed:81.0f/255.0f green:54.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
    eventSearchBarInputFld.backgroundColor = [UIColor colorWithRed:78.0f/255.0f green:132.0f/255.0f blue:216.0f/255.0f alpha:1.0f];
    
    // Do the same for the Magnifying glass icon in the search bar.
    UIImageView *magGlassIcon = (UIImageView *)eventSearchBarInputFld.leftView;
    magGlassIcon.image = [magGlassIcon.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    magGlassIcon.tintColor = [UIColor whiteColor];
    
    // Do the same for the Clear button in the search bar.
    UIButton *searchClearBtn = [eventSearchBarInputFld valueForKey:@"_clearButton"];
    [searchClearBtn setImage:[searchClearBtn.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    searchClearBtn.tintColor = [UIColor whiteColor];
    
    // Get a primary data controller that you will use later
    self.primaryDataController = [[FADataController alloc] init];
    
    // Ensure that the remote fetch spinner is not animating thus hidden
    [self.remoteFetchSpinner stopAnimating];
    
    // TO DO: DEBUGGING: DELETE. Make one of the events confirmed to yesterday
    // Get the date for the event represented by the cell
    /*NSDate *today = [NSDate date];
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = -1;
    NSDate *yesterday = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:today options:0];
   [self.primaryDataController upsertEventWithDate:yesterday relatedDetails:@"Unknown" relatedDate:yesterday type:@"Quarterly Earnings" certainty:@"Estimated" listedCompany:@"TSLA" estimatedEps:[NSNumber numberWithDouble:0.1] priorEndDate:[NSDate date] actualEpsPrior:[NSNumber numberWithDouble:0.2]];
    [self.primaryDataController upsertEventWithDate:yesterday relatedDetails:@"Unknown" relatedDate:yesterday type:@"Quarterly Earnings" certainty:@"Estimated" listedCompany:@"AAPL" estimatedEps:[NSNumber numberWithDouble:0.1] priorEndDate:[NSDate date] actualEpsPrior:[NSNumber numberWithDouble:0.2]];
    //[self.primaryDataController upsertEventWithDate:yesterday relatedDetails:@"After Market Close" relatedDate:yesterday type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"AVGO"]; */
    
    // Register a listener for changes to events stored locally
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(eventStoreChanged:)
                                                 name:@"EventStoreUpdated" object:nil];
    
    // Register a listener for messages to be shown to the user in the top bar userMessageGenerated
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userMessageGenerated:)
                                                 name:@"UserMessageCreated" object:nil];
    
    
    // Register a listener for refreshing the overall screen header, currently with today's date
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateScreenHeader:)
                                                 name:@"UpdateScreenHeader" object:nil];
    
   // Seed the company data, the very first time, to get the user started.
    // TO DO: UNCOMMENT FOR PRE SEEDING DB: Commenting out since we don't want to kick off a company/event sync due to preseeded data.
    if ([[self.primaryDataController getCompanySyncStatus] isEqualToString:@"NoSyncPerformed"]) {
        
        [self.primaryDataController performBatchedCompanySeedSyncLocally];
    }
    
    // Check for connectivity. If yes, sync data from remote data source
    if ([self checkForInternetConnectivity]) {
        
        // TO DO: UNCOMMENT FOR PRE SEEDING DB: Commenting out since we don't want to kick off a company/event sync due to preseeded data.
    
        // Seed the events data, the very first time, to get the user started.
        if ([[self.primaryDataController getEventSyncStatus] isEqualToString:@"NoSyncPerformed"]) {
            [self.primaryDataController performEventSeedSyncRemotely];
        }
        
        // If the initial company data has been seeded, perform the full company data sync from the API
        // in the background
        if ([[self.primaryDataController getCompanySyncStatus] isEqualToString:@"SeedSyncDone"]) {
            
            [self performSelectorInBackground:@selector(getAllCompaniesFromApiInBackground) withObject:nil];
        }
    }
    // If not, show error message
    else {
        
        [self sendUserMessageCreatedNotificationWithMessage:@"No Connection! Limited functionality available."];
    }
    
    // TO DO: Delete Later. In here for Testing.
    [self.primaryDataController getAllCompanies];
    
    // Set the Filter Specified flag to false, indicating that no search filter has been specified
    self.filterSpecified = NO;
    
    // Set the filter type to None_Specified, meaning no filter has been specified.
    self.filterType = [NSString stringWithFormat:@"None_Specified"];
    
    // Query all events as that is the default view first shown
    self.eventResultsController = [self.primaryDataController getAllEvents];
    NSLog(@"Data Setup and Query done in viewdidload");
    
    // This will remove extra separators from the bottom of the tableview which doesn't have any cells
    self.eventsListTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
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

// Set the header for the table view to a special table cell that serves as header.
-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UITableViewCell *headerView = nil;
    
    headerView = [tableView dequeueReusableCellWithIdentifier:@"EventsTableHeader"];
    return headerView;
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
// TO DO LATER: IMPORTANT: Any change to the formatting here could affect reminder creation (processReminderForEventInCell:,editActionsForRowAtIndexPath) since the reminder values are taken from the cell. Additionally changes here need to be reconciled with changes in the getEvents for ticker's queued reminder creation.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    // Get a custom cell to display
    FAEventsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventCell" forIndexPath:indexPath];
    
    //TO DO: Delete Later. Reset color for Event description to dark text, in case it's been set to blue for a "Get Events" display
    //cell.eventDescription.textColor = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    // Reset color for Event Date to dark text, in case it's been set to blue for a "Get Earnings" display.
    cell.eventDate.textColor = [UIColor colorWithRed:45.0f/255.0f green:45.0f/255.0f blue:45.0f/255.0f alpha:1.0f];
    
    // Set the compnay ticker background color to a darker to lighter (darker at the top) based on row number.
    // Currently supporting a dark gray scheme
    cell.companyTicker.backgroundColor = [self getColorForIndexPath:indexPath];
    
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
        NSLog(@"Before cell is set to display when values are being fetched from results controller, company ticker is:%@ and company confirmed is:%@",eventAtIndex.listedCompany.ticker,eventAtIndex.certainty);
    }
    
    // Depending the type of search filter that has been applied, Show the matching companies with events or companies
    // with the fetch events message.
    if ([self.filterType isEqualToString:@"Match_Companies_NoEvents"]) {
        
        // Show the company ticker associated with the event
        [[cell  companyTicker] setText:companyAtIndex.ticker];
        
        // Show the company name associated with the event
        [[cell  companyName] setText:companyAtIndex.name];
        
        // Show the "Get Events" text in the event display area.
        // TO DO: Delete Later. With the reformatting, the Get text should be shown in the event date column
        //[[cell  eventDescription] setText:@"Get Events"];
        //cell.eventDescription.textColor = [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
        [[cell eventDate] setText:@"Get Earnings"];
        // Set color to a link blue to provide a visual cue to click
        cell.eventDate.textColor = [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
        
        // Set the fetch state of the event cell to true
        // TO DO: Should you really be holding logic state at the cell level or should there
        // be a unique identifier for each event ?
        cell.eventRemoteFetch = YES;
        
        // Set all other fields to empty
        // TO DO: Delete Later since we will show the "Get Earnings" Message in the Event Date.
        //[[cell eventDate] setText:@" "];
        [[cell eventDescription] setText:@" "];
        [[cell eventCertainty] setText:@" "];
    }
    else {
        
        // TO DO LATER: !!!!!!!!!!IMPORTANT!!!!!!!!!!!!!: Any change to the formatting here could affect reminder creation (processReminderForEventInCell:,editActionsForRowAtIndexPath) since the reminder values are taken from the cell. Additionally changes here need to be reconciled with changes in the getEvents for ticker's queued reminder creation.
        
        // Show the company ticker associated with the event
        [[cell  companyTicker] setText:eventAtIndex.listedCompany.ticker];
        
        // Show the company name associated with the event
        [[cell  companyName] setText:eventAtIndex.listedCompany.name];
        
        // Set the fetch state of the event cell to false
        // TO DO: Should you really be holding logic state at the cell level or should there
        // be a unique identifier for each event ?
        cell.eventRemoteFetch = NO;
        
        // Show the event type. Format it for display. Currently map "Quarterly Earnings" to Quarterly.
        // TO DO LATER: !!!!!!!!!!IMPORTANT!!!!!!!!!!!!! If you are making a change here, reconcile with prepareForSegue in addition to the methods mentioned above.
        if ([eventAtIndex.type isEqualToString:@"Quarterly Earnings"])
        [[cell  eventDescription] setText:@"Quarterly"];
        
        // Show the event date
        NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
        // TO DO: For later different formatting styles.
        //[eventDateFormatter setDateFormat:@"dd-MMMM-yyyy"];
        //[eventDateFormatter setDateFormat:@"EEEE,MMMM dd,yyyy"];
        [eventDateFormatter setDateFormat:@"EEE MMMM dd"];
        NSString *eventDateString = [eventDateFormatter stringFromDate:eventAtIndex.date];
        NSString *eventTimeString = eventAtIndex.relatedDetails;
        // Append related details (timing information) to the event date if it's known
        if (![eventTimeString isEqualToString:@"Unknown"]) {
            //Format "After Market Close","Before Market Open", "During Market Trading" to be "After Close" & "Before Open" & "During Open"
            if ([eventTimeString isEqualToString:@"After Market Close"]) {
                eventTimeString = [NSString stringWithFormat:@"After Close"];
            }
            if ([eventTimeString isEqualToString:@"Before Market Open"]) {
                eventTimeString = [NSString stringWithFormat:@"Before Open"];
            }
            if ([eventTimeString isEqualToString:@"During Market Trading"]) {
                eventTimeString = [NSString stringWithFormat:@"While Open"];
            }
            eventDateString = [NSString stringWithFormat:@"%@ %@ ",eventDateString,eventTimeString];
        }
        [[cell eventDate] setText:eventDateString];
        
        // TO DO: FIX LATER. If we show the certainty of the event only if it's not Confirmed, else make it blank, the reminder functionality doesn't work, thus commenting this for now.
        /* if (![eventAtIndex.certainty isEqualToString:@"Confirmed"]) {
            [[cell eventCertainty] setText:eventAtIndex.certainty];
        } else {
            [[cell eventCertainty] setText:[NSString stringWithFormat:@" "]];
        } */
        
        // Show event certainty
        [[cell eventCertainty] setText:eventAtIndex.certainty];
        // Set it's color based on certainty. Confirmed is -> Dark Gray, Others -> Dark Gray
        if ([cell.eventCertainty.text isEqualToString:@"Confirmed"]) {
            
            // TO DO: Delete this purple,blue, bright blue later
            //cell.eventCertainty.textColor = [UIColor colorWithRed:81.0f/255.0f green:54.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
            //cell.eventCertainty.textColor = [UIColor colorWithRed:0.0f/255.0f green:168.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
            //cell.eventCertainty.textColor = [UIColor colorWithRed:35.0f/255.0f green:127.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            cell.eventCertainty.textColor = [UIColor darkGrayColor];
        } else {
            // TO DO: Delete Later Red Color
            //cell.eventCertainty.textColor = [UIColor colorWithRed:255.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
            cell.eventCertainty.textColor = [UIColor darkGrayColor];
        }
        
        NSLog(@"After cell is set to display, company ticker is:%@ and company confirmed is:%@",eventAtIndex.listedCompany.ticker,eventAtIndex.certainty);
    }
    // TO DO: Delete after testing
    NSDateFormatter *testDateFormatter = [[NSDateFormatter alloc] init];
    [testDateFormatter setDateFormat:@"EEE MMMM dd"];
    NSString *priorDateString = [testDateFormatter stringFromDate:eventAtIndex.priorEndDate];
    NSLog(@"ADDITIONAL INFORMATION FOR TICKER:%@ is EstimatedEPS:%f Prior End Date:%@ Actual Prior EPS:%f",eventAtIndex.listedCompany.ticker,[eventAtIndex.estimatedEps floatValue],priorDateString,[eventAtIndex.actualEpsPrior floatValue]);
    
    return cell;
}

// When a row is selected on the events list table, check to see if that row has an event cell with remote fetch status
// set to true, meaning the event needs to be fetched from the remote Data Source. Additionally clear out the search context.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"Row Clicked");
    
    // Check to see if the row selected has an event cell with remote fetch status set to true
    FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
    if (cell.eventRemoteFetch) {
        
        // Check for connectivity. If yes, process the fetch
        if ([self checkForInternetConnectivity]) {
            
            // Set the remote fetch spinner to animating to show a fetch is in progress
            NSLog(@"Starting to animate spinner");
            [self.remoteFetchSpinner startAnimating];
            
            // Fetch the event for the related parent company in the background
            NSLog(@"Fetching Event Data for ticker in the background:%@",(cell.companyTicker).text);
            [self performSelectorInBackground:@selector(getAllEventsFromApiInBackgroundWithTicker:) withObject:(cell.companyTicker).text];
        }
        // If not, show error message
        else {
            
            [self sendUserMessageCreatedNotificationWithMessage:@"Hmm! Unable to get data. Check Connection and retry."];
        }
    }
    // If not then, fetch event details before segueing to the details view
    else {
        
        // Check for connectivity. If yes, process the fetch
        if ([self checkForInternetConnectivity]) {
            
            // Set the busy spinner to show that details are being fetched. Do this in a background thread as the main
            // thread is being taken up by the table view. It's a best practice.
            [self.remoteFetchSpinner performSelectorInBackground:@selector(startAnimating) withObject:self];
            
            // Read whatever history details are available from event and fetch additional ones from the API to get ready to segue to
            // the event detail view
            FADataController *historyDataController1 = [[FADataController alloc] init];
            
            // Get the currently selected cell and details
            NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
            FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
            NSString *eventTicker = selectedCell.companyTicker.text;
            NSString *eventType = [NSString stringWithFormat:@"%@ Earnings",selectedCell.eventDescription.text];
            
            // Add whatever history related data you have in the event data store to the event history data store, if it's not already been added before
            // Get today's date
            NSDate *todaysDate = [NSDate date];
            Event *selectedEvent = [historyDataController1 getEventForParentEventTicker:eventTicker andEventType:eventType];
            NSLog(@"Before Segueing for ticker:%@ the event current quarter end date is:%@ and prior quarter end date is:%@",eventTicker, selectedEvent.relatedDate,selectedEvent.priorEndDate);
            // Compute the likely date for the previous event
            NSLog(@"ABOUT TO COMPUTE PREVIOUS EVENT for ticker:%@",eventTicker);
            NSDate *previousEvent1LikelyDate = [self computePreviousEventDateWithCurrentEventType:eventType currentEventDate:selectedEvent.date currentEventRelatedDate:selectedEvent.relatedDate previousEventRelatedDate:selectedEvent.priorEndDate];
            NSLog(@"COMPUTED PREVIOUS EVENT for ticker:%@ is: %@",eventTicker,previousEvent1LikelyDate);
            NSLog(@"Before deciding to create or update event history for ticker:%@, history exists is:%d and prior end date is:%@ and current end date is:%@",eventTicker, [historyDataController1 doesEventHistoryExistForParentEventTicker:eventTicker parentEventType:eventType], selectedEvent.priorEndDate,selectedEvent.relatedDate);
            if (![historyDataController1 doesEventHistoryExistForParentEventTicker:eventTicker parentEventType:eventType])
            {
                // Insert history.
                // NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
                NSNumber *emptyPlaceholder = [[NSNumber alloc] initWithFloat:999999.9];
                [historyDataController1 insertHistoryWithPreviousEvent1Date:previousEvent1LikelyDate previousEvent1Status:@"Estimated" previousEvent1RelatedDate:selectedEvent.priorEndDate currentDate:todaysDate previousEvent1Price:emptyPlaceholder previousEvent1RelatedPrice:emptyPlaceholder currentPrice:emptyPlaceholder parentEventTicker:eventTicker parentEventType:eventType];
                NSLog(@"Inserted event history for ticker:%@ with previous end date:%@", eventTicker,selectedEvent.priorEndDate);
            }
            // Else update the non price related data, except current date, on the event history from the event, in case the event info has been refreshed
            else
            {
                [historyDataController1 updateEventHistoryWithPreviousEvent1Date:previousEvent1LikelyDate previousEvent1Status:@"Estimated" previousEvent1RelatedDate:selectedEvent.priorEndDate parentEventTicker:eventTicker parentEventType:eventType];
                NSLog(@"Updated event history for ticker:%@ with previous end date:%@", eventTicker,selectedEvent.priorEndDate);
            }
            
            // Call price API, in the main thread, to get price history, if the current date is not today or if any of the price values are not available.
            EventHistory *selectedEventHistory = [historyDataController1 getEventHistoryForParentEventTicker:eventTicker parentEventType:eventType];
            // Set a value indicating that a value is not available. Currently a Not Available value
            // is represented by 999999.9
            double notAvailable = 999999.9f;
            double prev1PriceDbl = [[selectedEventHistory previous1Price] doubleValue];
            double prev1RelatedPriceDbl = [[selectedEventHistory previous1RelatedPrice] doubleValue];
            double currentPriceDbl = [[selectedEventHistory currentPrice] doubleValue];
            NSComparisonResult currDateComparison = [[NSCalendar currentCalendar] compareDate:selectedEventHistory.currentDate toDate:todaysDate toUnitGranularity:NSCalendarUnitDay];
            // Note: NSOrderedSame has the value 0
            if ((prev1PriceDbl == notAvailable)||(prev1RelatedPriceDbl == notAvailable)||(currentPriceDbl == notAvailable)||(currDateComparison != NSOrderedSame))
            {
                NSLog(@"Getting prices from API for ticker: %@ with prev event price:%f and prev related event price:%f current price:%f and date comparison:%ld and stored current date:%@ and actual todays date:%@", eventTicker, prev1PriceDbl,prev1RelatedPriceDbl,currentPriceDbl,(long)currDateComparison,selectedEventHistory.currentDate,todaysDate);
                // It's important to update the date here cause the get prices call gets the current date for the API call from the event history.
                [historyDataController1 updateEventHistoryWithCurrentDate:todaysDate parentEventTicker:eventTicker parentEventType:eventType];
                //[self performSelectorInBackground:@selector(getPricesInBackgroundWithEventInfo:) withObject:@[eventTicker,eventType]];
                [self getPricesWithCompanyTicker:eventTicker eventType:eventType dataController:historyDataController1];
            }
        }
        // If not, show error message
        else {
            
            //  Currently for simplicity, we are handling this in the event details controller as that's where the user is transitioning to on click.
        }
        
        // Stop the remote fetch spinner animation to indicate fetch is complete. Do this in a background thread as the main
        // thread is being taken up by the table view. It's a best practice.
        [self.remoteFetchSpinner performSelectorInBackground:@selector(stopAnimating) withObject:self];
    }
    
    // If search bar is in edit mode but the user has not entered any character to search (i.e. a search filter has not been applied), clear out of the search context when a user clicks on a row
    if ([self.eventsSearchBar isFirstResponder] && !(self.filterSpecified)) {
        
        NSLog(@"SEARCH BAR CONTEXT SHOULD BE CLEARED");
        [self.eventsSearchBar resignFirstResponder];
    }
}

#pragma mark - Data Source API

// Get all companies from API. Typically called in a background thread
- (void)getAllCompaniesFromApiInBackground
{
    
    // TO DO: Delete once you have background tasking figured out
    // Create a new FADataController so that this thread has its own MOC
   /* FADataController *companiesDataController = [[FADataController alloc] init];
    
    [companiesDataController getAllCompaniesFromApi]; */
    
    // Get a data controller for data store interactions
    FADataController *companiesDataController = [[FADataController alloc] init];
    
    // Creating a task that continues to process in the background.
    __block UIBackgroundTaskIdentifier bgFetchTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"bgCompaniesFetch" expirationHandler:^{
        
        // Clean up any unfinished task business before it's about to be terminated
        // In our case, check if all pages of companies data has been synced. If not, mark status to failed
        // so that another thread can pick up the completion on restart. Currently this is hardcoded to 26 as 26 pages worth of companies (7375 companies at 300 per page) were available as of July 15, 2105. When you change this, change the hard coded value in getAllCompaniesFromApi in FADataController. Also change in Search Bar Began Editing in the Events View Controller.
        // TO DO: Delete Later as now getting the value of the total no of companies to sync from db.
        // if ([[companiesDataController getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&[[companiesDataController getCompanySyncedUptoPage] integerValue] < 26)
        if ([[companiesDataController getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&[[companiesDataController getCompanySyncedUptoPage] integerValue] < [[companiesDataController getTotalNoOfCompanyPagesToSync] integerValue])
        {
            [companiesDataController upsertUserWithCompanySyncStatus:@"FullSyncAttemptedButFailed" syncedPageNo:[companiesDataController getCompanySyncedUptoPage]];
        }
        NSLog(@"**************Company Sync Status is:%@ and synced page is:%ld before terminating the background thread to update companies",[companiesDataController getCompanySyncStatus],[[companiesDataController getCompanySyncedUptoPage] longValue]);
        // TO DO: Delete timing information.
        NSTimeInterval timeRemaining = [UIApplication sharedApplication].backgroundTimeRemaining;
        NSLog(@"****Background time remaining: %f seconds (%d mins) and ending task", timeRemaining, (int)(timeRemaining / 60));
        
        // Stopped or ending the task outright.
        [[UIApplication sharedApplication] endBackgroundTask:bgFetchTask];
        bgFetchTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // TO DO: Delete. Just outputting the time
        NSTimeInterval timeRemaining = [UIApplication sharedApplication].backgroundTimeRemaining;
        NSLog(@"****Background time remaining: %f seconds (%d mins) and about to begin company sync from bg thread", timeRemaining, (int)(timeRemaining / 60));
        
        [companiesDataController getAllCompaniesFromApi];
        
        [[UIApplication sharedApplication] endBackgroundTask:bgFetchTask];
        bgFetchTask = UIBackgroundTaskInvalid;
    });
}

// Get events for company given a ticker. Typically called in a background thread
- (void)getAllEventsFromApiInBackgroundWithTicker:(NSString *)ticker
{
    // Create a new FADataController so that this thread has its own MOC
    FADataController *eventsDataController = [[FADataController alloc] init];
    
    [eventsDataController getAllEventsFromApiWithTicker:ticker];
    
    
    NSLog(@"Finished fetching Event Data for ticker in the background:%@",ticker);
    NSLog(@"Stopping to animate spinner");
    [self.remoteFetchSpinner stopAnimating];
    
    // Force a search to capture the refreshed event, so that the table can be refreshed
    // to show the refreshed event
    [self searchBarSearchButtonClicked:self.eventsSearchBar];
    NSLog(@"Finished researching with updated event");
}

// Get stock prices for company given a ticker and event type (event info). Executes in the main thread.
- (void)getPricesWithCompanyTicker:(NSString *)ticker eventType:(NSString *)type dataController:(FADataController *)specificDataController;
{
    EventHistory *eventForPricesFetch = [specificDataController getEventHistoryForParentEventTicker:ticker parentEventType:type];
    
    [specificDataController getStockPricesFromApiForTicker:ticker companyEventType:type fromDateInclusive:eventForPricesFetch.previous1RelatedDate toDateInclusive:eventForPricesFetch.currentDate];
    
    // Use this if you move this operation to a background thread
    //[[NSNotificationCenter defaultCenter]postNotificationName:@"EventHistoryUpdated" object:nil];
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
    
    //[searchBar resignFirstResponder];
    // TO DO: In case you want to clear the search context
    [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
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
        
        NSLog(@"Entered the search text not valid loop in text did change");
        
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

// Before a user enters a search term check to see if full company data sync has been completed.
// If not show the user a message warming them.
- (BOOL)searchBarShouldBeginEditing:(UISearchBar*)searchBar {
    
    NSLog(@"SEARCH BAR EDITING BEGIN FIRED:");
    
    // Check for connectivity. If yes, give user information message
    if ([self checkForInternetConnectivity]) {
        
        // TO DO: OPTIONAL UNCOMMENT FOR PRE SEEDING DB: Commenting out since we don't want to kick off a company/event sync due to preseeded data.
        /*
        // If the companies data is still being synced, give the user a warning message
        if (![[self.primaryDataController getCompanySyncStatus] isEqualToString:@"FullSyncDone"]) {
            // Show user a message that companies data is being synced
            // Give the user an informational message
            int pagesDone = [[self.primaryDataController getCompanySyncedUptoPage] intValue];
            // TO DO: Currently this is hardcoded to 26 as 26 pages worth of companies (7517 companies at 300 per page) were available as of Sep 29, 2105. When you change this, change the hard coded value in getAllCompaniesFromApi(2 places) in FADataController. Also change in Search Bar Began Editing in the Events View Controller. Also change in getAllCompaniesFromApiInBackground in FA Events View Controller. Also Change in refreshCompanyInfoIfNeededFromApiInBackground in AppDelegate.
            // TO DO: Delete this later
            // int totalPages = 26;
            // TO DO: Account for the case where total no of company pages to sync might be -1.
            int totalPages = (int)[[self.primaryDataController getTotalNoOfCompanyPagesToSync] integerValue];
            float percentageDone = (100 * pagesDone)/totalPages;
            NSString *userMessage = [NSString stringWithFormat:@"Fetching Tickers(%.f%% Done)! Can't find one,retry in a bit.", percentageDone];
            [self sendUserMessageCreatedNotificationWithMessage:userMessage];
            // TO DO: Delete Later after testing.
            //[self sendUserMessageCreatedNotificationWithMessage:@"Fetching Tickers! Can't find one, retry in a bit."];
        } */
    }
    // If not, show error message,
    else {
        
        [self sendUserMessageCreatedNotificationWithMessage:@"No Connection. Limited functionality available."];
    }
    
    return YES;
}

// Handle various user touch scenarios:
// 1) When user touches outside the search bar, if search bar is in edit mode but the user has not entered any character to search (i.e. a search filter has not been applied), clear out of the search context.
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    NSLog(@"Tap recognized by Touches Began with first responder:%d", [self isFirstResponder]);
    
    //When user touches outside the search bar, if search bar is in edit mode but the user has not entered any character to search (i.e. a search filter has not been applied), clear out of the search context.
    if ([self.eventsSearchBar isFirstResponder] && !(self.filterSpecified)) {
        [self.eventsSearchBar resignFirstResponder];
    }
    
    // When user touches outside the search bar, when a fetch event is displayed or in progress, clear out of the search context.
    if ([self.eventsSearchBar isFirstResponder] && (self.filterSpecified)) {
        NSLog(@"Entered touch outside to clear search bar context");
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
    }
}

#pragma mark - Notifications

// Send a notification to the events list controller with a message that should be shown to the user
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"UserMessageCreated" object:msgContents];
    NSLog(@"NOTIFICATION FIRED: With User Message: %@",msgContents);
}

#pragma mark - Change Listener Responses

// Refetch the events and refresh the events table when the events store for the table has changed
- (void)eventStoreChanged:(NSNotification *)notification {
    
    // Create a new DataController so that this thread has its own MOC
    // TO DO: Understand at what point does a new thread get spawned off. Seems to me the new thread is being created for
    // reloading the table. SHouldn't I be creating the new MOC in that thread as opposed to here ? Maybe it doesn't matter
    // as long as I am not sharing MOCs across threads ? The general rule with Core Data is one Managed Object Context per thread, and one thread per MOC
    FADataController *secondaryDataController = [[FADataController alloc] init];
    self.eventResultsController = [secondaryDataController getAllEvents];
    [self.eventsListTable reloadData];
    NSLog(@"*******************************************Event Store Changed listener fired to refresh table");
}

// Show the error message for a temporary period and then fade it if a user message has been generated
// TO DO: Currently set to 20 seconds. Change as you see fit.
- (void)userMessageGenerated:(NSNotification *)notification {
    
    // Make sure the message bar is empty and visible to the user
    self.messageBar.text = @"";
    self.messageBar.alpha = 1.0;
    
     NSLog(@"NOTIFICATION ABOUT TO BE SHOWN: With User Message: %@",[notification object]);
    
    // Show the message that's generated for a period of 20 seconds
    [UIView animateWithDuration:20 animations:^{
        self.messageBar.text = [notification object];
        self.messageBar.alpha = 0;
    }];
}

// Process the notification to update screen header which is the navigation bar title. Currently just set it to today's date.
- (void)updateScreenHeader:(NSNotification *)notification {
    
    NSDateFormatter *todayDateFormatter = [[NSDateFormatter alloc] init];
    [todayDateFormatter setDateFormat:@"EEE MMMM dd"];
    [self.navigationController.navigationBar.topItem setTitle:[todayDateFormatter stringFromDate:[NSDate date]]];
}

#pragma mark - Connectivity Methods

// Check if there is internet connectivity
- (BOOL) checkForInternetConnectivity {
    
    // Get internet access status
    Reachability *internetReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus internetStatus = [internetReachability currentReachabilityStatus];
    
    // If there is no internet access
    if (internetStatus == NotReachable) {
        return NO;
    }
    // If there is internet access
    else {
        return YES;
    }
}

#pragma mark - Helper Methods

// Return a color scheme from darker to lighter based on rwo number with darker on top. Currently returning a dark gray scheme.
- (UIColor *)getColorForIndexPath:(NSIndexPath *)indexPath
{
    
    // Set returned color to the darkest gray to start with
    UIColor *colorToReturn = [UIColor colorWithRed:45.0f/255.0f green:45.0f/255.0f blue:45.0f/255.0f alpha:1.0f];
    
    // Get row number, it's 0 based
    long rowNumber = indexPath.row;
    
    // For the first row go with the darkest color and then make it gradually lighter upto 7rows and then go with the lightest for all the rest
    if (rowNumber == 0) {
        
        colorToReturn = [UIColor colorWithRed:45.0f/255.0f green:45.0f/255.0f blue:45.0f/255.0f alpha:1.0f];
        
    } else if (rowNumber == 1) {
        
        colorToReturn = [UIColor colorWithRed:61.0f/255.0f green:61.0f/255.0f blue:61.0f/255.0f alpha:1.0f];
        
    } else if (rowNumber == 2) {
        
        colorToReturn = [UIColor colorWithRed:77.0f/255.0f green:76.0f/255.0f blue:77.0f/255.0f alpha:1.0f];
        
    } else if (rowNumber == 3) {
        
        colorToReturn = [UIColor colorWithRed:108.0f/255.0f green:107.0f/255.0f blue:108.0f/255.0f alpha:1.0f];
        
    } else if (rowNumber == 4) {
        
        colorToReturn = [UIColor colorWithRed:137.0f/255.0f green:135.0f/255.0f blue:136.0f/255.0f alpha:1.0f];
        
    } else if (rowNumber == 5) {
        
        colorToReturn = [UIColor colorWithRed:157.0f/255.0f green:154.0f/255.0f blue:156.0f/255.0f alpha:1.0f];
        
    } else if (rowNumber == 6) {
        
        colorToReturn = [UIColor colorWithRed:189.0f/255.0f green:185.0f/255.0f blue:187.0f/255.0f alpha:1.0f];
        
    } else {
        
        colorToReturn = [UIColor colorWithRed:189.0f/255.0f green:185.0f/255.0f blue:187.0f/255.0f alpha:1.0f];
        
    }
    
    return colorToReturn;
}


#pragma mark - Navigation

// Check to see if the table cell press is for a "Get Earnings" cell. If yes, then don't perform the table segue
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    
    BOOL returnVal = YES;
    
    // Check the segue is "ShowEventDetails"
    if ([identifier isEqualToString:@"ShowEventDetails" ]) {
        
        // If the cell is the "Get Earnings" cell identified by if Remote Fetch indicator is true, set return value to false indicating no swguw should be performed
        NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
        FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
        if (selectedCell.eventRemoteFetch) {
            returnVal = NO;
        }
    }

    return returnVal;
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([[segue identifier] isEqualToString:@"ShowEventDetails"]) {
        
        FAEventDetailsViewController *eventDetailsViewController = [segue destinationViewController];
        
        // Set the title on the destination view controller to be the same as that of the current view controller which is today's date
        [eventDetailsViewController.navigationItem setTitle:self.navigationController.navigationBar.topItem.title];
        
        // Get the currently selected cell and set details for the destination.
        // IMPORTANT: If the format here or in the events UI is changed, reminder creation in the details screen will break.
        NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
        FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
        NSString *eventTicker = selectedCell.companyTicker.text;
        NSString *eventType = [NSString stringWithFormat:@"%@ Earnings",selectedCell.eventDescription.text];
        // Set Event Parent Ticker for processing in destination
        [eventDetailsViewController setParentTicker:eventTicker];
        // Set Event Type for processing in destination
        [eventDetailsViewController setEventType: eventType];
        // Set Event Schedule as text for processing in destination
        [eventDetailsViewController setEventDateText:selectedCell.eventDate.text];
        // Set Event certainty status for processing in destination
        [eventDetailsViewController setEventCertainty:selectedCell.eventCertainty.text];
        
        // Set Event Title for display in destination
        [eventDetailsViewController setEventTitleStr:[NSString stringWithFormat:@"%@ %@", eventTicker, [eventType uppercaseString]]];
        // Set Event Schedule for display in destination
        [eventDetailsViewController setEventScheduleStr:selectedCell.eventDate.text];
    }
}

#pragma mark - Utility Methods

// Compute the likely date for the previous event based on current event type (currently only Quarterly), previous event related date (e.g. quarter end related to the quarterly earnings), current event date and current event related date.
- (NSDate *)computePreviousEventDateWithCurrentEventType:(NSString *)currentType currentEventDate:(NSDate *)currentDate currentEventRelatedDate:(NSDate *)currentRelatedDate previousEventRelatedDate:(NSDate *)previousRelatedDate
{
    
    // TO DO: Use Earnings type later
    
    // TO DO: Delete later. For testing
    NSLog(@"For computing prior earnings date the current earnings date is:%@ and current end of quarter is:%@",currentDate,currentRelatedDate);
    
    // Calculate the number of days between current event date (quarterly earnings) and current event related date (end of quarter being reported)
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    // NSUInteger unitFlags = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSUInteger unitFlags =  NSCalendarUnitDay;
    NSDateComponents *diffDateComponents = [aGregorianCalendar components:unitFlags fromDate:currentRelatedDate toDate:currentDate options:0];
    NSInteger difference = [diffDateComponents day];
    
    NSLog(@"The difference from the end of quarter is:%ld",(long)difference);
    
    // Add the no of days to the previous related event date (previously reported quarter end)
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = difference;
    NSDate *previousEventDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:previousRelatedDate options:0];
    
    // Make sure the date doesn't fall on a Friday, Saturday, Sunday. In these cases move it to the previous Thursday for Friday and following Monday for Saturday and Sunday.
    // Convert from string to Date
    NSDateFormatter *previousDayFormatter = [[NSDateFormatter alloc] init];
    [previousDayFormatter setDateFormat:@"EEE"];
    NSString *previousDayString = [previousDayFormatter stringFromDate:previousEventDate];
    NSLog(@"PREVIOUS EARNINGS DATE is computed to be: %@",previousEventDate);
    if ([previousDayString isEqualToString:@"Fri"]) {
        // TO DO: Delete right at the end before shipping. Will identify possible incorrect calculations.
        NSLog(@"CHECK DATA: Computed a friday prior event date that was shifted to a day earlier");
        differenceDayComponents.day = -1;
        previousEventDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:previousEventDate options:0];
    }
    if ([previousDayString isEqualToString:@"Sat"]) {
        // TO DO: Delete right at the end before shipping. Will identify possible incorrect calculations.
        NSLog(@"CHECK DATA: Computed a saturday prior event date that was shifted to 2 days later");
        differenceDayComponents.day = 2;
        previousEventDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:previousEventDate options:0];
    }
    if ([previousDayString isEqualToString:@"Sun"]) {
        // TO DO: Delete right at the end before shipping. Will identify possible incorrect calculations.
        NSLog(@"CHECK DATA: Computed a sunday prior event date that was shifted to a day later");
        differenceDayComponents.day = 1;
        previousEventDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:previousEventDate options:0];
    }
    
    return previousEventDate;
}

/*
#pragma mark - Code to use later
 
// Set bright colors randomly if needed in the future
 
 // Set the company ticker and name labels to one of 8 colors randomly
 int randomColor = arc4random_uniform(8);
 
 // Purple
 if (randomColor == 0) {
 
 cell.companyTicker.backgroundColor = [UIColor colorWithRed:175.0f/255.0f green:94.0f/255.0f blue:156.0f/255.0f alpha:1.0f];
 }
 
 // Orangish Pink
 if (randomColor == 1) {
 
 cell.companyTicker.backgroundColor = [UIColor colorWithRed:233.0f/255.0f green:141.0f/255.0f blue:112.0f/255.0f alpha:1.0f];
 }
 
 // Bright Blue
 if (randomColor == 2) {
 
 cell.companyTicker.backgroundColor = [UIColor colorWithRed:35.0f/255.0f green:127.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
 }
 
 // Bright Pink
 if (randomColor == 3) {
 
 cell.companyTicker.backgroundColor = [UIColor colorWithRed:224.0f/255.0f green:46.0f/255.0f blue:134.0f/255.0f alpha:1.0f];
 }
 
 // Light Purple
 if (randomColor == 4) {
 
 cell.companyTicker.backgroundColor = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
 }
 
 // Carrotish Orange
 if (randomColor == 5) {
 
 cell.companyTicker.backgroundColor = [UIColor colorWithRed:222.0f/255.0f green:105.0f/255.0f blue:38.0f/255.0f alpha:1.0f];
 }
 
 // Yellow
 if (randomColor == 6) {
 
 cell.companyTicker.backgroundColor = [UIColor colorWithRed:236.0f/255.0f green:186.0f/255.0f blue:38.0f/255.0f alpha:1.0f];
 }
 
 // Another Blue
 if (randomColor == 7) {
 
 cell.companyTicker.backgroundColor = [UIColor colorWithRed:40.0f/255.0f green:114.0f/255.0f blue:81.0f/255.0f alpha:1.0f];
 }
 
 // Reuse when displaying today's date. Also change the hidden state of the section header bar.
 // Make sure the section header bar is visible
 self.headerBar.alpha = 1.0;
 // Fade out the header bar message
 [UIView animateWithDuration:20 animations:^{
 self.headerBar.alpha = 0;
 }];
 
 // Bring in the App Icon
 [UIView animateWithDuration:20 delay:14 options:UIViewAnimationOptionBeginFromCurrentState animations:^{self.appIconBar.alpha = 1.0;} completion:^(BOOL finished){}]; 

 // Make Sure the table row, if it should be, is editable
 // TO DO: Check to see that the row has event information. Only then, make it editable
 // TO DO: Move to unused once reminder creation is ported to details screen.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 
 return YES;
 }

// TO DO: Understand this method better. Basically need this to be able to use the custom UITableViewRowAction
// TO DO: Move to unused once reminder creation is ported to details screen.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 
 }

// TO DO: Move to unused once reminder creation is ported to details screen.
// Add the following actions on swiping each event row: 1) "Set Reminder" if reminder hasn't already been created, else
// display a message that reminder has aleady been set.
- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
 
 // Get the cell for the row on which the action is being exercised
 FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
 
 // NOTE: Formatting Event Type to be "Quarterly Earnings" based on "Quarterly" that comes from the UI.
 // If the formatting changes, it needs to be changed here to accomodate as well.
 NSString *cellEventType = [NSString stringWithFormat:@"%@ Earnings", cell.eventDescription.text];
 
 UITableViewRowAction *setReminderAction;
 
 // Check to see if a reminder action has already been created for the event represented by the cell.
 // If yes, show a appropriately formatted status action.
 if ([self.primaryDataController doesReminderActionExistForEventWithTicker:cell.companyTicker.text eventType:cellEventType])
 {
 // Create the "Reimder Already Set" Action and handle it being exercised.
 setReminderAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Reminder Set" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
 
 // Slide the row back over the action.
 // TO DO: See if you can animate the slide back.
 [self.eventsListTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
 
 // Let the user know a reminder is already set for this ticker.
 [self sendUserMessageCreatedNotificationWithMessage:@"Already set to be reminded of this event a day before."];
 }];
 
 // Format the Action UI to be the correct color and everything
 setReminderAction.backgroundColor = [UIColor grayColor];
 }
 // If not, create the set reminder action
 else
 {
 // Create the "Set Reminder" Action and handle it being exercised.
 setReminderAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Set Reminder" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
 
 // Get the cell for the row on which the action is being exercised
 FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
 NSLog(@"Clicked the Set Reminder Action with ticker %@",cell.companyTicker.text);
 
 // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
 // TO DO: Decide if you want to close the slid out action, before the user has provided
 // access. Currently it's weird where the action closes and then the access popup is shown.
 [self requestAccessToUserEventStoreAndProcessReminderFromCell:cell];
 
 // Slide the row back over the action.
 // TO DO: See if you can animate the slide back.
 [self.eventsListTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
 }];
 
 // Format the Action UI to be the correct color and everything
 setReminderAction.backgroundColor = [UIColor colorWithRed:35.0f/255.0f green:127.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
 }
 
 return @[setReminderAction];
 }
 
 // TO DO: Move to unused once reminder creation is ported to details screen.
  #pragma mark - Calendar and Event Related
 
 // Set the getter for the user event store property so that only one event store object gets created
 - (EKEventStore *)userEventStore {
 if (!_userEventStore) {
 _userEventStore = [[EKEventStore alloc] init];
 }
 return _userEventStore;
 }
 
 // Present the user with an access request to their reminders if it's not already been done. Once that is done
 // or access is already provided, create the reminder.
 // TO DO: Change the name FinApp to whatever the real name will be.
 - (void)requestAccessToUserEventStoreAndProcessReminderFromCell:(FAEventsTableViewCell *)eventCell {
 
 // Get the current access status to the user's event store for event type reminder.
 EKAuthorizationStatus accessStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder];
 
 // Depending on the current access status, choose what to do. Idea is to request access from a user
 // only if he hasn't granted it before.
 switch (accessStatus) {
 
 // If the user hasn't provided access, show an appropriate error message.
 case EKAuthorizationStatusDenied:
 case EKAuthorizationStatusRestricted: {
 NSLog(@"Authorization Status for Reminders is Denied or Restricted");
 [self sendUserMessageCreatedNotificationWithMessage:@"Enable Reminders under Settings>Knotifi and try again!"];
 break;
 }
 
 // If the user has already provided access, create the reminder.
 case EKAuthorizationStatusAuthorized: {
 NSLog(@"Authorization Status for Reminders is Provided. About to create the reminder");
 [self processReminderForEventInCell:eventCell withDataController:self.primaryDataController];
 break;
 }
 
 // If the app hasn't requested access or the user hasn't decided yet, present the user with the
 // authorization dialog. If the user approves create the reminder. If user rejects, show error message.
 case EKAuthorizationStatusNotDetermined: {
 
 // create a weak reference to the controller, since you want to create the reminder, in
 // a non main thread where the authorization dialog is presented.
 __weak FAEventsViewController *weakPtrToSelf = self;
 [self.userEventStore requestAccessToEntityType:EKEntityTypeReminder
 completion:^(BOOL grantedByUser, NSError *error) {
 dispatch_async(dispatch_get_main_queue(), ^{
 if (grantedByUser) {
 NSLog(@"Authorization Status for Reminders was enabled by user. About to create the reminder");
 // Create a new Data Controller so that this thread has it's own MOC
 FADataController *afterAccessDataController = [[FADataController alloc] init];
 [weakPtrToSelf processReminderForEventInCell:eventCell withDataController:afterAccessDataController];
 } else {
 NSLog(@"Authorization Status for Reminderswas rejected by user.");
 [weakPtrToSelf sendUserMessageCreatedNotificationWithMessage:@"Enable Reminders under Settings>Knotifi and try again!"];
 }
 });
 }];
 break;
 }
 }
 }
 
 // Process the "Remind Me" action for the event represented by the cell on which the action was taken. If the event is confirmed, create the reminder immediately and make an appropriate entry in the Action data store. If it's estimated, then don't create the reminder, only make an appropriate entry in the action data store for later processing.
 - (void)processReminderForEventInCell:(FAEventsTableViewCell *)eventCell withDataController:(FADataController *)appropriateDataController {
 
 // NOTE: Formatting Event Type to be "Quarterly Earnings" based on "Quarterly" that comes from the UI.
 // If the formatting changes, it needs to be changed here to accomodate as well.
 NSString *cellEventType = [NSString stringWithFormat:@"%@ Earnings", eventCell.eventDescription.text];
 NSString *cellCompanyTicker = eventCell.companyTicker.text;
 NSString *cellEventDateText = eventCell.eventDate.text;
 NSString *cellEventCertainty = eventCell.eventCertainty.text;
 
 NSLog(@"Event Cell type is:%@ Ticker is:%@ DateText is:%@ and Certainty is:%@", cellEventType, cellCompanyTicker, cellEventDateText, cellEventCertainty);
 
 // Check to see if the event represented by the cell is estimated or confirmed ?
 // If confirmed create and save to action data store
 if ([eventCell.eventCertainty.text isEqualToString:@"Confirmed"]) {
 
 NSLog(@"About to create a reminder, since this event is confirmed");
 
 // Create the reminder and show user the appropriate message
 BOOL success = [self createReminderForEventOfType:cellEventType withTicker:cellCompanyTicker dateText:cellEventDateText andDataController:appropriateDataController];
 if (success) {
 NSLog(@"Successfully created the reminder");
 [self sendUserMessageCreatedNotificationWithMessage:@"All Set! You'll be reminded of this event a day before."];
 // Add action to the action data store with status created
 [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:cellCompanyTicker eventType:cellEventType];
 } else {
 NSLog(@"Actual Reminder Creation failed");
 [self sendUserMessageCreatedNotificationWithMessage:@"Oops! Unable to create a reminder for this event."];
 }
 }
 // If estimated add to action data store for later processing
 else if ([eventCell.eventCertainty.text isEqualToString:@"Estimated"]) {
 
 NSLog(@"About to queue a reminder for later creation, since this event is not confirmed");
 
 // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
 [appropriateDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:cellCompanyTicker eventType:cellEventType];
 [self sendUserMessageCreatedNotificationWithMessage:@"All Set! You'll be reminded of this event a day before."];
 }
 }
 
 // Actually create the reminder in the user's default calendar and return success or failure depending on the outcome.
 - (BOOL)createReminderForEventOfType:(NSString *)eventType withTicker:(NSString *)companyTicker dateText:(NSString *)eventDateText andDataController:(FADataController *)reminderDataController  {
 
 BOOL creationSuccess = NO;
 
 // Set title of the reminder to the reminder text.
 EKReminder *eventReminder = [EKReminder reminderWithEventStore:self.userEventStore];
 NSString *reminderText = [NSString stringWithFormat:@"%@ %@ tomorrow %@", companyTicker,eventType,eventDateText];
 eventReminder.title = reminderText;
 NSLog(@"The Reminder title is: %@",reminderText);
 
 // For now, create the reminder in the default calendar for new reminders as specified in settings
 eventReminder.calendar = [self.userEventStore defaultCalendarForNewReminders];
 
 // Get the date for the event represented by the cell
 NSDate *eventDate = [reminderDataController getDateForEventOfType:eventType eventTicker:companyTicker];
 
 // Subtract a day as we want to remind the user a day prior and then set the reminder time to noon of the previous day
 // and set reminder due date to that.
 NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
 NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
 differenceDayComponents.day = -1;
 NSDate *reminderDateTime = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:eventDate options:0];
 NSUInteger unitFlags = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
 NSDateComponents *reminderDateTimeComponents = [aGregorianCalendar components:unitFlags fromDate:reminderDateTime];
 reminderDateTimeComponents.hour = 12;
 reminderDateTimeComponents.minute = 0;
 reminderDateTimeComponents.second = 0;
 eventReminder.dueDateComponents = reminderDateTimeComponents;
 // Additionally add an alarm for the same time as due date/time so that the reminder actually pops up.
 NSDate *alarmDateTime = [aGregorianCalendar dateFromComponents:reminderDateTimeComponents];
 [eventReminder addAlarm:[EKAlarm alarmWithAbsoluteDate:alarmDateTime]];
 
 // TO DO: For debugging. Delete later.
 NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
 [eventDateFormatter setDateFormat:@"yyyy-MM-dd 'at' HH:mm:ss"];
 NSString *eventDueDateDebugString = [eventDateFormatter stringFromDate:alarmDateTime];
 NSLog(@"Event Reminder Date Time is:%@",eventDueDateDebugString);
 
 // Save the Reminder and return success or failure
 NSError *error = nil;
 creationSuccess = [self.userEventStore saveReminder:eventReminder commit:YES error:&error];
 
 return creationSuccess;
 } */

@end
