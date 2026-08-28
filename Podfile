# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'ProductInformer' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for ProductInformer
  pod 'GoogleMLKit/BarcodeScanning'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
    end
  end
end
