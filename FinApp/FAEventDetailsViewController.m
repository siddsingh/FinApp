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
#import "FACoinAltData.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <SafariServices/SafariServices.h>
#import <QuartzCore/QuartzCore.h>
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
    
    // Get the one alt data snapshot
    self.altDataSnapShot = [[FACoinAltData alloc] init];

    // Show the company name in the navigation bar header.
    self.navigationItem.title = [self.eventTitleStr uppercaseString];
    
    // Set the labels to the strings that hold their text. These strings will be set in the prepare for segue method when called. This is necessary since the label outlets are still nil when prepare for segue is called, so can't be set directly.
    [self.eventTitle setText:[self.eventType uppercaseString]];
    [self.eventSchedule setText:[self.eventScheduleStr uppercaseString]];
    
    // Format the details Info type selector and bottom border labels
    // Set Background color and tint to a very light almost white gray
    [self.detailsInfoSelector setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
    [self.detailsInfoSelector setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
    // Set text color and size of all unselected segments to a medium dark gray used in the event dates (R:113, G:113, B:113). Making this the almost white gray to hide it currently. Revert back to before when using this control
    NSDictionary *unselectedAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [UIFont systemFontOfSize:16], NSFontAttributeName,
                                          [UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                          nil];
    [self.detailsInfoSelector setTitleTextAttributes:unselectedAttributes forState:UIControlStateNormal];
    // Set text and size for selected segment to black. Making this the almost white gray to hide it currently. Revert back to before when using this control
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [UIFont boldSystemFontOfSize:16], NSFontAttributeName,
                                    [UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                    nil];
    [self.detailsInfoSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
    // Bottom border label
    if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
        
        // TO hide set everything to almost white. TO revert use code below
        [self.bottomBorderLbl1 setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl1 setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl1 setTextColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setTextColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        // Old way
        /*[self.bottomBorderLbl1 setBackgroundColor:[UIColor blackColor]];
        [self.bottomBorderLbl1 setTintColor:[UIColor blackColor]];
        [self.bottomBorderLbl1 setTextColor:[UIColor blackColor]];
        [self.bottomBorderLbl2 setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setTextColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];*/
    } else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
        
        // TO hide set everything to almost white. TO revert use code below
        [self.bottomBorderLbl1 setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl1 setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl1 setTextColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setTextColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        
        // Old Way
        /*[self.bottomBorderLbl2 setBackgroundColor:[UIColor blackColor]];
        [self.bottomBorderLbl2 setTintColor:[UIColor blackColor]];
        [self.bottomBorderLbl2 setTextColor:[UIColor blackColor]];
        [self.bottomBorderLbl1 setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl1 setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl1 setTextColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];*/
    }
    
    //Adding a pull to refresh action on the table.
    /*self.deetsTblRefreshControl = [[UIRefreshControl alloc] init];
    // tblRefreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Please Wait..."];
    [self.deetsTblRefreshControl addTarget:self action:@selector(deetsRefreshTbl:) forControlEvents:UIControlEventValueChanged];
    [self.eventDetailsTable addSubview:self.deetsTblRefreshControl];*/
    
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
    
   /* self.newsButton2.clipsToBounds = YES;
    self.newsButton2.layer.cornerRadius = 5;
    self.newsButton3.clipsToBounds = YES;
    self.newsButton3.layer.cornerRadius = 5;
    
    // Set color of news button 2 per event type as this is the primary contextual callout
    [self.newsButton2 setBackgroundColor:[self getColorForEventType:self.eventType]];
    [self.newsButton2 setTitleColor:[self getTextColorForEventType:self.eventType] forState:UIControlStateNormal];
    // Set title of news buttons 2 and 3 as they vary per event type
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"])
    {
        [self.newsButton2 setTitle:[NSString stringWithFormat:@"%@ NEWS",self.parentTicker] forState:UIControlStateNormal];
        
    } else {
        [self.newsButton2 setTitle:[NSString stringWithFormat:@"Best Info"] forState:UIControlStateNormal];
        [self.newsButton3 setTitle:[NSString stringWithFormat:@"More Info"] forState:UIControlStateNormal];
    } */
    
    // Set color of back navigation item based on event type
    //self.navigationController.navigationBar.tintColor = [self getColorForEventTypeForBackNav:self.eventType];
    
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
    NSInteger noOfSections = 2;
    
    // If it's a currency price event there are 2 sections for Info and 1 section for News
   /* if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
    
        if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
            noOfSections = 2;
            
        } else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
            noOfSections = 1;
        }
    }
    // Else there are 3
    else {
        noOfSections = 3;
    } */
    
    return noOfSections;
}

// To style the header appropriately
-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UILabel *customHeaderView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 32)];
    
    // ipad needed special treatment in the past. If no longer needed you can probably consolidate this code
   /*if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
       [customHeaderView setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
       customHeaderView.textColor = [UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f];
       customHeaderView.textAlignment = NSTextAlignmentCenter;
       [customHeaderView setFont:[UIFont systemFontOfSize:14]];
       
       // If it's a currency price event there are 2 sections
       if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
           
           if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
               if(section == 0) {
                   [customHeaderView setText:@"STATS"];
               }
               if(section == 1) {
                   [customHeaderView setText:@"ABOUT"];
               }
               
           } else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
               if(section == 0) {
                   [customHeaderView setText:@"LATEST"];
               }
           }
       }
       // Else 3 sections
       else {
           if(section == 0) {
               [customHeaderView setText:@"SUMMARY"];
           }
           if(section == 1) {
               [customHeaderView setText:@"STATS"];
           }
           if(section == 2) {
               [customHeaderView setText:@"ABOUT"];
           }
       }
    } */
    // For all other devices
//    else {
        [customHeaderView setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        customHeaderView.textColor = [UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f];
        customHeaderView.textAlignment = NSTextAlignmentCenter;
        [customHeaderView setFont:[UIFont systemFontOfSize:14]];
    
        if(section == 0) {
            
            // Handle for US GDP Release, since the text doesn't contain US
           /* if ([self.eventType containsString:@"GDP Release"]) {
                if ([self.eventType containsString:@"India"]) {
                    [customHeaderView setText:[self.eventType uppercaseString]];
                }
                else
                {
                    [customHeaderView setText:[NSString stringWithFormat:@"US %@",[self.eventType uppercaseString]]];
                }
            }
            else
            {
                [customHeaderView setText:[self.eventType uppercaseString]];
            } */
            [customHeaderView setText:[self.eventType uppercaseString]];
        }
        if(section == 1) {
            [customHeaderView setText:@"MORE"];
        }
        
        // If it's a currency price event there are 2 sections
        /*if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
            
            if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
                if(section == 0) {
                    [customHeaderView setText:@"STATS"];
                }
                if(section == 1) {
                    [customHeaderView setText:@"ABOUT"];
                }
                
            } else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
                if(section == 0) {
                    [customHeaderView setText:@"LATEST"];
                }
            }
        }
        // Else 3 sections
        else {
            if(section == 0) {
                [customHeaderView setText:@"SUMMARY"];
            }
            if(section == 1) {
                [customHeaderView setText:@"STATS"];
            }
            if(section == 2) {
                [customHeaderView setText:@"ABOUT"];
            }
        }*/
//    }
    
    return customHeaderView;
}

// Not needed since you are using a Custom Header
/*- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
   NSString *sectionTitle = nil;
    
    // If it's a currency price event there are 2 sections
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
        if(section == 0) {
            sectionTitle = @"   STATS";
        }
        if(section == 1) {
            sectionTitle = @"   ABOUT";
        }
    }
    // Else 3 sections
    else {
        if(section == 0) {
            sectionTitle = @"   SUMMARY";
        }
        if(section == 1) {
            sectionTitle = @"   STATS";
        }
        if(section == 2) {
            sectionTitle = @"   ABOUT";
        }
    }
    
    return sectionTitle;
}*/

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //Default height is 93.0
    CGFloat cellHeight = 93.0;
    
    int rowNo = (int)indexPath.row;
    
    // If earnings use the shorter height
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        cellHeight = 70.0;
    }
    // For econ event
    else {
        if (indexPath.section == 0) {
            
            if ((rowNo == 0)||(rowNo == 1))
            {
                cellHeight = 70.0;
            }
            else {
                cellHeight = 93.0;
            }
        }
        if (indexPath.section == 1) {
           cellHeight = 70.0;
        }
    }
    
    
    // If info type details is selected
  /*  if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
        
        // Assign a row no to the type of event detail row.
        #define infoRow0  -1
        #define infoRow1  0
        #define infoRow2  1
        #define infoRow3  2
        #define infoRow4  3
        #define infoRow5  4
        #define infoRow6  5
        #define infoRow7  6
        #define infoRow8  7
        #define infoRow9  8
        #define infoRow10  9
        #define infoRow11 10
        #define infoRow12 11
        #define infoRow13 12
        #define infoRow14 13
        
        int rowNo = 0;
        
        // If it's a currency price event, start at Row 1
        if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
            if (indexPath.section == 0) {
                rowNo = (int)indexPath.row;
            }
            if (indexPath.section == 1) {
                rowNo = ((int)indexPath.row + 5);
            }
        }
        // If it's a news event, start at Row 0, which includes a description of the event.
        else {
            if (indexPath.section == 0) {
                rowNo = ((int)indexPath.row - 1);
            }
            if (indexPath.section == 1) {
                rowNo = (int)indexPath.row;
            }
            if (indexPath.section == 2) {
                rowNo = ((int)indexPath.row + 5);
            }
        }
        
        // Display the appropriate details based on the row no
        switch (rowNo) {
                
            case infoRow0:
            {
                cellHeight = 93.0;
            }
                break;
                
            case infoRow1:
            {
                cellHeight = 70.0;
            }
                break;
                
            case infoRow2:
            {
                cellHeight = 70.0;
            }
                break;
                
            case infoRow3:
            {
                cellHeight = 70.0;
            }
                break;
                
            case infoRow4:
            {
                cellHeight = 70.0;
            }
                break;
                
            case infoRow5:
            {
                cellHeight = 70.0;
            }
                break;
                
            case infoRow6:
            {
                cellHeight = 93.0;
            }
                break;
                
            case infoRow7:
            {
                cellHeight = 93.0;
            }
                break;
                
            case infoRow8:
            {
                cellHeight = 93.0;
            }
                break;
                
            case infoRow9:
            {
                cellHeight = 93.0;
            }
                break;
                
            case infoRow10:
            {
                cellHeight = 93.0;
            }
                break;
                
            case infoRow11:
            {
                cellHeight = 70.0;
            }
                break;
                
            case infoRow12:
            {
                cellHeight = 70.0;
            }
                break;
                
            case infoRow13:
            {
                cellHeight = 70.0;
            }
                break;
                
            case infoRow14:
            {
                cellHeight = 70.0;
            }
                break;
                
            default:
                break;
        }
    }
    
    // If News type detail is selected
    else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
        
        cellHeight = 93.0;
    } */
    
    return cellHeight;
}

