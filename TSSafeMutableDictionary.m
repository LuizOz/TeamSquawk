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

#import "TSSafeMutableDictionary.h"

@implementation TSSafeMutableDictionary

- (id)init
{
  if (self = [super init])
  {
    dict = [[NSMutableDictionary alloc] init];
    queue = dispatch_queue_create("uk.co.sysctl.teamsquawk.safedict", 0);
  }
  return self;	
}

- (id)initWithCapacity:(NSUInteger)numItems
{
  if (self = [self init])
  {
    // nowt
  }
  return self;
}

- (void)dealloc
{
  dispatch_release(queue);
  [dict release];
  [super dealloc];
}

- (NSUInteger)count
{
  return [dict count];
}

- (id)objectForKey:(id)aKey
{
  id __block val = nil;
  dispatch_sync(queue, ^{
    val = [dict objectForKey:aKey];
  });
  return val;
}

- (NSEnumerator *)keyEnumerator
{
  NSEnumerator __block *enumerator = nil;
  dispatch_sync(queue, ^{
    enumerator = [[[dict copy] autorelease] keyEnumerator];
  });
  return enumerator;
}

- (void)removeObjectForKey:(id)aKey
{
  dispatch_sync(queue, ^{
    [dict removeObjectForKey:aKey];
  });
}

- (void)setObject:(id)anObject forKey:(id)aKey
{
  dispatch_sync(queue, ^{
    [dict setObject:anObject forKey:aKey];
  });
}

@end
