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
#import "FACompanyInfoStore.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
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
    
    // Do any additional setup after loading the view.
    
    // Initialize the Company Info local data store
    [FACompanyInfoStore sharedInfoStore];
    
    // Make the information messages area fully transparent so that it's invisible to the user
    self.messagesArea.alpha = 0.0;
    
    // Ensure that the busy spinner is not animating thus hidden
    [self.busySpinner stopAnimating];
    
    // Get a primary data controller that you will use later
    self.primaryDetailsDataController = [[FADataController alloc] init];
    
    // Show event type in the navigation bar header.
    self.navigationItem.title = [self.eventType uppercaseString];
    
    // Set the labels to the strings that hold their text. These strings will be set in the prepare for segue method when called. This is necessary since the label outlets are still nil when prepare for segue is called, so can't be set directly.
    [self.eventTitle setText:[self.eventTitleStr uppercaseString]];
    [self.eventSchedule setText:[self.eventScheduleStr uppercaseString]];
    
    // Check to see if a reminder has already been created for the event.
    // If yes, show the appropriate styling
    if ([self.primaryDetailsDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:self.eventType])
    {
        [self.reminderButton setBackgroundColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
        [self.reminderButton setTitle:@"REMINDER SET" forState:UIControlStateNormal];
        [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    // If not, show the appropriate styling
    else
    {
        // Modified Knotifi Green
        [self.reminderButton setBackgroundColor:[UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f]];
        [self.reminderButton setTitle:@"REMIND ME" forState:UIControlStateNormal];
        [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    // Register a listener for guidance messages to be shown to the user in the messages bar
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userGuidanceGenerated:)
                                                 name:@"UserGuidanceCreated" object:nil];
    
    
    // Register a listener for changes to the event history that's stored locally
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(eventHistoryDataChanged:)
                                                 name:@"EventHistoryUpdated" object:nil];
    
    // If there is no connectivity, it's safe to assume that it wasn't there when the user segued so today's data, might not be available. Show a guidance message to the user accordingly
    if (![self checkForInternetConnectivity]) {
        
        [self sendUserGuidanceCreatedNotificationWithMessage:@"Hmm! No Connection. Data might be outdated."];
    }
    
    // This will remove extra separators from the bottom of the tableview which doesn't have any cells
    self.eventDetailsTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    // TO DO: Delete before shipping v2
    //NSLog(@"Event Type in Details is: %@ and Parent Ticker is:%@",self.eventType,self.parentTicker);
}

#pragma mark - Event Details Table

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
        //headerView = [tableView dequeueReusableCellWithIdentifier:@"EventDetailsTableHeader"];
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
        
        // Set title. Don't use a title for related data table anymore.
        // sectionTitle = @"RELATED DATA";
    }
    
    return sectionTitle;
}*/

// Set the table header to 0 height as we don't need this for the details table.
// TO DO: Test on the ipad and then remove the above 2 header related methods as they are no longer needed.
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    
    return 0.0;
}

// Return number of rows in the events list table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self getNoOfInfoPiecesForEventType];
}

