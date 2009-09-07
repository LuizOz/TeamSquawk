/*
 *  time.h
 *  WiganWallgate
 *
 *  Created by Matt Wright on 06/09/2009.
 *  Copyright 2009 Matt Wright. All rights reserved.
 *
 */

#ifndef __DISPATCH_TIME_H__
#define __DISPATCH_TIME_H__

#include <stdint.h>
#include <sys/time.h>

typedef uint64_t dispatch_time_t;

#ifdef NSEC_PER_SEC
#undef NSEC_PER_SEC
#endif
#ifdef USEC_PER_SEC
#undef USEC_PER_SEC
#endif
#ifdef NSEC_PER_USEC
#undef NSEC_PER_USEC
#endif
#define NSEC_PER_SEC 1000000000ull
#define USEC_PER_SEC 1000000ull
#define NSEC_PER_USEC 1000ull

#define DISPATCH_TIME_NOW 0
#define DISPATCH_TIME_FOREVER (~0ull)

dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta);
dispatch_time_t dispatch_walltime(const struct timespec *when, int64_t delta);

#endif // __DISPATCH_TIME_H__
