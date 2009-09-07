/*
 *  sources.h
 *  WiganWallgate
 *
 *  Created by Matt Wright on 06/09/2009.
 *  Copyright 2009 Matt Wright. All rights reserved.
 *
 */

#ifndef __DISPATCH_SOURCES_H__
#define __DISPATCH_SOURCES_H__

#include <WiganWallgate/queue.h>
#include <WiganWallgate/time.h>

struct dispatch_source_s;
typedef struct dispatch_source_s* dispatch_source_t;
typedef const struct dispatch_source_type_s* dispatch_source_type_t;

#define DISPATCH_SOURCE_TYPE_READ (&_dispatch_source_type_read)
extern const struct dispatch_source_type_s _dispatch_source_type_read;

#define DISPATCH_SOURCE_TYPE_TIMER (&_dispatch_source_type_timer)
extern const struct dispatch_source_type_s _dispatch_source_type_timer;

dispatch_source_t dispatch_source_create(dispatch_source_type_t type, uintptr_t handle, unsigned long mask, dispatch_queue_t queue);
void dispatch_source_set_event_handler(dispatch_source_t source, dispatch_block_t handler);
void dispatch_source_cancel(dispatch_source_t source);

unsigned long dispatch_source_get_data(dispatch_source_t source);
uintptr_t dispatch_source_get_handle(dispatch_source_t source);
unsigned long dispatch_source_get_mask(dispatch_source_t source);

void dispatch_source_set_timer(dispatch_source_t source, dispatch_time_t start, uint64_t interval, uint64_t leeway);

#endif __DISPATCH_SOURCES_H__
