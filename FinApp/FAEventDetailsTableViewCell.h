//
//  FAEventDetailsTableViewCell.h
//  FinApp
//
//  Class represents event detail row shown in the event details table.
//
//  Created by Sidd Singh on 10/23/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FAEventDetailsTableViewCell : UITableViewCell

// First part of the description of the data being displayed
@property (weak, nonatomic) IBOutlet UILabel *descriptionPart1;

// Second part of the description of the data being displayed
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *descriptionPart2;

// Additional part of the description of the data being displayed
@property (weak, nonatomic) IBOutlet UILabel *descriptionAddtlPart;

// First value representing the data
@property (weak, nonatomic) IBOutlet UILabel *associatedValue1;

// Second value representing the data
@property (weak, nonatomic) IBOutlet UILabel *associatedValue2;

// Additional value/s representing the data
@property (weak, nonatomic) IBOutlet UILabel *additionalValue;

@end

