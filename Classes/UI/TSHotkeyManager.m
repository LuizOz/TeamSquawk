//
//  TSHotkeyManager.m
//  TeamSquawk
//
//  Created by Matt Wright on 09/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSHotkeyManager.h"

OSStatus hotkeyManagerHotkeyPressedEvent(EventHandlerCallRef nextHandler, EventRef anEvent, void *userData)
{
  NSDictionary *hotkeys = (NSDictionary*)userData;
  
  EventHotKeyID hotKeyId;
  GetEventParameter(anEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(EventHotKeyID), NULL, &hotKeyId);
  
  TSHotkey *hotkey = [hotkeys objectForKey:[NSNumber numberWithUnsignedInt:hotKeyId.id]];
  
  if ([hotkey target] && [[hotkey target] respondsToSelector:@selector(hotkeyPressed:)])
  {
    [[hotkey target] hotkeyPressed:hotkey];
  }

  return noErr;
}

OSStatus hotkeyManagerHotkeyReleasedEvent(EventHandlerCallRef nextHandler, EventRef anEvent, void *userData)
{
  NSDictionary *hotkeys = (NSDictionary*)userData;
  
  EventHotKeyID hotKeyId;
  GetEventParameter(anEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(EventHotKeyID), NULL, &hotKeyId);
  
  TSHotkey *hotkey = [hotkeys objectForKey:[NSNumber numberWithUnsignedInt:hotKeyId.id]];
  
  if ([hotkey target] && [[hotkey target] respondsToSelector:@selector(hotkeyReleased:)])
  {
    [[hotkey target] hotkeyReleased:hotkey];
  }
  
  return noErr;
}

static TSHotkeyManager *globalHotkeyManager = nil;

@implementation TSHotkey

@synthesize target;
@synthesize modifiers;
@synthesize keyCode;
@synthesize hotkeyID;
@synthesize context;

- (id)init
{
  if (self = [super init])
  {
    target = nil;
    context = nil;
  }
  return self;
}

- (void)dealloc
{
  [context release];
  [target release];
  [super dealloc];
}

- (EventHotKeyRef*)hotkeyRef
{
  return &hotkeyRef;
}

@end

@implementation TSHotkeyManager

+ (id)globalManager
{
  if (globalHotkeyManager == nil)
  {
    globalHotkeyManager = [[TSHotkeyManager alloc] init];
  }
  return globalHotkeyManager;
}

- (id)init
{
  if (self = [super init])
  {
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyPressed;
    
    hotkeys = [[NSMutableDictionary alloc] init];
    nextHotkeyID = 0;

    // register the pressed event handler
    InstallApplicationEventHandler(&hotkeyManagerHotkeyPressedEvent, 1, &eventType, hotkeys, NULL);
    
    // now register the released handler
    eventType.eventKind = kEventHotKeyReleased;
    InstallApplicationEventHandler(&hotkeyManagerHotkeyReleasedEvent, 1, &eventType, hotkeys, NULL);
  }
  return self;
}

- (void)dealloc
{
  for (TSHotkey *hotkey in hotkeys)
  {
    [self removeHotkey:hotkey];
  }
  
  [hotkeys release];
  [super dealloc];
}

- (unsigned int)nextHotkeyID
{
  return ++nextHotkeyID;
}

- (NSMutableDictionary*)hotkeys
{
  return hotkeys;
}

- (void)addHotkey:(TSHotkey*)hotkey
{
  EventHotKeyID hotkeyID;
  hotkeyID.id = [hotkey hotkeyID];
  
  OSStatus err = RegisterEventHotKey([hotkey keyCode], [hotkey modifiers], hotkeyID, GetApplicationEventTarget(), 0, [hotkey hotkeyRef]);
  if (err != noErr)
  {
    NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
    [[NSException exceptionWithName:@"TSHotkeyManager" reason:[error localizedDescription] userInfo:nil] raise];
    return;
  }
  
  [hotkeys setObject:hotkey forKey:[NSNumber numberWithUnsignedInt:[hotkey hotkeyID]]];
}

- (void)removeHotkey:(TSHotkey*)hotkey
{
  OSStatus err = UnregisterEventHotKey(*[hotkey hotkeyRef]);
  if (err != noErr)
  {
    NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
    [[NSException exceptionWithName:@"TSHotkeyManager" reason:[error localizedDescription] userInfo:nil] raise];
    return;
  }
  [hotkeys removeObjectForKey:[NSNumber numberWithUnsignedInt:[hotkey hotkeyID]]];
}

- (void)removeAllHotkeys
{
  NSMutableDictionary *removals = [hotkeys copy];
  for (TSHotkey *hotkey in [removals allValues])
  {
    [self removeHotkey:hotkey];
  }
  [removals release];
}

@end
