import 'dart:async';
import 'package:flutter/services.dart';
import 'llama_config.dart';

/// Main interface for llama.cpp inference on iOS.
///
/// This class provides a clean API for loading GGUF models, generating
/// responses with streaming tokens, and managing model lifecycle.
///
/// Example:
/// ```dart
/// final llama = LlamaCpp();
/// await llama.loadModel(LlamaConfig(modelPath: '/path/to/model.gguf'));
/// llama.tokenStream.listen((token) => print(token));
/// await llama.generate('Hello!');
/// await llama.unload();
/// ```
class LlamaCpp {
  static const MethodChannel _channel = MethodChannel('llama_cpp_flutter');
  static const EventChannel _eventChannel =
      EventChannel('llama_cpp_flutter/tokens');

  /// Singleton instance
  static final LlamaCpp _instance = LlamaCpp._();

  /// Get the singleton instance
  static LlamaCpp get instance => _instance;

  /// Factory constructor returns singleton
  factory LlamaCpp() => _instance;

  LlamaCpp._() {
    _setupEventChannel();
  }

  /// Whether a model is currently loaded
  bool _isModelLoaded = false;

  /// Current configuration
  LlamaConfig? _config;

  /// Current generation ID from native side
  int? _activeGenerationId;

  /// Whether generation was cancelled
  bool _generationCancelled = false;

  /// Stream controller for tokens
  StreamController<String>? _tokenController;

  /// Completer for generation completion
  Completer<void>? _generationCompleter;

  /// Subscription to native events
  StreamSubscription<dynamic>? _eventSubscription;

  /// Whether a model is loaded
  bool get isModelLoaded => _isModelLoaded;

  /// Current configuration
  LlamaConfig? get currentConfig => _config;

  /// Stream of generated tokens
  Stream<String>? get tokenStream => _tokenController?.stream;

  void _setupEventChannel() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          final generationId = event['generationId'] as int?;

          // Filter stale tokens from previous generations
          if (_activeGenerationId != null &&
              generationId != null &&
              generationId != _activeGenerationId) {
            return;
          }

          // If generation was cancelled, drop all tokens
          if (_generationCancelled) {
            return;
          }

          // Update active generation ID from first event
          if (_activeGenerationId == null && generationId != null) {
            _activeGenerationId = generationId;
          }

          if (type == 'token') {
            final token = event['token'] as String?;
            final controller = _tokenController;
            if (token != null && controller != null && !controller.isClosed) {
              controller.add(token);
            }
          } else if (type == 'done') {
            // Only close stream if this is our generation
            if (generationId != null && generationId == _activeGenerationId) {
              _tokenController?.close();
              _generationCompleter?.complete();
              _generationCompleter = null;
            }
          } else if (type == 'error') {
            final error = event['error'] as String?;
            _tokenController?.addError(Exception(error ?? 'Unknown error'));
            _generationCompleter?.completeError(Exception(error));
            _generationCompleter = null;
          }
        }
      },
      onError: (error) {
        _tokenController?.addError(error);
      },
    );
  }

  /// Check if the native library is available
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Load a GGUF model with the given configuration.
  ///
  /// Throws an exception if loading fails.
  Future<void> loadModel(LlamaConfig config) async {
    if (_isModelLoaded) {
      await unload();
    }

    _config = config;

    final result = await _channel.invokeMethod<Map>('loadModel', config.toMap());

    if (result != null && result['success'] == true) {
      _isModelLoaded = true;
    } else {
      final error = result?['error'] as String? ?? 'Unknown error';
      throw Exception('Failed to load model: $error');
    }
  }

  /// Generate a response for the given prompt.
  ///
  /// Tokens are streamed via [tokenStream]. This method returns when
  /// generation is complete.
  ///
  /// Parameters:
  /// - [prompt]: The user's input text
  /// - [systemPrompt]: Optional system prompt override
  /// - [history]: Optional conversation history
  Stream<String> generate(
    String prompt, {
    String? systemPrompt,
    List<Map<String, String>> history = const [],
  }) async* {
    if (!_isModelLoaded) {
      throw Exception('No model loaded');
    }

    // Reset generation tracking
    _activeGenerationId = null;
    _generationCancelled = false;

    // Create fresh stream controller
    _tokenController?.close();
    _tokenController = StreamController<String>();
    _generationCompleter = Completer<void>();

    final tokenStream = _tokenController!.stream;

    try {
      // Start generation on native side
      await _channel.invokeMethod('streamPrompt', {
        'prompt': prompt,
        'systemPrompt': systemPrompt ?? _config?.systemPrompt,
        'history': history,
      });

      // Yield tokens as they arrive
      await for (final token in tokenStream) {
        if (_generationCancelled) {
          break;
        }
        yield token;
      }
    } catch (e) {
      rethrow;
    } finally {
      _tokenController?.close();
      _tokenController = null;
    }
  }

  /// Stop the current generation.
  ///
  /// Any partial response is preserved.
  Future<void> stop() async {
    _generationCancelled = true;
    _activeGenerationId = null;

    _tokenController?.close();
    _tokenController = null;

    try {
      await _channel.invokeMethod('stopGeneration');
    } catch (e) {
      // Ignore errors when stopping
    }
  }

  /// Unload the current model and free resources.
  Future<void> unload() async {
    await stop();

    try {
      await _channel.invokeMethod('unloadModel');
    } catch (e) {
      // Ignore errors
    }

    _isModelLoaded = false;
    _config = null;
  }

  /// Dispose of all resources.
  ///
  /// Call this when you're done using the plugin.
  void dispose() {
    _eventSubscription?.cancel();
    _tokenController?.close();
    _tokenController = null;
  }
}
