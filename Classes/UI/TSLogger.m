/*
 * TeamSquawk: An open-source TeamSpeak client for Mac OS X
 *
 * Copyright (c) 2010 Matt Wright
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "TSLogger.h"
#import <stdarg.h>

@interface TSLogger ()

+ (id)logger;

- (id)init;
- (void)dealloc;
+ (NSString*)log;
- (void)logFormat:(NSString*)format arguments:(va_list)args;
- (void)setEventBlock:(dispatch_block_t)block;

@end

static TSLogger *staticLogger = nil;
static dispatch_once_t staticLoggerOnce = 0;

@implementation TSLogger

+ (id)logger
{
  dispatch_once(&staticLoggerOnce, ^{
    staticLogger = [[TSLogger alloc] init];
  });
  return staticLogger;
}

+ (NSString*)log
{
  return [[TSLogger logger] log];
}

+ (void)logFormat:(NSString*)format, ...
{
  va_list va;
  
  va_start(va, format);
  [[TSLogger logger] logFormat:format arguments:va];
  va_end(va);
}

+ (void)setEventBlock:(dispatch_block_t)block
{
  [[TSLogger logger] setEventBlock:block];
}

- (id)init
{
  if (self = [super init])
  {
    log = [[NSMutableString alloc] init];
    logQueue = dispatch_queue_create("uk.co.teamsquawk.log", 0);
  }
  return self;
}

- (void)dealloc
{
  dispatch_release(logQueue);
  [log release];
  [super dealloc];
}

- (NSString*)log
{
  NSString __block *val = nil;
  dispatch_sync(logQueue, ^{
    val = [[log copy] autorelease];
  });
  return val;
}

- (void)logFormat:(NSString*)format arguments:(va_list)args
{
  NSString *fmt = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  dispatch_async(logQueue, ^{
    [log appendFormat:@"%@\n", fmt];
    if (eventBlock)
    {
      dispatch_async(dispatch_get_global_queue(0, 0), eventBlock);
    }
  });
}

- (void)setEventBlock:(dispatch_block_t)block
{
  [eventBlock autorelease];
  eventBlock = [block copy];
}

@end
