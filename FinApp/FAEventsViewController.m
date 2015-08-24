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
@import EventKit;
#import <stdlib.h>

@interface FAEventsViewController ()

// Get all companies from API. Typically called in a background thread
- (void)getAllCompaniesFromApiInBackground;

// Validate search text entered
- (BOOL) searchTextValid:(NSString *)text;

// Get events for company given a ticker. Typically called in a background thread
- (void)getAllEventsFromApiInBackgroundWithTicker:(NSString *)ticker;

// Send a notification that the list of events has changed (updated)
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents;

// User's calendar events and reminders data store
@property (strong, nonatomic) EKEventStore *userEventStore;


@end

@implementation FAEventsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    // Make the message bar fully transparent so that it's invisible to the user
    self.messageBar.alpha = 0.0;
    
    // Change the color of the events search bar placeholder text and text entered to be white.
    UITextField *eventSearchBarInputFld = [self.eventsSearchBar valueForKey:@"_searchField"];
    [eventSearchBarInputFld setValue:[UIColor darkGrayColor] forKeyPath:@"_placeholderLabel.textColor"];
    eventSearchBarInputFld.textColor = [UIColor darkGrayColor];
    
    // Do the same for the Magnifying glass icon in the search bar.
    UIImageView *magGlassIcon = (UIImageView *)eventSearchBarInputFld.leftView;
    magGlassIcon.image = [magGlassIcon.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    magGlassIcon.tintColor = [UIColor darkGrayColor];
    
    // Do the same for the Clear button in the search bar.
    UIButton *searchClearBtn = [eventSearchBarInputFld valueForKey:@"_clearButton"];
    [searchClearBtn setImage:[searchClearBtn.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    searchClearBtn.tintColor = [UIColor darkGrayColor];
    
    // Get a primary data controller that you will use later
    self.primaryDataController = [[FADataController alloc] init];
    
    // Ensure that the remote fetch spinner is not animating thus hidden
    [self.remoteFetchSpinner stopAnimating];
    
    // Register a listener for changes to events stored locally
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(eventStoreChanged:)
                                                 name:@"EventStoreUpdated" object:nil];
    
    // Register a listener for messages to be shown to the user in the top bar userMessageGenerated
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userMessageGenerated:)
                                                 name:@"UserMessageCreated" object:nil];
    
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
    }
    
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
    
    // Get a custom cell to display
    FAEventsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventCell" forIndexPath:indexPath];
    
    // Reset color for Event description to dark text, in case it's been set to blue for a "Get Events" display
    cell.eventDescription.textColor = [UIColor colorWithRed:63.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    
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
        
        // Show the company name associated with the event
        [[cell  companyName] setText:companyAtIndex.name];
        
        // Show the "Get Events" text in the event display area.
        [[cell  eventDescription] setText:@"Get Events"];
        // Set color to a link blue to provide a visual cue to click
        cell.eventDescription.textColor = [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
        
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
        
        // Set the fetch state of the event cell to false
        // TO DO: Should you really be holding logic state at the cell level or should there
        // be a unique identifier for each event ?
        cell.eventRemoteFetch = NO;
        
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
    
    NSLog(@"Row Clicked");
    
    // Check to see if the row selected has an event cell with remote fetch status set to true
    FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
    if (cell.eventRemoteFetch) {
        
        // Set the remote fetch spinner to animating to show a fetch is in progress
        NSLog(@"Starting to animate spinner");
        [self.remoteFetchSpinner startAnimating];
        
        // Fetch the event for the related parent company in the background
        NSLog(@"Fetching Event Data for ticker in the background:%@",(cell.companyTicker).text);
        [self performSelectorInBackground:@selector(getAllEventsFromApiInBackgroundWithTicker:) withObject:(cell.companyTicker).text];
    }
}

// Make Sure the table row, if it should be, is editable
// TO DO: Check to see that the row has event information. Only then, make it editable
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return YES;
}

// TO DO: Understand this method better. Basically need this to be able to use the custom UITableViewRowAction
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

// Add the following actions on swiping each event row: 1) "Set Reminder" if reminder hasn't already been created, else
// display a message that reminder has aleady been set.
- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Get the cell for the row on which the action is being exercised
    FAEventsTableViewCell *cell = (FAEventsTableViewCell *)[self.eventsListTable cellForRowAtIndexPath:indexPath];
    
    UITableViewRowAction *setReminderAction;
    
    // Check to see if a reminder action has already been created for the event represented by the cell.
    // If yes, show a appropriately formatted status action.
    if ([self.primaryDataController doesReminderActionExistForEventWithTicker:cell.companyTicker.text eventType:cell.eventDescription.text])
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
        setReminderAction.backgroundColor = [UIColor blueColor];
    }
    
    // TO DO: For future, if you want to add an additional action.
    /* UITableViewRowAction *anotherAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Another Action" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        // Handle exercising the action
    }];
    anotherAction.backgroundColor = [UIColor blueColor];
    return @[setReminderAction, anotherAction]; */
    
    return @[setReminderAction];
}

#pragma mark - Data Source API

