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

@interface FAEventDetailsViewController ()

@end

@implementation FAEventDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    // Make the information messages area fully transparent so that it's invisible to the user
    self.messagesArea.alpha = 0.0;
    
    // Ensure that the busy spinner is not animating thus hidden
    [self.busySpinner stopAnimating];
    
    // Get a primary data controller that you will use later
    self.primaryDetailsDataController = [[FADataController alloc] init];
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

    // Get Row no
    int rowNo = (int)indexPath.row;
    
    // Get a custom cell to display details
    FAEventDetailsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventDetailsCell" forIndexPath:indexPath];
    
    // Get the event details parts of which will be displayed in the details table
    Event *eventData = [self.primaryDetailsDataController getEventForParentEventTicker:self.parentTicker andEventType:self.eventType];
    
    // Get the event history to be displayed as the details based on parent company ticker and event type. Assumption is that ticker and event type uniquely identify an event.
    EventHistory *eventHistoryData = [self.primaryDetailsDataController getEventHistoryForParentEventTicker:self.parentTicker parentEventType:self.eventType];
    
    // Display the appropriate details based on the row no
    switch (rowNo) {
            
        case expectedEpsRow:
        {
            [[cell descriptionPart1] setText:@"Expected Earnings Per Share for"];
            // Get the related date from the event which is the quarter end that is going to be reported
            NSString *relatedDateString = [NSString stringWithFormat:@"Quarter ended %@", [monthDateYearFormatter stringFromDate:eventData.relatedDate]];
            [[cell descriptionPart2] setText:relatedDateString];
            [[cell descriptionAddtlPart] setText:@"Estimated"];
            [[cell associatedValue1] setText:[decimal2Formatter stringFromNumber:eventData.estimatedEps]];
            // Hide other value labels as they are empty
            [[cell associatedValue2] setHidden:YES];
            [[cell additionalValue] setHidden:YES];
        }
        break;
            
        case priorEpsRow:
            //
            break;
            
        case changeSincePrevQuarter:
            //
            break;
            
        default:
            
            break;
    }
    
    return cell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
