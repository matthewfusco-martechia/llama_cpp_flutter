# llama_cpp_flutter

A production-ready Flutter plugin for on-device GGUF model inference using **llama.cpp** on iOS with Metal GPU acceleration.

## Features

- ✅ **Metal GPU Acceleration** - Optimal performance on iOS devices
- ✅ **Streaming Token Generation** - Real-time response streaming
- ✅ **Clean Cancellation** - Stop generation anytime, keep partial response
- ✅ **Memory-Safe Design** - Proper cleanup and resource management
- ✅ **Zero Xcode Configuration** - Works out of the box via CocoaPods
- ✅ **FlutterFlow Compatible** - No manual iOS project edits required

## Requirements

- iOS 14.0+
- arm64 devices (iPhone 6s+, iPad Air 2+)
- Xcode 15.0+
- Flutter 3.3+

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  llama_cpp_flutter:
    path: packages/llama_cpp_flutter  # For local plugin
```

Or, if published:

```yaml
dependencies:
  llama_cpp_flutter: ^1.0.0
```

Then run:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios
```

**That's it!** No Xcode configuration needed.

## Usage

### Basic Example

```dart
import 'package:llama_cpp_flutter/llama_cpp_flutter.dart';

// Get the singleton instance
final llama = LlamaCpp();

// Load a model
await llama.loadModel(LlamaConfig(
  modelPath: '/path/to/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  systemPrompt: 'You are a helpful assistant.',
  contextLength: 2048,
  maxTokens: 512,
));

// Generate with streaming
final stream = llama.generate('Hello, how are you?');
await for (final token in stream) {
  print(token); // Prints each token as it's generated
}

// Stop generation (optional)
await llama.stop();

// Unload model when done
await llama.unload();
```

### FlutterFlow Usage

1. Add the plugin as a Custom Package in FlutterFlow
2. Add your GGUF model to app storage
3. Use Custom Actions to call the plugin:

```dart
// Custom Action: loadModel
Future loadModel(String modelPath) async {
  final llama = LlamaCpp();
  await llama.loadModel(LlamaConfig(modelPath: modelPath));
}

// Custom Action: generateResponse
Stream<String> generateResponse(String prompt) {
  return LlamaCpp().generate(prompt);
}
```

## Supported Models

| Model | Size | RAM Required | Performance |
|-------|------|--------------|-------------|
| qwen2.5-0.5b-instruct-q4_k_m | 400 MB | ~800 MB | Excellent |
| gemma-2-2b-it-q4_0 | 1.4 GB | ~2.2 GB | Very Good |
| llama-3.2-1b-instruct-q4_k_m | 700 MB | ~1.2 GB | Very Good |
| phi-3-mini-4k-q4_k_m | 2.2 GB | ~3.5 GB | Good |

**Recommendations:**
- iPhone 12+ / iPad Air 4+: Use 1-2B parameter models (Q4/Q5)
- iPhone 14+ / iPad Pro: Can run 3-4B parameter models (Q4)
- Always use Q4_K_M or Q5_K_M quantization for best quality/size ratio

## Configuration Options

```dart
LlamaConfig(
  modelPath: '/path/to/model.gguf',  // Required
  systemPrompt: 'You are helpful.',   // Optional system prompt
  contextLength: 2048,                // Context window (default: 2048)
  nGpuLayers: -1,                     // GPU layers (-1 = auto)
  maxTokens: 2048,                    // Max tokens per response
  temperature: 0.7,                   // Randomness (0.0 - 1.0)
  topP: 0.9,                          // Nucleus sampling
  repeatPenalty: 1.1,                 // Repetition penalty
)
```

## Architecture

This plugin follows Flutter plugin best practices:

```
llama_cpp_flutter/
├── lib/                          # Dart API
│   ├── llama_cpp_flutter.dart    # Main exports
│   └── src/
│       ├── llama_cpp.dart        # LlamaCpp class
│       └── llama_config.dart     # Configuration
│
├── ios/
│   ├── Classes/                  # Native code
│   │   ├── LlamaCppFlutterPlugin.swift
│   │   ├── LlamaCppWrapper.h
│   │   └── LlamaCppWrapper.mm
│   │
│   ├── Frameworks/               # Vendored framework
│   │   └── llama.framework
│   │
│   └── llama_cpp_flutter.podspec # CocoaPods config
│
└── pubspec.yaml
```

**Key Design Decisions:**

1. **Vendored Framework**: The llama.cpp static library is bundled as a framework, eliminating the need for users to build anything.

2. **CocoaPods Integration**: All native dependencies are declared in the podspec, so `pod install` handles everything automatically.

3. **No Runner Modifications**: The plugin is completely self-contained. The host app's Runner folder is never touched.

## Building llama.cpp Framework

If you need to rebuild the llama.framework:

```bash
./scripts/build_llama_ios.sh
```

This will:
1. Clone llama.cpp
2. Build for iOS arm64 with Metal support
3. Create the framework bundle
4. Copy to `ios/Frameworks/llama.framework`

## Troubleshooting

### "llama.cpp not linked" error

Ensure the framework is properly included:
```bash
cd ios && pod deintegrate && pod install && cd ..
```

### "Undefined symbols" linker errors

Make sure you're building for a real device, not simulator. The framework is arm64 only.

### Memory warnings or crashes

- Use smaller quantized models (Q4_K_M instead of Q8)
- Reduce `contextLength`
- Ensure you call `unload()` when done

### Slow generation

- Check that Metal acceleration is working (look for "Metal" in logs)
- Use Q4 quantization instead of Q5/Q8
- Reduce `maxTokens` if you need shorter responses

## License

MIT License - see LICENSE file.

## Credits

- [llama.cpp](https://github.com/ggerganov/llama.cpp) - The amazing C++ inference library
- [ggml](https://github.com/ggerganov/ggml) - Tensor library with Metal support
