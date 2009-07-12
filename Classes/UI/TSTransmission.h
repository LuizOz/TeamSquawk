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
  MTCoreAudioStreamDescription *inputDeviceStreamDescription;
  MTByteBuffer *fragmentBuffer;
  SLConnection *connection;
  
  NSArray *whisperRecipients;
  BOOL isTransmitting;  
  BOOL isVoiceActivated;
  BOOL isWhispering;
  unsigned int packetCount;
  unsigned int transmissionCount;
  unsigned short codec;
  
  NSLock *transmissionLock;
  NSThread *transmissionThread;
}

@property (retain) NSArray *whisperRecipients;
@property (assign) BOOL isWhispering;

- (id)initWithConnection:(SLConnection*)connection codec:(unsigned short)codec voiceActivated:(BOOL)voiceActivated;
- (void)dealloc;

- (BOOL)isTransmitting;
- (void)setIsTransmitting:(BOOL)flag;
- (void)close;

- (unsigned short)codec;
- (void)setCodec:(unsigned short)codec;

@end
