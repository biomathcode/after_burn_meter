#import "AfterburnSensor.h"
#import <Security/Security.h>
#include <smartspectra/smartspectra.h>
#include <smartspectra/messages/metrics.h>
#include <atomic>
#include <algorithm>
#include <memory>
#include <mutex>
#include <vector>

namespace ss = presage::smartspectra;

@implementation ABCamera
@end
@implementation ABVital
@end

namespace {
struct Delivery {
    std::atomic<bool> active{true};
    std::atomic<bool> framePending{false};
    std::atomic<unsigned> frameCount{0};
    std::atomic<unsigned> accepted{0};
    std::atomic<unsigned> blocked{0};
    std::atomic<unsigned> packets{0};
};

void AddVital(NSMutableArray<ABVital *> *out, NSString *kind, double value,
              bool stable, int64_t timestamp, NSNumber *confidence = nil) {
    ABVital *reading = [ABVital new];
    reading.kind = kind; reading.value = value; reading.stable = stable;
    reading.timestamp = timestamp; reading.confidence = confidence;
    [out addObject:reading];
}

template <typename Series>
void AddSeries(NSMutableArray<ABVital *> *out, NSString *kind, const Series& series,
               bool withConfidence, bool latestOnly = false) {
    int start = std::max(0, series.size() - (latestOnly ? 1 : 120));
    for (int i = start; i < series.size(); ++i) {
        const auto& value = series.Get(i);
        NSNumber *confidence = nil;
        if constexpr (requires { value.confidence(); }) {
            if (withConfidence) confidence = @(value.confidence());
        }
        AddVital(out, kind, value.value(), value.stable(), value.timestamp(), confidence);
    }
}

NSArray<ABVital *> *ReadVitals(const ss::Metrics& metrics) {
    NSMutableArray<ABVital *> *out = [NSMutableArray array];
    if (metrics.has_cardio()) {
        const auto& cardio = metrics.cardio();
        AddSeries(out, @"pulse", cardio.pulse_rate(), true, true);
        AddSeries(out, @"arterial", cardio.arterial_pressure_trace(), true);
        if (!cardio.hrv().empty()) {
            const auto& hrv = cardio.hrv(cardio.hrv_size() - 1);
            AddVital(out, @"rmssd", hrv.rmssd(), hrv.stable(), hrv.timestamp(), @(hrv.confidence()));
            AddVital(out, @"sdnn", hrv.sdnn(), hrv.stable(), hrv.timestamp(), @(hrv.confidence()));
            AddVital(out, @"meanNN", hrv.mean_nn(), hrv.stable(), hrv.timestamp(), @(hrv.confidence()));
            AddVital(out, @"baevsky", hrv.baevsky(), hrv.stable(), hrv.timestamp(), @(hrv.confidence()));
        }
    }
    if (metrics.has_breathing()) {
        const auto& breathing = metrics.breathing();
        AddSeries(out, @"breathing", breathing.rate(), true, true);
        AddSeries(out, @"chest", breathing.upper_trace(), false);
        AddSeries(out, @"abdomen", breathing.lower_trace(), false);
    }
    if (metrics.has_eda()) AddSeries(out, @"eda", metrics.eda().trace(), false);
    return out;
}

uint8_t Channel(int value) { return static_cast<uint8_t>(std::clamp(value, 0, 255)); }

// Own a copy before returning from the SDK's borrowed-frame callback.
NSImage *CopyPreview(const ss::FrameBuffer& frame) {
    if (!frame.data || frame.width <= 0 || frame.height <= 0 || frame.stride_bytes <= 0 ||
        frame.width > 4096 || frame.height > 4096) return nil;
    const int width = frame.width, height = frame.height;
    std::vector<uint8_t> rgba(static_cast<size_t>(width) * height * 4);
    for (int y = 0; y < height; ++y) {
        const uint8_t *row = frame.data + y * frame.stride_bytes;
        for (int x = 0; x < width; ++x) {
            auto *out = rgba.data() + (static_cast<size_t>(y) * width + x) * 4;
            switch (frame.format) {
                case ss::PixelFormat::kRGB:
                case ss::PixelFormat::kBGR: {
                    bool rgb = frame.format == ss::PixelFormat::kRGB;
                    out[0] = row[x*3 + (rgb ? 0 : 2)]; out[1] = row[x*3+1];
                    out[2] = row[x*3 + (rgb ? 2 : 0)]; break;
                }
                case ss::PixelFormat::kRGBA:
                case ss::PixelFormat::kBGRA: {
                    bool rgb = frame.format == ss::PixelFormat::kRGBA;
                    out[0] = row[x*4 + (rgb ? 0 : 2)]; out[1] = row[x*4+1];
                    out[2] = row[x*4 + (rgb ? 2 : 0)]; break;
                }
                case ss::PixelFormat::kNV12:
                case ss::PixelFormat::kNV21:
                case ss::PixelFormat::kYUYV: {
                    int luminance, u, v;
                    if (frame.format == ss::PixelFormat::kYUYV) {
                        if (width % 2 != 0) return nil;
                        const auto *pair = row + (x / 2) * 4;
                        luminance = pair[(x % 2) * 2]; u = pair[1]; v = pair[3];
                    } else {
                        if (width % 2 != 0 || height % 2 != 0) return nil;
                        const auto *uv = frame.data + frame.stride_bytes * height +
                            (y / 2) * frame.stride_bytes + (x / 2) * 2;
                        bool nv12 = frame.format == ss::PixelFormat::kNV12;
                        luminance = row[x]; u = uv[nv12 ? 0 : 1]; v = uv[nv12 ? 1 : 0];
                    }
                    int c = std::max(0, luminance - 16), d = u - 128, e = v - 128;
                    out[0] = Channel((298*c + 409*e + 128) >> 8);
                    out[1] = Channel((298*c - 100*d - 208*e + 128) >> 8);
                    out[2] = Channel((298*c + 516*d + 128) >> 8); break;
                }
                default: return nil;
            }
            out[3] = 255;
        }
    }
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgba.data(), rgba.size());
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(width, height, 8, 32, width * 4, space,
        static_cast<CGBitmapInfo>(kCGImageAlphaNoneSkipLast) | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big), provider, nullptr, false,
        kCGRenderingIntentDefault);
    NSImage *result = image ? [[NSImage alloc] initWithCGImage:image size:NSMakeSize(width,height)] : nil;
    if (image) CGImageRelease(image);
    CGColorSpaceRelease(space); CGDataProviderRelease(provider); CFRelease(data);
    return result;
}
}

