#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ABCamera : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@end

@interface ABVital : NSObject
@property(nonatomic, copy) NSString *kind;
@property(nonatomic) double value;
@property(nonatomic, strong, nullable) NSNumber *confidence;
@property(nonatomic) BOOL stable;
@property(nonatomic) int64_t timestamp;
@end

/// All callbacks are delivered on the main queue. Start/stop never block the UI.
@interface ABSensor : NSObject
@property(nonatomic, copy, nullable) void (^onFrame)(NSImage *image);
@property(nonatomic, copy, nullable) void (^onMetrics)(NSArray<ABVital *> *readings, int64_t timestamp);
@property(nonatomic, copy, nullable) void (^onDiagnostics)(NSUInteger accepted, NSUInteger blocked, NSUInteger packets);
@property(nonatomic, copy, nullable) void (^onProcessing)(NSString *status);
@property(nonatomic, copy, nullable) void (^onValidation)(NSInteger code, NSString *hint);
@property(nonatomic, copy, nullable) void (^onState)(NSString *state);
@property(nonatomic, copy, nullable) void (^onError)(NSString *message);
+ (NSString *)version;
+ (BOOL)hasDevelopmentSignature;
+ (NSArray<ABCamera *> *)cameras;
- (void)startWithAPIKey:(NSString *)apiKey cameraID:(nullable NSString *)cameraID;
- (void)stop;
- (void)stopWithCompletion:(void (^ _Nullable)(void))completion;
@end

NS_ASSUME_NONNULL_END

