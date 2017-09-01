//
//  FAEventsTableViewCell.h
//  FinApp
//
//  Class that manages the custom events table view cell
//
//  Created by Sidd Singh on 12/23/14.
//  Copyright (c) 2014 Sidd Singh. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FAEventsTableViewCell : UITableViewCell

// Label that represents the company ticker whose event we are showing.
@property (weak, nonatomic) IBOutlet UILabel *companyTicker;

// Label that represents the company name whose event we are showing.
@property (weak, nonatomic) IBOutlet UILabel *companyName;

// Button to show news
@property (weak, nonatomic) IBOutlet UIButton *newsButon;

// Label that represents the event description
@property (weak, nonatomic) IBOutlet UILabel *eventDescription;

// Label that represents the date of the event
@property (weak, nonatomic) IBOutlet UILabel *eventDate;

// Label that represents how near or far in the future the event is
@property (weak, nonatomic) IBOutlet UILabel *eventDistance;

// Label that represents the certainty of this event
@property (weak, nonatomic) IBOutlet UILabel *eventCertainty;

// Flag to show if the event needs to be fetched from the remote data source
@property BOOL eventRemoteFetch;

// Label representing the event impact.
@property (weak, nonatomic) IBOutlet UILabel *eventImpact;

// Timeline Label
@property (weak, nonatomic) IBOutlet UILabel *timelineLbl;

@end
