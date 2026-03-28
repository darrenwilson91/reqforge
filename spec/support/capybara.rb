require "capybara/rspec"

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :system

  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_headless
  end
end
