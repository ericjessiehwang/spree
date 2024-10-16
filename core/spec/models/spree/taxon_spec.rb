require 'spec_helper'

describe Spree::Taxon, type: :model do
  let(:taxonomy) { create(:taxonomy) }
  let(:taxon) { build(:taxon, name: 'Ruby on Rails', parent: nil) }

  it_behaves_like 'metadata'

  describe '#to_param' do
    subject { super().to_param }

    it { is_expected.to eql taxon.permalink }
  end

  context 'validations' do
    describe '#check_for_root' do
      let(:valid_taxon) { build(:taxon, name: 'Vaild Rails', parent_id: 1, taxonomy: taxonomy) }

      it 'does not validate the taxon' do
        expect(taxon.valid?).to eq false
      end

      it 'validates the taxon' do
        expect(valid_taxon.valid?).to eq true
      end
    end

    describe '#parent_belongs_to_same_taxonomy' do
      let(:valid_parent) { create(:taxon, name: 'Valid Parent', taxonomy: taxonomy) }
      let(:invalid_parent) { create(:taxon, name: 'Invalid Parent', taxonomy: create(:taxonomy)) }

      it 'does not validate the taxon' do
        expect(build(:taxon, taxonomy: taxonomy, parent: invalid_parent).valid?).to eq false
      end

      it 'validates the taxon' do
        expect(build(:taxon, taxonomy: taxonomy, parent: valid_parent).valid?).to eq true
      end
    end
  end

  context 'when using another locale' do
    before do
      root_taxon = taxon.taxonomy.root
      taxon.update!(name: 'EN name', parent: taxon.taxonomy.root)

      Mobility.with_locale(:pl) do
        root_taxon.update!(name: 'PL taxonomy')

        taxon.update!(
          name: 'PL name',
          description: 'PL description'
        )
      end
    end

    let(:taxon_pl_translation) { taxon.translations.find_by(locale: 'pl') }

    it 'translates taxon fields' do
      expect(taxon.name).to eq('EN name')

      expect(taxon_pl_translation).to be_present
      expect(taxon_pl_translation.name).to eq('PL name')
      expect(taxon_pl_translation.permalink).to eq('pl-taxonomy/pl-name')
      expect(taxon_pl_translation.description).to eq('PL description')
    end
  end

  context 'set_permalink' do
    it 'sets permalink correctly when no parent present' do
      taxon.set_permalink
      expect(taxon.permalink).to eql 'ruby-on-rails'
    end

    it 'supports Chinese characters' do
      taxon.name = '你好'
      taxon.set_permalink
      expect(taxon.permalink).to eql 'ni-hao'
    end

    it 'stores old slugs in FriendlyIds history' do
      # Stub out the unrelated methods that cannot handle a save without an id
      allow(subject).to receive(:set_depth!)
      expect(subject).to receive(:create_slug)
      subject.permalink = 'custom-slug'
      subject.run_callbacks :save
    end

    context 'with parent taxon' do
      let(:parent) { FactoryBot.build(:taxon, permalink: 'brands') }

      before       { allow(taxon).to receive_messages parent: parent }

      it 'sets permalink correctly when taxon has parent' do
        taxon.set_permalink
        expect(taxon.permalink).to eql 'brands/ruby-on-rails'
      end

      it 'sets permalink correctly with existing permalink present' do
        taxon.permalink = 'b/rubyonrails'
        taxon.set_permalink
        expect(taxon.permalink).to eql 'brands/rubyonrails'
      end

      it 'supports Chinese characters' do
        taxon.name = '我'
        taxon.set_permalink
        expect(taxon.permalink).to eql 'brands/wo'
      end

      # Regression test for #3390
      context 'setting a new node sibling position via :child_index=' do
        let(:idx) { rand(0..100) }

        before { allow(parent).to receive(:move_to_child_with_index) }

        context 'taxon is not new' do
          before { allow(taxon).to receive(:new_record?).and_return(false) }

          it 'passes the desired index move_to_child_with_index of :parent ' do
            expect(taxon).to receive(:move_to_child_with_index).with(parent, idx)

            taxon.child_index = idx
          end
        end
      end
    end
  end

  # Regression test for #2620
  context 'creating a child node using first_or_create' do
    let!(:taxonomy) { create(:taxonomy) }

    it 'does not error out' do
      expect { taxonomy.root.children.unscoped.where(name: 'Some name', parent_id: taxonomy.taxons.first.id).first_or_create }.not_to raise_error
    end
  end

  context 'ransackable_associations' do
    it { expect(described_class.whitelisted_ransackable_associations).to include('taxonomy') }
  end

  describe '#cached_self_and_descendants_ids' do
    it { expect(taxon.cached_self_and_descendants_ids).to eq(taxon.self_and_descendants.ids) }
  end

  describe '#copy_taxonomy_from_parent' do
    let!(:parent) { create(:taxon, taxonomy: taxonomy) }
    let(:taxon) { build(:taxon, parent: parent, taxonomy: nil) }

    it { expect(taxon.valid?).to eq(true) }
    it { expect { taxon.save! }.to change(taxon, :taxonomy).to(taxonomy) }
  end

  describe '#sync_taxonomy_name' do
    let!(:taxonomy) { create(:taxonomy, name: 'Soft Goods') }
    let!(:taxon) { create(:taxon, taxonomy: taxonomy, name: 'Socks' ) }

    context 'when none root taxon name is updated' do
      it 'does not update the taxonomy name' do
        taxon.update!(name: 'Shoes')
        taxonomy.reload

        expect(taxonomy.name).not_to eql taxon.name
        expect(taxonomy.name).to eql 'Soft Goods'
      end
    end

    context 'when root taxon name is updated' do
      it 'updates the taxonomy name' do
        root_taxon = described_class.find_by(name: 'Soft Goods')

        root_taxon.update!(name: 'Hard Goods')
        taxonomy.reload

        expect(taxonomy.name).not_to eql 'Soft Goods'
        expect(taxonomy.name).to eql root_taxon.name
      end
    end

    context 'when root taxon name is updated with special characters' do
      it 'updates the taxonomy name' do
        root_taxon = described_class.find_by(name: 'Soft Goods')

        root_taxon.update!(name: 'spÉcial Numérique ƒ ˙ ¨ πø∆©')
        taxonomy.reload

        expect(taxonomy.name).not_to eql 'Soft Goods'
        expect(taxonomy.name).to eql root_taxon.name
      end
    end

    context 'when root taxon attribute other than name is updated' do
      it 'does not update the taxonomy' do
        root_taxon = described_class.find_by(name: 'Soft Goods')
        taxonomy_updated_at = taxonomy.updated_at.to_s

        expect {
          root_taxon.update!(permalink: 'something-else')
          root_taxon.reload
          taxonomy.reload
        }.not_to change { taxonomy.updated_at.to_s }.from(taxonomy_updated_at)

        expect(root_taxon.permalink).to eql 'something-else'
      end
    end
  end

  describe '#localized_slugs_for_store' do
    let(:store) { create(:store, default_locale: 'fr', supported_locales: 'en,pl,fr') }
    let(:taxonomy) { create(:taxonomy, name: 'categories', store: store) }
    let(:taxon) { create(:taxon, taxonomy: taxonomy, permalink: 'test_slug_en') }
    let!(:taxon_translation_fr) { taxon.translations.create(slug: 'test_slug_fr', locale: 'fr') }
    let!(:root_taxon) { taxonomy.taxons.find_by(parent_id: nil) }

    before { Spree::Locales::SetFallbackLocaleForStore.new.call(store: store) }

    subject { taxon.localized_slugs_for_store(store) }

    context 'when there are slugs in locales not supported by the store' do
      let!(:taxon_translation_pl) { taxon.translations.create(slug: 'test_slug_pl', locale: 'pl') }
      let!(:taxon_translation_de) { taxon.translations.create(slug: 'test_slug_de', locale: 'de') }

      let(:expected_slugs) do
        {
          'en' => 'categories/test-slug-en',
          'fr' => 'categories/test-slug-fr',
          'pl' => 'categories/test-slug-pl'
        }
      end

      it 'returns only slugs in locales supported by the store' do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'when one of the supported locales does not have a translation' do
      let(:expected_slugs) do
        {
          'en' => 'categories/test-slug-en',
          'fr' => 'categories/test-slug-fr',
          'pl' => 'categories/test-slug-fr'
        }
      end

      it "falls back to store's default locale" do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'when setting the slug translations for taxonomy' do
      let!(:root_taxon_translation_pl) { root_taxon.translations.create(slug: 'slug with space', locale: 'pl') }
      let!(:root_taxon_translation_fr) { root_taxon.translations.create(slug: 'categories-fr', locale: 'fr') }

      let(:expected_slugs) do
        {
          'en' => 'categories',
          'fr' => 'categories-fr',
          'pl' => 'slug-with-space'
        }
      end

      it "sets the slugs in slug format" do
        expect(root_taxon.reload.localized_slugs_for_store(store)).to match(expected_slugs)
      end
    end

    context 'when setting the slugs in taxon under taxomony with different parent slug' do
      let!(:root_taxon_translation_pl) { root_taxon.translations.create(slug: 'slug with space', locale: 'pl') }
      let!(:taxon_translation_pl) { taxon.translations.create(locale: 'pl') }

      let(:expected_slugs) do
        {
          'en' => 'categories/test-slug-en',
          'fr' => 'categories/test-slug-fr',
          'pl' => "slug-with-space/#{taxon.name.to_url}"
        }
      end

      it "sets the slug in valid format" do
        expect(taxon.localized_slugs_for_store(store)).to match(expected_slugs)
      end
    end
  end

  describe '#regenerate_pretty_name_and_permalink' do
    let!(:taxon) { create(:taxon, name: 'Category#1', taxonomy: taxonomy) }

    it 'regenerates pretty name and permalink' do
      expect(taxon.pretty_name).to eq("#{taxon.parent.pretty_name} -> #{taxon.name}")
      expect(taxon.permalink).to eq("#{taxon.parent.permalink}/#{taxon.name.to_url}")
    end

    context "when parent's permalink is changed" do
      before do
        taxon.parent.update!(permalink: 'new-permalink')
      end

      it 'updates the pretty name and permalink' do
        expect(taxon.reload.pretty_name).to eq("#{taxon.parent.pretty_name} -> #{taxon.name}")
        expect(taxon.permalink).to eq("new-permalink/#{taxon.name.to_url}")
      end
    end

    context 'when parent name is changed' do
      before do
        taxon.parent.update!(name: 'New Parent')
      end

      it 'updates the pretty name and permalink' do
        expect(taxon.reload.pretty_name).to eq("New Parent -> #{taxon.name}")
        expect(taxon.permalink).to eq("#{taxon.parent.permalink}/#{taxon.name.to_url}")
      end
    end

    context 'with translations' do
      before do
        Mobility.with_locale(:pl) do
          taxon.update!(name: 'Kategoria#1')
          taxon.reload

          taxon.parent.update!(name: 'Kategoria')
        end
      end

      it 'updates the pretty name and permalink for translations as well' do
        Mobility.with_locale(:pl) do
          expect(taxon.reload.pretty_name).to eq('Kategoria -> Kategoria#1')
          expect(taxon.permalink).to eq('kategoria/kategoria-number-1')
        end
      end
    end

    context 'when taxon is moved' do
      let(:parent2) { create(:taxon, name: 'Parent2', permalink: 'parent2', taxonomy: taxonomy) }
      let(:taxon2) { create(:taxon, name: 'Child', parent: parent2, permalink: 'child', taxonomy: taxonomy) }

      before do
        taxon.parent.update!(name: 'Grandparent', permalink: 'grandparent')
        taxon.update!(name: 'Parent', permalink: 'parent')

        parent2
        taxon2

        Mobility.with_locale(:pl) do
          taxon.parent.update!(name: 'Dziadek', permalink: 'dziadek')
          taxon.update!(name: 'Rodzic')

          parent2.update!(name: 'Rodzic2', permalink: 'rodzic2')
          taxon2.update!(name: 'Dziecko')
        end

        expect(taxon.permalink).to eq('grandparent/parent')
        expect(taxon.pretty_name).to eq('Grandparent -> Parent')

        expect(taxon2.permalink).to eq('grandparent/parent2/child')
        expect(taxon2.pretty_name).to eq('Grandparent -> Parent2 -> Child')

        Mobility.with_locale(:pl) do
          expect(taxon.reload.pretty_name).to eq('Dziadek -> Rodzic')
          expect(taxon.permalink).to eq('dziadek/rodzic')

          expect(taxon2.pretty_name).to eq('Dziadek -> Rodzic2 -> Dziecko')
          expect(taxon2.permalink).to eq('dziadek/rodzic2/dziecko')
        end
      end

      it 'updates the pretty name and permalink' do
        taxon2.move_to_child_with_index(taxon, 0)

        expect(taxon2.reload.pretty_name).to eq('Grandparent -> Parent -> Child')
        expect(taxon2.permalink).to eq('grandparent/parent/child')

        Mobility.with_locale(:pl) do
          expect(taxon2.reload.pretty_name).to eq('Dziadek -> Rodzic -> Dziecko')
          expect(taxon2.permalink).to eq('dziadek/rodzic/dziecko')
        end
      end

      it 'updates the pretty name and permalink when move is done inside different locales' do
        Mobility.with_locale(:pl) do
          taxon2.move_to_child_with_index(taxon, 0)
        end

        expect(taxon2.permalink).to eq('grandparent/parent/child')
        expect(taxon2.reload.pretty_name).to eq('Grandparent -> Parent -> Child')

        Mobility.with_locale(:pl) do
          expect(taxon2.reload.pretty_name).to eq('Dziadek -> Rodzic -> Dziecko')
          expect(taxon2.permalink).to eq('dziadek/rodzic/dziecko')
        end
      end
    end
  end

  describe '#pretty_name' do
    let!(:taxon) { create(:taxon, name: 'Category#1', taxonomy: taxonomy) }

    context '1 lvl deep' do
      it 'returns taxonomy name and taxon name' do
        expect(taxon.pretty_name).to eq("#{taxonomy.root.pretty_name} -> #{taxon.name}")
      end
    end

    context '2+ lvl deep' do
      let(:taxon_parent) { create(:taxon, name: 'Parent', taxonomy: taxonomy) }

      before do
        taxon.parent = taxon_parent
        taxon.save!
      end

      it 'returns parent name and taxon name' do
        expect(taxon.reload.pretty_name).to eq("#{taxonomy.root.pretty_name} -> Parent -> Category#1")
      end

      context 'when name is updated' do
        before do
          taxon.name = 'New Name'
          taxon.save!
        end

        it 'returns the updated pretty name' do
          expect(taxon.reload.pretty_name).to eq("#{taxonomy.root.pretty_name} -> Parent -> New Name")
        end
      end

      context 'when parent name is updated' do
        before do
          taxon_parent.name = 'New Parent'
          taxon_parent.save!
        end

        it 'returns the updated pretty name' do
          expect(taxon.reload.pretty_name).to eq("#{taxonomy.root.pretty_name} -> New Parent -> Category#1")
        end
      end
    end

    context 'when `always_use_translations` is disabled' do
      before do
        allow(Spree::Config).to receive(:always_use_translations).and_return(false)
      end

      it 'sets the pretty name' do
        expect(taxon.reload.pretty_name).to eq("#{taxonomy.name} -> #{taxon.name}")
      end
    end

    context 'when `always_use_translations` is enabled' do
      before do
        allow(Spree::Config).to receive(:always_use_translations).and_return(true)
      end

      it 'sets the pretty name' do
        expect(taxon.reload.pretty_name).to eq("#{taxonomy.name} -> #{taxon.name}")
      end
    end
  end

  describe '#store' do
    let(:taxonomy) { create(:taxonomy) }
    let(:taxon) { build(:taxon, taxonomy: taxonomy) }

    it 'returns the store from the taxonomy' do
      expect(taxon.store).to eq(taxonomy.store)
    end
  end
end
