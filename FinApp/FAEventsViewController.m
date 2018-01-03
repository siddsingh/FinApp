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
#import "FASnapShot.h"
#import <SafariServices/SafariServices.h>
@import EventKit;

@interface FAEventsViewController () <SFSafariViewControllerDelegate>

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

// Return the appropriate color for event distance based on type of event and how far it is from today.
- (UIColor *)getColorForDistanceFromEventDate:(NSDate *)eventDate withEventType:(NSString *)rawEventType;

// Return the appropriate color for event labels based on type of event.
- (UIColor *)getColorForCellLabelsBasedOnEventType:(NSString *)rawEventType;

// Return the appropriate color for event based on type.
- (UIColor *)getColorForEventTickerLbl:(NSString *)eventType;

// Compute the likely date for the previous event based on current event type (currently only Quarterly), previous event related date (e.g. quarter end related to the quarterly earnings), current event date and current event related date.
- (NSDate *)computePreviousEventDateWithCurrentEventType:(NSString *)currentType currentEventDate:(NSDate *)currentDate currentEventRelatedDate:(NSDate *)currentRelatedDate previousEventRelatedDate:(NSDate *)previousRelatedDate;

// Check if there is internet connectivity
- (BOOL) checkForInternetConnectivity;

// Show the busy message in the header.
- (void)showBusyMessage;

// Remove the busy message in the header to show appropriate header.
- (void)removeBusyMessage;

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
    
    // Set navigation bar header to title "Upcoming Events"
    NSDictionary *regularHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                    [UIColor blackColor], NSForegroundColorAttributeName,
                                    nil];
    [self.navigationController.navigationBar setTitleTextAttributes:regularHeaderAttributes];
    [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING MARKET EVENTS"];
    
    // Set font and size for searchbar text.
    [[UITextField appearanceWhenContainedInInstancesOfClasses:@[[UISearchBar class]]] setDefaultTextAttributes:@{ NSFontAttributeName: [UIFont fontWithName:@"Helvetica" size:14],}];
    
    // Change the color of the events search bar placeholder text and text entered
    // Set it to a light gray color
    [self.eventsSearchBar setBackgroundImage:[UIImage new]];
    UITextField *eventSearchBarInputFld = [self.eventsSearchBar valueForKey:@"_searchField"];
    [eventSearchBarInputFld setValue:[UIColor colorWithRed:160.0f/255.0f green:160.0f/255.0f blue:160.0f/255.0f alpha:1.0f] forKeyPath:@"_placeholderLabel.textColor"];
    eventSearchBarInputFld.textColor = [UIColor colorWithRed:160.0f/255.0f green:160.0f/255.0f blue:160.0f/255.0f alpha:1.0f];
    
    // Set search bar background color to a very light gray so that it stands out a little from the background.
    eventSearchBarInputFld.backgroundColor = [UIColor colorWithRed:225.0f/255.0f green:225.0f/255.0f blue:225.0f/255.0f alpha:1.0f];
    
    // Change the color of the Magnifying glass icon in the search bar to be a light gray text color
    UIImageView *magGlassIcon = (UIImageView *)eventSearchBarInputFld.leftView;
    magGlassIcon.image = [magGlassIcon.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    magGlassIcon.tintColor = [UIColor colorWithRed:160.0f/255.0f green:160.0f/255.0f blue:160.0f/255.0f alpha:1.0f];
    
    // Change the color of the Clear button in the search bar to be a light gray color
    UIButton *searchClearBtn = [eventSearchBarInputFld valueForKey:@"_clearButton"];
    [searchClearBtn setImage:[searchClearBtn.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    searchClearBtn.tintColor = [UIColor colorWithRed:160.0f/255.0f green:160.0f/255.0f blue:160.0f/255.0f alpha:1.0f];
    
    // Format the event type selector
    // Set Background color and tint to a very light almost white gray
    [self.eventTypeSelector setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
    [self.eventTypeSelector setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
    // Set text color of all unselected segments to a medium dark gray used in the event dates (R:113, G:113, B:113)
    [self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]} forState:UIControlStateNormal];
    // Set text color for the segment selected for the very first time which is Bold Black for ALL events type. Also set focus bar to draw focus to the search bar to the same color.
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
        NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                        [UIColor blackColor], NSForegroundColorAttributeName,
                                        nil];
        [self.eventTypeSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
    }
    
    // Format the main nav type selector
    // Set text color of all unselected segments to a medium dark gray used in the event dates (R:113, G:113, B:113)
    [self.mainNavSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]} forState:UIControlStateNormal];
    // Set text color for the segment selected for the very first time which is Black for ALL events type. Also set focus bar to draw focus to the search bar to the same color.
    if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
        NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                    [UIColor blackColor], NSForegroundColorAttributeName,
                                    nil];
        [self.mainNavSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
    }

    // Get a primary data controller that you will use later
    self.primaryDataController = [[FADataController alloc] init];
    
    // Ensure that the remote fetch spinner is not animating thus hidden
    if ([[self.primaryDataController getEventSyncStatus] isEqualToString:@"RefreshCheckDone"]) {
        [self removeBusyMessage];
    } else {
        [self showBusyMessage];
    }
    
    // TO DO: DEBUGGING: DELETE. Make one of the events confirmed to yesterday
    /*NSDate *today = [NSDate date];
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = -1;
    NSDate *yesterday = [aGregorianCalendar dateByAddingComponents:differenceDayComponents toDate:today options:0];
    [self.primaryDataController upsertEventWithDate:yesterday relatedDetails:@"Unknown" relatedDate:yesterday type:@"Quarterly Earnings" certainty:@"Confirmed" listedCompany:@"HSBC" estimatedEps:[NSNumber numberWithDouble:0.1] priorEndDate:[NSDate date] actualEpsPrior:[NSNumber numberWithDouble:0.2]];
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
        
        [self sendUserMessageCreatedNotificationWithMessage:@"No Connection. Limited functionality."];
    }
    
    // Set the Filter Specified flag to false, indicating that no search filter has been specified
    self.filterSpecified = NO;
    
    // Set the filter type to None_Specified, meaning no filter has been specified.
    self.filterType = [NSString stringWithFormat:@"None_Specified"];
    
    // Set Current Stock Price & Change String to "NA" which is the default value.
    self.currPriceAndChange = [NSString stringWithFormat:@"NA"];
    
    // Store name for Product Main Nav Option. Currently Products. Just change name here and in the UI element if one doesn't work out.
    self.mainNavProductOption = [NSString stringWithFormat:@"TIMELINE"];
    
    // Query all future events depending on the type selected in the selector, including today, as that is the default view first shown. Also factor in if the following nav is selected or not.
    // If All Events is selected.
    if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
        
        // Get the right future events depending on event type
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFutureEventsWithProductEventsOfVeryHighImpact];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFutureEarningsEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFutureEconEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFutureCryptoEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFutureProductEvents];
        }
    }
    // If following is selected in which case show the right following events
    if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
        // Show all following events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureEarningsEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureEconEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureCryptoEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame) {
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureProductEvents];
        }
    }
    // If the main nav Product Option is selected in which case show the product timeline
    if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
        // Show the product timeline. Currently showing no events.
        self.eventResultsController = [self.primaryDataController getNoEvents];
    }
    
    // This will remove extra separators from the bottom of the tableview which doesn't have any cells
    self.eventsListTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    // Create (now but get later, once it's created right at the start) the data Snapshot to use later.
    self.dataSnapShot = [[FASnapShot alloc] init];
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
        
        // If the filter type is Match_Companies_ForTimeline, meaning a filter of matching companies for getting their product timeline is specified
        if ([self.filterType isEqualToString:@"Match_Companies_ForTimeline"]) {
            id filteredCompaniesSection = [[self.filteredResultsController sections] objectAtIndex:section];
            numberOfRows = [filteredCompaniesSection numberOfObjects];
        }
    }
    
    // If not, show all events or following events based on navigation filter
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
    
    // Make the cell user interaction enabled in case it's been turned off for 52 week events.
    cell.userInteractionEnabled = YES;
    
    // Reset backgrnd and text colors for Ticker and news button to white and dark blackish respectively, in case it's been altered.
    cell.companyTicker.backgroundColor = [self.dataSnapShot getBrandBkgrndColorForCompany:cell.companyTicker.text];
    cell.companyTicker.textColor = [self.dataSnapShot getBrandTextColorForCompany:cell.companyTicker.text];
    cell.newsButon.backgroundColor = [self.dataSnapShot getBrandBkgrndColorForCompany:cell.companyTicker.text];
    [cell.newsButon setTitleColor:[self.dataSnapShot getBrandTextColorForCompany:cell.companyTicker.text] forState:UIControlStateNormal];
    
    // Show the event date in case it's been hidden for news.
    cell.eventDate.hidden = NO;
    
    // Reset color for Event description to dark text, in case it's been set to blue for a "Get Events" display.
    cell.eventDescription.textColor = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    
    // Hide the event impact label
    cell.eventImpact.hidden = YES;
    
    // Unhide the company ticker in case it was hidden during a product timeline view
    [[cell  companyTicker] setHidden:NO];
    
    // Hide the timeline label in case it was shown in the timeline view
    cell.timelineLbl.hidden = YES;
    
    // Reset color for timeline label, in case it's been set to dark color for current events.
    cell.timelineLbl.backgroundColor = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
    
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
        
        // If the filter type is Match_Companies_ForTimeline, meaning a filter of matching companies for getting their product timeline is specified
        if ([self.filterType isEqualToString:@"Match_Companies_ForTimeline"]) {
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
    if ([self.filterType isEqualToString:@"Match_Companies_NoEvents"]||[self.filterType isEqualToString:@"Match_Companies_ForTimeline"]) {
        
        // Show the company ticker associated with the event
        [[cell  companyTicker] setText:companyAtIndex.ticker];
        // Left align the ticker for visual consistency with this view
        [[cell  companyTicker] setTextAlignment:NSTextAlignmentLeft];
        
        // Set ticker colors to default black and white
        cell.companyTicker.backgroundColor = [UIColor whiteColor];
        cell.companyTicker.textColor = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
        
        // Set the company name associated with the event
        [[cell  companyName] setText:companyAtIndex.name];
        // Show the company Name as this information is needed to be displayed to the user when searching
        [[cell companyName] setHidden:NO];
        // Disable and hide the news button representing the event as this information is not needed when the user searches
        [[cell newsButon] setEnabled:NO];
        [[cell newsButon] setHidden:YES];
        
        // Check to see if the Events Main Nav is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
            // Show the "Get Events" text in the event display area.
            [[cell eventDescription] setText:@"GET EVENTS"];
            // Set color to a link blue to provide a visual cue to click
            cell.eventDescription.textColor = [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            // FOR BTC or ETHR or BCH$ or XRP, in case the user ever gets into this situation, set to NOT AVAILABLE.
            if (([cell.companyTicker.text caseInsensitiveCompare:@"BTC"] == NSOrderedSame)||([cell.companyTicker.text caseInsensitiveCompare:@"ETHR"] == NSOrderedSame)||([cell.companyTicker.text caseInsensitiveCompare:@"BCH$"] == NSOrderedSame)||([cell.companyTicker.text caseInsensitiveCompare:@"XRP"] == NSOrderedSame)) {
                [[cell eventDescription] setText:@"NOT AVAILABLE"];
                // Set color to a light gray.
                cell.eventDescription.textColor = [UIColor lightGrayColor];
            }
        }
        // Check to see if the Following Main Nav is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
            // Show the "Follow" text in the event display area.
            [[cell eventDescription] setText:@"NOT FOLLOWING"];
            // Set color to a light gray color to show not following
            //cell.eventDescription.textColor = [UIColor colorWithRed:205.0f/255.0f green:151.0f/255.0f blue:61.0f/255.0f alpha:1.0f];
            cell.eventDescription.textColor = [UIColor lightGrayColor];
        }
        // Check to see if the Product Main Nav is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
            // Show the "Show Timeline" text in the event display area.
            if ([self doesTimelineExistForTicker:companyAtIndex.ticker]) {
                [[cell eventDescription] setText:@"SHOW TIMELINE"];
                // Set color to a link blue to provide a visual cue to click
                cell.eventDescription.textColor = [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            } else {
                [[cell eventDescription] setText:@"TIMELINE NOT AVAILABLE"];
                // Set color to a light gray to provide a visual cue to click
                cell.eventDescription.textColor = [UIColor lightGrayColor];
            }
        }
        
        // Set the fetch state of the event cell to true which means either Get Events if Events main nav option is selected or Follow if the Following main nav is selected.
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
        
        // Make the cell inactive if it's of type 52 Week.
        // NOTE: In some places just 52 Week is used
        if ([eventAtIndex.type containsString:@"52 Week High"]||[eventAtIndex.type containsString:@"52 Week Low"]) {
            cell.userInteractionEnabled = NO;
        } else {
            cell.userInteractionEnabled = YES;
        }
        // Set the company ticker text and Add a tap gesture recognizer to the event ticker
        [[cell companyTicker] setText:[self formatTickerBasedOnEventType:eventAtIndex.listedCompany.ticker]];
        UITapGestureRecognizer *tickerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(processTypeIconTap:)];
        tickerTap.cancelsTouchesInView = YES;
        tickerTap.numberOfTapsRequired = 1;
        tickerTap.numberOfTouchesRequired = 1;
        [cell.companyTicker addGestureRecognizer:tickerTap];
        cell.companyTicker.tag = indexPath.row;
        
        // Enable, Show and Set News Button text color
        [[cell newsButon] setHidden:NO];
        cell.newsButon.backgroundColor = [self.dataSnapShot getBrandBkgrndColorForCompany:cell.companyTicker.text];
        [cell.newsButon setTitleColor:[self.dataSnapShot getBrandTextColorForCompany:cell.companyTicker.text] forState:UIControlStateNormal];
        [[cell newsButon] setEnabled:YES];
        cell.newsButon.tag = indexPath.row;
        // Also add the button press action
        [cell.newsButon addTarget:self action:@selector(newsButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        // Format the company ticker just like above
        cell.companyTicker.backgroundColor = [self.dataSnapShot getBrandBkgrndColorForCompany:cell.companyTicker.text];
        cell.companyTicker.textColor = [self.dataSnapShot getBrandTextColorForCompany:cell.companyTicker.text];
        
        // Hide the company Name as this information is not needed to be displayed to the user.
        [[cell companyName] setHidden:YES];
        // Set the company name associated with the event as this is needed in places like getting the earnings.
        [[cell  companyName] setText:eventAtIndex.listedCompany.name];
        // Center align the ticker for visual consistency with this view
        [[cell  companyTicker] setTextAlignment:NSTextAlignmentCenter];
        
        // If the product timeline view is selected, show timeline label
        // Check to see if the Product Main Nav is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
    
            // Format the ticker and news section with the correct brand colors. Looks hot!
            cell.companyTicker.backgroundColor = [self.dataSnapShot getBrandBkgrndColorForCompany:cell.companyTicker.text];
            cell.companyTicker.textColor = [self.dataSnapShot getBrandTextColorForCompany:cell.companyTicker.text];
            cell.newsButon.backgroundColor = [self.dataSnapShot getBrandBkgrndColorForCompany:cell.companyTicker.text];
            [cell.newsButon setTitleColor:[self.dataSnapShot getBrandTextColorForCompany:cell.companyTicker.text] forState:UIControlStateNormal];
            // Show the timeline label in case it was hidden
            cell.timelineLbl.hidden = NO;
            // Set color for timeline label based on event distance
            cell.timelineLbl.backgroundColor = [self getColorForDistanceFromEventDate:eventAtIndex.date];
        }
        
        // Set the fetch state of the event cell to false
        // TO DO: Should you really be holding logic state at the cell level or should there
        // be a unique identifier for each event ?
        cell.eventRemoteFetch = NO;
        
        // Show the event type. Format it for display. Currently map "Quarterly Earnings" to "Earnings", "Jan Fed Meeting" to "Fed Meeting", "Jan Jobs Report" to "Jobs Report" and so on.
        // TO DO LATER: !!!!!!!!!!IMPORTANT!!!!!!!!!!!!! If you are making a change here, reconcile with prepareForSegue in addition to the methods mentioned above.
        [[cell  eventDescription] setText:[self formatEventType:eventAtIndex.type]];
        [cell.eventDescription setTextColor:[self getColorForCellLabelsBasedOnEventType:eventAtIndex.type]];
        
        // Show the event date
        [[cell eventDate] setText:[self formatDateBasedOnEventType:eventAtIndex.type withDate:eventAtIndex.date withRelatedDetails:eventAtIndex.relatedDetails withStatus:eventAtIndex.certainty]];
        
        // Show the event distance
        [[cell eventDistance] setText:[self calculateDistanceFromEventDate:eventAtIndex.date withEventType:eventAtIndex.type]];
        
        // Set event distance to the appropriate color using a reddish scheme.
        [[cell eventDistance] setTextColor:[self getColorForDistanceFromEventDate:eventAtIndex.date withEventType:eventAtIndex.type]];
        
        // Show event impact label if the impact is high
        if ([self.dataSnapShot isEventHighImpact:eventAtIndex.type eventParent:eventAtIndex.listedCompany.ticker]) {
            [[cell eventImpact] setHidden:NO];
        }
        
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
        
        // Check to see if the Events Main Nav is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
            
            // FOR BTC or ETHR or BCH$ or XRP, don't fetch event from API as that's not needed
            if (!(([cell.companyTicker.text caseInsensitiveCompare:@"BTC"] == NSOrderedSame)||([cell.companyTicker.text caseInsensitiveCompare:@"ETHR"] == NSOrderedSame)||([cell.companyTicker.text caseInsensitiveCompare:@"BCH$"] == NSOrderedSame)||([cell.companyTicker.text caseInsensitiveCompare:@"XRP"] == NSOrderedSame))) {
                // Check for connectivity. If yes, process the fetch
                if ([self checkForInternetConnectivity]) {
                    
                    // Set the remote fetch spinner to animating to show a fetch is in progress
                    [self showBusyMessage];
                    
                    // Fetch the event for the related parent company in the background
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self getAllEventsFromApiInBackgroundWithTicker:(cell.companyTicker).text];
                    });
                    
                    // TRACKING EVENT: Get Earnings: User clicked the get earnings link for a company/ticker.
                    // TO DO: Disabling to not track development events. Enable before shipping.
                    [FBSDKAppEvents logEvent:@"Get Earnings"
                                  parameters:@{ @"Ticker" : (cell.companyTicker).text,
                                                @"Name" : (cell.companyName).text } ];
                }
                // If not, show error message
                else {
                    
                    [self sendUserMessageCreatedNotificationWithMessage:@"Unable to get data. Check Connection."];
                }
            }
        }
        // Check to see if the Following Main Nav is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
            
            // TO DO: In the future: trigger the follow action from here.
        }
        // Check to see if the Product Main Nav is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
            
            self.filteredResultsController = [self.primaryDataController getAllProductEventsForTicker:(cell.companyTicker).text since:[self computeDate4MosAgoFrom:[NSDate date]]];
            self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"PRODUCT TIMELINE"];
            // Reload messages table
            [self.eventsListTable reloadData];
            // Remove the search context that removes the keyboard
            [self.eventsSearchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
    }
    // If not then, fetch event details, if the event is of type quarterly earnings before segueing to the details view.
    // CURRENTLY simplified this to just go to details with a description. Commenting out a price fetch.
    else {
        
        // Get Details to pass off to detailed view.
        NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
        FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
        
        /*
        // New structure to fetch prices and segue to the detail view
        
        // Get Details to pass off to async processing of the price details fetch
        NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
        FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
        NSString *eventType = [self formatBackToEventType:selectedCell.eventDescription.text withAddedInfo:selectedCell.eventCertainty.text];
        // Get the ticker for the Quarterly Earnings
        NSString *eventTicker = selectedCell.companyTicker.text;
        
        // Pass off to async processing of the price details fetch
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
            
            // FOR BTC or ETHR or BCH$ or XRP, don't fetch price details yet as this is not supported.
            if (!(([eventTicker caseInsensitiveCompare:@"BTC"] == NSOrderedSame)||([eventTicker caseInsensitiveCompare:@"ETHR"] == NSOrderedSame)||([eventTicker caseInsensitiveCompare:@"BCH$"] == NSOrderedSame)||([eventTicker caseInsensitiveCompare:@"XRP"] == NSOrderedSame))) {
                // Check for connectivity. If yes, process the fetch
                if ([self checkForInternetConnectivity]) {
                    // Create a new FADataController so that this thread has its own MOC
                    FADataController *priceDetailsDataController = [[FADataController alloc] init];
                    self.currPriceAndChange = [priceDetailsDataController getPriceDetailsForEventOfType:eventType withTicker:eventTicker];
                }
                // If not, show error message
                else {
                    
                    //  Currently for simplicity, we are handling this in the event details controller as that's where the user is transitioning to on click.
                }
            }
            
            // Perform segue to the event detail view from the main thread as you can't do this in a background thread.
            dispatch_async(dispatch_get_main_queue(), ^{
                [self performSegueWithIdentifier:@"ShowEventDetails1" sender:selectedCell];
            });
        }); */
        
        [self performSegueWithIdentifier:@"ShowEventDetails1" sender:selectedCell];
    }
    
    // If search bar is in edit mode but the user has not entered any character to search (i.e. a search filter has not been applied), clear out of the search context when a user clicks on a row
    if ([self.eventsSearchBar isFirstResponder] && !(self.filterSpecified)) {
        
        [self.eventsSearchBar resignFirstResponder];
    }
}

