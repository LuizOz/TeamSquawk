//
//  SLConnection.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AsyncUdpSocket.h"
#import "AsyncUdpSocket+Extras.h"

#define PERMS_8BYTE                         0x00
#define PERMS_10BYTE                        0x01

#define PERMS_10BYTE_MISC_BYTE              0x09
#define PERMS_10BYTE_REVOKE_BYTE            0x07
#define PERMS_10BYTE_GRANT_BYTE             0x06
#define PERMS_10BYTE_CHANEDIT_BYTE          0x05
#define PERMS_10BYTE_CHAN_BYTE              0x04
#define PERMS_10BYTE_ADMIN_BYTE             0x03

#define PERMS_8BYTE_MISC_BYTE               0x06
#define PERMS_8BYTE_REVOKE_BYTE             0x04
#define PERMS_8BYTE_GRANT_BYTE              0x03
#define PERMS_8BYTE_CHANEDIT_BYTE           0x02
#define PERMS_8BYTE_CHAN_BYTE               0x01
#define PERMS_8BYTE_ADMIN_BYTE              0x00

#define PERMS_MISC_CHANCOMMANDER_BYTE5      0x80
#define PERMS_MISC_CHANKICK_BYTE5           0x40
#define PERMS_MISC_SERVERKICK_BYTE5         0x20
#define PERMS_MISC_TEXTPLAYER_BYTE5         0x10
#define PERMS_MISC_TEXTCHANALL_BYTE5        0x08
#define PERMS_MISC_TEXTCHANOWN_BYTE5        0x04
#define PERMS_MISC_TEXTALL_BYTE5            0x02

#define PERMS_GRANT_CA_BYTE                 0x04
#define PERMS_GRANT_AUTOOP_BYTE             0x08
#define PERMS_GRANT_OP_BYTE                 0x10
#define PERMS_GRANT_AUTOVOICE_BYTE          0x20
#define PERMS_GRANT_VOICE_BYTE              0x40
#define PERMS_GRANT_REGISTER_BYTE           0x80

#define PERMS_REVOKE_CA_BYTE                0x02
#define PERMS_REVOKE_AUTOOP_BYTE            0x04
#define PERMS_REVOKE_OP_BYTE                0x08
#define PERMS_REVOKE_AUTOVOICE_BYTE         0x10
#define PERMS_REVOKE_VOICE_BYTE             0x20
#define PERMS_REVOKE_REGISTER_BYTE          0x40

#define PERMS_CHAN_JOINREG_BYTE             0x02
#define PERMS_CHAN_CREATEREG_BYTE           0x04
#define PERMS_CHAN_CREATEUNREG_BYTE         0x08
#define PERMS_CHAN_CREATEDEF_BYTE           0x10
#define PERMS_CHAN_CREATESUB_BYTE           0x20
#define PERMS_CHAN_CREATEMOD_BYTE           0x40
#define PERMS_CHAN_DELETE_BYTE              0x80

#define PERMS_CHANEDIT_NAME_BYTE            0x01
#define PERMS_CHANEDIT_PWD_BYTE             0x02
#define PERMS_CHANEDIT_TOPIC_BYTE           0x04
#define PERMS_CHANEDIT_DESC_BYTE            0x08
#define PERMS_CHANEDIT_ORDER_BYTE           0x10
#define PERMS_CHANEDIT_MAXU_BYTE            0x20
#define PERMS_CHANEDIT_CODEC_BYTE           0x40
#define PERMS_CHANEDIT_CHNOPWD_BYTE         0x80

#define PERMS_ADMIN_MOVEPLAYER_BYTE         0x02
#define PERMS_ADMIN_BANIP_BYTE              0x01

typedef enum {
  SLCodecSpeex_3_4 = 0x05,
  SLCodecSpeex_5_2 = 0x06,
  SLCodecSpeex_7_2 = 0x07,
  SLCodecSpeex_9_3 = 0x08,
  SLCodecSpeex_12_3 = 0x09,
  SLCodecSpeex_16_3 = 0x0a,
  SLCodecSpeex_19_5 = 0x0b,
  SLCodecSpeex_25_9 = 0x0c,
} SLAudioCodecType;

