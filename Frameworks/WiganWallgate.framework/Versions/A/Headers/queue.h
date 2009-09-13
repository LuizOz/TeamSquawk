/*
 Wigan Wallgate: An open-source implementation of Grand Central Dispatch
 
 Copyright (c) 2009 Matt Wright
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#ifndef __DISPATCH_QUEUE_H__
#define __DISPATCH_QUEUE_H__

enum {
  DISPATCH_QUEUE_TYPE_PARALLEL = 0,
  DISPATCH_QUEUE_TYPE_SERIAL = 1,
};

enum {
  DISPATCH_QUEUE_IDLE = 0,
  DISPATCH_QUEUE_BUSY = 1,
};

#include <WiganWallgate/base.h>
#include <WiganWallgate/list.h>
#include <WiganWallgate/object.h>
#include <WiganWallgate/time.h>

struct dispatch_queue_s 
{
  struct dispatch_object_s object;
  
  // queue name
  char *name;
  
  // the queue type
  unsigned int type;
  
  // busyness
  unsigned int busy;
  
  // linked list of blocks to do
  dispatch_list_t list;
  dispatch_list_t last;
};

typedef struct dispatch_queue_s* dispatch_queue_t;
typedef int dispatch_queue_attr_t;

typedef void (^dispatch_block_t)(void);

dispatch_queue_t dispatch_queue_create_concurrent(const char *label, dispatch_queue_attr_t attr);
dispatch_queue_t dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);

void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t work);

void dispatch_sync(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_sync_f(dispatch_queue_t queue, void *context, dispatch_function_t work);

void dispatch_apply(size_t iterations, dispatch_queue_t queue, void (^block)(size_t));
void dispatch_apply_f(size_t iterations, dispatch_queue_t queue, void *context, void (*work)(void *, size_t));

void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
void dispatch_after_f(dispatch_time_t when, dispatch_queue_t queue, void *context, dispatch_function_t work);

/*
 Returns the global queue of a certain prority
 */
dispatch_queue_t dispatch_get_global_queue(long priority, unsigned long flags);
dispatch_queue_t dispatch_get_main_queue();

#endif