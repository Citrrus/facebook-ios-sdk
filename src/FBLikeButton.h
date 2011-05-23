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

#import "Facebook.h"

@protocol FBLikeButtonDelegate;

typedef enum _FBLikeButtonAction {
  FBLikeButtonActionSetup = 1,
  FBLikeButtonActionLike,
  FBLikeButtonActionUnlike,
  FBLikeButtonActionNone
} FBLikeButtonAction;

@interface FBLikeButton : UIView <FBRequestDelegate> {
  UIButton* _button;
	id<FBLikeButtonDelegate> _delegate;
	Facebook* _facebook;
	NSString* _href;
  NSString* _pageID;
	BOOL _isLiked;
  FBRequest* _likeStatusRequest;
  FBRequest* _likeUpdateRequest;
  FBLikeButtonAction _pendingUpdateAction;
  
  UIImage* _likeImage;
  UIImage* _unlikeImage;
}

@property(nonatomic) BOOL isLiked; 

- (id)initWithFrame:(CGRect)rect facebook:(Facebook *)facebook href:(NSString *)href;
- (id)initWithFrame:(CGRect)rect
           facebook:(Facebook *)facebook
               href:(NSString *)href
           delegate:(id<FBLikeButtonDelegate>)delegate;
- (void)setFacebook:(Facebook *)facebook;

@end

////////////////////////////////////////////////////////////////////////////////

@protocol FBLikeButtonDelegate <NSObject>

@optional

- (void)likeButton:(FBLikeButton *)button didSucceedWithAction:(FBLikeButtonAction)action;
- (void)likeButton:(FBLikeButton *)button didFailWithAction:(FBLikeButtonAction)action error:(NSError *)error;

@end
