/// llama_cpp_flutter - On-device GGUF model inference for iOS
///
/// A production-ready Flutter plugin that enables on-device inference using
/// llama.cpp with Metal GPU acceleration on iOS devices.
///
/// Features:
/// - Metal GPU acceleration for optimal performance
/// - Streaming token generation
/// - Clean cancellation support
/// - Memory-safe design
/// - Zero Xcode configuration required
///
/// Example:
/// ```dart
/// final llama = LlamaCpp();
///
/// // Load a GGUF model
/// await llama.loadModel('/path/to/model.gguf');
///
/// // Stream tokens
/// llama.tokenStream.listen((token) => print(token));
///
/// // Generate response
/// await llama.generate('Hello, how are you?');
///
/// // Stop generation
/// await llama.stop();
///
/// // Unload model
/// await llama.unload();
/// ```
library llama_cpp_flutter;

export 'src/llama_cpp.dart';
export 'src/llama_config.dart';
