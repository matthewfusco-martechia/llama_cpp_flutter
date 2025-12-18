//
//  LlamaCppWrapper.mm
//  llama_cpp_flutter
//
//  llama.cpp Objective-C++ wrapper for Flutter plugin
//

#import "LlamaCppWrapper.h"
#import <dispatch/dispatch.h>
#import <stdatomic.h>

// Include llama.cpp headers from the vendored framework
#if __has_include(<llama/llama.h>)
#import <llama/llama.h>
#define LLAMA_AVAILABLE 1
#elif __has_include("llama.h")
#import "llama.h"
#define LLAMA_AVAILABLE 1
#else
#define LLAMA_AVAILABLE 0
#warning "llama.h not found - plugin will return stub responses"
#endif

#pragma mark - LlamaCppConfig Implementation

@implementation LlamaCppConfig

- (instancetype)initWithModelPath:(NSString *)modelPath
                    contextLength:(int32_t)contextLength
                       nGpuLayers:(int32_t)nGpuLayers
                        maxTokens:(int32_t)maxTokens
                      temperature:(float)temperature
                             topP:(float)topP
                    repeatPenalty:(float)repeatPenalty
                     systemPrompt:(nullable NSString *)systemPrompt {
  self = [super init];
  if (self) {
    _modelPath = modelPath;
    _contextLength = contextLength;
    _nGpuLayers = nGpuLayers;
    _maxTokens = maxTokens;
    _temperature = temperature;
    _topP = topP;
    _repeatPenalty = repeatPenalty;
    _systemPrompt = systemPrompt;
  }
  return self;
}

@end

#pragma mark - LlamaCppWrapper Private Interface

@interface LlamaCppWrapper () {
#if LLAMA_AVAILABLE
  llama_model *_model;
  llama_context *_ctx;
  llama_sampler *_sampler;
  const llama_vocab *_vocab;
#endif
  LlamaCppConfig *_currentConfig;
  atomic_bool _shouldStop;
  dispatch_queue_t _inferenceQueue;
  BOOL _isGenerating;
}
@end

#pragma mark - LlamaCppWrapper Implementation

@implementation LlamaCppWrapper

