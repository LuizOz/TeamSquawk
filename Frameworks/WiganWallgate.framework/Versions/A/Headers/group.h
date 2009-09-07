/*
 *  group.h
 *  WiganWallgate
 *
 *  Created by Matt Wright on 06/09/2009.
 *  Copyright 2009 Matt Wright. All rights reserved.
 *
 */

#ifndef __DISPATCH_GROUP_H__
#define __DISPATCH_GROUP_H__

#include <WiganWallgate/queue.h>
#include <WiganWallgate/time.h>

struct dispatch_group_s;
typedef struct dispatch_group_s* dispatch_group_t;

dispatch_group_t dispatch_group_create(void);
void dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
void dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
long dispatch_group_wait(dispatch_group_t group, dispatch_time_t timeout);
void dispatch_group_enter(dispatch_group_t group);
void dispatch_group_leave(dispatch_group_t group);

#endif // __DISPATCH_GROUP_H__
