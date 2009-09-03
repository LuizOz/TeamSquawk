//
//  GCDUDPSocket.h
//  TeamSquawk
//
//  Created by Matt Wright on 03/09/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

@protocol GCDUDPSocketDelegate;

@interface GCDUDPSocket : NSObject {
  dispatch_queue_t send_queue;
  
  dispatch_source_t receive_source;
  dispatch_queue_t receive_queue;
  
  int socketfd;
  
  id<GCDUDPSocketDelegate> delegate;
}

@property (assign) id delegate;

- (id)init;
- (id)initWithDelegate:(id)delegate;

- (BOOL)connectToHost:(NSString*)host port:(unsigned short)port error:(NSError**)errPtr;
- (void)close;

- (BOOL)sendData:(NSData*)data withTimeout:(NSTimeInterval)timeout;

@end

@protocol GCDUDPSocketDelegate

@optional

- (void)GCDUDPSocket:(GCDUDPSocket*)socket didReceiveData:(NSData*)data fromHost:(NSString*)host port:(unsigned short)port;

@end