- (instancetype)init {
  self = [super init];
  if (self) {
#if LLAMA_AVAILABLE
    _model = NULL;
    _ctx = NULL;
    _sampler = NULL;
    _vocab = NULL;
    llama_backend_init();
    NSLog(@"🦙 [LlamaCppWrapper] Backend initialized");
#endif
    _currentConfig = nil;
    atomic_init(&_shouldStop, false);
    _isGenerating = NO;
    _inferenceQueue = dispatch_queue_create("com.llamacppflutter.inference",
                                            DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)dealloc {
  [self unloadModel];
#if LLAMA_AVAILABLE
  llama_backend_free();
  NSLog(@"🦙 [LlamaCppWrapper] Backend freed");
#endif
}

- (BOOL)isModelLoaded {
#if LLAMA_AVAILABLE
  return _model != NULL && _ctx != NULL;
#else
  return NO;
#endif
}

- (BOOL)isGenerating {
  return _isGenerating;
}

#pragma mark - Model Loading

- (void)loadModelWithConfig:(LlamaCppConfig *)config
                 completion:(LlamaLoadCallback)completion {
#if LLAMA_AVAILABLE
  dispatch_async(_inferenceQueue, ^{
    @autoreleasepool {
      NSLog(@"🦙 [LlamaCppWrapper] Loading model: %@", config.modelPath);

      // Unload any existing model
      [self unloadModelInternal];

      // Check file exists
      if (![[NSFileManager defaultManager] fileExistsAtPath:config.modelPath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          completion(NO, @"Model file not found");
        });
        return;
      }

      // Configure model parameters
      llama_model_params model_params = llama_model_default_params();
      model_params.n_gpu_layers = config.nGpuLayers;

      // Load model
      self->_model = llama_model_load_from_file([config.modelPath UTF8String],
                                                model_params);

      if (!self->_model) {
        dispatch_async(dispatch_get_main_queue(), ^{
          completion(NO, @"Failed to load model");
        });
        return;
      }

      // Get vocabulary
      self->_vocab = llama_model_get_vocab(self->_model);

      // Configure context
      llama_context_params ctx_params = llama_context_default_params();
      ctx_params.n_ctx = config.contextLength;
      ctx_params.n_threads = 4;
      ctx_params.n_threads_batch = 4;
      ctx_params.n_batch = 512;

      // Create context
      self->_ctx = llama_init_from_model(self->_model, ctx_params);

      if (!self->_ctx) {
        llama_model_free(self->_model);
        self->_model = NULL;
        dispatch_async(dispatch_get_main_queue(), ^{
          completion(NO, @"Failed to create context");
        });
        return;
      }

      // Configure sampler chain
      llama_sampler_chain_params sp = llama_sampler_chain_default_params();
      self->_sampler = llama_sampler_chain_init(sp);
      llama_sampler_chain_add(self->_sampler, llama_sampler_init_top_k(40));
      llama_sampler_chain_add(self->_sampler,
                              llama_sampler_init_top_p(config.topP, 1));
      llama_sampler_chain_add(self->_sampler,
                              llama_sampler_init_temp(config.temperature));
      llama_sampler_chain_add(self->_sampler,
                              llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

      self->_currentConfig = config;

      NSLog(@"🦙 [LlamaCppWrapper] Model loaded successfully");

      dispatch_async(dispatch_get_main_queue(), ^{
        completion(YES, nil);
      });
    }
  });
#else
  dispatch_async(dispatch_get_main_queue(), ^{
    completion(NO, @"llama.cpp not linked");
  });
#endif
}

#pragma mark - Model Unloading

- (void)unloadModel {
#if LLAMA_AVAILABLE
  dispatch_sync(_inferenceQueue, ^{
    [self unloadModelInternal];
  });
#endif
}

- (void)unloadModelInternal {
#if LLAMA_AVAILABLE
  NSLog(@"🦙 [LlamaCppWrapper] Unloading model");

  if (_sampler) {
    llama_sampler_free(_sampler);
    _sampler = NULL;
  }
  if (_ctx) {
    llama_free(_ctx);
    _ctx = NULL;
  }
  if (_model) {
    llama_model_free(_model);
    _model = NULL;
  }
  _vocab = NULL;
  _currentConfig = nil;
#endif
}

#pragma mark - Text Generation

- (void)streamResponse:(NSString *)prompt
          systemPrompt:(nullable NSString *)systemPrompt
               history:
                   (NSArray<NSDictionary<NSString *, NSString *> *> *)history
         tokenCallback:(LlamaTokenCallback)tokenCallback {
#if LLAMA_AVAILABLE
  if (!self.isModelLoaded) {
    tokenCallback(nil, YES, @"No model loaded");
    return;
  }

  if (_isGenerating) {
    tokenCallback(nil, YES, @"Generation already in progress");
    return;
  }

  atomic_store(&_shouldStop, false);
  _isGenerating = YES;

  dispatch_async(_inferenceQueue, ^{
    @autoreleasepool {
      // Build prompt with ChatML format (Qwen/Llama compatible)
      NSMutableString *fullPrompt = [NSMutableString string];

      NSString *sysPrompt = systemPrompt ?: self->_currentConfig.systemPrompt;
      if (sysPrompt.length > 0) {
        [fullPrompt
            appendFormat:@"<|im_start|>system\n%@<|im_end|>\n", sysPrompt];
      }

      for (NSDictionary *msg in history) {
        NSString *role = msg[@"role"];
        NSString *content = msg[@"content"];
        if ([role isEqualToString:@"user"]) {
          [fullPrompt
              appendFormat:@"<|im_start|>user\n%@<|im_end|>\n", content];
        } else if ([role isEqualToString:@"assistant"]) {
          [fullPrompt
              appendFormat:@"<|im_start|>assistant\n%@<|im_end|>\n", content];
        }
      }

      [fullPrompt
          appendFormat:
              @"<|im_start|>user\n%@<|im_end|>\n<|im_start|>assistant\n",
              prompt];

      const char *promptCStr = [fullPrompt UTF8String];
      int32_t text_len = (int32_t)strlen(promptCStr);

      // Get required token count
      int32_t n_prompt = llama_tokenize(self->_vocab, promptCStr, text_len,
                                        NULL, 0, true, true);
      if (n_prompt < 0) {
        n_prompt = -n_prompt;
      }

      if (n_prompt == 0) {
        self->_isGenerating = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
          tokenCallback(nil, YES, @"Empty prompt");
        });
        return;
      }

      // Tokenize
      llama_token *tokens =
          (llama_token *)malloc(sizeof(llama_token) * n_prompt);
      int32_t actual_tokens = llama_tokenize(self->_vocab, promptCStr, text_len,
                                             tokens, n_prompt, true, true);

      if (actual_tokens < 0) {
        free(tokens);
        self->_isGenerating = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
          tokenCallback(nil, YES, @"Tokenization failed");
        });
        return;
      }

      // Clear KV cache
      llama_memory_t memory = llama_get_memory(self->_ctx);
      llama_memory_clear(memory, true);

      // Process prompt
      llama_batch batch = llama_batch_get_one(tokens, actual_tokens);
      if (llama_decode(self->_ctx, batch) != 0) {
        free(tokens);
        self->_isGenerating = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
          tokenCallback(nil, YES, @"Prompt decode failed");
        });
        return;
      }

      free(tokens);

      // Generate tokens
      int maxTokens = self->_currentConfig.maxTokens;
      int generated = 0;

      while (generated < maxTokens) {
        if (atomic_load(&self->_shouldStop)) {
          break;
        }

        llama_token new_token =
            llama_sampler_sample(self->_sampler, self->_ctx, -1);

        // Check for end of generation
        if (llama_vocab_is_eog(self->_vocab, new_token)) {
          break;
        }

        // Convert token to text
        char buf[256];
        int32_t n = llama_token_to_piece(self->_vocab, new_token, buf,
                                         sizeof(buf), 0, true);

        if (n > 0) {
          NSString *piece =
              [[NSString alloc] initWithBytes:buf
                                       length:n
                                     encoding:NSUTF8StringEncoding];
          if (piece) {
            dispatch_async(dispatch_get_main_queue(), ^{
              tokenCallback(piece, NO, nil);
            });
          }
        }

        // Decode next token
        llama_batch next_batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(self->_ctx, next_batch) != 0) {
          break;
        }

        generated++;
      }

      self->_isGenerating = NO;

      dispatch_async(dispatch_get_main_queue(), ^{
        tokenCallback(nil, YES, nil);
      });
    }
  });
#else
  tokenCallback(nil, YES, @"llama.cpp not available");
#endif
}

#pragma mark - Stop Generation

- (void)stopGeneration {
  atomic_store(&_shouldStop, true);
  NSLog(@"🦙 [LlamaCppWrapper] Stop requested");
}

@end