#pragma mark - Following Related

// Make Sure the table row, if it should be, is editable
// TO DO: Before shipping v2.8: Do I really need this method ?
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    BOOL returnVal = YES;
    
    // Get the cell for the row on which the action is being exercised
    FAEventsTableViewCell *cell1 = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
    
    // If a filter has been specified, meaning it's in search mode, don't allow edit if it's in the "GET EVENTS" or "SHOW TIMELINE" mode.
    if (self.filterSpecified) {
        if ([self.filterType isEqualToString:@"Match_Companies_NoEvents"]||[self.filterType isEqualToString:@"Match_Companies_ForTimeline"]) {
            returnVal = NO;
        }
    }
    if (([cell1.eventDescription.text containsString:@"52 Week"])||([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame)) {
        returnVal = NO;
    }
    
    return returnVal;
}

// TO DO: Understand this method better. Basically need this to be able to use the custom UITableViewRowAction
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

// Add the right actions to each row in the table, either following or Set Reminder.
// Also add the Delete or Unfollow based on which main nav option is selected
- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Get the cell for the row on which the action is being exercised
    FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
    
    // Format event display name back to event type for logic in the destination
    NSString *cellEventType = [self formatBackToEventType:cell.eventDescription.text withAddedInfo:cell.eventCertainty.text];
    
    UITableViewRowAction *setReminderAction;
    
    // String to hold the action name
    NSString *actionName = nil;
    
    FADataController *unfollowDataController = [[FADataController alloc] init];
    
    // If the cell contains a followable event, add and process following of the ticker
    if ([self isEventFollowable:cellEventType]) {
        
        // For a price change event, create reminders for all followable events for that ticker thus indicating this ticker is being followed
        if ([cellEventType containsString:@"% up"]||[cellEventType containsString:@"% down"])
        {
            // Check to see if a reminder action has already been created for the quarterly earnings event for this ticker, which means this ticker is already being followed
            // TO DO: Hardcoding this for now to be quarterly earnings
            if ([self.primaryDataController doesReminderActionExistForEventWithTicker:cell.companyTicker.text eventType:@"Quarterly Earnings"])
            {
                actionName = [NSString stringWithFormat:@"Unfollow %@",cell.companyTicker.text];
                
                // Create the "Reimder Already Set" Action and handle it being exercised.
                setReminderAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:actionName handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
                    
                    // Delete the actions in the action store, that indicate following, for the particular ticker.
                    [unfollowDataController deleteFollowingEventActionsForTicker:cell.companyTicker.text];
                    
                    // Slide the row back over the action.
                    // TO DO: See if you can animate the slide back.
                    //[self.eventsListTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    
                    // Refresh Table
                    [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
                    
                    // Let the user know a reminder is already set for this ticker.
                    [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Unfollowed %@",cell.companyTicker.text]];
                    
                    // Delete any reminders for the ticker
                    [self deleteRemindersForTicker:cell.companyTicker.text];
                    
                    // TRACKING EVENT: Unset Follow: User clicked the "Set Reminder" button to create a reminder.
                    // TO DO: Disabling to not track development events. Enable before shipping.
                    [FBSDKAppEvents logEvent:@"Unset Follow"
                                  parameters:@{ @"Ticker" : cell.companyTicker.text,
                                                @"Event Type" : cellEventType,
                                                @"Event Certainty" : @"Confirmed" } ];
                }];
                
                // Format the Action UI to be the correct color and everything
                setReminderAction.backgroundColor = [UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f];
            }
            else
            // If not create the follow action
            {
                actionName = [NSString stringWithFormat:@"Follow %@",cell.companyTicker.text];
                
                setReminderAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:actionName handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
                    
                    // Get the cell for the row on which the action is being exercised
                    FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
                    
                    // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
                    // TO DO: Decide if you want to close the slid out action, before the user has provided
                    // access. Currently it's weird where the action closes and then the access popup is shown.
                    [self requestAccessToUserEventStoreAndProcessReminderFromCell:cell];
                    
                    // Slide the row back over the action.
                    // TO DO: See if you can animate the slide back.
                    [self.eventsListTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    
                    // Let the user know a reminder is already set for this ticker.
                    [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Following %@",cell.companyTicker.text]];
                    
                    // TRACKING EVENT: Set Follow: User clicked the "Set Reminder" button to create a reminder.
                    // TO DO: Disabling to not track development events. Enable before shipping.
                    [FBSDKAppEvents logEvent:@"Set Follow"
                                  parameters:@{ @"Ticker" : cell.companyTicker.text,
                                                @"Event Type" : cellEventType,
                                                @"Event Certainty" : @"Confirmed" } ];
                }];
                
                // Format the Action UI to be the correct color and everything
                setReminderAction.backgroundColor = [UIColor blackColor];
            }
        }
        // For quarterly earnings or product events, create a reminder which indicates that this ticker is being followed
        else {
            
            // Check to see if a reminder action has already been created for the event represented by the cell.
            // If yes, show a appropriately formatted status action, in this case that you are following the ticker.
            if ([self.primaryDataController doesReminderActionExistForEventWithTicker:cell.companyTicker.text eventType:cellEventType])
            {
                actionName = [NSString stringWithFormat:@"Unfollow %@",cell.companyTicker.text];
                
                // Create the "Reimder Already Set" Action and handle it being exercised.
                setReminderAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:actionName handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
                    
                    // Delete the actions in the action store, that indicate following, for the particular ticker.
                    [unfollowDataController deleteFollowingEventActionsForTicker:cell.companyTicker.text];
                    
                    // Slide the row back over the action.
                    // TO DO: See if you can animate the slide back.
                    //[self.eventsListTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    
                    // Refresh Table
                    [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
                    
                    // Let the user know a reminder is already set for this ticker.
                    [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Unfollowed %@",cell.companyTicker.text]];
                    
                    // Delete any reminders for the ticker
                    [self deleteRemindersForTicker:cell.companyTicker.text];
                    
                    // TRACKING EVENT: Unset Follow: User clicked the "Set Reminder" button to create a reminder.
                    // TO DO: Disabling to not track development events. Enable before shipping.
                    [FBSDKAppEvents logEvent:@"Unset Follow"
                                  parameters:@{ @"Ticker" : cell.companyTicker.text,
                                                @"Event Type" : cellEventType,
                                                @"Event Certainty" : cell.eventCertainty.text } ];
                }];
                
                // Format the Action UI to be the correct color and everything
                setReminderAction.backgroundColor = [UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f];
            }
            else
            // If not create the follow action
            {
                actionName = [NSString stringWithFormat:@"Follow %@",cell.companyTicker.text];
                
                setReminderAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:actionName handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
                    
                    // Get the cell for the row on which the action is being exercised
                    FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
                    
                    // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
                    // TO DO: Decide if you want to close the slid out action, before the user has provided
                    // access. Currently it's weird where the action closes and then the access popup is shown.
                    [self requestAccessToUserEventStoreAndProcessReminderFromCell:cell];
                    
                    // Slide the row back over the action.
                    // TO DO: See if you can animate the slide back.
                    [self.eventsListTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    
                    // Let the user know a reminder is already set for this ticker.
                    [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Following %@",cell.companyTicker.text]];
                    
                    // TRACKING EVENT: Set Follow: User clicked the "Set Reminder" button to create a reminder.
                    // TO DO: Disabling to not track development events. Enable before shipping.
                    [FBSDKAppEvents logEvent:@"Set Follow"
                                  parameters:@{ @"Ticker" : cell.companyTicker.text,
                                                @"Event Type" : cellEventType,
                                                @"Event Certainty" : cell.eventCertainty.text } ];
                }];
                
                // Format the Action UI to be the correct color and everything
                setReminderAction.backgroundColor = [UIColor blackColor];
            }
        }
    }
    ///////// Else, for a non followable event (currently econ event), put a Set Reminder button, as we are not supporting following these yet. Update: Making Econ events followable as well, where you can follow a type of econ event like "Jobs Report" and we'll add all instances of Jobs Reports to your reminders/following list.
    else {
        // Check to see if a reminder action has already been created for the event represented by the cell.
        // If yes, show a appropriately formatted status action.
        if ([self.primaryDataController doesReminderActionExistForEventWithTicker:[self.primaryDataController getTickerForName:cell.companyName.text] eventType:cellEventType])
        {
            // Create the "Reimder Already Set" Action and handle it being exercised.
            setReminderAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Unfollow" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
                
                // Delete the actions in the action store, that indicate following, for that econ event type.
                [unfollowDataController deleteFollowingEventActionsForEconEvent:cellEventType];
                
                // Slide the row back over the action.
                // TO DO: See if you can animate the slide back.
                //[self.eventsListTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];

                // Refresh Table
                [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
                
                // Let the user know a reminder is already set for this ticker.
                [self sendUserMessageCreatedNotificationWithMessage:@"Unfollowed event"];
                
                // Delete reminders for this event type e.g. containing Fed Meeting not Jan Fed Meeting
                [self deleteRemindersForEconEventType:cell.eventDescription.text];
                
                // TRACKING EVENT: Unset Reminder: User clicked the "Set Reminder" button to create a reminder.
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Unset Follow"
                              parameters:@{ @"Ticker" : cell.companyTicker.text,
                                            @"Event Type" : cellEventType,
                                            @"Event Certainty" : cell.eventCertainty.text } ];
            }];
            
            // Format the Action UI to be the correct color and everything
            setReminderAction.backgroundColor = [UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f];
        }
        // If not, create the follow action.
        else
        {
            // Create the "Follow" Action and handle it being exercised, which includes following all economic events of this type.
            setReminderAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Follow" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
                
                // Get the cell for the row on which the action is being exercised
                FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
                
                // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
                // TO DO: Decide if you want to close the slid out action, before the user has provided
                // access. Currently it's weird where the action closes and then the access popup is shown.
                [self requestAccessToUserEventStoreAndProcessReminderFromCell:cell];
                
                // Slide the row back over the action.
                // TO DO: See if you can animate the slide back.
                [self.eventsListTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                
                // TRACKING EVENT: Create Reminder: User clicked the "Set Reminder" button to create a reminder.
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Set Follow"
                              parameters:@{ @"Ticker" : cell.companyTicker.text,
                                            @"Event Type" : cellEventType,
                                            @"Event Certainty" : cell.eventCertainty.text } ];
            }];
            
            // Format the Action UI to be the correct color and everything
            setReminderAction.backgroundColor = [UIColor blackColor];
        }
    }
    
    return @[setReminderAction];
}

