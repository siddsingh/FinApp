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

// Data Controller to add/access events data in the data store
@property (strong, nonatomic) FADataController *eventDataController;

// Controller containing results of event queries to Core Data store
@property (strong, nonatomic) NSFetchedResultsController *eventResultsController;

// Table for list of events
@property (weak, nonatomic) IBOutlet UITableView *eventsListTable;


@end
