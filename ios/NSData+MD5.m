//
//  NSData+MD5.m
//  stockeasy
//
//  Created by Man Leung on 21/9/2017.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "NSData+MD5.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData(MD5)

//- (NSString*)MD5
//{
////  // Create byte array of unsigned chars
////  unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
////  
////  // Create 16 byte MD5 hash value, store in buffer
////  CC_MD5(self.bytes, self.length, md5Buffer);
////  
////  // Convert unsigned char buffer to NSString of hex values
////  NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
////  for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
////    [output appendFormat:@"%02x",md5Buffer[i]];
////  
////  return output;
//  unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
//  CC_MD5(self.bytes, (CC_LONG)self.length, md5Buffer);
//  NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
//  for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
//    [output appendFormat:@"%02x",md5Buffer[i]];
//  
//  return output;
//}

- (NSString*)MD5
{
  unsigned char result[16];
  CC_MD5( self.bytes, self.length, result );
  return [NSString stringWithFormat:
          @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
          result[0], result[1], result[2], result[3],
          result[4], result[5], result[6], result[7],
          result[8], result[9], result[10], result[11],
          result[12], result[13], result[14], result[15]
          ];
}

@end
