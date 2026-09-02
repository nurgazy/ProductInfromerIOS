# Uncomment the next line to define a global platform for your project
platform :ios, '16.6'

target 'ProductInformer' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks! :linkage => :static

  # Pods for ProductInformer
  pod 'GoogleMLKit/BarcodeScanning'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      
      # Гарантируем поддержку всех архитектур на виртуальных машинах Xcode Cloud
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
      
      # Принудительно устанавливаем версию iOS для всех зависимостей (включая FBLPromises)
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.6'
      
      # Включаем поддержку модулей Clang для правильной линковки
      config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
    end
  end
end
