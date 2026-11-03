require '/Users/admin/.gem/ruby/2.6.0/gems/xcodeproj-1.22.0/lib/xcodeproj'

project_path = File.expand_path('VirtualTouchAI.xcodeproj', __dir__)
project = Xcodeproj::Project.new(project_path)

main_group = project.main_group
source_group = main_group.new_group('VirtualTouchAI')
Dir[File.join(__dir__, 'VirtualTouchAI', '*.swift')].sort.each do |path|
  source_group.new_file(path)
end

resources_group = main_group.new_group('Resources')
resources_group.new_file(File.join(__dir__, 'Resources', 'Info.plist'))
assets_file = source_group.new_reference(File.join(__dir__, 'VirtualTouchAI', 'Assets.xcassets'))
target_resources_build_phase = nil

product_group = main_group.new_group('Products')
target = project.new_target(:application, 'VirtualTouchAI', :osx, '11.0')
target.product_name = 'VirtualTouch AI'

target.add_system_framework('AppKit')
target.add_system_framework('AVFoundation')
target.add_system_framework('Vision')
target.add_system_framework('CoreGraphics')
target.add_system_framework('CoreImage')
target.add_system_framework('Accelerate')
target.resources_build_phase.add_file_reference(assets_file)

Dir[File.join(__dir__, 'VirtualTouchAI', '*.swift')].sort.each do |path|
  file_name = File.basename(path)
  file_reference = source_group.files.find { |file| File.basename(file.real_path.to_s) == file_name }
  target.source_build_phase.add_file_reference(file_reference) if file_reference
end

info_file = File.join(__dir__, 'Resources', 'Info.plist')
target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.virtualtouch.ai'
  settings['PRODUCT_NAME'] = 'VirtualTouch AI'
  settings['SWIFT_VERSION'] = '5.0'
  settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
  settings['INFOPLIST_FILE'] = info_file
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

project.save
puts project_path
