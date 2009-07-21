/*
 *  MWFramework.h
 *  MWFramework
 *
 *  Created by Matt Wright on 20/07/2009.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#import <MWFramework/MWBetterCrashes.h>
#import <MWFramework/UKCrashReporter.h>

NSString *MWStackTrace(void);

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
// Returns a string containing a nicely formatted stack trace from the
// exception.  Only available on 10.5 or later, uses 
// -[NSException callStackReturnAddresses].
//
NSString *MWStackTraceFromException(NSException *e);
#endif