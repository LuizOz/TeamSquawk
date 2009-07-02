//
//  SpeexDecoder.h
//  TeamSquawk
//
//  Created by Matt Wright on 01/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <speex/speex.h>

@interface SpeexDecoder : NSObject {
  void *speexState;
  SpeexBits speexBits;
}

- (id)init;
- (void)dealloc;

@end
