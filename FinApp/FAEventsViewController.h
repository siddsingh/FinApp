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
@property (strong, nonatomic) NSFetchedResultsController *filteredEventsController;

// Flag to show if the search filter has been applied
@property BOOL filterSpecified;

// Outlet for the events search bar
@property (weak, nonatomic) IBOutlet UISearchBar *eventsSearchBar;

// Table for list of events
@property (weak, nonatomic) IBOutlet UITableView *eventsListTable;


@end
