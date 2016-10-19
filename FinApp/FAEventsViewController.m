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
#import <FBSDKCoreKit/FBSDKCoreKit.h>
@import EventKit;

@interface FAEventsViewController ()

// Get all companies from API. Typically called in a background thread
- (void)getAllCompaniesFromApiInBackground;

// Validate search text entered
- (BOOL) searchTextValid:(NSString *)text;

// Get events for company given a ticker. Typically called in a background thread.
- (void)getAllEventsFromApiInBackgroundWithTicker:(NSString *)ticker;

// Get stock prices for company given a ticker and event type (event info). Executes in the main thread.
- (void)getPricesWithCompanyTicker:(NSString *)ticker eventType:(NSString *)type dataController:(FADataController *)specificDataController historyFetch:(BOOL)fetchHistory;

// Send a notification to the events list controller with a message that should be shown to the user
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents;

// Return the appropriate color for event distance based on how far it is from today.
- (UIColor *)getColorForDistanceFromEventDate:(NSDate *)eventDate;

// Compute the likely date for the previous event based on current event type (currently only Quarterly), previous event related date (e.g. quarter end related to the quarterly earnings), current event date and current event related date.
- (NSDate *)computePreviousEventDateWithCurrentEventType:(NSString *)currentType currentEventDate:(NSDate *)currentDate currentEventRelatedDate:(NSDate *)currentRelatedDate previousEventRelatedDate:(NSDate *)previousRelatedDate;

// Check if there is internet connectivity
- (BOOL) checkForInternetConnectivity;

// User's calendar events and reminders data store
@property (strong, nonatomic) EKEventStore *userEventStore;

@end

@implementation FAEventsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    // Visual styling setup
    
    // Make the message bar fully transparent so that it's invisible to the user
    self.messageBar.alpha = 0.0;
    
    // TO DO: Delete before shipping v2.5
    // Show today's date in the navigation bar header.
    /*NSDateFormatter *todayDateFormatter = [[NSDateFormatter alloc] init];
    [todayDateFormatter setDateFormat:@"EEE MMMM dd"];
    [self.navigationController.navigationBar.topItem setTitle:[[todayDateFormatter stringFromDate:[NSDate date]] uppercaseString]];*/
    
    // Set navigation bar header to title "Upcoming Events"
    [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING EVENTS"];
    
    // Change the color of the events search bar placeholder text and text entered to be a black text color.
    [self.eventsSearchBar setBackgroundImage:[UIImage new]];
    UITextField *eventSearchBarInputFld = [self.eventsSearchBar valueForKey:@"_searchField"];
    [eventSearchBarInputFld setValue:[UIColor blackColor] forKeyPath:@"_placeholderLabel.textColor"];
    eventSearchBarInputFld.textColor = [UIColor blackColor];
    
    // Set search bar background color to a very light, almost white gray so that it matches the background.
    eventSearchBarInputFld.backgroundColor = [UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f];
    
    // Change the color of the Magnifying glass icon in the search bar to be a black text color
    UIImageView *magGlassIcon = (UIImageView *)eventSearchBarInputFld.leftView;
    magGlassIcon.image = [magGlassIcon.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    magGlassIcon.tintColor = [UIColor blackColor];
    
    // Change the color of the Clear button in the search bar to be a black text color
    UIButton *searchClearBtn = [eventSearchBarInputFld valueForKey:@"_clearButton"];
    [searchClearBtn setImage:[searchClearBtn.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    searchClearBtn.tintColor = [UIColor blackColor];
    
    // Format the event type selector
    // Set text color of all unselected segments to a medium dark gray used in the event dates (R:113, G:113, B:113)
    [self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]} forState:UIControlStateNormal];
    // Set text color for the segment selected for the very first time which is Black for ALL events type. Also set focus bar to draw focus to the search bar to the same color.
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"All"] == NSOrderedSame) {
        [self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor blackColor]} forState:UIControlStateSelected];
        [self.focusBar setTextColor:[UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f]];
        [self.focusBar setBackgroundColor:[UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f]];
        [self.focusBar setTintColor:[UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f]];
    }
    
    // Get a primary data controller that you will use later
    self.primaryDataController = [[FADataController alloc] init];
    
    // Ensure that the remote fetch spinner is not animating thus hidden
    [self.remoteFetchSpinner stopAnimating];
    
    // TO DO: DEBUGGING: DELETE. Make one of the events confirmed to yesterday
    /*NSDate *today = [NSDate date];
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = -1;
    NSDate *yesterday = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:today options:0];
    [self.primaryDataController upsertEventWithDate:yesterday relatedDetails:@"Unknown" relatedDate:yesterday type:@"Quarterly Earnings" certainty:@"Estimated" listedCompany:@"BOX" estimatedEps:[NSNumber numberWithDouble:0.1] priorEndDate:[NSDate date] actualEpsPrior:[NSNumber numberWithDouble:0.2]];
    [self.primaryDataController upsertEventWithDate:yesterday relatedDetails:@"Unknown" relatedDate:yesterday type:@"Quarterly Earnings" certainty:@"Estimated" listedCompany:@"MSFT" estimatedEps:[NSNumber numberWithDouble:0.1] priorEndDate:[NSDate date] actualEpsPrior:[NSNumber numberWithDouble:0.2]];
    [self.primaryDataController upsertEventWithDate:yesterday relatedDetails:@"After Market Close" relatedDate:yesterday type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"AVGO"]; */
    
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
    
    // Register a listener for queued reminders to be created now that they have been confirmed
    // We do this here, instead of the event details since this is the most likely screen the user
    // will be on when the reminders are confirmed in a background thread
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(createQueuedReminder:)
                                                 name:@"CreateQueuedReminder" object:nil];
    
    // Register a listener for starting the busy spinner in case we need to call it remotely
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startBusySpinner:)
                                                 name:@"StartBusySpinner" object:nil];
    
    // Register a listener for stopping the busy spinner in case we need to call it remotely
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stopBusySpinner:)
                                                 name:@"StopBusySpinner" object:nil];
    
   // Seed the company data, the very first time, to get the user started.
    // TO DO: UNCOMMENT FOR PRE SEEDING DB: Commenting out since we don't want to kick off a company/event sync due to preseeded data.
    /*if ([[self.primaryDataController getCompanySyncStatus] isEqualToString:@"NoSyncPerformed"]) {
        
        [self.primaryDataController performBatchedCompanySeedSyncLocally];
    }*/
    
    // Check for connectivity. If yes, sync data from remote data source
    if ([self checkForInternetConnectivity]) {
        
        // TO DO: UNCOMMENT FOR PRE SEEDING DB: Commenting out since we don't want to kick off a company/event sync due to preseeded data.
        /*
        // Seed the events data, the very first time, to get the user started.
        if ([[self.primaryDataController getEventSyncStatus] isEqualToString:@"NoSyncPerformed"]) {
            [self.primaryDataController performEventSeedSyncRemotely];
        }
        
        // If the initial company data has been seeded, perform the full company data sync from the API
        // in the background
        if ([[self.primaryDataController getCompanySyncStatus] isEqualToString:@"SeedSyncDone"]) {
            
            [self performSelectorInBackground:@selector(getAllCompaniesFromApiInBackground) withObject:nil];
        }*/
    }
    // If not, show error message
    else {
        
        [self sendUserMessageCreatedNotificationWithMessage:@"No Connection! Limited functionality available."];
    }
    
    // Set the Filter Specified flag to false, indicating that no search filter has been specified
    self.filterSpecified = NO;
    
    // Set the filter type to None_Specified, meaning no filter has been specified.
    self.filterType = [NSString stringWithFormat:@"None_Specified"];
    
    // Set Current Stock Price & Change String to "NA" which is the default value.
    self.currPriceAndChange = [NSString stringWithFormat:@"NA"];
    
    // Query all future events depending on the type selected in the selector, including today, as that is the default view first shown
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"All"] == NSOrderedSame) {
        self.eventResultsController = [self.primaryDataController getAllFutureEvents];
    }
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
        self.eventResultsController = [self.primaryDataController getAllFutureEarningsEvents];
    }
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Economic"] == NSOrderedSame) {
        self.eventResultsController = [self.primaryDataController getAllFutureEconEvents];
    }
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Product"] == NSOrderedSame) {
        self.eventResultsController = [self.primaryDataController getAllFutureProductEvents];
    }
    
    // This will remove extra separators from the bottom of the tableview which doesn't have any cells
    self.eventsListTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    // TO DO: Delete before shipping v2.7
    [self.primaryDataController getAllPriceChangeEventsFromApi];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Events List Table

