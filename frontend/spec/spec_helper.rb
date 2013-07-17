if ENV["COVERAGE"]
  # Run Coverage report
  require 'simplecov'
  SimpleCov.start do
    add_group 'Controllers', 'app/controllers'
    add_group 'Helpers', 'app/helpers'
    add_group 'Mailers', 'app/mailers'
    add_group 'Models', 'app/models'
    add_group 'Views', 'app/views'
    add_group 'Libraries', 'lib'
  end
end

# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)
require 'rspec/rails'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'database_cleaner'

if ENV["CHECK_TRANSLATIONS"]
  require "spree/testing_support/i18n"
end

require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/capybara_ext'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/flash'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/order_walkthrough'

require 'paperclip/matchers'

require 'capybara/rails'
require 'capybara/rspec'

Capybara.default_driver = :accessible
Capybara.configure do |config|
  config.match = :prefer_exact
  config.ignore_hidden_elements = false
end

RSpec.configure do |config|
  config.color = true
  config.mock_with :rspec

  config.fixture_path = File.join(File.expand_path(File.dirname(__FILE__)), "fixtures")

  #config.include Devise::TestHelpers, :type => :controller
  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  config.around(:each, :inaccessible => true) do |example|
    Capybara::Accessible.skip_audit { example }
  end

  config.before(:each) do
    WebMock.disable!
    # if example.metadata[:js]
      DatabaseCleaner.strategy = :truncation
    # else
      # DatabaseCleaner.strategy = :transaction
    # end
  end

  config.before(:each) do
    DatabaseCleaner.start
    reset_spree_preferences
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.after(:each, :type => :request) do
    missing_translations = page.body.scan(/translation missing: #{I18n.locale}\.(.*?)[\s<\"&]/)
    if missing_translations.any?
      #binding.pry
      puts "Found missing translations: #{missing_translations.inspect}"
      puts "In spec: #{example.location}"
    end
  end


  config.include FactoryGirl::Syntax::Methods

  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::ControllerRequests
  config.include Spree::TestingSupport::Flash

  config.include Paperclip::Shoulda::Matchers

  config.fail_fast = ENV['FAIL_FAST'] || false
end
