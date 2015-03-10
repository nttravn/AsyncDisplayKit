/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASDownloaderContext.h>

#import <OCMock/OCMock.h>

#import <XCTest/XCTest.h>


@interface ASDownloaderContextTests : XCTestCase

@end

@implementation ASDownloaderContextTests

- (NSURL *)randomURL
{
  // random URL for each test, doesn't matter that this is not really a URL
  return [NSURL URLWithString:[NSUUID UUID].UUIDString];
}

- (void)testContextCreation
{
  NSURL *url = [self randomURL];
  ASDownloaderContext *c1 = [ASDownloaderContext contextForURL:url];
  ASDownloaderContext *c2 = [ASDownloaderContext contextForURL:url];
  XCTAssert(c1 == c2, @"Context objects are not the same");
}

- (void)testContextInvalidation
{
  NSURL *url = [self randomURL];
  ASDownloaderContext *context = [ASDownloaderContext contextForURL:url];
  [context invalidate];
  XCTAssert([context isInvalid], @"Context should be invalid");
}

- (void)testAsyncContextInvalidation
{
  NSURL *url = [self randomURL];
  ASDownloaderContext *context = [ASDownloaderContext contextForURL:url];
  XCTestExpectation *expectation = [self expectationWithDescription:@"Context invalidation"];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [expectation fulfill];
    XCTAssert([context isInvalid], @"Context should be invalid");
  });

  [context invalidate];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testContextSessionCanceled
{
  NSURL *url = [self randomURL];
  id task = [OCMockObject mockForClass:[NSURLSessionTask class]];
  ASDownloaderContext *context = [ASDownloaderContext contextForURL:url];
  context.sessionTask = task;

  [[task expect] cancel];

  [context invalidate];
}

@end
