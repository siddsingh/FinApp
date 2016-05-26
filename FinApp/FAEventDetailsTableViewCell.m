//
//  FAEventDetailsTableViewCell.m
//  FinApp
//
//  Class represents event detail row shown in the event details table.
//
//  Created by Sidd Singh on 10/23/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "FAEventDetailsTableViewCell.h"

@implementation FAEventDetailsTableViewCell

- (void)awakeFromNib {
    // Initialization code
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(textViewTapped:)];
    [self.descriptionArea addGestureRecognizer:gestureRecognizer];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)textViewTapped:(UITapGestureRecognizer *)tapGesture {
    
    NSLog(@"DESCRIPTION TEXT VIEW TAPPED");
    //NSDictionary *attributes = [textView textStylingAtPosition:textPosition inDirection:UITextStorageDirectionForward];
    
    //NSURL *url = attributes[NSLinkAttributeName];
    
    /*if (url) {
        [[UIApplication sharedApplication] openURL:url];
    }*/
    NSAttributedString *descriptionString = [self.descriptionArea attributedText];
    NSRange descriptionRange = NSMakeRange(0,[descriptionString length]);
    NSDictionary *attributes = [descriptionString attributesAtIndex:0 effectiveRange:&descriptionRange];
    NSURL *url = attributes[NSLinkAttributeName];
    
     NSLog(@"DESCRIPTION TEXT VIEW TAPPED WITH URL:%@",url);
    
    if (url) {
     [[UIApplication sharedApplication] openURL:url];
    }
    
}

@end
