//
//  Action.m
//  FinApp
//
//  Class represents Action object in the core data model.
//
//  Created by Sidd Singh on 8/17/15.
//  Copyright (c) 2015 Sidd Singh. All rights reserved.
//

#import "Action.h"
#import "Event.h"


@implementation Action

// Represents the type of action that the user has taken on this event. Currently there's only one type of action "OSReminder" which means creating a reminder native to iOS.
@dynamic type;

// Represents the status of that action. It's dependent on the type of action. Currently for action type "OSReminder", there's two statuses 1) "Created" - meaning the reminder has been created 2) "Queued" - meaning the reminder is queued to be created and will be once the actual date for the event is confirmed.
@dynamic status;

// The event associated with this action.
@dynamic parentEvent;

@end
