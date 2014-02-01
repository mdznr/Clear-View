//
//  CoreGraphicsAdditions.c
//  Camera
//
//  Created by Matt Zanchelli on 2/1/14.
//  Copyright (c) 2014 Matt Zanchelli. All rights reserved.
//

#import "CoreGraphicsAdditions.h"

CGRect CGRectWithZeroOrigin(CGRect rect)
{
	return (CGRect){CGPointZero, rect.size};
}