#pragma mark - Following Reminder Creation

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
            [self sendUserMessageCreatedNotificationWithMessage:@"Enable Reminders (Settings>Knotifi)."];
            break;
        }
            
            // If the user has already provided access, create the reminder.
        case EKAuthorizationStatusAuthorized: {
            
            // Create a new Data Controller so that this thread has it's own MOC
            FADataController *accessDataController = [[FADataController alloc] init];
            [self processReminderForEventInCell:eventCell withDataController:accessDataController];
            // If the event is a followable event, create all reminders for all followable events for this ticker. Does not do anything for econ events. Make sure that you are checking for formatted name i.e. Quarterly Earnings and not display name i.e. Earnings
            if ([self isEventFollowable:[self formatBackToEventType:eventCell.eventDescription.text withAddedInfo:eventCell.eventCertainty.text]]) {
                [self createAllRemindersForFollowedTicker:eventCell.companyTicker.text withDataController:accessDataController];
            }
            // If it's an econ event, create all reminders for all econ events of this type
            else {
                [self createAllRemindersForEconEventType:eventCell.eventDescription.text withDataController:accessDataController];
            }
            
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
                                                            
                                                            // Create a new Data Controller so that this thread has it's own MOC
                                                            FADataController *afterAccessDataController = [[FADataController alloc] init];
                                                            [weakPtrToSelf processReminderForEventInCell:eventCell withDataController:afterAccessDataController];
                                                            // If the event is a followable event, create all reminders for all followable events for this ticker. Does not do anything for econ events.
                                                            if ([weakPtrToSelf isEventFollowable:eventCell.eventDescription.text]) {
                                                                [weakPtrToSelf createAllRemindersForFollowedTicker:eventCell.companyTicker.text withDataController:afterAccessDataController];
                                                            }
                                                            // If it's an econ event, create all reminders for all econ events of this type
                                                            else {
                                                                [weakPtrToSelf createAllRemindersForEconEventType:eventCell.eventDescription.text withDataController:afterAccessDataController];
                                                            }
                                                        } else {
                                                            [weakPtrToSelf sendUserMessageCreatedNotificationWithMessage:@"Enable Reminders (Settings>Knotifi)."];
                                                        }
                                                    });
                                                }];
            break;
        }
    }
}

