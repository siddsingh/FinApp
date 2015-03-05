//
//  FAEventsViewController.m
//  FinApp
//
//  Class that manages the view showing upcoming events.
//
//  Created by Sidd Singh on 12/18/14.
//  Copyright (c) 2014 Sidd Singh. All rights reserved.
//

#import "FAEventsViewController.h"
#import "FAEventsTableViewCell.h"
#import "FADataController.h"

@interface FAEventsViewController ()

@end

@implementation FAEventsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    // Get a data controller that you will use later
    self.eventDataController = [[FADataController alloc] init];
    
    // TO DO: Temporaray Data Setup for testing. Erase later

    // Add Three Companies, Apple, Tesla, Electronic Arts
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Events List Table

// Return number of sections in the events list table view
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // There's only one section for now
    return 1;
}

// Return number of rows in the events list table view
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // TO DO: Placeholder for testing
    return 1;
}

// Return a cell configured to display a task or a task nav item
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //static NSString *CellIdentifier = @"EventCell";
    FAEventsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EventCell" forIndexPath:indexPath];
        
    // TO DO: Show the company ticker from the database
    [[cell  companyTicker] setText:@"TSLA"];
    
    // TO DO: Show the company name from the database
    [[cell  companyName] setText:@"Tesla"];
    
    // TO DO: Show the event description from the database
    [[cell  eventDescription] setText:@"Q4 Earnings Call on Jan 12th, 2015"];
    
    return cell;
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
