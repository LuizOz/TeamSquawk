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

#import "TSPlayerCell.h"
#import "TSPlayer.h"

@implementation TSPlayerCell

+ (float)cellHeight
{
  return 32.0;
}

+ (float)smallCellHeight
{
  return 18.0;
}

- (NSSize)cellSize
{
  return NSMakeSize(0, 32.0);
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{ 
  TSPlayer *player = [self objectValue];
  BOOL small = [[NSUserDefaults standardUserDefaults] boolForKey:@"SmallPlayers"];
  
  // draw the transmission logo
  {
    NSRect transmissionRect;
    NSImage *image;
    float opacity;
    
    if ([player isLocallyMuted])
    {
      image = [NSImage imageNamed:@"TransmitGray"];
      opacity = 1.0;
    }
    else if ([player isTalking] && [player isWhispering])
    {
      image = [NSImage imageNamed:@"TransmitRed"];
      opacity = 1.0;
    }
    else if ([player isTalking])
    {
      image = [NSImage imageNamed:@"TransmitOrange"];
      opacity = 1.0;
    }
    else
    {
      image = [NSImage imageNamed:@"TransmitGray"];
      opacity = 0.25;
    }
    
    // gah bit of a cheat, draw at 16x16 if we're small or 24x24 if we're large
    NSSize compositeSize = (small ? NSMakeSize(17, 17) : [image size]);
    
    NSDivideRect(cellFrame, &transmissionRect, &cellFrame, compositeSize.width + 5, NSMaxXEdge);
    transmissionRect.origin.x += ceil((transmissionRect.size.width - compositeSize.width) / 2);

    BOOL oldFlipped = [image isFlipped];
    [image setFlipped:[controlView isFlipped]];
    
    transmissionRect.size = compositeSize;    
    transmissionRect.origin.y += ceil((cellFrame.size.height - transmissionRect.size.height) / 2);

    [image drawInRect:transmissionRect fromRect:NSMakeRect(0, 0, [image size].width, [image size].height) operation:NSCompositeSourceOver fraction:opacity];
    [image setFlipped:oldFlipped];
  }
  
  // draw the light
  {
    NSRect userLightRect;
    NSImage *image;
    
    if ([player hasMutedSpeakers])
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
    else if ([(TSPlayer*)[self objectValue] isChannelAdmin])
    {
      statusText = [[NSMutableAttributedString alloc] initWithString:@"Channel Admin"];
    }
    else if ([(TSPlayer*)[self objectValue] isChannelOperator])
    {
      statusText = [[NSMutableAttributedString alloc] initWithString:@"Operator"];
    }
    else if ([(TSPlayer*)[self objectValue] isChannelVoice])
    {
      statusText = [[NSMutableAttributedString alloc] initWithString:@"Voice"];
    }
    else if ([(TSPlayer*)[self objectValue] isRegistered])
    {
      statusText = [[NSMutableAttributedString alloc] initWithString:@"Registered"];
    }
    else
    {
      statusText = [[NSMutableAttributedString alloc] initWithString:@"Unregistered"];
    }
    
    float playerFontSize = (small ? [NSFont smallSystemFontSize] : [NSFont systemFontSize]);
    NSFont *playerNameFont = [NSFont labelFontOfSize:playerFontSize];
    [playerName addAttribute:NSFontAttributeName value:playerNameFont range:NSMakeRange(0, [playerName length])];
    
    NSFont *statusTextFont = [NSFont labelFontOfSize:[NSFont smallSystemFontSize]];
    [statusText addAttribute:NSFontAttributeName value:statusTextFont range:NSMakeRange(0, [statusText length])];
    
    NSColor *grayColor = [NSColor grayColor];
    [statusText addAttribute:NSForegroundColorAttributeName value:grayColor range:NSMakeRange(0, [statusText length])];
    
    NSRect playerNameDrawRect = [playerName boundingRectWithSize:NSZeroSize options:0];
    NSRect statusTextDrawRect = [statusText boundingRectWithSize:NSZeroSize options:0];
    
    if ([self backgroundStyle] == NSBackgroundStyleDark)
    {
      NSColor *whiteColor = [NSColor whiteColor];
      [playerName addAttribute:NSForegroundColorAttributeName value:whiteColor range:NSMakeRange(0, [playerName length])];
      [statusText addAttribute:NSForegroundColorAttributeName value:whiteColor range:NSMakeRange(0, [statusText length])];
    }
    
    if (small)
    {
      playerNameDrawRect.origin.y = cellFrame.origin.y + ceil((cellFrame.size.height - playerNameDrawRect.size.height) / 2);
      playerNameDrawRect.origin.x = cellFrame.origin.x + 3;
    }
    else
    {
      playerNameDrawRect.origin.y = cellFrame.origin.y;// + ceil((cellFrame.size.height - playerNameDrawRect.size.height) / 2);
      playerNameDrawRect.origin.x = cellFrame.origin.x + 3;
      
      statusTextDrawRect.origin.y = cellFrame.origin.y;// + ceil((cellFrame.size.height - playerNameDrawRect.size.height) / 2);
      statusTextDrawRect.origin.x = cellFrame.origin.x + 3;
      
      float combinedTextHeight = playerNameDrawRect.size.height + statusTextDrawRect.size.height;
      statusTextDrawRect.origin.y = playerNameDrawRect.origin.y + playerNameDrawRect.size.height;
      
      playerNameDrawRect.origin.y += ceil((cellFrame.size.height - combinedTextHeight) / 2);
      statusTextDrawRect.origin.y += ceil((cellFrame.size.height - combinedTextHeight) / 2);

      [statusText drawInRect:statusTextDrawRect];
    }
    
    [playerName drawInRect:playerNameDrawRect];
    
    [playerName release];
    [statusText release];
  }
}

@end
