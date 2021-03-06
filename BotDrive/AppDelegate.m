//
//  AppDelegate.m
//  BotDrive
//
//  Created by Rasmus Sten on 5.12.2019.
//  Copyright © 2019 Rasmus Sten. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()
{
}
- (IBAction)upAction:(id)sender;
- (IBAction)downAction:(id)sender;
- (IBAction)leftAction:(id)sender;
- (IBAction)rightAction:(id)sender;
@property NSMutableData* frameBuffer;
@property (weak) IBOutlet NSWindow *window;
@property NSOperationQueue* ioQueue;
@property NSURL* apiURL;
@property NSURLSessionDataTask* cameraStreamTask;
@end

@interface DLLBotWindow : NSWindow
@property AppDelegate* appDelegate;
@end

@implementation DLLBotWindow

- (void)keyDown:(NSEvent *)event {
    NSLog(@"keyDown: event=%@", event);
    switch (event.keyCode) {
        case 126:
            [self.appDelegate upAction:nil];
            break;
        case 125:
            [self.appDelegate downAction:nil];
            break;
        case 123:
            [self.appDelegate leftAction:nil];
            break;
        case 124:
            [self.appDelegate rightAction:nil];
            break;
    }
}

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    ((DLLBotWindow*)self.window).appDelegate = self;
    NSError* error;
    NSData* data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/.boturl", NSHomeDirectory()] options:0 error:&error];
    if (!data) {
        NSLog(@"Error reading bot URL: %@", error);
        [self sadStatus];
        return;
    }
    NSString* apiURLString = [[NSString stringWithUTF8String:data.bytes] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.apiURL = [NSURL URLWithString:apiURLString];;
    if (!self.apiURL) {
        NSLog(@"Failed to parse URL from %@", apiURLString);
        [self sadStatus];
        return;
    }
    [self updatestatus];
}


// MARK: request objects
- (NSURLRequest*)driveRequestWithLeftSpeed:(NSInteger) lspeed rightSpeed:(NSInteger) rspeed andDuration:(double) duration {
    NSURL* driveURL = [NSURL URLWithString:@"drive" relativeToURL:self.apiURL];
    NSMutableURLRequest* driveRequest = [NSMutableURLRequest requestWithURL:driveURL];
    NSDictionary* driveDict = @{ @"lspeed" : @(lspeed), @"rspeed" : @(rspeed), @"duration": @(duration) };
    NSError* error;
    NSData* driveJSON = [NSJSONSerialization dataWithJSONObject:driveDict options:0 error:&error];
    if (error) {
        NSLog(@"Blef: %@", error);
        return nil;
    }
    driveRequest.HTTPMethod = @"POST";
    driveRequest.HTTPBody = driveJSON;
    return driveRequest;
}

- (NSURLRequest*)imageRequestWIthImage:(NSImage*) image {
    CGImageRef cgRef = [image CGImageForProposedRect:NULL
                                             context:nil
                                               hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[image size]];
    NSData *pngData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    
    NSURL* url = [NSURL URLWithString:@"image" relativeToURL:self.apiURL];
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody = pngData;
    return req;
}

- (NSURLRequest*)statusRequest {
    NSURL* driveURL = [NSURL URLWithString:@"status" relativeToURL:self.apiURL];
    return [NSMutableURLRequest requestWithURL:driveURL];
}

- (NSURLRequest*)liftRequestWithHeight:(float) height{
    NSURL* driveURL = [NSURL URLWithString:@"lift" relativeToURL:self.apiURL];
    NSMutableURLRequest* driveRequest = [NSMutableURLRequest requestWithURL:driveURL];
    NSDictionary* driveDict = @{ @"height" : @(height) };
    NSError* error;
    NSData* driveJSON = [NSJSONSerialization dataWithJSONObject:driveDict options:0 error:&error];
    if (error) {
        NSLog(@"Blef: %@", error);
        return nil;
    }
    driveRequest.HTTPMethod = @"POST";
    driveRequest.HTTPBody = driveJSON;
    return driveRequest;
}

- (NSURLRequest*)tiltRequestWithHeight:(float) height{
    NSURL* driveURL = [NSURL URLWithString:@"tilt" relativeToURL:self.apiURL];
    NSMutableURLRequest* driveRequest = [NSMutableURLRequest requestWithURL:driveURL];
    driveRequest.HTTPMethod = @"POST";
    driveRequest.HTTPBody = [[NSString stringWithFormat:@"%0.2f", height] dataUsingEncoding:NSASCIIStringEncoding];
    return driveRequest;
}

- (NSURLRequest*)headLightRequest:(BOOL) enabled{
    NSURL* driveURL = [NSURL URLWithString:@"headlight" relativeToURL:self.apiURL];
    NSMutableURLRequest* driveRequest = [NSMutableURLRequest requestWithURL:driveURL];
    driveRequest.HTTPMethod = @"POST";
    driveRequest.HTTPBody = [[NSString stringWithFormat:@"%d", enabled] dataUsingEncoding:NSASCIIStringEncoding];
    return driveRequest;
}

