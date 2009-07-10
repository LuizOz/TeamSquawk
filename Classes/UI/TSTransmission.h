//
//  TSTransmission.h
//  TeamSquawk
//
//  Created by Matt Wright on 10/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MTCoreAudio/MTCoreAudio.h>
#import "speex/speex.h"

#import "SLConnection.h"
#import "SpeexEncoder.h"
#import "TSAudioConverter.h"

@interface TSTransmission : NSObject {
  SpeexEncoder *encoder;
  TSAudioConverter *converter;
  MTCoreAudioDevice *inputDevice;
  
  BOOL isTransmitting;  
  BOOL isVoiceActivated;
  
  NSLock *transmissionLock;
  
  NSThread *transmissionThread;
}

- (id)initWithConnection:(SLConnection*)connection bitrate:(unsigned int)bitrate voiceActivated:(BOOL)voiceActivated;
- (void)dealloc;

- (BOOL)isTransmitting;
- (void)setIsTransmitting:(BOOL)flag;

@end
