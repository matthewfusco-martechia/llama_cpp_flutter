#import <Foundation/Foundation.h>

@interface LlamaModelConfig : NSObject
@property(nonatomic, copy) NSString *modelPath;
@property(nonatomic, assign) int contextSize;
@property(nonatomic, assign) int nGpuLayers;
@property(nonatomic, assign) int nThreads;
@property(nonatomic, assign) int batchSize;
@property(nonatomic, assign) float temperature;
@property(nonatomic, assign) int topK;
@property(nonatomic, assign) float topP;
@property(nonatomic, assign) float repeatPenalty;
@property(nonatomic, assign) int maxTokens;
@property(nonatomic, assign) BOOL useGpu;
@property(nonatomic, assign) BOOL verbose;
@property(nonatomic, copy) NSString *systemPrompt;

+ (instancetype)configFromDictionary:(NSDictionary *)dict;
@end

@interface LlamaCppWrapper : NSObject

- (BOOL)loadModel:(LlamaModelConfig *)config error:(NSError **)error;
- (void)unloadModel;
- (void)stopStreaming;
- (void)resetContext;

- (void)
     streamResponse:(NSString *)prompt
       systemPrompt:(NSString *)systemPrompt
            history:(NSArray<NSDictionary *> *)history
    formattedPrompt:(NSString *)formattedPrompt
       generationId:(NSInteger)genId
            onToken:(void (^)(NSString *token, NSInteger generationId))onToken
             onDone:(void (^)(NSInteger generationId))onDone
            onError:(void (^)(NSString *error, NSInteger generationId))onError;

@end
