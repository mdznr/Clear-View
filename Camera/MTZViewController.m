//
//  MTZViewController.m
//  Camera
//
//  Created by Matt Zanchelli on 1/29/14.
//  Copyright (c) 2014 Matt Zanchelli. All rights reserved.
//

#import "MTZViewController.h"

#import "MTZCameraView.h"

@interface MTZViewController () <MTZCameraViewDelegate>

@property (weak, nonatomic) IBOutlet MTZCameraView *cameraView;

@end

@implementation MTZViewController


#pragma mark - View Events

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	_cameraView.delegate = self;
	[_cameraView loadCam];
	_cameraView.cameraOrientation = self.interfaceOrientation;
	
	// Load UI on left, right, or bottom side depending on preference
	// Link to open this app from Keynote? (Tap on "Demo")?
	// Button to open Keynote? (Just in case)
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[_cameraView willAppear];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	[_cameraView didDisappear];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[_cameraView willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation];
}


#pragma mark - Gesture Recognizers

- (IBAction)didTap:(UITapGestureRecognizer *)sender
{
	NSLog(@"Did Tap");
	// Focus (and lock) on tapped region
	[_cameraView focusOnPoint:[sender locationInView:_cameraView]];
}

- (IBAction)didLongPress:(UILongPressGestureRecognizer *)sender
{
	NSLog(@"Did Long Press");
	// Unlock focus lock
}

- (IBAction)didPan:(UIPanGestureRecognizer *)sender
{
	NSLog(@"Did Pan");
	// Up/down to increase/down exposure
}


#pragma mark - Camera View Delegate

- (void)cameraView:(MTZCameraView *)cameraView didTakePhoto:(UIImage *)image
{
	NSLog(@"Took photo: %@", image);
}


#pragma mark - View Controller Misc.

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
