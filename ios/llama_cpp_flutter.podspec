Pod::Spec.new do |s|
  s.name             = 'llama_cpp_flutter'
  s.version          = '0.1.3'
  s.summary          = 'llama.cpp inference for Flutter iOS'
  s.description      = <<-DESC
A production-ready Flutter plugin for on-device GGUF model inference using llama.cpp on iOS with Metal GPU acceleration.
                       DESC
  s.homepage         = 'https://github.com/martechia/llama_cpp_flutter'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Martechia' => 'hello@martechia.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  s.vendored_frameworks = 'Frameworks/llama.framework'
  s.frameworks = ['Accelerate', 'Metal', 'MetalKit', 'Foundation']
  s.libraries = 'c++'
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks/llama.framework/Headers"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_ENABLE_MODULES' => 'YES',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'OTHER_LDFLAGS' => '-ObjC -lc++',
  }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.static_framework = true
end
