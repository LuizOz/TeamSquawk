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

#ifndef __DISPATCH_LIST_H__
#define __DISPATCH_LIST_H__

#include <CoreFoundation/CoreFoundation.h>
#include <libkern/OSAtomic.h>
#include <WiganWallgate/object.h>

struct dispatch_list_s;
typedef struct dispatch_list_s* dispatch_list_t;

struct dispatch_list_s 
{
  struct dispatch_object_s object;
  CFMutableArrayRef array;
  OSSpinLock lock;
};

dispatch_list_t dispatch_list_init();
unsigned int dispatch_list_count(dispatch_list_t list);
void dispatch_list_insert(dispatch_list_t list, unsigned int index, void *data);
void dispatch_list_insert_sorted(dispatch_list_t list, void *data, int (^block)(void* a, void* b));
void dispatch_list_append(dispatch_list_t list, void *data);
void dispatch_list_remove_at_index(dispatch_list_t list, unsigned int index);
void dispatch_list_remove_value(dispatch_list_t list, void *data);
void* dispatch_list_value_at_index(dispatch_list_t list, unsigned int index);
void* dispatch_list_pop_from_front(dispatch_list_t list);

#endif
