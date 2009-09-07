/*
 *  list.h
 *  WiganWallgate
 *
 *  Created by Matt Wright on 04/09/2009.
 *  Copyright 2009 Matt Wright. All rights reserved.
 *
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
void dispatch_list_append(dispatch_list_t list, void *data);
void dispatch_list_remove_at_index(dispatch_list_t list, unsigned int index);
void* dispatch_list_value_at_index(dispatch_list_t list, unsigned int index);
void* dispatch_list_pop_from_front(dispatch_list_t list);

#endif
