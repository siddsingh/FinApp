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
#import "Company.h"
#import "Reachability.h"
#import "FACompanyInfoStore.h"
#import "FASnapShot.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <SafariServices/SafariServices.h>
@import EventKit;

@interface FAEventDetailsViewController () <SFSafariViewControllerDelegate>

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
    
    // Get the one data snapshot
    self.dataSnapShot2 = [[FASnapShot alloc] init];

    // Show the company name in the navigation bar header.
    self.navigationItem.title = [self.eventTitleStr uppercaseString];
    
    // Set the labels to the strings that hold their text. These strings will be set in the prepare for segue method when called. This is necessary since the label outlets are still nil when prepare for segue is called, so can't be set directly.
    [self.eventTitle setText:[self.eventType uppercaseString]];
    [self.eventSchedule setText:[self.eventScheduleStr uppercaseString]];
    
    // Set status of button to Follow or Following (for all events except econ events) and to Set Reminder or Reminder Set (for econ events)
    
    // String to hold the action name
    //NSString *actionName = nil;
    
    // If the cell contains a followable event, set status to Follow or Following
    /* if ([self isEventFollowable:self.eventType]) {
        
        // For a price change event
        if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"])
        {
            // Check to see if a reminder action has already been created for the quarterly earnings event for this ticker, which means this ticker is already being followed
            // TO DO: Hardcoding this for now to be quarterly earnings
            if ([self.primaryDetailsDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:@"Quarterly Earnings"])
            {
                actionName = [NSString stringWithFormat:@"UNFOLLOW %@",self.parentTicker];
                [self.reminderButton setBackgroundColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                [self.reminderButton setTitle:actionName forState:UIControlStateNormal];
                [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            }
            else
                // If not create show the follow action
            {
                actionName = [NSString stringWithFormat:@"FOLLOW %@",self.parentTicker];
                // Set button color based on event type
                [self.reminderButton setBackgroundColor:[self getColorForEventType:self.eventType]];
                [self.reminderButton setTitle:actionName forState:UIControlStateNormal];
                [self.reminderButton setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
            }
        }
        // For quarterly earnings or product events
        else {
            
            // Check to see if a reminder action has already been created for the event which means this ticker is already being followed
            if ([self.primaryDetailsDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:self.eventType])
            {
                actionName = [NSString stringWithFormat:@"UNFOLLOW %@",self.parentTicker];
                [self.reminderButton setBackgroundColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                [self.reminderButton setTitle:actionName forState:UIControlStateNormal];
                [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            }
            else
                // If not show the follow action
            {
                actionName = [NSString stringWithFormat:@"FOLLOW %@",self.parentTicker];
                // Set button color based on event type
                [self.reminderButton setBackgroundColor:[self getColorForEventType:self.eventType]];
                [self.reminderButton setTitle:actionName forState:UIControlStateNormal];
                [self.reminderButton setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
            }
        }
    }
    ///////// Else, for a non followable event (currently econ event), show a Set Reminder or Reminder Set button. Updating this to be FOLLOW/UNFOLLOW. Basically now econ events are follow/unfollowable just like any other event.
    else {
        // Check to see if a reminder action has already been created for the event represented by the cell.
        // If yes, show the Reminder set action.
        if ([self.primaryDetailsDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:self.eventType])
        {
            [self.reminderButton setBackgroundColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
            [self.reminderButton setTitle:@"UNFOLLOW" forState:UIControlStateNormal];
            [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
        // If not, show the set reminder action
        else
        {
            // Set button color based on event type
            [self.reminderButton setBackgroundColor:[self getColorForEventType:self.eventType]];
            [self.reminderButton setTitle:@"FOLLOW" forState:UIControlStateNormal];
            [self.reminderButton setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
        }
    } */

    // For Crypto events, disable + hide the newsbuttons 2 & 3 for others enable + show them.
    // FOR BTC or ETHR or BCH$ or XRP.
    if (([self.parentTicker caseInsensitiveCompare:@"BTC"] == NSOrderedSame)||([self.parentTicker caseInsensitiveCompare:@"ETHR"] == NSOrderedSame)||([self.parentTicker caseInsensitiveCompare:@"BCH$"] == NSOrderedSame)||([self.parentTicker caseInsensitiveCompare:@"XRP"] == NSOrderedSame)) {
        [self.newsButton2 setEnabled:NO];
        [self.newsButton2 setHidden:YES];
        [self.newsButton3 setEnabled:NO];
        [self.newsButton3 setHidden:YES];
    }
    else {
        [self.newsButton2 setEnabled:YES];
        [self.newsButton2 setHidden:NO];
        [self.newsButton3 setEnabled:YES];
        [self.newsButton3 setHidden:NO];
    }
    
    // Set color of "See News" buttons based on event type. Currently not using News Buttons 2 and 3.
    [self.newsButton setBackgroundColor:[self getColorForEventType:self.eventType]];
    [self.newsButton2 setBackgroundColor:[self getColorForEventType:self.eventType]];
    [self.newsButton3 setBackgroundColor:[self getColorForEventType:self.eventType]];
    [self.newsButton setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
    [self.newsButton2 setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
    [self.newsButton3 setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
    
    
    
    // Set color of back navigation item based on event type
    self.navigationController.navigationBar.tintColor = [self getColorForEventTypeForBackNav:self.eventType];
    
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

// Return a cell configured to display the event details based on the cell number and event type. Currently upto 6 types of information pieces are available.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Get a custom cell to display details and reset states/colors of cell elements to avoid carryover
    FAEventDetailsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventDetailsCell" forIndexPath:indexPath];
    
    // Assign a row no to the type of event detail row. Currently upto 5 types of related info pieces are available.
    #define infoRow1  0
    
    // Get Row no
    int rowNo = (int)indexPath.row;
    
    // Default
    [[cell titleLabel] setText:@"?"];
    [[cell descriptionArea] setText:@"Details not available."];
    
    // Display the appropriate details based on the row no
    // TO DO: SOLIDIFY LATER: Currently we use the event data to get the previous related date in expectedEps, priorEps, changeSincePrevQuarter. The scrubbed version of the previous related date (updated if it was on a weekend) is stored in the event history so that the stock price can be fetched. This is working fine for now but might want to rethink this.
    switch (rowNo) {
        
            // Common impact and description cell
        case infoRow1:
        {
            // Get Impact String
            NSString *impact_str = [self getImpactDescriptionForEventType:self.eventType eventParent:self.parentTicker];
            
            // Set the impact icon
            // Very High Impact
            if ([impact_str caseInsensitiveCompare:@"Very High Impact"] == NSOrderedSame) {
                [[cell titleLabel] setText:@"🔥"];
            }
            // High Impact
            if ([impact_str caseInsensitiveCompare:@"High Impact"] == NSOrderedSame) {
                cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"♨︎"];
            }
            // Medium Impact
            if ([impact_str caseInsensitiveCompare:@"Medium Impact"] == NSOrderedSame) {
                cell.titleLabel.textColor = [UIColor colorWithRed:255.0f/255.0f green:127.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"♨︎"];
            }
            // Low Impact
            if ([impact_str caseInsensitiveCompare:@"Low Impact"] == NSOrderedSame) {
                cell.titleLabel.textColor = [UIColor colorWithRed:207.0f/255.0f green:187.0f/255.0f blue:29.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"♨︎"];
            }
            
            // Set the rationale
            [[cell descriptionArea] setText:[NSString stringWithFormat:@"%@.%@",[self getImpactDescriptionForEventType:self.eventType eventParent:self.parentTicker],[self getEventDescriptionForEventType:self.eventType eventParent:self.parentTicker]]];
        }
            break;
            
        default:
            
            break;
    }
    
    return cell;
}

// OLD ONE, REPLACED BY A SIMPLER DETAIL VIEW:Return a cell configured to display the event details based on the cell number and event type. Currently upto 6 types of information pieces are available.
/*- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
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
    
    // Get the event history, only if the event type is quarterly earnings or price change event or a product event, to be displayed as the details based on parent company ticker and event type. Assumption is that ticker and event type uniquely identify an event.
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]||[self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]||[self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
        
        // Since we use the eventhistory for the quarterly earnings event for price events, use the string "Quarterly Earnings" instead of self.eventType
        eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:self.parentTicker parentEventType:@"Quarterly Earnings"];
    }
    
    // Display the appropriate details based on the row no
    // TO DO: SOLIDIFY LATER: Currently we use the event data to get the previous related date in expectedEps, priorEps, changeSincePrevQuarter. The scrubbed version of the previous related date (updated if it was on a weekend) is stored in the event history so that the stock price can be fetched. This is working fine for now but might want to rethink this.
    switch (rowNo) {
        
        // Display todays price or description or impact depending on event type.
        case infoRow1:
        {
            // Clear the image if it's been added to the background and remove text to reset state
            //cell.titleLabel.backgroundColor = [UIColor whiteColor];
            //[[cell titleLabel] setText:@""];

            if ([self.eventType isEqualToString:@"Quarterly Earnings"]||[self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
                [[cell descriptionArea] setText:@"Current price"];
                if ([self.currentPriceAndChange containsString:@"-"]) {
                    // Set color to Red
                    cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:self.currentPriceAndChange];
                } else {
                    // Set color to Green
                    cell.titleLabel.textColor = [UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:self.currentPriceAndChange];
                }
            }
            if ([self.eventType containsString:@"Fed Meeting"]) {
                
                [[cell descriptionArea] setText:[self getShortDescriptionForEventType:self.eventType parentCompanyName:self.parentCompany]];
                // TO DO: See if you want to bring back the icon later. If you do uncheck the resetting of label states for each row.
                //cell.titleLabel.backgroundColor = [UIColor colorWithPatternImage:[self getImageBasedOnEventType:self.eventType]];
                
                // Econ Blue
                //cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                // Light purple
                cell.titleLabel.textColor = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"?"];
            }
            if ([self.eventType containsString:@"Jobs Report"]) {
                
                [[cell descriptionArea] setText:[self getShortDescriptionForEventType:self.eventType parentCompanyName:self.parentCompany]];
                // TO DO: See if you want to bring back the icon later. If you do uncheck the resetting of label states for each row.
                //cell.titleLabel.backgroundColor = [UIColor colorWithPatternImage:[self getImageBasedOnEventType:self.eventType]];
                
                // Econ Blue
                //cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                // Light purple
                cell.titleLabel.textColor = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"?"];
            }
            if ([self.eventType containsString:@"Consumer Confidence"]) {
                
                [[cell descriptionArea] setText:[self getShortDescriptionForEventType:self.eventType parentCompanyName:self.parentCompany]];
                // TO DO: See if you want to bring back the icon later. If you do uncheck the resetting of label states for each row.
                //cell.titleLabel.backgroundColor = [UIColor colorWithPatternImage:[self getImageBasedOnEventType:self.eventType]];
                
                // Econ Blue
                //cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                // Light purple
                cell.titleLabel.textColor = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"?"];
            }
            if ([self.eventType containsString:@"GDP Release"]) {
                
                [[cell descriptionArea] setText:[self getShortDescriptionForEventType:self.eventType parentCompanyName:self.parentCompany]];
                // TO DO: See if you want to bring back the icon later. If you do uncheck the resetting of label states for each row.
                //cell.titleLabel.backgroundColor = [UIColor colorWithPatternImage:[self getImageBasedOnEventType:self.eventType]];
                
                // Econ Blue
                //cell.titleLabel.textColor = [UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f];
                // Light purple
                cell.titleLabel.textColor = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"?"];
            }
            if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
                
                // Show EPS for earnings and Impact Image bars for all others
                // Description
                [[cell descriptionArea] setText:[self getEpsOrImpactTextForEventType:self.eventType eventParent:self.parentTicker]];
                
                // Very High, High Impact
                if ([cell.descriptionArea.text containsString:@"High Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                    //[[cell titleLabel] setText:@"||||||||||"];
                    [[cell titleLabel] setText:@"♨︎"];
                }
                // Medium Impact
                if ([cell.descriptionArea.text containsString:@"Medium Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:255.0f/255.0f green:127.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    //[[cell titleLabel] setText:@"||||||"];
                    [[cell titleLabel] setText:@"♨︎"];
                }
                // Low Impact
                if ([cell.descriptionArea.text containsString:@"Low Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:207.0f/255.0f green:187.0f/255.0f blue:29.0f/255.0f alpha:1.0f];
                    //[[cell titleLabel] setText:@"||||"];
                    [[cell titleLabel] setText:@"♨︎"];
                }

            }
        }
        break;
            
        // Display Impact Level or 1 month price change depending on the event type
        case infoRow2:
        {
            // Clear the image if it's been added to the background and remove text to reset state
            //cell.titleLabel.backgroundColor = [UIColor whiteColor];
            //[[cell titleLabel] setText:@""];
            
            // For product event show the current price
            if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
                [[cell descriptionArea] setText:@"Current price"];
                if ([self.currentPriceAndChange containsString:@"-"]) {
                    // Set color to Red
                    cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:self.currentPriceAndChange];
                } else {
                    // Set color to Green
                    cell.titleLabel.textColor = [UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:self.currentPriceAndChange];
                }
            }
            // Else for Quarterly Earnings, econ events
            else {
                // Show EPS for earnings and Impact Image bars for all others
                // Description
                [[cell descriptionArea] setText:[self getEpsOrImpactTextForEventType:self.eventType eventParent:self.parentTicker]];
                
                // Display Label
                // EPS
                if ([self.eventType isEqualToString:@"Quarterly Earnings"]||[self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
                    // Text
                    // Get the 30 days prior date
                    // More detailed formatting if needed in the future
                    
                    // TO DO: Comment 1st line and delete second line before shipping v2.7
                    //NSString *priorEndDateToYestString = [NSString stringWithFormat:@"%@ - Now", [monthDateYearFormatter stringFromDate:eventHistoryData.previous1Date]];
                    //NSLog(@"30 days price change range is:%@",priorEndDateToYestString);
                    
                    //[[cell descriptionArea] setText:[self getPriceSinceOrTipTextForEventType:self.eventType additionalInfo:priorEndDateToYestString]];
                    [[cell descriptionArea] setText:[self getPriceSinceOrTipTextForEventType:self.eventType additionalInfo:@""]];
                    
                    // Calculate the difference in stock prices from end of prior quarter to yesterday, if both of them are available, format and display them
                    double prev1RelatedPriceDbl = [[eventHistoryData previous1Price] doubleValue];
                    double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
                    // TO DO: Comment 1st line and delete second line before shipping v2.7
                    //NSLog(@"The 30 days ago price was:%f and current price is:%f",prev1RelatedPriceDbl,currentPriceDbl);
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
                        [[cell titleLabel] setTextColor:[UIColor blackColor]];
                        [[cell titleLabel] setText:@"NA"];
                    }
                }
                // Very High, High Impact
                if ([cell.descriptionArea.text containsString:@"High Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                    //[[cell titleLabel] setText:@"||||||||||"];
                    [[cell titleLabel] setText:@"♨︎"];
                }
                // Medium Impact
                if ([cell.descriptionArea.text containsString:@"Medium Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:255.0f/255.0f green:127.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    //[[cell titleLabel] setText:@"||||||"];
                    [[cell titleLabel] setText:@"♨︎"];
                }
                // Low Impact
                if ([cell.descriptionArea.text containsString:@"Low Impact"]) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:207.0f/255.0f green:187.0f/255.0f blue:29.0f/255.0f alpha:1.0f];
                    //[[cell titleLabel] setText:@"||||"];
                    [[cell titleLabel] setText:@"♨︎"];
                }
            }
        }
        break;
            
        // Display "Sectors Affected" link for economic events and "year to date change" for earnings event. Nothing for product
        case infoRow3:
        {
            // Clear the image if it's been added to the background and remove text to reset state
            //cell.titleLabel.backgroundColor = [UIColor whiteColor];
            //[[cell titleLabel] setText:@""];
            
            // For product event show the 30 days price change
            if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
                
                [[cell descriptionArea] setText:[self getPriceSinceOrTipTextForEventType:self.eventType additionalInfo:@""]];
                
                // Calculate the difference in stock prices from end of prior quarter to yesterday, if both of them are available, format and display them
                double prev1RelatedPriceDbl = [[eventHistoryData previous1Price] doubleValue];
                double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
                // TO DO: Comment 1st line and delete second line before shipping v2.7
                //NSLog(@"The 30 days ago price was:%f and current price is:%f",prev1RelatedPriceDbl,currentPriceDbl);
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
                    [[cell titleLabel] setTextColor:[UIColor blackColor]];
                    [[cell titleLabel] setText:@"NA"];
                }
            }
            // Else for Quarterly Earnings, econ events
            else {
                
                // Description
                [[cell descriptionArea] setText:[self getEpsOrSectorsTextForEventType:self.eventType]];
                
                // Image/Value
                if ([self.eventType isEqualToString:@"Quarterly Earnings"]||[self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
                    // Text
                    // Get the start of the year date
                    // More detailed formatting in case you need it later.
                    
                    // TO DO: Comment 1st line and delete second line before shipping v2.7
                    //NSString *priorEarningsDateToYestString = [NSString stringWithFormat:@"%@ - Now", [monthDateYearFormatter stringFromDate:eventHistoryData.previous1RelatedDate]];
                    //NSLog(@"ytd price change range is:%@",priorEarningsDateToYestString);
                    
                    //[[cell descriptionArea] setText:[self getPriceSincePriorEstimatedEarningsDate:self.eventType additionalInfo:priorEarningsDateToYestString]];
                    [[cell descriptionArea] setText:[self getPriceSincePriorEstimatedEarningsDate:self.eventType additionalInfo:@""]];
                    
                    // Calculate the difference in stock prices since start of the year, if both of them are available, format and display them
                    double prev1PriceDbl = [[eventHistoryData previous1RelatedPrice] doubleValue];
                    double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
                    // TO DO: Comment 1st line and delete second line before shipping v2.7
                    //NSLog(@"The first day of the yr price was:%f and current price is:%f and NA is:%f",prev1PriceDbl,currentPriceDbl, notAvailable);
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
                        [[cell titleLabel] setTextColor:[UIColor blackColor]];
                        [[cell titleLabel] setText:@"NA"];
                    }
                }
                
                if ([self.eventType containsString:@"Fed Meeting"]) {
                    // Select the appropriate color and text for Financial Stocks
                    cell.titleLabel.textColor = [UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"$"];
                }
                
                if ([self.eventType containsString:@"Jobs Report"]) {
                    // Select the appropriate color and text for All Stocks
                    cell.titleLabel.textColor = [UIColor blackColor];
                    [[cell titleLabel] setText:@"☼"];
                }
                
                if ([self.eventType containsString:@"Consumer Confidence"]) {
                    // Select the appropriate color and text for Retail Stocks
                    // Pinkish deep red
                    cell.titleLabel.textColor = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"⦿"];
                }
                
                if ([self.eventType containsString:@"GDP Release"]) {
                    // Select the appropriate color and text for All Stocks
                    cell.titleLabel.textColor = [UIColor blackColor];
                    [[cell titleLabel] setText:@"☼"];
                }
            }
        }
        break;
        
        // Display Expected EPS or Tip depending on the event type
        case infoRow4:
        {
            // Clear the image if it's been added to the background and remove text to reset state
            //cell.titleLabel.backgroundColor = [UIColor whiteColor];
            //[[cell titleLabel] setText:@""];
            
            // For product event show the 30 days price change
            if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
                
                [[cell descriptionArea] setText:[self getPriceSincePriorEstimatedEarningsDate:self.eventType additionalInfo:@""]];
                
                // Calculate the difference in stock prices since start of the year, if both of them are available, format and display them
                double prev1PriceDbl = [[eventHistoryData previous1RelatedPrice] doubleValue];
                double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
                // TO DO: Comment 1st line and delete second line before shipping v2.7
                //NSLog(@"The first day of the yr price was:%f and current price is:%f",prev1PriceDbl,currentPriceDbl);
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
                    [[cell titleLabel] setTextColor:[UIColor blackColor]];
                    [[cell titleLabel] setText:@"NA"];
                }
            }
            // Else for Quarterly Earnings, econ events
            else {
                
                // Text
                [[cell descriptionArea] setText:[self getPriceSinceOrTipTextForEventType:self.eventType additionalInfo:@""]];
                
                // Value
                if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                    // Show EPS for earnings and Impact Image bars for all others
                    // Description
                    [[cell descriptionArea] setText:[self getEpsOrImpactTextForEventType:self.eventType eventParent:self.parentTicker]];
                    
                    // Display Label
                    // EPS
                    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                        cell.titleLabel.textColor = [UIColor blackColor];
                        [[cell titleLabel] setText:[decimal2Formatter stringFromNumber:eventData.estimatedEps]];
                    }
                }
                
                if ([self.eventType containsString:@"Fed Meeting"]) {
                    // Select the appropriate color and text for Pro Tip
                    cell.titleLabel.textColor = [UIColor blackColor];
                    [[cell titleLabel] setText:@"⚇"];
                }
                
                if ([self.eventType containsString:@"Jobs Report"]) {
                    // Select the appropriate color and text for Pro Tip
                    cell.titleLabel.textColor = [UIColor blackColor];
                    [[cell titleLabel] setText:@"⚇"];
                }
                
                if ([self.eventType containsString:@"Consumer Confidence"]) {
                    // Select the appropriate color and text for Pro Tip
                    cell.titleLabel.textColor = [UIColor blackColor];
                    [[cell titleLabel] setText:@"⚇"];
                }
                
                if ([self.eventType containsString:@"GDP Release"]) {
                    // Select the appropriate color and text for Pro Tip
                    cell.titleLabel.textColor = [UIColor blackColor];
                    [[cell titleLabel] setText:@"⚇"];
                }  
            }
        }
        break;
            
        // Show prior EPS for Quarterly earnings
        case infoRow5:
        {
            // Clear the image if it's been added to the background and remove text to reset state
            //cell.titleLabel.backgroundColor = [UIColor whiteColor];
            //[[cell titleLabel] setText:@""];
            
            // Description
            [[cell descriptionArea] setText:[self getEpsOrSectorsTextForEventType:self.eventType]];
            
            cell.titleLabel.textColor = [UIColor blackColor];
            [[cell titleLabel] setText:[decimal2Formatter stringFromNumber:eventData.actualEpsPrior]];
        }
        break;
        
        default:
            
        break;
    }
    
    return cell;
} */

#pragma mark - Reminder Related

// Action to take when Reminder button is pressed, which is set a reminder if reminder hasn't already been created, else display a message that reminder has aleady been set.
- (IBAction)reminderAction:(id)sender {
    
   /* FADataController *detailUnfollowDataController = [[FADataController alloc] init];
    
    // If it's a followable event, process following of the ticker
    if ([self isEventFollowable:self.eventType]) {
        
        // For a price change event, create reminders for all followable events for that ticker thus indicating this ticker is being followed
        if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"])
        {
            // Check to see if a reminder action has already been created for the quarterly earnings event for this ticker, which means this ticker is already being followed
            // TO DO: Hardcoding this for now to be quarterly earnings
            if ([detailUnfollowDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:@"Quarterly Earnings"])
            {
                // Disable the following button to indicate it's busy
                [self.reminderButton setEnabled:NO];
                [self.reminderButton setTitle:@"Working..." forState:UIControlStateNormal];
                
                // Delete the following event actions for the ticker
                [detailUnfollowDataController deleteFollowingEventActionsForTicker:self.parentTicker];
                
                // Refresh the event list on the prior screen
                [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
                
                // Delete existing reminders for this ticker
                [self deleteRemindersForTicker:self.parentTicker];
                
                // Style the button to post set styling with a slight delay to give time for all reminders to finish deleting
                [self performSelector:@selector(updateToFollowStateForTickerBasedEvent) withObject:nil afterDelay:2];
                
                // TRACKING EVENT: Unset Follow: User clicked the "Reminder Set" button, most likely to unset the reminder.
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Unset Follow"
                              parameters:@{ @"Ticker" : self.parentTicker,
                                            @"Event Type" : self.eventType,
                                            @"Event Certainty" : self.eventCertainty } ];
            }
            else
            // If not trigger following
            {
                // Disable the following button to indicate it's busy
                [self.reminderButton setEnabled:NO];
                [self.reminderButton setTitle:@"Working..." forState:UIControlStateNormal];
                
                // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
                [self requestAccessToUserEventStoreAndProcessReminderWithEventType:self.eventType companyTicker:self.parentTicker eventDateText:self.eventDateText eventCertainty:self.eventCertainty withDataController:detailUnfollowDataController];
                
                // Refresh the event list on the prior screen
                [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
                
                // Style the button to post set styling with a slight delay to give time for all reminders to finish creating
                [self performSelector:@selector(updateToUnfollowStateForTickerBasedEvent) withObject:nil afterDelay:2];
                
                // TRACKING EVENT: Set Follow: User clicked the "Set Reminder" button to create a reminder.
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Set Follow"
                              parameters:@{ @"Ticker" : self.parentTicker,
                                            @"Event Type" : self.eventType,
                                            @"Event Certainty" : self.eventCertainty } ];
            }
        }
        // For quarterly earnings or product events, either show already following or take follow action
        else {
            
            // Check to see if a reminder action has already been created for the event represented by the cell.
            // If yes, show a appropriately formatted message.
            if ([detailUnfollowDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:self.eventType])
            {
                // Disable the following button to indicate it's busy
                [self.reminderButton setEnabled:NO];
                [self.reminderButton setTitle:@"Working..." forState:UIControlStateNormal];
                
                // Delete the following event actions for the ticker
                [detailUnfollowDataController deleteFollowingEventActionsForTicker:self.parentTicker];
                
                // Refresh the event list on the prior screen
                [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
                
                // Delete existing reminders for this ticker
                [self deleteRemindersForTicker:self.parentTicker];
                
                // Style the button to post set styling with a slight delay to give time for all reminders to finish deleting
                [self performSelector:@selector(updateToFollowStateForTickerBasedEvent) withObject:nil afterDelay:2];
                
                // TRACKING EVENT: Unset Follow: User clicked the "Reminder Set" button, most likely to unset the reminder.
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Unset Follow"
                              parameters:@{ @"Ticker" : self.parentTicker,
                                            @"Event Type" : self.eventType,
                                            @"Event Certainty" : self.eventCertainty } ];
            }
            else
            // If not take the follow action
            {
                // Disable the following button to indicate it's busy
                [self.reminderButton setEnabled:NO];
                [self.reminderButton setTitle:@"Working..." forState:UIControlStateNormal];
                
                // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
                [self requestAccessToUserEventStoreAndProcessReminderWithEventType:self.eventType companyTicker:self.parentTicker eventDateText:self.eventDateText eventCertainty:self.eventCertainty withDataController:detailUnfollowDataController];
                
                // Refresh the event list on the prior screen
                [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
                
                // Style the button to post set styling with a slight delay to give time for all reminders to finish creating
                [self performSelector:@selector(updateToUnfollowStateForTickerBasedEvent) withObject:nil afterDelay:2];
                
                // TRACKING EVENT: Set Follow: User clicked the "Set Reminder" button to create a reminder.
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Set Follow"
                              parameters:@{ @"Ticker" : self.parentTicker,
                                            @"Event Type" : self.eventType,
                                            @"Event Certainty" : self.eventCertainty } ];
            }
        }
    }
    ///////// Else, for a non followable event (currently econ event), process Set Reminder/Reminder Set as usual. Updating this to enable following/unfollowing for Econ events.
    else {
        // Check to see if a reminder has already been created for the event.
        // If yes let the user know a reminder is already set for this ticker.
        if ([detailUnfollowDataController doesReminderActionExistForEventWithTicker:self.parentTicker eventType:self.eventType])
        {
            // Disable the following button to indicate it's busy
            [self.reminderButton setEnabled:NO];
            [self.reminderButton setTitle:@"Working..." forState:UIControlStateNormal];
            
            // Delete the following event actions for the ticker
            [detailUnfollowDataController deleteFollowingEventActionsForEconEvent:self.eventType];
            
            // Refresh the event list on the prior screen
            [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
            
            // Delete existing reminders for this econ event type i.e. Fed Meeting not Jan Fed Meeting. We send in Jan Fed Meeting but it automatically gets converted to Fed Meeting in the delete method.
            [self deleteRemindersForEconEventType:self.eventType];
            
            // Style the button to post set styling with a slight delay to give time for all reminders to finish deleting
            // Message is "Unfollowed Event"
            [self performSelector:@selector(updateToFollowStateForEconEvent) withObject:nil afterDelay:2];
            
            // TRACKING EVENT: Unset Reminder: User clicked the "Reminder Set" button, most likely to unset the reminder.
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"Unset Follow"
                          parameters:@{ @"Ticker" : self.parentTicker,
                                        @"Event Type" : self.eventType,
                                        @"Event Certainty" : self.eventCertainty } ];
        }
        
        // If not, create the reminder and style the button to post set styling
        else
        {
            // Disable the following button to indicate it's busy
            [self.reminderButton setEnabled:NO];
            [self.reminderButton setTitle:@"Working..." forState:UIControlStateNormal];
            
            // Present the user with an access request to their reminders if it's not already been done. Once that is done or access is already provided, create the reminder.
            [self requestAccessToUserEventStoreAndProcessReminderWithEventType:self.eventType companyTicker:self.parentTicker eventDateText:self.eventDateText eventCertainty:self.eventCertainty withDataController:detailUnfollowDataController];
            
            // Style the button to post set styling with a slight delay to give time for all reminders to finish creating
            [self performSelector:@selector(updateToUnfollowStateForEconEvent) withObject:nil afterDelay:2];
            
            // TRACKING EVENT: Create Reminder: User clicked the "Set Reminder" button to create a reminder.
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"Set Follow"
                          parameters:@{ @"Ticker" : self.parentTicker,
                                        @"Event Type" : self.eventType,
                                        @"Event Certainty" : self.eventCertainty } ];
        }
    } */
}

// Activate the action button and set text to unfollow state for a ticker based event like earnings or product events or price change events.
-(void)updateToUnfollowStateForTickerBasedEvent
{
    // Show appropriate message
  /*  [self sendUserGuidanceCreatedNotificationWithMessage:[NSString stringWithFormat:@"Following %@",self.parentTicker]];
    
    // Background Gray Color
    [self.reminderButton setBackgroundColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
    [self.reminderButton setTitle:[NSString stringWithFormat:@"UNFOLLOW %@",self.parentTicker] forState:UIControlStateNormal];
    [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.reminderButton setEnabled:YES]; */
}

// Activate the action button and set text to unfollow state for an econ event like earnings or product events or price change events.
-(void)updateToUnfollowStateForEconEvent
{
    // Show appropriate message
  /*  [self sendUserGuidanceCreatedNotificationWithMessage:@"Following event"];
    
    // Background Gray Color
    [self.reminderButton setBackgroundColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
    [self.reminderButton setTitle:@"UNFOLLOW" forState:UIControlStateNormal];
    [self.reminderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.reminderButton setEnabled:YES]; */
}


// Activate the action button and set text to follow state for a ticker based event like earnings or product events or price change events.
-(void)updateToFollowStateForTickerBasedEvent
{
    // Show appropriate message
   /* [self sendUserGuidanceCreatedNotificationWithMessage:[NSString stringWithFormat:@"Unfollowed %@",self.parentTicker]];
    
    // Color based on event type
    [self.reminderButton setBackgroundColor:[self getColorForEventType:self.eventType]];
    [self.reminderButton setTitle:[NSString stringWithFormat:@"FOLLOW %@",self.parentTicker] forState:UIControlStateNormal];
    [self.reminderButton setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
    [self.reminderButton setEnabled:YES];*/
}

// Activate the action button and set text to follow state for an econ event like earnings or product events or price change events.
-(void)updateToFollowStateForEconEvent
{
    // Show appropriate message
   /* [self sendUserGuidanceCreatedNotificationWithMessage:@"Unfollowed event"];
    
    // Color based on event type
    [self.reminderButton setBackgroundColor:[self getColorForEventType:self.eventType]];
    [self.reminderButton setTitle:@"FOLLOW" forState:UIControlStateNormal];
    [self.reminderButton setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
    [self.reminderButton setEnabled:YES];*/
}


#pragma mark - News related

// Send the user to the appropriate news site when they click the news button 1. Currently Google.
- (IBAction)seeNewsAction:(id)sender {
    
    NSString *moreInfoURL = nil;
    NSString *searchTerm = nil;
    NSURL *targetURL = nil;
    
    // Send them to different sites with different queries based on which site has the best informtion for that event type
    
    // TO DO: If you want to revert to using Bing
    // Bing News is the default we are going with for now
    /*moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.bing.com/news/search?q="];
    searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];*/
    
    // Google news is default for now
    moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
    searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];
    
    // For Quarterly Earnings, search query term is ticker and Earnings e.g. BOX earnings
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        searchTerm = [NSString stringWithFormat:@"%@ %@",self.parentTicker,@"earnings"];
    }
    
    // For Product events, search query term is the product name i.e. iPhone 7 or WWWDC 2016
    if ([self.eventType containsString:@"Launch"]) {
        searchTerm = [self.eventType stringByReplacingOccurrencesOfString:@" Launch" withString:@""];
    }
    // E.g. Naples Epyc Sales Launch becomes Naples Epyc
    if ([self.eventType containsString:@"Sales Launch"]) {
        searchTerm = [self.eventType stringByReplacingOccurrencesOfString:@" Sales Launch" withString:@""];
    }
    if ([self.eventType containsString:@"Conference"]) {
        searchTerm = [self.eventType stringByReplacingOccurrencesOfString:@" Conference" withString:@""];
    }
    
    // For economic events, search query term is customized for each type
    if ([self.eventType containsString:@"GDP Release"]) {
        searchTerm = @"us gdp growth";
    }
    if ([self.eventType containsString:@"Consumer Confidence"]) {
        searchTerm = @"us consumer confidence";
    }
    if ([self.eventType containsString:@"Fed Meeting"]) {
        searchTerm = @"fomc meeting";
    }
    if ([self.eventType containsString:@"Jobs Report"]) {
        searchTerm = @"jobs report us";
    }
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
        searchTerm = [NSString stringWithFormat:@"%@ %@",self.parentTicker,@"stock"];
    }
    
    // Remove any spaces in the URL query string params
    searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
    
    targetURL = [NSURL URLWithString:moreInfoURL];
    
    if (targetURL) {
        
        // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"See External News"
         parameters:@{ @"News Source" : @"Google",
         @"Action Query" : searchTerm,
         @"Action URL" : [targetURL absoluteString]} ];
        
        SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
        externalInfoVC.delegate = self;
        // Just use whatever is the default color for the Safari View Controller
        //externalInfoVC.preferredControlTintColor = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        [self presentViewController:externalInfoVC animated:YES completion:nil];
    }
}


