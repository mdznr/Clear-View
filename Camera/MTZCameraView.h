//
//  MTZCameraView.h
//  Camera
//
//  Created by Matt Zanchelli on 1/30/14.
//  Copyright (c) 2014 Matt Zanchelli. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MTZCameraView;

@protocol MTZCameraViewDelegate

- (void)cameraView:(MTZCameraView *)cameraView didTakePhoto:(UIImage *)image;

@end


@interface MTZCameraView : UIView

@property (nonatomic, assign) id<MTZCameraViewDelegate> delegate;

/// Load the camera.
/// @discussion Perform this in the @c viewDidLoad: method of the containing view controller.
- (void)loadCam;

/// Prepare the camera view to appear.
/// @discussion Perform this in the @c viewWillAppear:duration: method of the containing view controller.
- (void)willAppear;

/// Prepare the camera view to dissapear.
/// @discussion Perform this in the @c viewDidDisappear: method of the containing view controller.
- (void)didDisappear;

/// Rotate camera view.
/// @discussion Perform this in the @c willRotateToInterfaceOrientation:duration: method of the containing view contoller.
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation;

@end