enum {
  SLConnectionErrorTimedOut = 1,
  SLConnectionErrorPingTimeout = 2,
  SLConnectionErrorBadLogin = 3,
  SLConnectionErrorSelfLeft = 4,
};

typedef enum {
  SLConnectionAnonymousPlayer = 0x00,
  SLConnectionServerAdmin = 0x01,
  SLConnectionRegisteredPlayer = 0x04,
} SLConnectionExtendedFlags;

typedef enum {
  SLConnectionChannelAdmin = 0x01,
  SLConnectionVoice = 0x02,
  SLConnectionOperator = 0x04,
} SLConnectionChannelPrivFlags;

typedef enum {
  SLConnectionPrivAdded = YES,
  SLConnectionPrivRemoved = NO,
} SLConnectionPrivChange;

typedef enum {
  SLConnectionPermissionMisc = 0x00,
  SLConnectionPermissionRevoke = 0x01,
  SLConnectionPermissionGrant = 0x02,
  SLConnectionPermissionChanEdit = 0x03,
  SLConnectionPermissionChan = 0x04,
  SLConnectionPermissionAdmin = 0x05,
} SLConnectionPermissionType;

@interface SLConnection : NSObject {
  AsyncUdpSocket *socket;
  NSThread *connectionThread;
  NSRecursiveLock *sendReceiveLock;
  
  NSTimer *pingTimer;
  NSTimer *connectionTimer;
  NSMutableData *fragments;

  unsigned int connectionID;
  unsigned int clientID;
  
  unsigned int connectionSequenceNumber;
  unsigned int standardSequenceNumber;
  
  unsigned int serverConnectionSequenceNumber;
  unsigned int serverStandardSequenceNumber;
  
  unsigned short audioSequenceCounter;
  
  int clientMajorVersion, clientMinorVersion;
  NSString *clientName;
  NSString *clientOperatingSystem;
  
  BOOL isDisconnecting;
  BOOL hasFinishedDisconnecting;
  BOOL pendingReceive;
  unsigned int pingReplysPending;
  
  // permissions
  unsigned char channelAdminPermissions[8];
  unsigned char operatorPemissions[8];
  unsigned char voicePermissions[8];
  unsigned char anonymousPermissions[8];
  
  unsigned char serverAdminPermissions[10];
  unsigned char registeredPermissions[10];
  
  id delegate;
}

@property (assign) id delegate;
@property (retain) NSString *clientName;
@property (retain) NSString *clientOperatingSystem;
@property (assign) int clientMajorVersion;
@property (assign) int clientMinorVersion;
@property (readonly) unsigned int clientID;

+ (unsigned int)bitrateForCodec:(unsigned int)codec;
- (id)initWithHost:(NSString*)host withError:(NSError**)error;
- (id)initWithHost:(NSString*)host withPort:(short)port withError:(NSError**)error;
- (void)dealloc;

#pragma mark Threading

- (void)spawnThread;
- (void)initSocketOnThread;
- (void)sendData:(NSData*)data;
- (void)queueReceiveData;
- (void)waitForSend;
- (void)queueReceiveDataAndWait;

#pragma mark Commands

- (void)beginAsynchronousLogin:(NSString*)username password:(NSString*)password nickName:(NSString*)nickName isRegistered:(BOOL)isRegistered;
- (void)disconnect;

#pragma mark Incoming Events

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port;
- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error;
- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error;

#pragma mark Permissions

- (void)parsePermissionData:(NSData*)data;
- (BOOL)checkPermission:(unsigned char)permission permissionType:(SLConnectionPermissionType)type forExtendedFlags:(SLConnectionExtendedFlags)extendedFlags andChannelPrivFlags:(SLConnectionChannelPrivFlags)channelPrivFlags;

