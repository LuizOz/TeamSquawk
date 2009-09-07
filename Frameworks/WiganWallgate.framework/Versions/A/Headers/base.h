/*
 *  base.h
 *  WiganWallgate
 *
 *  Created by Matt Wright on 06/09/2009.
 *  Copyright 2009 Matt Wright. All rights reserved.
 *
 */

#ifndef __DISPATCH_BASE_H__
#define __DISPATCH_BASE_H__

enum {
  DISPATCH_QUEUE_PRIORITY_HIGH = 2,
  DISPATCH_QUEUE_PRIORITY_DEFAULT = 0,
  DISPATCH_QUEUE_PRIORITY_LOW = -2,
};

typedef union {
  struct dispatch_object_s *_do;
  struct dispatch_queue_s *_dq;
  struct dispatch_group_s *_dg;
  struct dispatch_list_s *_dl;
  struct dispatch_source_s *_ds;
} dispatch_object_t __attribute__((transparent_union));

/*
 We don't really want to present all of the manager's internals to the public
 so the init function and other useful ones are defined here
 */

void dispatch_manager_init();

/*
 We can't avoid having to make the use setup the main thread consumer because
 we can't hook into Foundation ourselves and make it automagically appear like
 in Grand Central. Boo.
 */
void dispatch_manager_runloop_init();

/*
 A debug function, zomg ;)
 */
#define WW_DEBUG 1

#ifdef WW_DEBUG
#include <stdio.h>
#define WW_DBG(x...) fprintf(stderr, "WW_DBG: " x)
#else
#define WW_DBG()
#endif

#define WW_ERROR(x...) fprintf(stderr, "WW_ERROR: " x)

#endif // __DISPATCH_BASE_H__
