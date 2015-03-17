//
//  FADataController.m
//  FinApp
//
//  Class to interact with the core data store. Each thread should have it's own
//  FADataController that creates a new managed object context that talks to the
//  single data store.
//
//  Created by Sidd Singh on 3/2/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "FADataController.h"
#import "FADataStore.h"
#import "Company.h"
#import "Event.h"

@implementation FADataController

#pragma mark - Data Store related

// Managed Object Context to interact with Data Store.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    // Get the single persistent store for this application.
    self.appDataStore = [FADataStore sharedStore];
    
    if ([self.appDataStore persistentStoreCoordinator] != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:[self.appDataStore persistentStoreCoordinator]];
    }
    
    return _managedObjectContext;
}

#pragma mark - Company Data Related


// Add company details to the company data store. Current design is that a company
// is uniquely identified by it's ticker. Thus this method creates the company with
// it's details only if the ticker doesn't exist.
- (void)insertUniqueCompanyWithTicker:(NSString *)companyTicker name:(NSString *)companyName
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Check to see if the Company exists by doing a case insensitive query on companyTicker
    NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
    NSPredicate *companyPredicate = [NSPredicate predicateWithFormat:@"ticker =[c] %@",companyTicker];
    [companyFetchRequest setEntity:companyEntity];
    [companyFetchRequest setPredicate:companyPredicate];
    NSError *error;
    Company *existingCompany = nil;
    existingCompany  = [[dataStoreContext executeFetchRequest:companyFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting a company from data store, to check uniqueness when inserting, failed: %@",error.description);
    }
    
    // If the Company does not exist, insert it
    if (!existingCompany) {
        Company *company = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:dataStoreContext];
        company.ticker = companyTicker;
        company.name = companyName;
        // Insert
        if (![dataStoreContext save:&error]) {
            NSLog(@"ERROR: Saving a company that is unique, to the data store, failed: %@",error.description);
        }
    }
}


#pragma mark - Events Data Related

// Add an Event along with a parent company to the Event Data Store
- (void)insertEventWithDate:(NSDate *)eventDate details:(NSString *)eventDetails type:(NSString *)eventType certainty:(NSString *)eventCertainty listedCompany:(NSString *)listedCompanyTicker
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get the parent listed company for the event by doing a case insensitive query on the company ticker
    NSFetchRequest *companyFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *companyEntity = [NSEntityDescription entityForName:@"Company" inManagedObjectContext:dataStoreContext];
    [companyFetchRequest setEntity:companyEntity];
    NSPredicate *companyPredicate = [NSPredicate predicateWithFormat:@"ticker =[c] %@",listedCompanyTicker];
    [companyFetchRequest setPredicate:companyPredicate];
    NSError *error;
    Company *parentCompany = nil;
    parentCompany  = [[dataStoreContext executeFetchRequest:companyFetchRequest error:&error] lastObject];
    if (error) {
        NSLog(@"ERROR: Getting a parent listed company, for inserting an associated event from data store failed: %@",error.description);
    }
    
    // Insert the event with the parent listed company
    Event *event = [NSEntityDescription insertNewObjectForEntityForName:@"Event" inManagedObjectContext:dataStoreContext];
    event.date = eventDate;
    event.details = eventDetails;
    event.certainty = eventCertainty;
    event.listedCompany = parentCompany;
    if (![dataStoreContext save:&error]) {
        NSLog(@"ERROR: Saving event to data store failed: %@",error.description);
    }
}

// Get all Events. Returns a results controller with identities of all Events recorded, but no more
// than batchSize (currently set to 15) objects’ data will be fetched from the persistent store at a time.
- (NSFetchedResultsController *)getAllEvents
{
    NSManagedObjectContext *dataStoreContext = [self managedObjectContext];
    
    // Get all events with the upcoming ones first
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *eventEntity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:dataStoreContext];
    [eventFetchRequest setEntity:eventEntity];
    NSSortDescriptor *sortField = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
    [eventFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortField]];
    [eventFetchRequest setFetchBatchSize:15];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest
                                                                 managedObjectContext:dataStoreContext sectionNameKeyPath:nil
                                                                            cacheName:nil];
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        NSLog(@"ERROR: Getting all events from data store failed: %@",error.description);
    }
    
    return self.resultsController;
}

@end













