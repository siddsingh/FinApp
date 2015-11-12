//
//  FAEventDetailsViewController.m
//  FinApp
//
//  Class that manages the view showing details of the selected event.
//
//  Created by Sidd Singh on 10/21/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "FAEventDetailsViewController.h"
#import "FAEventDetailsTableViewCell.h"
#import "EventHistory.h"
#import "FADataController.h"
#import "Event.h"
#import "Reachability.h"
@import EventKit;

@interface FAEventDetailsViewController ()

// Send a notification that there's guidance messge to be presented to the user
- (void)sendUserGuidanceCreatedNotificationWithMessage:(NSString *)msgContents;

// User's calendar events and reminders data store
@property (strong, nonatomic) EKEventStore *userEventStore;

@end

@implementation FAEventDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"Event Details View Controller View Did Load called");
    
    // Do any additional setup after loading the view.
    
    // Make the information messages area fully transparent so that it's invisible to the user
    self.messagesArea.alpha = 0.0;
    
    // Ensure that the busy spinner is not animating thus hidden
    [self.busySpinner stopAnimating];
    
    // Get a primary data controller that you will use later
    self.primaryDetailsDataController = [[FADataController alloc] init];
    
    // Set the labels to the strings that hold their text. These strings will be set in the prepare for segue method when called. This is necessary since the label outlets are still nil when prepare for segue is called, so can't be set directly.
    [self.eventTitle setText:self.eventTitleStr];
    [self.eventSchedule setText:self.eventScheduleStr];
    
    // Check to see if a reminder has already been created for the event.
    // If yes, show the appropriate styling
    if ([self.primaryDetailsDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:self.eventType])
    {
        [self.reminderButton setBackgroundColor:[UIColor grayColor]];
        [self.reminderButton setTitle:@"REMINDER SET" forState:UIControlStateNormal];
        [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    // If not, show the appropriate styling
    else
    {
        // TO DO: Finally decide between this currently set blue and purple color
        [self.reminderButton setBackgroundColor:[UIColor colorWithRed:78.0f/255.0f green:132.0f/255.0f blue:216.0f/255.0f alpha:1.0f]];
        //[self.reminderButton setBackgroundColor:[UIColor colorWithRed:81.0f/255.0f green:54.0f/255.0f blue:127.0f/255.0f alpha:1.0f]];
        [self.reminderButton setTitle:@"REMIND ME" forState:UIControlStateNormal];
        [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    // Register a listener for guidance messages to be shown to the user in the messages bar
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userGuidanceGenerated:)
                                                 name:@"UserGuidanceCreated" object:nil];
    
    // Register a listener for queued reminders to be created now that they have been confirmed
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(createQueuedReminder:)
                                                 name:@"CreateQueuedReminder" object:nil];
    
    // Register a listener for changes to the event history that's stored locally
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(eventHistoryDataChanged:)
                                                 name:@"EventHistoryUpdated" object:nil];
    
    // If there is no connectivity, it's safe to assume that it wasn't there when the user segued so today's data, might not be available. Show a guidance message to the user accordingly
    if (![self checkForInternetConnectivity]) {
        
        NSLog(@"ENTERED THE CHECK FOR NO CONNECTION.");
        [self sendUserGuidanceCreatedNotificationWithMessage:@"Hmm! No Connection. Data might be outdated."];
    }
    
    // This will remove extra separators from the bottom of the tableview which doesn't have any cells
    self.eventDetailsTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

#pragma mark - Event Details Table

// Return number of sections in the events list table view
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSLog(@"Number of sections in event details table view returned");
    // There's only one section for now
    return 1;
}

// Set the header for the table view to a special table cell that serves as header.
-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UITableViewCell *headerView = nil;
    
    headerView = [tableView dequeueReusableCellWithIdentifier:@"EventDetailsTableHeader"];
    return headerView;
}

// Return number of rows in the events list table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Currently number of rows of events related data is 4: Expected EPS, Prior EPS, Change in price since end of prior quarter, Change in price since previous earnings call.
    NSInteger numberOfRows = 4;
    
    return numberOfRows;
}

