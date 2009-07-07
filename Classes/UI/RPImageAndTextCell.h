//
//  RPImageAndTextCell.h
//  Rapport
//
//  Created by Matt Wright on 30/08/2008.
//  Copyright 2008 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RPImageAndTextCell : NSTextFieldCell {

@private
  NSImage  *image;
}

- (void)setImage:(NSImage *)anImage;
- (NSImage *)image;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end
