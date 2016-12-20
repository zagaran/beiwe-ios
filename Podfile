platform :ios, '9.0'
swift_version = "2.3"

target 'Beiwe' do
  use_frameworks!
  pod 'Crashlytics', '~> 3.4'
  pod 'KeychainSwift', '~> 3.0'
  pod "PromiseKit", "~> 3.1.1"
  pod 'Alamofire', '~> 3.0'
  pod 'ObjectMapper', '~> 1.1'
  pod 'Eureka', :git => 'https://github.com/xmartlabs/Eureka.git', :branch => 'swift2.3'
  pod 'SwiftValidator', '3.0.3' 
  pod "PKHUD", '~> 3.0'
  pod 'IDZSwiftCommonCrypto', :git => 'git@github.com:RocketFarm/IDZSwiftCommonCrypto.git', :branch => 'swift2.3'
  pod 'couchbase-lite-ios'
  pod 'ResearchKit', :git => 'https://github.com/ResearchKit/ResearchKit.git'
  pod 'ReachabilitySwift', :git => 'https://github.com/ashleymills/Reachability.swift', :branch => 'swift-2.3'
  pod 'EmitterKit', '~> 4.0'
  pod 'PermissionScope', :git => 'git@github.com:RocketFarm/PermissionScope', :branch => 'loc-notif-only'
  pod 'Hakuba'
  pod 'XLActionController', :git => 'git@github.com:RocketFarm/XLActionController.git', :branch => 'swift2.3'
  pod 'XCGLogger', '~> 3.3'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless (target.name == 'PromiseKit')
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    end
  end
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '2.3'    
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end

