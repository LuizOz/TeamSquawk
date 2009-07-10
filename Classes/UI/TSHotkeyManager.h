//
//  TSHotkeyManager.h
//  TeamSquawk
//
//  Created by Matt Wright on 09/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

@interface TSHotkey : NSObject {
  id target;
  
  unsigned int modifiers;
  unsigned int keyCode;
  unsigned int hotkeyID;
  
  EventHotKeyRef hotkeyRef;
}

@property (retain) id target;
@property (assign) unsigned int modifiers;
@property (assign) unsigned int keyCode;
@property (assign) unsigned int hotkeyID;
@property (readonly) EventHotKeyRef *hotkeyRef;

- (id)init;
- (void)dealloc;
- (EventHotKeyRef*)hotkeyRef;

@end


@interface TSHotkeyManager : NSObject {
  NSMutableDictionary *hotkeys;
  unsigned int nextHotkeyID;
}

+ (id)globalManager;
- (id)init;
- (void)dealloc;
- (unsigned int)nextHotkeyID;
- (void)addHotkey:(TSHotkey*)hotkey;
- (void)removeHotkey:(TSHotkey*)hotkey;

@end

@interface NSObject (HotkeyTarget)

- (void)hotkeyPressed:(TSHotkey*)hotkey;
- (void)hotkeyReleased:(TSHotkey*)hotkey;

@end