// Set the table header to 32.0 height
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    
    CGFloat headerSize = 32.0;
    
    return headerSize;
}

// Return number of rows in the events list table view for a given section
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self getNoOfInfoPiecesForEventTypeForSection:section];
}

// Return a cell configured to display the event details based on the cell number and event type.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Get a custom cell to display details and reset states/colors of cell elements to avoid carryover
    FAEventDetailsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventDetailsCell" forIndexPath:indexPath];
    Event *eventData = [self.primaryDetailsDataController getEventForParentEventTicker:self.parentTicker andEventType:self.eventType];
    
    // NEW WAY
    // Assign a row no to the type of event detail row.
    #define infoRow0  -1
    #define infoRow1  0
    #define infoRow2  1
    #define infoRow3  2
    #define infoRow4  3
    #define infoRow5  4
    #define infoRow6  5
    #define infoRow7  6
    #define infoRow8  7
    #define infoRow9  8
  /*  #define infoRow10  9
    #define infoRow11 10
    #define infoRow12 11
    #define infoRow13 12
    #define infoRow14 13*/
    
    // Define formatters
    // Currency formatter. Currently using US locale for everything.
    NSNumberFormatter *currencyFormatter1 = [[NSNumberFormatter alloc] init];
    [currencyFormatter1 setNumberStyle:NSNumberFormatterCurrencyStyle];
    currencyFormatter1.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    [currencyFormatter1 setMaximumFractionDigits:2];
    
    // Define a not available value
    float notAvailable = 999999.9f;
    float zeroValue = 0.000000f;
    
    int rowNo = 0;
    
    // Adjust for different event types
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        if (indexPath.section == 0) {
            rowNo = (int)indexPath.row;
        }
        if (indexPath.section == 1) {
            rowNo = ((int)indexPath.row + 4);
        }
    }
    // If it's an econ event, there are 6 rows in section 1.
    // For econ events here are the 6 section 1 rows: Description(getShortDescriptionForEventType:),Impact Level (getImpactDescriptionForEventType:) + Impact(getEpsOrImpactTextForEventType:), Sectors Affected(getEpsOrSectorsTextForEventType:), Tip(getPriceSinceOrTipTextForEventType:).
    else {
        if (indexPath.section == 0) {
            rowNo = (int)indexPath.row;
        }
        if (indexPath.section == 1) {
            rowNo = ((int)indexPath.row + 6);
        }
    }
    
    // Default
    [[cell titleLabel] setText:@"NA"];
    [[cell descriptionArea] setText:@"Details not available."];
    
    // Display the appropriate details based on the row no
    switch (rowNo) {
            
        // Keep for later. Unused for now
        case infoRow0:
        {
           
        }
        break;
            
        // Show When for Earnings/Econ events
        case infoRow1:
        {
            // Hide detail action label
            cell.detailsActionLbl.textColor = [UIColor whiteColor];
            cell.detailsActionLbl.hidden = YES;
            
            // Correct Font and Colors
            cell.titleLabel.backgroundColor = [UIColor whiteColor];
            cell.titleLabel.textColor = [UIColor blackColor];
            [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:15]];
            [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
            [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
            
            // Earnings
            //if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                [[cell titleLabel] setText:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]];
                [[cell descriptionArea] setText:@"When"];
            //}
        }
            break;
            
        // Show Schedule for Earnings/Econ
        case infoRow2:
        {
            // Hide detail action label
            cell.detailsActionLbl.textColor = [UIColor whiteColor];
            cell.detailsActionLbl.hidden = YES;
            
            // Correct Font and Colors
            cell.titleLabel.backgroundColor = [UIColor whiteColor];
            cell.titleLabel.textColor = [UIColor blackColor];
            [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:15]];
            [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
            [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
            
            // Earnings
            //if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                [[cell titleLabel] setText:self.eventDateText];
                [[cell descriptionArea] setText:@"Schedule"];
            //}
        }
            break;
            
        // Show expected EPS for earnings/econ event description Sectors Affected(getEpsOrSectorsTextForEventType:)
        case infoRow3:
        {
            // Hide detail action label
            cell.detailsActionLbl.textColor = [UIColor whiteColor];
            cell.detailsActionLbl.hidden = YES;
            
            // Correct Font and Colors
            cell.titleLabel.backgroundColor = [UIColor whiteColor];
            cell.titleLabel.textColor = [UIColor blackColor];
            [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:17]];
            [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
            [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
            
            // Earnings
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                // Check that the eps value is available
                if (([eventData.estimatedEps floatValue] != notAvailable)&&([eventData.estimatedEps floatValue] != zeroValue))
                {
                    if ([eventData.estimatedEps floatValue] >=  0.0f) {
                        cell.titleLabel.textColor = [UIColor colorWithRed:41.0f/255.0f green:151.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
                        [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:17]];
                    } else {
                        cell.titleLabel.textColor = [UIColor colorWithRed:226.0f/255.0f green:35.0f/255.0f blue:95.0f/255.0f alpha:1.0f];
                        [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:17]];
                    }
                    
                    NSString *expectedEPS = [NSString stringWithFormat:@"%@", [currencyFormatter1 stringFromNumber:eventData.estimatedEps]];
                    
                    [[cell titleLabel] setText:expectedEPS];
                    [[cell descriptionArea] setText:@"Expected EPS"];
                }
                else
                {
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica" size:17]];
                    [[cell titleLabel] setText:@"NA"];
                    [[cell descriptionArea] setText:@"Expected EPS"];
                }
            }
            // Econ event description
            else {
                [[cell titleLabel] setText:@"?"];
                [[cell descriptionArea] setText:[self getShortDescriptionForEventType:eventData.type parentCompanyName:self.parentCompany]];
            }
        }
            break;
            
        // Show last eps for earnings/econ Tip(getPriceSinceOrTipTextForEventType:)
        case infoRow4:
        {
            // Hide detail action label
            cell.detailsActionLbl.textColor = [UIColor whiteColor];
            cell.detailsActionLbl.hidden = YES;
            
            // Correct Font and Colors
            cell.titleLabel.backgroundColor = [UIColor whiteColor];
            cell.titleLabel.textColor = [UIColor blackColor];
            [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:17]];
            [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
            [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
            
            // Earnings
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                
                if (([eventData.actualEpsPrior floatValue] != notAvailable)&&([eventData.actualEpsPrior floatValue] != zeroValue))
                {
                    if ([eventData.actualEpsPrior floatValue] >=  0.0f) {
                        cell.titleLabel.textColor = [UIColor colorWithRed:41.0f/255.0f green:151.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
                        [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:17]];
                    } else {
                        cell.titleLabel.textColor = [UIColor colorWithRed:226.0f/255.0f green:35.0f/255.0f blue:95.0f/255.0f alpha:1.0f];
                        [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:17]];
                    }
                    
                    NSString *lastEPS = [NSString stringWithFormat:@"%@", [currencyFormatter1 stringFromNumber:eventData.actualEpsPrior]];
                    
                    [[cell titleLabel] setText:lastEPS];
                    [[cell descriptionArea] setText:@"Last EPS"];
                }
                else
                {
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica" size:17]];
                    [[cell titleLabel] setText:@"NA"];
                    [[cell descriptionArea] setText:@"Last EPS"];
                }
            }
            // Econ impact level
            else {
                [[cell titleLabel] setText:[self getImpactDescriptionForEventType:eventData.type eventParent:self.parentCompany]];
                [[cell descriptionArea] setText:[self getEpsOrImpactTextForEventType:eventData.type eventParent:self.parentCompany]];
            }
        }
            break;
            
        // Show Action 1
        case infoRow5:
        {
            // Earnings - Price on CNBC
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                // Hide the action label anyways
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                
                // Format the title label & description
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                cell.titleLabel.textColor = [UIColor colorWithRed:21.0f/255.0f green:85.0f/255.0f blue:148.0f/255.0f alpha:1.0f];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                [[cell titleLabel] setText:@"$"];
                [[cell descriptionArea] setText:@"See Price"];
            }
            // Econ Sectors Affected(getEpsOrSectorsTextForEventType:)
            else {
                
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:17]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                if ([self.eventType containsString:@"Fed Meeting"]) {
                    // Select the appropriate color and text for Financial Stocks
                    cell.titleLabel.textColor = [UIColor colorWithRed:104.0f/255.0f green:182.0f/255.0f blue:37.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"$"];
                }
                
                if ([self.eventType containsString:@"Jobs Report"]) {
                    // Select the appropriate color and text for All Stocks
                    cell.titleLabel.textColor = [UIColor orangeColor];
                    [[cell titleLabel] setText:@"❖"];
                }
                
                if ([self.eventType containsString:@"Consumer Confidence"]) {
                    // Select the appropriate color and text for Retail Stocks
                    // Pinkish deep red
                    cell.titleLabel.textColor = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"⦿"];
                }
                
                if ([self.eventType containsString:@"GDP Release"]) {
                    // Select the appropriate color and text for All Stocks
                    cell.titleLabel.textColor = [UIColor orangeColor];
                    [[cell titleLabel] setText:@"❖"];
                }
                
                // New econ events types
                if ([self.eventType containsString:@"US Retail Sales"]) {
                    // Select the appropriate color and text for Retail Stocks
                    // Pinkish deep red
                    cell.titleLabel.textColor = [UIColor colorWithRed:233.0f/255.0f green:65.0f/255.0f blue:78.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"⦿"];
                }
                if ([self.eventType containsString:@"US Housing Starts"]) {
                    // Select the appropriate color and text for Retail Stocks
                    // Blue
                    cell.titleLabel.textColor = [UIColor colorWithRed:0.0f/255.0f green:117.0f/255.0f blue:251.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"⌂"];
                }
                if ([self.eventType containsString:@"US New Homes Sales"]) {
                    // Select the appropriate color and text for Retail Stocks
                    // Blue
                    cell.titleLabel.textColor = [UIColor colorWithRed:0.0f/255.0f green:117.0f/255.0f blue:251.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"⌂"];
                }
                // End new econ events types
                
                [[cell descriptionArea] setText:[self getEpsOrSectorsTextForEventType:eventData.type]];
             }
        }
            break;
            
        // Show Action 2 - See News
        case infoRow6:
        {
            // Earnings
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                // Hide the action label anyways
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                
                // Format the title label & description
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                cell.titleLabel.textColor = [UIColor colorWithRed:85.0f/255.0f green:169.0f/255.0f blue:84.0f/255.0f alpha:1.0f];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                [[cell titleLabel] setText:@"𝗡"];
                [[cell descriptionArea] setText:[self getActionType4ForEvent:self.eventType withEventDistance:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]]];
            }
            // Econ Impact Level (getPriceSinceOrTipTextForEventType:)
            else {
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:17]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                // Econ Blue
                cell.titleLabel.textColor = [UIColor blackColor];
                [[cell titleLabel] setText:@"!"];
                [[cell descriptionArea] setText:[self getPriceSinceOrTipTextForEventType:eventData.type additionalInfo:@"NA"]];
             }
        }
            break;
            
        // Show Action 3
        case infoRow7:
        {
            // Hide the action label anyways
            cell.detailsActionLbl.textColor = [UIColor whiteColor];
            cell.detailsActionLbl.hidden = YES;
            
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                
            // Format the title label & description
            cell.titleLabel.backgroundColor = [UIColor whiteColor];
            [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
            cell.titleLabel.textColor = [UIColor colorWithRed:245.0f/255.0f green:115.0f/255.0f blue:67.0f/255.0f alpha:1.0f];
            [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
            [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
            
            [[cell titleLabel] setText:@"𝗘"];
            [[cell descriptionArea] setText:[self getActionType1ForEvent:self.eventType withEventDistance:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]]];
            }
            // For econ events
            else {
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                // Econ Blue  close to current blue in icon
                cell.titleLabel.textColor = [UIColor colorWithRed:21.0f/255.0f green:85.0f/255.0f blue:148.0f/255.0f alpha:1.0f];
                [[cell titleLabel] setText:@"▶︎"];
                [[cell descriptionArea] setText:[self getActionType1ForEvent:self.eventType withEventDistance:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]]];
            }
        }
            break;
            
        // Show Action 4
        case infoRow8:
        {
            // Hide the action label anyways
            cell.detailsActionLbl.textColor = [UIColor whiteColor];
            cell.detailsActionLbl.hidden = YES;
            
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                // Format the title label & description
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                cell.titleLabel.textColor = [self.dataSnapShot2 getBrandBkgrndColorForCompany:self.parentTicker];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica-Bold" size:15]];
                [cell.descriptionArea setTextColor:[UIColor blackColor]];
                
                [[cell titleLabel] setText:@"▶︎"];
                // Play Earnings Call
                [[cell descriptionArea] setText:[self getActionType2ForEvent:self.eventType withEventDistance:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]]];
            }
            // If econ events
            else {
                // Format the title label & description
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                cell.titleLabel.textColor = [UIColor colorWithRed:85.0f/255.0f green:169.0f/255.0f blue:84.0f/255.0f alpha:1.0f];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                [[cell titleLabel] setText:@"𝗡"];
                [[cell descriptionArea] setText:[self getActionType4ForEvent:self.eventType withEventDistance:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]]];
            }
            
            
            //View Transcript
            //[[cell descriptionArea] setText:[self getActionType3ForEvent:self.eventType withEventDistance:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]]];
        }
            break;
            
        // Show Action 5 - Go to Investor Site
        case infoRow9:
        {
            // Hide the action label anyways
            cell.detailsActionLbl.textColor = [UIColor whiteColor];
            cell.detailsActionLbl.hidden = YES;
            
            // Format the title label & description
            cell.titleLabel.backgroundColor = [UIColor whiteColor];
            [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
            cell.titleLabel.textColor = [self.dataSnapShot2 getBrandBkgrndColorForCompany:self.parentTicker];
            [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
            [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
            
            [[cell titleLabel] setText:@"▷"];
            [[cell descriptionArea] setText:[self getActionType5ForEvent:self.eventType withEventDistance:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]]];
        }
            break;
    
        default:
            break;
    }
    
    
    // OLD WAY WHERE INFO AND NEWS SELECTOR IS AVAILABLE
    // If info type details is selected
   /* if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
        
        NSString *actionLocation = nil;
        
        // Get the event details parts of which will be displayed in the details table
        // Trickery: We basically want to get the price change event to get the related details, so when viewing a news event trick it into getting the price change event
        EventHistory *eventHistoryData = nil;
        if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
            eventData = [self.primaryDetailsDataController getEventForParentEventTicker:self.parentTicker andEventType:self.eventType];
        }
        else {
            eventData = [self.primaryDetailsDataController getEventForParentEventTicker:self.parentTicker andEventType:@"% up today"];
        }
        // Set the event history details
        eventHistoryData = (EventHistory *)[eventData relatedEventHistory];
        
        // Define formatters
        // Currency formatter. Currently using US locale for everything.
        NSNumberFormatter *currencyFormatter1 = [[NSNumberFormatter alloc] init];
        [currencyFormatter1 setNumberStyle:NSNumberFormatterCurrencyStyle];
        currencyFormatter1.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
        [currencyFormatter1 setMaximumFractionDigits:0];
        
        NSNumberFormatter *currencyFormatter2 = [[NSNumberFormatter alloc] init];
        [currencyFormatter2 setNumberStyle:NSNumberFormatterCurrencyStyle];
        currencyFormatter2.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
        [currencyFormatter2 setMaximumFractionDigits:4];
        
        NSNumberFormatter *twoDecNumberFormatter = [[NSNumberFormatter alloc] init];
        twoDecNumberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        [twoDecNumberFormatter setMaximumFractionDigits:2];
        
        // Assign a row no to the type of event detail row.
        #define infoRow0  -1
        #define infoRow1  0
        #define infoRow2  1
        #define infoRow3  2
        #define infoRow4  3
        #define infoRow5  4
        #define infoRow6  5
        #define infoRow7  6
        #define infoRow8  7
        #define infoRow9  8
        #define infoRow10  9
        #define infoRow11 10
        #define infoRow12 11
        #define infoRow13 12
        #define infoRow14 13
        
        int rowNo = 0;
        
        // If it's a currency price event, start at Row 1
        if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
            if (indexPath.section == 0) {
                rowNo = (int)indexPath.row;
            }
            if (indexPath.section == 1) {
                rowNo = ((int)indexPath.row + 5);
            }
        }
        // If it's a news event, start at Row 0, which includes a description of the event.
        else {
            if (indexPath.section == 0) {
                rowNo = ((int)indexPath.row - 1);
            }
            if (indexPath.section == 1) {
                rowNo = (int)indexPath.row;
            }
            if (indexPath.section == 2) {
                rowNo = ((int)indexPath.row + 5);
            }
        }
        
        // Default
        [[cell titleLabel] setText:@"NA"];
        [[cell descriptionArea] setText:@"Details not available."];
        
        // Display the appropriate details based on the row no
        switch (rowNo) {
                
                // Show impact and desscription for product events right now.
            case infoRow0:
            {
                // Hide detail action label
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                
                // Get Impact String
                NSString *impact_str = [self getImpactDescriptionForEventType:self.eventType eventParent:self.parentTicker];
                
                // Set proper formatting
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                cell.titleLabel.textColor = [UIColor blackColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:16]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // Set the impact icon
                // Very High Impact
                if ([impact_str caseInsensitiveCompare:@"Very High Impact"] == NSOrderedSame) {
                    [[cell titleLabel] setText:@"Very High Impact"];
                }
                // High Impact
                if ([impact_str caseInsensitiveCompare:@"High Impact"] == NSOrderedSame) {
                    //cell.titleLabel.textColor = [UIColor colorWithRed:229.0f/255.0f green:55.0f/255.0f blue:53.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"High Impact"];
                }
                // Medium Impact
                if ([impact_str caseInsensitiveCompare:@"Medium Impact"] == NSOrderedSame) {
                    //cell.titleLabel.textColor = [UIColor colorWithRed:255.0f/255.0f green:127.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"Medium Impact"];
                }
                // Low Impact
                if ([impact_str caseInsensitiveCompare:@"Low Impact"] == NSOrderedSame) {
                    //cell.titleLabel.textColor = [UIColor colorWithRed:207.0f/255.0f green:187.0f/255.0f blue:29.0f/255.0f alpha:1.0f];
                    [[cell titleLabel] setText:@"Low Impact"];
                }
                
                // Set the rationale
                [[cell descriptionArea] setText:[NSString stringWithFormat:@"%@",[self getEventDescriptionForEventType:self.eventType eventParent:self.parentTicker]]];
            }
                break;
                
                // Show Market Cap Rank and Total
            case infoRow1:
            {
                // Hide detail action label
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                
                // Correct Font and Colors
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                cell.titleLabel.textColor = [UIColor blackColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:19]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:16]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // Total Cap String
                NSString *totalCapString = [NSString stringWithFormat:@"%@", [currencyFormatter1 stringFromNumber:eventData.estimatedEps]];
                // Cap Rank String
                NSString *capCumulativeStr = [NSString stringWithFormat:@"#%@  %@", eventData.relatedDetails, totalCapString];
                
                [[cell titleLabel] setText:capCumulativeStr];
                [[cell descriptionArea] setText:@"MARKET CAP"];
            }
                break;
                
                // Show Current Price
            case infoRow2:
            {
                // Hide detail action label
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:19]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:16]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // Default State Colors
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                // If 24 hr price change is 0 or positive set green else red
                if ([eventHistoryData.previous1RelatedPrice floatValue] >= 0.0f) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:41.0f/255.0f green:151.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                } else {
                    cell.titleLabel.textColor = [UIColor colorWithRed:226.0f/255.0f green:35.0f/255.0f blue:95.0f/255.0f alpha:1.0f];
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:18]];
                }
                
                // Curr Price String
                NSString *currPriceString = [NSString stringWithFormat:@"%@", [currencyFormatter2 stringFromNumber:eventHistoryData.currentPrice]];
                
                [[cell titleLabel] setText:currPriceString];
                [[cell descriptionArea] setText:@"CURRENT PRICE"];
            }
                break;
                
                // Show 1 Hr Price Change
            case infoRow3:
            {
                // Hide detail action label
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:19]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:16]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // Default State Colors
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                // If 1 hr price change is 0 or positive set green else red
                if ([eventData.actualEpsPrior floatValue] >=  0.0f) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:41.0f/255.0f green:151.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                } else {
                    cell.titleLabel.textColor = [UIColor colorWithRed:226.0f/255.0f green:35.0f/255.0f blue:95.0f/255.0f alpha:1.0f];
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:18]];
                }
                
                NSString *oneChangeString = [NSString stringWithFormat:@"%@%%", [twoDecNumberFormatter stringFromNumber:eventData.actualEpsPrior]];
                
                [[cell titleLabel] setText:oneChangeString];
                [[cell descriptionArea] setText:@"1 HR PRICE CHANGE"];
            }
                break;
                
                // Show 24 Hr Price Change
            case infoRow4:
            {
                // Hide detail action label
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:19]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:16]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // Default State Colors
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                // If 24 hr price change is 0 or positive set green else red
                if ([eventHistoryData.previous1RelatedPrice floatValue] >= 0.0f) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:41.0f/255.0f green:151.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                } else {
                    cell.titleLabel.textColor = [UIColor colorWithRed:226.0f/255.0f green:35.0f/255.0f blue:95.0f/255.0f alpha:1.0f];
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:18]];
                }
                
                // Curr Price String
                NSString *twentyChangeString = [NSString stringWithFormat:@"%@%%", [twoDecNumberFormatter stringFromNumber:eventHistoryData.previous1RelatedPrice]];
                
                [[cell titleLabel] setText:twentyChangeString];
                [[cell descriptionArea] setText:@"24 HR PRICE CHANGE"];
            }
                break;
                
                // Show 7 Days Price Change
            case infoRow5:
            {
                // Hide detail action label
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:19]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:16]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // Default State Colors
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                // If 24 hr price change is 0 or positive set green else red
                if ([eventHistoryData.previous1Price floatValue] >= 0.0f) {
                    cell.titleLabel.textColor = [UIColor colorWithRed:41.0f/255.0f green:151.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
                } else {
                    cell.titleLabel.textColor = [UIColor colorWithRed:226.0f/255.0f green:35.0f/255.0f blue:95.0f/255.0f alpha:1.0f];
                    [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:18]];
                }
                
                // Curr Price String
                NSString *sevenChangeString = [NSString stringWithFormat:@"%@%%", [twoDecNumberFormatter stringFromNumber:eventHistoryData.previous1Price]];
                
                [[cell titleLabel] setText:sevenChangeString];
                [[cell descriptionArea] setText:@"7 DAYS PRICE CHANGE"];
            }
                break;
                
                // Show What is ?
            case infoRow6:
            {
                // Show action detail label if the data exists
                actionLocation = [NSString stringWithFormat:@"%@",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:2]];
                
                // Set proper formatting
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                cell.titleLabel.textColor =[self getColorForEventType:self.eventType];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:18]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // What is <coin name>
                NSString *whatIsString = [NSString stringWithFormat:@"%@",[self.parentCompany uppercaseString]];
                NSString *descString = [NSString stringWithFormat:@"%@.",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:0]];
                
                if ([actionLocation caseInsensitiveCompare:@"Not Available"] == NSOrderedSame)
                {
                    cell.detailsActionLbl.textColor = [UIColor whiteColor];
                    cell.detailsActionLbl.hidden = YES;
                }
                else
                {
                    cell.detailsActionLbl.textColor = [self getColorForEventType:self.eventType];
                    cell.detailsActionLbl.hidden = NO;
                }
                
                [[cell titleLabel] setText:whatIsString];
                [[cell descriptionArea] setText:descString];
                [[cell detailsActionLbl] setText:@"Website >"];
            }
                break;
                
                // Show Use Cases
            case infoRow7:
            {
                // Show action detail label if the data exists
                actionLocation = [NSString stringWithFormat:@"%@",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:3]];
                
                if ([actionLocation caseInsensitiveCompare:@"Not Available"] == NSOrderedSame)
                {
                    cell.detailsActionLbl.textColor = [UIColor whiteColor];
                    cell.detailsActionLbl.hidden = YES;
                }
                else
                {
                    cell.detailsActionLbl.textColor = [UIColor blackColor];
                    cell.detailsActionLbl.hidden = NO;
                }
                
                // Set proper formatting
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                cell.titleLabel.textColor = [UIColor blackColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // Used For
                NSString *usedForString = [NSString stringWithFormat:@"USES"];
                NSString *usedForDescString = [NSString stringWithFormat:@"%@.",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:1]];
                
                [[cell titleLabel] setText:usedForString];
                [[cell descriptionArea] setText:usedForDescString];
                [[cell detailsActionLbl] setText:@"Details >"];
            }
                break;
                
                // Show Backed By
            case infoRow8:
            {
                // Set proper formatting
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                cell.titleLabel.textColor = [UIColor blackColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                // Backed By
                NSString *backedByString = [NSString stringWithFormat:@"BACKERS"];
                NSString *backedByDescString = [NSString stringWithFormat:@"%@.",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:7]];
                
                [[cell titleLabel] setText:backedByString];
                [[cell descriptionArea] setText:backedByDescString];
            }
                break;
                
                // Show Concerns
            case infoRow9:
            {
                // Set proper formatting
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                cell.titleLabel.textColor = [UIColor blackColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                NSString *concernsString = [NSString stringWithFormat:@"CONCERNS"];
                NSString *concernsDescString = [NSString stringWithFormat:@"%@.",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:8]];
                
                [[cell titleLabel] setText:concernsString];
                [[cell descriptionArea] setText:concernsDescString];
            }
                break;
                
            // Show Exchanges
            case infoRow10:
            {
                // Set proper formatting
                cell.detailsActionLbl.textColor = [UIColor whiteColor];
                cell.detailsActionLbl.hidden = YES;
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                cell.titleLabel.textColor = [UIColor blackColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                NSString *exchangesString = [NSString stringWithFormat:@"EXCHANGES"];
                NSString *exchangesListString = [NSString stringWithFormat:@"%@.",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:11]];
                
                [[cell titleLabel] setText:exchangesString];
                [[cell descriptionArea] setText:exchangesListString];
            }
                break;
                
                // Show Reddit
            case infoRow11:
            {
                // Show action detail label if the data exists
                actionLocation = [NSString stringWithFormat:@"%@",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:4]];
                
                if ([actionLocation caseInsensitiveCompare:@"Not Available"] == NSOrderedSame)
                {
                    cell.detailsActionLbl.textColor = [UIColor whiteColor];
                    cell.detailsActionLbl.hidden = YES;
                    cell.titleLabel.textColor = [UIColor blackColor];
                }
                else
                {
                    // Reddit Orangish Red
                    cell.detailsActionLbl.textColor = [UIColor colorWithRed:233.0f/255.0f green:63.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
                    cell.detailsActionLbl.hidden = NO;
                    cell.titleLabel.textColor = [UIColor colorWithRed:233.0f/255.0f green:63.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
                }
                
                // Set proper formatting
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                NSString *redditTxt = [NSString stringWithFormat:@"SEE REDDIT DISCUSSION"];
                NSString *subRedditExt = [NSString stringWithFormat:@"%@",actionLocation];
                
                [[cell titleLabel] setText:subRedditExt];
                [[cell descriptionArea] setText:redditTxt];
                [[cell detailsActionLbl] setText:@">"];
            }
                break;
                
                // Show Twitter
            case infoRow12:
            {
                NSString *twitterHandle = nil;
                
                // Show action detail label if the data exists
                actionLocation = [NSString stringWithFormat:@"%@",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:6]];
                
                if ([actionLocation caseInsensitiveCompare:@"Not Available"] == NSOrderedSame)
                {
                    cell.detailsActionLbl.textColor = [UIColor whiteColor];
                    cell.detailsActionLbl.hidden = YES;
                    cell.titleLabel.textColor = [UIColor blackColor];
                    twitterHandle = [NSString stringWithFormat:@"%@",actionLocation];
                }
                else
                {
                    // Twitter Blue
                    cell.detailsActionLbl.textColor = [UIColor colorWithRed:34.0f/255.0f green:125.0f/255.0f blue:251.0f/255.0f alpha:1.0f];
                    cell.detailsActionLbl.hidden = NO;
                    cell.titleLabel.textColor = [UIColor colorWithRed:34.0f/255.0f green:125.0f/255.0f blue:251.0f/255.0f alpha:1.0f];
                    twitterHandle = [NSString stringWithFormat:@"@%@",actionLocation];
                }
                
                // Set proper formatting
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                NSString *twitterTxt = [NSString stringWithFormat:@"SEE TWEETS"];
                
                [[cell titleLabel] setText:twitterHandle];
                [[cell descriptionArea] setText:twitterTxt];
                [[cell detailsActionLbl] setText:@">"];
            }
                break;
                
                // Show Github
            case infoRow13:
            {
                // Show action detail label if the data exists
                actionLocation = [NSString stringWithFormat:@"%@",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:5]];
                
                if ([actionLocation caseInsensitiveCompare:@"Not Available"] == NSOrderedSame)
                {
                    cell.detailsActionLbl.textColor = [UIColor whiteColor];
                    cell.detailsActionLbl.hidden = YES;
                    cell.titleLabel.textColor = [UIColor blackColor];
                }
                else
                {
                    // Code Blue
                    cell.detailsActionLbl.textColor = [UIColor colorWithRed:0.0f/255.0f green:102.0f/255.0f blue:214.0f/255.0f alpha:1.0f];
                    cell.detailsActionLbl.hidden = NO;
                    cell.titleLabel.textColor = [UIColor colorWithRed:0.0f/255.0f green:102.0f/255.0f blue:214.0f/255.0f alpha:1.0f];
                }
                
                // Set proper formatting
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:15]];
                [cell.descriptionArea setTextColor:[UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f]];
                
                NSString *githubTxt = [NSString stringWithFormat:@"SEE GITHUB ACTIVITY"];
                NSString *githubRepo = [NSString stringWithFormat:@"%@",actionLocation];
                
                [[cell titleLabel] setText:githubRepo];
                [[cell descriptionArea] setText:githubTxt];
                [[cell detailsActionLbl] setText:@">"];
            }
                break;
                
            // Show data warning
            case infoRow14:
            {
                // Set proper formatting
                cell.detailsActionLbl.hidden = NO;
                cell.detailsActionLbl.textColor = [UIColor grayColor];
                cell.titleLabel.textColor = [UIColor grayColor];
                cell.titleLabel.backgroundColor = [UIColor whiteColor];
                [cell.titleLabel setFont:[UIFont fontWithName:@"Helvetica" size:14]];
                [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:10]];
                [cell.descriptionArea setTextColor:[UIColor grayColor]];
                
                NSString *dataTxt = [NSString stringWithFormat:@"©"];
                NSString *dataDesc = @"About data by Litchi Labs.Contact us to reuse.";
                
                [[cell titleLabel] setText:dataTxt];
                [[cell descriptionArea] setText:dataDesc];
                [[cell detailsActionLbl] setText:@">"];
            }
                break;
                
            default:
                break;
        }
    }
    
    // If News type detail is selected
    else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
        
        eventData = [self.infoResultsController objectAtIndexPath:indexPath];
        
        // Proper formatting
        [cell.descriptionArea setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        [cell.descriptionArea setTextColor:[UIColor blackColor]];
        cell.detailsActionLbl.hidden = NO;
        cell.detailsActionLbl.textColor = [UIColor lightGrayColor];
        
        // Set the source for attribution
        //[[cell  titleLabel] setText:[self.dataSnapShot2 getNewsSource:eventData]];
        //[[cell titleLabel] setAttributedText:[self.dataSnapShot2 getFormattedSource:[self.dataSnapShot2 getNewsSource:eventData]]];
        
        // Show the news title
        [[cell descriptionArea] setText:[self formatEventType:eventData]];
        
        // Set the date of the article to the eventImpact.
        [[cell detailsActionLbl] setText:[self calculateDistanceFromEventDate:eventData.date withEventType:eventData.type]];
    }
    */
    
    return cell;
}

