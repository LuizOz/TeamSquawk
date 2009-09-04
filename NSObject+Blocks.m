//
//  NSObject+Blocks.m
//  TeamSquawk
//
//  Created by Matt Wright on 04/09/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "NSObject+Blocks.h"


@implementation NSObject (Blocks)

- (void)performBlock:(void (^)())block
{
  block();
}

- (void)performBlock:(void (^)())block onThread:(NSThread*)thread
{
  if (![[NSThread currentThread] isEqual:thread])
  {
    [self performSelector:@selector(performBlock:) onThread:thread withObject:block waitUntilDone:YES];
    return;
  }
  block();
}

@end