// Return a cell configured to display the event details based on the cell number. Currently 4 types of data points are available.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Get a custom cell to display details and reset states/colors of cell elements to avoid carryover
    FAEventDetailsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventDetailsCell" forIndexPath:indexPath];
    [[cell associatedValue1] setHidden:NO];
    [[cell additionalValue] setHidden:NO];
    [[cell descriptionAddtlPart] setHidden:NO];
    cell.associatedValue1.textColor = [UIColor darkGrayColor];
    cell.associatedValue2.textColor = [UIColor darkGrayColor];
    
    // Assign a row no to the type of event detail row. Currently number of rows of events related data is 4: Expected EPS, Prior EPS, Change in price since end of prior quarter, Change in price since previous earnings call.
    #define expectedEpsRow  0
    #define priorEpsRow  1
    #define changeSincePrevQuarter 2
    #define changeSincePrevEarnings 3
    
    // Define date formatters that will be used later
    // 1. Jun 30 2015
    NSDateFormatter *monthDateYearFormatter = [[NSDateFormatter alloc] init];
    [monthDateYearFormatter setDateFormat:@"MMM dd yyyy"];
    
    // Define number formatters to be used later.
    NSNumberFormatter *decimal2Formatter = [[NSNumberFormatter alloc] init];
    [decimal2Formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [decimal2Formatter setMaximumFractionDigits:2];
    [decimal2Formatter setRoundingMode: NSNumberFormatterRoundUp];
    
    // Set a value indicating that a value is not available. Currently a Not Available value
    // is represented by
    double notAvailable = 999999.9f;

    // Get Row no
    int rowNo = (int)indexPath.row;
    
    // Get the event details parts of which will be displayed in the details table
    Event *eventData = [self.primaryDetailsDataController getEventForParentEventTicker:self.parentTicker andEventType:self.eventType];
    
    // Get the event history to be displayed as the details based on parent company ticker and event type. Assumption is that ticker and event type uniquely identify an event.
    EventHistory *eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:self.parentTicker parentEventType:self.eventType];
    
    // Display the appropriate details based on the row no
    switch (rowNo) {
            
        case expectedEpsRow:
        {
            [[cell descriptionPart1] setText:@"Expected earnings per share for"];
            // Get the related date from the event which is the quarter end that is going to be reported
            NSString *relatedDateString = [NSString stringWithFormat:@"quarter ended %@", [monthDateYearFormatter stringFromDate:eventData.relatedDate]];
            [[cell descriptionPart2] setText:relatedDateString];
            [[cell descriptionAddtlPart] setText:@"Estimated"];
            // Set color to the bright blue
            cell.associatedValue2.textColor = [UIColor colorWithRed:35.0f/255.0f green:127.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            [[cell associatedValue2] setText:[decimal2Formatter stringFromNumber:eventData.estimatedEps]];
            // Hide other value labels as they are empty
            [[cell associatedValue1] setHidden:YES];
            [[cell additionalValue] setHidden:YES];
        }
        break;
            
        case priorEpsRow:
        {
            [[cell descriptionPart1] setText:@"Earnings per share for prior"];
            // Get the prior end date from the event which is the end date of previously reported quarter
            NSString *priorEndDateString = [NSString stringWithFormat:@"quarter ended %@", [monthDateYearFormatter stringFromDate:eventData.priorEndDate]];
            [[cell descriptionPart2] setText:priorEndDateString];
            [[cell descriptionAddtlPart] setText:@"Reported"];
            // Set color to the bright blue
            cell.associatedValue2.textColor = [UIColor colorWithRed:35.0f/255.0f green:127.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            [[cell associatedValue2] setText:[decimal2Formatter stringFromNumber:eventData.actualEpsPrior]];
            // Hide other value labels as they are empty
            [[cell associatedValue1] setHidden:YES];
            [[cell additionalValue] setHidden:YES];
        }
        break;
            
        case changeSincePrevQuarter:
        {
            [[cell descriptionPart1] setText:@"Change in stock price since"];
            [[cell descriptionPart2] setText:@"end of prior reported quarter"];
            // Get the prior end date from the event which is the end date of previously reported quarter
            NSString *priorEndDateToYestString = [NSString stringWithFormat:@"%@ - Yesterday", [monthDateYearFormatter stringFromDate:eventData.priorEndDate]];
            [[cell descriptionAddtlPart] setText:priorEndDateToYestString];
            // Calculate the difference in stock prices from end of prior quarter to yesterday, if both of them are available, format and display them
            double prev1RelatedPriceDbl = [[eventHistoryData previous1RelatedPrice] doubleValue];
            double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
            // TO DO: Delete Later after testing
            NSLog(@"For Ticker %@ Previous Related Event 1 Price is %f and current price is %f",self.parentTicker,prev1RelatedPriceDbl,currentPriceDbl);
            NSLog(@"Not available double value is %f",notAvailable);
            if ((prev1RelatedPriceDbl != notAvailable)&&(currentPriceDbl != notAvailable))
            {
                double priceDiff = currentPriceDbl - prev1RelatedPriceDbl;
                double priceDiffAbs = fabs(priceDiff);
                double percentageDiff = (100 * priceDiff)/prev1RelatedPriceDbl;
                NSString *priceDiffString = nil;
                NSString *percentageDiffString = nil;
                NSString *pricesString = nil;
                if(priceDiff < 0)
                {
                    priceDiffString = [NSString stringWithFormat:@"-%.1f", priceDiffAbs];
                    percentageDiffString = [NSString stringWithFormat:@"%.1f%%", percentageDiff];
                    // Set color to Red
                    cell.associatedValue1.textColor = [UIColor colorWithRed:255.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    cell.associatedValue2.textColor = [UIColor colorWithRed:255.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    [[cell associatedValue1] setText:priceDiffString];
                    [[cell associatedValue2] setText:percentageDiffString];
                }
                else
                {
                    priceDiffString = [NSString stringWithFormat:@"+%.1f", priceDiffAbs];
                    percentageDiffString = [NSString stringWithFormat:@"%.1f%%", percentageDiff];
                    // Set color to Green
                    cell.associatedValue1.textColor = [UIColor colorWithRed:0.0f/255.0f green:168.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    cell.associatedValue2.textColor = [UIColor colorWithRed:0.0f/255.0f green:168.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    [[cell associatedValue1] setText:priceDiffString];
                    [[cell associatedValue2] setText:percentageDiffString];
                }
                pricesString = [NSString stringWithFormat:@"%.2f - %.2f", prev1RelatedPriceDbl, currentPriceDbl];
                [[cell additionalValue] setText:pricesString];
            }
            // If not available, display an appropriately formatted NA
            else
            {
                [[cell associatedValue2] setText:@"NA"];
                // Hide other value labels as they are empty
                [[cell associatedValue1] setHidden:YES];
                [[cell additionalValue] setHidden:YES];
                // Hide the additional description as that is not valid as well
                [[cell descriptionAddtlPart] setHidden:YES];
            }
        }
        break;
            
        case changeSincePrevEarnings:
        {
            [[cell descriptionPart1] setText:@"Change in stock price since"];
            [[cell descriptionPart2] setText:@"estimated prior earnings day"];
            // Get the prior end date from the event which is the end date of previously reported quarter
            NSString *priorEarningsDateToYestString = [NSString stringWithFormat:@"%@ - Yesterday", [monthDateYearFormatter stringFromDate:eventHistoryData.previous1Date]];
            [[cell descriptionAddtlPart] setText:priorEarningsDateToYestString];
            // Calculate the difference in stock prices from end of prior quarter to yesterday, if both of them are available, format and display them
            double prev1PriceDbl = [[eventHistoryData previous1Price] doubleValue];
            double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
            // TO DO: For Testing Delete Later
            NSLog(@"For Ticker %@ Previous Event 1 Price is %f and current price is %f",self.parentTicker,prev1PriceDbl,currentPriceDbl);
            if ((prev1PriceDbl != notAvailable)&&(currentPriceDbl != notAvailable))
            {
                double priceDiff = currentPriceDbl - prev1PriceDbl;
                double priceDiffAbs = fabs(priceDiff);
                double percentageDiff = (100 * priceDiff)/prev1PriceDbl;
                NSString *priceDiffString = nil;
                NSString *percentageDiffString = nil;
                NSString *pricesString = nil;
                if(priceDiff < 0)
                {
                    priceDiffString = [NSString stringWithFormat:@"-%.1f", priceDiffAbs];
                    percentageDiffString = [NSString stringWithFormat:@"%.1f%%", percentageDiff];
                    // Set color to Red
                    cell.associatedValue1.textColor = [UIColor colorWithRed:255.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    cell.associatedValue2.textColor = [UIColor colorWithRed:255.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    [[cell associatedValue1] setText:priceDiffString];
                    [[cell associatedValue2] setText:percentageDiffString];
                }
                else
                {
                    priceDiffString = [NSString stringWithFormat:@"+%.1f", priceDiffAbs];
                    percentageDiffString = [NSString stringWithFormat:@"%.1f%%", percentageDiff];
                    // Set color to Green
                    cell.associatedValue1.textColor = [UIColor colorWithRed:0.0f/255.0f green:168.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    cell.associatedValue2.textColor = [UIColor colorWithRed:0.0f/255.0f green:168.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    [[cell associatedValue1] setText:priceDiffString];
                    [[cell associatedValue2] setText:percentageDiffString];
                }
                pricesString = [NSString stringWithFormat:@"%.2f - %.2f", prev1PriceDbl, currentPriceDbl];
                [[cell additionalValue] setText:pricesString];
            }
            // If not available, display an appropriately formatted NA
            else
            {
                [[cell associatedValue2] setText:@"NA"];
                // Hide other value labels as they are empty
                [[cell associatedValue1] setHidden:YES];
                [[cell additionalValue] setHidden:YES];
                // Hide the additional description as that is not valid as well
                [[cell descriptionAddtlPart] setHidden:YES];
            }
        }
        break;
            
        default:
            
        break;
    }
    
    return cell;
}

#pragma mark - Reminder Related

// Action to take when Reminder button is pressed, which is set a reminder if reminder hasn't already been created, else display a message that reminder has aleady been set.
- (IBAction)reminderAction:(id)sender {
    
    // Check to see if a reminder has already been created for the event.
    // If yes let the user know a reminder is already set for this ticker.
    if ([self.primaryDetailsDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:self.eventType])
    {
        [self sendUserGuidanceCreatedNotificationWithMessage:@"Already set to be reminded of this event a day before."];
    }
    
    // If not, create the reminder and style the button to post set styling
    else
    {
        NSLog(@"Clicked the Set Reminder Action with ticker %@",self.parentTicker);
        // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
        [self requestAccessToUserEventStoreAndProcessReminderWithEventType:self.eventType companyTicker:self.parentTicker eventDateText:self.eventDateText eventCertainty:self.eventCertainty withDataController:self.primaryDetailsDataController];
        
        // Style the button to post set styling
        [self.reminderButton setBackgroundColor:[UIColor grayColor]];
        [self.reminderButton setTitle:@"REMINDER SET" forState:UIControlStateNormal];
        [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
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
- (void)requestAccessToUserEventStoreAndProcessReminderWithEventType:(NSString *)eventType companyTicker:(NSString *)parentTicker eventDateText:(NSString *)evtDateText eventCertainty:(NSString *)evtCertainty withDataController:(FADataController *)appropriateDataController {
    
    // Get the current access status to the user's event store for event type reminder.
    EKAuthorizationStatus accessStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder];
    
    // Depending on the current access status, choose what to do. Idea is to request access from a user
    // only if he hasn't granted it before.
    switch (accessStatus) {
            
            // If the user hasn't provided access, show an appropriate error message.
        case EKAuthorizationStatusDenied:
        case EKAuthorizationStatusRestricted: {
            NSLog(@"Authorization Status for Reminders is Denied or Restricted");
            [self sendUserGuidanceCreatedNotificationWithMessage:@"Enable Reminders under Settings>Knotifi and try again!"];
            break;
        }
            
            // If the user has already provided access, create the reminder.
        case EKAuthorizationStatusAuthorized: {
            NSLog(@"Authorization Status for Reminders is Provided. About to create the reminder");
            [self processReminderForEventType:eventType companyTicker:parentTicker eventDateText:evtDateText eventCertainty:evtCertainty withDataController:appropriateDataController];
            break;
        }
            
            // If the app hasn't requested access or the user hasn't decided yet, present the user with the
            // authorization dialog. If the user approves create the reminder. If user rejects, show error message.
        case EKAuthorizationStatusNotDetermined: {
            
            // create a weak reference to the controller, since you want to create the reminder, in
            // a non main thread where the authorization dialog is presented.
            __weak FAEventDetailsViewController *weakPtrToSelf = self;
            [self.userEventStore requestAccessToEntityType:EKEntityTypeReminder
                                                completion:^(BOOL grantedByUser, NSError *error) {
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                        if (grantedByUser) {
                                                            NSLog(@"Authorization Status for Reminders was enabled by user. About to create the reminder");
                                                            // Create a new Data Controller so that this thread has it's own MOC
                                                            FADataController *afterAccessDataController = [[FADataController alloc] init];
                                                            //[weakPtrToSelf processReminderForEventInCell:eventCell withDataController:afterAccessDataController];
                                                            [weakPtrToSelf processReminderForEventType:eventType companyTicker:parentTicker eventDateText:evtDateText eventCertainty:evtCertainty withDataController:afterAccessDataController];
                                                        } else {
                                                            NSLog(@"Authorization Status for Reminderswas rejected by user.");
                                                            [weakPtrToSelf sendUserGuidanceCreatedNotificationWithMessage:@"Enable Reminders under Settings>Knotifi and try again!"];
                                                        }
                                                    });
                                                }];
            break;
        }
    }
}

// Process the "Remind Me" action for the event represented by the cell on which the action was taken. If the event is confirmed, create the reminder immediately and make an appropriate entry in the Action data store. If it's estimated, then don't create the reminder, only make an appropriate entry in the action data store for later processing.
- (void)processReminderForEventType:(NSString *)eventType companyTicker:(NSString *)parentTicker eventDateText:(NSString *)evtDateText eventCertainty:(NSString *)evtCertainty withDataController:(FADataController *)appropriateDataController {
    
    // NOTE: Format for Event Type is expected to be "Quarterly Earnings" based on "Quarterly" that comes from the UI.
    // If the formatting changes, it needs to be changed here to accomodate as well.
    NSString *cellEventType = eventType;
    NSString *cellCompanyTicker = parentTicker;
    NSString *cellEventDateText = evtDateText;
    NSString *cellEventCertainty = evtCertainty;
    
    NSLog(@"Event Cell type is:%@ Ticker is:%@ DateText is:%@ and Certainty is:%@", cellEventType, cellCompanyTicker, cellEventDateText, cellEventCertainty);
    
    // Check to see if the event represented by the cell is estimated or confirmed ?
    // If confirmed create and save to action data store
    if ([cellEventCertainty isEqualToString:@"Confirmed"]) {
        
        NSLog(@"About to create a reminder, since this event is confirmed");
        
        // Create the reminder and show user the appropriate message
        BOOL success = [self createReminderForEventOfType:cellEventType withTicker:cellCompanyTicker dateText:cellEventDateText andDataController:appropriateDataController];
        if (success) {
            NSLog(@"Successfully created the reminder");
            [self sendUserGuidanceCreatedNotificationWithMessage:@"All Set! You'll be reminded of this event a day before."];
            // Add action to the action data store with status created
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:cellCompanyTicker eventType:cellEventType];
        } else {
            NSLog(@"Actual Reminder Creation failed");
            [self sendUserGuidanceCreatedNotificationWithMessage:@"Oops! Unable to create a reminder for this event."];
        }
    }
    // If estimated add to action data store for later processing
    else if ([cellEventCertainty isEqualToString:@"Estimated"]) {
        
        NSLog(@"About to queue a reminder for later creation, since this event is not confirmed");
        
        // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
        [appropriateDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:cellCompanyTicker eventType:cellEventType];
        [self sendUserGuidanceCreatedNotificationWithMessage:@"All Set! You'll be reminded of this event a day before."];
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
}


#pragma mark - Notifications

// Send a notification that there's guidance messge to be presented to the user
- (void)sendUserGuidanceCreatedNotificationWithMessage:(NSString *)msgContents {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"UserGuidanceCreated" object:msgContents];
    NSLog(@"NOTIFICATION FIRED: With Guidance Message: %@",msgContents);
}

#pragma mark - Change Listener Responses

// Refresh the Events Data Table when newer data is available
- (void)eventHistoryDataChanged:(NSNotification *)notification {
    
    // Create a new DataController so that this thread has its own MOC
    // TO DO: Understand at what point does a new thread get spawned off. Seems to me the new thread is being created for
    // reloading the table. SHouldn't I be creating the new MOC in that thread as opposed to here ? Maybe it doesn't matter
    // as long as I am not sharing MOCs across threads ? The general rule with Core Data is one Managed Object Context per thread, and one thread per MOC
    // FADataController *historyDataController = [[FADataController alloc] init];
    // self.eventResultsController = [secondaryDataController getAllEvents];
    [self.eventDetailsTable reloadData];
    NSLog(@"*******************************************Event History Changed listener fired to refresh table");
}

// Take a queued reminder and create it in the user's OS Reminders now that the event has been confirmed.
// The notification object contains an array of strings representing {eventType,companyTicker,eventDateText}
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

// Show the error message for a temporary period and then fade it if a user guidance message has been generated
// TO DO: Currently set to 20 seconds. Change as you see fit.
- (void)userGuidanceGenerated:(NSNotification *)notification {
    
    // Make sure the message bar is empty and visible to the user
    self.messagesArea.text = @"";
    self.messagesArea.alpha = 1.0;
    
    NSLog(@"NOTIFICATION ABOUT TO BE SHOWN: With User Guidance Message: %@",[notification object]);
    
    // Show the message that's generated for a period of 20 seconds
    [UIView animateWithDuration:20 animations:^{
        self.messagesArea.text = [notification object];
        self.messagesArea.alpha = 0;
    }];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/* #pragma mark - Navigation


// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
} */

@end