- (void)sendRequst:(NSURLRequest*) driveRequest {
    NSURLSessionDataTask* driveTask = [[NSURLSession sharedSession] dataTaskWithRequest:driveRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"drive task response: %@", response);
    }];
    [driveTask resume];
}

- (void)sadStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.title = @"BotDrive 🥴";
    });
}

- (void)happyStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
         self.window.title = @"BotDrive ✅";
     });
}

- (void)updatestatus {
    NSURLSessionDataTask* statusTask = [[NSURLSession sharedSession] dataTaskWithRequest:[self statusRequest] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSelector:@selector(updatestatus) withObject:nil afterDelay:4.0];
        });
        if (!data) {
            NSLog(@"no status data!");
            if (error) {
                NSLog(@"status request error: %@", error);
                [self sadStatus];
            }
            return;
        }
        NSError* jsonError;
        NSDictionary* status = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!status) {
            NSLog(@"Error: %@", jsonError);
            return;
        }
        [self happyStatus];
 
        //NSLog(@"*** got status: %@", status);
        [self updateStatusFrom:status];
    }];
    [statusTask resume];
}

- (void)updateStatusFrom:(NSDictionary*) status {
    double headMax = [status[@"head_angle_max_rad"] doubleValue];
    double headMin = [status[@"head_angle_min_rad"] doubleValue];
    double headCurrent = [status[@"head_angle_rad"] doubleValue];
    double headSpan = headMax - headMin;
    double liftMax = [status[@"lift_height_max_mm"] doubleValue];
    double liftMin = [status[@"lift_height_min_mm"] doubleValue];
    double liftCurrent = [status[@"lift_height_mm"] doubleValue];
    double liftSpan = liftMax - liftMin;
    
    double liftFraction = liftSpan / (liftCurrent - liftMin);
    double headFraction = headSpan / (headCurrent - headMin);
/*
    dispatch_async(dispatch_get_main_queue(), ^{
        self.headSlider.doubleValue = headFraction;
        self.liftSlider.doubleValue = liftFraction;
    });*/
}

- (void)startStream {
    [self.cameraStreamTask cancel];
    NSURL* url = [NSURL URLWithString:@"stream.mjpg" relativeToURL:self.apiURL];
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    NSURLSessionDataTask* tak = [session dataTaskWithURL:url];
    [tak resume];
    self.cameraStreamTask = tak;
}

// MARK: UI actions
- (IBAction)headLightToggleAction:(NSSwitch*)sender {
    [self sendRequst:[self headLightRequest:sender.state == NSControlStateValueOn]];
}


- (IBAction)displayImageAction:(NSImageView*)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self sendRequst:[self imageRequestWIthImage:sender.image]];
    });
}

- (IBAction)stopStreamAction:(id)sender {
    [self.cameraStreamTask cancel];
}

- (IBAction)refreshAction:(id)sender {
    [self startStream];
}

- (IBAction)tiltAction:(NSSlider*)sender {
    NSLog(@"tilting to: %0.3f", sender.floatValue);
    [self sendRequst:[self tiltRequestWithHeight:sender.floatValue]];

}

- (IBAction)liftAction:(NSSlider*)sender {
    NSLog(@"lifting to: %0.3f", sender.floatValue);
    [self sendRequst:[self liftRequestWithHeight:sender.floatValue]];
}


- (IBAction)upAction:(id)sender {
    NSLog(@"speed: %d", self.speedKnob.intValue);
    NSURLRequest* driveRequest = [self driveRequestWithLeftSpeed:self.speedKnob.intValue rightSpeed:self.speedKnob.intValue andDuration:self.durationSlider.floatValue];
    [self sendRequst:driveRequest];
}

- (IBAction)rightAction:(id)sender {
    NSURLRequest* driveRequest = [self driveRequestWithLeftSpeed:self.speedKnob.intValue rightSpeed:-(self.speedKnob.intValue) andDuration:self.durationSlider.floatValue/3.0];
    [self sendRequst:driveRequest];
}

- (IBAction)downAction:(id)sender {
    NSURLRequest* driveRequest = [self driveRequestWithLeftSpeed:-(self.speedKnob.intValue) rightSpeed:-(self.speedKnob.intValue) andDuration:self.durationSlider.floatValue];
    [self sendRequst:driveRequest];
}

- (IBAction)leftAction:(id)sender {
    NSURLRequest* driveRequest = [self driveRequestWithLeftSpeed:-(self.speedKnob.intValue) rightSpeed:self.speedKnob.intValue andDuration:self.durationSlider.floatValue/3.0];
    [self sendRequst:driveRequest];
}


- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    const char* bytes = data.bytes;
    const char magic[] = { 0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46 };
    //NSLog(@"Got data (counter=%d) %@", self.counter, data);
    if (memcmp(bytes, magic, sizeof(magic)) == 0) {
        //NSLog(@"New frame! counter=%d", self.counter++);
        if (self.frameBuffer) {
            NSImage* image = [[NSImage alloc] initWithData:self.frameBuffer];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.cameraView.image = image;
            });
        }
        self.frameBuffer = [[NSMutableData alloc] initWithData:data];
    } else {
        //NSLog(@"Appending: counter: %d; will append %@ to %@", self.counter, data, self.frameBuffer);
        [self.frameBuffer appendData:data];
    }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
