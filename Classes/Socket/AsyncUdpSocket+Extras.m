//
//  AsyncUdpSocket+Extras.m
//  TeamSquawk
//
//  Created by Matt Wright on 12/08/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "AsyncUdpSocket+Extras.h"


@implementation AsyncUdpSocket (Extras)

- (BOOL)connectToHost:(NSString *)host onPort:(UInt16)port retainingError:(NSError **)errPtr
{
  BOOL res = [self connectToHost:host onPort:port error:errPtr];
  if (!res && errPtr && *errPtr)
  {
    [*errPtr retain];
  }
  return res;
}

@end
