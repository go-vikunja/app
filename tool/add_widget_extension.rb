#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the VikunjaWidgets WidgetKit extension to the Flutter iOS project and keeps
# the project's file list in sync with app/ios/VikunjaWidgets (Swift files, the asset
# catalog, Localizable.strings and Localizable.stringsdict per language, the privacy
# manifest). It also gives the Runner its entitlements and its privacy manifest.
# Re-running it changes nothing unless files were added or removed. Needs only the
# xcodeproj gem, which ships with CocoaPods.
#
#   ruby tool/add_widget_extension.rb [path/to/Runner.xcodeproj]
require 'fileutils'
require 'tmpdir'
require 'xcodeproj'

NAME = 'VikunjaWidgets'
BUNDLE_ID = 'io.vikunja.app.widgets'
DEPLOYMENT_TARGET = '17.0'
EMBED_PHASE = 'Embed Foundation Extensions'
PRIVACY_MANIFEST = 'PrivacyInfo.xcprivacy'
LOCALIZED_FILES = %w[Localizable.strings Localizable.stringsdict].freeze

EXTENSION_SETTINGS = {
  'PRODUCT_BUNDLE_IDENTIFIER' => BUNDLE_ID,
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'INFOPLIST_FILE' => "#{NAME}/Info.plist",
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Vikunja',
  'CODE_SIGN_ENTITLEMENTS' => "#{NAME}/#{NAME}.entitlements",
  'CODE_SIGN_STYLE' => 'Automatic',
  'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
  'TARGETED_DEVICE_FAMILY' => '1,2',
  'SWIFT_VERSION' => '5.0',
  'SWIFT_EMIT_LOC_STRINGS' => 'YES',
  'APPLICATION_EXTENSION_API_ONLY' => 'YES',
  'SKIP_INSTALL' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks',
                                '@executable_path/../../Frameworks'],
  # The Flutter xcconfigs (set as the base configuration below) define these.
  'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
  'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
  'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  'ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME' => 'WidgetBackground'
}.freeze

def create_extension(project)
  ext = project.new_target(:app_extension, NAME, :ios, DEPLOYMENT_TARGET, project.products_group, :swift)
  # new_target links Foundation through a hard-coded SDK path; Swift links it by itself.
  ext.frameworks_build_phase.files.to_a.each do |build_file|
    ref = build_file.file_ref
    build_file.remove_from_project
    ref&.remove_from_project
  end
  frameworks = project.main_group['Frameworks']
  if frameworks && frameworks.recursive_children.none? { |c| c.is_a?(Xcodeproj::Project::Object::PBXFileReference) }
    frameworks.recursive_children.each(&:remove_from_project)
    frameworks.remove_from_project
  end
  ext
end

def file_reference(group, path)
  group.files.find { |f| f.path == path } || group.new_reference(path)
end

# xcodeproj leaves the type of an .xcprivacy file empty; Xcode writes text.xml.
def privacy_manifest_reference(group)
  file_reference(group, PRIVACY_MANIFEST).tap { |ref| ref.last_known_file_type = 'text.xml' }
end

def add_to_phase(phase, ref)
  phase.add_file_reference(ref, true) unless phase.include?(ref)
end

def sync_sources(ext, group, ext_dir)
  swift = Dir.glob('*.swift', base: ext_dir).sort
  ext.source_build_phase.files.to_a.each do |build_file|
    next if build_file.file_ref.nil? || swift.include?(build_file.file_ref.path)

    ref = build_file.file_ref
    build_file.remove_from_project
    ref.remove_from_project
  end
  swift.each { |name| add_to_phase(ext.source_build_phase, file_reference(group, name)) }
end

def sync_resources(ext, group, ext_dir)
  if Dir.exist?(File.join(ext_dir, 'Assets.xcassets'))
    add_to_phase(ext.resources_build_phase, file_reference(group, 'Assets.xcassets'))
  end
  add_to_phase(ext.resources_build_phase, privacy_manifest_reference(group))
  LOCALIZED_FILES.each { |name| sync_localized(ext, group, ext_dir, name) }
end