// Process the "Remind Me" action for the event represented by the cell on which the action was taken. If the event is confirmed, create the reminder immediately and make an appropriate entry in the Action data store. If it's estimated, then don't create the reminder, only make an appropriate entry in the action data store for later processing.
- (void)processReminderForEventInCell:(FAEventsTableViewCell *)eventCell withDataController:(FADataController *)appropriateDataController {
    
    // Format event display name back to event type for logic in the destination
    NSString *cellEventType = [self formatBackToEventType:eventCell.eventDescription.text withAddedInfo:eventCell.eventCertainty.text];
    NSString *cellCompanyTicker = eventCell.companyTicker.text;
    NSString *cellEventDateText = eventCell.eventDate.text;
    NSString *cellEventCertainty = eventCell.eventCertainty.text;
    
    // Check to see if the event is of type Earnings, Product Event or Economic event.
    // Earnings
    if ([cellEventType isEqualToString:@"Quarterly Earnings"]) {
        
        // Check to see if the event represented by the cell is estimated or confirmed ?
        // If confirmed create and save to action data store
        if ([cellEventCertainty isEqualToString:@"Confirmed"]) {
            
            // Create the reminder and show user the appropriate message
            BOOL success = [self createReminderForEventOfType:cellEventType withTicker:cellCompanyTicker dateText:cellEventDateText andDataController:appropriateDataController];
            if (success) {
                // Add action to the action data store with status created
                [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:cellCompanyTicker eventType:cellEventType];
                [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Following %@",cellCompanyTicker]];
            } else {
                [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Unable to follow %@",cellCompanyTicker]];
            }
        }
        // If estimated add to action data store for later processing
        else if ([cellEventCertainty isEqualToString:@"Estimated"]) {
            
            // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:cellCompanyTicker eventType:cellEventType];
            [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Following %@",cellCompanyTicker]];
        }
    }
    // Economic Event
    if ([cellEventType containsString:@"Fed Meeting"]||[cellEventType containsString:@"Jobs Report"]||[cellEventType containsString:@"Consumer Confidence"]||[cellEventType containsString:@"GDP Release"]) {
        
        // Get the fully formatted ticker for ECON events i.e. ECON_FOMC
        cellCompanyTicker = [appropriateDataController getTickerForName:eventCell.companyName.text];
        
        // Create the reminder and show user the appropriate message
        BOOL success = [self createReminderForEventOfType:cellEventType withTicker:cellCompanyTicker dateText:cellEventDateText andDataController:appropriateDataController];
        if (success) {
            [self sendUserMessageCreatedNotificationWithMessage:@"Following event"];
            // Add action to the action data store with status created
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:cellCompanyTicker eventType:cellEventType];
        } else {
            [self sendUserMessageCreatedNotificationWithMessage:@"Unable to create a reminder."];
        }
    }
    // Product Event.
    if ([cellEventType containsString:@"Launch"]||[cellEventType containsString:@"Conference"]) {
        
        // Check to see if the event represented by the cell is estimated or confirmed ?
        // If confirmed create and save to action data store
        if ([cellEventCertainty isEqualToString:@"Confirmed"]) {
            
            // Create the reminder and show user the appropriate message
            BOOL success = [self createReminderForEventOfType:cellEventType withTicker:cellCompanyTicker dateText:cellEventDateText andDataController:appropriateDataController];
            if (success) {
                // Add action to the action data store with status created
                [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:cellCompanyTicker eventType:cellEventType];
                [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Following %@",cellCompanyTicker]];
            } else {
                [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Unable to follow %@",cellCompanyTicker]];
            }
        }
        // If estimated add to action data store for later processing
        else if ([cellEventCertainty isEqualToString:@"Estimated"]) {
            
            // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:cellCompanyTicker eventType:cellEventType];
            [self sendUserMessageCreatedNotificationWithMessage:[NSString stringWithFormat:@"Following %@",cellCompanyTicker]];
        }
    }
    // Price Change event. Do nothing currently
    if ([cellEventType containsString:@"% up"]||[cellEventType containsString:@"% down"])
    {
        
    }
}

// Create reminders for all followable events (currently earnings and product events) for a given ticker, if it's not already been created
- (void)createAllRemindersForFollowedTicker:(NSString *)ticker withDataController:(FADataController *)appropriateDataController {
    
    NSString *cellEventType = nil;
    NSString *cellEventDateText = nil;
    NSString *cellEventCertainty = nil;
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all events for a ticker
    NSArray *allEvents = [appropriateDataController getAllEventsForParentEventTicker:ticker];
    for (Event *fetchedEvent in allEvents) {
        
        // Get event details
        cellEventType = fetchedEvent.type;
        cellEventDateText = [self formatDateBasedOnEventType:fetchedEvent.type withDate:fetchedEvent.date withRelatedDetails:fetchedEvent.relatedDetails withStatus:fetchedEvent.certainty];
        cellEventCertainty = fetchedEvent.certainty;
        
        // If the event is a followable event, create a reminder for it
        if ([self isEventFollowable:cellEventType]) {
            
            // For a price change event create a "PriceChange" action, which is only used for determining if this event ticker is being followed.
            if ([cellEventType containsString:@"% up"]||[cellEventType containsString:@"% down"])
            {
                [appropriateDataController insertActionOfType:@"PriceChange" status:@"Queued" eventTicker:ticker eventType:cellEventType];
            }
            // For quarterly earnings or product events, create a reminder which indicates that this ticker is being followed
            else {
                
                // Check to see if a reminder action has already been created for this event.
                // If yes, do nothing.
                if ([appropriateDataController doesReminderActionExistForEventWithTicker:ticker eventType:cellEventType])
                {
                }
                else
                // If not create the reminder or queue it up depending on the confirmed status
                {
                    // Check to see if the event was in the past. If not create a reminder for it
                    if (fetchedEvent.date >= todaysDate) {
                        
                        // Check to see if the event is estimated or confirmed ?
                        // If confirmed create and save to action data store
                        if ([cellEventCertainty isEqualToString:@"Confirmed"]) {
                            
                            // Create the reminder and show user the appropriate message
                            BOOL success = [self createReminderForEventOfType:cellEventType withTicker:ticker dateText:cellEventDateText andDataController:appropriateDataController];
                            if (success) {
                                // Add action to the action data store with status created
                                [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:ticker eventType:cellEventType];
                            } else {
                                NSLog(@"ERROR: Unable to create the following reminder for confirmed event %@ for ticker %@",cellEventType,ticker);
                            }
                        }
                        // If estimated add to action data store for later processing
                        else if ([cellEventCertainty isEqualToString:@"Estimated"]) {
                            
                            // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
                            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:ticker eventType:cellEventType];
                        }
                    }
                }
            }
        }
    }
}

// Create reminders for all economic events of a certain type (e.g. Jobs Report) for a given ticker, if it's not already been created
- (void)createAllRemindersForEconEventType:(NSString *)type withDataController:(FADataController *)appropriateDataController {
    
    NSString *cellEventType = nil;
    NSString *cellEventDateText = nil;
    NSString *cellEventCertainty = nil;
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all events for a ticker
    NSArray *allEvents = [appropriateDataController getAllEconEventsOfType:type];
    for (Event *fetchedEvent in allEvents) {
        
        // Get event details
        cellEventType = fetchedEvent.type;
        cellEventDateText = [self formatDateBasedOnEventType:fetchedEvent.type withDate:fetchedEvent.date withRelatedDetails:fetchedEvent.relatedDetails withStatus:fetchedEvent.certainty];
        cellEventCertainty = fetchedEvent.certainty;
        
        // Check to see if a reminder action has already been created for this event.
        // If yes, do nothing.
        if ([appropriateDataController doesReminderActionExistForSpecificEvent:cellEventType])
        {
        }
        // If not create the reminder or queue it up depending on the confirmed status
        else
        {
            // Check to see if the event was in the past. If not create a reminder for it
            if (fetchedEvent.date >= todaysDate) {
                    
                // Create the reminder and show user the appropriate message
                BOOL success = [self createReminderForEventOfType:cellEventType withTicker:fetchedEvent.listedCompany.ticker dateText:cellEventDateText andDataController:appropriateDataController];
                if (success) {
                    // Add action to the action data store with status created
                    [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:fetchedEvent.listedCompany.ticker eventType:cellEventType];
                } else {
                    NSLog(@"ERROR: Unable to create the following reminder for confirmed event %@ for ticker %@",cellEventType,fetchedEvent.listedCompany.ticker);
                }
            }
        }
    }
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

// Delete reminders that contain a certain string in the title
- (void)deleteRemindersForTicker:(NSString *)ticker {
    
    // Get the default calendar where Knotifi events have been created
    EKCalendar *knotifiRemindersCalendar = [self.userEventStore defaultCalendarForNewReminders];
    
     // Get all events
    [self.userEventStore fetchRemindersMatchingPredicate:[self.userEventStore predicateForRemindersInCalendars:[NSArray arrayWithObject:knotifiRemindersCalendar]] completion:^(NSArray *eventReminders) {
        NSError *error = nil;
        
        // Get all future product events with the given ticker
        FADataController *tickerDataController = [[FADataController alloc] init];
        NSArray *tickerFutureProductEvents = [tickerDataController getAllFutureProductEventsForTicker:ticker];
        
        for (EKReminder *eventReminder in eventReminders) {
            
            // See if a matching earnings event Knotifi reminder is found, if so add to batch to be deleted
            if ([eventReminder.title containsString:[NSString stringWithFormat:@"Knotifi ▶︎ %@",ticker]]) {
                [self.userEventStore removeReminder:eventReminder commit:NO error:&error];
            }
            
            // See if a matching product event for that ticker is found, if so add to batch to be deleted
            for(Event *listEvent in tickerFutureProductEvents) {
                if([eventReminder.title containsString:listEvent.type]) {
                    [self.userEventStore removeReminder:eventReminder commit:NO error:&error];
                }
            }
        }
        
        // Commit the changes
        [self.userEventStore commit:&error];
    }];
}

// Delete reminders for a given econ event type e.g. Fed Meeting not Jan Fed Meeting
- (void)deleteRemindersForEconEventType:(NSString *)eventType {
    
    // Get the default calendar where Knotifi events have been created
    EKCalendar *knotifiRemindersCalendar = [self.userEventStore defaultCalendarForNewReminders];
    
    // Get all events
    [self.userEventStore fetchRemindersMatchingPredicate:[self.userEventStore predicateForRemindersInCalendars:[NSArray arrayWithObject:knotifiRemindersCalendar]] completion:^(NSArray *eventReminders) {
        NSError *error = nil;
    
        for (EKReminder *eventReminder in eventReminders) {
            
            // See if a matching earnings event Knotifi reminder is found, if so add to batch to be deleted
            if ([eventReminder.title containsString:@"Knotifi ▶︎"]&&[eventReminder.title containsString:eventType]) {
                [self.userEventStore removeReminder:eventReminder commit:NO error:&error];
            }
        }
        
        // Commit the changes
        [self.userEventStore commit:&error];
    }];
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
    
    [self removeBusyMessage];
    
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
    
    // TRACKING EVENT: Explicitly track Price fetch events
    // TO DO: Disabling to not track development events. Enable before shipping.
    [FBSDKAppEvents logEvent:@"Price Fetched"
                  parameters:@{ @"Event Type" : @"Daily Price" } ];
    
    // Get historical prices if needed
    if(fetchHistory) {
        
        // See which one is before in time, the ytd date or 30 days ago date and set from date to that.
        if ([(eventForPricesFetch.previous1Date) timeIntervalSinceDate:(eventForPricesFetch.previous1RelatedDate)] > 0) {
            
            [specificDataController getStockPricesFromApiForTicker:ticker companyEventType:type fromDateInclusive:eventForPricesFetch.previous1RelatedDate toDateInclusive:eventForPricesFetch.currentDate];
            
            // TRACKING EVENT: Explicitly track Price fetch events
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"Price Fetched"
                          parameters:@{ @"Event Type" : @"Price History" } ];
        } else {
            
            [specificDataController getStockPricesFromApiForTicker:ticker companyEventType:type fromDateInclusive:eventForPricesFetch.previous1Date toDateInclusive:eventForPricesFetch.currentDate];
            
            // TRACKING EVENT: Explicitly track Price fetch events
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"Price Fetched"
                          parameters:@{ @"Event Type" : @"Price History" } ];
        }
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
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Home"];
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
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"All"];
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
            }
            // Check to see if Product Main Option is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
                // Basically find Companies so that user can select one to show the product timeline
                self.filteredResultsController = [self.primaryDataController searchCompaniesFor:searchBar.text];
                // Set the filter type to Match_Companies_ForTimeline, meaning a filter matching companies with no existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_ForTimeline"];
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Earnings" events types are selected. Search on "ticker" or "name" fields for the listed Company for earnings events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
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
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"Earnings"];
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
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Economic" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Economic"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"Economic"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Crypto" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
    
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Crypto"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"Crypto"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Product" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all product events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Product"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
                
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Price" events type is selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all price events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Price"] == NSOrderedSame) {
            
            // Double check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"Price"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
    }
    
    // TRACKING EVENT: Search Button Clicked: User clicked the search button to search for a company or ticker.
    // TO DO: Disabling to not track development events. Enable before shipping.
    [FBSDKAppEvents logEvent:@"Search Button Clicked"
                  parameters:@{ @"Search String" : searchBar.text } ];
    
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
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Home"];
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
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"All"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
                
                // If no events are found, that means search for the name and ticker fields on the companies data store.
                if ([self.filteredResultsController fetchedObjects].count == 0) {
                    
                    self.filteredResultsController = [self.primaryDataController searchCompaniesFor:searchBar.text];
                    
                    // Set the filter type to Match_Companies_NoEvents, meaning a filter matching companies with no existing events
                    // has been specified.
                    self.filterType = [NSString stringWithFormat:@"Match_Companies_NoEvents"];
                }
            }
            // Check to see if Product Main Option is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
                // Basically find Companies so that user can select one to show the product timeline
                self.filteredResultsController = [self.primaryDataController searchCompaniesFor:searchBar.text];
                // Set the filter type to Match_Companies_ForTimeline, meaning a filter matching companies with no existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_ForTimeline"];
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Earnings" events types are selected. Search on "ticker" or "name" fields for the listed Company for earnings events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
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
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"Earnings"];
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
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Economic" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Economic"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"Economic"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
                
                // If no events are found, set the appropriate header message.
                if ([self.filteredResultsController fetchedObjects].count == 0) {
                    
                    // Set navigation bar header to an attention orange color
                    NSDictionary *attentionHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                               [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                                               [UIColor colorWithRed:205.0f/255.0f green:151.0f/255.0f blue:61.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                                               nil];
                    [self.navigationController.navigationBar setTitleTextAttributes:attentionHeaderAttributes];
                    [self.navigationController.navigationBar.topItem setTitle:@"No matching events being followed"];
                }
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Crypto" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all economic events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Crypto"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"Crypto"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
                
                // If no events are found, set the appropriate header message.
                if ([self.filteredResultsController fetchedObjects].count == 0) {
                    
                    // Set navigation bar header to an attention orange color
                    NSDictionary *attentionHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                               [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                                               [UIColor colorWithRed:205.0f/255.0f green:151.0f/255.0f blue:61.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                                               nil];
                    [self.navigationController.navigationBar setTitleTextAttributes:attentionHeaderAttributes];
                    [self.navigationController.navigationBar.topItem setTitle:@"No matching events being followed"];
                }
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }

        // Check to see if "Product" events types are selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all product events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchEventsFor:searchBar.text eventDisplayType:@"Product"];
                // Set the filter type to Match_Companies_Events, meaning a filter matching companies with existing events
                // has been specified.
                self.filterType = [NSString stringWithFormat:@"Match_Companies_Events"];
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
        
        // Check to see if "Price" events type is selected. Search on "ticker" or "name" fields for the listed Company or the "type" field on the event for all price events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Price"] == NSOrderedSame) {
            
            // Double check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Search the ticker and name fields on the company related to the events and the type of event in the data store, for the search text entered
                self.filteredResultsController = [self.primaryDataController searchFollowingEventsFor:searchBar.text eventDisplayType:@"Price"];
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
            }
            
            // Set the Filter Specified flag to true, indicating that a search filter has been specified
            self.filterSpecified = YES;
            
            // Reload messages table
            [self.eventsListTable reloadData];
        }
    }
    // If not valid
    else {
        
        // Check to see if "All" events types are selected. In this case query all events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFutureEventsWithProductEventsOfVeryHighImpact];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFollowingFutureEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            // Check to see if Product Main Option is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
                // Query no events, as that is the default view
                self.eventResultsController = [self.primaryDataController getNoEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
                
                // Set correct header text
                [self.navigationController.navigationBar.topItem setTitle:@"See Product Timeline"];
            }
            
            // Reload messages table
            [self.eventsListTable reloadData];
            
            // TO DO: In case you want to clear the search context
            [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
        
        // Check to see if "Earnings" events types are selected. In this case query all earnings
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFutureEarningsEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFollowingFutureEarningsEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            
            // Reload messages table
            [self.eventsListTable reloadData];
            
            // TO DO: In case you want to clear the search context
            [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
        
        // Check to see if "Economic" events types are selected. In this case query all economic events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFutureEconEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFollowingFutureEconEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            
            [self removeBusyMessage];
            
            // Reload messages table
            [self.eventsListTable reloadData];
            
            // TO DO: In case you want to clear the search context
            [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
        
        // Check to see if "Crypto" events types are selected. In this case query all crypto events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFutureCryptoEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFollowingFutureCryptoEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            
            [self removeBusyMessage];
            
            // Reload messages table
            [self.eventsListTable reloadData];
            
            // TO DO: In case you want to clear the search context
            [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
        
        // Check to see if "News" event type is selected.
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame) {
            
            // Check to see if the Events Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
                // Query all future events, including today, as that is the default view
                self.eventResultsController = [self.primaryDataController getAllFutureProductEvents];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            
            // Reload messages table
            [self.eventsListTable reloadData];
            
            // TO DO: In case you want to clear the search context
            [searchBar performSelector: @selector(resignFirstResponder) withObject: nil afterDelay: 0.1];
        }
        
        // Check to see if "Price" events type is selected.
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Price"] == NSOrderedSame) {
            
            // Check to see if the Following Main Nav is selected
            if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
                
                self.eventResultsController = [self.primaryDataController getAllPriceChangeEventsForFollowedStocks];
                
                // Set the Filter Specified flag to false, indicating that no search filter has been specified
                self.filterSpecified = NO;
                
                // Set the filter type to None_Specified i.e. no filter is specified
                self.filterType = [NSString stringWithFormat:@"None_Specified"];
            }
            
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
        [FBSDKAppEvents logEvent:@"Search Initiated"];
        
        // If the newer companies data is still being synced, give the user a warning message
        if (![[self.primaryDataController getCompanySyncStatus] isEqualToString:@"FullSyncDone"]) {
            
            [self sendUserMessageCreatedNotificationWithMessage:@"Fetching new tickers."];
        }
    }
    // If not, show error message,
    else {
        
        [self sendUserMessageCreatedNotificationWithMessage:@"No Connection. Limited functionality."];
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
    
    // Reset the navigation bar header text color to black
    NSDictionary *regularHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                               [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                               [UIColor blackColor], NSForegroundColorAttributeName,
                                               nil];
    [self.navigationController.navigationBar setTitleTextAttributes:regularHeaderAttributes];
    
    // Change formatting of the selected option to indicate selection and filter the table to show the correct events of that type. Also set the color of the focus bar to the same color as the selected option.
    
    // All Event Types - Color Black
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
        NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                        [UIColor blackColor], NSForegroundColorAttributeName,
                                        nil];
        [self.eventTypeSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
        // Old way is just set color
        //[self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor blackColor]} forState:UIControlStateSelected];
        
        // Clear out the search context
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
        
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"COMPANY/TICKER/EVENT";
        
        // Query all future events or future following events, including today.
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING MARKET EVENTS"];
            self.eventResultsController = [self.primaryDataController getAllFutureEventsWithProductEventsOfVeryHighImpact];
            [self.eventsListTable reloadData];
        }
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"ALL FOLLOWED EVENTS"];
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureEvents];
            [self.eventsListTable reloadData];
        }
        // If Product Main Option is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"See Product Timeline"];
            // Set correct search bar placeholder text
            self.eventsSearchBar.placeholder = @"Company/Ticker/Cryptocurrency";
            // Get No Events as the default view for the product main option is empty
            self.eventResultsController = [self.primaryDataController getNoEvents];
            [self.eventsListTable reloadData];
        }
        
        // TRACKING EVENT: Event Type Selected: User selected All event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"All" } ];
    }
    // Earnings - Black
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
        
        // Making size smaller to fit iphone SE
        NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont boldSystemFontOfSize:13], NSFontAttributeName,
                                        [UIColor blackColor], NSForegroundColorAttributeName,
                                        nil];
        [self.eventTypeSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
        // Old way is just set color
        //[self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:104.0f/255.0f green:202.0f/255.0f blue:94.0f/255.0f alpha:1.0f]} forState:UIControlStateSelected];
        
        // Clear out the search context
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
        
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"COMPANY/TICKER";
        
        // Query all future earnings events or following future events, including today.
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING EARNINGS"];
            self.eventResultsController = [self.primaryDataController getAllFutureEarningsEvents];
            [self.eventsListTable reloadData];
        }
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"FOLLOWED EARNINGS"];
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureEarningsEvents];
            [self.eventsListTable reloadData];
        }
        
        // TRACKING EVENT: Event Type Selected: User selected Earnings event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Earnings" } ];
    }
    // Economic - Black
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
        // Black
        //[self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f]} forState:UIControlStateSelected];
        NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                        [UIColor blackColor], NSForegroundColorAttributeName,
                                        nil];
        [self.eventTypeSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
        // Old way is just set color
        // Light purple
        //[self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f]} forState:UIControlStateSelected];
        
        // Clear out the search context
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
        
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"EVENT";
        
        // Query all future economic events or following economic events, including today.
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING ECON EVENTS"];
            self.eventResultsController = [self.primaryDataController getAllFutureEconEvents];
            [self.eventsListTable reloadData];
        }
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"FOLLOWED ECON EVENTS"];
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureEconEvents];
            [self.eventsListTable reloadData];
        }
        
        // TRACKING EVENT: Event Type Selected: User selected Economic event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Economic" } ];
    }
    // Crypto - Black 
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
        
        NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                        [UIColor blackColor], NSForegroundColorAttributeName,
                                        nil];
        [self.eventTypeSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
        
        // Clear out the search context
        [self.eventsSearchBar setText:@""];
        [self searchBar:self.eventsSearchBar textDidChange:@""];
        
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"TICKER/NAME/EVENT";
        
        // Query all future economic events or following economic events, including today.
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING CRYPTO EVENTS"];
            self.eventResultsController = [self.primaryDataController getAllFutureCryptoEvents];
            [self.eventsListTable reloadData];
        }
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"FOLLOWED CRYPTO EVENTS"];
            self.eventResultsController = [self.primaryDataController getAllFollowingFutureCryptoEvents];
            [self.eventsListTable reloadData];
        }
        
        // TRACKING EVENT: Event Type Selected: User selected Crypto event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Crypto" } ];
    }
    
    // NEWS (Prod) - Black
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame) {
        
        // Black
        NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                        [UIColor blackColor], NSForegroundColorAttributeName,
                                        nil];
        
        [self.eventTypeSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
        
        // Query all future product events, including today.
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
            
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING PRODUCT EVENTS"];
            // Clear out the search context
            [self.eventsSearchBar setText:@""];
            [self searchBar:self.eventsSearchBar textDidChange:@""];
            // Set correct search bar placeholder text
            self.eventsSearchBar.placeholder = @"COMPANY/TICKER/EVENT";
            
            self.eventResultsController = [self.primaryDataController getAllFutureProductEvents];
            [self.eventsListTable reloadData];
            
            // Refresh all product events asynchronously
            // Don't need to do this anymore as we are syncing on startup every 6 hours.
            /*dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
                // Create a new FADataController so that this thread has its own MOC
                FADataController *newsDataController = [[FADataController alloc] init];
                [newsDataController syncProductEventsWrapper];
            });*/
            
        }
        
        // TRACKING EVENT: Event Type Selected: User selected Product event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Prod" } ];
    }
    
    // PRICE - BLACK
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Price"] == NSOrderedSame) {
        
        NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                        [UIColor blackColor], NSForegroundColorAttributeName,
                                        nil];
        [self.eventTypeSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
        // Old way is just set color
        //[self.eventTypeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f]} forState:UIControlStateSelected];
        
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
            
            // Set correct header text
            [self.navigationController.navigationBar.topItem setTitle:@"FOLLOWED PRICE CHANGES"];
            // Set correct search bar placeholder text
            self.eventsSearchBar.placeholder = @"COMPANY/TICKER";
            
            // TURNED THIS OFF CURRENTLY  as it was not consistently working. Check to make sure we are syncing daily price data only once a day, after the market has opened.
            // Get time in GMT, US markets open at 9:30 am ET which is 1:30 pm GMT
            /*NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
            NSDate *todaysDate1 = [NSDate date];
            NSTimeInterval tzOffset = [[NSTimeZone systemTimeZone] secondsFromGMT];
            NSTimeInterval gmtTimeIt = [todaysDate1 timeIntervalSinceReferenceDate] - tzOffset;
            NSDate *todaysDateInGmt = [NSDate dateWithTimeIntervalSinceReferenceDate:gmtTimeIt];
            NSLog(@"TODAYS DATE AND TIME IN GMT IS:%@",todaysDateInGmt);
            NSDateComponents *components1 = [gregorianCalendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:todaysDateInGmt];
            NSInteger gmtHour = [components1 hour];
            NSInteger gmtMinute = [components1 minute];
            NSLog(@"TODAYS HOUR IN GMT IS:%ld",(long)gmtHour);
            NSLog(@"TODAYS MINUTES IN GMT IS:%ld",(long)gmtMinute);
            NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
            // Get the event sync date
            NSDate *lastSyncDate = [self setTimeToMidnightLastNightOnDate:[self.primaryDataController getDailyPriceEventSyncDate]];
            NSLog(@"MIDNIGHT ADJUSTED LAST EVENT SYNCED DATE AND TIME IS:%@",lastSyncDate);
            NSLog(@"MIDNIGHT ADJUSTED TODAYS DATE AND TIME IS:%@",lastSyncDate);
            // Get the number of days between the 2 dates
            NSDateComponents *components = [gregorianCalendar components:NSCalendarUnitDay fromDate:lastSyncDate toDate:todaysDate options:0];
            NSInteger daysBetween = [components day];
            NSLog(@"Days between LAST EVENT SYNC AND TODAY are: %ld",(long)daysBetween);
            // Refresh only if a day has passed since last refresh and if the market has opened.
            // Make sure in the new version string in app delegate you delete all daily price events. That brings you to a clean state
            // If it's been more than one day since sync. For clean slate the sync date method returns 7 days ago
            if ((int)daysBetween > 0) {
                
                // If time is past the market open time, refresh
                if(((gmtHour * 60) + gmtMinute) > 810) { */
                    
                    // Delete existing price events.
                    [self.primaryDataController deleteAllDailyPriceChangeEvents];
                    // Delete 52 weeks events
                    [self.primaryDataController deleteAll52WkEvents];
                    
                    self.eventResultsController = [self.primaryDataController getAllPriceChangeEventsForFollowedStocks];
                    [self.eventsListTable reloadData];
                    
                    // Get all price change events for followed stocks asynchronously
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
                        // Create a new FADataController so that this thread has its own MOC
                        FADataController *priceDataController = [[FADataController alloc] init];
                        
                        [priceDataController getPriceChangeEventsForFollowingStocksWrapper];
                    });
                /*}
                // Show existing price events along with a refresh message
                else {
                    
                    self.eventResultsController = [self.primaryDataController getAllPriceChangeEventsForFollowedStocks];
                    [self.eventsListTable reloadData];
                    
                    // Set navigation bar header to an attention orange color
                    NSDictionary *attentionHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                               [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                                               [UIColor colorWithRed:205.0f/255.0f green:151.0f/255.0f blue:61.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                                               nil];
                    
                    // Set navigation bar header to indicate busy
                    [self.navigationController.navigationBar setTitleTextAttributes:attentionHeaderAttributes];
                    [self.navigationController.navigationBar.topItem setTitle:@"Will refresh when markets open!"];
                }
            }
            // If not attempting a sync show current price change events.
            else {
                self.eventResultsController = [self.primaryDataController getAllPriceChangeEventsForFollowedStocks];
                [self.eventsListTable reloadData];
            } */
        }
        
        // TRACKING EVENT: Event Type Selected: User selected Product event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Price" } ];
    }
}