// Send the user to the appropriate news site when they click the news button 2. Currently Seeking Alpha News.
- (IBAction)seeNewsAction2:(id)sender {
    
    NSString *moreInfoURL = nil;
    NSString *searchTerm = nil;
    NSURL *targetURL = nil;
    
    // Send them to different sites with different queries based on which site has the best informtion for that event type
    
    // TO DO: If you want to revert to using Bing
    // Bing News is the default we are going with for now
    /*moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.bing.com/news/search?q="];
     searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];*/
    
    // Seeking Alpha home is default
    moreInfoURL = [NSString stringWithFormat:@"%@",@"https://seekingalpha.com"];
    searchTerm = [NSString stringWithFormat:@"%@",@""];
    
    // For Quarterly Earnings, the URL extension is the ticker /symbol/NVDA
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        searchTerm = [NSString stringWithFormat:@"%@%@",@"/symbol/",self.parentTicker];
    }
    
    // For Product events, the URL extension is the ticker /symbol/NVDA
    if ([self.eventType containsString:@"Launch"]) {
        searchTerm = [NSString stringWithFormat:@"%@%@",@"/symbol/",self.parentTicker];
    }
    if ([self.eventType containsString:@"Conference"]) {
        searchTerm = [NSString stringWithFormat:@"%@%@",@"/symbol/",self.parentTicker];
    }
    
    // For economic events, just take them to the SA home page, so no URL extension
    if ([self.eventType containsString:@"GDP Release"]) {
        searchTerm = @"";
    }
    if ([self.eventType containsString:@"Consumer Confidence"]) {
        searchTerm = @"";
    }
    if ([self.eventType containsString:@"Fed Meeting"]) {
        searchTerm = @"";
    }
    if ([self.eventType containsString:@"Jobs Report"]) {
        searchTerm = @"";
    }
    // For Price events, the URL extension is the ticker /symbol/NVDA
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
        searchTerm =[NSString stringWithFormat:@"%@%@",@"/symbol/",self.parentTicker];
    }
    
    // Remove any spaces in the URL query string params
    searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
    
    targetURL = [NSURL URLWithString:moreInfoURL];
    
    if (targetURL) {
        
        // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"See External News"
                      parameters:@{ @"News Source" : @"Seeking Alpha",
                                    @"Action Query" : searchTerm,
                                    @"Action URL" : [targetURL absoluteString]} ];
        
        SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
        externalInfoVC.delegate = self;
        // Just use whatever is the default color for the Safari View Controller
        //externalInfoVC.preferredControlTintColor = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        [self presentViewController:externalInfoVC animated:YES completion:nil];
    } 
}

