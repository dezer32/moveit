#!/bin/bash

echo "Testing refactored MoveIt compilation..."

# Compile all Swift files together to check for errors
swiftc \
  -sdk $(xcrun --show-sdk-path) \
  -target arm64-apple-macos14.0 \
  -framework SwiftUI \
  -framework Combine \
  -framework CoreData \
  -framework UserNotifications \
  -framework AppKit \
  MoveIt/Models/*.swift \
  MoveIt/Services/*.swift \
  MoveIt/ViewModels/*.swift \
  MoveIt/Views/*.swift \
  MoveIt/Views/Components/*.swift \
  MoveIt/Utilities/*.swift \
  MoveIt/StatisticsService.swift \
  MoveIt/MoveItApp.swift \
  -parse 2>&1

if [ $? -eq 0 ]; then
    echo "✅ All Swift files parse successfully!"
else
    echo "❌ Compilation errors found"
fi