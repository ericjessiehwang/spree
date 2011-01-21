Then /^I should see listing taxonomies tabular attributes$/ do
  output = tableish('table#listing_taxonomies tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'

  data = output[1]
  #data[0].should == Taxonomy.limit(1).order('name asc').to_a.first.name
end

Then /^I should see listing payment methods tabular attributes$/ do
  output = tableish('table#listing_payment_methods tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "Provider"
  data[2].should == "Environment"
  data[3].should == "Display"
  data[4].should == "Active"

  data = output[1]
  #data[0].should == PaymentMethod.limit(1).order('name asc').to_a.first.name
  #data[1].should == PaymentMethod.limit(1).order('name asc').to_a.first.provider
end

Then /^I should see listing states tabular attributes$/ do
  output = tableish('table#listing_states tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "Abbreviation"

  data = output[1]
  data[0].should == State.limit(1).order('name asc').to_a.first.name
  data[1].should == State.limit(1).order('name asc').to_a.first.abbr
end

Then /^I should see listing zones tabular attributes$/ do
  output = tableish('table#listing_zones tr', 'td,th')
  data = output[0]
  data[0].should match(/Name/)
  data[1].should == "Description"

  data = output[1]
  data[0].should == Zone.limit(1).order('name asc').to_a.first.name
  data[1].should == Zone.limit(1).order('name asc').to_a.first.description
end

Then /^I should see listing tax categories tabular attributes$/ do
  output = tableish('table#listing_tax_categories tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == "Description"
  data[2].should == "Default"

  data = output[1]
  data[0].should == TaxCategory.limit(1).order('name asc').to_a.first.name
end