// Send the user to the appropriate news site when they click the news button 3. Currently Yahoo Finance.
- (IBAction)seeNewsAction3:(id)sender {
    
    NSString *moreInfoURL = nil;
    NSString *searchTerm = nil;
    NSURL *targetURL = nil;
    
    // Send them to different sites with different queries based on which site has the best informtion for that event type
    
    // TO DO: If you want to revert to using Bing
    // Bing News is the default we are going with for now
    /*moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.bing.com/news/search?q="];
     searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];*/
    
    // Yahoo finance is default
    moreInfoURL = [NSString stringWithFormat:@"%@",@"https://finance.yahoo.com"];
    searchTerm = [NSString stringWithFormat:@"%@",@""];
    
    // For Quarterly Earnings, the URL extension is the ticker /quote/NVDA?ql
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        searchTerm = [NSString stringWithFormat:@"%@%@%@",@"/quote/",self.parentTicker,@"?ql"];
    }
    
    // For Product events, the URL extension is the ticker /quote/NVDA?ql
    if ([self.eventType containsString:@"Launch"]) {
        searchTerm = [NSString stringWithFormat:@"%@%@%@",@"/quote/",self.parentTicker,@"?ql"];
    }
    if ([self.eventType containsString:@"Conference"]) {
        searchTerm = [NSString stringWithFormat:@"%@%@%@",@"/quote/",self.parentTicker,@"?ql"];
    }
    
    // For economic events, just take them to the home page, so no URL extension
    if ([self.eventType containsString:@"GDP Release"]) {
        searchTerm = @"";
    }
    if ([self.eventType containsString:@"Consumer Confidence"]) {
        searchTerm = @"";
    }
    if ([self.eventType containsString:@"Fed Meeting"]) {
        searchTerm = @"";
    }
    if ([self.eventType containsString:@"Jobs Report"]) {
        searchTerm = @"";
    }
    // For Price events, the URL extension is the ticker /quote/NVDA?ql
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
        searchTerm = [NSString stringWithFormat:@"%@%@%@",@"/quote/",self.parentTicker,@"?ql"];
    }
    
    // Remove any spaces in the URL query string params
    searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
    
    targetURL = [NSURL URLWithString:moreInfoURL];
    
    if (targetURL) {
        
        // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"See External News"
                      parameters:@{ @"News Source" : @"Yahoo Finance",
                                    @"Action Query" : searchTerm,
                                    @"Action URL" : [targetURL absoluteString]} ];
        
        SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
        externalInfoVC.delegate = self;
        // Just use whatever is the default color for the Safari View Controller
        //externalInfoVC.preferredControlTintColor = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        [self presentViewController:externalInfoVC animated:YES completion:nil];
    } 
}


