#!/usr/bin/env ruby
# frozen_string_literal: true

# Sets up the RunnerTests target of the Flutter iOS project for the XCTests of the
# native code (app/ios/RunnerTests): a test bundle without a host app, so that testing
# builds no Flutter app, which compiles the Swift files it tests from the Runner and
# the VikunjaWidgets extension itself, and a shared RunnerTests scheme for
# `xcodebuild test`. It also keeps the Runner target's Swift files in sync with
# app/ios/Runner. Run it after tool/add_widget_extension.rb. Re-running it changes
# nothing unless files were added or removed. Needs only the xcodeproj gem, which
# ships with CocoaPods.
#
#   ruby tool/add_runner_tests.rb [path/to/Runner.xcodeproj]
require 'fileutils'
require 'tmpdir'
require 'xcodeproj'

NAME = 'RunnerTests'
# Xcode 27's XCTest is built for iOS 17, as is the extension; below it the linker warns.
DEPLOYMENT_TARGET = '17.0'
# Every widget file but the bundle, whose @main has no place in a test bundle.
TESTED_SOURCES = {
  'Runner' => %w[LocationRemoval.swift NotificationResponses.swift],
  'VikunjaWidgets' => %w[
    AppGroupStore.swift DoneTaps.swift ListConfiguration.swift ListSelection.swift
    MarkDoneIntent.swift QuickAddWidget.swift TasksTimeline.swift TasksWidget.swift
    WidgetData.swift WidgetKinds.swift
  ]
}.freeze

def file_reference(group, path)
  group.files.find { |f| f.path == path } || group.new_reference(path)
end

def add_to_phase(phase, ref)
  phase.add_file_reference(ref, true) unless phase.include?(ref)
end

# The group's Swift references are the folder's Swift files, each in the target.
def sync_swift(target, group, dir)
  swift = Dir.glob('*.swift', base: dir).sort
  group.files.to_a.each do |ref|
    ref.remove_from_project if ref.path.to_s.end_with?('.swift') && !swift.include?(ref.path)
  end
  swift.map { |name| file_reference(group, name).tap { |ref| add_to_phase(target.source_build_phase, ref) } }
end

def tested_references(project)
  TESTED_SOURCES.flat_map do |group_name, names|
    group = project.main_group[group_name] || abort("#{group_name} group missing")
    names.map { |name| group.files.find { |f| f.path == name } || abort("#{group_name}/#{name} missing") }
  end
end

def compile_only(tests, refs)
  refs.each { |ref| add_to_phase(tests.source_build_phase, ref) }
  tests.source_build_phase.files.to_a.each do |build_file|
    build_file.remove_from_project unless refs.include?(build_file.file_ref)
  end
end

def without_host(project, tests, runner)
  tests.build_configurations.each do |config|
    config.build_settings.delete('TEST_HOST')
    config.build_settings.delete('BUNDLE_LOADER')
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  end
  tests.dependencies.to_a.each { |dependency| dependency.remove_from_project if dependency.target == runner }
  project.root_object.attributes.dig('TargetAttributes', tests.uuid)&.delete('TestTargetID')
end

def scheme(tests)
  Xcodeproj::XCScheme.new.tap do |scheme|
    scheme.add_build_target(tests, false)
    scheme.add_test_target(tests)
  end
end

# Writes only when the serialised project or scheme differs, so a re-run leaves the files untouched.
def save_if_changed(project, project_path, tests)
  Dir.mktmpdir do |dir|
    candidate = File.join(dir, 'Runner.xcodeproj')
    project.save(candidate)
    scheme(tests).save_as(candidate, NAME)
    changed = false
    current = File.join(project_path, 'project.pbxproj')
    unless FileUtils.identical?(File.join(candidate, 'project.pbxproj'), current)
      project.save
      changed = true
    end
    scheme_path = File.join('xcshareddata', 'xcschemes', "#{NAME}.xcscheme")
    target = File.join(project_path, scheme_path)
    unless File.exist?(target) && FileUtils.identical?(File.join(candidate, scheme_path), target)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(candidate, scheme_path), target)
      changed = true
    end
    changed
  end
end

project_path = File.expand_path(ARGV[0] || File.join(__dir__, '..', 'app', 'ios', 'Runner.xcodeproj'))
ios_dir = File.dirname(project_path)
TESTED_SOURCES.each do |folder, names|
  names.each do |name|
    path = File.join(ios_dir, folder, name)
    abort "#{path} missing" unless File.exist?(path)
  end
end

project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |t| t.name == 'Runner' } || abort('Runner target missing')
tests = project.targets.find { |t| t.name == NAME } || abort("#{NAME} target missing")
abort 'VikunjaWidgets missing: run tool/add_widget_extension.rb first' unless project.main_group['VikunjaWidgets']

sync_swift(runner, project.main_group['Runner'] || abort('Runner group missing'), File.join(ios_dir, 'Runner'))
group = project.main_group[NAME] || abort("#{NAME} group missing")
own = sync_swift(tests, group, File.join(ios_dir, NAME))
compile_only(tests, own + tested_references(project))
without_host(project, tests, runner)

puts(save_if_changed(project, project_path, tests) ? "Updated #{NAME} in #{project_path}" : "#{NAME} is up to date")
