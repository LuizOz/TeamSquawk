//
//  GCDUDPSocket.m
//  TeamSquawk
//
//  Created by Matt Wright on 03/09/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "GCDUDPSocket.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

@implementation GCDUDPSocket

@synthesize delegate;

- (id)init
{
  if (self = [super init])
  {
    delegate = nil;
  }
  return self;
}

- (id)initWithDelegate:(id)aDelegate
{
  if (self = [self init])
  {
    socketfd = -1;
    self.delegate = aDelegate;
    send_queue = dispatch_queue_create("uk.co.sysctl.teamsquawk.udpsendqueue", 0);
    receive_queue = dispatch_queue_create("uk.co.sysctl.teamsquawk.udpreceivequeue", 0);
  }
  return self;
}

- (void)dealloc
{
  if (socketfd >= 0)
  {
    [self close];
  }
  dispatch_release(send_queue);
  dispatch_release(receive_queue);
  
  [super dealloc];
}

- (BOOL)connectToHost:(NSString*)host port:(unsigned short)port error:(NSError**)errPtr
{
  struct sockaddr_in addr;

  // first do some address conversion. 
  if (!host || host.length == 0)
  {
    // needs some error message
    return NO;
  }
  else if ([host isEqualToString:@"localhost"] || [host isEqualToString:@"loopback"])
  {
    addr.sin_len = sizeof(struct sockaddr_in);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    memset(&(addr.sin_zero), 0, sizeof(addr.sin_zero));
    
    socketfd = socket(addr.sin_family, SOCK_DGRAM, IPPROTO_UDP);
    if (socketfd == -1)
    {
      if (errPtr)
      {
        *errPtr = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s", strerror(errno)], NSLocalizedDescriptionKey, nil]];
      }

      return NO;
    }
    
    if (connect(socketfd, (struct sockaddr*)&addr, sizeof(addr)) == -1)
    {
      if (errPtr)
      {
        *errPtr = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s", strerror(errno)], NSLocalizedDescriptionKey, nil]];
      }

      return NO;
    }
  }
  else
  {
    struct addrinfo hints, *res, *res0;
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;
    
    int error = getaddrinfo([host UTF8String], [[NSString stringWithFormat:@"%hu", port] UTF8String], &hints, &res0);
    
    if (error)
    {
      if (errPtr)
      {
        *errPtr = [NSError errorWithDomain:@"GetAddrInfoErrorDomain" code:error userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s", gai_strerror(error)], NSLocalizedDescriptionKey, nil]];
      }
      return NO;
    }
    
    for (res = res0; res; res = res->ai_next)
    {
      if (res->ai_family == AF_INET)
      {
        // got a domain, lets open the socket
        socketfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
        if (socketfd == -1)
        {
          if (errPtr)
          {
            *errPtr = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s", strerror(errno)], NSLocalizedDescriptionKey, nil]];
          }
          
          freeaddrinfo(res0);
          return NO;
        }
        
        if (connect(socketfd, res->ai_addr, res->ai_addrlen) == -1)
        {
          if (errPtr)
          {
            *errPtr = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s", strerror(errno)], NSLocalizedDescriptionKey, nil]];
          }

          freeaddrinfo(res0);
          return NO;
        }
      }
    }
    freeaddrinfo(res0);
  }
  
  // if we got this far, check we've got a socket
  if (socketfd > -1)
  {
    // we've got a socket. We need to attach a dispatch source to it now
    receive_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, socketfd, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    dispatch_source_set_event_handler(receive_source, ^{
      void *buf = malloc(9216); // async socket deemed this the max packet size;
      size_t bufsz = 9216;
      
      struct sockaddr_in addr;
      socklen_t addr_len = sizeof(addr);
      
      int result = recvfrom(socketfd, buf, bufsz, 0, (struct sockaddr*)&addr, &addr_len);
      
      // no point doing this without a delegate
      if (self.delegate && [self.delegate respondsToSelector:@selector(GCDUDPSocket:didReceiveData:fromHost:port:)] && (result >= 0))
      {
        if (result != bufsz)
        {
          buf = realloc(buf, result);
        }
        
        // put our bytes in a wrapper
        NSData *data = [[NSData alloc] initWithBytesNoCopy:buf length:result freeWhenDone:YES];
        NSString *host = nil;
        unsigned short port = ntohs(addr.sin_port);
        
        char addrBuf[INET_ADDRSTRLEN];
        if (inet_ntop(AF_INET, &addr.sin_addr, addrBuf, sizeof(addrBuf)) != NULL)
        {
          host = [[NSString alloc] initWithUTF8String:addrBuf];
        }
        
        // put it in a dispatch to the class
        dispatch_async(receive_queue, ^{
          // tell the class
          [self.delegate GCDUDPSocket:self didReceiveData:data fromHost:host port:port];
          
          // release the dataz
          [data release];
          [host release];
        });
      }
      else 
      {
        free(buf);
      }
    });
    
    dispatch_resume(receive_source);
    
    return YES;
  }
  
  return NO;
}

- (void)close
{
  dispatch_source_cancel(receive_source);
  close(socketfd);
  socketfd = -1;
}

- (BOOL)sendData:(NSData*)data withTimeout:(NSTimeInterval)timeout
{
  // right, keep hold of the data item till we've finished the send
  [data retain];
  
  // right, we want to do this but put it on the send queue
  dispatch_async(send_queue, ^{
    const void *buf = [data bytes];
    unsigned size = [data length];
    
    int result = send(socketfd, buf, size, 0);
    if (result == -1)
    {
      NSLog(@"send failed: %s", strerror(errno));
    }
    
    [data release];
  });
  
  return YES;
}

@end