// When a row is selected send it to the respective detail view based on section and cell
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Get a custom cell to display details and reset states/colors of cell elements to avoid carryover
    FAEventDetailsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventDetailsCell" forIndexPath:indexPath];
    
    // NEW WAY
    // Assign a row no to the type of event detail row.
    #define infoRow0  -1
    #define infoRow1  0
    #define infoRow2  1
    #define infoRow3  2
    #define infoRow4  3
    #define infoRow5  4
    #define infoRow6  5
    #define infoRow7  6
    #define infoRow8  7
    #define infoRow9  8
    /*  #define infoRow10  9
     #define infoRow11 10
     #define infoRow12 11
     #define infoRow13 12
     #define infoRow14 13*/
    
    // Define formatters
    // Currency formatter. Currently using US locale for everything.
    NSNumberFormatter *currencyFormatter1 = [[NSNumberFormatter alloc] init];
    [currencyFormatter1 setNumberStyle:NSNumberFormatterCurrencyStyle];
    currencyFormatter1.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    [currencyFormatter1 setMaximumFractionDigits:2];
    
    // Target URLs
    NSString *actionURL = nil;
    NSURL *targetURL = nil;
    
    int rowNo = 0;
    
    // Adjust for different event types
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        if (indexPath.section == 0) {
            rowNo = (int)indexPath.row;
        }
        if (indexPath.section == 1) {
            rowNo = ((int)indexPath.row + 4);
        }
    }
    // If it's an econ event.
    else {
        if (indexPath.section == 0) {
            rowNo = (int)indexPath.row;
        }
        if (indexPath.section == 1) {
            rowNo = ((int)indexPath.row + 6);
        }
    }
    
    // Default
    [[cell titleLabel] setText:@"NA"];
    [[cell descriptionArea] setText:@"Details not available."];
    
    // Display the appropriate details based on the row no
    switch (rowNo) {
            
        // Use for econ event
        case infoRow0:
        {
            
        }
            break;
            
        // Show When
        case infoRow1:
        {
            
        }
            break;
            
        // Show Schedule
        case infoRow2:
        {
            
        }
            break;
            
        // Show expected EPS
        case infoRow3:
        {
            
        }
            break;
            
        // Show last eps
        case infoRow4:
        {
            
        }
            break;
            
        // Show Action 1
        case infoRow5:
        {
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                actionURL = [NSString stringWithFormat:@"%@",[self getLocationType6ForEvent:self.eventType withTicker:self.parentTicker]];
                targetURL = [NSURL URLWithString:actionURL];
                
                if (targetURL) {
                    
                    // TRACKING EVENT:
                    // TO DO: Disabling to not track development events. Enable before shipping.
                    [FBSDKAppEvents logEvent:@"Take External Action"
                                  parameters:@{ @"Ticker" : self.parentTicker,
                                                @"Event" : self.eventType,
                                                @"Action" : @"see Price"} ];
                    
                    SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
                    externalInfoVC.delegate = self;
                    [self presentViewController:externalInfoVC animated:YES completion:nil];
                }
            }
            // Do nothing for Econ
            else {
                
            }
        }
            break;
            
        // Show Action 2 See News
        case infoRow6:
        {
            if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
                actionURL = [NSString stringWithFormat:@"%@",[self getActionLocation4ForEvent:self.eventType]];
                targetURL = [NSURL URLWithString:actionURL];
                
                if (targetURL) {
                    
                    // TRACKING EVENT:
                    // TO DO: Disabling to not track development events. Enable before shipping.
                    [FBSDKAppEvents logEvent:@"Take External Action"
                                  parameters:@{ @"Ticker" : self.parentTicker,
                                                @"Event" : self.eventType,
                                                @"Action" : @"See Google News"} ];
                    
                    SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
                    externalInfoVC.delegate = self;
                    [self presentViewController:externalInfoVC animated:YES completion:nil];
                }
            }
            // Do nothing for Econ
            else {
                
            }
        }
            break;
            
        // Show Action 3
        case infoRow7:
        {
            actionURL = [NSString stringWithFormat:@"%@",[self getActionLocation1ForEvent:self.eventType withTicker:self.parentTicker]];
            targetURL = [NSURL URLWithString:actionURL];
            
            
            if (targetURL) {
                
                // TRACKING EVENT:
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Take External Action"
                              parameters:@{ @"Ticker" : self.parentTicker,
                                            @"Event" : self.eventType,
                                            @"Action" : @"Preview Earnings/See Econ Agency Site"} ];
                
                SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
                externalInfoVC.delegate = self;
                [self presentViewController:externalInfoVC animated:YES completion:nil];
            }
        }
            break;
            
        // Show Action 3
        case infoRow8:
        {
            actionURL = [NSString stringWithFormat:@"%@",[self getActionLocation2ForEvent:self.eventType]];
            targetURL = [NSURL URLWithString:actionURL];
            
            // Delete Later:
            NSLog(@"Clicked URL is:%@",targetURL);
            
            if (targetURL) {
                
                // TRACKING EVENT:
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Take External Action"
                              parameters:@{ @"Ticker" : self.parentTicker,
                                            @"Event" : self.eventType,
                                            @"Action" : @"Play Earnings Call/Scan Econ News"} ];
                
                SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
                externalInfoVC.delegate = self;
                [self presentViewController:externalInfoVC animated:YES completion:nil];
            }
        }
            break;
            
        // Show Action 5 Go to Investor Site
        case infoRow9:
        {
            actionURL = [NSString stringWithFormat:@"%@",[self getActionLocation5ForEvent:self.eventType]];
            targetURL = [NSURL URLWithString:actionURL];
            
            // Delete Later:
            NSLog(@"Clicked URL is:%@",targetURL);
            
            if (targetURL) {
                
                // TRACKING EVENT:
                // TO DO: Disabling to not track development events. Enable before shipping.
                [FBSDKAppEvents logEvent:@"Take External Action"
                              parameters:@{ @"Ticker" : self.parentTicker,
                                            @"Event" : self.eventType,
                                            @"Action" : @"Go To Investor Site"} ];
                
                SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
                externalInfoVC.delegate = self;
                // Just use whatever is the default color for the Safari View Controller
                //externalInfoVC.preferredControlTintColor = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
                [self presentViewController:externalInfoVC animated:YES completion:nil];
            }
        }
            break;
            
        default:
            break;
    }
}

