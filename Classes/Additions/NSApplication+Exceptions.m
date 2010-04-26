//
//  NSApplication+Exceptions.m
//  TeamSquawk
//
//  Created by Matt Wright on 21/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "NSApplication+Exceptions.h"
#import <MWFramework/MWFramework.h>

@implementation NSApplication (Exceptions)

- (void)reportException:(NSException *)anException
{
  NSString *stackTraceLog = [NSString stringWithFormat:@"Exception:\n\n%@\n\nStack Trace:\n\n%@",
                             anException,
                             MWStackTraceFromException(anException)];
  
  NSAlert *alert = [NSAlert alertWithMessageText:@"An unhandled exception occured"
                                   defaultButton:@"OK"
                                 alternateButton:@"Send Report"
                                     otherButton:nil
                       informativeTextWithFormat:@"An unhandled exception occured, it is displayed below. To aid debugging your crash, you are encouraged to press the \"Send Report\" button to transmit this exception to the author. Thank you."];
  
  NSTextView *stackTraceView = [[[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)] autorelease];
  [stackTraceView setString:stackTraceLog];
  [stackTraceView setHorizontallyResizable:YES];
  [stackTraceView setVerticallyResizable:YES];
  [stackTraceView sizeToFit];
  
  NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)] autorelease];
  [scrollView setDocumentView:stackTraceView];
  [scrollView setBorderType:NSBezelBorder];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setHasHorizontalRuler:YES];
  
  [alert setAccessoryView:scrollView];
  [alert beginSheetModalForWindow:[self keyWindow]
                    modalDelegate:self
                   didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                      contextInfo:[stackTraceLog retain]];
}

- (void)alertDidEnd:(NSAlert*)alert returnCode:(int)returnCode contextInfo:(void*)context
{
  [[alert window] orderOut:self];
  
  if (returnCode == 0)
  {
    [[[UKCrashReporter alloc] initWithLogString:(NSString*)context] autorelease];
    [(NSException*)context release];
  }
}

@end
