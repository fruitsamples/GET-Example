/*
 *  GetExampleDelegate.h
 *  GET Example
 *
 *  Created by Jeremy Wyld on Dec 05 2001.
 *  Copyright (c) 2001, 2002 Apple Computer, Inc. All rights reserved.
 *
 */


#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>


@interface GetExampleDelegate : NSObject
{
    IBOutlet id authName;
    IBOutlet id authPanel;
    IBOutlet id authPass;
    IBOutlet id authPrompt;
    IBOutlet id authRealm;

    IBOutlet id resultsTextView;
    IBOutlet id statusTextField;
    IBOutlet id urlTextField;
    
    NSURL*				_url;
    CFReadStreamRef		_stream;
    CFHTTPMessageRef	_request;
    CFHTTPMessageRef	_response;
}

- (IBAction)fetchUrl:(id)sender;
- (IBAction)refetchUrl:(id)sender;

- (void)fetch:(CFHTTPMessageRef)request;

- (void)handleNetworkEvent:(CFStreamEventType)type;

- (void)handleBytesAvailable;
- (void)handleStreamComplete;
- (void)handleStreamError;

@end