// Return a cell configured to display the event details based on the cell number and event type. Currently upto 5 types of information pieces are available.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    EventHistory *eventHistoryData;
    
    // Get a custom cell to display details and reset states/colors of cell elements to avoid carryover
    FAEventDetailsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventDetailsCell" forIndexPath:indexPath];
    
    // Assign a row no to the type of event detail row. Currently upto 5 types of related info pieces are available.
    #define infoRow1  0
    #define infoRow2  1
    #define infoRow3  2
    #define infoRow4  3
    #define infoRow5  4
    
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
    
    // Get the event history, only if the event type is quarterly earnings, to be displayed as the details based on parent company ticker and event type. Assumption is that ticker and event type uniquely identify an event.
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:self.parentTicker parentEventType:self.eventType];
    }
    
    // Display the appropriate details based on the row no
    // TO DO: SOLIDIFY LATER: Currently we use the event data to get the previous related date in expectedEps, priorEps, changeSincePrevQuarter. The scrubbed version of the previous related date (updated if it was on a weekend) is stored in the event history so that the stock price can be fetched. This is working fine for now but might want to rethink this.
    switch (rowNo) {
        
        // Display a short description of the event along with the related static image.
        case infoRow1:
        {
            [[cell descriptionArea] setText:[self getShortDescriptionForEventType:self.eventType parentCompanyName:self.parentCompany]];
            cell.titleLabel.backgroundColor = [UIColor colorWithPatternImage:[self getImageBasedOnEventType:self.eventType]];
        }
        break;
            
        // Display Expected EPS or Impact Level depending on the event type
        case infoRow2:
        {
            // Description
            [[cell descriptionArea] setText:[self getEpsOrImpactTextForEventType:self.eventType eventParent:self.parentTicker]];
            
            // Value for Quarterl Earnings
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                // Econ Blue Color
                cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:[decimal2Formatter stringFromNumber:eventData.estimatedEps]];
            }
            // Impact Image bars for all others
            else {
                // Very High, High Impact
                if ([cell.descriptionArea.text containsString:@"High Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"||||||||||"];
                }
                // Medium Impact
                if ([cell.descriptionArea.text containsString:@"Medium Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:255.0f/255.0f green:127.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"||||||"];
                }
                // Low Impact
                if ([cell.descriptionArea.text containsString:@"Low Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:207.0f/255.0f green:187.0f/255.0f blue:29.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"||||"];
                }
            }
    
            // TO DO: Delete before shipping v 2.5
           /* if ([self.eventType containsString:@"Fed Meeting"]) {
                // Select the appropriate color and text for Very High Impact
                cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"||||||||||"];
            }
            
            if ([self.eventType containsString:@"Jobs Report"]) {
                // Select the appropriate color and text for Very High Impact
                cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"||||||||||"];
            }
            
            if ([self.eventType containsString:@"Consumer Confidence"]) {
                // Select the appropriate color and text for Medium Impact
                cell.titleLabel.textColor = [UIColor colorWithRed:255.0f/255.0f green:127.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"|||||"];
            }
            
            if ([self.eventType containsString:@"GDP Release"]) {
                // Select the appropriate color and text for Medium Impact
                cell.titleLabel.textColor = [UIColor colorWithRed:255.0f/255.0f green:127.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"|||||"];
            }*/
        }
        break;
        
        // Display Prior EPS or Sectors Affected depending on the event type
        case infoRow3:
        {
            // Text
            [[cell descriptionArea] setText:[self getEpsOrSectorsTextForEventType:self.eventType]];
            
            // Value
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                // Econ Blue Color
                cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:[decimal2Formatter stringFromNumber:eventData.actualEpsPrior]];
            }
            
            if ([self.eventType containsString:@"Fed Meeting"]) {
                // Select the appropriate color and text for Financial Stocks
                cell.titleLabel.textColor = [UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"$$"];
            }
            
            if ([self.eventType containsString:@"Jobs Report"]) {
                // Select the appropriate color and text for All Stocks
                cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"All"];
            }
            
            if ([self.eventType containsString:@"Consumer Confidence"]) {
                // Select the appropriate color and text for Retail Stocks
                cell.titleLabel.textColor = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"Sale!"];
            }
            
            if ([self.eventType containsString:@"GDP Release"]) {
                // Select the appropriate color and text for All Stocks
                cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"All"];
            }
        }
        break;
        
        // Display Price Change Since Previous Quarter end or Tip depending on the event type
        case infoRow4:
        {
            // Text
            // Get the prior end date from the event which is the end date of previously reported quarter
            NSString *priorEndDateToYestString = [NSString stringWithFormat:@"%@ - Yesterday", [monthDateYearFormatter stringFromDate:eventData.priorEndDate]];
            [[cell descriptionArea] setText:[self getPriceSinceOrTipTextForEventType:self.eventType additionalInfo:priorEndDateToYestString]];
            
            // Value
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                
                // Calculate the difference in stock prices from end of prior quarter to yesterday, if both of them are available, format and display them
                double prev1RelatedPriceDbl = [[eventHistoryData previous1RelatedPrice] doubleValue];
                double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
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
                        cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                        [[cell titleLabel] setText:percentageDiffString];
                    }
                    else
                    {
                        priceDiffString = [NSString stringWithFormat:@"+%.1f", priceDiffAbs];
                        percentageDiffString = [NSString stringWithFormat:@"%.1f%%", percentageDiff];
                        // Set color to Green
                        cell.titleLabel.textColor = [UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f];
                        [[cell titleLabel] setText:percentageDiffString];
                    }
                    pricesString = [NSString stringWithFormat:@"%.2f - %.2f", prev1RelatedPriceDbl, currentPriceDbl];
                }
                // If not available, display an appropriately formatted NA
                else
                {
                    [[cell titleLabel] setText:@"NA"];
                }
            }
            
            if ([self.eventType containsString:@"Fed Meeting"]) {
                // Select the appropriate color and text for Pro Tip
                cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"!!"];
            }
            
            if ([self.eventType containsString:@"Jobs Report"]) {
                // Select the appropriate color and text for Pro Tip
                cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"!!"];
            }
            
            if ([self.eventType containsString:@"Consumer Confidence"]) {
                // Select the appropriate color and text for Pro Tip
                cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"!!"];
            }
            
            if ([self.eventType containsString:@"GDP Release"]) {
                // Select the appropriate color and text for Pro Tip
                cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"!!"];
            }
        }
        break;
        
        // Display price change since estimated prior earnings date
        case infoRow5:
        {
            // Text
            // Get the prior end date from the event which is the estimated prior earnings date
            NSString *priorEarningsDateToYestString = [NSString stringWithFormat:@"%@ - Yesterday", [monthDateYearFormatter stringFromDate:eventHistoryData.previous1Date]];
            [[cell descriptionArea] setText:[self getPriceSincePriorEstimatedEarningsDate:self.eventType additionalInfo:priorEarningsDateToYestString]];
            
            // Value
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                
                // Calculate the difference in stock prices from end of prior quarter to yesterday, if both of them are available, format and display them
                double prev1PriceDbl = [[eventHistoryData previous1Price] doubleValue];
                double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
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
                        cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                        [[cell titleLabel] setText:percentageDiffString];
                    }
                    else
                    {
                        priceDiffString = [NSString stringWithFormat:@"+%.1f", priceDiffAbs];
                        percentageDiffString = [NSString stringWithFormat:@"%.1f%%", percentageDiff];
                        // Set color to Green
                        cell.titleLabel.textColor = [UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f];
                        [[cell titleLabel] setText:percentageDiffString];
                    }
                    pricesString = [NSString stringWithFormat:@"%.2f - %.2f", prev1PriceDbl, currentPriceDbl];
                }
                // If not available, display an appropriately formatted NA
                else
                {
                    [[cell titleLabel] setText:@"NA"];
                }
            }
            
            if ([self.eventType containsString:@"Fed Meeting"]) {
                // Just in case
                [[cell titleLabel] setText:@"NA"];
            }
            
            if ([self.eventType containsString:@"Jobs Report"]) {
                // Just in case
                [[cell titleLabel] setText:@"NA"];
            }
            
            if ([self.eventType containsString:@"Consumer Confidence"]) {
                // Just in case
                [[cell titleLabel] setText:@"NA"];
            }
            
            if ([self.eventType containsString:@"GDP Release"]) {
                // Just in case
                [[cell titleLabel] setText:@"NA"];
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
        
        // TRACKING EVENT: Unset Reminder: User clicked the "Reminder Set" button, most likely to unset the reminder.
        // TO DO: Disabling to not track development events. Enable before shipping.
        /*[FBSDKAppEvents logEvent:@"Unset Reminder"
                      parameters:@{ @"Ticker" : self.parentTicker,
                                    @"Event Certainty" : self.eventCertainty } ];*/
    }
    
    // If not, create the reminder and style the button to post set styling
    else
    {
        // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
        [self requestAccessToUserEventStoreAndProcessReminderWithEventType:self.eventType companyTicker:self.parentTicker eventDateText:self.eventDateText eventCertainty:self.eventCertainty withDataController:self.primaryDetailsDataController];
        
        // Style the button to post set styling
        [self.reminderButton setBackgroundColor:[UIColor grayColor]];
        [self.reminderButton setTitle:@"REMINDER SET" forState:UIControlStateNormal];
        [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        // TRACKING EVENT: Create Reminder: User clicked the "Set Reminder" button to create a reminder.
        // TO DO: Disabling to not track development events. Enable before shipping.
        /*[FBSDKAppEvents logEvent:@"Create Reminder"
                      parameters:@{ @"Ticker" : self.parentTicker,
                                    @"Event Certainty" : self.eventCertainty } ];*/
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
            [self sendUserGuidanceCreatedNotificationWithMessage:@"Enable Reminders under Settings>Knotifi and try again!"];
            break;
        }
            
            // If the user has already provided access, create the reminder.
        case EKAuthorizationStatusAuthorized: {
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
                                                            // Create a new Data Controller so that this thread has it's own MOC
                                                            FADataController *afterAccessDataController = [[FADataController alloc] init];
                                                            //[weakPtrToSelf processReminderForEventInCell:eventCell withDataController:afterAccessDataController];
                                                            [weakPtrToSelf processReminderForEventType:eventType companyTicker:parentTicker eventDateText:evtDateText eventCertainty:evtCertainty withDataController:afterAccessDataController];
                                                        } else {
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
    
    // NOTE: Format for Event Type is expected to be "Quarterly Earnings"  based on "Earnings" or "Jan Fed Meeting" based on "Fed Meeting" that comes from the UI.
    // If the formatting changes, it needs to be changed here to accomodate as well.
    NSString *cellEventType = eventType;
    NSString *cellCompanyTicker = parentTicker;
    NSString *cellEventDateText = evtDateText;
    NSString *cellEventCertainty = evtCertainty;
    
    // Check to see if the event is of type Earnings or Economic event
    // Based on event type and what's available, return the no of pieces of information.
    if ([cellEventType isEqualToString:@"Quarterly Earnings"]) {
        
        // Check to see if the event represented by the cell is estimated or confirmed ?
        // If confirmed create and save to action data store
        if ([cellEventCertainty isEqualToString:@"Confirmed"]) {
            
            // Create the reminder and show user the appropriate message
            BOOL success = [self createReminderForEventOfType:cellEventType withTicker:cellCompanyTicker dateText:cellEventDateText andDataController:appropriateDataController];
            if (success) {
                [self sendUserGuidanceCreatedNotificationWithMessage:@"All Set! You'll be reminded of this event a day before."];
                // Add action to the action data store with status created
                [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:cellCompanyTicker eventType:cellEventType];
            } else {
                [self sendUserGuidanceCreatedNotificationWithMessage:@"Oops! Unable to create a reminder for this event."];
            }
        }
        // If estimated add to action data store for later processing
        else if ([cellEventCertainty isEqualToString:@"Estimated"]) {
            
            // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:cellCompanyTicker eventType:cellEventType];
            [self sendUserGuidanceCreatedNotificationWithMessage:@"All Set! You'll be reminded of this event a day before."];
        }
    }
    if ([cellEventType containsString:@"Fed Meeting"]||[cellEventType containsString:@"Jobs Report"]||[cellEventType containsString:@"Consumer Confidence"]||[cellEventType containsString:@"GDP Release"]) {
        
        // Create the reminder and show user the appropriate message
        BOOL success = [self createReminderForEventOfType:cellEventType withTicker:cellCompanyTicker dateText:cellEventDateText andDataController:appropriateDataController];
        if (success) {
            [self sendUserGuidanceCreatedNotificationWithMessage:@"All Set! You'll be reminded of this event a day before."];
            // Add action to the action data store with status created
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:cellCompanyTicker eventType:cellEventType];
        } else {
            [self sendUserGuidanceCreatedNotificationWithMessage:@"Oops! Unable to create a reminder for this event."];
        }
    }
}