// Delegate mthod to dismiss the Safari View Controller when a user is done with it.
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    
    //[self dismissViewControllerAnimated:true completion:nil];
}

// Load the appropriate news site in a web view in the app, when the user clicks the See News button
/*- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"ShowExternalInfo"]) {
        
        FAExternalInfoViewController *webViewController = [segue destinationViewController];
        
        NSString *moreInfoURL = nil;
        NSString *searchTerm = nil;
        NSURL *targetURL = nil;
        
        // Send them to different sites with different queries based on which site has the best informtion for that event type
        
        // Google news is default for now
        moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = [NSString stringWithFormat:@"%@",@"stocks"];
        
        // For Quarterly Earnings, search query term is ticker and Earnings e.g. BOX earnings
        if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
            searchTerm = [NSString stringWithFormat:@"%@ %@",self.parentTicker,@"earnings"];
        }
        
        // For Product events, search query term is the product name i.e. iPhone 7 or WWWDC 2016
        if ([self.eventType containsString:@"Launch"]) {
            searchTerm = [self.eventType stringByReplacingOccurrencesOfString:@" Launch" withString:@""];
        }
        if ([self.eventType containsString:@"Conference"]) {
            searchTerm = [self.eventType stringByReplacingOccurrencesOfString:@" Conference" withString:@""];
        }
        
        // For economic events, search query term is customized for each type
        if ([self.eventType containsString:@"GDP Release"]) {
            searchTerm = @"us gdp growth";
        }
        if ([self.eventType containsString:@"Consumer Confidence"]) {
            searchTerm = @"us consumer confidence";
        }
        if ([self.eventType containsString:@"Fed Meeting"]) {
            searchTerm = @"fomc meeting";
        }
        if ([self.eventType containsString:@"Jobs Report"]) {
            searchTerm = @"jobs report us";
        }
        if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
            searchTerm = [NSString stringWithFormat:@"%@ %@",self.parentTicker,@"stock"];
        }
        
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
        
        targetURL = [NSURL URLWithString:moreInfoURL];
        
        if (targetURL) {
            
            // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"External Action Clicked"
                          parameters:@{ @"Action Title" : @"See News",
                                        @"Action Query" : searchTerm,
                                        @"Action URL" : [targetURL absoluteString]} ];
            
            // Set the URL for the webview to open
            webViewController.externalInfoURL =  moreInfoURL;
        }
    }
}*/


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
            
            if ([self isEventFollowable:eventType]) {
                // Create all reminders for all followable events for this ticker. Does not do anything for econ events
                [self createAllRemindersInDetailsViewForFollowedTicker:parentTicker withDataController:appropriateDataController];
            }
            // If it's an econ event, create all reminders for all econ events of this type
            else {
                [self createAllRemindersInDetailsViewForEconEventType:eventType withDataController:appropriateDataController];
            }
            
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
                
                                                            [weakPtrToSelf processReminderForEventType:eventType companyTicker:parentTicker eventDateText:evtDateText eventCertainty:evtCertainty withDataController:afterAccessDataController];
                                                            
                                                            if ([weakPtrToSelf isEventFollowable:eventType]) {
                                                                // Create all reminders for all followable events for this ticker. Does not do anything for econ events
                                                                [weakPtrToSelf createAllRemindersInDetailsViewForFollowedTicker:parentTicker withDataController:appropriateDataController];
                                                            }
                                                            // If it's an econ event, create all reminders for all econ events of this type
                                                            else {
                                                                [weakPtrToSelf createAllRemindersInDetailsViewForEconEventType:eventType withDataController:appropriateDataController];
                                                            }
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
            } else {
                [self sendUserGuidanceCreatedNotificationWithMessage:[NSString stringWithFormat:@"Unable to follow %@",cellCompanyTicker]];
            }
        }
        // If estimated add to action data store for later processing
        else if ([cellEventCertainty isEqualToString:@"Estimated"]) {
            
            // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:cellCompanyTicker eventType:cellEventType];
        }
    }
    // Economic Event
    if ([cellEventType containsString:@"Fed Meeting"]||[cellEventType containsString:@"Jobs Report"]||[cellEventType containsString:@"Consumer Confidence"]||[cellEventType containsString:@"GDP Release"]) {
        
        // Create the reminder and show user the appropriate message
        BOOL success = [self createReminderForEventOfType:cellEventType withTicker:cellCompanyTicker dateText:cellEventDateText andDataController:appropriateDataController];
        if (success) {
            // Add action to the action data store with status created
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Created" eventTicker:cellCompanyTicker eventType:cellEventType];
        } else {
            [self sendUserGuidanceCreatedNotificationWithMessage:@"Oops! Unable to create a reminder for this event."];
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
            } else {
                [self sendUserGuidanceCreatedNotificationWithMessage:[NSString stringWithFormat:@"Unable to follow %@",cellCompanyTicker]];
            }
        }
        // If estimated add to action data store for later processing
        else if ([cellEventCertainty isEqualToString:@"Estimated"]) {
            
            // Make an appropriate entry for this action in the action data store for later processing. The action type is: "OSReminder" and status is: "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
            [appropriateDataController insertActionOfType:@"OSReminder" status:@"Queued" eventTicker:cellCompanyTicker eventType:cellEventType];
        }
    }
    // Price Change event. Do nothing currently
    if ([cellEventType containsString:@"% up"]||[cellEventType containsString:@"% down"])
    {
        
    }
}

