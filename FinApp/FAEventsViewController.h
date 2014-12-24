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

@interface FAEventsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>


// Table for list of events
@property (weak, nonatomic) IBOutlet UITableView *eventsListTable;


@end