// When a user scrolls on the detail view
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // TRACKING EVENT:
    // TO DO: Disabling to not track development events. Enable before shipping.
    [FBSDKAppEvents logEvent:@"Viewed About"
                  parameters:@{ @"About Ticker" : self.parentTicker} ];
}

#pragma mark - Info Selector Related

// Take action when a details info type is selected
- (IBAction)detailsInfoTypeSelected:(id)sender {
    
    // Reset the navigation bar header text color to black
    NSDictionary *regularHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                             [UIColor blackColor], NSForegroundColorAttributeName,
                                             nil];
    [self.navigationController.navigationBar setTitleTextAttributes:regularHeaderAttributes];
    
    
    // Set text color and size of all unselected segments to a medium dark gray used in the event dates (R:113, G:113, B:113)
    NSDictionary *unselectedAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [UIFont systemFontOfSize:16], NSFontAttributeName,
                                          [UIColor colorWithRed:113.0f/255.0f green:113.0f/255.0f blue:113.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                          nil];
    [self.detailsInfoSelector setTitleTextAttributes:unselectedAttributes forState:UIControlStateNormal];
    // Set text and size for selected segment
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [UIFont boldSystemFontOfSize:16], NSFontAttributeName,
                                    [UIColor blackColor], NSForegroundColorAttributeName,
                                    nil];
    [self.detailsInfoSelector setTitleTextAttributes:textAttributes forState:UIControlStateSelected];
    
    // If Info
    if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
        
        // Reset the company name in the navigation bar header.
        self.navigationItem.title = [self.eventTitleStr uppercaseString];
        
        // Format
        [self.bottomBorderLbl1 setBackgroundColor:[UIColor blackColor]];
        [self.bottomBorderLbl1 setTintColor:[UIColor blackColor]];
        [self.bottomBorderLbl1 setTextColor:[UIColor blackColor]];
        [self.bottomBorderLbl2 setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl2 setTextColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        
        //Action
        [self.eventDetailsTable reloadData];
        
        // TRACKING EVENT: Event Type Selected: User selected Crypto event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"Event Type Selected"
                      parameters:@{ @"Event Type" : @"Price Info in Details" } ];
    }
    // If News
    else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
        
        // Reset crypto in the navigation bar header.
        self.navigationItem.title = @"CRYPTO";
        
        // Format
        [self.bottomBorderLbl2 setBackgroundColor:[UIColor blackColor]];
        [self.bottomBorderLbl2 setTintColor:[UIColor blackColor]];
        [self.bottomBorderLbl2 setTextColor:[UIColor blackColor]];
        [self.bottomBorderLbl1 setBackgroundColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl1 setTintColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [self.bottomBorderLbl1 setTextColor:[UIColor colorWithRed:241.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        
        // Action
        // Reload the details table with the news.
        //self.infoResultsController = [self.primaryDetailsDataController getLatestCryptoEvents];
        [self.eventDetailsTable reloadData];
        
        // Set navigation bar header to an attention orange color
        NSDictionary *attentionHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                                   [UIColor colorWithRed:205.0f/255.0f green:151.0f/255.0f blue:61.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                                   nil];
        [self.navigationController.navigationBar setTitleTextAttributes:attentionHeaderAttributes];
        //[self.navigationController.navigationBar.topItem setTitle:[notification object]];
        self.navigationItem.title = @"Fetching...";
        
        // Force a pull down to refresh asynchronously
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
            dispatch_async(dispatch_get_main_queue(), ^{
                // Trigger the table refresh
                [self.deetsTblRefreshControl sendActionsForControlEvents:UIControlEventValueChanged];
            });
        });
        
        
        // TRACKING EVENT: Event Type Selected: User selected Crypto event type explicitly in the events type selector
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"In App News Viewed"
                      parameters:@{ @"Event Type" : @"Latest News in Details" } ];
    }
}

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

