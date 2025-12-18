import 'dart:async';
import 'package:flutter/services.dart';
import 'llama_config.dart';

/// Main interface for llama.cpp inference on iOS.
class LlamaCpp {
  static const MethodChannel _channel = MethodChannel('com.transception/llama_cpp');
  static const EventChannel _eventChannel = EventChannel('com.transception/llama_cpp/tokens');

  static final LlamaCpp _instance = LlamaCpp._();
  static LlamaCpp get instance => _instance;
  factory LlamaCpp() => _instance;

  LlamaCpp._() {
    _setupEventChannel();
  }

  bool _isModelLoaded = false;
  LlamaConfig? _config;
  int? _activeGenerationId;
  bool _generationCancelled = false;
  StreamController<String>? _tokenController;
  StreamSubscription<dynamic>? _eventSubscription;

  bool get isModelLoaded => _isModelLoaded;
  LlamaConfig? get currentConfig => _config;
  Stream<String>? get tokenStream => _tokenController?.stream;

  void _setupEventChannel() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          final generationId = event['generationId'] as int?;

          if (_activeGenerationId != null && generationId != null && generationId != _activeGenerationId) {
            return;
          }

          if (_generationCancelled) return;

          if (_activeGenerationId == null && generationId != null) {
            _activeGenerationId = generationId;
          }

          if (type == 'token') {
            final token = event['token'] as String?;
            if (token != null) _tokenController?.add(token);
          } else if (type == 'done') {
            if (generationId == _activeGenerationId) {
              _tokenController?.close();
            }
          } else if (type == 'error') {
            final error = event['error'] as String?;
            _tokenController?.addError(Exception(error ?? 'Unknown error'));
          }
        }
      }
    );
  }

  Future<void> loadModel(LlamaConfig config) async {
    final result = await _channel.invokeMethod<Map>('loadModel', config.toMap());
    if (result?['success'] == true) {
      _isModelLoaded = true;
      _config = config;
    } else {
      throw Exception('Failed to load model: ${result?['error']}');
    }
  }

  Stream<String> generate(String prompt, {String? formattedPrompt}) async* {
    _activeGenerationId = null;
    _generationCancelled = false;
    _tokenController?.close();
    _tokenController = StreamController<String>();

    final tokenStream = _tokenController!.stream;

    await _channel.invokeMethod('streamPrompt', {
      'prompt': prompt,
      'formattedPrompt': formattedPrompt,
    });

    await for (final token in tokenStream) {
      if (_generationCancelled) break;
      yield token;
    }
  }

  Future<void> stop() async {
    _generationCancelled = true;
    await _channel.invokeMethod('stopGeneration');
  }

  Future<void> unload() async {
    await stop();
    await _channel.invokeMethod('unloadModel');
    _isModelLoaded = false;
  }
}
