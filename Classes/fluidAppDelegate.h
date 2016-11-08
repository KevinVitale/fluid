//
//  fluidAppDelegate.h
//  fluid
//
//  Created by Kevin Vitale on 4/28/11.
//  Copyright Domino's Pizza 2011. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RootViewController;

@interface fluidAppDelegate : NSObject <UIApplicationDelegate> {
	UIWindow			*window;
	RootViewController	*viewController;
}

@property (nonatomic, retain) UIWindow *window;

@end
