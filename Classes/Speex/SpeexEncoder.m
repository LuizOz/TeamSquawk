//
//  SpeexEncoder.m
//  TeamSquawk
//
//  Created by Matt Wright on 01/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "SpeexEncoder.h"


@implementation SpeexEncoder

- (id)init
{
  return [self initWithMode:SpeexEncodeNarrowBandMode];
}

- (id)initWithMode:(SpeexEncodeMode)aMode
{
  if (self = [super init])
  {
    mode = aMode;
    if (aMode == SpeexEncodeNarrowBandMode)
    {
      speexState = speex_encoder_init(&speex_nb_mode);
    }
    else if (aMode == SpeexEncodeWideBandMode)
    {
      speexState = speex_encoder_init(&speex_wb_mode);
    }
    else if (aMode == SpeexEncodeUltraWideBandMode)
    {
      speexState = speex_encoder_init(&speex_uwb_mode);
    }
    else
    {
      [self release];
      return nil;
    }
    
    int sampleRate, on = 1;
    
    speex_bits_init(&speexBits);
    speex_encoder_ctl(speexState, SPEEX_GET_FRAME_SIZE, &frameSize);
    speex_encoder_ctl(speexState, SPEEX_GET_SAMPLING_RATE, &sampleRate);
    
    preprocessState = speex_preprocess_state_init(frameSize, sampleRate);
    speex_preprocess_ctl(preprocessState, SPEEX_PREPROCESS_SET_DENOISE, &on);
    speex_preprocess_ctl(preprocessState, SPEEX_PREPROCESS_SET_AGC, &on);
    speex_preprocess_ctl(preprocessState, SPEEX_PREPROCESS_SET_DEREVERB, &on);
    
    resamplerState = NULL;
    internalEncodeBuffer = (void*)malloc(frameSize * sizeof(short));
  }
  return self;
}

- (void)dealloc
{
  free(internalEncodeBuffer);
  speex_preprocess_state_destroy(preprocessState);
  speex_encoder_destroy(speexState);
  speex_bits_destroy(&speexBits);
  [super dealloc];
}

- (unsigned int)frameSize
{
  return frameSize;
}

- (float)sampleRate
{
  int sampleRate;
  speex_encoder_ctl(speexState, SPEEX_GET_SAMPLING_RATE, &sampleRate);
  
  return (float)sampleRate;
}

- (unsigned int)bitRate
{
  unsigned int bitrate;
  speex_encoder_ctl(speexState, SPEEX_GET_BITRATE, &bitrate);
  return bitrate;
}

- (void)setBitrate:(unsigned int)bitrate
{
  speex_encoder_ctl(speexState, SPEEX_SET_BITRATE, &bitrate);
}

- (unsigned int)inputSampleRate
{
  return inputSampleRate;
}

- (void)setInputSampleRate:(unsigned int)sampleRate
{
  inputSampleRate = sampleRate;
  
  if (resamplerState)
  {
    speex_resampler_destroy(resamplerState);
    resamplerState = NULL;
  }
  
  if (inputSampleRate != [self sampleRate])
  {
    int error;
    resamplerState = speex_resampler_init(1, inputSampleRate, [self sampleRate], 0, &error);
  }
}

- (MTCoreAudioStreamDescription*)encoderStreamDescription
{
  MTCoreAudioStreamDescription *desc = [MTCoreAudioStreamDescription nativeStreamDescription];
  // set format
  [desc setFormatID:kAudioFormatLinearPCM];
  // set flags
  [desc setFormatFlags:kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked|kAudioFormatFlagsNativeEndian];
  // 16 bit audio
  [desc setBitsPerChannel:8*sizeof(short)];
  // mono
  [desc setChannelsPerFrame:1];
  // bitrate
  [desc setSampleRate:[self inputSampleRate]];
  [desc setBytesPerFrame:sizeof(short)*[desc channelsPerFrame]];
  [desc setBytesPerPacket:[desc bytesPerFrame]];
    
  return desc;
}

- (void)resetEncoder
{
  speex_bits_reset(&speexBits);
}

- (void)encodeAudioBufferList:(AudioBufferList*)audioBufferList
{
  if (inputSampleRate == [self sampleRate])
  {
    speex_preprocess_run(preprocessState, audioBufferList->mBuffers[0].mData);
    speex_encode_int(speexState, audioBufferList->mBuffers[0].mData, &speexBits);
  }
  else
  {
    if (resamplerState)
    {
      unsigned int inBytes = (audioBufferList->mBuffers[0].mDataByteSize / sizeof(short)), outBytes = [self frameSize];
      
      speex_resampler_process_int(resamplerState, 0, audioBufferList->mBuffers[0].mData, &inBytes, internalEncodeBuffer, &outBytes);
      speex_preprocess_run(preprocessState, internalEncodeBuffer);
      speex_encode_int(speexState, internalEncodeBuffer, &speexBits);
    }
    else
    {
      [[NSException exceptionWithName:@"NoResampler" reason:@"No resampler was initialised, have you called setInputSampleRate: ?" userInfo:nil] raise];
    }
  }
}

- (NSData*)encodedData
{
  // find out how many bits we're gonna have to write
  int nbytes = speex_bits_nbytes(&speexBits);
  char *buffer = (char*)malloc(nbytes);
  
  nbytes = speex_bits_write(&speexBits, buffer, nbytes);
  
  // copy the encoded data into an NSData
  return [NSData dataWithBytesNoCopy:buffer length:nbytes freeWhenDone:YES];  
}

@end
