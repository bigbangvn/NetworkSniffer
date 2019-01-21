//
//  InjectURLSessionDelegate.h
//  NetworkSniffer
//
//  Created by Bang Nguyen on 21/1/19.
//  Copyright © 2019 Bang Nguyen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InjectURLSessionDelegate : NSObject
+ (void)injectIntoAllNSURLConnectionDelegateClasses;
@end

NS_ASSUME_NONNULL_END
