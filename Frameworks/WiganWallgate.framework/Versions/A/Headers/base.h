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