// Return number of sections in the events list table view
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // There's only one section for now
    return 1;
}

// TO DO: Delete before shipping v2.5
// Set the header for the table view to a special table cell that serves as header.
// TO DO: Currently only set a customized header for non ipad devices since there are weird
// alignment problems with ipad.
/*-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UITableViewCell *headerView = nil;
    
    // If device is ipad
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        
        // Don't set the header
    }
    // For all other devices
    else {
        
        // Set the header to the appropriate table cell
        //headerView = [tableView dequeueReusableCellWithIdentifier:@"EventsTableHeader"];
    }
    
    return headerView;
}*/

// TO DO: Delete before shipping v2.5
// Set the section header title for the table view that serves as the overall header.
// TO DO: Currently only do this for the ipad since we can't use a customized header for it. See above.
// When we are able to set a customized header for the ipad this won't be needed.
/*- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionTitle = nil;
    
    // If device is ipad
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        
       // Set title
       //sectionTitle = @"Upcoming Events";
    }
    
    return sectionTitle;
}*/

// Return number of rows in the events list table view
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // TO DO: Delete before shipping v2
    //NSLog(@"EVENT: List table rows refreshed");
    
    NSInteger numberOfRows = 0;
    
    // If a search filter has been applied return the number of events in the filtered list of events or companies,
    // depending on the type of filter
    if (self.filterSpecified) {
        
        // If the filter type is Match_Companies_Events, meaning a filter of matching companies with existing events
        // has been specified.
        if ([self.filterType isEqualToString:@"Match_Companies_Events"]) {
            id filteredEventSection = [[self.filteredResultsController sections] objectAtIndex:section];
            numberOfRows = [filteredEventSection numberOfObjects];
        }
        
        // If the filter type is Match_Companies_NoEvents, meaning a filter of matching companies with no existing events
        // has been specified.
        if ([self.filterType isEqualToString:@"Match_Companies_NoEvents"]) {
            id filteredCompaniesSection = [[self.filteredResultsController sections] objectAtIndex:section];
            numberOfRows = [filteredCompaniesSection numberOfObjects];
        }
    }
    
    // If not, show all events
    else {
        // Use all events results set
        id eventSection = [[self.eventResultsController sections] objectAtIndex:section];
        numberOfRows = [eventSection numberOfObjects];
    }

    return numberOfRows;
}

