//
//  TSController.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SLConnection.h"
#import "TSCoreAudioPlayer.h"
#import "TSAudioConverter.h"

#import "SpeexEncoder.h"
#import "SpeexDecoder.h"

@interface TSController : NSObject {
  SLConnection *connection;
  
  TSCoreAudioPlayer *player;
  TSAudioConverter *converter;
  
  SpeexDecoder *speex;
  SpeexEncoder *speexEncoder;
}

@end
