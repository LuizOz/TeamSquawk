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