// Actually create the reminder in the user's default calendar and return success or failure depending on the outcome.
- (BOOL)createReminderForEventOfType:(NSString *)eventType withTicker:(NSString *)companyTicker dateText:(NSString *)eventDateText andDataController:(FADataController *)reminderDataController  {
    
    BOOL creationSuccess = NO;
    NSString *reminderText = @"An earnings Call of interest is tomorrow.";
    
    // Set title of the reminder to the reminder text, based on event type
    EKReminder *eventReminder = [EKReminder reminderWithEventStore:self.userEventStore];
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        reminderText = [NSString stringWithFormat:@"%@ %@ tomorrow %@", companyTicker,eventType,eventDateText];
    }
    if ([eventType containsString:@"Fed Meeting"]||[eventType containsString:@"Jobs Report"]||[eventType containsString:@"Consumer Confidence"]||[eventType containsString:@"GDP Release"]) {
        reminderText = [NSString stringWithFormat:@"%@ tomorrow %@", eventType,eventDateText];
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


#pragma mark - Notifications

// Send a notification that there's guidance messge to be presented to the user
- (void)sendUserGuidanceCreatedNotificationWithMessage:(NSString *)msgContents {
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"UserGuidanceCreated" object:msgContents];
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
}

// Show the error message for a temporary period and then fade it if a user guidance message has been generated
// TO DO: Currently set to 20 seconds. Change as you see fit.
- (void)userGuidanceGenerated:(NSNotification *)notification {
    
    // Make sure the message bar is empty and visible to the user
    self.messagesArea.text = @"";
    self.messagesArea.alpha = 1.0;
    
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

#pragma mark - Event Info Related

// Depending on the event type return the number of related information pieces available. Currently: Quarterly Earnings -> 5 possible info pieces: Short Description, Expected Eps, Prior Eps, ChangeSincePriorQuarter, ChangeSincePriorEarnings. Jan Fed Meeting -> 4 possible info pieces: Short Description, Impact, SectorsAffected, Tips). NOTE: If any of these pieces is not available that piece will not be counted.
- (NSInteger)getNoOfInfoPiecesForEventType
{
    NSInteger numberOfPieces = 0;
    
    // Set a value indicating that a value is not available. Currently a Not Available value is represented by
    double notAvailable = 999999.9f;
    EventHistory *eventHistoryData;
    
    // Based on event type and what's available, return the no of pieces of information.
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        
        numberOfPieces = 5;
        // Get the event history.
        eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:self.parentTicker parentEventType:self.eventType];
        
        // Check to see if stock prices at end of prior quarter and yesterday are available.If yes, then return 5 pieces. If not then return 3 pieces (desc, expected eps, prior eps)
        double prev1RelatedPriceDbl = [[eventHistoryData previous1RelatedPrice] doubleValue];
        double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
        if ((prev1RelatedPriceDbl != notAvailable)&&(currentPriceDbl != notAvailable)) {
            numberOfPieces = 5;
        } else {
            numberOfPieces = 3;
        }
    }
    
    if ([self.eventType containsString:@"Fed Meeting"]) {
        numberOfPieces = 4;
    }
    
    if ([self.eventType containsString:@"Jobs Report"]) {
        numberOfPieces = 4;
    }
    
    if ([self.eventType containsString:@"Consumer Confidence"]) {
        numberOfPieces = 4;
    }
    
    if ([self.eventType containsString:@"GDP Release"]) {
        numberOfPieces = 4;
    }
    
    if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
        numberOfPieces = 5;
    }
        
    return numberOfPieces;
}

