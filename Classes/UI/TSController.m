//
//  TSController.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSController.h"
#import "SLConnection.h"

@implementation TSController

- (void)awakeFromNib
{
  NSError *error = nil;
  SLConnection *connection = [[SLConnection alloc] initWithHost:@"ts.deadcodeelimination.com" withError:&error];
  if (!connection)
  {
    NSLog(@"%@", error);
  }
  
  [connection setClientName:@"TeamSquawk"];
  [connection setClientOperatingSystem:@"Mac OS X"];
  [connection setClientMajorVersion:1];
  [connection setClientMinorVersion:0];
  
  [connection beginAsynchronousLogin:nil password:@"lionftw" nickName:@"Shamlion" isRegistered:NO];
}

@end