// Show them Google news
- (IBAction)seeNewsAction2:(id)sender {
    
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
    searchTerm = [NSString stringWithFormat:@"%@",@"cryptocurrency news"];
    
    // If price change event this button label is <TICKER> News and links out to Ticker cryptocurrency.
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
        searchTerm = [NSString stringWithFormat:@"%@ %@",self.parentCompany,@"cryptocurrency"];
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
        targetURL = [NSURL URLWithString:moreInfoURL];
    }
    // Else the button label is Best Info and links out to the linked article stored as part of the event.
    else {
        moreInfoURL = [self getBestInfoUrlWithEventType:self.eventType eventParentTicker:self.parentTicker];
        targetURL = [NSURL URLWithString:moreInfoURL];
    }
    
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

// Currently being shown in the About section so no longer used
// Surface Reddit content through Bing https://www.bing.com/search?q=Reddit+Ripple
- (IBAction)seeNewsAction:(id)sender {
    
    NSString *moreInfoURL = nil;
    NSString *searchTerm = nil;
    NSURL *targetURL = nil;
    
    // Here is the URL for surfacing Reddit info on Bing https://www.bing.com/search?q=Reddit+Ripple
    moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.bing.com/search?q="];
    searchTerm = [NSString stringWithFormat:@"%@ %@",@"reddit",self.parentCompany];
    
    // Remove any spaces in the URL query string params
    searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
    
    targetURL = [NSURL URLWithString:moreInfoURL];
    
    if (targetURL) {
        
        // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"See External News"
                      parameters:@{ @"News Source" : @"Bing_Reddit",
                                    @"Action Query" : searchTerm,
                                    @"Action URL" : [targetURL absoluteString]} ];
        
        SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
        externalInfoVC.delegate = self;
        // Just use whatever is the default color for the Safari View Controller
        //externalInfoVC.preferredControlTintColor = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        [self presentViewController:externalInfoVC animated:YES completion:nil];
    } 
}

