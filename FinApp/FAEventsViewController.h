//
//  FAEventsViewController.h
//  FinApp
//
//  Class that manages the view showing upcoming events.
//
//  Created by Sidd Singh on 12/18/14.
//  Copyright (c) 2014 Sidd Singh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
@class FADataController;

@interface FAEventsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

// Primary Data Controller to add/access data in the data store
@property (strong, nonatomic) FADataController *primaryDataController;

// Controller containing results of event queries to Core Data store
@property (strong, nonatomic) NSFetchedResultsController *eventResultsController;

// Controller containing results of search queries to Data store
@property (strong, nonatomic) NSFetchedResultsController *filteredResultsController;

// Flag to show if the search filter has been applied
@property BOOL filterSpecified;

// Specify which type of search filter has been applied. Currently
// Match_Companies_Events: filters matching companies with existing events.
// Match_Companies_NoEvents: filters for matching companies with no events.
// None_Specified: no filter is specified.
@property (strong,nonatomic) NSString *filterType;

// Current Stock Price & Change String to store this value for the event that the user selects. "NA" is the default value.
@property (strong,nonatomic) NSString *currPriceAndChange;

// Outlet for the events search bar
@property (weak, nonatomic) IBOutlet UISearchBar *eventsSearchBar;

// Table for list of events
@property (weak, nonatomic) IBOutlet UITableView *eventsListTable;

// Spinner to indicate a remote fetch is in progress
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *remoteFetchSpinner;

// Label to show error and informational messages
@property (weak, nonatomic) IBOutlet UILabel *messageBar;

// Segmented control for selecting event type
@property (weak, nonatomic) IBOutlet UISegmentedControl *eventTypeSelector;

// Event type selection action
- (IBAction)eventTypeSelectAction:(id)sender;

// Underline bar to draw focus to a certain area
@property (weak, nonatomic) IBOutlet UILabel *focusBar;

@end