// Get short description of event given event type. Currently this is hardcoded.
// FUTURE TO DO: Get this into the event data model.
- (NSString *)getShortDescriptionForEventType:(NSString *)eventType parentCompanyName:(NSString *)companyName
{
    NSString *description = @"Data Not Available";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        description = @"\"Report Card\" for companies.Covers their performance over the last quarter.";
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        description = @"Meeting between federal officials to determine future monetary policy.";
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        description = @"Estimate of the number of people who have jobs and those that don't.";
    }
    
    if ([eventType containsString:@"Consumer Confidence"]) {
        description = @"Measure of how likely people are to spend money in the future.";
    }
    
    if ([eventType containsString:@"GDP Release"]) {
        description = @"GDP is a measure of the country's economic health.";
    }
    
    if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
        description = [NSString stringWithFormat:@"Event related to products or services offered by %@",companyName];
    }
    
    return description;
}

// Return the appropriate event image based on event type
- (UIImage *)getImageBasedOnEventType:(NSString *)eventType
{
    UIImage *eventImage;
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        
        eventImage = [UIImage imageNamed:@"EarningsDetailCircle"];
        
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        
        eventImage = [UIImage imageNamed:@"EconDetailCircle"];
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        
        eventImage = [UIImage imageNamed:@"EconDetailCircle"];
    }
    
    if ([eventType containsString:@"Consumer Confidence"]) {
        
        eventImage = [UIImage imageNamed:@"EconDetailCircle"];
    }
    
    if ([eventType containsString:@"GDP Release"]) {
        
        eventImage = [UIImage imageNamed:@"EconDetailCircle"];
    }
    
    return eventImage;
}