@implementation ABSensor {
    std::mutex mutex_;
    std::shared_ptr<ss::SmartSpectra> sdk_;
    std::shared_ptr<Delivery> delivery_;
    dispatch_queue_t workQueue_;
}

- (instancetype)init {
    if ((self = [super init])) {
        workQueue_ = dispatch_queue_create("app.afterburn.sensor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (NSString *)version { return @SMART_SPECTRA_VERSION_STRING; }

+ (BOOL)hasDevelopmentSignature {
    SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
    if (!task) return NO;
    CFTypeRef entitlement = SecTaskCopyValueForEntitlement(task,
        CFSTR("com.apple.developer.team-identifier"), nullptr);
    BOOL valid = entitlement && CFGetTypeID(entitlement) == CFStringGetTypeID() &&
        CFStringGetLength((CFStringRef)entitlement) > 0;
    if (entitlement) CFRelease(entitlement);
    CFRelease(task);
    return valid;
}

+ (NSArray<ABCamera *> *)cameras {
    std::vector<ss::CameraInfo> devices;
    if (!ss::SmartSpectra::AvailableCameras(devices).ok()) return @[];
    NSMutableArray *result = [NSMutableArray array];
    for (const auto& camera : devices) {
        ABCamera *value = [ABCamera new];
        value.identifier = [NSString stringWithUTF8String:camera.id.c_str()];
        value.name = camera.name ? [NSString stringWithUTF8String:camera.name->c_str()] : @"Camera";
        [result addObject:value];
    }
    return result;
}

- (void)startWithAPIKey:(NSString *)apiKey cameraID:(NSString *)cameraID {
    [self stop];
    auto delivery = std::make_shared<Delivery>();
    {
        std::lock_guard lock(mutex_);
        delivery_ = delivery;
    }
    __weak ABSensor *weakSelf = self;
    dispatch_async(workQueue_, ^{
        @autoreleasepool {
            if (!delivery->active) return;
            // Relative paths in the vendor manifest are resolved consistently
            // both from the dylib directory and from the process working dir.
            NSString *frameworks = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"SmartSpectraRuntime"];
            if (frameworks) [[NSFileManager defaultManager] changeCurrentDirectoryPath:frameworks];
            NSString *cache = [NSHomeDirectory() stringByAppendingPathComponent:
                @"Library/Application Support/Afterburn/SDK"];
            NSError *directoryError;
            [[NSFileManager defaultManager] createDirectoryAtPath:cache
                withIntermediateDirectories:YES attributes:nil error:&directoryError];
            auto fail = [weakSelf, delivery](NSString *message) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ABSensor *owner = weakSelf;
                    if (delivery->active && owner.onError) owner.onError(message);
                });
            };
            if (directoryError) { fail(@"Cannot create the local sensor cache."); return; }
            if (auto error = ss::Preconfigure(cache.UTF8String); !error.ok()) {
                fail([NSString stringWithUTF8String:error.FullMessage().c_str()]); return;
            }
            ss::SmartSpectraConfig config;
            config.api_key = std::string(apiKey.UTF8String);
            // Match the vendor's macOS example: the public physiological bundles.
            // Do not request unavailable metrics or the experimental BP stand-in.
            config.requested_metrics = ss::SmartSpectraConfig::BreathingMetrics();
            config.AddMetrics(ss::SmartSpectraConfig::CardioMetrics());
            config.AddMetrics(ss::SmartSpectraConfig::EdaMetrics());
            config.enable_telemetry = false;
            config.enable_accumulated_output = false;
            config.log_level = ss::SmartSpectraLogLevel::kNone;
            // No Insights callback/requests, recording directory, or face analysis.
            auto sdk = std::make_shared<ss::SmartSpectra>(config);
            sdk->SetOnProcessingStatusChanged([weakSelf, delivery](ss::ProcessingStatus status) {
                NSString *value = [NSString stringWithUTF8String:ss::ToString(status)];
                dispatch_async(dispatch_get_main_queue(), ^{
                    ABSensor *owner = weakSelf;
                    if (delivery->active && owner.onProcessing) owner.onProcessing(value);
                });
            });
            sdk->SetOnValidationStatusChanged([weakSelf, delivery](const ss::ValidationStatus& status, int64_t) {
                NSInteger code = static_cast<NSInteger>(status.code);
                NSString *hint = [NSString stringWithUTF8String:status.hint.c_str()];
                dispatch_async(dispatch_get_main_queue(), ^{
                    ABSensor *owner = weakSelf;
                    if (delivery->active && owner.onValidation) owner.onValidation(code, hint);
                });
            });
            sdk->SetOnMetrics([weakSelf, delivery](const ss::Metrics& metrics, int64_t timestamp) {
                if (!delivery->active) return;
                ++delivery->packets;
                NSArray<ABVital *> *readings = ReadVitals(metrics);
                dispatch_async(dispatch_get_main_queue(), ^{
                    ABSensor *owner = weakSelf;
                    if (delivery->active && owner.onMetrics) owner.onMetrics(readings, timestamp);
                });
            });
            sdk->SetOnFrameSentThrough([weakSelf, delivery](bool accepted, int64_t) {
                if (!delivery->active) return;
                if (accepted) ++delivery->accepted; else ++delivery->blocked;
                unsigned total = delivery->accepted + delivery->blocked;
                if (total % 30 != 0) return;
                unsigned good = delivery->accepted, bad = delivery->blocked, packets = delivery->packets;
                dispatch_async(dispatch_get_main_queue(), ^{
                    ABSensor *owner = weakSelf;
                    if (delivery->active && owner.onDiagnostics) owner.onDiagnostics(good, bad, packets);
                });
            });
            sdk->SetOnVideoOutput([weakSelf, delivery](const ss::FrameBuffer& frame, int64_t) {
                if (!delivery->active || ++delivery->frameCount % 2 != 0 ||
                    delivery->framePending.exchange(true)) return;
                @autoreleasepool {
                    NSImage *image = CopyPreview(frame);
                    if (!image) { delivery->framePending = false; return; }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        ABSensor *owner = weakSelf;
                        if (delivery->active && owner.onFrame) owner.onFrame(image);
                        delivery->framePending = false;
                    });
                }
            });
            sdk->SetOnError([fail](const ss::SmartSpectraError& error) {
                fail([NSString stringWithUTF8String:error.FullMessage().c_str()]);
            });
            auto selection = cameraID.length > 0
                ? ss::CameraSelection::ById(cameraID.UTF8String) : ss::CameraSelection::Default();
            if (auto error = sdk->UseCamera(selection).SetResolution(1280,720).SetFps(30).Build(); !error.ok()) {
                fail([NSString stringWithUTF8String:error.FullMessage().c_str()]); return;
            }
            ABSensor *owner = weakSelf;
            if (!owner || !delivery->active) return;
            {
                std::lock_guard lock(owner->mutex_);
                if (!delivery->active) return;
                owner->sdk_ = sdk;
            }
            if (auto error = sdk->Start(); !error.ok()) {
                fail([NSString stringWithUTF8String:error.FullMessage().c_str()]);
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ABSensor *current = weakSelf;
                    if (delivery->active && current.onState) current.onState(@"Measuring");
                });
            }
            if (!delivery->active) (void)sdk->Stop();
        }
    });
}

- (void)stop {
    [self stopWithCompletion:nil];
}

- (void)stopWithCompletion:(void (^)(void))completion {
    std::shared_ptr<ss::SmartSpectra> previous;
    {
        std::lock_guard lock(mutex_);
        if (delivery_) delivery_->active = false;
        previous = std::move(sdk_);
        delivery_.reset();
    }
    dispatch_async(workQueue_, ^{
        if (previous) (void)previous->Stop();
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
    });
}

- (void)dealloc { [self stop]; }
@end

