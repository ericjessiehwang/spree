require 'rake'
require 'rubygems/package_task'
require 'thor/group'
begin
  require 'spree/testing_support/common_rake'
rescue LoadError
  raise "Could not find spree/testing_support/common_rake. You need to run this command using Bundler."
end

SPREE_GEMS = %w(core api cmd backend frontend sample).freeze

task default: :test

namespace :i18n do
  desc "Gives a health report pertaining to the locale files in core/config/locales"
  task :health_check do
    Dir.chdir("#{File.dirname(__FILE__)}/core") do
      sh "i18n-tasks health"
    end
  end

  desc "Lists all unused locales in en.yml"
  task :unused do
    Dir.chdir("#{File.dirname(__FILE__)}/core") do
      sh "i18n-tasks unused --locales en"
    end
  end

  desc "Finds translations in the view files that are not present as keys in en.yml"
  task :add_missing_translations_to_base_file do
    Dir.chdir("#{File.dirname(__FILE__)}/core") do
      sh "i18n-tasks add-missing --locales en en-GB en-AU en-US en-IN en-NZ"
    end
  end

  desc "Translates all locales from en.yml to all other none English files in core/config/locales"
  task :translate do
    Dir.chdir("#{File.dirname(__FILE__)}/core") do
      sh "i18n-tasks translate-missing"
    end
  end
end

desc "Runs all tests in all Spree engines"
task test: :test_app do
  SPREE_GEMS.each do |gem_name|
    Dir.chdir("#{File.dirname(__FILE__)}/#{gem_name}") do
      sh 'rspec'
    end
  end
end

desc "Generates a dummy app for testing for every Spree engine"
task :test_app do
  SPREE_GEMS.each do |gem_name|
    Dir.chdir("#{File.dirname(__FILE__)}/#{gem_name}") do
      sh 'rake test_app'
    end
  end
end

desc "clean the whole repository by removing all the generated files"
task :clean do
  rm_f  "Gemfile.lock"
  rm_rf "sandbox"
  rm_rf "pkg"

  SPREE_GEMS.each do |gem_name|
    rm_f  "#{gem_name}/Gemfile.lock"
    rm_rf "#{gem_name}/pkg"
    rm_rf "#{gem_name}/spec/dummy"
  end
end

namespace :gem do
  def version
    require 'spree/core/version'
    Spree.version
  end

  def for_each_gem
    SPREE_GEMS.each do |gem_name|
      yield "pkg/spree_#{gem_name}-#{version}.gem"
    end
    yield "pkg/spree-#{version}.gem"
  end

  desc "Build all spree gems"
  task :build do
    pkgdir = File.expand_path("../pkg", __FILE__)
    FileUtils.mkdir_p pkgdir

    SPREE_GEMS.each do |gem_name|
      Dir.chdir(gem_name) do
        sh "gem build spree_#{gem_name}.gemspec"
        mv "spree_#{gem_name}-#{version}.gem", pkgdir
      end
    end

    sh "gem build spree.gemspec"
    mv "spree-#{version}.gem", pkgdir
  end

  desc "Install all spree gems"
  task install: :build do
    for_each_gem do |gem_path|
      Bundler.with_clean_env do
        sh "gem install #{gem_path}"
      end
    end
  end

  desc "Release all gems to rubygems"
  task release: :build do
    sh "git tag -a -m \"Version #{version}\" v#{version}"

    for_each_gem do |gem_path|
      sh "gem push '#{gem_path}'"
    end
  end
end

desc "Creates a sandbox application for simulating the Spree code in a deployed Rails app"
task :sandbox do
  Bundler.with_clean_env do
    exec("bin/sandbox.sh")
  end
end
