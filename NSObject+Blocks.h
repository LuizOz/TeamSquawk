//
//  NSObject+Blocks.h
//  TeamSquawk
//
//  Created by Matt Wright on 04/09/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSObject (Blocks)

- (void)performBlock:(void (^)())block;
- (void)performBlock:(void (^)())block onThread:(NSThread*)thread;

@end
