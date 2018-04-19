//
//  FACoinAltData.m
//  FinApp
//  Class to store alternate data for entities (stocks, fed) like investor site. Basically, when looking at this class think of a Coin as an entity (stocks, fed meetings). Implemented as a singleton.
//  Created by Sidd Singh on 4/15/18.
//  Copyright © 2018 Sidd Singh. All rights reserved.
//  The data in this file has been curated by Litchi Labs. Cannot be used in apps without approval from Litchi Labs. If you need to please reach connect with us here: http://www.knotifi.com/p/contact.html
//

#import "FACoinAltData.h"
#import "FADataController.h"
#import "EventHistory.h"
#import <UIKit/UIKit.h>

@implementation FACoinAltData

static FACoinAltData *sharedInstance;

// Implement this class as a Singleton to create a single data store accessible
// from anywhere in the app.
+ (void)initialize
{
    
    static BOOL exists = NO;
    
    // If a SnapShot doesn't already exist
    if(!exists)
    {
        exists = YES;
        sharedInstance= [[FACoinAltData alloc] init];
    }
}

// Create and/or return the single Snapshot
+(FACoinAltData *)singleAltDataBox {
    
    return sharedInstance;
}

// Get mostly static profile information for a given entity (stocks, fed, etc) i.e.
// 1. Investor Site(for stock)/Agency home page
// 2. Best Earnings/Econ event outcome link (typically on the site from 1)
- (NSMutableArray *)getProfileInfoForCoin:(NSString *)ticker {
    
    NSMutableArray * infoArray = [NSMutableArray arrayWithCapacity:2];
    
    if ([ticker caseInsensitiveCompare:@"AAPL"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"Not Available"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"Not Available"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"AMD"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"Not Available"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"Not Available"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"AMZN"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"Not Available"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"Not Available"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"AXP"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"Not Available"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"Not Available"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"BAC"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"http://investor.bankofamerica.com/phoenix.zhtml?c=71595&p=irol-irhome#fbid=Leba_PsPn-w"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"http://investor.bankofamerica.com/phoenix.zhtml?c=71595&p=irol-audioarchives"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"C"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"http://www.citigroup.com/citi/investor/pres.htm"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"http://www.citigroup.com/citi/investor/pres.htm"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"EA"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"Not Available"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"Not Available"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"FB"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://investor.fb.com/home/default.aspx"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://investor.fb.com/investor-events/default.aspx"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"GS"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"http://www.goldmansachs.com/investor-relations/"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"http://www.goldmansachs.com/investor-relations/presentations/index.html"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"JPM"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://www.jpmorganchase.com/corporate/investor-relations/investor-relations.htm"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://www.jpmorganchase.com/corporate/investor-relations/quarterly-earnings.htm"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"IBM"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://www.ibm.com/investor/"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://www.ibm.com/investor/events/"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"MS"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://www.morganstanley.com/about-us-ir"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://www.morganstanley.com/about-us-ir"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"CLDR"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://investors.cloudera.com/Investors/default.aspx.html"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://investors.cloudera.com/events/Events/default.aspx"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"FOX"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://www.21cf.com/investor-relations/"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://www.21cf.com/investor-relations/"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"TEAM"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://investors.atlassian.com/investors-overview/default.aspx"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://investors.atlassian.com/events-and-presentations/default.aspx"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"GOOG"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://abc.xyz/investor/"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"GOOGL"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://abc.xyz/investor/"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://abc.xyz/investor/"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"GM"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://www.gm.com/investors/index.html"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"http://www.gm.com/investors/announcements-events.html"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"HSBC"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"http://www.hsbc.com/investor-relations"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"http://www.hsbc.com/investor-relations/events-and-presentations"];
    }
    
    else if ([ticker caseInsensitiveCompare:@"NFLX"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"https://ir.netflix.com/investor-relations"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"https://ir.netflix.com/quarterly-earnings"];
    }
    
   /* else if ([ticker caseInsensitiveCompare:@"NKE"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"NVDA"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"QCOM"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"SNAP"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"T"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"TSLA"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"V"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"VZ"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"WFC"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"CRM"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"MSFT"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"VIA"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"CMCSA"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"UA"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"NTDOY"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"TWX"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"NOK"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"INTC"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"SNE"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"SQ"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"GRMN"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"FIT"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"GPRO"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"ANET"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"ATVI"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"DIS"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"BABA"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"BOX"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"LULU"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"ORCL"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"BB"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"TWLO"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    else if ([ticker caseInsensitiveCompare:@"OKTA"] == NSOrderedSame) {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@""];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@""];
    }
    
    */
    
    // If not available set to default value of Not Available
    else {
        // 1. Investor Site(for stock)/Agency home page
        [infoArray addObject:@"Not Available"];
        // 2. Best Earnings/Econ event outcome link (typically on the site from 1)
        [infoArray addObject:@"Not Available"];
    }
    
    return infoArray;
}

@end

