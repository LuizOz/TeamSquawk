//
//  TSController.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSController.h"

@implementation TSController

- (void)awakeFromNib
{
  NSError *error = nil;
  
  [NSApp setDelegate:self];
  
  connection = [[SLConnection alloc] initWithHost:@"ts.deadcodeelimination.com" withError:&error];
  [connection setDelegate:self];
  
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

- (void)connectionFinishedLogin:(SLConnection*)conn
{
  [conn sendTextMessage:@"hey foo" toPlayer:2];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  [connection disconnect];
  return YES;
}

@end