// Create reminders for all followable events (currently earnings and product events) for a given ticker, if it's not already been created
- (void)createAllRemindersInDetailsViewForFollowedTicker:(NSString *)ticker withDataController:(FADataController *)appropriateDataController {
    
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
- (void)createAllRemindersInDetailsViewForEconEventType:(NSString *)type withDataController:(FADataController *)appropriateDataController {
    
    NSString *cellEventType = nil;
    NSString *cellEventDateText = nil;
    NSString *cellEventCertainty = nil;
    
    // Get today's date formatted to midnight last night
    NSDate *todaysDate = [self setTimeToMidnightLastNightOnDate:[NSDate date]];
    
    // Get all events for an econ type
    // Send in the generic type (e.g. Jobs Report) rather than the exact type (e.g. Jan Jobs Report)
    // Filter based on type
    NSArray *allEvents = nil;
    if ([type containsString:@"Fed Meeting"]) {
        allEvents = [appropriateDataController getAllEconEventsOfType:@"Fed Meeting"];
    }
    if ([type containsString:@"Jobs Report"]) {
        allEvents = [appropriateDataController getAllEconEventsOfType:@"Jobs Report"];
    }
    if ([type containsString:@"Consumer Confidence"]) {
        allEvents = [appropriateDataController getAllEconEventsOfType:@"Consumer Confidence"];
    }
    if ([type containsString:@"GDP Release"]) {
        allEvents = [appropriateDataController getAllEconEventsOfType:@"GDP Release"];
    }
    
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
    NSString *reminderText = @"A financial event of interest is tomorrow.";
    
    // Set title of the reminder to the reminder text, based on event type
    EKReminder *eventReminder = [EKReminder reminderWithEventStore:self.userEventStore];
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
    
    NSString *genericEventType = nil;
    
    // Get the generic event type i.e. Fed Meeting as opposed to Jan Fed Meeting
    if ([eventType containsString:@"Fed Meeting"]) {
        genericEventType = @"Fed Meeting";
    }
    if ([eventType containsString:@"Jobs Report"]) {
        genericEventType = @"Jobs Report";
    }
    if ([eventType containsString:@"Consumer Confidence"]) {
        genericEventType = @"Consumer Confidence";
    }
    if ([eventType containsString:@"GDP Release"]) {
        genericEventType = @"GDP Release";
    }
    
    // Get the default calendar where Knotifi events have been created
    EKCalendar *knotifiRemindersCalendar = [self.userEventStore defaultCalendarForNewReminders];
    
    // Get all events
    [self.userEventStore fetchRemindersMatchingPredicate:[self.userEventStore predicateForRemindersInCalendars:[NSArray arrayWithObject:knotifiRemindersCalendar]] completion:^(NSArray *eventReminders) {
        NSError *error = nil;
        
        for (EKReminder *eventReminder in eventReminders) {
            
            // See if a matching earnings event Knotifi reminder is found, if so add to batch to be deleted
            if ([eventReminder.title containsString:@"Knotifi ▶︎"]&&[eventReminder.title containsString:genericEventType]) {
                [self.userEventStore removeReminder:eventReminder commit:NO error:&error];
            }
        }
        
        // Commit the changes
        [self.userEventStore commit:&error];
    }];
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

//CURRENTLY: Just retunr one row for all types. Depending on the event type return the number of related information pieces available. Currently: Quarterly Earnings -> 5 possible info pieces: Short Description, Expected Eps, Prior Eps, ChangeSincePriorQuarter, ChangeSincePriorEarnings. Jan Fed Meeting -> 4 possible info pieces: Short Description, Impact, SectorsAffected, Tips). NOTE: If any of these pieces is not available that piece will not be counted.
- (NSInteger)getNoOfInfoPiecesForEventType
{
    NSInteger numberOfPieces = 1;
    
/*    // Set a value indicating that a value is not available. Currently a Not Available value is represented by
    double notAvailable = 999999.9f;
    EventHistory *eventHistoryData;
    
    // Based on event type and what's available, return the no of pieces of information.
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        
        numberOfPieces = 5;
        // Get the event history.
        eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:self.parentTicker parentEventType:self.eventType];
        
        // Check to see if stock prices at end of prior quarter and yesterday are available.If yes, then return 4 pieces. If not then return 2 pieces (desc, expected eps, prior eps)
        double prev1RelatedPriceDbl = [[eventHistoryData previous1RelatedPrice] doubleValue];
        double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
        
        // Always return 5 pieces
        if ((prev1RelatedPriceDbl != notAvailable)&&(currentPriceDbl != notAvailable)) {
            numberOfPieces = 5;
        } else {
            numberOfPieces = 5;
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
        
        numberOfPieces = 4;
        
        // FOR BTC or ETHR or BCH$ or XRP, only show one cell right now. Later make this 4 to show price data.
        if (([self.parentTicker caseInsensitiveCompare:@"BTC"] == NSOrderedSame)||([self.parentTicker caseInsensitiveCompare:@"ETHR"] == NSOrderedSame)||([self.parentTicker caseInsensitiveCompare:@"BCH$"] == NSOrderedSame)||([self.parentTicker caseInsensitiveCompare:@"XRP"] == NSOrderedSame)) {
            numberOfPieces = 1;
        }
        else {
            // Get the event history.
            eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:self.parentTicker parentEventType:self.eventType];
            
            // Check to see if stock prices at end of prior quarter and yesterday are available.If yes, then return 4 pieces. If not then return 2 pieces (desc, expected eps, prior eps)
            double prev1RelatedPriceDbl = [[eventHistoryData previous1RelatedPrice] doubleValue];
            double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
            // Always return 4 pieces
            if ((prev1RelatedPriceDbl != notAvailable)&&(currentPriceDbl != notAvailable)) {
                numberOfPieces = 4;
            } else {
                numberOfPieces = 4;
            }
        }
    }
    
    // Price change events we want to show the current stock price and 30 day and ytd change.
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
        
        numberOfPieces = 3;
        // Get the event history.
        eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:self.parentTicker parentEventType:self.eventType];
        
        // Check to see if stock prices at end of prior quarter and yesterday are available.If yes, then return 4 pieces. If not then return 2 pieces (desc, expected eps, prior eps)
        double prev1RelatedPriceDbl = [[eventHistoryData previous1RelatedPrice] doubleValue];
        double currentPriceDbl = [[eventHistoryData currentPrice] doubleValue];
        // Always return 3
        if ((prev1RelatedPriceDbl != notAvailable)&&(currentPriceDbl != notAvailable)) {
            numberOfPieces = 3;
        } else {
            numberOfPieces = 3;
        }
    } */
        
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
        description = [NSString stringWithFormat:@"Related to products or services offered by %@",companyName];
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
    
    if ([eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        
        eventImage = [UIImage imageNamed:@"ProdDetailCircle"];
    }
    
    return eventImage;
}

// Get the display text for Prior EPS or Sectors Affected depending on the event type.
// FUTURE TO DO: Get the sectors affected values into the database model.
- (NSString *)getEpsOrSectorsTextForEventType:(NSString *)eventType
{
    NSString *description = @"Data Not Available";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        // More detailed formatting if needed in the future
        //description = @"Prior reported quarter EPS";
        description = @"Prior EPS";
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

// Get the display text for Expected EPS or Impact depending on the event type.
// FUTURE TO DO: Get the impact values into the database model.
- (NSString *)getEpsOrImpactTextForEventType:(NSString *)eventType eventParent:(NSString *)parentTicker
{
    NSString *description = @"Data Not Available";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        // More detailed formatting in case you need it later
        //description = @"Expected Earnings Per Share.EPS is the profit per share of the company.";
        description = @"Expected EPS";
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
        
        // Get event history that stores the following string for product events in it's previous1Status field: Impact_Impact Description_MoreInfoTitle_MoreInfoUrl
        EventHistory *eventHistoryData1 = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:parentTicker parentEventType:eventType];
        
        // Parse out to construct the Impact Text.
        NSArray *impactComponents = [eventHistoryData1.previous1Status componentsSeparatedByString:@"_"];
        description = [NSString stringWithFormat:@"%@ Impact.%@",impactComponents[0],impactComponents[1]];
    }
    
    return description;
}

// Get the impact description text given event type and ticker
- (NSString *)getImpactDescriptionForEventType:(NSString *)eventType eventParent:(NSString *)parentTicker
{
    NSString *description = @"Unknown Impact";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        
        if ([self.dataSnapShot2 isEventHighImpact:eventType eventParent:parentTicker]) {
            description = @"Very High Impact";
        } else {
             description = @"Medium Impact";
        }
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        description = @"Very High Impact";
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        description = @"Very High Impact";
    }
    
    if ([eventType containsString:@"Consumer Confidence"]) {
        description = @"Medium Impact";
    }
    
    if ([eventType containsString:@"GDP Release"]) {
        description = @"Medium Impact";
    }
    
    // If event type is Product, the impact is stored in the event history data store, so fetch it from there.
    // If new product event types are added, add them here as well.
    if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
        
        // Get event history that stores the following string for product events in it's previous1Status field: Impact_Impact Description_MoreInfoTitle_MoreInfoUrl
        EventHistory *eventHistoryData1 = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:parentTicker parentEventType:eventType];
        
        // Parse out to construct the Impact Text.
        NSArray *impactComponents = [eventHistoryData1.previous1Status componentsSeparatedByString:@"_"];
        description = [NSString stringWithFormat:@"%@ Impact",impactComponents[0]];
    }
    
    return description;
}