#pragma mark - Main Nav Selection
// When a main nav type selection has been made, change the color of the selected type and 1) show the appropriate event types in the results table 2) Set the correct search bar placeholder text 3) Clear out the search context
- (IBAction)mainNavSelectAction:(id)sender {
    
    // Reset the navigation bar header text color to black
    NSDictionary *regularHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                             [UIColor blackColor], NSForegroundColorAttributeName,
                                             nil];
    [self.navigationController.navigationBar setTitleTextAttributes:regularHeaderAttributes];
    
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                    [UIColor blackColor], NSForegroundColorAttributeName,
                                    nil];
    [self.mainNavSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
    
    // Clear out the search context
    [self.eventsSearchBar setText:@""];
    [self searchBar:self.eventsSearchBar textDidChange:@""];
    
    // If Product option is selected, set the correct search bar placeholder text disable and hide the event selection bar
    if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
        [self.eventTypeSelector setEnabled:NO];
        [self.eventTypeSelector setHidden:YES];
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"Company/Ticker/Cryptocurrency";
    }
    // If Events or Following is selected, set the correct search bar placeholder text enable and show the event selection bar
    else if (([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame)||([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame)) {
        [self.eventTypeSelector setEnabled:YES];
        [self.eventTypeSelector setHidden:NO];
        // Set correct search bar placeholder text
        self.eventsSearchBar.placeholder = @"COMPANY/TICKER/EVENT";
    }
    
    // Go with either NEWS or PRICE option based on Events or Following
    if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
        [self.eventTypeSelector setTitle:@"PROD" forSegmentAtIndex:4];
    }
    else if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
        [self.eventTypeSelector setTitle:@"PRICE" forSegmentAtIndex:4];
    }
    
    // Set events selector to All Events
    // ****SUPER IMPORTANT NOTE: This essentially triggers all the logic for what should happen when a main nav option is selected.
    [self.eventTypeSelector setSelectedSegmentIndex:0];
    [self.eventTypeSelector sendActionsForControlEvents:UIControlEventValueChanged];
    
    // TRACKING EVENT: EventsNav Selected: User clicked the "Reminder Set" button, most likely to unset the reminder.
    // TO DO: Disabling to not track development events. Enable before shipping.
    [FBSDKAppEvents logEvent:@"MainNav Selected"
                  parameters:@{ @"Option" :  [self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex]} ];
}

