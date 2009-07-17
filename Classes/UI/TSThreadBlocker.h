//
//  TSThreadBlocker.h
//  TeamSquawk
//
//  Created by Matt Wright on 17/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Sigh, stupid class. Here to block up another thread while you perform some operations.
// I'm going to use it to try and maintain thread safety in cocoa without having to have a
// GAZZILION ways of updating data on the main thread

@interface TSThreadBlocker : NSObject {
  BOOL isBlocked;
  NSLock *lock;
}

- (id)init;
- (void)dealloc;

- (void)blockThread:(NSThread*)thread;
- (void)blockMainThread;
- (void)unblockThread;

@end
