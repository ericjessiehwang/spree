FactoryGirl.define do
  factory :address, aliases: [:bill_address, :ship_address], class: Spree::Address do
    firstname 'John'
    lastname 'Doe'
    company 'Company'
    address1 '10 Lovely Street'
    address2 'Northwest'
    city 'Herndon'
    zipcode do
      TwitterCldr::Shared::PostalCodes
        .for_territory(country.iso)
        .sample(1)
        .first
    end
    phone '555-555-0199'
    alternative_phone '555-555-0199'

    state { |address| Spree::State.first || address.association(:state) }
    country do |address|
      if address.state
        address.state.country
      else
        address.association(:country)
      end
    end
  end
end