// Get all companies from API. Typically called in a background thread
- (void)getAllCompaniesFromApiInBackground
{
    // Create a new FADataController so that this thread has its own MOC
    FADataController *companiesDataController = [[FADataController alloc] init];
    
    [companiesDataController getAllCompaniesFromApi];
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
    // If the companies data is still being synced, give the user a warning message
    if (![[self.primaryDataController getCompanySyncStatus] isEqualToString:@"FullSyncDone"]) {
        NSLog(@"NOTIFICATION ABOUT TO BE FIRED: With User Message: %@",@"Fetching Companies. If you can't find a Company, retry in a bit.");
        // Show user a message that companies data is being synced
        [self sendUserMessageCreatedNotificationWithMessage:@"Fetching Companies. If you can't find a Company, retry in a bit."];
    }
    return YES;
}

#pragma mark - Notifications

// Send a notification that the list of events has changed (updated)
- (void)sendUserMessageCreatedNotificationWithMessage:(NSString *)msgContents {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"UserMessageCreated" object:msgContents];
    NSLog(@"NOTIFICATION FIRED: With User Message: %@",msgContents);
}

#pragma mark - Change Listener Responses

// Refresh the messages table when the message store for the table has changed
- (void)eventStoreChanged:(NSNotification *)notification {
    
    [self.eventsListTable reloadData];
    NSLog(@"*******************************************Event Store Changed listener fired to refresh table");
}

// Show the error message for a temporary period and then fade it if a user message has been generated
// TO DO: Currently set to 5 seconds. Change as you see fit.
- (void)userMessageGenerated:(NSNotification *)notification {
    
    // Make sure the message bar is empty and visible to the user
    self.messageBar.text = @"";
    self.messageBar.alpha = 1.0;
    
     NSLog(@"NOTIFICATION ABOUT TO BE SHOWN: With User Message: %@",[notification object]);
    
    // Show the message that's generated for a period of 5 seconds
    [UIView animateWithDuration:5 animations:^{
        self.messageBar.text = [notification object];
        self.messageBar.alpha = 0;
    }];
    
    NSLog(@"*******************************************User Message Generated listener fired to show error message");
}

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
            [self sendUserMessageCreatedNotificationWithMessage:@"Enable access to your Reminders under Settings>Finapp and try again!"];
            break;
        }
            
        // If the user has already provided access, create the reminder.
        case EKAuthorizationStatusAuthorized: {
            [self processReminderForEventInCell:eventCell];
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
                                                        [weakPtrToSelf processReminderForEventInCell:eventCell];
                                                    } else {
                                                        [self sendUserMessageCreatedNotificationWithMessage:@"Unable to Create Reminder. Try again after enabling Reminders under Settings>Finapp!"];
                                                    }
                                                    
                                                });
                                            }];
            break;
        }
    }
}

// Process the "Remind Me" action for the event represented by the cell on which the action was taken. If the event is confirmed, create the reminder immediately and make an appropriate entry in the Action data store. If it's estimated, then don't create the reminder, only make an appropriate entry in the action data store for later processing.
// TO DO: How do you prevent duplicate reminders ?
- (void)processReminderForEventInCell:(FAEventsTableViewCell *)eventCell {
    
    // Check to see if the event represented by the cell is estimated or confirmed ?
    
    // If confirmed create and save to action data store
    if ([eventCell.eventCertainty.text isEqualToString:@"Confirmed"]) {
        
        NSLog(@"About to create a reminder, since this event is confirmed");
        
        // Create the reminder
        
        // Set its title to the reminder text.
        EKReminder *eventReminder = [EKReminder reminderWithEventStore:self.userEventStore];
        NSString *reminderText = [NSString stringWithFormat:@"%@ %@ tomorrow %@", eventCell.companyTicker.text,eventCell.eventDescription.text,eventCell.eventDate.text];
        eventReminder.title = reminderText;
        NSLog(@"The Reminder title is: %@",reminderText);
        
        // For now, create the reminder in the default calendar for new reminders as specified in settings
        eventReminder.calendar = [self.userEventStore defaultCalendarForNewReminders];
        
        // Get the date for the event represented by the cell
        NSDate *eventDate = [self.primaryDataController getDateForEventOfType:eventCell.eventDescription.text eventTicker:eventCell.companyTicker.text];
        
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
        
        // TO DO: Delete later. For debugging purposes, converting reminder due date components to date, time
        NSDate *debugEventDate = [aGregorianCalendar dateFromComponents:reminderDateTimeComponents];
        NSDateFormatter *eventDateFormatter = [[NSDateFormatter alloc] init];
        [eventDateFormatter setDateFormat:@"yyyy-MM-dd 'at' HH:mm:ss"];
        NSString *eventDueDateDebugString = [eventDateFormatter stringFromDate:debugEventDate];
        NSLog(@"Event Reminder Date Time is:%@",eventDueDateDebugString);
        
        // Save the Reminder and show user the appropriate message
        NSError *error = nil;
        BOOL success = [self.userEventStore saveReminder:eventReminder commit:YES error:&error];
        if (success) {
            
            [self sendUserMessageCreatedNotificationWithMessage:@"Rest Easy! You'll be reminded of this event a day before."];
        } else {
            
            [self sendUserMessageCreatedNotificationWithMessage:@"Oops! Unable to create a reminder for this event."];
        }
        
        // Add action to the action data store with status created
        [self.primaryDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:eventCell.companyTicker.text eventType:eventCell.eventDescription.text];
    }
    
    // If estimated add to action data store for later processing
    else if ([eventCell.eventCertainty.text isEqualToString:@"Estimated"]) {
        
        NSLog(@"About to queue a reminder for later creation, since this event is not confirmed");
        
        // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
        [self.primaryDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:eventCell.companyTicker.text eventType:eventCell.eventDescription.text];
    }
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
