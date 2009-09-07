/*
 *  queue.h
 *  WiganWallgate
 *
 *  Created by Matt Wright on 04/09/2009.
 *  Copyright 2009 Matt Wright. All rights reserved.
 *
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

dispatch_queue_t dispatch_queue_create_concurrent();
dispatch_queue_t dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);

void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t work);

void dispatch_sync(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_sync_f(dispatch_queue_t queue, void *context, dispatch_function_t work);

void dispatch_apply(size_t iterations, dispatch_queue_t queue, void (^block)(size_t));
void dispatch_apply_f(size_t iterations, dispatch_queue_t queue, void *context, void (*work)(void *, size_t));

void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
void dispatch_after_f(dispatch_time_t when, void *context, dispatch_function_t work);

/*
 Returns the global queue of a certain prority
 */
dispatch_queue_t dispatch_get_global_queue(long priority, unsigned long flags);
dispatch_queue_t dispatch_get_main_queue();

#endif