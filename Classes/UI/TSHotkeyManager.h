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

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

@interface TSHotkey : NSObject {
  id target;
  
  unsigned int modifiers;
  unsigned int keyCode;
  unsigned int hotkeyID;
  
  EventHotKeyRef hotkeyRef;
  id context;
}

@property (retain) id target;
@property (assign) unsigned int modifiers;
@property (assign) unsigned int keyCode;
@property (assign) unsigned int hotkeyID;
@property (readonly) EventHotKeyRef *hotkeyRef;
@property (assign) id context;

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
- (NSMutableDictionary*)hotkeys;
- (void)addHotkey:(TSHotkey*)hotkey;
- (void)removeHotkey:(TSHotkey*)hotkey;
- (void)removeAllHotkeys;

@end

@interface NSObject (HotkeyTarget)

- (void)hotkeyPressed:(TSHotkey*)hotkey;
- (void)hotkeyReleased:(TSHotkey*)hotkey;

@end

