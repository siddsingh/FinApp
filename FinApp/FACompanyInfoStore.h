//
//  FACompanyInfoStore.h
//  FinApp
//
//  Single Instance class that stores static company related information e.g. URL for investor site for AAPL.
//
//
//  Created by Sidd Singh on 2/12/16.
//  Copyright © 2016 Sidd Singh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FACompanyInfoStore : NSObject

// Create and/or return the single shared data store
+ (FACompanyInfoStore *) sharedInfoStore;

// Initialize the investor site store with all the companies and their investor sites
+ (void)initInvestorSiteStore;

// Get the investor site URL for a given ticker
+ (NSString *)getInvestorSiteForTicker:(NSString *)ticker;

@end
