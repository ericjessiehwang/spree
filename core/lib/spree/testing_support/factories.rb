require 'factory_girl'

module SpreeSpec
  module Zone
    def self.global
      Spree::Zone.find_by(name: 'GlobalZone') || FactoryGirl.create(:global_zone)
    end
  end
end

Dir["#{File.dirname(__FILE__)}/factories/**"].each do |f|
  require File.expand_path(f)
end

FactoryGirl.define do
  sequence(:random_string)      { FFaker::Lorem.sentence }
  sequence(:random_description) { FFaker::Lorem.paragraphs(1 + Kernel.rand(5)).join("\n") }
  sequence(:random_email)       { FFaker::Internet.email }

  sequence(:sku) { |n| "SKU-#{n}" }
end
