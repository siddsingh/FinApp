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

// The title for the table row.
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

// The description text box area for the table row.
@property (weak, nonatomic) IBOutlet UITextView *descriptionArea;

@end

