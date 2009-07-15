//
//  NSOutlineView+ThreadSafety.m
//  TeamSquawk
//
//  Created by Matt Wright on 15/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSOutlineView.h"


@implementation TSOutlineView

- (id)initWithCoder:(NSCoder *)decoder
{
  if (self = [super initWithCoder:decoder])
  {
    lock = [[NSLock alloc] init];
  }
  return self;
}

- (id)initWithFrame:(NSRect)frame
{
  if (self = [super initWithFrame:frame])
  {
    lock = [[NSLock alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [lock release];
  [super dealloc];
}

- (void)displayIfNeeded
{
  [lock lock];
  [super displayIfNeeded];
  [lock unlock];
}

- (void)lock
{
  [lock lock];
}

- (void)unlock
{
  [lock unlock];
}

@end
