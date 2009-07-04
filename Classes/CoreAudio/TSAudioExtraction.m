//
//  TSAudioExtraction.m
//  TeamSquawk
//
//  Created by Matt Wright on 02/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSAudioExtraction.h"
#import <MTCoreAudio/MTCoreAudio.h>

@interface NSString (Extras)

+ (NSString *)stringWithFSRef:(const FSRef *)aFSRef;
- (BOOL)getFSRef:(FSRef *)aFSRef;

@end

@implementation NSString (Extras)

+ (NSString *)stringWithFSRef:(const FSRef *)aFSRef
{
  CFURLRef theURL = CFURLCreateFromFSRef( kCFAllocatorDefault, aFSRef );
  NSString* thePath = [(NSURL *)theURL path];
  CFRelease ( theURL );
  return thePath;
}

- (BOOL)getFSRef:(FSRef *)aFSRef
{
  return FSPathMakeRef( (const UInt8 *)[self fileSystemRepresentation], aFSRef, NULL ) == noErr;
}

@end

@implementation TSAudioExtraction

-(id)init
{
  if (self = [super init])
  {
    // nothing
  }
	return self;
}

- (id)initWithFilename:(NSString*)filename
{
  if (self = [self init])
  {
    OSStatus err = [self openWithFilename:filename];
    if (err != noErr)
    {
      NSLog(@"openWithFilename: failed, err %d.", err);
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)initWithFilename:(NSString*)filename withInternalCache:(BOOL)cache
{
  if (self = [self init])
  {
    OSStatus err = [self openWithFilename:filename withInternalCache:cache];
    if (err != noErr)
    {
      NSLog(@"openWithFilename:withInternalCache: failed, err %d.", err);
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)close
{
  ExtAudioFileDispose(extAudioRef);
  AudioFileClose(audioFileID);
  [audioFile release];
}

-(void)dealloc
{
  [super dealloc];
}


OSStatus ExtractionAudioFileRead (void *inClientData, SInt64 inPosition, UInt32 requestCount, void *buffer, UInt32 *actualCount)
{
  NSData *audio = inClientData;
  
  ByteCount requestOffset = inPosition + requestCount;
  ByteCount availableBytes = [audio length] - inPosition;
  
  if (requestOffset > [audio length]) {
    *actualCount = availableBytes;
  } else {
    *actualCount = requestCount;
  }
  [audio getBytes:buffer range:NSMakeRange(inPosition,*actualCount)];
  return noErr;
}

SInt64 ExtractionFileSize (void *inClientData)
{
  return [(NSData*)inClientData length];
}

- (OSStatus)openWithFilename:(NSString*)filename
{
  return [self openWithFilename:filename withInternalCache:NO];
}

- (OSStatus)openWithFilename:(NSString*)filename withInternalCache:(BOOL)cache
{
  if (cache)
  {
    audioFile = [[NSData alloc] initWithContentsOfFile:filename];
    OSErr err = AudioFileOpenWithCallbacks(audioFile, ExtractionAudioFileRead, NULL, ExtractionFileSize, NULL, 0, &audioFileID);
    if (err != noErr)
    {
      return err;
    }
    
    err = ExtAudioFileWrapAudioFileID(audioFileID, NO, &extAudioRef);
    if (err != noErr)
    {
      return err;
    }
    return err;
  }
  else
  {
    NSURL *url = [NSURL fileURLWithPath:filename];
    
    if (url)
    {
      OSErr err = ExtAudioFileOpenURL((CFURLRef)url, &extAudioRef);
      return err;
    }
    
    return -1;
  }
}

- (MTCoreAudioStreamDescription*)fileStreamDescription
{
  AudioStreamBasicDescription asbd;
  UInt32 size = sizeof(AudioStreamBasicDescription);
  OSErr err = ExtAudioFileGetProperty(extAudioRef, kExtAudioFileProperty_FileDataFormat, &size, &asbd);
  if (err != noErr)
  {
    NSLog(@"ExtAudioFileGetProperty returned %d. %@", err, [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]);
    return nil;
  }
  
  return [MTCoreAudioStreamDescription streamDescriptionWithAudioStreamBasicDescription:asbd];
}

- (MTCoreAudioStreamDescription*)outputStreamDescription
{
  return outputStreamDescription;
}

- (void)setOutputStreamDescription:(MTCoreAudioStreamDescription*)outputStreamDesc
{
  [outputStreamDescription autorelease];
  outputStreamDescription = [outputStreamDesc retain];
  
  AudioStreamBasicDescription asbd = [outputStreamDescription audioStreamBasicDescription];
  UInt32 size = sizeof(AudioStreamBasicDescription);
  
  OSErr err = ExtAudioFileSetProperty(extAudioRef, kExtAudioFileProperty_ClientDataFormat, size, &asbd);
  if (err != noErr)
  {
    NSLog(@"ExtAudioFileSetProperty returned %d. %@", err, [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]);
    [[NSException exceptionWithName:@"TSAudioExtractionStreamDescriptionError" reason:[[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil] localizedDescription] userInfo:nil] raise];
  }
}

- (AudioBufferList*)extractNumberOfFrames:(unsigned long)frames
{
  AudioBufferList *buffer = MTAudioBufferListNew([outputStreamDescription channelsPerFrame], frames, !([outputStreamDescription formatFlags] & kAudioFormatFlagIsNonInterleaved));
  
  UInt32 numberOfFrames = frames;
  OSErr err = ExtAudioFileRead(extAudioRef, &numberOfFrames, buffer);
  if (err != noErr)
  {
    NSLog(@"ExtAudioFileRead returned %d. %@", err, [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]);
    MTAudioBufferListDispose(buffer);
    
    return nil;
  }
  
  return buffer;
}

-(NSData*)extractWithDuration:(int)seconds error:(NSError**)error
{
  OSErr err;
  AudioStreamBasicDescription sourceStreamDescription, destStreamDescription;
  
  UInt32 size = sizeof(sourceStreamDescription);
  err = ExtAudioFileGetProperty(extAudioRef, kExtAudioFileProperty_FileDataFormat, &size, &sourceStreamDescription);
  
	if (err != noErr)
	{
    if (error)
    {
      *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
    }
		return nil;
	}
	
  // Convert the ASBD to return interleaved 16-bit PCM instead of non-interleaved Float32.
  destStreamDescription.mFormatID = kAudioFormatLinearPCM;
  destStreamDescription.mSampleRate = 44100;
  destStreamDescription.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
  destStreamDescription.mBitsPerChannel = sizeof (float) * 8;
  destStreamDescription.mChannelsPerFrame = 1; // override this, I want mono
  destStreamDescription.mBytesPerFrame = sizeof(float) * destStreamDescription.mChannelsPerFrame;
  destStreamDescription.mBytesPerPacket = destStreamDescription.mBytesPerFrame;
  destStreamDescription.mFramesPerPacket = 1;
	
  size = sizeof(destStreamDescription);
  err = ExtAudioFileSetProperty(extAudioRef, kExtAudioFileProperty_ClientDataFormat, size, &destStreamDescription);
  
  if (err != noErr)
	{
    if (error)
    {
      *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
    }
    return nil;
	}
	
  // Work out the number of frames we need for fingerprinting
  // Docs say we only need 135 seconds of audio, we'll be sure and get 140
  int numFrames = destStreamDescription.mSampleRate * 140;
  AudioBufferList *bufferList = MTAudioBufferListNew(2, numFrames, TRUE);
  
  err = ExtAudioFileRead(extAudioRef, (UInt32*)&numFrames, bufferList);
  if (err != noErr)
  {
    MTAudioBufferListDispose(bufferList);
    if (error)
    {
      *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
    }
    return nil;
  }
  
  NSData *extractedData = [NSData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
  
  MTAudioBufferListDispose(bufferList);
  
  return extractedData;
}

- (unsigned long)position
{
  SInt64 position;
  ExtAudioFileTell(extAudioRef, &position);
  
  return position;
}

- (unsigned long)numOfFrames
{
  OSErr err;
  UInt32 size = sizeof(numFramesFile);
  
  err = ExtAudioFileGetProperty(extAudioRef, kExtAudioFileProperty_FileLengthFrames, &size, &numFramesFile);
  return numFramesFile;
}

@end
