//
//  TSController.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSController.h"
#import "TSAudioExtraction.h"
#import <MTCoreAudio/MTCoreAudio.h>

@implementation TSController

- (void)awakeFromNib
{
//  NSError *error = nil;
//  
//  [NSApp setDelegate:self];
//  
//  connection = [[SLConnection alloc] initWithHost:@"ts.deadcodeelimination.com" withError:&error];
//  [connection setDelegate:self];
//  
//  if (!connection)
//  {
//    NSLog(@"%@", error);
//  }
//  
//  [connection setClientName:@"TeamSquawk"];
//  [connection setClientOperatingSystem:@"Mac OS X"];
//  [connection setClientMajorVersion:1];
//  [connection setClientMinorVersion:0];
//  
//  [connection beginAsynchronousLogin:nil password:@"lionftw" nickName:@"Shamlion" isRegistered:NO];
  
  player = [[TSCoreAudioPlayer alloc] initWithOutputDevice:[MTCoreAudioDevice defaultOutputDevice]];
  
  [self performSelectorInBackground:@selector(audioPlayerThread) withObject:nil];
  [self performSelectorInBackground:@selector(audioDecoderThread) withObject:nil];
}

- (void)audioPlayerThread
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [player setIsRunning:YES];
  [pool release];
}

- (void)audioDecoderThread
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSError *error = nil;
  
  TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Desktop/Disturbed/Believe/Disturbed/Believe/01 - Prayer.m4a"];
  NSLog(@"starting, %@", extraction);
  NSData *audio = [extraction extractWithDuration:120 error:&error];
  NSLog(@"finished, %@, %d", error, [audio length]);
  
  unsigned int counter = 0;
  while (counter < [audio length])
  {
    [player queueBytesFromData:[audio subdataWithRange:NSMakeRange(counter, 44100*4)] numOfFrames:44100];
    counter += 44110*4;
  }
  
  [pool release];
}

@end
