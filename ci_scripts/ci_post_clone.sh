#!/bin/sh

# Install CocoaPods using Homebrew or system gem
brew install cocoapods

# Navigate to the workspace directory containing the Podfile
# Adjust path if your Podfile is inside an 'ios' subfolder: cd ../ios
cd ..

# Install Pods to generate the missing .xcfilelist files
pod install
