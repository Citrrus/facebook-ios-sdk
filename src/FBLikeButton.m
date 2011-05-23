/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FBLikeButton.h"
#import "Facebook.h"
#import "FBRequest.h"
#import "JSON.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
// private methods

@interface FBLikeButton()
- (void)clearLikeUpdateRequest;
- (void)sendLikeUpdateRequest;
- (void)clearLikeStatusRequest;
- (void)sendLikeStatusRequest;
- (void)handleFailedButtonClickWithError:(NSError *)error;
@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation FBLikeButton

@synthesize isLiked = _isLiked;

///////////////////////////////////////////////////////////////////////////////////////////////////
// constants

// Apps in languages other than English may want to replace these images.
static NSString* kLikeImage   = @"FBDialog.bundle/images/like.png";
static NSString* kUnlikeImage = @"FBDialog.bundle/images/like_clicked.png";

static CGFloat kWidth = 63;
static CGFloat kHeight = 29;

///////////////////////////////////////////////////////////////////////////////////////////////////
// public

/**
 * Convenience method to create a new like button without a delegate.
 */
- (id)initWithFrame:(CGRect)rect facebook:(Facebook *)facebook href:(NSString *)href {
	self = [self initWithFrame:rect facebook:facebook href:href delegate:nil];
  return self;
}

/**
 * Creates a new like button.
 */
- (id)initWithFrame:(CGRect)rect
           facebook:(Facebook *)facebook
               href:(NSString *)href
           delegate:(id <FBLikeButtonDelegate>)delegate {
  if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) {
    CGSize size = [self sizeThatFits:CGSizeZero];
    rect = CGRectMake(0, 0, size.width, size.height);
  }
  
  self = [super initWithFrame:rect];
  if (!self) {
    return nil;
  }
  
  _href = [href retain];
  _delegate = delegate;
  _pageID = nil;
  _isLiked = NO;
  _pendingUpdateAction = FBLikeButtonActionNone;
  
  _likeImage = [[UIImage imageNamed:kLikeImage] retain];
  _unlikeImage = [[UIImage imageNamed:kUnlikeImage] retain];

  // create the button
  _button = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
  _button.frame = CGRectMake(0, 0, kWidth, kHeight);
  _button.center = self.center;
  _button.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                              UIViewAutoresizingFlexibleTopMargin |
                              UIViewAutoresizingFlexibleRightMargin |
                              UIViewAutoresizingFlexibleBottomMargin);
  [_button setBackgroundColor:[UIColor clearColor]];	
	[_button addTarget:self
              action:@selector(onClick)
    forControlEvents:UIControlEventTouchUpInside];
  [self addSubview:_button];
    
  [self setFacebook:facebook];
  
  return self;
}

/**
 * Release the stuff we retained earlier.
 */
- (void)dealloc {
  [self clearLikeStatusRequest];
  [self clearLikeUpdateRequest];

  [_facebook release];
  [_pageID release];
  
  [_button release];
  [_href release];
  [_likeImage release];
  [_unlikeImage release];
    
  [super dealloc];
}

/**
 * Should be called when a user logs out and a different user logs in, so that the button uses
 * the session associated with the new user.
 */
- (void)setFacebook:(Facebook *)facebook {
  if (facebook != _facebook) {
    [_facebook release];
    _facebook = [facebook retain];
  }

  // Set the button's initial state to unliked, as that's more likely to be the correct state.
  // This will get updated to the true value when the request sent by sendLikeStatusRequest is 
  // received.
  _isLiked = NO;
  [_button setImage:_likeImage forState:UIControlStateNormal];
      
  [self clearLikeUpdateRequest];
  // the following function clears the previous request before sending out a new one
  [self sendLikeStatusRequest];
}

/**
 * Returns the size of the button.
 */