// Get the event description text given event type and ticker
- (NSString *)getEventDescriptionForEventType:(NSString *)eventType eventParent:(NSString *)parentTicker
{
    NSString *description = @"Unknown Description";
    
    // Big name companies earnings like FANG or Apple whose earnings can impact overall market.
    if ([eventType isEqualToString:@"Quarterly Earnings"]) {
        
        if ([self.dataSnapShot2 isEventHighImpact:eventType eventParent:parentTicker]) {
            description = @"Past quarter report card for a highly watched company.";
        } else {
            description = @"Past quarter report card for this company.";
        }
    }
    
    if ([eventType containsString:@"Fed Meeting"]) {
        description = @"Outcome determines key interest rates.";
    }
    
    if ([eventType containsString:@"Jobs Report"]) {
        description = @"Reflects the health of the job market.";
    }
    
    if ([eventType containsString:@"Consumer Confidence"]) {
        description = @"Indicator of future personal spending.";
    }
    
    if ([eventType containsString:@"GDP Release"]) {
        description = @"Scorecard of the country's economic health.";
    }
    
    // If event type is Product, the impact is stored in the event history data store, so fetch it from there.
    // If new product event types are added, add them here as well.
    if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
        
        // Get event history that stores the following string for product events in it's previous1Status field: Impact_Impact Description_MoreInfoTitle_MoreInfoUrl
        EventHistory *eventHistoryData1 = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:parentTicker parentEventType:eventType];
        
        // Parse out to construct the Impact Text.
        NSArray *impactComponents = [eventHistoryData1.previous1Status componentsSeparatedByString:@"_"];
        description = [NSString stringWithFormat:@"%@",impactComponents[1]];
    }
    
    return description;
}

