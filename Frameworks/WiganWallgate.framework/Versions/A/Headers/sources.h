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

#ifndef __DISPATCH_SOURCES_H__
#define __DISPATCH_SOURCES_H__

#include <WiganWallgate/queue.h>
#include <WiganWallgate/time.h>

struct dispatch_source_s;
typedef struct dispatch_source_s* dispatch_source_t;
typedef const struct dispatch_source_type_s* dispatch_source_type_t;

#define DISPATCH_SOURCE_TYPE_READ (&_dispatch_source_type_read)
extern const struct dispatch_source_type_s _dispatch_source_type_read;

#define DISPATCH_SOURCE_TYPE_WRITE (&_dispatch_source_type_write)
extern const struct dispatch_source_type_s _dispatch_source_type_write;

#define DISPATCH_SOURCE_TYPE_TIMER (&_dispatch_source_type_timer)
extern const struct dispatch_source_type_s _dispatch_source_type_timer;

#define DISPATCH_SOURCE_TYPE_DATA_ADD (&_dispatch_source_type_add)
extern const struct dispatch_source_type_s _dispatch_source_type_add;

#define DISPATCH_SOURCE_TYPE_DATA_OR (&_dispatch_source_type_or)
extern const struct dispatch_source_type_s _dispatch_source_type_or;

dispatch_source_t dispatch_source_create(dispatch_source_type_t type, uintptr_t handle, unsigned long mask, dispatch_queue_t queue);
void dispatch_source_set_event_handler(dispatch_source_t source, dispatch_block_t handler);
void dispatch_source_set_cancel_handler(dispatch_source_t source, dispatch_block_t cancel_handler);
void dispatch_source_cancel(dispatch_source_t source);

unsigned long dispatch_source_get_data(dispatch_source_t source);
uintptr_t dispatch_source_get_handle(dispatch_source_t source);
unsigned long dispatch_source_get_mask(dispatch_source_t source);

void dispatch_source_set_timer(dispatch_source_t source, dispatch_time_t start, uint64_t interval, uint64_t leeway);

void dispatch_source_merge_data(dispatch_source_t source, unsigned long value);

#endif __DISPATCH_SOURCES_H__
