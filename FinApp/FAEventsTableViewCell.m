//
//  FAEventsTableViewCell.m
//  FinApp
//
//  Class that manages the custom events table view cell
//
//  Created by Sidd Singh on 12/23/14.
//  Copyright (c) 2014 Sidd Singh. All rights reserved.
//

#import "FAEventsTableViewCell.h"
#import <QuartzCore/QuartzCore.h>

@implementation FAEventsTableViewCell

- (void)awakeFromNib {
    // Initialization code
    [super awakeFromNib];
    
    // Set top left and right corners to rounded for ticker label
    CGRect lblBounds = self.companyTicker.bounds;
    UIBezierPath *lblMaskPath = [UIBezierPath bezierPathWithRoundedRect:lblBounds
                                                   byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                                         cornerRadii:CGSizeMake(5.0, 5.0)];
    CAShapeLayer *lblMaskLayer = [CAShapeLayer layer];
    lblMaskLayer.frame = lblBounds;
    lblMaskLayer.path = lblMaskPath.CGPath;
    self.companyTicker.layer.mask = lblMaskLayer;
    
    // Set bottom left and right corners to rounded for news button
    CGRect btnBounds = self.newsButon.bounds;
    UIBezierPath *btnMaskPath = [UIBezierPath bezierPathWithRoundedRect:btnBounds
                                                      byRoundingCorners:(UIRectCornerBottomRight | UIRectCornerBottomLeft)
                                                            cornerRadii:CGSizeMake(5.0, 5.0)];
    CAShapeLayer *btnMaskLayer = [CAShapeLayer layer];
    btnMaskLayer.frame = btnBounds;
    btnMaskLayer.path = btnMaskPath.CGPath;
    self.newsButon.layer.mask = btnMaskLayer;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
