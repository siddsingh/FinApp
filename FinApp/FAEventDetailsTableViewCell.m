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
#import <FBSDKCoreKit/FBSDKCoreKit.h>

@implementation FAEventDetailsTableViewCell

- (void)awakeFromNib {
    
    // Initialization code
    [super awakeFromNib];
    
    // Add a tap gesture recognizer to the related data description area to capture link clicks
    UITapGestureRecognizer *linkTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(textViewTapped:)];
    [self.descriptionArea addGestureRecognizer:linkTapRecognizer];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

// When a user taps the related data description area, if it contains a URL, open that URL
// using the system methods.
- (void)textViewTapped:(UITapGestureRecognizer *)tapGesture {
    
    NSAttributedString *descriptionString = [self.descriptionArea attributedText];
    NSRange descriptionRange = NSMakeRange(0,[descriptionString length]);
    NSDictionary *descAttributes = [descriptionString attributesAtIndex:0 effectiveRange:&descriptionRange];
    NSURL *targetURL = descAttributes[NSLinkAttributeName];
    
    if (targetURL) {
        
        // TRACKING EVENT: External Action Clicked: User clicked a link to do something outside Knotifi.
        // TO DO: Disabling to not track development events. Enable before shipping.
        /*[FBSDKAppEvents logEvent:@"External Action Clicked"
                      parameters:@{ @"Action Title" : self.descriptionArea.text,
                                    @"Action URL" : [targetURL absoluteString]} ];*/
        
        // TO DO FINAL: Delete after final test
        //NSLog(@"LINK TAPPED:%@ %@", self.descriptionArea.text, targetURL);
        
        [[UIApplication sharedApplication] openURL:targetURL];
    }
}

@end
