//
//  MTZCameraView.h
//  Camera
//
//  Created by Matt Zanchelli on 1/30/14.
//  Copyright (c) 2014 Matt Zanchelli. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class MTZCameraView;

@protocol MTZCameraViewDelegate

@optional

/// Tells the delegate that the user snapped a still image.
/// @param cameraView The camera view that took the photo.
/// @param image The resulting image from the capture.
/// @discussion Implementation of this method is optional, but expected.
- (void)cameraView:(MTZCameraView *)cameraView didTakePhoto:(UIImage *)image;

@end

@interface MTZCameraView : UIView


#pragma mark - Properties

/// The camera view's delegate object.
@property (nonatomic, assign) id<MTZCameraViewDelegate> delegate;

/// The orientation of the camera.
#warning AVCaptureVideoOrientation or UIInterfaceOrientation?
@property (nonatomic) AVCaptureVideoOrientation cameraOrientation;


#pragma mark -

/// Load the camera.
/// @discussion Perform this in the @c viewDidLoad: method of the containing view controller.
#warning Should this be done automatically?
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


#pragma mark - Camera Settings

/// Focus the camera on a point in the preview.
/// @param point The point in the camera view at which to focus.
/// @dicussion Locks focus afterwards.
- (void)focusOnPoint:(CGPoint)point;


#pragma mark -

/// Take a photo.
- (void)takePhoto;

@end
