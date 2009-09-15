/*
 * TeamSquawk: An open-source TeamSpeak client for Mac OS X
 *
 * Copyright (c) 2009 Matt Wright
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

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
