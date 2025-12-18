class LlamaConfig {
  final String modelPath;
  final String? systemPrompt;
  final int contextLength;
  final int nGpuLayers;
  final int maxTokens;
  final double temperature;
  final double topP;
  final int topK;
  final double repeatPenalty;

  LlamaConfig({
    required this.modelPath,
    this.systemPrompt,
    this.contextLength = 2048,
    this.nGpuLayers = -1,
    this.maxTokens = 1024,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.repeatPenalty = 1.1,
  });

  Map<String, dynamic> toMap() {
    return {
      'modelPath': modelPath,
      'systemPrompt': systemPrompt,
      'contextSize': contextLength,
      'nGpuLayers': nGpuLayers,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'topP': topP,
      'topK': topK,
      'repeatPenalty': repeatPenalty,
    };
  }
}