// Send the user to the appropriate news site when they click the news button 3. Currently cointelegraph.
- (IBAction)seeNewsAction3:(id)sender {
    
    [self.navigationController popViewControllerAnimated:YES];
    
   /* NSString *moreInfoURL = nil;
    NSURL *targetURL = nil;
    NSString *searchTerm = nil;
    
    // For price events this take them to CoinTelegraph
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
        moreInfoURL = [NSString stringWithFormat:@"%@",@"https://cointelegraph.com"];
        targetURL = [NSURL URLWithString:moreInfoURL];
    }
    // Else do a google news with the correct search term
    else {
        moreInfoURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = [NSString stringWithFormat:@"%@",@"cryptocurrency news"];
        
        // For News events, search query term is the product name i.e. iPhone 7 or WWWDC 2016
        if ([self.eventType containsString:@"Launch"]) {
            searchTerm = [NSString stringWithFormat:@"%@ %@",self.parentCompany,[self.eventType stringByReplacingOccurrencesOfString:@" Launch" withString:@""]];
        }
        // E.g. Naples Epyc Sales Launch becomes Naples Epyc
        if ([self.eventType containsString:@"Sales Launch"]) {
            searchTerm = [NSString stringWithFormat:@"%@ %@",self.parentCompany,[self.eventType stringByReplacingOccurrencesOfString:@" Sales Launch" withString:@""]];
        }
        if ([self.eventType containsString:@"Conference"]) {
            searchTerm = [NSString stringWithFormat:@"%@ %@",self.parentCompany,[self.eventType stringByReplacingOccurrencesOfString:@" Conference" withString:@""]];
        }
        
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        moreInfoURL = [moreInfoURL stringByAppendingString:searchTerm];
        
        targetURL = [NSURL URLWithString:moreInfoURL];
    }
    
    if (targetURL) {
        
        // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
        // TO DO: Disabling to not track development events. Enable before shipping.
        [FBSDKAppEvents logEvent:@"See External News"
                      parameters:@{ @"News Source" : @"Cointelegraph",
                                    @"Action Query" : @" ",
                                    @"Action URL" : [targetURL absoluteString]} ];
        
        SFSafariViewController *externalInfoVC = [[SFSafariViewController alloc] initWithURL:targetURL];
        externalInfoVC.delegate = self;
        // Just use whatever is the default color for the Safari View Controller
        //externalInfoVC.preferredControlTintColor = [UIColor colorWithRed:240.0f/255.0f green:142.0f/255.0f blue:51.0f/255.0f alpha:1.0f];
        [self presentViewController:externalInfoVC animated:YES completion:nil];
    } */
}


// Delegate mthod to dismiss the Safari View Controller when a user is done with it.
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    
    // Refresh details table when user clicks Done in Safari view to prevent crashes if same cell is clicked again
    [self.eventDetailsTable reloadData];
}

// Get the Best Info url that's stored on the event history for a news event
- (NSString *)getBestInfoUrlWithEventType:(NSString *)eventType eventParentTicker:(NSString *)parentTicker
{
    NSString *moreInfoURL = @"NA";
    EventHistory *eventHistoryData = nil;
    NSArray *infoComponents = nil;
    
    if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
        // Get event history that stores the following string for product events in it's previous1Status field: Impact_Impact Description_MoreInfoTitle_MoreInfoUrl
        eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:parentTicker parentEventType:eventType];
        
        // Parse out the MoreInfoUrl
        infoComponents = [eventHistoryData.previous1Status componentsSeparatedByString:@"_"];
        moreInfoURL = infoComponents[3];
    }
    
    return moreInfoURL;
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
    
    // Set navigation bar header to an attention orange color
    NSDictionary *attentionHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                               [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                               [UIColor colorWithRed:205.0f/255.0f green:151.0f/255.0f blue:61.0f/255.0f alpha:1.0f], NSForegroundColorAttributeName,
                                               nil];
    [self.navigationController.navigationBar setTitleTextAttributes:attentionHeaderAttributes];
    [self.navigationController.navigationBar.topItem setTitle:[notification object]];
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

