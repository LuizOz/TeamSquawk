//
//  AsyncUdpSocket+Extras.h
//  TeamSquawk
//
//  Created by Matt Wright on 12/08/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AsyncUdpSocket.h"

@interface AsyncUdpSocket (Extras)

- (BOOL)connectToHost:(NSString *)host onPort:(UInt16)port retainingError:(NSError **)errPtr;

@end
