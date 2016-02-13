//
//  FACompanyInfoStore.m
//  FinApp
//
//  Single Instance class that stores static company related information e.g. URL for investor site for AAPL.
//
//  Created by Sidd Singh on 2/12/16.
//  Copyright © 2016 Sidd Singh. All rights reserved.
//

#import "FACompanyInfoStore.h"

@implementation FACompanyInfoStore


static FACompanyInfoStore *sharedInstance;

// Dictionary that stores the companies investor site info
static NSMutableDictionary *investorSiteStore;


// Implement this class as a Singleton to create a single company info store accessible
// from anywhere in the app.
+ (void)initialize
{
    
    static BOOL exists = NO;
    
    // If a company info store doesn't already exist
    if(!exists)
    {
        exists = YES;
        sharedInstance = [[FACompanyInfoStore alloc] init];
        investorSiteStore = [[NSMutableDictionary alloc] init];
        [self initInvestorSiteStore];
    }
}

// Create and/or return the single shared company info store
+ (FACompanyInfoStore *)sharedInfoStore {
    
    return sharedInstance;
}

// Initialize the investor site store with all the companies and their investor sites
+ (void)initInvestorSiteStore
{
    // Add Apple's info
    [investorSiteStore setObject:@"http://investor.apple.com/" forKey:@"AAPL"];
}

// Get the investor site URL for a given ticker. Returns "Not_Found" if the info doesn't exist.
+ (NSString *)getInvestorSiteForTicker:(NSString *)ticker
{
    NSString *siteURL = [investorSiteStore valueForKey:ticker];
    
    // If the site URL doesn't exist, set it to "Not_Found"
    if(siteURL == nil) {
        siteURL = @"Not_Found";
    }
    
    return siteURL;
}

@end
