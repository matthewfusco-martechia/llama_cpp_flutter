Pod::Spec.new do |s|
  s.name             = 'llama_cpp_flutter'
  s.version          = '1.0.0'
  s.summary          = 'llama.cpp inference for Flutter iOS'
  s.description      = <<-DESC
A production-ready Flutter plugin for on-device GGUF model inference
using llama.cpp on iOS with Metal GPU acceleration.
                       DESC
  s.homepage         = 'https://github.com/martechia/llama_cpp_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Martechia' => 'hello@martechia.com' }
  s.source           = { :path => '.' }
  
  # Source files
  s.source_files = 'Classes/**/*'
  
  # Dependencies
  s.dependency 'Flutter'
  
  # iOS platform
  s.platform = :ios, '14.0'
  s.swift_version = '5.0'
  
  # Vendored framework - THIS IS THE KEY!
  # The framework is bundled with the plugin, not the app
  s.vendored_frameworks = 'Frameworks/llama.framework'
  
  # Required system frameworks for Metal acceleration
  s.frameworks = [
    'Accelerate',
    'Metal',
    'MetalKit',
    'Foundation'
  ]
  
  # Link C++ standard library
  s.libraries = 'c++'
  
  # Build settings
  s.pod_target_xcconfig = {
    # Header search paths for llama.cpp headers
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks/llama.framework/Headers"',
    
    # C++ language standard
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    
    # Enable modules for Swift interop
    'CLANG_ENABLE_MODULES' => 'YES',
    
    # Allow non-modular includes (needed for llama.cpp)
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    
    # Exclude arm64 simulator (llama.framework is device-only)
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    
    # Other linker flags
    'OTHER_LDFLAGS' => '-ObjC -lc++',
  }
  
  # User target settings (applies to the app)
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
  }
  
  # Use static frameworks (required for Flutter)
  s.static_framework = true
end