def sync_localized(ext, group, ext_dir, name)
  paths = Dir.glob("*.lproj/#{name}", base: ext_dir).sort
  variants = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXVariantGroup) && c.name == name }
  variants&.files&.to_a&.each { |ref| ref.remove_from_project unless paths.include?(ref.path) }
  if paths.empty?
    variants&.remove_from_project
    return
  end

  variants ||= group.new_variant_group(name)
  paths.each do |path|
    ref = variants.files.find { |f| f.path == path }
    unless ref
      ref = variants.new_reference(path)
      ref.name = File.basename(File.dirname(path), '.lproj')
    end
    # xcodeproj leaves the type of a .stringsdict file empty; Xcode writes this one.
    ref.last_known_file_type = 'text.plist.stringsdict' if path.end_with?('.stringsdict')
  end
  add_to_phase(ext.resources_build_phase, variants)
end

def configure_extension(project, ext)
  xcconfigs = project.files.select { |f| f.path.to_s.end_with?('.xcconfig') }
  ext.build_configurations.each do |config|
    base = config.name == 'Debug' ? 'Flutter/Debug.xcconfig' : 'Flutter/Release.xcconfig'
    config.base_configuration_reference = xcconfigs.find { |f| f.path == base } || abort("#{base} missing")
    EXTENSION_SETTINGS.each { |key, value| config.build_settings[key] = value }
  end
end

def embed_in_runner(runner, ext)
  runner.add_dependency(ext)
  embed = runner.copy_files_build_phases.find { |p| p.name == EMBED_PHASE } ||
          runner.new_copy_files_build_phase(EMBED_PHASE)
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.dst_path = ''
  unless embed.include?(ext.product_reference)
    embed.add_file_reference(ext.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
  # With the embed phase after Thin Binary, Xcode reports a build cycle in Runner.
  thin = runner.shell_script_build_phases.find { |p| p.name == 'Thin Binary' } || abort('Thin Binary phase missing')
  phases = runner.build_phases
  return if phases.index(embed) == phases.index(thin) - 1

  phases.delete(embed)
  phases.insert(phases.index(thin), embed)
end

def add_runner_entitlements(project, runner)
  file_reference(project.main_group['Runner'], 'Runner.entitlements')
  runner.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  end
end

def add_runner_privacy_manifest(project, runner)
  add_to_phase(runner.resources_build_phase, privacy_manifest_reference(project.main_group['Runner']))
end

# Writes only when the serialised project differs, so a re-run leaves the file untouched.
def save_if_changed(project, project_path)
  Dir.mktmpdir do |dir|
    candidate = File.join(dir, 'Runner.xcodeproj')
    project.save(candidate)
    current = File.join(project_path, 'project.pbxproj')
    return false if FileUtils.identical?(File.join(candidate, 'project.pbxproj'), current)

    project.save
    true
  end
end

project_path = File.expand_path(ARGV[0] || File.join(__dir__, '..', 'app', 'ios', 'Runner.xcodeproj'))
ios_dir = File.dirname(project_path)
ext_dir = File.join(ios_dir, NAME)
['Info.plist', "#{NAME}.entitlements", PRIVACY_MANIFEST].each do |name|
  abort "#{File.join(ext_dir, name)} missing" unless File.exist?(File.join(ext_dir, name))
end
['Runner.entitlements', PRIVACY_MANIFEST].each do |name|
  path = File.join(ios_dir, 'Runner', name)
  abort "#{path} missing" unless File.exist?(path)
end

project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |t| t.name == 'Runner' } || abort('Runner target missing')
ext = project.targets.find { |t| t.name == NAME } || create_extension(project)

group = project.main_group[NAME] || project.main_group.new_group(NAME, NAME)
file_reference(group, 'Info.plist')
file_reference(group, "#{NAME}.entitlements")
sync_sources(ext, group, ext_dir)
sync_resources(ext, group, ext_dir)
configure_extension(project, ext)
embed_in_runner(runner, ext)
add_runner_entitlements(project, runner)
add_runner_privacy_manifest(project, runner)

puts(save_if_changed(project, project_path) ? "Updated #{NAME} in #{project_path}" : "#{NAME} is up to date")
