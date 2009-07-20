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
    doneInvocation = nil;
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
  
  if (doneInvocation)
  {
    [doneInvocation invoke];
  }
  
  isBlocked = NO;
}

- (void)blockThread:(NSThread*)thread
{
  if ([thread isEqual:[NSThread currentThread]])
  {
    isBlocked = NO;
    return;
  }
  
  isBlocked = NO;
  [lock lock];
  
  [self performSelector:@selector(_blocker) onThread:thread withObject:nil waitUntilDone:NO];
  
  // spin till we've got the thread blocked
  while (!isBlocked) { /* do nothing */ }
}

- (void)blockMainThread
{
  [self blockThread:[NSThread mainThread]];
}

- (void)unblockThread
{
  if (isBlocked)
  {
    [lock unlock];
  }
  while (isBlocked) {}
}

- (void)unblockAndPerformSelector:(SEL)selector onObject:(id)object
{
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:selector]];
  [invocation setSelector:selector];
  [self unblockAndInvoke:invocation onObject:object];
}

- (void)unblockAndPerformSelector:(SEL)selector onObject:(id)object withObject:(id)arg;
{
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:selector]];
  [invocation setSelector:selector];
  [invocation setArgument:&arg atIndex:2];
  
  [self unblockAndInvoke:invocation onObject:object];
}

- (void)unblockAndPerformSelector:(SEL)selector onObject:(id)object withObject:(id)arg andObject:(id)arg2;
{
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:selector]];
  [invocation setSelector:selector];
  [invocation setArgument:&arg atIndex:2];
  [invocation setArgument:&arg2 atIndex:3];
  
  [self unblockAndInvoke:invocation onObject:object];
}

- (void)unblockAndInvoke:(NSInvocation*)invocation onObject:(id)object
{
  [invocation setTarget:object];
  doneInvocation = invocation;
  [self unblockThread];
}

@end
