//
//  RPImageAndTextCell.m
//  Rapport
//
//  Created by Matt Wright on 30/08/2008.
//  Copyright 2008 Matt Wright Consulting. All rights reserved.
//

#import "RPImageAndTextCell.h"


@implementation RPImageAndTextCell

- (void)dealloc {
  [image release];
  image = nil;
  [super dealloc];
}

- copyWithZone:(NSZone *)zone
{
  RPImageAndTextCell *cell = (RPImageAndTextCell *)[super copyWithZone:zone];
  cell->image = [image retain];
  return cell;
}

- (void)setImage:(NSImage *)anImage
{
  if (anImage != image)
  {
    [image release];
    image = [anImage retain];
  }
}

- (NSImage *)image
{
  return image;
}

- (NSRect)imageFrameForCellFrame:(NSRect)cellFrame
{
  if (image != nil)
  {
    NSRect imageFrame;
    imageFrame.size = [image size];
    imageFrame.origin = cellFrame.origin;
    imageFrame.origin.x += 3;
    imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
    return imageFrame;
  }
  else
    return NSZeroRect;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
  NSRect textFrame, imageFrame;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
  [super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
  NSRect textFrame, imageFrame;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
  [super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  if (image != nil)
  {
    NSSize  imageSize;
    NSRect  imageFrame;
    
    imageSize = [image size];
    NSDivideRect(cellFrame, &imageFrame, &cellFrame, 5 + imageSize.width, NSMinXEdge);
    if ([self drawsBackground])
    {
      [[self backgroundColor] set];
      NSRectFill(imageFrame);
    }
    imageFrame.origin.x += 3;
    imageFrame.size = imageSize;
    
    if ([controlView isFlipped])
      imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
    else
      imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
    
    [image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
  }
	
	NSMutableParagraphStyle *paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedStringValue]];
  
	[paraStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[mutableString addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange(0, [mutableString length])];
	
	NSRect drawRect = [mutableString boundingRectWithSize:NSZeroSize options:0];
	cellFrame.origin.y += (NSHeight(cellFrame) / 2) - (NSHeight(drawRect) / 2);
	cellFrame.size.height = drawRect.size.height;
	cellFrame.origin.x += 1;
	
	if ([self backgroundStyle] == NSBackgroundStyleDark)
	{
		NSColor *whiteColor = [NSColor whiteColor];
		[mutableString addAttribute:NSForegroundColorAttributeName value:whiteColor range:NSMakeRange(0, [mutableString length])];
	}
	
	[mutableString drawInRect:cellFrame];
  [mutableString release];
  [paraStyle release];
	
  //[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize
{
  NSSize cellSize = [super cellSize];
  cellSize.width += (image ? [image size].width : 0) + 3;
  return cellSize;
}

@end
