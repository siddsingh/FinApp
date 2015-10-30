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
    
    // Set the labels to the strings that hold their text. These strings will be set in the prepare for segue method when called. This is necessary since the label outlets are still nil when prepare for segue is called, so can't be set directly.
    [self.eventTitle setText:self.eventTitleStr];
    [self.eventSchedule setText:self.eventScheduleStr];
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
    [[cell associatedValue2] setHidden:NO];
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
            [[cell descriptionPart1] setText:@"Expected Earnings Per Share for"];
            // Get the related date from the event which is the quarter end that is going to be reported
            NSString *relatedDateString = [NSString stringWithFormat:@"Quarter ended %@", [monthDateYearFormatter stringFromDate:eventData.relatedDate]];
            [[cell descriptionPart2] setText:relatedDateString];
            [[cell descriptionAddtlPart] setText:@"Estimated"];
            // Set color to the bright blue
            cell.associatedValue1.textColor = [UIColor colorWithRed:35.0f/255.0f green:127.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            [[cell associatedValue1] setText:[decimal2Formatter stringFromNumber:eventData.estimatedEps]];
            // Hide other value labels as they are empty
            [[cell associatedValue2] setHidden:YES];
            [[cell additionalValue] setHidden:YES];
        }
        break;
            
        case priorEpsRow:
        {
            [[cell descriptionPart1] setText:@"Earnings Per Share for Prior"];
            // Get the prior end date from the event which is the end date of previously reported quarter
            NSString *priorEndDateString = [NSString stringWithFormat:@"Quarter ended %@", [monthDateYearFormatter stringFromDate:eventData.priorEndDate]];
            [[cell descriptionPart2] setText:priorEndDateString];
            [[cell descriptionAddtlPart] setText:@"Reported"];
            // Set color to the bright blue
            cell.associatedValue1.textColor = [UIColor colorWithRed:35.0f/255.0f green:127.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
            [[cell associatedValue1] setText:[decimal2Formatter stringFromNumber:eventData.actualEpsPrior]];
            // Hide other value labels as they are empty
            [[cell associatedValue2] setHidden:YES];
            [[cell additionalValue] setHidden:YES];
        }
        break;
            
        case changeSincePrevQuarter:
        {
            [[cell descriptionPart1] setText:@"Change in stock price since"];
            [[cell descriptionPart2] setText:@"end of Prior Reported Quarter"];
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
                    cell.associatedValue1.textColor = [UIColor colorWithRed:121.0f/255.0f green:182.0f/255.0f blue:57.0f/255.0f alpha:1.0f];
                    cell.associatedValue2.textColor = [UIColor colorWithRed:121.0f/255.0f green:182.0f/255.0f blue:57.0f/255.0f alpha:1.0f];
                    [[cell associatedValue1] setText:priceDiffString];
                    [[cell associatedValue2] setText:percentageDiffString];
                }
                pricesString = [NSString stringWithFormat:@"%.2f - %.2f", prev1RelatedPriceDbl, currentPriceDbl];
                [[cell additionalValue] setText:pricesString];
            }
            // If not available, display an appropriately formatted NA
            else
            {
                [[cell associatedValue1] setText:@"NA"];
                // Hide other value labels as they are empty
                [[cell associatedValue2] setHidden:YES];
                [[cell additionalValue] setHidden:YES];
                // Hide the additional description as that is not valid as well
                [[cell descriptionAddtlPart] setHidden:YES];
            }
        }
        break;
            
        case changeSincePrevEarnings:
        {
            [[cell descriptionPart1] setText:@"Change in stock price since"];
            [[cell descriptionPart2] setText:@"estimated Prior Earnings Day"];
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
                    cell.associatedValue1.textColor = [UIColor colorWithRed:121.0f/255.0f green:182.0f/255.0f blue:57.0f/255.0f alpha:1.0f];
                    cell.associatedValue2.textColor = [UIColor colorWithRed:121.0f/255.0f green:182.0f/255.0f blue:57.0f/255.0f alpha:1.0f];
                    [[cell associatedValue1] setText:priceDiffString];
                    [[cell associatedValue2] setText:percentageDiffString];
                }
                pricesString = [NSString stringWithFormat:@"%.2f - %.2f", prev1PriceDbl, currentPriceDbl];
                [[cell additionalValue] setText:pricesString];
            }
            // If not available, display an appropriately formatted NA
            else
            {
                [[cell associatedValue1] setText:@"NA"];
                // Hide other value labels as they are empty
                [[cell associatedValue2] setHidden:YES];
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
