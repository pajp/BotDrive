//
//  AppDelegate.h
//  BotDrive
//
//  Created by Rasmus Sten on 5.12.2019.
//  Copyright © 2019 Rasmus Sten. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSURLSessionDelegate, NSURLSessionDataDelegate>

@property int counter;
@property (weak) IBOutlet NSImageView *cameraView;
@property (weak) IBOutlet NSSlider *speedKnob;
@property (weak) IBOutlet NSSlider *liftSlider;
@property (weak) IBOutlet NSSlider *headSlider;
@property (weak) IBOutlet NSSlider *durationSlider;

@end

