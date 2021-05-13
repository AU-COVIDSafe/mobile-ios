# Uncomment the next line to define a global platform for your project
platform :ios, '10.0'

workspace 'CovidSafe.xcworkspace'

source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/wogaa/Specs.git'


target 'CovidSafe' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for CovidSafe
  pod 'Alamofire'
  pod 'KeychainSwift'
  pod 'lottie-ios'
  pod 'FlagKit'
  pod 'ReachabilitySwift'
end



target 'CovidSafe-staging' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  # Pods for CovidSafe
  pod 'Alamofire'
  pod 'KeychainSwift'
  pod 'lottie-ios'
  pod 'FlagKit'
  pod 'ReachabilitySwift'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '10.0'
    end
  end
end
