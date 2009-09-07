/*
 *  object.h
 *  WiganWallgate
 *
 *  Created by Matt Wright on 06/09/2009.
 *  Copyright 2009 Matt Wright. All rights reserved.
 *
 */

#ifndef __DISPATCH_OBJECT_H__
#define __DISPATCH_OBJECT_H__

#include <WiganWallgate/base.h>

typedef void (*dispatch_function_t)(void*);

struct dispatch_object_s
{
  int retain_count;
  int suspend_count;
  
  void (^dealloc)(void);
  void (^suspend)(void);
  void (^resume)(void);
  
  dispatch_function_t finaliser;
  void *context;
};

void dispatch_retain(dispatch_object_t object);
void dispatch_release(dispatch_object_t object);
void dispatch_suspend(dispatch_object_t object);
void dispatch_resume(dispatch_object_t object);

#endif __DISPATCH_OBJECT_H__
