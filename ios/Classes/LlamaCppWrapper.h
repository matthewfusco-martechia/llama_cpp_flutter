#ifndef LlamaCppWrapper_h
#define LlamaCppWrapper_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Configuration for loading a llama.cpp model
@interface LlamaCppConfig : NSObject

@property(nonatomic, strong) NSString *modelPath;
@property(nonatomic, assign) int32_t contextLength;
@property(nonatomic, assign) int32_t nGpuLayers;
@property(nonatomic, assign) int32_t maxTokens;
@property(nonatomic, assign) float temperature;
@property(nonatomic, assign) float topP;
@property(nonatomic, assign) float repeatPenalty;
@property(nonatomic, strong, nullable) NSString *systemPrompt;

- (instancetype)initWithModelPath:(NSString *)modelPath
                    contextLength:(int32_t)contextLength
                       nGpuLayers:(int32_t)nGpuLayers
                        maxTokens:(int32_t)maxTokens
                      temperature:(float)temperature
                             topP:(float)topP
                    repeatPenalty:(float)repeatPenalty
                     systemPrompt:(nullable NSString *)systemPrompt;

@end

/// Callback for streaming tokens
/// @param token The generated token (nil if done or error)
/// @param isDone Whether generation is complete
/// @param error Error message if any
typedef void (^LlamaTokenCallback)(NSString *_Nullable token, BOOL isDone,
                                   NSString *_Nullable error);

/// Callback for model loading
/// @param success Whether loading succeeded
/// @param error Error message if failed
typedef void (^LlamaLoadCallback)(BOOL success, NSString *_Nullable error);

/// Wrapper for llama.cpp inference on iOS
///
/// This class provides a thread-safe interface to llama.cpp with:
/// - Metal GPU acceleration
/// - Streaming token generation
/// - Clean cancellation
/// - Memory-safe design
@interface LlamaCppWrapper : NSObject

/// Whether a model is currently loaded
@property(nonatomic, readonly) BOOL isModelLoaded;

/// Whether generation is in progress
@property(nonatomic, readonly) BOOL isGenerating;

/// Load a GGUF model with the given configuration
/// @param config Model configuration
/// @param completion Callback when loading completes
- (void)loadModelWithConfig:(LlamaCppConfig *)config
                 completion:(LlamaLoadCallback)completion;

/// Stream a response for the given prompt
/// @param prompt User input text
/// @param systemPrompt Optional system prompt override
/// @param history Conversation history (array of {role, content} dicts)
/// @param tokenCallback Callback for each generated token
- (void)streamResponse:(NSString *)prompt
          systemPrompt:(nullable NSString *)systemPrompt
               history:
                   (NSArray<NSDictionary<NSString *, NSString *> *> *)history
         tokenCallback:(LlamaTokenCallback)tokenCallback;

/// Stop the current generation
- (void)stopGeneration;

/// Unload the current model and free resources
- (void)unloadModel;

@end

NS_ASSUME_NONNULL_END

#endif /* LlamaCppWrapper_h */
