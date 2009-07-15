//
//  NSOutlineView+ThreadSafety.h
//  TeamSquawk
//
//  Created by Matt Wright on 15/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TSOutlineView : NSOutlineView {
  NSLock *lock;
}

- (void)displayIfNeeded;

- (void)lock;
- (void)unlock;

@end
