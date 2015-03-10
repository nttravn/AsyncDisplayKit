/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASDownloaderContext.h"

#import "ASThread.h"


@interface ASDownloaderContext ()
{
  BOOL _invalid;
  ASDN::RecursiveMutex _propertyLock;
}
@end

@implementation ASDownloaderContext

static NSMutableDictionary *currentRequests = nil;
static ASDN::RecursiveMutex currentRequestsLock;

+ (ASDownloaderContext *)contextForURL:(NSURL *)URL
{
  ASDN::MutexLocker l(currentRequestsLock);
  if (!currentRequests) {
    currentRequests = [[NSMutableDictionary alloc] init];
  }
  ASDownloaderContext *context = currentRequests[URL];
  if (!context) {
    context = [[ASDownloaderContext alloc] initWithURL:URL];
    currentRequests[URL] = context;
  }
  return context;
}

+ (void)invalidateContextWithURL:(NSURL *)URL
{
  ASDN::MutexLocker l(currentRequestsLock);
  if (currentRequests) {
    [currentRequests removeObjectForKey:URL];
  }
}

- (instancetype)initWithURL:(NSURL *)URL
{
  if (self = [super init]) {
    _URL = URL;
  }
  return self;
}

- (void)invalidate
{
  ASDN::MutexLocker l(_propertyLock);

  NSURLSessionTask *sessionTask = self.sessionTask;
  if (sessionTask) {
    [sessionTask cancel];
    self.sessionTask = nil;
  }

  _invalid = YES;
  [self.class invalidateContextWithURL:self.URL];
}

- (BOOL)isInvalid
{
  ASDN::MutexLocker l(_propertyLock);
  return _invalid;
}

@end
