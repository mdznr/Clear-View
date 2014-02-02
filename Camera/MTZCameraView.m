//
//  MTZCameraView.m
//  Camera
//
//  Created by Matt Zanchelli on 1/30/14.
//  Copyright (c) 2014 Matt Zanchelli. All rights reserved.
//

//  Using some sample code from Apple:
/*
 File: AVCamViewController.m
 Abstract: View controller for camera interface.
 Version: 3.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import "MTZCameraView.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import "AVCamPreviewView.h"
#import "CoreGraphicsAdditions.h"

#define PICTURE_DELAY 0.8f

static void *CapturingStillImageContext = &CapturingStillImageContext;
static void *RecordingContext = &RecordingContext;
static void *SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;
static void *PreviewLayerConnectionContext = &PreviewLayerConnectionContext;

@interface MTZCameraView ()

@property (strong, nonatomic) NSTimer *timer;

@property (strong, nonatomic) AVCamPreviewView *previewView;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) id runtimeErrorHandlingObserver;

@end

@implementation MTZCameraView


#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self MTZCameraView_setup];
		_previewView.frame = CGRectWithZeroOrigin(frame);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self MTZCameraView_setup];
	}
	return self;
}

- (id)init
{
	self = [super init];
	if (self) {
		[self MTZCameraView_setup];
	}
	return self;
}

- (void)MTZCameraView_setup
{
	_previewView = [[AVCamPreviewView alloc] initWithFrame:CGRectWithZeroOrigin(self.frame)];
	_previewView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	_previewView.videoGravity = AVLayerVideoGravityResizeAspectFill;
	[self addSubview:_previewView];
}


#pragma mark - Properties

- (void)setCameraOrientation:(AVCaptureVideoOrientation)cameraOrientation
{
	_cameraOrientation = cameraOrientation;
	
	if ( [self canSetCameraOrientationNow] ) {
		[self setCameraOrientationNow:cameraOrientation];
	} else {
		[self setCameraOrientationWhenReady:cameraOrientation];
	}
}

- (BOOL)canSetCameraOrientationNow
{
	return ((AVCaptureVideoPreviewLayer *)self.previewView.layer).connection != nil;
}

- (void)setCameraOrientationNow:(AVCaptureVideoOrientation)cameraOrientation
{
	((AVCaptureVideoPreviewLayer *)self.previewView.layer).connection.videoOrientation = cameraOrientation;
}

- (void)setCameraOrientationWhenReady:(AVCaptureVideoOrientation)orientation
{
	// Watch for connection
	[self.previewView.layer addObserver:self
							 forKeyPath:NSStringFromSelector(@selector(connection))
								options:NSKeyValueObservingOptionNew
								context:PreviewLayerConnectionContext];
}

- (void)previewLayersConnectionIsNowReady
{
	// Stop observing connection
	[self.previewView.layer removeObserver:self
								forKeyPath:NSStringFromSelector(@selector(connection))
								   context:PreviewLayerConnectionContext];
	
	// Set orientation
	[self setCameraOrientationNow:self.cameraOrientation];
}


#pragma mark - Public API

- (void)loadCam;
{
	// Create the AVCaptureSession
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	self.session = session;
	
	// Setup the preview view
	self.previewView.session = session;
	
	// Check for device authorization
	[self checkDeviceAuthorizationStatus];
	
	// Dispatch the rest of session setup to the sessionQueue so that the main queue isn't blocked.
	dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	self.sessionQueue = sessionQueue;
	
	dispatch_async(sessionQueue, ^{
		self.backgroundRecordingID = UIBackgroundTaskInvalid;
		
		NSError *error = nil;
		
		AVCaptureDevice *videoDevice = [MTZCameraView deviceWithMediaType:AVMediaTypeVideo
													   preferringPosition:AVCaptureDevicePositionBack];
		
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice
																					   error:&error];
		
		if ( !videoDeviceInput ) {
			NSLog(@"%@", error);
		}
		
		if ( [session canAddInput:videoDeviceInput] ) {
			[session addInput:videoDeviceInput];
			self.videoDeviceInput = videoDeviceInput;
		}
		
		AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
		if ( [session canAddOutput:stillImageOutput] ) {
			stillImageOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
			[session addOutput:stillImageOutput];
			self.stillImageOutput = stillImageOutput;
		}
	});
}

- (void)willAppear
{
	dispatch_async([self sessionQueue], ^{
		[self addObserver:self
			   forKeyPath:@"sessionRunningAndDeviceAuthorized"
				  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
				  context:SessionRunningAndDeviceAuthorizedContext];
		
		[self addObserver:self
			   forKeyPath:@"stillImageOutput.capturingStillImage"
				  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
				  context:CapturingStillImageContext];
		
		[self addObserver:self
			   forKeyPath:@"movieFileOutput.recording"
				  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
				  context:RecordingContext];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(subjectAreaDidChange:)
													 name:AVCaptureDeviceSubjectAreaDidChangeNotification
												   object:self.videoDeviceInput.device];
		
		__weak MTZCameraView *weakSelf = self;
		[self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:self.session queue:nil usingBlock:^(NSNotification *note) {
			MTZCameraView *strongSelf = weakSelf;
			dispatch_async(strongSelf.sessionQueue, ^{
				// Manually restarting the session since it must have been stopped due to an error.
				[strongSelf.session startRunning];
			});
		}]];
		[self.session startRunning];
	});
}

- (void)didDisappear
{
	dispatch_async([self sessionQueue], ^{
		[self.session stopRunning];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:AVCaptureDeviceSubjectAreaDidChangeNotification
													  object:self.videoDeviceInput.device];
		
		[[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
		
		[self removeObserver:self
				  forKeyPath:@"sessionRunningAndDeviceAuthorized"
					 context:SessionRunningAndDeviceAuthorizedContext];
		
		[self removeObserver:self
				  forKeyPath:@"stillImageOutput.capturingStillImage"
					 context:CapturingStillImageContext];
		
		[self removeObserver:self
				  forKeyPath:@"movieFileOutput.recording"
					 context:RecordingContext];
	});
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	self.cameraOrientation = (AVCaptureVideoOrientation) toInterfaceOrientation;
}

- (void)focusOnPoint:(CGPoint)point
{
	CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)self.previewView.layer captureDevicePointOfInterestForPoint:point];
	[self focusWithMode:AVCaptureFocusModeAutoFocus
		 exposeWithMode:AVCaptureExposureModeAutoExpose
		  atDevicePoint:devicePoint
monitorSubjectAreaChange:NO];
}

- (void)takePhoto
{
	[self snapStillImage:self];
}


#pragma mark - Delegate Methods

- (void)handleSnappedImage:(UIImage *)image
{
	[self.delegate cameraView:self didTakePhoto:image];
}


#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	if ( context == CapturingStillImageContext ) {
		BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
		
		if ( isCapturingStillImage ) {
			//[self runStillImageCaptureAnimation];
		}
	} else if ( context == RecordingContext ) {
//		BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
	} else if ( context == SessionRunningAndDeviceAuthorizedContext ) {
//		BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
	} else if ( context == PreviewLayerConnectionContext ) {
		[self previewLayersConnectionIsNowReady];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark - Actions

- (IBAction)snapStillImage:(id)sender
{
	dispatch_async([self sessionQueue], ^{
		// Update the orientation on the still image output video connection before capturing.
		[self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation = ((AVCaptureVideoPreviewLayer *)self.previewView.layer).connection.videoOrientation;
		
		// Flash set to Auto for Still Capture
		[MTZCameraView setFlashMode:AVCaptureFlashModeOff
						  forDevice:self.videoDeviceInput.device];
		
		// Capture a still image.
		[self.stillImageOutput captureStillImageAsynchronouslyFromConnection:[self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo]
														   completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
															   if ( imageDataSampleBuffer ) {
																   NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
																   UIImage *image = [[UIImage alloc] initWithData:imageData];
																   [self handleSnappedImage:image];
															   }
														   }];
	});
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
	CGPoint devicePoint = CGPointMake(.5, .5);
	[self focusWithMode:AVCaptureFocusModeContinuousAutoFocus
		 exposeWithMode:AVCaptureExposureModeContinuousAutoExposure
		  atDevicePoint:devicePoint
monitorSubjectAreaChange:NO];
}


#pragma mark -

- (void)checkDeviceAuthorizationStatus
{
	NSString *mediaType = AVMediaTypeVideo;
	
	[AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
		if ( granted ) {
			//Granted access to mediaType
			self.deviceAuthorized = YES;
		} else {
			//Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"AVCam!"
											message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
										   delegate:self
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil] show];
				self.deviceAuthorized = NO;
			});
		}
	}];
}


#pragma mark Device Configuration

- (void)focusWithMode:(AVCaptureFocusMode)focusMode
	   exposeWithMode:(AVCaptureExposureMode)exposureMode
		atDevicePoint:(CGPoint)point
monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
	dispatch_async([self sessionQueue], ^{
		AVCaptureDevice *device = self.videoDeviceInput.device;
		NSError *error = nil;
		if ( [device lockForConfiguration:&error] ) {
			if ( device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode] ) {
				device.focusMode = focusMode;
				device.focusPointOfInterest = point;
			}
			if ( device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode] ) {
				device.exposureMode = exposureMode;
				device.exposurePointOfInterest = point;
			}
			device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
			[device unlockForConfiguration];
		} else {
			NSLog(@"%@", error);
		}
	});
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
	if ( device.hasFlash && [device isFlashModeSupported:flashMode] ) {
		NSError *error = nil;
		if ( [device lockForConfiguration:&error] ) {
			device.flashMode = flashMode;
			[device unlockForConfiguration];
		} else {
			NSLog(@"%@", error);
		}
	}
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = [devices firstObject];
	
	for ( AVCaptureDevice *device in devices ) {
		if ( device.position == position ) {
			captureDevice = device;
			break;
		}
	}
	
	return captureDevice;
}

@end
