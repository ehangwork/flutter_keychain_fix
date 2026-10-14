Pod::Spec.new do |s|
  s.name             = 'flutter_keychain_fix'
  s.version          = '0.0.1'
  s.summary          = 'Flutter secure storage via native Keychain (iOS) and Keystore (Android).'
  s.description      = <<-DESC
    Flutter plugin for secure string storage using the iOS Keychain and Android Keystore.
    Supports optional access groups (kSecAttrAccessGroup) for cross-app sharing and
    item labels (kSecAttrLabel) for iOS Passwords visibility.
  DESC
  s.homepage         = 'https://github.com/ehangwork/flutter_keychain_fix'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jeroen Trappers' => 'jeroen@apple.be' }
  s.source           = { :path => '.' }

  # Sources live in the Swift Package Manager tree because Flutter requires that exact
  # path (ios/<package_name>/Package.swift). CocoaPods compiles them from here so both
  # integration modes build one single copy of the plugin instead of two that can drift.
  s.source_files = 'flutter_keychain_fix/Sources/flutter_keychain_fix/**/*.swift'
  s.swift_version = '5.0'

  s.dependency 'Flutter'
  s.ios.deployment_target = '12.0'
end