// Return a cell configured to display an event or a company with a fetch event
// TO DO LATER: IMPORTANT: Any change to the formatting here could affect reminder creation (processReminderForEventInCell:,editActionsForRowAtIndexPath) since the reminder values are taken from the cell. Additionally changes here need to be reconciled with changes in the getEvents for ticker's queued reminder creation. Also reconcile in didSelectRowAtIndexPath.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    // Get a custom cell to display
    FAEventsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventCell" forIndexPath:indexPath];
    
    // Reset color for Event Date to dark text, in case it's been set to blue for a "Get Events" display.
    cell.eventDescription.textColor = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    
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
    
    // Depending the type of search filter that has been applied, Show the matching companies with events or companies
    // with the fetch events message.
    if ([self.filterType isEqualToString:@"Match_Companies_NoEvents"]) {
        
        // Show the company ticker associated with the event
        [[cell  companyTicker] setText:companyAtIndex.ticker];
        
        // Set the company name associated with the event
        [[cell  companyName] setText:companyAtIndex.name];
        // Show the company Name as this information is needed to be displayed to the user when searching
        [[cell companyName] setHidden:NO];
        // Hide the image representing the event as this information is not needed when the user searches
        [[cell eventImage] setHidden:YES];
        
        // Show the "Get Events" text in the event display area.
        [[cell eventDescription] setText:@"GET EVENTS"];
        // Set color to a link blue to provide a visual cue to click
        cell.eventDescription.textColor = [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
        
        // Set the fetch state of the event cell to true
        // TO DO: Should you really be holding logic state at the cell level or should there
        // be a unique identifier for each event ?
        cell.eventRemoteFetch = YES;
        
        // Set all other fields to empty
        [[cell eventDate] setText:@" "];
        [[cell eventCertainty] setText:@" "];
        [[cell eventDistance] setText:@" "];
    }
    else {
        
        // TO DO LATER: !!!!!!!!!!IMPORTANT!!!!!!!!!!!!!: Any change to the formatting here could affect reminder creation (processReminderForEventInCell:,editActionsForRowAtIndexPath) since the reminder values are taken from the cell. Additionally changes here need to be reconciled with changes in the getEvents for ticker's queued reminder creation. Also reconcile in didSelectRowAtIndexPath.
        
        // Show the company ticker associated with the event
        [[cell  companyTicker] setText:[self formatTickerBasedOnEventType:eventAtIndex.listedCompany.ticker]];
        
        // Hide the company Name as this information is not needed to be displayed to the user.
        [[cell companyName] setHidden:YES];
        // Show the image representing the event as this information is needed when user isn't searching
        [[cell eventImage] setHidden:NO];
        // Set the company name associated with the event as this is needed in places like getting the earnings.
        [[cell  companyName] setText:eventAtIndex.listedCompany.name];
        
        // Set the fetch state of the event cell to false
        // TO DO: Should you really be holding logic state at the cell level or should there
        // be a unique identifier for each event ?
        cell.eventRemoteFetch = NO;
        
        // Show the event type. Format it for display. Currently map "Quarterly Earnings" to "Earnings", "Jan Fed Meeting" to "Fed Meeting", "Jan Jobs Report" to "Jobs Report" and so on.
        // TO DO LATER: !!!!!!!!!!IMPORTANT!!!!!!!!!!!!! If you are making a change here, reconcile with prepareForSegue in addition to the methods mentioned above.
        [[cell  eventDescription] setText:[self formatEventType:eventAtIndex.type]];
        
        // Show the event date
        [[cell eventDate] setText:[self formatDateBasedOnEventType:eventAtIndex.type withDate:eventAtIndex.date withRelatedDetails:eventAtIndex.relatedDetails withStatus:eventAtIndex.certainty]];
        
        // Show the appropriate event Image
        [[cell eventImage] setImage:[self getImageBasedOnEventType:eventAtIndex.type]];
        
        // Show the event distance
        [[cell eventDistance] setText:[self calculateDistanceFromEventDate:eventAtIndex.date]];
        
        // Set event distance to the appropriate color using a reddish scheme.
        [[cell eventDistance] setTextColor:[self getColorForDistanceFromEventDate:eventAtIndex.date]];
        
        // Hide the event certainty as this information is not needed to be displayed to the user.
        [[cell eventCertainty] setHidden:YES];
        // Set event certainty though since it's needed by reminder creation.
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
        
        // Check for connectivity. If yes, process the fetch
        if ([self checkForInternetConnectivity]) {
            
            // Set the remote fetch spinner to animating to show a fetch is in progress
            [self.remoteFetchSpinner startAnimating];
            
            // Fetch the event for the related parent company in the background
            // TO DO: Understand this better. PerformSelectorInBackground was causing warnings with attempting to modify UI in a background thread in iOS 9. Using dispatch async solved that error.
            //[self performSelectorInBackground:@selector(getAllEventsFromApiInBackgroundWithTicker:) withObject:(cell.companyTicker).text];
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self getAllEventsFromApiInBackgroundWithTicker:(cell.companyTicker).text];
            });
            
            // TRACKING EVENT: Get Earnings: User clicked the get earnings link for a company/ticker.
            // TO DO: Disabling to not track development events. Enable before shipping.
            /*[FBSDKAppEvents logEvent:@"Get Earnings"
                          parameters:@{ @"Ticker" : (cell.companyTicker).text,
                                        @"Name" : (cell.companyName).text } ];*/
        }
        // If not, show error message
        else {
            
            [self sendUserMessageCreatedNotificationWithMessage:@"Hmm! Unable to get data. Check Connection and retry."];
        }
    }
    // If not then, fetch event details, if the event is of type quarterly earnings before segueing to the details view
    else {
        
        // Check for connectivity. If yes, process the fetch
        if ([self checkForInternetConnectivity]) {
            
            // Read whatever history details are available from event to get ready to segue to the event detail view
            // The prices for the ticker will be fetched in the detail view. 
            FADataController *historyDataController1 = [[FADataController alloc] init];
            
            // Get the currently selected cell and details
            NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
            FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
            
            // Get the database level (not display level) event type based on the display type.
            // Earnings -> Quarterly Earnings, Fed Meeting -> Jan Fed Meeting, Jobs Report -> Jan Jobs Report and so on.
            NSString *eventType = [self formatBackToEventType:selectedCell.eventDescription.text withAddedInfo:selectedCell.eventCertainty.text];
            
            // If Quarterly Earnings or price change event get the historical data for display in the details
            // We basically use the quarterly earnings event history to keep track of the stock prices for price change events since there cannot be a price change event for a ticker that we don't have the quarterly earnings for.
            if ([eventType isEqualToString:@"Quarterly Earnings"]||[eventType containsString:@"% up"]||[eventType containsString:@"% down"]) {
                
                // Set the busy spinner to show that details are being fetched. Do this in a background thread as the main
                // thread is being taken up by the table view. It's a best practice.
                [self.remoteFetchSpinner performSelectorInBackground:@selector(startAnimating) withObject:self];
                
                // Get the ticker for the Quarterly Earnings
                NSString *eventTicker = selectedCell.companyTicker.text;
                
                // Since we  use the quarterly earnings event history to keep track of the stock prices for price change events, use the Quarterly Earnings as the event type, even for price change events
                eventType = @"Quarterly Earnings";
                
                // Add whatever history related data you have in the event data store to the event history data store, if it's not already been added before
                // Get today's date
                NSDate *todaysDate = [NSDate date];
                
                // If Event history doesn't exist insert it
                if (![historyDataController1 doesEventHistoryExistForParentEventTicker:eventTicker parentEventType:eventType])
                {
                    // Insert history, with previous event 1 date being the market open date 30 days ago and previous event 1 related date being the market open date at the beginning of the year.
                    // NOTE: 999999.9 is a placeholder for empty prices, meaning we don't have the value.
                    NSNumber *emptyPlaceholder = [[NSNumber alloc] initWithFloat:999999.9];
                    // To Do: Delete when shipping v2.7
                    NSLog(@"The 30 days ago date when inserting history is:%@",[self scrubDateToNotBeWeekendOrHoliday:[self computeDate30DaysAgoFrom:todaysDate]]);
                    [historyDataController1 insertHistoryWithPreviousEvent1Date:[self scrubDateToNotBeWeekendOrHoliday:[self computeDate30DaysAgoFrom:todaysDate]] previousEvent1Status:@"Estimated" previousEvent1RelatedDate:[self computeMarketStartDateOfTheYearFrom:todaysDate] currentDate:todaysDate previousEvent1Price:emptyPlaceholder previousEvent1RelatedPrice:emptyPlaceholder currentPrice:emptyPlaceholder parentEventTicker:eventTicker parentEventType:eventType];
                }
                // Else update the non price related data, not including current date, on the event history from the event. We don't include the current date as current date is set only once a day which is when the user first accesses the event.
                else
                {
                    [historyDataController1 updateEventHistoryWithPreviousEvent1Date:[self scrubDateToNotBeWeekendOrHoliday:[self computeDate30DaysAgoFrom:todaysDate]] previousEvent1Status:@"Estimated" previousEvent1RelatedDate:[self computeMarketStartDateOfTheYearFrom:todaysDate] parentEventTicker:eventTicker parentEventType:eventType];
                    // TO DO: Delete before shipping v2.7
                    NSLog(@"30 days ago date in updating price history is:%@",[self scrubDateToNotBeWeekendOrHoliday:[self computeDate30DaysAgoFrom:todaysDate]]);
                }
                
                // Call price API, in the main thread, to refresh the price history
                // Check to see if the current date on which the price history was fetched is today or not in addition to if it was fetched at all. If today, fetch only current price. If not, then fetch both historical and current price
                EventHistory *selectedEventHistory = [historyDataController1 getEventHistoryForParentEventTicker:eventTicker parentEventType:eventType];
                // Set a value indicating that a value is not available. Currently a Not Available value
                // is represented by 999999.9
                double notAvailable = 999999.9f;
                double prev1PriceDbl = [[selectedEventHistory previous1Price] doubleValue];
                double prev1RelatedPriceDbl = [[selectedEventHistory previous1RelatedPrice] doubleValue];
                double currentPriceDbl = [[selectedEventHistory currentPrice] doubleValue];
                NSDateFormatter *checkDateFormatter = [[NSDateFormatter alloc] init];
                [checkDateFormatter setDateFormat:@"yyyy-MM-dd"];
                // Format historical and now current dates to local time zone comparison
                NSString *currentDateInHistory = [checkDateFormatter stringFromDate:selectedEventHistory.currentDate];
                NSString *currentDateNow = [checkDateFormatter stringFromDate:todaysDate];
                if ((prev1PriceDbl == notAvailable)||(prev1RelatedPriceDbl == notAvailable)||(currentPriceDbl == notAvailable)||([currentDateInHistory caseInsensitiveCompare:currentDateNow] != NSOrderedSame))
                {
                    [self getPricesWithCompanyTicker:eventTicker eventType:eventType dataController:historyDataController1 historyFetch:YES];
                    // Current date is set only once a day which is when the user first accesses the event.
                    [historyDataController1 updateEventHistoryWithCurrentDate:todaysDate parentEventTicker:eventTicker parentEventType:eventType];
                } else {
                    [self getPricesWithCompanyTicker:eventTicker eventType:eventType dataController:historyDataController1 historyFetch:NO];
                }
            }
        }
        // If not, show error message
        else {
            
            //  Currently for simplicity, we are handling this in the event details controller as that's where the user is transitioning to on click.
        }
        
        // Stop the remote fetch spinner animation to indicate fetch is complete. Do this in a background thread as the main
        // thread is being taken up by the table view. It's a best practice.
        [self.remoteFetchSpinner performSelectorInBackground:@selector(stopAnimating) withObject:self];
        
        // Perform segue to the event detail view
        [self performSegueWithIdentifier:@"ShowEventDetails1" sender:self];
    }
    
    // If search bar is in edit mode but the user has not entered any character to search (i.e. a search filter has not been applied), clear out of the search context when a user clicks on a row
    if ([self.eventsSearchBar isFirstResponder] && !(self.filterSpecified)) {
        
        [self.eventsSearchBar resignFirstResponder];
    }
}