- (NSInteger)getNoOfInfoPiecesForEventTypeForSection:(NSInteger)sectionNo
{
    NSInteger numberOfPieces = 0;
    
    if ([self.eventType isEqualToString:@"Quarterly Earnings"]) {
        if(sectionNo == 0) {
            numberOfPieces = 4;
        }
        if(sectionNo == 1) {
            numberOfPieces = 5;
        }
    }
    
    // For econ events: Description(getShortDescriptionForEventType:), Impact Level: getImpactDescriptionForEventType: + Impact(getEpsOrImpactTextForEventType:), Sectors Affected(getEpsOrSectorsTextForEventType:), Tip(getPriceSinceOrTipTextForEventType:),
    if ([self.eventType containsString:@"Fed Meeting"]) {
        if(sectionNo == 0) {
            numberOfPieces = 6;
        }
        if(sectionNo == 1) {
            numberOfPieces = 2;
        }
    }
    
    if ([self.eventType containsString:@"Jobs Report"]) {
        if(sectionNo == 0) {
            numberOfPieces = 6;
        }
        if(sectionNo == 1) {
            numberOfPieces = 2;
        }
    }
    
    if ([self.eventType containsString:@"Consumer Confidence"]) {
        if(sectionNo == 0) {
            numberOfPieces = 6;
        }
        if(sectionNo == 1) {
            numberOfPieces = 2;
        }
    }
    
    if ([self.eventType containsString:@"GDP Release"]) {
        if(sectionNo == 0) {
            numberOfPieces = 6;
        }
        if(sectionNo == 1) {
            numberOfPieces = 2;
        }
    }
    
    // New econ events types
    if ([self.eventType containsString:@"US Retail Sales"]) {
        if(sectionNo == 0) {
            numberOfPieces = 6;
        }
        if(sectionNo == 1) {
            numberOfPieces = 2;
        }
    }
    if ([self.eventType containsString:@"US Housing Starts"]) {
        if(sectionNo == 0) {
            numberOfPieces = 6;
        }
        if(sectionNo == 1) {
            numberOfPieces = 2;
        }
    }
    if ([self.eventType containsString:@"US New Homes Sales"]) {
        if(sectionNo == 0) {
            numberOfPieces = 6;
        }
        if(sectionNo == 1) {
            numberOfPieces = 2;
        }
    }
    // End new econ events types
    
    if ([self.eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
        if(sectionNo == 0) {
            numberOfPieces = 6;
        }
        if(sectionNo == 1) {
            numberOfPieces = 2;
        }
    }
    
    // Old way
    /*FADataController *piecesDC = [[FADataController alloc] init];
    
    // If it's a currency price event
    if ([self.eventType containsString:@"% up"]||[self.eventType containsString:@"% down"]) {
        
        if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
            if(sectionNo == 0) {
                numberOfPieces = 5;
            }
            if(sectionNo == 1) {
                numberOfPieces = 9;
            }
        } else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
            if(sectionNo == 0) {
               // id newsSection = [[[piecesDC getLatestCryptoEvents] sections] objectAtIndex:0];
          //      numberOfPieces = [newsSection numberOfObjects];
            }
        }
    }
    // Else
    else {
        if(sectionNo == 0) {
            numberOfPieces = 1;
        }
        if(sectionNo == 1) {
            numberOfPieces = 5;
        }
        if(sectionNo == 2) {
            numberOfPieces = 9;
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
        // Old text
        // description = @"Represents the total value of all goods & services produced over a period.";
        description = @"Total value of goods & services produced over a period, compared to the prior period.";
    }
    
    // New econ events types
    if ([self.eventType containsString:@"US Retail Sales"]) {
        description = @"Measure of retail sales to consumers, compared to prior month.";
    }
    if ([self.eventType containsString:@"US Housing Starts"]) {
        description = @"No. of new residential construction projects that began in a given month.";
    }
    if ([self.eventType containsString:@"US New Homes Sales"]) {
        description = @"Sales (deposit or contract signing) of newly built homes in a given month.";
    }
    // End new econ events types
    
    if ([eventType containsString:@"Launch"]||[self.eventType containsString:@"Conference"]) {
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
    
    // New econ events types
    if ([eventType containsString:@"US Retail Sales"]) {
        description = @"Retail stocks are impacted most by this.";
    }
    if ([eventType containsString:@"US Housing Starts"]) {
        description = @"Housing stocks are impacted most by this.";
    }
    if ([eventType containsString:@"US New Homes Sales"]) {
        description = @"Housing stocks are impacted most by this.";
    }
    // End new econ events types
    
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
    
    // New econ events types
    if ([eventType containsString:@"US Retail Sales"]) {
        description = @"Component in the calculation of GDP.";
    }
    if ([eventType containsString:@"US Housing Starts"]) {
        description = @"Leading (~ 1 yr) indicator of housing demand & prices.";
    }
    if ([eventType containsString:@"US New Homes Sales"]) {
        description = @"Indicator of housing demand & prices.";
    }
    // End new econ events types
    
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
        description = @"High Impact";
    }
    
    // New econ events types
    if ([eventType containsString:@"US Retail Sales"]) {
        description = @"Medium";
    }
    if ([eventType containsString:@"US Housing Starts"]) {
        description = @"High";
    }
    if ([eventType containsString:@"US New Homes Sales"]) {
        description = @"Medium";
    }
    // End new econ events types
    
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
    
    // New econ events types
    if ([eventType containsString:@"US Retail Sales"]) {
        description = @"Component in the calculation of GDP.";
    }
    if ([eventType containsString:@"US Housing Starts"]) {
        description = @"Leading (~ 1 yr) indicator of housing demand & prices.";
    }
    if ([eventType containsString:@"US New Homes Sales"]) {
        description = @"Indicator of housing demand & prices.";
    }
    // End new econ events types
    
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
    
    // New econ events types
    if ([eventType containsString:@"US Retail Sales"]) {
        description = @"Pro Tip! As consumer spending increases, the economy grows.";
    }
    if ([eventType containsString:@"US Housing Starts"]) {
        description = @"Pro Tip! When starts are rising, house prices should appreciate as well & vice versa.";
    }
    if ([eventType containsString:@"US New Homes Sales"]) {
        description = @"Pro Tip! Along with housing starts, is a leading indicator (~ 1 yr) of home prices.";
    }
    // End new econ events types
    
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
    
    // New econ events types
    if ([eventType containsString:@"US Retail Sales"]) {
        colorToReturn = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
    }
    if ([eventType containsString:@"US Housing Starts"]) {
        colorToReturn = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
    }
    if ([eventType containsString:@"US New Homes Sales"]) {
        colorToReturn = [UIColor colorWithRed:123.0f/255.0f green:79.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
    }
    // End new econ events types
    
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
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        eventTimeString = @"8:30 a.m. ET";
        eventDateString = [NSString stringWithFormat:@"%@ %@",eventDateString,eventTimeString];
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        eventTimeString = @"8:30 a.m. ET";
        eventDateString = [NSString stringWithFormat:@"%@ %@",eventDateString,eventTimeString];
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        eventTimeString = @"10:00 a.m. ET";
        eventDateString = [NSString stringWithFormat:@"%@ %@",eventDateString,eventTimeString];
    }
    // End new econ events types
    
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

// Format the event type for appropriate display. Currently the formatting looks like the following: Quarterly Earnings -> Earnings. Jan Fed Meeting -> Fed Meeting. Jan Jobs Report -> Jobs Report and so on. For product events strip out conference keyword WWDC 2016 Conference -> WWDC 2016
- (NSString *)formatEventType:(Event *)rawEvent
{
    NSString *rawEventType = rawEvent.type;
    NSString *formattedEventType = rawEventType;
    //NSMutableString *tempString = [NSMutableString stringWithFormat:@"%@",formattedEventType];
    NSArray *typeComponents = nil;
    
    // For price events strip out the up and down
    if ([rawEventType containsString:@"% up"])
    {
        
    }
    else if ([rawEventType containsString:@"% down"])
    {
        
    }
    // For news event, strip out the cryptofinews:: from the beginning
    else if ([rawEventType containsString:@"cryptofinews::"]) {
        typeComponents = [rawEventType componentsSeparatedByString:@"::"];
        formattedEventType = [typeComponents objectAtIndex:1];
    }
    else if ([rawEventType containsString:@"Conference"]) {
        formattedEventType = [rawEventType stringByReplacingOccurrencesOfString:@" Conference" withString:@""];
    }
    
    return formattedEventType;
}

// Calculate how far the event is from today. Typical values are Past,Today, Tomorrow, 2d, 3d and so on.
- (NSString *)calculateDistanceFromEventDate:(NSDate *)eventDate withEventType:(NSString *)rawEventType
{
    NSString *formattedDistance = @" ";
    
    // Calculate the number of days between event date and today's date
    NSCalendar *aGregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSUInteger unitFlags =  NSCalendarUnitDay;
    NSDateComponents *diffDateComponents = [aGregorianCalendar components:unitFlags fromDate:[self setTimeToMidnightLastNightOnDate:[NSDate date]] toDate:[self setTimeToMidnightLastNightOnDate:eventDate] options:0];
    NSInteger difference = [diffDateComponents day];
    
    if ((difference < 0)&&(difference > -2)) {
        formattedDistance = @"Yesterday";
    } else if ((difference <= -2)&&(difference > -4)) {
        formattedDistance = @"Day Before";
    } else if ((difference <= -4)&&(difference > -31)) {
        formattedDistance = [NSString stringWithFormat:@"%@ days ago",[@(ABS(difference)) stringValue]];
    } else if ((difference <= -31)&&(difference > -366)) {
        formattedDistance = [NSString stringWithFormat:@"%@ mos ago",[@(ABS(difference/30)) stringValue]];
    } else if (difference <= -366) {
        formattedDistance = @"Over 1 yr ago";
    } else if (difference == 0) {
        formattedDistance = @"Today";
    } else if (difference == 1) {
        formattedDistance = @"Tomorrow";
    } else if ((difference > 1)&&(difference < 31)) {
        formattedDistance = [NSString stringWithFormat:@"In %@ days",[@(difference) stringValue]];
    } else if ((difference >= 31)&&(difference < 366)) {
        formattedDistance = [NSString stringWithFormat:@"In %@ mos",[@(difference/30) stringValue]];
    } else if (difference >= 366) {
        formattedDistance = @"Beyond 1 yr";
    } else {
        formattedDistance = [NSString stringWithFormat:@"%@ days",[@(difference) stringValue]];
    }
    
    return formattedDistance;
}

// Get the first action type: Preview Earnings or See Earnings Release
- (NSString *)getActionType1ForEvent:(NSString *)rawEventType withEventDistance:(NSString *)distanceTxt
{
    NSString *actionType = @"Not Available";
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        // If event happened in the past, type is "Replay"
        if ([distanceTxt containsString:@"Yesterday"]||[distanceTxt containsString:@"Day Before"]||[distanceTxt containsString:@"ago"]) {
            actionType = @"Preview Earnings";
        }
        // If event is today, type is "Listen"
        else if ([distanceTxt containsString:@"Today"]) {
            actionType = @"Preview Earnings";
        }
        // If the event is happening in the future, the type is "Preview"
        else {
            actionType = @"Preview Earnings";
        }
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        actionType = @"See FOMC site";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        actionType = @"See BLS site";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        actionType = @"See TCB site";
    }
    
   /* if ([rawEventType containsString:@"GDP Release"]) {
        
        
        actionType = @"SEE BEA SITE";
    }*/
    
    if ([rawEventType containsString:@"US GDP Release"]) {
        actionType = @"See BEA site";
    }
    if ([rawEventType containsString:@"India GDP Release"]) {
            actionType = @"See MOS site";
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        actionType = @"See UCB site";
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        actionType = @"See UCB site";
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        actionType = @"See UCB site";
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionType = @"Not Available";
    }
    
    return actionType;
}

// Get the first action type location: Preview Earnings
- (NSString *)getActionLocation1ForEvent:(NSString *)rawEventType withTicker:(NSString *)eventTicker
{
    NSString *actionLocation = @"https://seekingalpha.com";
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
            actionLocation = [NSString stringWithFormat:@"https://seekingalpha.com/symbol/%@",eventTicker];
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        actionLocation = @"https://www.federalreserve.gov/monetarypolicy.htm";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        actionLocation = @"https://www.bls.gov/mobile/mobile_releases.htm";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        actionLocation = @"https://www.conference-board.org/data/consumerconfidence.cfm";
    }
    
    if ([rawEventType containsString:@"US GDP Release"]) {
        actionLocation = @"https://www.bea.gov/data/gdp/gross-domestic-product";
    }
    if ([rawEventType containsString:@"India GDP Release"]) {
        actionLocation = @"http://mospi.nic.in";
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        actionLocation = @"https://www.census.gov/retail/index.html";
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        actionLocation = @"https://www.census.gov/construction/nrc/index.html";
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        actionLocation = @"https://www.census.gov/construction/nrs/index.html";
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionLocation = @"Not Available";
    }
    
    return actionLocation;
}

// Get the second action type: Play Earnings Call or Replay Earnings Call
- (NSString *)getActionType2ForEvent:(NSString *)rawEventType withEventDistance:(NSString *)distanceTxt
{
    NSString *actionType = @"Not Available";
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        // If event happened in the past, type is "Replay"
        if ([distanceTxt containsString:@"Yesterday"]||[distanceTxt containsString:@"Day Before"]||[distanceTxt containsString:@"ago"]) {
            actionType = @"Replay Earnings Call";
        }
        // If event is today, type is "Listen"
        else if ([distanceTxt containsString:@"Today"]) {
            actionType = @"Play Earnings Call";
        }
        // If the event is happening in the future, the type is "Preview"
        else {
            actionType = @"Play last Earnings Call";
        }
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        actionType = @"Not Available";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        actionType = @"Not Available";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        actionType = @"Not Available";
    }
    
    if ([rawEventType containsString:@"GDP Release"]) {
        actionType = @"Not Available";
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        actionType = @"Not Available";
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        actionType = @"Not Available";
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        actionType = @"Not Available";
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionType = @"Not Available";
    }
    
    return actionType;
}

// Get the second action type location: Play Earnings Call or Replay Earnings Call
- (NSString *)getActionLocation2ForEvent:(NSString *)rawEventType
{
    NSString *actionLocation = @"Not Available";
    NSString *externalURL = nil;
    NSString *searchTerm = nil;
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        actionLocation = [NSString stringWithFormat:@"%@",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:1]];
        
        if ([actionLocation caseInsensitiveCompare:@"Not Available"] == NSOrderedSame)
        {
            externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?q="];
            searchTerm = [NSString stringWithFormat:@"%@ %@ listen to earnings call",self.parentCompany,self.parentTicker];
            // Remove any spaces in the URL query string params
            searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
            actionLocation = [externalURL stringByAppendingString:searchTerm];
        }
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = @"fomc meeting";
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = @"jobs report us";
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = @"us consumer confidence";
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }
    
    if ([rawEventType containsString:@"US GDP Release"]) {
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = @"us gdp release";
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }
    if ([rawEventType containsString:@"India GDP Release"]) {
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = @"india gdp release";
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = @"us retail sales";
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = @"us housing starts";
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = @"us new homes sales";
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionLocation = @"Not Available";
    }
    
    return actionLocation;
}

