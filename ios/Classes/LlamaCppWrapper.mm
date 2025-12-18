#import "LlamaCppWrapper.h"
#import <atomic>
#import <ggml-metal.h>
#import <llama.h>
#import <string>
#import <vector>

@interface LlamaCppWrapper () {
  llama_model *_model;
  llama_context *_ctx;
  llama_sampler *_sampler;
  std::atomic<bool> _shouldStop;
  BOOL _isStreaming;
}
@property(nonatomic, strong) LlamaModelConfig *currentConfig;
@end

@implementation LlamaModelConfig
+ (instancetype)configFromDictionary:(NSDictionary *)dict {
  LlamaModelConfig *config = [[LlamaModelConfig alloc] init];
  config.modelPath = dict[@"modelPath"];
  config.contextSize = [dict[@"contextSize"] intValue] ?: 2048;
  config.nGpuLayers = [dict[@"nGpuLayers"] intValue] ?: -1;
  config.nThreads = [dict[@"nThreads"] intValue] ?: 4;
  config.batchSize = [dict[@"batchSize"] intValue] ?: 512;
  config.temperature = [dict[@"temperature"] floatValue] ?: 0.7f;
  config.topK = [dict[@"topK"] intValue] ?: 40;
  config.topP = [dict[@"topP"] floatValue] ?: 0.9f;
  config.repeatPenalty = [dict[@"repeatPenalty"] floatValue] ?: 1.1f;
  config.maxTokens = [dict[@"maxTokens"] intValue] ?: 1024;
  config.useGpu = dict[@"useGpu"] ? [dict[@"useGpu"] boolValue] : YES;
  config.verbose = [dict[@"verbose"] boolValue];
  return config;
}
@end

@implementation LlamaCppWrapper

- (instancetype)init {
  self = [super init];
  if (self) {
    _model = nullptr;
    _ctx = nullptr;
    _sampler = nullptr;
    _shouldStop = false;
    _isStreaming = NO;
    llama_backend_init();
  }
  return self;
}

- (void)dealloc {
  [self unloadModel];
  llama_backend_free();
}

- (BOOL)loadModel:(LlamaModelConfig *)config error:(NSError **)error {
  [self unloadModel];
  self.currentConfig = config;

  llama_model_params model_params = llama_model_default_params();
  model_params.n_gpu_layers = config.nGpuLayers;

  _model =
      llama_load_model_from_file(config.modelPath.UTF8String, model_params);
  if (!_model) {
    if (error)
      *error = [NSError
          errorWithDomain:@"LlamaCpp"
                     code:1
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Failed to load model file"
                 }];
    return NO;
  }

  llama_context_params ctx_params = llama_context_default_params();
  ctx_params.n_ctx = config.contextSize;
  ctx_params.n_batch = config.batchSize;
  ctx_params.n_threads = config.nThreads;
  ctx_params.n_threads_batch = config.nThreads;

  _ctx = llama_new_context_with_model(_model, ctx_params);
  if (!_ctx) {
    llama_free_model(_model);
    if (error)
      *error = [NSError
          errorWithDomain:@"LlamaCpp"
                     code:2
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Failed to create context"
                 }];
    return NO;
  }

  _sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
  llama_sampler_chain_add(_sampler, llama_sampler_init_top_k(config.topK));
  llama_sampler_chain_add(_sampler, llama_sampler_init_top_p(config.topP, 1));
  llama_sampler_chain_add(_sampler,
                          llama_sampler_init_temp(config.temperature));
  llama_sampler_chain_add(_sampler,
                          llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

  NSLog(@"🦙 [LlamaCppWrapper] Model loaded: %@",
        config.modelPath.lastPathComponent);
  return YES;
}

- (void)unloadModel {
  if (_sampler) {
    llama_sampler_free(_sampler);
    _sampler = nullptr;
  }
  if (_ctx) {
    llama_free(_ctx);
    _ctx = nullptr;
  }
  if (_model) {
    llama_free_model(_model);
    _model = nullptr;
  }
}