// Get the display text for Expected EPS or Impact depending on the event type.
// FUTURE TO DO: Get the impact values into the database model.
- (NSString *)getEpsOrImpactTextForEventType:(NSString *)eventType eventParent:(NSString *)parentTicker
{
    NSString *description = @"Data Not Available";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        description = @"Expected Earnings Per Share.EPS is the profit per share of the company.";
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        description = @"Very High Impact.Outcome determines key interest rates.";
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        description = @"Very High Impact.Reflects the health of the job market.";
    }
    
    if ([eventType containsString:@"Consumer Confidence"]) {
        description = @"Medium Impact.Indicator of future personal spending.";
    }
    
    if ([eventType containsString:@"GDP Release"]) {
        description = @"Medium Impact.Scorecard of the country's economic health.";
    }
    
    // If event type is Product, the impact is stored in the event history data store, so fetch it from there.
    // If new product event types are added, add them here as well.
    if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
        
        // Get event history that stores the following string for product events in it's previous1Status field: Impact_Impact Description_TimeString_MoreInfoTitle_MoreInfoUrl
        EventHistory *eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:parentTicker parentEventType:eventType];
        
        // Parse out to construct the Impact Text.
        NSArray *impactComponents = [eventHistoryData.previous1Status componentsSeparatedByString:@"_"];
        description = [NSString stringWithFormat:@"%@ Impact.%@",impactComponents[0],impactComponents[1]];
    }
    
    return description;
}

