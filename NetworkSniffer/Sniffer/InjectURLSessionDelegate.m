//
//  InjectURLSessionDelegate.m
//  NetworkSniffer
//
//  Created by Bang Nguyen on 21/1/19.
//  Copyright © 2019 Bang Nguyen. All rights reserved.
//

#import "InjectURLSessionDelegate.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/queue.h>

@implementation InjectURLSessionDelegate

+ (void)injectIntoAllNSURLConnectionDelegateClasses
{
  // Only allow swizzling once.
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // Swizzle any classes that implement one of these selectors.
    const SEL selectors[] = {
      @selector(connectionDidFinishLoading:),
      @selector(connection:willSendRequest:redirectResponse:),
      @selector(connection:didReceiveResponse:),
      @selector(connection:didReceiveData:),
      @selector(connection:didFailWithError:),
      @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:),
      @selector(URLSession:dataTask:didReceiveData:),
      @selector(URLSession:dataTask:didReceiveResponse:completionHandler:),
      @selector(URLSession:task:didCompleteWithError:),
      @selector(URLSession:dataTask:didBecomeDownloadTask:),
      @selector(URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:),
      @selector(URLSession:downloadTask:didFinishDownloadingToURL:)
    };

    const int numSelectors = sizeof(selectors) / sizeof(SEL);

    Class *classes = NULL;
    int numClasses = objc_getClassList(NULL, 0);

    if (numClasses > 0) {
      classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
      numClasses = objc_getClassList(classes, numClasses);
      for (NSInteger classIndex = 0; classIndex < numClasses; ++classIndex) {
        Class class = classes[classIndex];

        if (class == [InjectURLSessionDelegate class]) {
          continue;
        }

        // Use the runtime API rather than the methods on NSObject to avoid sending messages to
        // classes we're not interested in swizzling. Otherwise we hit +initialize on all classes.
        // NOTE: calling class_getInstanceMethod() DOES send +initialize to the class. That's why we iterate through the method list.
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(class, &methodCount);
        BOOL matchingSelectorFound = NO;
        for (unsigned int methodIndex = 0; methodIndex < methodCount; methodIndex++) {
          for (int selectorIndex = 0; selectorIndex < numSelectors; ++selectorIndex) {
            if (method_getName(methods[methodIndex]) == selectors[selectorIndex]) {
              [self injectTaskDidReceiveDataIntoDelegateClass:class];
              matchingSelectorFound = YES;
              break;
            }
          }
          if (matchingSelectorFound) {
            break;
          }
        }
        free(methods);
      }
      free(classes);
    }
  });
}

+ (SEL)swizzledSelectorForSelector:(SEL)selector
{
  return NSSelectorFromString([NSString stringWithFormat:@"_flex_swizzle_%x_%@", arc4random(), NSStringFromSelector(selector)]);
}

+ (void)injectTaskDidReceiveDataIntoDelegateClass:(Class)cls
{
  SEL selector = @selector(URLSession:dataTask:didReceiveData:);
  SEL swizzledSelector = [self swizzledSelectorForSelector:selector];

  Protocol *protocol = @protocol(NSURLSessionDataDelegate);

  struct objc_method_description methodDescription = protocol_getMethodDescription(protocol, selector, NO, YES);

  typedef void (^NSURLSessionDidReceiveDataBlock)(id <NSURLSessionDataDelegate> slf, NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data);

  NSURLSessionDidReceiveDataBlock undefinedBlock = ^(id <NSURLSessionDataDelegate> slf, NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data) {
    //Record the request

  };

  NSURLSessionDidReceiveDataBlock implementationBlock = ^(id <NSURLSessionDataDelegate> slf, NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data) {
    [self sniffWithoutDuplicationForObject:session selector:selector sniffingBlock:^{
      undefinedBlock(slf, session, dataTask, data);
    } originalImplementationBlock:^{
      ((void(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzledSelector, session, dataTask, data);
    }];
  };

  [self replaceImplementationOfSelector:selector withSelector:swizzledSelector forClass:cls withMethodDescription:methodDescription implementationBlock:implementationBlock undefinedBlock:undefinedBlock];

}

+ (void)sniffWithoutDuplicationForObject:(NSObject *)object selector:(SEL)selector sniffingBlock:(void (^)(void))sniffingBlock originalImplementationBlock:(void (^)(void))originalImplementationBlock
{
  // If we don't have an object to detect nested calls on, just run the original implmentation and bail.
  // This case can happen if someone besides the URL loading system calls the delegate methods directly.
  // See https://github.com/Flipboard/FLEX/issues/61 for an example.
  if (!object) {
    originalImplementationBlock();
    return;
  }

  const void *key = selector;

  // Don't run the sniffing block if we're inside a nested call
  if (!objc_getAssociatedObject(object, key)) {
    sniffingBlock();
  }

  // Mark that we're calling through to the original so we can detect nested calls
  objc_setAssociatedObject(object, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  originalImplementationBlock();
  objc_setAssociatedObject(object, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)replaceImplementationOfSelector:(SEL)selector withSelector:(SEL)swizzledSelector forClass:(Class)cls withMethodDescription:(struct objc_method_description)methodDescription implementationBlock:(id)implementationBlock undefinedBlock:(id)undefinedBlock
{
  if ([self instanceRespondsButDoesNotImplementSelector:selector class:cls]) {
    return;
  }

  IMP implementation = imp_implementationWithBlock((id)([cls instancesRespondToSelector:selector] ? implementationBlock : undefinedBlock));

  Method oldMethod = class_getInstanceMethod(cls, selector);
  if (oldMethod) {
    class_addMethod(cls, swizzledSelector, implementation, methodDescription.types);

    Method newMethod = class_getInstanceMethod(cls, swizzledSelector);

    method_exchangeImplementations(oldMethod, newMethod);
  } else {
    class_addMethod(cls, selector, implementation, methodDescription.types);
  }
}

+ (BOOL)instanceRespondsButDoesNotImplementSelector:(SEL)selector class:(Class)cls
{
  if ([cls instancesRespondToSelector:selector]) {
    unsigned int numMethods = 0;
    Method *methods = class_copyMethodList(cls, &numMethods);

    BOOL implementsSelector = NO;
    for (int index = 0; index < numMethods; index++) {
      SEL methodSelector = method_getName(methods[index]);
      if (selector == methodSelector) {
        implementsSelector = YES;
        break;
      }
    }

    free(methods);

    if (!implementsSelector) {
      return YES;
    }
  }

  return NO;
}

@end
