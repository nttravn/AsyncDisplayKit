/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASImageDownloader.h"

#import <objc/runtime.h>

#import <UIKit/UIKit.h>

#import "ASThread.h"


#pragma mark -
/**
 * Collection of properties associated with a download request.
 */
@interface ASImageDownloaderMetadata : NSObject
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, copy) void (^downloadProgressBlock)(CGFloat);
@property (nonatomic, copy) void (^completionBlock)(CGImageRef, NSError *);
@end

@implementation ASImageDownloaderMetadata
@end


#pragma mark -
/**
 * NSURLSessionDownloadTask lacks a `userInfo` property, so add this association ourselves.
 */
@interface NSURLRequest (ASImageDownloader)
@property (nonatomic, strong) ASImageDownloaderMetadata *asyncdisplaykit_metadata;
@end

@implementation NSURLRequest (ASImageDownloader)
static const char *kMetadataKey = NSStringFromClass(ASImageDownloaderMetadata.class).UTF8String;
- (void)setAsyncdisplaykit_metadata:(ASImageDownloaderMetadata *)asyncdisplaykit_metadata
{
  objc_setAssociatedObject(self, kMetadataKey, asyncdisplaykit_metadata, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (ASImageDownloader *)asyncdisplaykit_metadata
{
  return objc_getAssociatedObject(self, kMetadataKey);
}
@end


#pragma mark -
@interface ASImageDownloader () <NSURLSessionDownloadDelegate>
{
  NSOperationQueue *_sessionDelegateQueue;
  NSURLSession *_session;
}

@end

@implementation ASImageDownloader

#pragma mark Lifecycle.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _sessionDelegateQueue = [[NSOperationQueue alloc] init];
  _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                           delegate:self
                                      delegateQueue:_sessionDelegateQueue];

  return self;
}


#pragma mark ASImageDownloaderProtocol.

- (id)downloadImageWithURL:(NSURL *)URL
             callbackQueue:(dispatch_queue_t)callbackQueue
     downloadProgressBlock:(void (^)(CGFloat))downloadProgressBlock
                completion:(void (^)(CGImageRef, NSError *))completion
{
  ASDownloaderContext *context = [ASDownloaderContext contextForURL:URL];

  // NSURLSessionDownloadTask will do file I/O to create a temp directory. If called on the main thread this will
  // cause significant performance issues.
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    // the downloader may have been invalidated in the time it takes to async dispatch this block
    if ([context isInvalid]) {
      return;
    }
    
    // create download task
    NSURLSessionDownloadTask *task = [_session downloadTaskWithURL:URL];

    // since creating the task does disk I/O, we should check if it has been invalidated
    if ([context isInvalid]) {
      return;
    }

    // associate metadata with it
    ASImageDownloaderMetadata *metadata = [[ASImageDownloaderMetadata alloc] init];
    metadata.callbackQueue = callbackQueue ?: dispatch_get_main_queue();
    metadata.downloadProgressBlock = downloadProgressBlock;
    metadata.completionBlock = completion;
    task.originalRequest.asyncdisplaykit_metadata = metadata;

    // start downloading
    [task resume];

    context.sessionTask = task;
  });

  return context;
}

- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  if (!downloadIdentifier) {
    return;
  }

  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:ASDownloaderContext.class], @"unexpected downloadIdentifier");
  ASDownloaderContext *context = (ASDownloaderContext *)downloadIdentifier;

  [context invalidate];
}


#pragma mark NSURLSessionDownloadDelegate.

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
  ASImageDownloaderMetadata *metadata = downloadTask.originalRequest.asyncdisplaykit_metadata;
  if (metadata.downloadProgressBlock) {
    metadata.downloadProgressBlock((CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite);
  }
}

// invoked if the download succeeded with no error
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                              didFinishDownloadingToURL:(NSURL *)location
{
  UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:location]];

  ASImageDownloaderMetadata *metadata = downloadTask.originalRequest.asyncdisplaykit_metadata;
  if (metadata.completionBlock) {
    dispatch_async(metadata.callbackQueue, ^{
      metadata.completionBlock(image.CGImage, nil);
    });
  }
}

// invoked unconditionally
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDownloadTask *)task
                           didCompleteWithError:(NSError *)error
{
  ASImageDownloaderMetadata *metadata = task.originalRequest.asyncdisplaykit_metadata;
  if (metadata && error) {
    dispatch_async(metadata.callbackQueue, ^{
      metadata.completionBlock(NULL, error);
    });
  }
}

@end
