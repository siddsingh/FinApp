//
//  AppDelegate.h
//  FinApp
//
//  Created by Sidd Singh on 10/8/14.
//  Copyright (c) 2014 Sidd Singh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

/* Not needed since our achitecture uses a Data Controller and Data Store to manage core data storage and retrieval. These mehtods are implemented in there.
 
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;
*/

@end