- (CGSize)sizeThatFits:(CGSize)size {
  return CGSizeMake(kWidth, kHeight);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// private

/**
 * Returns an NSError given a code from the FBClientErrorDomain domain.
 */
- (NSError *)errorWithCode:(NSInteger)code {
  return [NSError errorWithDomain:FBClientErrorDomain code:code userInfo:nil];
}

/**
 * Calls the failure delegate given an NSError.
 */
- (void)failAction:(FBLikeButtonAction)action withError:(NSError *)error {
  if ([_delegate respondsToSelector:@selector(likeButton:didFailWithAction:error:)]) {
    [_delegate likeButton:self didFailWithAction:action error:error];
  }
}

/**
 * Calls the failure delegate given a code from the FBClientErrorDomain domain.
 */
- (void)failAction:(FBLikeButtonAction)action withCode:(NSInteger)code {
  NSError* error = [self errorWithCode:code];
  [self failAction:action withError:error];
}

/**
 * Makes the magic happen when the button is clicked.
 */
- (void)onClick {
  // optimistically assume the button click worked
  _isLiked = !_isLiked;
  UIImage* image = _isLiked ? _unlikeImage : _likeImage;
  [_button setImage:image forState:UIControlStateNormal];

  // if the button was clicked before the initial like status was received, then the local state
  // takes precendence over the server state, so we can clear that request.
  [self clearLikeStatusRequest];
  
  // finally, update the server state
  [self sendLikeUpdateRequest];
}

/**
 * Cleans up a pending like update request.
 */
- (void)clearLikeUpdateRequest {
  _likeUpdateRequest.delegate = nil;
  [_likeUpdateRequest release];
  _likeUpdateRequest = nil;
  _pendingUpdateAction = FBLikeButtonActionNone;
}

/**
 * Updates the server's like status using the Graph API.
 */
- (void)sendLikeUpdateRequest {
  [self clearLikeUpdateRequest];

  NSMutableDictionary* params =
   [NSMutableDictionary dictionaryWithObjectsAndKeys: _href, @"url", nil];
  NSString *method = _isLiked ? @"POST" : @"DELETE";
  _likeUpdateRequest = [[_facebook requestWithGraphPath:@"me/likes"
                                              andParams:params
                                          andHttpMethod:method
                                            andDelegate:self] retain];
  _pendingUpdateAction = _isLiked ? FBLikeButtonActionLike : FBLikeButtonActionUnlike;
}

/**
 * Cleans up a pending like status request.
 */
- (void)clearLikeStatusRequest {
  _likeStatusRequest.delegate = nil;
  [_likeStatusRequest release];
  _likeStatusRequest = nil;
}

/**
 * Sends out an FQL request to figure out the Page ID corresponding to the button's URL, as well
 * as whether the user has previously liked this URL or not.
 */
- (void)sendLikeStatusRequest {
  NSMutableDictionary* queries;
  
  if (_pageID) {
    NSString* likeStatusQuery =
     [NSString stringWithFormat:@"select uid, page_id from page_fan"
                                 " where uid=me() and page_id = \"%@\"",
      _pageID];
    queries = [NSMutableDictionary dictionaryWithObjectsAndKeys:
               likeStatusQuery, @"like_status_query", nil];
    
  } else {
    NSString* pageIDQuery = 
     [NSString stringWithFormat:@"select id from object_url where url=\"%@\"", _href];
    NSString* likeStatusQuery = @"select uid, page_id from page_fan"
                                 " where uid=me() and page_id in (select id from #page_id_query)";
    queries = [NSMutableDictionary dictionaryWithObjectsAndKeys:
               pageIDQuery, @"page_id_query",
               likeStatusQuery, @"like_status_query", nil];    
  }
  
  NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 [queries JSONRepresentation], @"queries", nil];

  [self clearLikeStatusRequest];
  _likeStatusRequest = [[_facebook requestWithMethodName:@"fql.multiquery"
                                               andParams:(NSMutableDictionary *)params
                                           andHttpMethod:@"GET"
                                             andDelegate:self] retain];
}

/**
 * Processes the response to the API request to figure out if the user has previously liked this
 * page. This was triggered by processPageIDResponse, which was triggered by init.
 */