// Get a more information title with the underlying URL hyperlinked into an NSAttributableString, based on the type of the more information. Currently support "Most Relevant Website" and "Latest On Search Engine"
- (NSMutableAttributedString *)getMoreInfoTitleWithLinkForEventType:(NSString *)eventType eventParentTicker:(NSString *)parentTicker moreInfoType:(NSString *)infoType
{
    NSMutableAttributedString *attributedTitleWithURL = nil;
    NSString *moreInfoTitle = nil;
    NSString *moreInfoURL = nil;
    NSString *searchTerm = nil;
    EventHistory *eventHistoryData = nil;
    NSArray *infoComponents = nil;
    
    // For "Most Relevant Website" construct link pointing to an external website for product events
    if ([infoType isEqualToString:@"Most Relevant Website"]&&([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"])) {
        // Get event history that stores the following string for product events in it's previous1Status field: Impact_Impact Description_MoreInfoTitle_MoreInfoUrl
        eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:parentTicker parentEventType:eventType];
        
        // Parse out the MoreInfoTitle and MoreInfoUrl
        infoComponents = [eventHistoryData.previous1Status componentsSeparatedByString:@"_"];
        moreInfoTitle = [NSString stringWithFormat:@"%@ %@",infoComponents[2],@"▶︎"];
        moreInfoURL = infoComponents[3];
    }
    
    // For "Latest On Search Engine" construct link pointing to an external search engine with a preset query.
    // NOTE: Depending on type of event the title and URL with query to search engine varies.
    if ([infoType isEqualToString:@"Latest On Search Engine"]) {
        
        moreInfoTitle = [NSString stringWithFormat:@"%@",@"Latest News On Bing ▶︎"];
        moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.bing.com/news/search?q="];
        
        // For Quarterly Earnings, search query term is ticker and Earnings e.g. BOX earnings
        if ([eventType isEqualToString:@"Quarterly Earnings"]) {
            searchTerm = [NSString stringWithFormat:@"%@ %@",parentTicker,@"earnings"];
        }
        
        // For Product events, search query term is the product name i.e. iPhone 7 or WWWDC 2016
        if ([eventType containsString:@"Launch"]) {
            searchTerm = [eventType stringByReplacingOccurrencesOfString:@" Launch" withString:@""];
            moreInfoTitle = @"Latest On Google ▶︎";
            moreInfoURL = @"https://www.google.com/search?q=";
        }
        if ([eventType containsString:@"Conference"]) {
            searchTerm = [eventType stringByReplacingOccurrencesOfString:@" Conference" withString:@""];
            moreInfoTitle = @"Latest On Google ▶︎";
            moreInfoURL = @"https://www.google.com/search?q=";
        }
        
        // For economic events, search query term is customized for each type
        if ([eventType containsString:@"GDP Release"]) {
            searchTerm = @"us gdp growth";
        }
        if ([eventType containsString:@"Consumer Confidence"]) {
            searchTerm = @"us consumer confidence";
        }
        if ([eventType containsString:@"Fed Meeting"]) {
            searchTerm = @"fomc meeting";
        }
        if ([eventType containsString:@"Jobs Report"]) {
            searchTerm = @"jobs report us";
            moreInfoTitle = @"Latest On Google ▶︎";
            moreInfoURL = @"https://www.google.com/search?q=";
        }
        
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
    }
    
    // Form the hyperlinked attributed String
    attributedTitleWithURL = [[NSMutableAttributedString alloc] initWithString:moreInfoTitle
                                                                           attributes:@{NSLinkAttributeName:[NSURL URLWithString:moreInfoURL]}];
    // Set font and color for the string
    UIFont *titleFont = [UIFont fontWithName:@"Helvetica" size:20];
    [attributedTitleWithURL addAttribute:NSFontAttributeName value:titleFont range:NSMakeRange(0,[attributedTitleWithURL length])];
    [attributedTitleWithURL addAttribute:NSBackgroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0,[attributedTitleWithURL length])];
    // Econ Blue color
    [attributedTitleWithURL addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:29.0f/255.0f green:119.0f/255.0f blue:239.0f/255.0f alpha:1.0f] range:NSMakeRange(0,[attributedTitleWithURL length])];
    
    // Set center alignment
    NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc]init] ;
    [paraStyle setAlignment:NSTextAlignmentCenter];
    [attributedTitleWithURL addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange(0,[attributedTitleWithURL length])];
    
    return attributedTitleWithURL;
}

