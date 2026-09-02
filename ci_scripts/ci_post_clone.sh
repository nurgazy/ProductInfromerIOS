#!/bin/sh

# Устанавливаем кодировку для корректной работы CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Устанавливаем CocoaPods на виртуальную машину Xcode Cloud
brew install cocoapods

# Переходим в директорию с Podfile (подправьте путь, если Podfile лежит в подпапке)
cd ..

# Обновляем репозиторий спецификаций и устанавливаем зависимости
pod repo update
pod install
