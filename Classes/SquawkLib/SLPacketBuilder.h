//
//  SLPacketBuilder.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SLPacketBuilder : NSObject {

}

+ (id)packetBuilder;
- (id)init;

#pragma mark Login

- (NSData*)buildLoginPacketWithSequenceID:(unsigned int)sequenceID
                               clientName:(NSString*)client 
                      operatingSystemName:(NSString*)osName
                       clientVersionMajor:(int)majorVersion
                       clientVersionMinor:(int)minorVersion
                             isRegistered:(BOOL)isRegistered
                                loginName:(NSString*)loginName
                            loginPassword:(NSString*)loginPassword
                            loginNickName:(NSString*)loginNickName;

- (NSData*)buildLoginResponsePacketWithConnectionID:(unsigned int)connectionID
                                           clientID:(unsigned int)clientID
                                         sequenceID:(unsigned int)sequenceID
                                          lastCRC32:(unsigned int)lastCRC32;

@end
