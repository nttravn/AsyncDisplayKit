/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@interface ASDownloaderContext : NSObject

/// The URL for the sessionTask. Readonly.
@property (nonatomic, strong, readonly) NSURL *URL;

/// The session task for the context object.
@property (nonatomic, strong) NSURLSessionTask *sessionTask;

/// Get a context object for a URL. The object is either fetched from an existing request or created for you.
+ (ASDownloaderContext *)contextForURL:(NSURL *)URL;

/// Determine if the context has been invalidated.
- (BOOL)isInvalid;

/// Cancel the session task if it exists.
- (void)invalidate;

@end
