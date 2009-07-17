//
//  TSThreadBlocker.m
//  TeamSquawk
//
//  Created by Matt Wright on 17/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSThreadBlocker.h"

@interface TSThreadBlocker (Private)

- (void)_blocker;

@end


@implementation TSThreadBlocker

- (id)init
{
  if (self = [super init])
  {
    lock = [[NSLock alloc] init];
    isBlocked = NO;
  }
  return self;
}

- (void)dealloc
{
  [lock release];
  [super dealloc];
}

- (void)_blocker
{
  isBlocked = YES;
  [lock lock];
  [lock unlock];
  isBlocked = NO;
}

- (void)blockThread:(NSThread*)thread
{
  isBlocked = NO;
  [lock lock];
  
  [self performSelector:@selector(_blocker) onThread:thread withObject:nil waitUntilDone:NO];
  
  // spin till we've got the thread blocked
  while (!isBlocked) {}
}

- (void)blockMainThread
{
  [self blockThread:[NSThread mainThread]];
}

- (void)unblockThread
{
  [lock unlock];
  while (isBlocked) {}
}

@end