#pragma mark - Event Type Icon Action

// Process clicking of event type icon
- (void)processTypeIconTap:(UIGestureRecognizer *)gestureRecognizer
{
    // Get the event description corresponding to the tapped icon/ticker
    UIImageView *eventIcon = (UIImageView *)gestureRecognizer.view;
    NSIndexPath *tappedIndexPath = [NSIndexPath indexPathForRow:eventIcon.tag inSection:0];
    FAEventsTableViewCell *tappedIconCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:tappedIndexPath];
    
    // Currently just transitioning to the detail view as the shortcut was confusing to users. Uncomment if you need to bring it back.
    [self performSegueWithIdentifier:@"ShowEventDetails1" sender:tappedIconCell];
    
   /* NSString *formattedEventType = tappedIconCell.eventDescription.text;
    NSString *ticker = tappedIconCell.companyTicker.text;
    
    // Open the corresponding News in mobile Safari
    NSString *moreInfoURL = nil;
    NSString *searchTerm = nil;
    NSURL *targetURL = nil;
    
    // Send them to different sites with different queries based on which site has the best informtion for that event type
    
    // TO DO: If you want to revert to using Bing
    // Bing News is the default we are going with for now
    //moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.bing.com/news/search?q="];
    // searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];
    
    // Google news is default for now
    moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
    searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];
    
    // For Quarterly Earnings, search query term is ticker and Earnings e.g. BOX earnings
    if ([formattedEventType isEqualToString:@"Earnings"]) {
        searchTerm = [NSString stringWithFormat:@"%@ %@",ticker,@"earnings"];
    }
    
    // For Product events, search query term is the product name i.e. iPhone 7 or WWWDC 2016
    if ([formattedEventType containsString:@"Launch"]) {
        searchTerm = [formattedEventType stringByReplacingOccurrencesOfString:@" Launch" withString:@""];
    }
    // E.g. Naples Epyc Sales Launch becomes Naples Epyc
    if ([formattedEventType containsString:@"Sales Launch"]) {
        searchTerm = [formattedEventType stringByReplacingOccurrencesOfString:@" Sales Launch" withString:@""];
    }
    // For conference you want to use the raw event type as it contains the word conference and formatted does not
    if ([[self formatBackToEventType:tappedIconCell.eventDescription.text withAddedInfo:tappedIconCell.eventCertainty.text] containsString:@"Conference"]) {
        searchTerm = [formattedEventType stringByReplacingOccurrencesOfString:@" Conference" withString:@""];
    }
    // For economic events, search query term is customized for each type
    if ([formattedEventType containsString:@"GDP Release"]) {
        searchTerm = @"us gdp growth";
    }
    if ([formattedEventType containsString:@"Consumer Confidence"]) {
        searchTerm = @"us consumer confidence";
    }
    if ([formattedEventType containsString:@"Fed Meeting"]) {
        searchTerm = @"fomc meeting";
    }
    if ([formattedEventType containsString:@"Jobs Report"]) {
        searchTerm = @"jobs report us";
    }
    if ([formattedEventType containsString:@"% up"]||[formattedEventType containsString:@"% down"]) {
        searchTerm = [NSString stringWithFormat:@"%@ %@",ticker,@"stock"];
    }
    
    // Remove any spaces in the URL query string params
    searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
    
    targetURL = [NSURL URLWithString:moreInfoURL];
    
    if (targetURL) {
        
        // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"See External News Shortcut"
                      parameters:@{ @"News Source" : @"Google",
                                    @"Action Query" : searchTerm,
                                    @"Action URL" : [targetURL absoluteString]} ];
        
        SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
        externalInfoVC.delegate = self;
        // Just use whatever is the default color for the Safari View Controller
        //externalInfoVC.preferredControlTintColor = [self getColorForEventType:[self formatBackToEventType:tappedIconCell.eventDescription.text withAddedInfo:tappedIconCell.eventCertainty.text] withCompanyTicker:ticker];
        [self presentViewController:externalInfoVC animated:YES completion:nil];
    } */
}

// News Button on cell press
- (void)newsButtonPressed:(UIButton *)sender
{
    // Get the event description corresponding to the pressed button
    NSIndexPath *tappedIndexPath = [NSIndexPath indexPathForRow:sender.tag inSection:0];
    FAEventsTableViewCell *tappedButtonCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:tappedIndexPath];
    
    // Currently just transitioning to the detail view as the shortcut was confusing to users. Uncomment if you need to bring it back.
    [self performSegueWithIdentifier:@"ShowEventDetails1" sender:tappedButtonCell];
    
   /* NSString *formattedEventType = tappedButtonCell.eventDescription.text;
    NSString *ticker = tappedButtonCell.companyTicker.text;
    
    // Open the corresponding News in mobile Safari
    NSString *moreInfoURL = nil;
    NSString *searchTerm = nil;
    NSURL *targetURL = nil;
    
    // Send them to different sites with different queries based on which site has the best informtion for that event type
    
    // TO DO: If you want to revert to using Bing
    // Bing News is the default we are going with for now
    //moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.bing.com/news/search?q="];
    // searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];
    
    // Google news is default for now
    moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
    searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];
    
    // For Quarterly Earnings, search query term is ticker and Earnings e.g. BOX earnings
    if ([formattedEventType isEqualToString:@"Earnings"]) {
        searchTerm = [NSString stringWithFormat:@"%@ %@",ticker,@"earnings"];
    }
    
    // For Product events, search query term is the product name i.e. iPhone 7 or WWWDC 2016
    if ([formattedEventType containsString:@"Launch"]) {
        searchTerm = [formattedEventType stringByReplacingOccurrencesOfString:@" Launch" withString:@""];
    }
    // E.g. Naples Epyc Sales Launch becomes Naples Epyc
    if ([formattedEventType containsString:@"Sales Launch"]) {
        searchTerm = [formattedEventType stringByReplacingOccurrencesOfString:@" Sales Launch" withString:@""];
    }
    // For conference you want to use the raw event type as it contains the word conference and formatted does not
    if ([[self formatBackToEventType:tappedButtonCell.eventDescription.text withAddedInfo:tappedButtonCell.eventCertainty.text] containsString:@"Conference"]) {
        searchTerm = [formattedEventType stringByReplacingOccurrencesOfString:@" Conference" withString:@""];
    }
    
    // For economic events, search query term is customized for each type
    if ([formattedEventType containsString:@"GDP Release"]) {
        searchTerm = @"us gdp growth";
    }
    if ([formattedEventType containsString:@"Consumer Confidence"]) {
        searchTerm = @"us consumer confidence";
    }
    if ([formattedEventType containsString:@"Fed Meeting"]) {
        searchTerm = @"fomc meeting";
    }
    if ([formattedEventType containsString:@"Jobs Report"]) {
        searchTerm = @"jobs report us";
    }
    if ([formattedEventType containsString:@"% up"]||[formattedEventType containsString:@"% down"]) {
        searchTerm = [NSString stringWithFormat:@"%@ %@",ticker,@"stock"];
    }
    
    // Remove any spaces in the URL query string params
    searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
    
    targetURL = [NSURL URLWithString:moreInfoURL];
    
    if (targetURL) {
        
        // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"See External News Shortcut"
                      parameters:@{ @"News Source" : @"Google",
                                    @"Action Query" : searchTerm,
                                    @"Action URL" : [targetURL absoluteString]} ];
        
        SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
        externalInfoVC.delegate = self;
        // Just use whatever is the default color for the Safari View Controller
        //externalInfoVC.preferredControlTintColor = [self getColorForEventType:[self formatBackToEventType:tappedButtonCell.eventDescription.text withAddedInfo:tappedButtonCell.eventCertainty.text] withCompanyTicker:ticker];
        [self presentViewController:externalInfoVC animated:YES completion:nil];
    } */
}