#pragma mark - Data Source API

// Get all companies from API. Typically called in a background thread
- (void)getAllCompaniesFromApiInBackground
{
    // Get a data controller for data store interactions
    FADataController *companiesDataController = [[FADataController alloc] init];
    
    // Creating a task that continues to process in the background.
    __block UIBackgroundTaskIdentifier bgFetchTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"bgCompaniesFetch" expirationHandler:^{
        
        // Clean up any unfinished task business before it's about to be terminated
        // In our case, check if all pages of companies data has been synced. If not, mark status to failed
        // so that another thread can pick up the completion on restart. Currently this is hardcoded to 26 as 26 pages worth of companies (7375 companies at 300 per page) were available as of July 15, 2105. When you change this, change the hard coded value in getAllCompaniesFromApi in FADataController. Also change in Search Bar Began Editing in the Events View Controller.
        if ([[companiesDataController getCompanySyncStatus] isEqualToString:@"FullSyncStarted"]&&[[companiesDataController getCompanySyncedUptoPage] integerValue] < [[companiesDataController getTotalNoOfCompanyPagesToSync] integerValue])
        {
            [companiesDataController upsertUserWithCompanySyncStatus:@"FullSyncAttemptedButFailed" syncedPageNo:[companiesDataController getCompanySyncedUptoPage]];
        }
        
        // Stopped or ending the task outright.
        [[UIApplication sharedApplication] endBackgroundTask:bgFetchTask];
        bgFetchTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
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
    
    [self.remoteFetchSpinner stopAnimating];
    
    // Force a search to capture the refreshed event, so that the table can be refreshed
    // to show the refreshed event
    [self searchBarSearchButtonClicked:self.eventsSearchBar];
}

// Get stock prices for company given a ticker and event type (event info). Executes in the main thread.
- (void)getPricesWithCompanyTicker:(NSString *)ticker eventType:(NSString *)type dataController:(FADataController *)specificDataController historyFetch:(BOOL)fetchHistory;
{
    EventHistory *eventForPricesFetch = [specificDataController getEventHistoryForParentEventTicker:ticker parentEventType:type];
    
    // Get current price and set the global current price and change string to the value returned.
    self.currPriceAndChange = [specificDataController getCurrentStockPriceFromApiForTicker:ticker companyEventType:type];
    
    // Get historical prices if needed
    if(fetchHistory) {
        [specificDataController getStockPricesFromApiForTicker:ticker companyEventType:type fromDateInclusive:eventForPricesFetch.previous1RelatedDate toDateInclusive:eventForPricesFetch.currentDate];
    }
    
    // Use this if you move this operation to a background thread
    //[[NSNotificationCenter defaultCenter]postNotificationName:@"EventHistoryUpdated" object:nil];
}

#pragma mark - Search Bar Delegate Methods, Related

// When Search button associated with the search bar is clicked, search the ticker and name
// fields on the company related to the event, for the search text entered. Display the events
// found. If there are no events, search for the same fields on the company to display the matching
// companies to prompt the user to fetch the events data for these companies.
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    
    // Validate search text entered. If valid
    if ([self searchTextValid:searchBar.text]) {
    
        // Check to see if "All" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"All"] == NSOrderedSame) {
            // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
            self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"All"];
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
        
        // Check to see if "Earnings" events types are selected. Search on "ticker" or "name" fields for the listed Company for earnings events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
            self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Earnings"];
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
        
        // Check to see if "Economic" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Economic"] == NSOrderedSame) {
            // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
            self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Economic"];
            // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
            // has been specified.
            self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Product" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all product events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Product"] == NSOrderedSame) {
            // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
            self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Product"];
            // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
            // has been specified.
            self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
    }
    
    // TRACKING EVENT: Search Button Clicked: User clicked the search button to search for a company or ticker.
    // TO DO: Disabling to not track development events. Enable before shipping.
    /*[FBSDKAppEvents logEvent:@"Search Button Clicked"
                  parameters:@{ @"Search String" : searchBar.text } ];*/
    
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
        
        // Check to see if "All" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"All"] == NSOrderedSame) {
            // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
            self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"All"];
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
        
        // Check to see if "Earnings" events types are selected. Search on "ticker" or "name" fields for the listed Company for earnings events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
            self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Earnings"];
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
        
        // Check to see if "Economic" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Economic"] == NSOrderedSame) {
            // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
            self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Economic"];
            // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
            // has been specified.
            self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }

        // Check to see if "Product" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all product events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Product"] == NSOrderedSame) {
            // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
            self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Product"];
            // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
            // has been specified.
            self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
    }
    // If not valid
    else {
        
        // Check to see if "All" events types are selected. In this case query all events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"All"] == NSOrderedSame) {
            // Query all future events, including today, as that is the default view
            self.eventResultsController = [self.primaryDataController getAllFutureEvents];
            
            // Set the Filter Specified flag to false, indicating that no search filter has been specified
            self.filterSpecified = NO;
            
            // Set the filter type to None_Specified i.e. no filter is specified
            self.filterType = [NSString stringWithFormat:@"None_Specified"];
            
            // Reload messages table
            [self.eventsListTable reloadData];
            
            // TO DO: In case you want to clear the search context
            [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
        
        // Check to see if "Earnings" events types are selected. In this case query all earnings
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            // Query all future events, including today, as that is the default view
            self.eventResultsController = [self.primaryDataController getAllFutureEarningsEvents];
            
            // Set the Filter Specified flag to false, indicating that no search filter has been specified
            self.filterSpecified = NO;
            
            // Set the filter type to None_Specified i.e. no filter is specified
            self.filterType = [NSString stringWithFormat:@"None_Specified"];
            
            // Reload messages table
            [self.eventsListTable reloadData];
            
            // TO DO: In case you want to clear the search context
            [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
        
        // Check to see if "Economic" events types are selected. In this case query all economic events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Economic"] == NSOrderedSame) {
            // Query all future events, including today, as that is the default view
            self.eventResultsController = [self.primaryDataController getAllFutureEconEvents];
            
            // Set the Filter Specified flag to false, indicating that no search filter has been specified
            self.filterSpecified = NO;
            
            // Set the filter type to None_Specified i.e. no filter is specified
            self.filterType = [NSString stringWithFormat:@"None_Specified"];
            
            // Reload messages table
            [self.eventsListTable reloadData];
            
            // TO DO: In case you want to clear the search context
            [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
        
        // Check to see if "Product" events types are selected. In this case query all product events.
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Product"] == NSOrderedSame) {
            // Query all future events, including today, as that is the default view
            self.eventResultsController = [self.primaryDataController getAllFutureProductEvents];
            
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
// If not show the user a message warning them.
- (BOOL)searchBarShouldBeginEditing:(UISearchBar*)searchBar {
    
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
        
        // TRACKING EVENT: Search Initiated: User clicked into the search bar to initiate a search.
        // TO DO: Disabling to not track development events. Enable before shipping.
        //[FBSDKAppEvents logEvent:@"Search Initiated"];
        
        // If the newer companies data is still being synced, give the user a warning message
        if (![[self.primaryDataController getCompanySyncStatus] isEqualToString:@"FullSyncDone"]) {
            
            [self sendUserMessageCreatedNotificationWithMessage:@"Fetching new tickers! Can't find one, retry later."];
        }
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
    
    //When user touches outside the search bar, if search bar is in edit mode but the user has not entered any character to search (i.e. a search filter has not been applied), clear out of the search context.
    if ([self.eventsSearchBar isFirstResponder] && !(self.filterSpecified)) {
        [self.eventsSearchBar resignFirstResponder];
    }
    
    // When user touches outside the search bar, when a fetch event is displayed or in progress, clear out of the search context.
    if ([self.eventsSearchBar isFirstResponder] && (self.filterSpecified)) {
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
    }
}

#pragma mark - Event Type Selection

// When an event type selection has been made, change the color of the selected type and 1) show the appropriate event types in the results table 2) Set the correct search bar placeholder text 3) Clear out the search context
- (IBAction)eventTypeSelectAction:(id)sender {
    
    // Change color of the selected option to indicate selection and filter the table to show the correct events of that type. Also set the color of the focus bar to the same color as the selected option.
    // All Event Types - Color Black
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"All"] == NSOrderedSame) {
        [self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor blackColor]} forState:UIControlStateSelected];
        [self.focusBar setTextColor:[UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f]];
        [self.focusBar setBackgroundColor:[UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f]];
        [self.focusBar setTintColor:[UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f]];
        
        // Clear out the search context
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
        
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"COMPANY or TICKER or EVENT";
        
        // Query all future events, including today.
        self.eventResultsController = [self.primaryDataController getAllFutureEvents];
        [self.eventsListTable reloadData];
        
        // TRACKING EVENT: Event Type Selected: User selected All event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        /*[FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"All" } ];*/
    }
    // Earnings - Color Knotifi Green
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
        [self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f]} forState:UIControlStateSelected];
        [self.focusBar setTextColor:[UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f]];
        [self.focusBar setBackgroundColor:[UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f]];
        [self.focusBar setTintColor:[UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f]];
        
        // Clear out the search context
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
        
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"COMPANY or TICKER";
        
        // Query all future earnings events, including today.
        self.eventResultsController = [self.primaryDataController getAllFutureEarningsEvents];
        [self.eventsListTable reloadData];
        
        // TRACKING EVENT: Event Type Selected: User selected Earnings event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        /*[FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Earnings" } ];*/
    }
    // Economic - Color Econ Blue
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Economic"] == NSOrderedSame) {
        [self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f]} forState:UIControlStateSelected];
        [self.focusBar setTextColor:[UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f]];
        [self.focusBar setBackgroundColor:[UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f]];
        [self.focusBar setTintColor:[UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f]];
        
        // Clear out the search context
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
        
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"EVENT";
        
        // Query all future economic events, including today.
        self.eventResultsController = [self.primaryDataController getAllFutureEconEvents];
        [self.eventsListTable reloadData];
        
        // TRACKING EVENT: Event Type Selected: User selected Economic event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        /*[FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Economic" } ];*/
    }
    // Product - Product Brown
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Product"] == NSOrderedSame) {
        [self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:113.0f/255.0f green:34.0f/255.0f blue:32.0f/255.0f alpha:1.0f]} forState:UIControlStateSelected];
        [self.focusBar setTextColor:[UIColor colorWithRed:113.0f/255.0f green:34.0f/255.0f blue:32.0f/255.0f alpha:1.0f]];
        [self.focusBar setBackgroundColor:[UIColor colorWithRed:113.0f/255.0f green:34.0f/255.0f blue:32.0f/255.0f alpha:1.0f]];
        [self.focusBar setTintColor:[UIColor colorWithRed:113.0f/255.0f green:34.0f/255.0f blue:32.0f/255.0f alpha:1.0f]];
        
        // Clear out the search context
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
        
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"COMPANY or TICKER or EVENT";
        
        // Query all future product events, including today.
        self.eventResultsController = [self.primaryDataController getAllFutureProductEvents];
        [self.eventsListTable reloadData];
        
        // TRACKING EVENT: Event Type Selected: User selected Product event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        /*[FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Product" } ];*/
    }
}

