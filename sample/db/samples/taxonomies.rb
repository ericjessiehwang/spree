taxonomies = [
  { :name => "מחלקות" },
  { :name => "מוצרים במבצע" }
]

taxonomies.each do |taxonomy_attrs|
  Spree::Taxonomy.create!(taxonomy_attrs)
end
