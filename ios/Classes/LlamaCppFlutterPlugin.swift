import Flutter
import UIKit

/// Flutter plugin for llama.cpp inference on iOS.
///
/// This plugin provides the platform channel bridge between Flutter and
/// the native llama.cpp Objective-C++ wrapper.
public class LlamaCppFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    // MARK: - Properties
    
    /// The llama.cpp wrapper instance
    private let wrapper = LlamaCppWrapper()
    
    /// Event sink for streaming tokens to Flutter
    private var tokenEventSink: FlutterEventSink?
    
    /// Current generation ID for tracking
    private var currentGenerationId: Int = 0
    
    // MARK: - Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Method channel for commands - matches existing Dart code
        let channel = FlutterMethodChannel(
            name: "com.transception/llama_cpp",
            binaryMessenger: registrar.messenger()
        )
        
        // Event channel for streaming tokens - matches existing Dart code
        let eventChannel = FlutterEventChannel(
            name: "com.transception/llama_cpp/tokens",
            binaryMessenger: registrar.messenger()
        )
        
        let instance = LlamaCppFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        
        print("🦙 [LlamaCppFlutterPlugin] Registered")
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        tokenEventSink = events
        print("🦙 [LlamaCppFlutterPlugin] Token stream connected")
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        tokenEventSink = nil
        print("🦙 [LlamaCppFlutterPlugin] Token stream disconnected")
        return nil
    }
    
    // MARK: - FlutterPlugin
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(true)
            
        case "loadModel":
            handleLoadModel(call: call, result: result)
            
        case "streamPrompt":
            handleStreamPrompt(call: call, result: result)
            
        case "stopGeneration":
            handleStopGeneration(result: result)
            
        case "unloadModel":
            handleUnloadModel(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Load Model
    
    private func handleLoadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "modelPath is required",
                details: nil
            ))
            return
        }
        
        // Build configuration
        let config = LlamaCppConfig(
            modelPath: modelPath,
            contextLength: args["contextLength"] as? Int32 ?? 2048,
            nGpuLayers: args["nGpuLayers"] as? Int32 ?? -1,
            maxTokens: args["maxTokens"] as? Int32 ?? 2048,
            temperature: args["temperature"] as? Float ?? 0.7,
            topP: args["topP"] as? Float ?? 0.9,
            repeatPenalty: args["repeatPenalty"] as? Float ?? 1.1,
            systemPrompt: args["systemPrompt"] as? String
        )
        
        print("🦙 [LlamaCppFlutterPlugin] Loading model: \(modelPath)")
        
        wrapper.loadModel(with: config) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("🦙 [LlamaCppFlutterPlugin] Model loaded successfully")
                    result(["success": true])
                } else {
                    print("🦙 [LlamaCppFlutterPlugin] Model load failed: \(error ?? "Unknown")")
                    result(FlutterError(
                        code: "LOAD_FAILED",
                        message: error ?? "Unknown error",
                        details: nil
                    ))
                }
            }
        }
    }
    
    // MARK: - Stream Prompt
    
    private func handleStreamPrompt(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let prompt = args["prompt"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "prompt is required",
                details: nil
            ))
            return
        }
        
        // Increment generation ID
        currentGenerationId += 1
        let thisGenerationId = currentGenerationId
        
        let systemPrompt = args["systemPrompt"] as? String
        let history = args["history"] as? [[String: String]] ?? []
        
        print("🦙 [LlamaCppFlutterPlugin] Starting generation #\(thisGenerationId)")
        
        wrapper.streamResponse(prompt, systemPrompt: systemPrompt, history: history) { [weak self] token, isDone, error in
            guard let self = self else { return }
            
            // Check if this generation is still current
            guard thisGenerationId == self.currentGenerationId else {
                return
            }
            
            if let error = error {
                self.tokenEventSink?(FlutterError(
                    code: "GENERATION_ERROR",
                    message: error,
                    details: nil
                ))
                return
            }
            
            if isDone {
                self.tokenEventSink?(["type": "done", "generationId": thisGenerationId])
            } else if let token = token {
                self.tokenEventSink?(["type": "token", "token": token, "generationId": thisGenerationId])
            }
        }
        
        // Return immediately - tokens come via event channel
        result(["success": true, "generationId": thisGenerationId])
    }
    
    // MARK: - Stop Generation
    
    private func handleStopGeneration(result: @escaping FlutterResult) {
        print("🦙 [LlamaCppFlutterPlugin] Stopping generation")
        
        currentGenerationId += 1
        wrapper.stopGeneration()
        
        result(["success": true])
    }
    
    // MARK: - Unload Model
    
    private func handleUnloadModel(result: @escaping FlutterResult) {
        print("🦙 [LlamaCppFlutterPlugin] Unloading model")
        
        wrapper.unloadModel()
        
        result(["success": true])
    }
}