#pragma mark - Notifications

// Send a notification to the events list controller with a message that should be shown to the user
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"UserMessageCreated" object:msgContents];
}

#pragma mark - Change Listener Responses

// Refetch the events and refresh the events table when the events store for the table has changed
- (void)eventStoreChanged:(NSNotification *)notification {
    
    // Create a new DataController so that this thread has its own MOC
    // TO DO: Understand at what point does a new thread get spawned off. Seems to me the new thread is being created for
    // reloading the table. SHouldn't I be creating the new MOC in that thread as opposed to here ? Maybe it doesn't matter
    // as long as I am not sharing MOCs across threads ? The general rule with Core Data is one Managed Object Context per thread, and one thread per MOC
    FADataController *secondaryDataController = [[FADataController alloc] init];
    
    // Query all future events depending on the type selected in the selector, including today, as that is the default view first shown
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"All"] == NSOrderedSame) {
        self.eventResultsController = [secondaryDataController getAllFutureEvents];
    }
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
        self.eventResultsController = [secondaryDataController getAllFutureEarningsEvents];
    }
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Economic"] == NSOrderedSame) {
        self.eventResultsController = [secondaryDataController getAllFutureEconEvents];
    }
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Product"] == NSOrderedSame) {
        self.eventResultsController = [secondaryDataController getAllFutureProductEvents];
    }

    [self.eventsListTable reloadData];
    // TO DO: Delete before shipping v2
    //NSLog(@"EVENT RELOAD NOTIFICATION: In View Controller");
}

