//
//  FACoinAltData.h
//  FinApp
//
//  Class to store alternate data for entities (stocks, fed) like investor site. Basically, when looking at this class think of a Coin as an entity (stocks, fed)
//
//  Created by Sidd Singh on 04/15/18.
//  Copyright © 2018 Sidd Singh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class FADataController;
@class EventHistory;

@interface FACoinAltData : NSObject

// Create and/or return the single shared data store
+ (FACoinAltData *) singleAltDataBox;

// Get profile information for a given coin i.e. Short Description,Real World Use Case,Backed By,Best Exchange,More Exchanges.
- (NSMutableArray *)getProfileInfoForCoin:(NSString *)ticker;

@end
