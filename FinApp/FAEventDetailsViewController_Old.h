//
//  FAEventDetailsViewController.h
//  FinApp
//
//  Class that manages the view showing details of the selected event.
//
//  Created by Sidd Singh on 10/21/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import <UIKit/UIKit.h>
@class FADataController;
@class FASnapShot;

@interface FAEventDetailsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

// Title indicating the kind of event
@property (weak, nonatomic) IBOutlet UILabel *eventTitle;

// Schedule information for the event
@property (weak, nonatomic) IBOutlet UILabel *eventSchedule;

// Event Related Details Table
@property (weak, nonatomic) IBOutlet UITableView *eventDetailsTable;

// Spinner to show activity related to this view
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *busySpinner;

// Area to show user information messages.
@property (weak, nonatomic) IBOutlet UILabel *messagesArea;

// Store the text for the eventTitle label
@property (strong,nonatomic) NSString *eventTitleStr;

// Store the text for the eventSchedule label
@property (strong,nonatomic) NSString *eventScheduleStr;

// Store the curr price and change string.
@property (strong,nonatomic) NSString *currentPriceAndChange;

// Assumption is that ticker and event type uniquely identify an event
// Ticker of the parent company for this event
@property (strong,nonatomic) NSString *parentTicker;
// Type of event. Currently support "Quarterly Earnings", "Jan Fed Meeting" and so on
@property (strong,nonatomic) NSString *eventType;
// This event's scheduled date as text
@property (strong,nonatomic) NSString *eventDateText;
// This event's certainty status. Currently "Confirmed" or "Estimated"
@property (strong,nonatomic) NSString *eventCertainty;
// The company name to which this event belongs
@property (strong,nonatomic) NSString *parentCompany;

// Primary Data Controller to add/access data in the data store
@property (strong, nonatomic) FADataController *primaryDetailsDataController;

// Access to the one data snapshot.
@property (strong,nonatomic) FASnapShot *dataSnapShot2;

// Button for setting the Reminder
@property (weak, nonatomic) IBOutlet UIButton *reminderButton;

// Action to take when Reminder button is pressed
- (IBAction)reminderAction:(id)sender;

// Button to see the news (Google for now)
@property (weak, nonatomic) IBOutlet UIButton *newsButton;

// Action to take when the news button is clicked
- (IBAction)seeNewsAction:(id)sender;

// Button to see the second news source (Seeking Alpha for now)
@property (weak, nonatomic) IBOutlet UIButton *newsButton2;

// Corresponding Action
- (IBAction)seeNewsAction2:(id)sender;

// Button to see the third news source (Yahoo Finance for now)
@property (weak, nonatomic) IBOutlet UIButton *newsButton3;

// Corresponding Action
- (IBAction)seeNewsAction3:(id)sender;

@end
