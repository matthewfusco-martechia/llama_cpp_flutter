import 'package:flutter/material.dart';
import 'package:llama_cpp_flutter/llama_cpp_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final LlamaCpp _llama = LlamaCpp();
  bool _isLoaded = false;
  bool _isGenerating = false;
  String _response = '';
  final TextEditingController _promptController = TextEditingController(text: 'Tell me a short joke.');

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadModel() async {
    // Note: In a real app, you'd pick a model file from the filesystem.
    // This expects a GGUF model to exist in the app's documents directory.
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync().where((f) => f.path.endsWith('.gguf')).toList();

    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No .gguf models found in documents directory. Please add one first.')),
        );
      }
      return;
    }

    final modelPath = files.first.path;

    setState(() {
      _response = 'Loading model: ${modelPath.split('/').last}...';
    });

    final config = LlamaConfig(
      modelPath: modelPath,
      contextLength: 2048,
      nGpuLayers: -1, // Use Metal
    );

    final result = await _llama.loadModel(config);

    if (mounted) {
      setState(() {
        _isLoaded = result;
        _response = result ? 'Model loaded successfully!' : 'Model load failed.';
      });
    }
  }

  Future<void> _generate() async {
    if (!_isLoaded) return;

    setState(() {
      _isGenerating = true;
      _response = '';
    });

    try {
      await for (final token in _llama.generate(_promptController.text)) {
        setState(() {
          _response += token;
        });
      }
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('llama.cpp Flutter Example')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _promptController,
                decoration: const InputDecoration(labelText: 'Prompt'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _loadModel,
                      child: const Text('Load First GGUF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoaded && !_isGenerating ? _generate : null,
                      child: const Text('Generate'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isGenerating)
                ElevatedButton(
                  onPressed: () => _llama.stop(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Stop'),
                ),
              const SizedBox(height: 16),
              const Text('Response:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(_response),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