// Get the display text for Prior EPS or Sectors Affected depending on the event type.
// FUTURE TO DO: Get the sectors affected values into the database model.
- (NSString *)getEpsOrSectorsTextForEventType:(NSString *)eventType
{
    NSString *description = @"Data Not Available";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        description = @"Prior Reported Quarter EPS.";
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        description = @"Financial stocks are impacted most by this.";
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        description = @"All types of stocks are impacted by this.";
    }
    
    if ([eventType containsString:@"Consumer Confidence"]) {
        description = @"Retail stocks are impacted most by this.";
    }
    
    if ([eventType containsString:@"GDP Release"]) {
        description = @"All types of stocks are impacted by this.";
    }
    
    return description;
}

// Get the display text for PriceSince or Tip depending on the event type.
// FUTURE TO DO: Get the tip value into the database model.
- (NSString *)getPriceSinceOrTipTextForEventType:(NSString *)eventType additionalInfo:(NSString *)infoString
{
    NSString *description = @"Data Not Available";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        description = [NSString stringWithFormat:@"Price since prior quarter end(%@).",infoString];
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        description = @"Pro Tip! If short term interest rates go up, banks typically benefit.";
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        description = @"Tip! Watch the jobless rate. In a strong labor market this decreases.";
    }
    
    if ([eventType containsString:@"Consumer Confidence"]) {
        description = @"Pro Tip! Consumers account for about 2/3rd of the nation's economic activity.";
    }
    
    if ([eventType containsString:@"GDP Release"]) {
        description = @"Pro Tip! Decreasing GDP for 2 or more quarters indicates a recession.";
    }
    
    return description;
}

// Get the display text for Price Since Prior Estimated Earnings Date.
- (NSString *)getPriceSincePriorEstimatedEarningsDate:(NSString *)eventType additionalInfo:(NSString *)infoString
{
    NSString *description = @"Data Not Available";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        description = [NSString stringWithFormat:@"Price since prior estimated earnings(%@).",infoString];
    }
    
    return description;
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
