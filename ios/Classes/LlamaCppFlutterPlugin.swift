import Flutter
import UIKit

public class LlamaCppFlutterPlugin: NSObject, FlutterPlugin {
    private let CHANNEL_NAME = "com.transception/llama_cpp"
    private let STREAM_CHANNEL_NAME = "com.transception/llama_cpp/tokens"
    
    private var wrapper: LlamaCppWrapper?
    private var eventSink: FlutterEventSink?
    private var nextGenerationId: Int = 1
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = LlamaCppFlutterPlugin()
        
        // Method channel
        let channel = FlutterMethodChannel(name: instance.CHANNEL_NAME, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Event channel
        let eventChannel = FlutterEventChannel(name: instance.STREAM_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        
        instance.wrapper = LlamaCppWrapper()
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(true)
            
        case "loadModel":
            guard let args = call.arguments as? [String: Any] else {
                result(["success": false, "error": "Invalid arguments"])
                return
            }
            
            let config = LlamaModelConfig.config(from: args)
            var error: NSError?
            let success = wrapper?.loadModel(config, error: &error) ?? false
            
            if success {
                result(["success": true])
            } else {
                result(["success": false, "error": error?.localizedDescription ?? "Unknown error"])
            }
            
        case "streamPrompt":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a dictionary", details: nil))
                return
            }
            
            let prompt = args["prompt"] as? String ?? ""
            let systemPrompt = args["systemPrompt"] as? String
            let history = args["history"] as? [[String: String]] ?? []
            let formattedPrompt = args["formattedPrompt"] as? String // New argument
            
            let genId = nextGenerationId
            nextGenerationId += 1
            
            wrapper?.streamResponse(prompt, 
                                 systemPrompt: systemPrompt, 
                                 history: history, 
                                 formattedPrompt: formattedPrompt,
                                 generationId: genId, 
            onToken: { [weak self] (token, id) in
                self?.sendEvent(["type": "token", "token": token, "generationId": id])
            }, onDone: { [weak self] (id) in
                self?.sendEvent(["type": "done", "generationId": id])
            }, onError: { [weak self] (error, id) in
                self?.sendEvent(["type": "error", "error": error, "generationId": id])
            })
            
            result(genId)
            
        case "stopGeneration":
            wrapper?.stopStreaming()
            result(true)
            
        case "unloadModel":
            wrapper?.unloadModel()
            result(true)
            
        case "resetContext":
            wrapper?.resetContext()
            result(true)
            
        case "getModelInfo":
            result(["status": "ready"])
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func sendEvent(_ event: [String: Any]) {
        DispatchQueue.main.async {
            self.eventSink?(event)
        }
    }
}

extension LlamaCppFlutterPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