- (void)stopStreaming {
  _shouldStop = true;
}

- (void)
     streamResponse:(NSString *)prompt
       systemPrompt:(NSString *)systemPrompt
            history:(NSArray<NSDictionary *> *)history
    formattedPrompt:(NSString *)formattedPrompt
       generationId:(NSInteger)genId
            onToken:(void (^)(NSString *token, NSInteger generationId))onToken
             onDone:(void (^)(NSInteger generationId))onDone
            onError:(void (^)(NSString *error, NSInteger generationId))onError {

  if (!_ctx || !_model) {
    onError(@"Model not loaded", genId);
    return;
  }

  _shouldStop = false;
  _isStreaming = YES;

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    // 1. Build the prompt string
    NSString *fullPromptString;

    if (formattedPrompt && formattedPrompt.length > 0) {
      fullPromptString = formattedPrompt;
    } else {
      NSMutableString *buffer = [NSMutableString string];
      if (systemPrompt && systemPrompt.length > 0) {
        [buffer
            appendFormat:@"<|im_start|>system\n%@<|im_end|>\n", systemPrompt];
      }
      for (NSDictionary *msg in history) {
        NSString *role = msg[@"role"];
        NSString *content = msg[@"content"];
        [buffer appendFormat:@"<|im_start|>%@\n%@<|im_end|>\n", role, content];
      }
      [buffer appendFormat:
                  @"<|im_start|>user\n%@<|im_end|>\n<|im_start|>assistant\n",
                  prompt];
      fullPromptString = buffer;
    }

    const struct llama_vocab *vocab = llama_model_get_vocab(_model);

    // 2. Tokenize
    std::vector<llama_token> tokens;
    tokens.resize(fullPromptString.length + 1);
    int n_tokens = llama_tokenize(vocab, fullPromptString.UTF8String,
                                  (int)fullPromptString.length, tokens.data(),
                                  (int)tokens.size(), true, false);
    if (n_tokens < 0) {
      tokens.resize(-n_tokens);
      n_tokens = llama_tokenize(vocab, fullPromptString.UTF8String,
                                (int)fullPromptString.length, tokens.data(),
                                (int)tokens.size(), true, false);
    }
    tokens.resize(n_tokens);

    // 3. Clear KV cache (using new API)
    llama_memory_clear(llama_get_memory(_ctx), true);

    // 4. Ingest tokens
    int maxTokens = self.currentConfig.maxTokens ?: 1024;
    int n_gen = 0;

    for (int i = 0; i < tokens.size(); i += self.currentConfig.batchSize) {
      if (_shouldStop)
        break;
      int n_eval = (int)tokens.size() - i;
      if (n_eval > self.currentConfig.batchSize)
        n_eval = self.currentConfig.batchSize;

      llama_batch batch = llama_batch_get_one(&tokens[i], n_eval);
      if (llama_decode(_ctx, batch) != 0) {
        onError(@"Failed to decode", genId);
        return;
      }
    }

    // 5. Generate
    while (n_gen < maxTokens) {
      if (_shouldStop)
        break;

      llama_token id = llama_sampler_sample(_sampler, _ctx, -1);
      if (llama_vocab_is_eog(vocab, id))
        break;

      // Convert to string piece
      char piece[128];
      int n = llama_token_to_piece(vocab, id, piece, sizeof(piece), 0, true);
      if (n > 0) {
        NSString *tokenStr =
            [[NSString alloc] initWithBytes:piece
                                     length:n
                                   encoding:NSUTF8StringEncoding];
        if (tokenStr) {
          dispatch_async(dispatch_get_main_queue(), ^{
            onToken(tokenStr, genId);
          });
        }
      }

      // Decode next
      llama_batch batch = llama_batch_get_one(&id, 1);
      if (llama_decode(_ctx, batch) != 0)
        break;

      n_gen++;
    }

    _isStreaming = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
      onDone(genId);
    });
  });
}

- (void)resetContext {
  if (_ctx)
    llama_memory_clear(llama_get_memory(_ctx), true);
}

@end