- (void)processLikeStatusResponse:(id)result {
  [self clearLikeStatusRequest];
  
  // parse the multiquery results
  BOOL foundPageIDQueryResult = NO;
  BOOL foundLikeStatusQueryResult = NO;
  for (NSDictionary* query_result in result) {
    NSString* name = [query_result objectForKey:@"name"];
    if ([name isEqualToString:@"page_id_query"]) {
      if (foundPageIDQueryResult) {
        [self failAction:FBLikeButtonActionSetup
                withCode:FBClientErrorLikeButtonFailedActivation];
        return;
      }
      NSArray* fqlResultSet = [query_result objectForKey:@"fql_result_set"];
      NSDictionary* pageIDResult = [fqlResultSet lastObject];
      [_pageID release];
      _pageID = [[pageIDResult objectForKey:@"id"] retain];
      if (_pageID) {
        foundPageIDQueryResult = YES;
      }
    } else if ([name isEqualToString:@"like_status_query"]) {
      if (foundLikeStatusQueryResult) {
        [self failAction:FBLikeButtonActionSetup
                withCode:FBClientErrorLikeButtonFailedActivation];
        return;
      }
      NSArray* fqlResultSet = [query_result objectForKey:@"fql_result_set"];
      _isLiked = ([fqlResultSet count] != 0);
      foundLikeStatusQueryResult = YES;
    }
  }
  if ((!_pageID && !foundPageIDQueryResult) || !foundLikeStatusQueryResult) {
    [self failAction:FBLikeButtonActionSetup
            withCode:FBClientErrorLikeButtonFailedActivation];
    return;
  }
  
  // once we have the like status, show the proper button
  if (_isLiked) {
    [_button setImage:_unlikeImage forState:UIControlStateNormal];
  } else {
    [_button setImage:_likeImage forState:UIControlStateNormal];
  }
}

/**
 * Processes the response to the Graph API request triggered by a button click.
 */
- (void)processButtonClickResponse:(id)result {
  FBLikeButtonAction action = _pendingUpdateAction;
  [self clearLikeUpdateRequest];
  
  if ([result objectForKey:@"result"] == @"true") {
    
    // if result is true, the action succeeded, so notify the delegates
    
    if ([_delegate respondsToSelector:@selector(likeButton:didSucceedWithAction:)]) {
      [_delegate likeButton:self didSucceedWithAction:action];
    }
    
  } else {
    
    // otherwise, the action failed
    
    NSInteger code;
    if (action == FBLikeButtonActionLike) {
      code = FBClientErrorLikeButtonFailedLike;
    } else if (action == FBLikeButtonActionUnlike) {
      code = FBClientErrorLikeButtonFailedUnlike;
    } else {
      code = FBClientErrorLikeButtonUnknownRequest;
    }
    NSError* error = [self errorWithCode:code];
    // set this variable again so that the following function can use it
    _pendingUpdateAction = action;
    [self handleFailedButtonClickWithError:error];
  }
}

/**
 * If the Graph API request triggered by a button click failed, we need to change the image
 * back to what it used to be (since we had optimistically  changed the image as if the action
 * had already succeeded), as well as notify the delegate.
 */
- (void)handleFailedButtonClickWithError:(NSError *)error {
  FBLikeButtonAction action = _pendingUpdateAction;
  [self clearLikeUpdateRequest];

  if (action == FBLikeButtonActionLike && _isLiked) {
    _isLiked = NO;
  } else if (action == FBLikeButtonActionUnlike && !_isLiked) {
    _isLiked = YES;
  }
  
  UIImage* image = _isLiked ? _unlikeImage : _likeImage;
  [_button setImage:image forState:UIControlStateNormal];    
  
  [self failAction:action withError:error];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// FBRequestDelegate

/**
 * Route the response from a Graph API request to the appropriate handler.
 */
- (void)request:(FBRequest *)request didLoad:(id)result {
  if (request == _likeStatusRequest) {
    [self processLikeStatusResponse:result];
  } else if (request == _likeUpdateRequest) {
    [self processButtonClickResponse:result];
  }
}

/**
 * If there was an error with the Graph API request, bubble it up.
 */
- (void)request:(FBRequest *)request didFailWithError:(NSError *)error {
  if (request == _likeStatusRequest) {
    [self failAction:FBLikeButtonActionSetup withError:error];
  } else if (request == _likeUpdateRequest) {
    [self handleFailedButtonClickWithError:error];
  }
}

@end 