// Get the third action type: View Transcript or View last Transcript
- (NSString *)getActionType3ForEvent:(NSString *)rawEventType withEventDistance:(NSString *)distanceTxt
{
    NSString *actionType = @"Not Available";
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        // If event happened in the past, type is "Replay"
        if ([distanceTxt containsString:@"Yesterday"]||[distanceTxt containsString:@"Day Before"]||[distanceTxt containsString:@"ago"]) {
            actionType = @"View Transcript";
        }
        // If event is today, type is "Listen"
        else if ([distanceTxt containsString:@"Today"]) {
            actionType = @"View Transcript";
        }
        // If the event is happening in the future, the type is "Preview"
        else {
            actionType = @"View last Transcript";
        }
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        actionType = @"Not Available";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        actionType = @"Not Available";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        actionType = @"Not Available";
    }
    
    if ([rawEventType containsString:@"GDP Release"]) {
        actionType = @"Not Available";
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        actionType = @"Not Available";
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        actionType = @"Not Available";
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        actionType = @"Not Available";
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionType = @"Not Available";
    }
    
    return actionType;
}

// Get the third action type location: View Transcript or View last Transcript
- (NSString *)getActionLocation3ForEvent:(NSString *)rawEventType
{
    NSString *actionLocation = @"Not Available";
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        // Replacing GOOGL with GOOG as the former doesn't work for SA.
        if ([[self.parentTicker uppercaseString] isEqualToString:@"GOOGL"]) {
            actionLocation = [NSString stringWithFormat:@"https://seekingalpha.com/symbol/GOOG/earnings/transcripts"];
        }
        else {
            actionLocation = [NSString stringWithFormat:@"https://seekingalpha.com/symbol/%@/earnings/transcripts",[self.parentTicker uppercaseString]];
        }
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        actionLocation = @"Not Available";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        actionLocation = @"Not Available";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        actionLocation = @"Not Available";
    }
    
    if ([rawEventType containsString:@"GDP Release"]) {
        actionLocation = @"Not Available";
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        actionLocation = @"Not Available";
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        actionLocation = @"Not Available";
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        actionLocation = @"Not Available";
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionLocation = @"Not Available";
    }
    
    return actionLocation;
}

// Get the fourth action type: See News
- (NSString *)getActionType4ForEvent:(NSString *)rawEventType withEventDistance:(NSString *)distanceTxt
{
    NSString *actionType = @"Not Available";
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        // If event happened in the past, type is "Replay"
        if ([distanceTxt containsString:@"Yesterday"]||[distanceTxt containsString:@"Day Before"]||[distanceTxt containsString:@"ago"]) {
            actionType = @"Scan News";
        }
        // If event is today, type is "Listen"
        else if ([distanceTxt containsString:@"Today"]) {
            actionType = @"Scan News";
        }
        // If the event is happening in the future, the type is "Preview"
        else {
            actionType = @"Scan News";
        }
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        actionType = @"Scan News";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        actionType = @"Scan News";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        actionType = @"Scan News";
    }
    
    if ([rawEventType containsString:@"GDP Release"]) {
        actionType = @"Scan News";
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        actionType = @"Scan News";
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        actionType = @"Scan News";
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        actionType = @"Scan News";
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionType = @"Scan News";
    }
    
    return actionType;
}

// Get the 4th action type location: See News for earnings
- (NSString *)getActionLocation4ForEvent:(NSString *)rawEventType
{
    NSString *actionLocation = @"Not Available";
    NSString *externalURL = nil;
    NSString *searchTerm = nil;
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?tbm=nws&q="];
        searchTerm = [NSString stringWithFormat:@"%@ %@ stock news",self.parentCompany,self.parentTicker];
        // Remove any spaces in the URL query string params
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        actionLocation = [externalURL stringByAppendingString:searchTerm];
    }

    return actionLocation;
}

// Get the fifth action type: Go to Investor Site
- (NSString *)getActionType5ForEvent:(NSString *)rawEventType withEventDistance:(NSString *)distanceTxt
{
    NSString *actionType = @"Not Available";
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        // If event happened in the past, type is "Replay"
        if ([distanceTxt containsString:@"Yesterday"]||[distanceTxt containsString:@"Day Before"]||[distanceTxt containsString:@"ago"]) {
            actionType = @"Go to Investor Site";
        }
        // If event is today, type is "Listen"
        else if ([distanceTxt containsString:@"Today"]) {
            actionType = @"Go to Investor Site";
        }
        // If the event is happening in the future, the type is "Preview"
        else {
            actionType = @"Go to Investor Site";
        }
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        actionType = @"Go to Site";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        actionType = @"Go to Site";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        actionType = @"Go to Site";
    }
    
    if ([rawEventType containsString:@"GDP Release"]) {
        actionType = @"Go to Site";
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        actionType = @"Go to Site";
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        actionType = @"Go to Site";
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        actionType = @"Go to Site";
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionType = @"Go to Site";
    }
    
    return actionType;
}

// Get the 5th action type location: Go to Investor Site
- (NSString *)getActionLocation5ForEvent:(NSString *)rawEventType
{
    NSString *actionLocation = @"Not Available";
    NSString *externalURL = nil;
    NSString *searchTerm = nil;
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
        actionLocation = [NSString stringWithFormat:@"%@",[[self.altDataSnapShot getProfileInfoForCoin:self.parentTicker] objectAtIndex:0]];
        
        if ([actionLocation caseInsensitiveCompare:@"Not Available"] == NSOrderedSame)
        {
            externalURL = [NSString stringWithFormat:@"%@",@"https://www.google.com/m/search?q="];
            searchTerm = [NSString stringWithFormat:@"%@ %@ investor site",self.parentCompany,self.parentTicker];
            // Remove any spaces in the URL query string params
            searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
            actionLocation = [externalURL stringByAppendingString:searchTerm];
        }
    }
    
    if ([rawEventType containsString:@"Fed Meeting"]) {
        actionLocation = @"Not Available";
    }
    
    if ([rawEventType containsString:@"Jobs Report"]) {
        actionLocation = @"Not Available";
    }
    
    if ([rawEventType containsString:@"Consumer Confidence"]) {
        actionLocation = @"Not Available";
    }
    
    if ([rawEventType containsString:@"GDP Release"]) {
        actionLocation = @"Not Available";
    }
    
    // New econ events types
    if ([rawEventType containsString:@"US Retail Sales"]) {
        actionLocation = @"Not Available";
    }
    if ([rawEventType containsString:@"US Housing Starts"]) {
        actionLocation = @"Not Available";
    }
    if ([rawEventType containsString:@"US New Homes Sales"]) {
        actionLocation = @"Not Available";
    }
    // End new econ events types
    
    if ([rawEventType containsString:@"Conference"]) {
        actionLocation = @"Not Available";
    }
    
    return actionLocation;
}

// Get the sixth location type: See Price, currently on CNBC
- (NSString *)getLocationType6ForEvent:(NSString *)rawEventType withTicker:(NSString *)eventTicker
{
    NSString *actionLocation = @"https://www.cnbc.com";
    NSString *externalURL = @"NA";
    
    if ([rawEventType isEqualToString:@"Quarterly Earnings"]) {
        
            externalURL = [NSString stringWithFormat:@"%@",@"https://www.cnbc.com/quotes/?symbol="];
            actionLocation = [externalURL stringByAppendingString:eventTicker];
    }
    
    return actionLocation;
}

// Refresh table view per the main nav action selected.
- (void)deetsRefreshTbl:(UIRefreshControl *)refreshTblControl
{
    // Check for connectivity. If yes, sync data from remote data source
    if ([self checkForInternetConnectivity]) {
        
        // If Info is selected, sync the price
        if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"Info"] == NSOrderedSame) {
            
            // Asynchronous refresh
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
                dispatch_async(dispatch_get_main_queue(), ^{
                   // FADataController *priceRefreshDataController = [[FADataController alloc] init];
                   // [priceRefreshDataController getAllCryptoPriceChangeEventsFromApi];
                    [self.eventDetailsTable reloadData];
                    [refreshTblControl endRefreshing];
                    // Reset the navigation bar header text color to black
                    NSDictionary *regularHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                             [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                                             [UIColor blackColor], NSForegroundColorAttributeName,
                                                             nil];
                    [self.navigationController.navigationBar setTitleTextAttributes:regularHeaderAttributes];
                    // Reset the company name in the navigation bar header.
                    self.navigationItem.title = [self.eventTitleStr uppercaseString];
                    // Make sure the price list is refreshed as well.
                    [[NSNotificationCenter defaultCenter]postNotificationName:@"EventStoreUpdated" object:self];
                });
            });
            
            
            // TRACKING EVENT: Event Type Selected: User selected Crypto event type explicitly in the events type selector
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"Pull Down Refresh"
                          parameters:@{ @"Event Type" : @"Price Info in Details" } ];
        }
        // If News is selected, fetch the news and refresh
        else if ([[self.detailsInfoSelector titleForSegmentAtIndex:self.detailsInfoSelector.selectedSegmentIndex] caseInsensitiveCompare:@"News"] == NSOrderedSame) {
            
            // Asynchronous refresh
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
                dispatch_async(dispatch_get_main_queue(), ^{
                   // FADataController *newsRefreshDataController = [[FADataController alloc] init];
                   // [newsRefreshDataController getAllNewsFromApi];
                   // self.infoResultsController = [newsRefreshDataController getLatestCryptoEvents];
                    [self.eventDetailsTable reloadData];
                    [refreshTblControl endRefreshing];
                    // Reset the navigation bar header text color to black
                    NSDictionary *regularHeaderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                             [UIFont boldSystemFontOfSize:14], NSFontAttributeName,
                                                             [UIColor blackColor], NSForegroundColorAttributeName,
                                                             nil];
                    [self.navigationController.navigationBar setTitleTextAttributes:regularHeaderAttributes];
                    // Reset the company name in the navigation bar header.
                    self.navigationItem.title = @"CRYPTO";
                });
            });
            
            // TRACKING EVENT: Event Type Selected: User selected Crypto event type explicitly in the events type selector
            // TO DO: Disabling to not track development events. Enable before shipping.
            [FBSDKAppEvents logEvent:@"Pull Down Refresh"
                          parameters:@{ @"Event Type" : @"Latest News in Details" } ];
        }
    }
    // If not, show error message
    else {
        
        [self sendUserGuidanceCreatedNotificationWithMessage:@"No Connection. Limited functionality."];
        [refreshTblControl endRefreshing];
    }
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