// Show the error message for a temporary period and then fade it if a user message has been generated
// TO DO: Currently set to 20 seconds. Change as you see fit.
- (void)userMessageGenerated:(NSNotification *)notification {
    
    // Make sure the message bar is empty and visible to the user
    self.messageBar.text = @"";
    self.messageBar.alpha = 1.0;
    
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

// Take a queued reminder and create it in the user's OS Reminders now that the event has been confirmed.
// The notification object contains an array of strings representing {eventType,companyTicker,eventDateText}
// We do this here, instead of the event details since this is the most likely screen the user will be on when
// the reminders are confirmed in a background thread
- (void)createQueuedReminder:(NSNotification *)notification {
    
    NSArray *infoArray = [notification object];
    // Create a new DataController so that this thread has its own MOC
    // TO DO: Understand at what point does a new thread get spawned off. Shouldn't I be creating the new MOC in that thread as opposed to here ? Maybe it doesn't matter as long as I am not sharing MOCs across threads ? The general rule with Core Data is one Managed Object Context per thread, and one thread per MOC
    FADataController *thirdDataController = [[FADataController alloc] init];
    
    // Create the reminder
    BOOL success = [self createReminderForEventOfType:[infoArray objectAtIndex:0] withTicker:[infoArray objectAtIndex:1] dateText:[infoArray objectAtIndex:2] andDataController:thirdDataController];
    
    // If successful, update the status of the event in the data store to be "Created" from "Queued"
    if (success) {
        [thirdDataController updateActionWithStatus:@"Created" type:@"OSReminder" eventTicker:[infoArray objectAtIndex:1] eventType:[infoArray objectAtIndex:0]];
    }
    // Else log an error message
    else {
        NSLog(@"ERROR:Creating a queued reminder for ticker:%@ and event type:%@ failed", [infoArray objectAtIndex:1], [infoArray objectAtIndex:0]);
    }
}

// Respond to the notification to start the busy spinner
- (void)startBusySpinner:(NSNotification *)notification {
    
    // Set the busy spinner to spin.
    [self.remoteFetchSpinner startAnimating];
}

// Respond to the notification to stop the busy spinner
- (void)stopBusySpinner:(NSNotification *)notification {
    
    // Set the busy spinner to stop spinning.
    [self.remoteFetchSpinner stopAnimating];
}

#pragma mark - Reminder Related

// Set the getter for the user event store property so that only one event store object gets created
- (EKEventStore *)userEventStore {
    if (!_userEventStore) {
        _userEventStore = [[EKEventStore alloc] init];
    }
    return _userEventStore;
}


// Actually create the reminder in the user's default calendar and return success or failure depending on the outcome.
- (BOOL)createReminderForEventOfType:(NSString *)eventType withTicker:(NSString *)companyTicker dateText:(NSString *)eventDateText andDataController:(FADataController *)reminderDataController  {
    
    BOOL creationSuccess = NO;
    
    // Set title of the reminder to the reminder text.
    EKReminder *eventReminder = [EKReminder reminderWithEventStore:self.userEventStore];
    NSString *reminderText = @"A financial event of interest is tomorrow.";
    // Set title of the reminder to the reminder text, based on event type
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        reminderText = [NSString stringWithFormat:@"Knotifi ▶︎ %@ Earnings tomorrow %@",companyTicker,eventDateText];
    }
    if ([eventType containsString:@"Fed Meeting"]) {
        reminderText = [NSString stringWithFormat:@"Knotifi ▶︎ Fed Meeting Outcome tomorrow %@", eventDateText];
    }
    if ([eventType containsString:@"Jobs Report"]) {
        reminderText = [NSString stringWithFormat:@"Knotifi ▶︎ Jobs Report tomorrow %@", eventDateText];
    }
    if ([eventType containsString:@"Consumer Confidence"]) {
        reminderText = [NSString stringWithFormat:@"Knotifi ▶︎ Consumer Confidence Report tomorrow %@", eventDateText];
    }
    if ([eventType containsString:@"GDP Release"]) {
        reminderText = [NSString stringWithFormat:@"Knotifi ▶︎ GDP Release tomorrow %@", eventDateText];
    }
    if ([eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        reminderText = [NSString stringWithFormat:@"Knotifi ▶︎ %@ tomorrow %@",eventType,eventDateText];
    }
    eventReminder.title = reminderText;
    
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
    
    // Save the Reminder and return success or failure
    NSError *error = nil;
    creationSuccess = [self.userEventStore saveReminder:eventReminder commit:YES error:&error];
    
    return creationSuccess;
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

#pragma mark - Navigation

// Check to see if the table cell press is for a "Get Events" cell. If yes, then don't perform the table segue
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    
    BOOL returnVal = YES;
    
    // Check the segue is "ShowEventDetails"
    //if ([identifier isEqualToString:@"ShowEventDetails"]) {
    if ([identifier isEqualToString:@"ShowEventDetails1"]) {
        // If the cell is the "Get Earnings" cell identified by if Remote Fetch indicator is true, set return value to false indicating no segue should be performed
        NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
        FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
        if (selectedCell.eventRemoteFetch) {
            returnVal = NO;
        }
    }
    
    if ([identifier isEqualToString:@"ShowEventDetails"]) {
        returnVal = NO;
    }

    return returnVal;
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
   // if ([[segue identifier] isEqualToString:@"ShowEventDetails"]) {
    if ([[segue identifier] isEqualToString:@"ShowEventDetails1"]) {
        FAEventDetailsViewController *eventDetailsViewController = [segue destinationViewController];
        
        // TO DO: Delete before shipping v2.5. Not needed anymore.
        // Set the title on the destination view controller to be the same as that of the current view controller which is today's date
        //[eventDetailsViewController.navigationItem setTitle:self.navigationController.navigationBar.topItem.title];
        
        // Get the currently selected cell and set details for the destination.
        // IMPORTANT: If the format here or in the events UI is changed, reminder creation in the details screen will break.
        FADataController *segueDataController = [[FADataController alloc] init];
        NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
        FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
        NSString *eventCompany = selectedCell.companyName.text;
        // Format event display name back to event type for logic in the destination
        NSString *eventType = [self formatBackToEventType:selectedCell.eventDescription.text withAddedInfo:selectedCell.eventCertainty.text];
        // Set the full name of the Event Parent Ticker for processing in destination
        [eventDetailsViewController setParentTicker:[segueDataController getTickerForName:selectedCell.companyName.text]];
        // Set Event Type for processing in destination
        [eventDetailsViewController setEventType: eventType];
        // Set Event Schedule as text for processing in destination
        [eventDetailsViewController setEventDateText:selectedCell.eventDate.text];
        // Set Event certainty status for processing in destination
        [eventDetailsViewController setEventCertainty:selectedCell.eventCertainty.text];
        // Set Event Parent Company Name for processing in destination
        [eventDetailsViewController setParentCompany:eventCompany];
        
        // Set Event Title for display in destination
        [eventDetailsViewController setEventTitleStr:eventCompany];
        // Set current price and change string in the destination
        [eventDetailsViewController setCurrentPriceAndChange:[self formatCurrPriceAndChange:self.currPriceAndChange]];
        // Set Event Schedule for display in destination
        // For Product Events that are estimated, prepend the estimated keyword
        // When new product event types are added, change here as well
        if (([eventType containsString:@"Launch"]||[eventType containsString:@"Conference"])&&[selectedCell.eventCertainty.text isEqualToString:@"Estimated"]) {
            [eventDetailsViewController setEventScheduleStr:[NSString stringWithFormat:@"%@ %@",selectedCell.eventCertainty.text,selectedCell.eventDate.text]];
            
        }
        // For price change events, there's no schedule
        else if ([eventType containsString:@"% up"]||[eventType containsString:@"% down"]) {
            [eventDetailsViewController setEventScheduleStr:@" "];
        }
        else {
            [eventDetailsViewController setEventScheduleStr:selectedCell.eventDate.text];
        }
        
        // TRACKING EVENT: Go To Details: User clicked the event in the events list to go to the details screen.
        // TO DO: Disabling to not track development events. Enable before shipping.
        /*[FBSDKAppEvents logEvent:@"Go To Details"
                      parameters:@{ @"Ticker" : [segueDataController getTickerForName:selectedCell.companyName.text],
                                    @"Event Type" : eventType,
                                    @"Name" : (selectedCell.companyName).text } ];*/
    }
}

#pragma mark - Utility Methods

// Compute the likely date for the previous event based on current event type (currently only Quarterly), previous event related date (e.g. quarter end related to the quarterly earnings), current event date and current event related date.
- (NSDate *)computePreviousEventDateWithCurrentEventType:(NSString *)currentType currentEventDate:(NSDate *)currentDate currentEventRelatedDate:(NSDate *)currentRelatedDate previousEventRelatedDate:(NSDate *)previousRelatedDate
{
    
    // TO DO: Use Earnings type later
    
    // Calculate the number of days between current event date (quarterly earnings) and current event related date (end of quarter being reported)
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    // NSUInteger unitFlags = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSUInteger unitFlags =  NSCalendarUnitDay;
    NSDateComponents *diffDateComponents = [aGregorianCalendar components:unitFlags fromDate:currentRelatedDate toDate:currentDate options:0];
    NSInteger difference = [diffDateComponents day];
    
    // Add the no of days to the previous related event date (previously reported quarter end)
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = difference;
    NSDate *previousEventDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:previousRelatedDate options:0];
    
    // Make sure the date doesn't fall on a Friday, Saturday, Sunday. In these cases move it to the previous Thursday for Friday and following Monday for Saturday and Sunday. TO DO LATER: Factor in holidays here.
    // Convert from string to Date
    NSDateFormatter *previousDayFormatter = [[NSDateFormatter alloc] init];
    [previousDayFormatter setDateFormat:@"EEE"];
    NSString *previousDayString = [previousDayFormatter stringFromDate:previousEventDate];
    if ([previousDayString isEqualToString:@"Fri"]) {
        differenceDayComponents.day = -1;
        previousEventDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:previousEventDate options:0];
    }
    if ([previousDayString isEqualToString:@"Sat"]) {
        differenceDayComponents.day = 2;
        previousEventDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:previousEventDate options:0];
    }
    if ([previousDayString isEqualToString:@"Sun"]) {
        differenceDayComponents.day = 1;
        previousEventDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:previousEventDate options:0];
    }
    
    return previousEventDate;
}

