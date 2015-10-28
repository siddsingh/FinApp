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
            
            [[cell descriptionPart1] setText:@"Expected Earnings Per Share for"];
            // Get the related date from the event which is the quarter end that is going to be reported
            NSString *relatedDateString = [NSString stringWithFormat:@"Quarter ended %@", [monthDateYearFormatter stringFromDate:eventData.relatedDate]];
            [[cell descriptionPart2] setText:relatedDateString];
            [[cell descriptionAddtlPart] setText:@"Estimated"];
            [[cell associatedValue1] setText:[decimal2Formatter stringFromNumber:eventData.estimatedEps]];
            // Hide other value labels as they are empty
            [[cell associatedValue2] setHidden:YES];
            [[cell additionalValue] setHidden:YES];
            
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
    
    
    
    
    
    
    
    
    
    
    // Get a custom cell to display
    FAEventsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventCell" forIndexPath:indexPath];
    
    indexPath.r
    
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
        
        // TO DO LATER: IMPORTANT: Any change to the formatting here could affect reminder creation (processReminderForEventInCell:,editActionsForRowAtIndexPath) since the reminder values are taken from the cell. Additionally changes here need to be reconciled with changes in the getEvents for ticker's queued reminder creation.
        
        // Show the company ticker associated with the event
        [[cell  companyTicker] setText:eventAtIndex.listedCompany.ticker];
        
        // Show the company name associated with the event
        [[cell  companyName] setText:eventAtIndex.listedCompany.name];
        
        // Set the fetch state of the event cell to false
        // TO DO: Should you really be holding logic state at the cell level or should there
        // be a unique identifier for each event ?
        cell.eventRemoteFetch = NO;
        
        // Show the event type. Format it for display. Currently map "Quarterly Earnings" to Quarterly.
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
        // Set it's color based on certainty. Confirmed is -> Knotifi Purple, Others -> Light Gray
        if ([cell.eventCertainty.text isEqualToString:@"Confirmed"]) {
            
            cell.eventCertainty.textColor = [UIColor colorWithRed:81.0f/255.0f green:54.0f/255.0f blue:127.0f/255.0f alpha:1.0f];
            // TO DO: Delete this bright blue later
            //cell.eventCertainty.textColor = [UIColor colorWithRed:35.0f/255.0f green:127.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
        } else {
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
