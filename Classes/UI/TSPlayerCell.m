//
//  TSPlayerCell.m
//  TeamSquawk
//
//  Created by Matt Wright on 07/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSPlayerCell.h"
#import "TSPlayer.h"

@implementation TSPlayerCell

+ (float)cellHeight
{
  return 32.0;
}

- (NSSize)cellSize
{
  return NSMakeSize(0, 32.0);
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{ 
  TSPlayer *player = [self objectValue];
  
  // draw the transmission logo
  {
    NSRect transmissionRect;
    NSImage *image;
    float opacity;
    
    if ([player isTalking])
    {
      image = [NSImage imageNamed:@"TransmitOrange"];
      opacity = 1.0;
    }
    else
    {
      image = [NSImage imageNamed:@"TransmitGray"];
      opacity = 0.25;
    }
    
    NSDivideRect(cellFrame, &transmissionRect, &cellFrame, [image size].width + 5, NSMaxXEdge);
    transmissionRect.origin.y -= ceil((transmissionRect.size.height - [image size].height) / 2);
    transmissionRect.origin.x += ceil((transmissionRect.size.width - [image size].width) / 2);

    if ([controlView isFlipped])
      transmissionRect.origin.y += ceil((cellFrame.size.height + transmissionRect.size.height) / 2);
    else
      transmissionRect.origin.y += ceil((cellFrame.size.height - transmissionRect.size.height) / 2);

    [image compositeToPoint:transmissionRect.origin operation:NSCompositeSourceOver fraction:opacity];
  }
  
  // draw the light
  {
    NSRect userLightRect;
    NSImage *image;
    
    if ([player isMuted])
    {
      image = [NSImage imageNamed:@"Mute"];
    }
    else if ([player isAway])
    {
      image = [NSImage imageNamed:@"Away"];
    }
    else if ([player hasMutedMicrophone])
    {
      image = [NSImage imageNamed:@"Orange"];
    }
    else if ([player isChannelCommander])
    {
      image = [NSImage imageNamed:@"Blue"];
    }
    else if ([player isServerAdmin])
    {
      image = [NSImage imageNamed:@"Purple"];
    }
    else
    {
      image = [NSImage imageNamed:@"Green"];
    }
    
    NSDivideRect(cellFrame, &userLightRect, &cellFrame, [image size].width + 5, NSMinXEdge);
    
    userLightRect.origin.y -= ceil((userLightRect.size.height - [image size].height) / 2);
    userLightRect.origin.x += ceil((userLightRect.size.width - [image size].width) / 2);
    
    if ([controlView isFlipped])
      userLightRect.origin.y += ceil((cellFrame.size.height + userLightRect.size.height) / 2);
    else
      userLightRect.origin.y += ceil((cellFrame.size.height - userLightRect.size.height) / 2);
    
    [image compositeToPoint:userLightRect.origin operation:NSCompositeSourceOver];
  }
  
  // draw the player name
  {
    NSMutableAttributedString *playerName = [[NSMutableAttributedString alloc] initWithString:[(TSPlayer*)[self objectValue] playerName]];
    NSMutableAttributedString *statusText;
    if ([(TSPlayer*)[self objectValue] isServerAdmin])
    {
      statusText = [[NSMutableAttributedString alloc] initWithString:@"Server Admin"];
    }
    else if ([(TSPlayer*)[self objectValue] isRegistered])
    {
      statusText = [[NSMutableAttributedString alloc] initWithString:@"Registered"];
    }
    else
    {
      statusText = [[NSMutableAttributedString alloc] initWithString:@"Unregistered"];
    }
    
    NSFont *playerNameFont = [NSFont labelFontOfSize:[NSFont systemFontSize]];
    [playerName addAttribute:NSFontAttributeName value:playerNameFont range:NSMakeRange(0, [playerName length])];
    
    NSFont *statusTextFont = [NSFont labelFontOfSize:[NSFont smallSystemFontSize]];
    [statusText addAttribute:NSFontAttributeName value:statusTextFont range:NSMakeRange(0, [statusText length])];
    
    NSColor *grayColor = [NSColor grayColor];
    [statusText addAttribute:NSForegroundColorAttributeName value:grayColor range:NSMakeRange(0, [statusText length])];
    
    NSRect playerNameDrawRect = [playerName boundingRectWithSize:NSZeroSize options:0];
    playerNameDrawRect.origin.y = cellFrame.origin.y;// + ceil((cellFrame.size.height - playerNameDrawRect.size.height) / 2);
    playerNameDrawRect.origin.x = cellFrame.origin.x + 3;
    
    NSRect statusTextDrawRect = [statusText boundingRectWithSize:NSZeroSize options:0];
    statusTextDrawRect.origin.y = cellFrame.origin.y;// + ceil((cellFrame.size.height - playerNameDrawRect.size.height) / 2);
    statusTextDrawRect.origin.x = cellFrame.origin.x + 3;
      
    float combinedTextHeight = playerNameDrawRect.size.height + statusTextDrawRect.size.height;
    statusTextDrawRect.origin.y = playerNameDrawRect.origin.y + playerNameDrawRect.size.height;
    
    playerNameDrawRect.origin.y += ceil((cellFrame.size.height - combinedTextHeight) / 2);
    statusTextDrawRect.origin.y += ceil((cellFrame.size.height - combinedTextHeight) / 2);
    
    if ([self backgroundStyle] == NSBackgroundStyleDark)
    {
      NSColor *whiteColor = [NSColor whiteColor];
      [playerName addAttribute:NSForegroundColorAttributeName value:whiteColor range:NSMakeRange(0, [playerName length])];
      [statusText addAttribute:NSForegroundColorAttributeName value:whiteColor range:NSMakeRange(0, [statusText length])];
    }
    
    [playerName drawInRect:playerNameDrawRect];
    [statusText drawInRect:statusTextDrawRect];
    
    [playerName release];
    [statusText release];
  }
}

@end