#pragma mark - Support Related

// Initiate support experience when button is clicked. Currently open http://www.knotifi.com/p/contact.html
- (IBAction)initiateSupport:(id)sender {
    
    SFSafariViewController *supportVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:@"http://www.knotifi.com/p/contact.html"]];
    supportVC.delegate = self;
    supportVC.preferredControlTintColor = [UIColor blackColor];
    [self presentViewController:supportVC animated:YES completion:nil];
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
    
    // If All Events is selected.
    if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
        
        // Get the right future events depending on event type
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFutureEventsWithProductEventsOfVeryHighImpact];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFutureEarningsEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFutureEconEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFutureCryptoEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFutureProductEvents];
        }
    }
    // If following is selected in which case show the right following events
    if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
        // Show all following events
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFollowingFutureEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFollowingFutureEarningsEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFollowingFutureEconEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllFollowingFutureCryptoEvents];
        }
        if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Price"] == NSOrderedSame) {
            self.eventResultsController = [secondaryDataController getAllPriceChangeEventsForFollowedStocks];
        }
    }
    
    [self.eventsListTable reloadData];
}

// Show the error message in the header
- (void)userMessageGenerated:(NSNotification *)notification {
    
   // In case you want to animate in the error message
    
   /* CATransition *fadingAnimation = [CATransition animation];
    fadingAnimation.duration = 3.0;
    fadingAnimation.type = kCATransitionFade; 
    [self.navigationController.navigationBar.layer addAnimation: fadingAnimation forKey: @"fadeText"];
    [self.navigationController.navigationBar.topItem setTitle:[notification object]];
    */
    
    // Set navigation bar header to an attention orange color
    NSDictionary *attentionHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                               [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                               [UIColor colorWithRed:205.0f/255.0f green:151.0f/255.0f blue:61.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                               nil];
    [self.navigationController.navigationBar setTitleTextAttributes:attentionHeaderAttributes];
    [self.navigationController.navigationBar.topItem setTitle:[notification object]];
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
    [self showBusyMessage];
}

// Respond to the notification to stop the busy spinner
- (void)stopBusySpinner:(NSNotification *)notification {
    
    // Set the busy spinner to stop spinning.
    [self removeBusyMessage];
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
        
        // Get the currently selected cell and set details for the destination.
        // IMPORTANT: If the format here or in the events UI is changed, reminder creation in the details screen will break.
        FADataController *segueDataController = [[FADataController alloc] init];
        //NSIndexPath *selectedRowIndexPath = [self.eventsListTable indexPathForSelectedRow];
        //FAEventsTableViewCell *selectedCell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:selectedRowIndexPath];
        // Table Cell is being sent in as the sender, instead of the old way commented above.
        FAEventsTableViewCell *selectedCell = sender;
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
        [FBSDKAppEvents logEvent:@"Go To Details"
                      parameters:@{ @"Ticker" : [segueDataController getTickerForName:selectedCell.companyName.text],
                                    @"Event Type" : eventType,
                                    @"Name" : (selectedCell.companyName).text } ];
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

// Compute the unscrubbed date 4 mos ago from today. Unscrubbed means it could be a weekend or a holiday.
- (NSDate *)computeDate4MosAgoFrom:(NSDate *)startingDate
{
    // Subtract 124 days from start date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = -124;
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
    // TO DO Change for beginning of the year 2019: For 2017, the first market day will be 2 days later on Jan 3. So add 2 instead of 3 here. That's it. www.timeanddate.com/calendar/?year=2017&country=1
    // FOR 2018: the first day the market is open is Tue Jan 2nd. So add 1 instead of 2.
    NSDateComponents *differenceDayComponents = [[NSDateComponents alloc] init];
    differenceDayComponents.day = 1;
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

// Check to see if the event is of a type that it is followable. Currently price change events, or a product event or an earnings event, are followable. Econ events are not.
- (BOOL)isEventFollowable:(NSString *)eventType
{
    BOOL returnVal = NO;
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]||[eventType containsString:@"% up"]||[eventType containsString:@"% down"]||[eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        returnVal = YES;
    }
    
    return returnVal;
}

- (BOOL)doesTimelineExistForTicker:(NSString *)ticker {
    
    BOOL returnVal = NO;
    
    NSFetchedResultsController *result = [self.primaryDataController getAllProductEventsForTicker:ticker since:[self computeDate4MosAgoFrom:[NSDate date]]];
    
    if (result.fetchedObjects.count > 0) {
        returnVal = YES;
    }
    
    return returnVal;
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
- (NSString *)calculateDistanceFromEventDate:(NSDate *)eventDate withEventType:(NSString *)rawEventType
{
    NSString *formattedDistance = @"Details ▸";
    
    // Calculate the number of days between event date and today's date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSUInteger unitFlags =  NSCalendarUnitDay;
    NSDateComponents *diffDateComponents = [aGregorianCalendar components:unitFlags fromDate:[self setTimeToMidnightLastNightOnDate:[NSDate date]] toDate:[self setTimeToMidnightLastNightOnDate:eventDate] options:0];
    NSInteger difference = [diffDateComponents day];
    
    // Return an appropriately formatted string
   /* if ((difference < 0)&&(difference > -2)) {
        formattedDistance = @"Yesterday ▸";
    } else if ((difference <= -2)&&(difference > -4)) {
        formattedDistance = @"Day Before ▸";
    } else if ((difference <= -4)&&(difference > -8)) {
        formattedDistance = [NSString stringWithFormat:@"%@d ago ▸",[@(ABS(difference)) stringValue]];
    } else if ((difference <= -8)&&(difference > -31)) {
        formattedDistance = @"Past month ▸";
    } else if ((difference <= -31)&&(difference > -92)) {
        formattedDistance = @"Past 3 mos ▸";
    } else if ((difference <= -92)&&(difference > -184)) {
        formattedDistance = @"Past 6 mos ▸";
    } else if ((difference <= -184)&&(difference > -366)) {
        formattedDistance = @"Past year ▸";
    } else if (difference <= -366) {
        formattedDistance = [NSString stringWithFormat:@"%@d ago ▸",[@(ABS(difference)) stringValue]];
    } else if (difference == 0) {
        formattedDistance = @"Today ▸";
    } else if (difference == 1) {
        formattedDistance = @"Tomorrow ▸";
    } else if ((difference > 1)&&(difference < 8)) {
        formattedDistance = [NSString stringWithFormat:@"In %@d ▸",[@(difference) stringValue]];
    } else if ((difference >= 8)&&(difference < 15)) {
        formattedDistance = @"In 1 wk ▸";
    } else if ((difference >= 15)&&(difference < 31)) {
        formattedDistance = @"In 2 wks ▸";
    } else if ((difference >= 31)&&(difference < 62)) {
        formattedDistance = @"In 1 mo ▸";
    } else if ((difference >= 62)&&(difference < 92)) {
        formattedDistance = @"In 2 mos ▸";
    } else if ((difference >= 92)&&(difference < 123)) {
        formattedDistance = @"In 3 mos ▸";
    } else if ((difference >= 123)&&(difference < 153)) {
        formattedDistance = @"In 4 mos ▸";
    } else if ((difference >= 153)&&(difference < 184)) {
        formattedDistance = @"In 5 mos ▸";
    } else if ((difference >= 184)&&(difference < 214)) {
        formattedDistance = @"In 6 mos ▸";
    } else if ((difference >= 214)&&(difference < 366)) {
        formattedDistance = @"Beyond 6 mos ▸";
    } else if (difference >= 366) {
        formattedDistance = @"Beyond 1 yr ▸";
    } else {
        formattedDistance = [NSString stringWithFormat:@"%@d ▸",[@(difference) stringValue]];
    }*/
    
    
    // Return an appropriately formatted string. Show the ▸ when it's not a price event, else don't show that for price event as there is going to be no detail view for that.
    if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Price"] == NSOrderedSame) {
        if ((difference < 0)&&(difference > -2)) {
            formattedDistance = @"Yesterday";
        } else if ((difference <= -2)&&(difference > -4)) {
            formattedDistance = @"Day Before";
        } else if ((difference <= -4)&&(difference > -31)) {
            formattedDistance = [NSString stringWithFormat:@"%@d ago",[@(ABS(difference)) stringValue]];
        } else if ((difference <= -31)&&(difference > -366)) {
            formattedDistance = [NSString stringWithFormat:@"%@mos ago",[@(ABS(difference/30)) stringValue]];
        } else if (difference <= -366) {
            formattedDistance = @"Over 1yr ago";
        } else if (difference == 0) {
            formattedDistance = @"Today";
        } else if (difference == 1) {
            formattedDistance = @"Tomorrow";
        } else if ((difference > 1)&&(difference < 31)) {
            formattedDistance = [NSString stringWithFormat:@"In %@d",[@(difference) stringValue]];
        } else if ((difference >= 31)&&(difference < 366)) {
            formattedDistance = [NSString stringWithFormat:@"In %@mos",[@(difference/30) stringValue]];
        } else if (difference >= 366) {
            formattedDistance = @"Beyond 1yr ▸";
        } else {
            formattedDistance = [NSString stringWithFormat:@"%@d",[@(difference) stringValue]];
        }
        if ([rawEventType containsString:@"% up"]||[rawEventType containsString:@"% down"]) {
            formattedDistance = [NSString stringWithFormat:@"%@ ▸",formattedDistance];
        }
    } else {
        if ((difference < 0)&&(difference > -2)) {
            formattedDistance = @"Yesterday ▸";
        } else if ((difference <= -2)&&(difference > -4)) {
            formattedDistance = @"Day Before ▸";
        } else if ((difference <= -4)&&(difference > -31)) {
            formattedDistance = [NSString stringWithFormat:@"%@d ago ▸",[@(ABS(difference)) stringValue]];
        } else if ((difference <= -31)&&(difference > -366)) {
            formattedDistance = [NSString stringWithFormat:@"%@mos ago ▸",[@(ABS(difference/30)) stringValue]];
        } else if (difference <= -366) {
            formattedDistance = @"Over 1yr ago ▸";
        } else if (difference == 0) {
            formattedDistance = @"Today ▸";
        } else if (difference == 1) {
            formattedDistance = @"Tomorrow ▸";
        } else if ((difference > 1)&&(difference < 31)) {
            formattedDistance = [NSString stringWithFormat:@"In %@d ▸",[@(difference) stringValue]];
        } else if ((difference >= 31)&&(difference < 366)) {
            formattedDistance = [NSString stringWithFormat:@"In %@mos ▸",[@(difference/30) stringValue]];
        } else if (difference >= 366) {
            formattedDistance = @"Beyond 1yr ▸";
        } else {
            formattedDistance = [NSString stringWithFormat:@"%@d ▸",[@(difference) stringValue]];
        }
    }
    
    return formattedDistance;
}

// Return the appropriate color for event distance based on type of event and how far it is from today.
- (UIColor *)getColorForDistanceFromEventDate:(NSDate *)eventDate withEventType:(NSString *)rawEventType {
    
    //Very lightish gray
    UIColor *colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
    
    // For % up and down events, go with the color green or red. For all others include the
    if ([rawEventType containsString:@"% up"])
    {
        // Kinda Green
        //colorToReturn = [UIColor colorWithRed:56.0f/255.0f green:197.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
        colorToReturn = [UIColor colorWithRed:52.0f/255.0f green:181.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
    } else if ([rawEventType containsString:@"% down"])
    {
        // Kinda Red
        colorToReturn = [UIColor colorWithRed:255.0f/255.0f green:63.0f/255.0f blue:61.0f/255.0f alpha:1.0f];
    } else if ([rawEventType containsString:@"52 Week High"])
    {
        // Very lightish gray
        colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
    } else if ([rawEventType containsString:@"52 Week Low"])
    {
        // Very lightish gray
        colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
    }
    // Don't need this anymore as we are not treating PROD events any differently.
    /*else if (([rawEventType containsString:@"Launch"]||[rawEventType containsString:@"Conference"])&&([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame)) {
        // Very lightish gray
        colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
    }*/
    else {
        
        // Return the standard color pattern
        colorToReturn = [self getColorForDistanceFromEventDate:eventDate];
    }

    return colorToReturn;
}

// Return the appropriate color for event distance based on how far it is from today.
- (UIColor *)getColorForDistanceFromEventDate:(NSDate *)eventDate
{
    // Set returned color to light gray text to start with
    //UIColor *colorToReturn = [UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f];
    //Very lightish gray
    UIColor *colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
    
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
        //colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
        // Original Product Brown
        //colorToReturn = [UIColor colorWithRed:113.0f/255.0f green:34.0f/255.0f blue:32.0f/255.0f alpha:1.0f];
        // High Impact Indicator Red
        //colorToReturn = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
        // Return almost black
        //colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
        // Return black
        //colorToReturn = [UIColor blackColor];
        // Return normal blue
        colorToReturn = [UIColor blueColor];
        
    } else if (difference == 1) {
        // Older slightly less orangish red
        //colorToReturn = [UIColor colorWithRed:232.0f/255.0f green:81.0f/255.0f blue:62.0f/255.0f alpha:1.0f];
        // Newer pinkish deep red
        //colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
        // Original Product Brown
        //colorToReturn = [UIColor colorWithRed:113.0f/255.0f green:34.0f/255.0f blue:32.0f/255.0f alpha:1.0f];
        // High Impact Indicator Red
        //colorToReturn = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
        // Return almost black
        //colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
        // Return black
        //colorToReturn = [UIColor blackColor];
        // Return the blue that was used for Econ events
        colorToReturn = [UIColor blueColor];
    } else if ((difference > 1)&&(difference < 8)){
        // Older More orange, less red
        //colorToReturn = [UIColor colorWithRed:255.0f/255.0f green:89.0f/255.0f blue:68.0f/255.0f alpha:1.0f];
        // Newer pinkish deep red
        //colorToReturn = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
        // Original Product Brown
        //colorToReturn = [UIColor colorWithRed:113.0f/255.0f green:34.0f/255.0f blue:32.0f/255.0f alpha:1.0f];
        // High Impact Indicator Red
        //colorToReturn = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
        // Return almost black
        //colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
        // Return black
        //colorToReturn = [UIColor blackColor];
        // Return blue
        colorToReturn = [UIColor blueColor];
    } else if ((difference < 0)&&(difference > -8)){
        // Return almost black
        // colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
        // Return total black
        colorToReturn = [UIColor blackColor];
    } else if (((difference > 7)&&(difference < 31))||((difference > -31)&&(difference < -7))){
        // Return almost black
        // colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
        // Return total black
        colorToReturn = [UIColor blackColor];
    }
    
    return colorToReturn;
}

// Return the appropriate color for event labels based on type of event.
- (UIColor *)getColorForCellLabelsBasedOnEventType:(NSString *)rawEventType {
    
    //Default very dark gray
    UIColor *colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    
    // For % up and down events, go with the color green or red. For all others include the
    if ([rawEventType containsString:@"% up"])
    {
        // Kinda Green
        //colorToReturn = [UIColor colorWithRed:56.0f/255.0f green:197.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
        colorToReturn = [UIColor colorWithRed:52.0f/255.0f green:181.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
    } else if ([rawEventType containsString:@"% down"])
    {
        // Kinda Red
        colorToReturn = [UIColor colorWithRed:255.0f/255.0f green:63.0f/255.0f blue:61.0f/255.0f alpha:1.0f];
    } else if ([rawEventType containsString:@"52 Week High"])
    {
        // Very lightish gray
        colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
    } else if ([rawEventType containsString:@"52 Week Low"])
    {
        // Very lightish gray
        colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
    } else {
        
        //Default very dark gray
        colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
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
    
    // For price change events, there's no schedule
    if ([eventType containsString:@"% up"]) {
        
        eventImage = [UIImage imageNamed:@"PriceIncreaseListCircle"];
    }
    
    if([eventType containsString:@"% down"]) {
        
        eventImage = [UIImage imageNamed:@"PriceDecreaseListCircle"];
    }
    
    return eventImage;
}

// Return the appropriate color for event based on type.
- (UIColor *)getColorForEventType:(NSString *)eventType withCompanyTicker:(NSString *)ticker
{
    // Set returned color to dark gray text to start with
    UIColor *colorToReturn = [UIColor darkGrayColor];
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        // Punchy Knotifi Green
        colorToReturn = [UIColor colorWithRed:104.0f/255.0f green:202.0f/255.0f blue:94.0f/255.0f alpha:1.0f];
    }
    if ([eventType containsString:@"Fed Meeting"]) {
        // Econ Blue
        //colorToReturn = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
        // Light purple
        colorToReturn = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
    }
    if ([eventType containsString:@"Jobs Report"]) {
        // Econ Blue
        //colorToReturn = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
        // Light purple
        colorToReturn = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
    }
    if ([eventType containsString:@"Consumer Confidence"]) {
        // Econ Blue
        //colorToReturn = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
        // Light purple
        colorToReturn = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
    }
    if ([eventType containsString:@"GDP Release"]) {
        // Econ Blue
        //colorToReturn = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
        // Light purple
        colorToReturn = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
    }
    if ([eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        // FOR BTC: Add any new cryptocurrencies here. Return copper penny color. Don't need this anymore.
        if (([ticker caseInsensitiveCompare:@"BTC"] == NSOrderedSame)||([ticker caseInsensitiveCompare:@"ETHR"] == NSOrderedSame)) {
            colorToReturn = [UIColor colorWithRed:192.0f/255.0f green:134.0f/255.0f blue:114.0f/255.0f alpha:1.0f];
        }
        // Else return product yellow.
        else {
            colorToReturn = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        }
    }
    if ([eventType containsString:@"% up"])
    {
        // Kinda Green
        //colorToReturn = [UIColor colorWithRed:56.0f/255.0f green:197.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
        colorToReturn = [UIColor colorWithRed:52.0f/255.0f green:181.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
        
    }
    if ([eventType containsString:@"% down"])
    {
        // Kinda Red
        colorToReturn = [UIColor colorWithRed:255.0f/255.0f green:63.0f/255.0f blue:61.0f/255.0f alpha:1.0f];
    }
    if ([eventType containsString:@"52 Week High"])
    {
        // Very lightish gray
        //colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
        colorToReturn = [UIColor whiteColor];
    }
    if ([eventType containsString:@"52 Week Low"])
    {
        // Very lightish gray
        //colorToReturn = [UIColor colorWithRed:150.0f/255.0f green:150.0f/255.0f blue:150.0f/255.0f alpha:1.0f];
        colorToReturn = [UIColor whiteColor];
    }
    
    return colorToReturn;
}

// Return the appropriate color for event based on type.
- (UIColor *)getColorForEventTickerLbl:(NSString *)eventType
{
    // Set returned color to the default almost black dark gray
    UIColor *colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    
    // For % up and down events, go with the color green or red. For all others include the
    if ([eventType containsString:@"% up"])
    {
        // Kinda Green
        //colorToReturn = [UIColor colorWithRed:56.0f/255.0f green:197.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
        colorToReturn = [UIColor colorWithRed:52.0f/255.0f green:181.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
    } else if ([eventType containsString:@"% down"])
    {
        // Kinda Red
        colorToReturn = [UIColor colorWithRed:255.0f/255.0f green:63.0f/255.0f blue:61.0f/255.0f alpha:1.0f];
    } else if ([eventType containsString:@"52 Week High"])
    {
        colorToReturn = [UIColor whiteColor];
    } else if ([eventType containsString:@"52 Week Low"])
    {
        colorToReturn = [UIColor whiteColor];
    } else {
        //Default almost black very dark gray
        colorToReturn = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    }
    
    return colorToReturn;
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

// Show the busy message in the header.
- (void)showBusyMessage {
    
    // Set navigation bar header to the correct text based on all events or following, if this view is currently being displayed. If not, for instance, say details view is being displayed, do nothing as we don't want this view's headers being shown in the details view.
    
    // If the list view is currently being shown
    if (self.navigationController.topViewController == self) {
        
        // Set navigation bar header to an attention orange color
        NSDictionary *attentionHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                                   [UIColor colorWithRed:205.0f/255.0f green:151.0f/255.0f blue:61.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                                   nil];
        [self.navigationController.navigationBar setTitleTextAttributes:attentionHeaderAttributes];
        [self.navigationController.navigationBar.topItem setTitle:@"Fetching..."];
    }
}

// Remove the busy message in the header to show appropriate header.
- (void)removeBusyMessage {
    
    // Set navigation bar header to the correct text based on all events or following or product timeline, if this view is currently being displayed. If not, for instance, say details view is being displayed, do nothing as we don't want this view's headers being shown in the details view.
        
    // If the list view is currently being shown
    if (self.navigationController.topViewController == self) {
        
        // Set navigation bar header to title "Upcoming Events"
        NSDictionary *regularHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                                 [UIColor blackColor], NSForegroundColorAttributeName,
                                                 nil];
        [self.navigationController.navigationBar setTitleTextAttributes:regularHeaderAttributes];
        
        // If All Events is selected.
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Events"] == NSOrderedSame) {
            
            // If Home is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING MARKET EVENTS"];
            }
            
            // If Earnings is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING EARNINGS"];
            }
            
            // If Econ events is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING ECON EVENTS"];
            }
            
            // If Crypto events is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"UPCOMING CRYPTO EVENTS"];
            }
            
            // If News (Prod) is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Prod"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"PRODUCT NEWS"];
            }
        }
        // If following is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Following"] == NSOrderedSame) {
            
            // If Home is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Home"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"ALL FOLLOWED EVENTS"];
            }
            
            // If Earnings is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Earnings"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"FOLLOWED EARNINGS"];
            }
            
            // If Econ events is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Econ"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"FOLLOWED ECON EVENTS"];
            }
            
            // If Crypto events is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Crypto"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"FOLLOWED CRYPTO EVENTS"];
            }
            
            // If Price is selected
            if ([[self.eventTypeSelector titleForSegmentAtIndex:self.eventTypeSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Price"] == NSOrderedSame) {
                [self.navigationController.navigationBar.topItem setTitle:@"FOLLOWED PRICE CHANGES"];
            }
        }
        // Check to see if the Product Main Nav is selected
        if ([[self.mainNavSelector titleForSegmentAtIndex:self.mainNavSelector.selectedSegmentIndex] caseInsensitiveCompare:self.mainNavProductOption] == NSOrderedSame) {
            // If no product timeline is displayed
            if ([self.filterType isEqualToString:@"None_Specified"]) {
                [self.navigationController.navigationBar.topItem setTitle:@"See Product Timeline"];
            } else {
                [self.navigationController.navigationBar.topItem setTitle:@"PRODUCT TIMELINE"];
            }
        }
    }
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
