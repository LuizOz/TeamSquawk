//
//  SpeexDecoder.m
//  TeamSquawk
//
//  Created by Matt Wright on 01/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "SpeexDecoder.h"


@implementation SpeexDecoder

- (id)init
{
  if (self = [super init])
  {
    speexState = speex_encoder_init(&speex_nb_mode);
    speex_bits_init(&speexBits);
  }
  return self;
}

- (void)dealloc
{
  speex_decoder_destroy(&speexState);
  speex_bits_destroy(&speexBits);
  [super dealloc];
}

@end