// Implementing the UITextView (that holds the description text including the links) delegate to track the actions being clicked by the user
- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
    // TO DO: Disabling to not track development events. Enable before shipping.
    [FBSDKAppEvents logEvent:@"External Action Clicked"
                  parameters:@{ @"Action Title" : textView.text,
                                @"Action URL" : [URL absoluteString] } ];
    
    // TO DO FINAL: Delete after final test
    //NSLog(@"LINK CLICKED:%@ %@", textView.text, URL);
    
    // Return NO if iOS should not open the link
    return YES;
}

// Get the display text for PriceSince or Tip depending on the event type.
// FUTURE TO DO: Get the tip value into the database model.
- (NSString *)getPriceSinceOrTipTextForEventType:(NSString *)eventType additionalInfo:(NSString *)infoString
{
    NSString *description = @"Data Not Available";
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]||[eventType containsString:@"% up"]||[eventType containsString:@"% down"]||[eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        // More detailed formatting if needed for the future
        //description = [NSString stringWithFormat:@"1 month price change(%@).",infoString];
        description = [NSString stringWithFormat:@"1 month price change"];
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
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]||[eventType containsString:@"% up"]||[eventType containsString:@"% down"]||[eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        // More detailed formatting in case you need it later
        //description = [NSString stringWithFormat:@"Year to date price change(%@).",infoString];
        description = [NSString stringWithFormat:@"Year to date price change"];
    }
    
    return description;
}

#pragma mark - Others

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

#pragma mark - utility methods

// Check to see if the event is of a type that it is followable. Currently price change events, or a product event or an earnings event, are followable. Econ events are not.
- (BOOL)isEventFollowable:(NSString *)eventType
{
    BOOL returnVal = NO;
    
    if ([eventType isEqualToString:@"Quarterly Earnings"]||[eventType containsString:@"% up"]||[eventType containsString:@"% down"]||[eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        returnVal = YES;
    }
    
    return returnVal;
}

// Return the appropriate color for event based on type.
- (UIColor *)getColorForEventType:(NSString *)eventType
{
    // Set returned color to black text to start with
    UIColor *colorToReturn = [UIColor blackColor];
    
    // Always return the brand colors (including for Econ as that's taken care of in the brand colors).
    // TO DO: Delete before shipping v4.3
    //NSLog(@"TICKER FOR EEVENT IS:%@",self.parentTicker);
    colorToReturn = [self.dataSnapShot2 getBrandBkgrndColorForCompany:self.parentTicker];
    
   /* if ([eventType isEqualToString:@"Quarterly Earnings"]) {
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
        // Dark Yellow
        //colorToReturn = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        // Return the brand color
        colorToReturn = [self.dataSnapShot2 getBrandBkgrndColorForCompany:self.parentTicker];
    }
    if ([self.eventType containsString:@"% up"])
    {
        // Kinda Green
        //colorToReturn = [UIColor colorWithRed:56.0f/255.0f green:197.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
        colorToReturn = [UIColor colorWithRed:52.0f/255.0f green:181.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
    }
    if ([self.eventType containsString:@"% down"])
    {
        // Kinda Red
        colorToReturn = [UIColor colorWithRed:255.0f/255.0f green:63.0f/255.0f blue:61.0f/255.0f alpha:1.0f];
    } */
    
    return colorToReturn;
}

// Return the appropriate color for event based on type.
- (UIColor *)getTextColorForEventType:(NSString *)eventType
{
    // Set returned color to white color since all events other than product events have white text.
    UIColor *colorToReturn = [UIColor whiteColor];
    
    // Always return the brand colors (including for Econ as that's taken care of in the brand colors).
    // Return the brand text color
    colorToReturn = [self.dataSnapShot2 getBrandTextColorForCompany:self.parentTicker];
    
   /* if ([eventType containsString:@"Launch"]||[eventType containsString:@"Conference"]) {
        
        // Return the brand text color
        colorToReturn = [self.dataSnapShot2 getBrandTextColorForCompany:self.parentTicker];
    } */
    
    return colorToReturn;
}

// Return the appropriate color for event based on type.
- (UIColor *)getColorForEventTypeForBackNav:(NSString *)eventType
{
    // Set returned color to black text to start with
    UIColor *colorToReturn = [UIColor blackColor];
    
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
        // Dark Yellow
        colorToReturn = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
    }
    if ([self.eventType containsString:@"% up"])
    {
        // Kinda Green
        //colorToReturn = [UIColor colorWithRed:56.0f/255.0f green:197.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
        colorToReturn = [UIColor colorWithRed:52.0f/255.0f green:181.0f/255.0f blue:4.0f/255.0f alpha:1.0f];
    }
    if ([self.eventType containsString:@"% down"])
    {
        // Kinda Red
        colorToReturn = [UIColor colorWithRed:255.0f/255.0f green:63.0f/255.0f blue:61.0f/255.0f alpha:1.0f];
    }
    
    return colorToReturn;
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

// Format the given date to set the time on it to midnight last night. e.g. 03/21/2016 9:00 pm becomes 03/21/2016 12:00 am.
- (NSDate *)setTimeToMidnightLastNightOnDate:(NSDate *)dateToFormat
{
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponents = [aGregorianCalendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:dateToFormat];
    NSDate *formattedDate = [aGregorianCalendar dateFromComponents:dateComponents];
    
    return formattedDate;
}

#pragma mark - unused code
/* To set a clickable link on a text area
case infoRow3:
{
    // Clear the image if it's been added to the title background
    cell.titleLabel.backgroundColor = [UIColor whiteColor];
    
    // For product event types get the most relevant Info link and display appropriately. NOTE: Set label to nothing for the product events, just for safety.
    if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
     [[cell descriptionArea] setAttributedText:[self getMoreInfoTitleWithLinkForEventType:self.eventType eventParentTicker:self.parentTicker moreInfoType:@"Most Relevant Website"]];
     [[cell titleLabel] setText:@""];
     }
    // For Quarterly earnings events show the Prior EPS
    else if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        [[cell descriptionArea] setText:[self getEpsOrImpactTextForEventType:self.eventType eventParent:self.parentTicker]];
        cell.titleLabel.textColor = [UIColor blackColor];
        [[cell titleLabel] setText:[decimal2Formatter stringFromNumber:eventData.estimatedEps]];
    }
    // For all other Econ events get the "Latest On Search Engine" link and display appropriately
    else {
        [[cell descriptionArea] setAttributedText:[self getMoreInfoTitleWithLinkForEventType:self.eventType eventParentTicker:self.parentTicker moreInfoType:@"Latest On Search Engine"]];
        cell.titleLabel.textColor = [UIColor blackColor];
        [[cell titleLabel] setText:@""];
    }
}
break;
*/

@end