// Compute the unscrubbed date 30 days ago from today. Unscrubbed means it could be a weekend or a holiday.
- (NSDate *)computeDate30DaysAgoFrom:(NSDate *)startingDate
{
    // Subtract 30 days from start date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = -30;
    NSDate *returnDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:startingDate options:0];
    
    return returnDate;
}

// Compute the scrubbed first market day of the year for the given date. Currently it works only for 2016.
// TO DO: Change this for 2017 and so on and so forth
- (NSDate *)computeMarketStartDateOfTheYearFrom:(NSDate *)givenDate
{
    // Compute the first date of the year from the given date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents * aCalComponents = [aGregorianCalendar components: NSCalendarUnitYear fromDate:givenDate];
    [aCalComponents setYear:[aCalComponents year]];
    NSDate *returnDate = [aGregorianCalendar dateFromComponents:aCalComponents];
    
    // For 2016, the first market open day was 3 days after, Jan 1 putting it at Jan 4.
    // TO DO: For 2017, the first market day will be 2 days later on Jan 3. So add 2 instead of 3 here. That's it. www.timeanddate.com/calendar/?year=2017&country=1
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = 3;
    returnDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:returnDate options:0];
    
    return returnDate;
}


// Make sure the date doesn't fall on a Friday, Saturday, Sunday. In these cases move it to the previous Friday for Saturday and following Monday for Sunday. TO DO LATER: Factor in holidays here.
- (NSDate *)scrubDateToNotBeWeekendOrHoliday:(NSDate *)dateToScrub
{
    // Make sure the date doesn't fall on a Friday, Saturday, Sunday. In these cases move it to the previous Friday for Saturday and following Monday for Sunday. TO DO LATER: Factor in holidays here.
    // Convert from string to Date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateFormatter *dayFormatter = [[NSDateFormatter alloc] init];
    [dayFormatter setDateFormat:@"EEE"];
    // Set the formatter to be GMT since dates are always GMT and formatters are defaulted to local timezone
    [dayFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    NSDate *scrubbedDate = dateToScrub;
    NSString *dayString = [dayFormatter stringFromDate:dateToScrub];

    if ([dayString isEqualToString:@"Sat"]) {
        differenceDayComponents.day = -1;
        scrubbedDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:dateToScrub options:0];
    }
    
    if ([dayString isEqualToString:@"Sun"]) {
        differenceDayComponents.day = 1;
        scrubbedDate = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:dateToScrub options:0];
    }
    
    return scrubbedDate;
}

// Check if the ticker other than a normal ticker e.g. for economic event
// ticker will be of the format ECONOMY_FOMC. In that case format it to say ECONOMY.
- (NSString *)formatTickerBasedOnEventType:(NSString *)tickerToFormat
{
    NSString *formattedTicker = tickerToFormat;
    
    if ([tickerToFormat containsString:@"ECONOMY_"]) {
        
        formattedTicker = @"ECON";
    }
    
    return formattedTicker;
}

// Format the event type for appropriate display. Currently the formatting looks like the following: Quarterly Earnings -> Earnings. Jan Fed Meeting -> Fed Meeting. Jan Jobs Report -> Jobs Report and so on. For product events strip out conference keyword WWDC 2016 Conference -> WWDC 2016
- (NSString *)formatEventType:(NSString *)rawEventType
{
    NSString *formattedEventType = rawEventType;
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        formattedEventType = @"Earnings";
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        formattedEventType = @"Fed Meeting";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        formattedEventType = @"Jobs Report";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        formattedEventType = @"Consumer Confidence";
    }
    
    if ([rawEventType containsString:@"GDP Release"]) {
        formattedEventType = @"GDP Release";
    }
    
    if ([rawEventType containsString:@"Conference"]) {
        formattedEventType = [rawEventType stringByReplacingOccurrencesOfString:@" Conference" withString:@""];
    }
    
    return formattedEventType;
}

// Take the event displayed and format it back to the event type stored in the db. Currently the formatting looks like the following: Earnings -> Quarterly Earnings. Fed Meeting -> Jan Fed Meeting. Jobs Report -> Jan Jobs Report and so on. For product events, only the conference keyword needs to be added back. So WWDC 2016 -> WWDC 2016 Conference. NOTE: When a new product event type other than launch or conference is added, reconcile here as well.
- (NSString *)formatBackToEventType:(NSString *)rawEventType withAddedInfo:(NSString *)addtlInfo
{
    NSString *formattedEventType = rawEventType;
    
    if ([rawEventType isEqualToString:@"Earnings"]) {
        formattedEventType = @"Quarterly Earnings";
    } else if (([addtlInfo isEqualToString:@"Confirmed"]||[addtlInfo isEqualToString:@"Estimated"])&&(![rawEventType containsString:@"Launch"])){
        formattedEventType = [NSString stringWithFormat:@"%@ %@",rawEventType,@"Conference"];
    } else if (([addtlInfo isEqualToString:@"Confirmed"]||[addtlInfo isEqualToString:@"Estimated"])&&([rawEventType containsString:@"Launch"])) {
        // Do Nothing as for Launch the full event type already exists
    } else if ([rawEventType containsString:@"% up"]||[rawEventType containsString:@"% down"]) {
        // Do Nothing as for price events the full event type already exists
    }
    else {
        formattedEventType = [NSString stringWithFormat:@"%@ %@",addtlInfo,rawEventType];
    }
    
    return formattedEventType;
}


