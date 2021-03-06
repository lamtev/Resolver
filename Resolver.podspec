Pod::Spec.new do |s|
  s.name         = "Resolver"
  s.version      = "1.1.2"
  s.summary      = "An ultralight Dependency Injection / Service Locator framework for Swift on iOS."
  s.homepage     = "https://github.com/hmlongco/Resolver"
  s.license      = "MIT"
  s.author       = "Michael Long"
  s.platform     = :ios, "9.3"
  s.source       = { :git => "https://github.com/hmlongco/Resolver.git", :tag => "#{s.version}" }
  s.source_files  = "Classes", "Sources/Resolver/*.swift"
  s.swift_version = '5.1'
  s.ios.framework  = 'UIKit'
end