#pragma mark Ping Timer

- (void)pingTimer:(NSTimer*)timer;
- (void)connectionTimer:(NSTimer*)timer;

#pragma mark Text Message

- (void)sendTextMessage:(NSString*)message toPlayer:(unsigned int)playerID;

#pragma mark Voice Message

- (void)sendVoiceMessage:(NSData*)audioCodecData frames:(unsigned char)frames packetCount:(unsigned short)packetCount transmissionID:(unsigned short)transmissionID codec:(SLAudioCodecType)codec;
- (void)sendVoiceWhisper:(NSData*)audioCodecData frames:(unsigned char)frames packetCount:(unsigned short)packetCount transmissionID:(unsigned short)transmissionID codec:(SLAudioCodecType)codec recipients:(NSArray*)recipients;;

#pragma mark Channel/Status

- (void)changeChannelTo:(unsigned int)newChannel withPassword:(NSString*)password;
- (void)changeStatusTo:(unsigned short)flags;
- (void)changeMute:(BOOL)isMuted onOtherPlayerID:(unsigned int)playerID;

#pragma mark Admin Functions

- (void)kickPlayer:(unsigned int)player withReason:(NSString*)reason;
- (void)kickPlayerFromChannel:(unsigned int)player withReason:(NSString*)reason;

@end

@interface NSObject (SLConnectionDelegate)

- (void)connection:(SLConnection*)connection didLoginTo:(NSString*)host port:(int)port serverName:(NSString*)serverName platform:(NSString*)platform
      majorVersion:(int)majorVersion minorVersion:(int)minorVersion subLevelVersion:(int)subLevelVersion subsubLevelVersion:(int)subsubLevelVersion welcomeMessage:(NSString*)welcomeMessage;

- (void)connectionFinishedLogin:(SLConnection*)connection;
- (void)connectionFailedToLogin:(SLConnection*)connection withError:(NSError*)error;
- (void)connectionDisconnected:(SLConnection*)connection withError:(NSError*)error;

- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary;
- (void)connection:(SLConnection*)connection receivedPlayerList:(NSDictionary*)playerDictionary;

- (void)connection:(SLConnection*)connection receivedNewPlayerNotification:(unsigned int)playerID channel:(unsigned int)channelID nickname:(NSString*)nickname channelPrivFlags:(unsigned int)cFlags extendedFlags:(unsigned int)eFlags;
- (void)connection:(SLConnection*)connection receivedPlayerLeftNotification:(unsigned int)playerID;
- (void)connection:(SLConnection*)connection receivedPlayerUpdateNotification:(unsigned int)playerID flags:(unsigned short)flags;
- (void)connection:(SLConnection*)connection receivedPlayerMutedNotification:(unsigned int)playerID wasMuted:(BOOL)muted;
- (void)connection:(SLConnection*)connection receivedChannelChangeNotification:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID toChannel:(unsigned int)toChannelID;
- (void)connection:(SLConnection*)connection receivedPlayerPriviledgeChangeNotification:(unsigned int)player byPlayerID:(unsigned int)byPlayerID changeType:(SLConnectionPrivChange)changeType privFlag:(SLConnectionChannelPrivFlags)flag;
- (void)connection:(SLConnection*)connection receivedPlayerServerPriviledgeChangeNotification:(unsigned int)player byPlayerID:(unsigned int)byPlayerID changeType:(SLConnectionPrivChange)changeType privFlag:(SLConnectionChannelPrivFlags)flag;
- (void)connection:(SLConnection*)connection receivedPlayerKickedFromChannel:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID intoChannel:(unsigned int)channelID reason:(NSString*)reason;

- (void)connectionPingReply:(SLConnection*)connection;

- (void)connection:(SLConnection*)connection receivedTextMessage:(NSString*)message fromNickname:(NSString*)nickname playerID:(unsigned int)playerID;
- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID isWhisper:(BOOL)isWhisper senderPacketCounter:(unsigned short)count;

@end

