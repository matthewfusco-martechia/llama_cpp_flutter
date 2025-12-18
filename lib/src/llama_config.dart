/// Configuration options for loading a GGUF model.
class LlamaConfig {
  /// Path to the GGUF model file
  final String modelPath;

  /// System prompt to use for all conversations
  final String? systemPrompt;

  /// Maximum context length (default: 2048)
  final int contextLength;

  /// Number of GPU layers to offload (-1 = auto, 0 = CPU only)
  final int nGpuLayers;

  /// Maximum tokens to generate per response
  final int maxTokens;

  /// Temperature for sampling (0.0 = deterministic, higher = more random)
  final double temperature;

  /// Top-p (nucleus) sampling threshold
  final double topP;

  /// Repeat penalty to avoid repetition
  final double repeatPenalty;

  const LlamaConfig({
    required this.modelPath,
    this.systemPrompt,
    this.contextLength = 2048,
    this.nGpuLayers = -1,
    this.maxTokens = 2048,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.repeatPenalty = 1.1,
  });

  /// Create a copy with modified values
  LlamaConfig copyWith({
    String? modelPath,
    String? systemPrompt,
    int? contextLength,
    int? nGpuLayers,
    int? maxTokens,
    double? temperature,
    double? topP,
    double? repeatPenalty,
  }) {
    return LlamaConfig(
      modelPath: modelPath ?? this.modelPath,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      contextLength: contextLength ?? this.contextLength,
      nGpuLayers: nGpuLayers ?? this.nGpuLayers,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
    );
  }

  /// Convert to map for platform channel
  Map<String, dynamic> toMap() {
    return {
      'modelPath': modelPath,
      'systemPrompt': systemPrompt,
      'contextLength': contextLength,
      'nGpuLayers': nGpuLayers,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'topP': topP,
      'repeatPenalty': repeatPenalty,
    };
  }
}
