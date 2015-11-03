/*
	Copyright: 	© Copyright 2002 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
			copyrights in this original Apple software (the "Apple Software"), to use,
			reproduce, modify and redistribute the Apple Software, with or without
			modifications, in source and/or binary forms; provided that if you redistribute
			the Apple Software in its entirety and without modifications, you must retain
			this notice and the following text and disclaimers in all such redistributions of
			the Apple Software.  Neither the name, trademarks, service marks or logos of
			Apple Computer, Inc. may be used to endorse or promote products derived from the
			Apple Software without specific prior written permission from Apple.  Except as
			expressly stated in this notice, no other rights or licenses, express or implied,
			are granted by Apple herein, including but not limited to any patent rights that
			may be infringed by your derivative works or by other works in which the Apple
			Software may be incorporated.

			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
			WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
			WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
			PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
			COMBINATION WITH YOUR PRODUCTS.

			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
			CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
			GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
			ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
			OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
			(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
			ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#import "GetExampleDelegate.h"


static const CFOptionFlags kNetworkEvents = kCFStreamEventOpenCompleted |
                                            kCFStreamEventHasBytesAvailable |
                                            kCFStreamEventEndEncountered |
                                            kCFStreamEventErrorOccurred;


static void
ReadStreamClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    // Pass off to the object to handle.
    [((GetExampleDelegate*)clientCallBackInfo) handleNetworkEvent: type];
}


#pragma mark -
#pragma mark Implementation GetExampleDelegate
@implementation GetExampleDelegate


- (IBAction)fetchUrl:(id)sender
{
    CFHTTPMessageRef request;
    NSString* url_string = [urlTextField stringValue];
    
    // Make sure there is a string in the text field
    if (!url_string || ![url_string length]) {
        [statusTextField setStringValue: @"Enter a valid URL."];
        return;
    }
    
    // If there is no scheme of http or https, slap "http://" on the front.
    if (![url_string hasPrefix: @"http://"] && ![url_string hasPrefix: @"https://"])
        url_string = [NSString stringWithFormat: @"http://%@", url_string];
    
    // Release the old url
    if (_url) {
        [_url release];
        _url = NULL;
    }
    
    // Create a new url based upon the user entered string
    _url = [NSURL URLWithString: url_string];
    
    // Make sure it succeeded
    if (!_url) {
        [statusTextField setStringValue: @"Enter a valid URL."];
        return;
    }
    
    // Hold it around so that the authorization code can get to it
    // in order to display the host name in the prompt.
    [_url retain];

    // Create a new HTTP request.
    request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (CFURLRef)_url, kCFHTTPVersion1_1);
    if (!request) {
        [statusTextField setStringValue: @"Creating the request failed."];
        return;
    }
    
    // Start the fetch.
    [self fetch: request];
    
    // Release the request.  The fetch should've retained it if it
    // is performing the fetch.
    CFRelease(request);
}


- (IBAction)refetchUrl:(id)sender
{
    // Get the user entered values for name and password.
    NSString* user = [authName stringValue];
    NSString* pass = [authPass stringValue];
    
    // For security sake, empty out the password field.
    [authPass setStringValue: @""];
    
    // Close the panel
    [authPanel performClose: self];
    
    // Try to add the authentication credentials to the request.  If it
    // succeeds, perform the fetch.  This example does not support proxy
    // authentication, but the API does support it.  Use "NULL" for the
    // authentication method, so the API chooses the strongest.
    if (CFHTTPMessageAddAuthentication(_request, _response, (CFStringRef)user, (CFStringRef)pass, NULL, FALSE))
        [self fetch: _request];
    
    else
        [statusTextField setStringValue: @"Could not apply authenticatiion to the request."];
}


- (void)fetch:(CFHTTPMessageRef)request
{
    
    CFHTTPMessageRef old;
    CFStreamClientContext ctxt = {0, self, NULL, NULL, NULL};
    
    // Don't fetch if there is a fetch in progress.
    if (!_stream)
        [statusTextField setStringValue: @""];
    else {
        [statusTextField setStringValue: @"There is a request in progress."];
        return;
    }
    
    // Clear out the old results
    [resultsTextView scrollRangeToVisible: NSMakeRange(0, 0)];
    [resultsTextView replaceCharactersInRange: NSMakeRange(0, [[resultsTextView string] length])
                     withString: @""];
    
    // Swap the old request and the new request.  It is done in this
    // order since the new request could be the same as the existing
    // request.  If the old one is released first, it could be destroyed
    // before retain.
    old = _request;
    _request = (CFHTTPMessageRef)CFRetain(request);
    if (old)
        CFRelease(old);
    
    // Create the stream for the request.
    _stream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, _request);

    // Make sure it succeeded.
    if (!_stream) {
        [statusTextField setStringValue: @"Creating the stream failed."];
        return;
    }
    
    // Set the client
    if (!CFReadStreamSetClient(_stream, kNetworkEvents, ReadStreamClientCallBack, &ctxt)) {
        CFRelease(_stream);
        _stream = NULL;
        [statusTextField setStringValue: @"Setting the stream's client failed."];
        return;
    }
    
    // Schedule the stream
    CFReadStreamScheduleWithRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
    // Start the HTTP connection
    if (!CFReadStreamOpen(_stream)) {
        CFReadStreamSetClient(_stream, 0, NULL, NULL);
        CFReadStreamUnscheduleFromRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFRelease(_stream);
        _stream = NULL;
        [statusTextField setStringValue: @"Opening the stream failed."];
        return;
    }
}


- (void)handleNetworkEvent:(CFStreamEventType)type {
    
    // Dispatch the stream events.
    switch (type) {
        case kCFStreamEventHasBytesAvailable:
            [self handleBytesAvailable];
            break;
            
        case kCFStreamEventEndEncountered:
            [self handleStreamComplete];
            break;
            
        case kCFStreamEventErrorOccurred:
            [self handleStreamError];
            break;
            
        default:
            break;
    }
}


- (void)handleBytesAvailable {

    UInt8 buffer[2048];
    CFIndex bytesRead = CFReadStreamRead(_stream, buffer, sizeof(buffer));
    
    // Less than zero is an error
    if (bytesRead < 0)
        [self handleStreamError];
    
    // If zero bytes were read, wait for the EOF to come.
    else if (bytesRead) {
        
        // This would not work for binary data!  Build a string to add
        // to the results.
        NSString* to_add = [NSString stringWithCString: (char*)buffer length: bytesRead];
        
        // Append and scroll the results field.
        [resultsTextView replaceCharactersInRange: NSMakeRange([[resultsTextView string] length], 0)
                         withString: to_add];
        
        [resultsTextView scrollRangeToVisible: NSMakeRange([[resultsTextView string] length], 0)];
    }
}


- (void)handleStreamComplete {
    
    // Toss the old response if there is one.
    if (_response)
        CFRelease(_response);
    
    // Save the new response for authentication
    _response = (CFHTTPMessageRef)CFReadStreamCopyProperty(_stream, kCFStreamPropertyHTTPResponseHeader);
        
    // Check to see if it is a 401 "Authorization Needed" error.  To
    // test for proxy authentication, 407 would have to be caught too.
    if (CFHTTPMessageGetResponseStatusCode(_response) == 401) {
    
        // Grab the authentication header in order to display the realm.
		NSString* auth_header = (NSString*)CFHTTPMessageCopyHeaderFieldValue(_response, CFSTR("WWW-Authenticate"));
        [auth_header autorelease];
        
        // Parse out the realm and prompt the user
        if (auth_header) {
            
            // Find "realm" authentication parameter
            NSRange range = [auth_header rangeOfString: @"realm" options: NSCaseInsensitiveSearch];
            
            // Continue processing if found
            if (range.location != NSNotFound) {
            
                unsigned int start = NSNotFound;				// Start of the realm value
                unsigned int end = NSNotFound;					// End of the realm value
                unsigned int length = [auth_header length];		// Length of the header
                unichar c;										// Character walking across the string
                
                // Jump over "realm"
                range.location += range.length;
                
                // Loop through each character to find start and end.
                while ((range.location < length) && (end == NSNotFound)) {
                    
                    // Pull off the character
                    c = [auth_header characterAtIndex: range.location];
                    
                    
                    switch (c) {
                        
                        // If it is a quote, mark the start and end
                        case '"':
                            if (start == NSNotFound)
                                start = range.location + 1;
                            
                            // The realm is defined as a quoted string, but escape sequences are
                            // allowed.  Only take the quote if it was not preceeded with the
                            // escape.
                            else if ([auth_header characterAtIndex: range.location - 1] != '\\')
                                end = range.location;
                            break;
                            
                        default:
                            break;
                    }
                    
                    // Next character
                    range.location++;
                }
                
                // Build the range based upon the start and end
                range.location = start;
                range.length = end - start;
                
                // Populate the prompt for the user
                [authRealm setStringValue: [auth_header substringWithRange: range]];
                
                // Populate the host value
                [authPrompt setStringValue: [NSString stringWithFormat: @"Connect to %@ as", [_url host]]];
                
                // Prompt the user
                [authPanel makeKeyAndOrderFront: self];
            }
        }
    }
    
    // Don't need the stream any more, and indicate complete.
    CFReadStreamSetClient(_stream, 0, NULL, NULL);
    CFReadStreamUnscheduleFromRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamClose(_stream);
    CFRelease(_stream);
    _stream = NULL;
    [statusTextField setStringValue: @"Fetch is complete."];
}


- (void)handleStreamError {

    // Lame error handling.  Simply state that an error did occur.
    CFReadStreamSetClient(_stream, 0, NULL, NULL);
    CFReadStreamUnscheduleFromRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamClose(_stream);
    CFRelease(_stream);
    _stream = NULL;
    [statusTextField setStringValue: @"Error occurred."];
}


@end