// Format the event date for appropriate display. Currently the formatting looks like: Quarterly Earnings -> Wed January 27 Before Open. Fed Meeting -> Wed January 27 2:00 p.m. ET . iPhone 7 Launch -> Early September
- (NSString *)formatDateBasedOnEventType:(NSString *)rawEventType withDate:(NSDate *)eventDate withRelatedDetails:(NSString *)eventRelatedDetails withStatus:(NSString *)eventStatus
{
    
    NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
    [eventDateFormatter setDateFormat:@"EEE MMMM dd"];
    NSString *eventDateString = [eventDateFormatter stringFromDate:eventDate];
    NSString *eventTimeString = eventRelatedDetails;
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
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
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        
        eventTimeString = @"2 p.m. ET";
        eventDateString = [NSString stringWithFormat:@"%@ %@",eventDateString,eventTimeString];
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        
        eventTimeString = @"8:30 a.m. ET";
        eventDateString = [NSString stringWithFormat:@"%@ %@",eventDateString,eventTimeString];
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        
        eventTimeString = @"10 a.m. ET";
        eventDateString = [NSString stringWithFormat:@"%@ %@",eventDateString,eventTimeString];
    }
    
    if ([rawEventType containsString:@"GDP Release"]) {
        
        eventTimeString = @"8:30 a.m. ET";
        eventDateString = [NSString stringWithFormat:@"%@ %@",eventDateString,eventTimeString];
    }
    
    if ([rawEventType containsString:@"Launch"]||[rawEventType containsString:@"Conference"]) {
        
        if ([eventStatus isEqualToString:@"Confirmed"]) {
            eventDateString = [NSString stringWithFormat:@"%@ %@",eventDateString,eventTimeString];
        }
        // If status is not confirmed set 1-10 as Early 10-20 Mid 20-30/31 as Late
        if ([eventStatus isEqualToString:@"Estimated"]) {
            
            // Get the year in the event date as rumored product events could well be in the next year
            [eventDateFormatter setDateFormat:@"EEE MMMM dd y"];
            eventDateString = [eventDateFormatter stringFromDate:eventDate];
            NSArray *eventDateComponents = [eventDateString componentsSeparatedByString:@" "];
            NSString *eventDayString = eventDateComponents[2];
            int eventDay = [eventDayString intValue];
            // Return an appropriately formatted string
            if (eventDay <= 10) {
                 eventDateString = [NSString stringWithFormat:@"%@ %@ %@",@"Early",eventDateComponents[1],eventDateComponents[3]];
            } else if (eventDay <= 20) {
                eventDateString = [NSString stringWithFormat:@"%@ %@ %@",@"Mid",eventDateComponents[1],eventDateComponents[3]];
            } else if (eventDay <= 31) {
                eventDateString = [NSString stringWithFormat:@"%@ %@ %@",@"Late",eventDateComponents[1],eventDateComponents[3]];
            }
        }
    }
    
    // For price change events, there's no schedule
    if ([rawEventType containsString:@"% up"]||[rawEventType containsString:@"% down"]) {
        eventDateString = @" ";
    }
    
    return eventDateString;
}

// Calculate how far the event is from today. Typical values are Past,Today, Tomorrow, 2d, 3d and so on.
- (NSString *)calculateDistanceFromEventDate:(NSDate *)eventDate
{
    NSString *formattedDistance = @"Upcoming";
    
    // Calculate the number of days between event date and today's date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSUInteger unitFlags =  NSCalendarUnitDay;
    NSDateComponents *diffDateComponents = [aGregorianCalendar components:unitFlags fromDate:[self setTimeToMidnightLastNightOnDate:[NSDate date]] toDate:[self setTimeToMidnightLastNightOnDate:eventDate] options:0];
    NSInteger difference = [diffDateComponents day];
    
    // Return an appropriately formatted string
    if (difference < 0) {
        formattedDistance = @"Past";
    } else if (difference == 0) {
        formattedDistance = @"Today";
    } else if (difference == 1) {
        formattedDistance = @"Tomorrow";
    } else {
        formattedDistance = [NSString stringWithFormat:@"%@d",[@(difference) stringValue]];
    }
    
    return formattedDistance;
}

// Return the appropriate color for event distance based on how far it is from today.
- (UIColor *)getColorForDistanceFromEventDate:(NSDate *)eventDate
{
    // Set returned color to light gray text to start with
    UIColor *colorToReturn = [UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f];
    
    // Calculate the number of days between event date and today's date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSUInteger unitFlags =  NSCalendarUnitDay;
    NSDateComponents *diffDateComponents = [aGregorianCalendar components:unitFlags fromDate:[self setTimeToMidnightLastNightOnDate:[NSDate date]] toDate:[self setTimeToMidnightLastNightOnDate:eventDate] options:0];
    NSInteger difference = [diffDateComponents day];
    
    // Return an appropriate color based on distance. Typical values and colors are Past(Light Gray Text),Today(Orangish Red), Tomorrow (Slightly less orangish red), 2d-7d (More orange, less red) and everything else (Light Gray).
    // Currently return only a single shade of red for near events.
    if (difference == 0) {
        // Older orangish red
        //colorToReturn = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
        // Newer pinkish deep red
        colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
        
    } else if (difference == 1) {
        // Older slightly less orangish red
        //colorToReturn = [UIColor colorWithRed:232.0f/255.0f green:81.0f/255.0f blue:62.0f/255.0f alpha:1.0f];
        // Newer pinkish deep red
        colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
    } else if ((difference > 1)&&(difference < 8)){
        // Older More orange, less red
        //colorToReturn = [UIColor colorWithRed:255.0f/255.0f green:89.0f/255.0f blue:68.0f/255.0f alpha:1.0f];
        // Newer pinkish deep red
        colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
    }
    
    return colorToReturn;
}

// Return the appropriate event image based on event type
- (UIImage *)getImageBasedOnEventType:(NSString *)eventType
{
    UIImage *eventImage;
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        
        eventImage = [UIImage imageNamed:@"EarningsListCircle"];
        
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        
        eventImage = [UIImage imageNamed:@"EconListCircle"];
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        
        eventImage = [UIImage imageNamed:@"EconListCircle"];
    }
    
    if ([eventType containsString:@"Consumer Confidence"]) {
        
        eventImage = [UIImage imageNamed:@"EconListCircle"];
    }
    
    if ([eventType containsString:@"GDP Release"]) {
        
        eventImage = [UIImage imageNamed:@"EconListCircle"];
    }
    
    if ([eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        
        eventImage = [UIImage imageNamed:@"ProdListCircle"];
    }
    
    return eventImage;
}

// Format the given date to set the time on it to midnight last night. e.g. 03/21/2016 9:00 pm becomes 03/21/2016 12:00 am.
- (NSDate *)setTimeToMidnightLastNightOnDate:(NSDate *)dateToFormat
{
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponents = [aGregorianCalendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:dateToFormat];
    NSDate *formattedDate = [aGregorianCalendar dateFromComponents:dateComponents];
    
    return formattedDate;
}

// Format the current price and change string appropriately
- (NSString *)formatCurrPriceAndChange:(NSString *)rawPriceStr
{
    NSString *formattedStr = rawPriceStr;
    
    // If there is actually price information, then format it
    if (![rawPriceStr isEqualToString:@"NA"]) {
        // Get the price components in an array
        NSArray *priceComponents = [rawPriceStr componentsSeparatedByString:@"_"];
        
        // Construct the formatted price change string
        if ([rawPriceStr containsString:@"-"]) {
            formattedStr = [NSString stringWithFormat:@"$%@ ▼%@ %@%%",priceComponents[0],priceComponents[1],priceComponents[2]];
        } else {
            formattedStr = [NSString stringWithFormat:@"$%@ ▲+%@ +%@%%",priceComponents[0],priceComponents[1],priceComponents[2]];
        }
    }
    
    return formattedStr;
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
