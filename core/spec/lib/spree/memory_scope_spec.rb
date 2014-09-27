require 'spec_helper'

describe Spree::MemoryScope do

  let(:base)             { [1, 2, 3]                                   }
  let(:object)           { described_class.new(base, parent_predicate) }
  let(:parent_predicate) { described_class::TAUTOLOGY                  }
  let(:results)          { subject.to_a                                }

  describe '.new' do
    it 'returns frozen objects' do
      expect(object.frozen?).to be(true)
    end
  end

  describe '.memory_scope' do
    it 'defines a named memory scope' do
      scope = Class.new(described_class) do
        memory_scope(:foo) { |member| member.equal?(2) }
      end.new(base)
      expect(scope.foo.to_a).to eql([2])
    end
  end

  describe '.memory_scope_attribute_value' do
    it 'defines a named memory scope for attribute value comparison' do
      scope = Class.new(described_class) do
        memory_scope_attribute_value(:foo, :upcase, 'A')
      end.new(%w[a aa])
      expect(scope.foo.to_a).to eql(['a'])
    end
  end

  shared_examples_for '#each method' do
    context 'with block' do
      subject { object.each { |_item| } }
      it { should be(object) }
    end

    context 'with no block' do
      subject { object.each }

      it { should be_instance_of(to_enum.class) }

      it 'yields the expected values' do
        expect(subject.to_a).to eql(object.to_a)
      end
    end
  end

  describe '#each' do
    subject { object.each }

    context 'with default scope' do
      let(:object) { described_class.new(base) }

      it 'returns all members' do
        expect(results).to eql(base)
      end

      include_examples '#each method'
    end

    context 'with selective predicate' do
      let(:parent_predicate) { ->(member) { member.equal?(1) } }

      it 'returns all selected members' do
        expect(results).to eql([1])
      end

      include_examples '#each method'
    end
  end

  describe '#restrict' do
    subject { object.restrict(&restrict_predicate) }

    context 'with tautology' do
      let(:restrict_predicate) { described_class::TAUTOLOGY }

      context 'on default parent scope' do
        # hack to allow message expectation on frozen object
        let(:described_class) do
          Class.new(Spree::MemoryScope) do
            def freeze
              self
            end
          end
        end

        it 'returns all members' do
          expect(results).to eql(base)
        end

        it 'still operates on original base' do
          expect(base).to receive(:create!)
          expect(object).to_not receive(:create!)
          subject.create!(double('attributes'))
        end
      end

      context 'on restricted parent scope' do
        let(:parent_predicate) { ->(member) { member.equal?(1) } }

        it 'returns restricted members' do
          expect(results).to eql([1])
        end
      end
    end

    context 'with selective predicate' do
      let(:restrict_predicate) { ->(member) { member.equal?(1) } }

      context 'on default parent scope' do
        it 'returns all selected members' do
          expect(results).to eql([1])
        end
      end

      context 'on restricted parent scope' do
        context 'when predicate includes parent items' do
          let(:parent_predicate) { ->(member) { member < 3 } }

          it 'returns the intersection' do
            expect(results).to eql([1])
          end
        end

        context 'when predicate does not include parent items' do
          let(:parent_predicate) { ->(member) { member > 3 } }

          it 'returns the intersection' do
            expect(results).to eql([])
          end
        end
      end
    end
  end

  describe '#where' do
    subject { object.where(*arguments) }

    let(:base) do
      [
        double('member a', id: 1, foo: 'bar'),
        double('member b', id: 2, foo: 'baz')
      ]
    end

    context 'with single argument' do
      let(:arguments) { [argument] }

      context 'with hash as argument' do
        context 'single key' do
          let(:argument) { { foo: 'bar' } }

          it 'restricts members by attribute values' do
            expect(results).to eql([base.fetch(0)])
          end
        end

        context 'multiple keys' do
          let(:argument) { { id: 1, foo: 'baz' } }

          it 'restricts members by attribute values' do
            expect(results).to eql([])
          end
        end
      end

      context 'with string as argument' do
        let(:argument) { 'id = 1' }

        it 'raises unsupported error' do
          expect { subject }.to raise_error(
            described_class::UnsupportedInterfaceError,
            '#where interface with non Hash argument is unsupported'
          )
        end
      end

      context 'with array as argument' do
        let(:argument) { [] }

        it 'raises unsupported error' do
          expect { subject }.to raise_error(
            described_class::UnsupportedInterfaceError,
            '#where interface with non Hash argument is unsupported'
          )
        end
      end
    end

    context 'with multiple arguments' do
      let(:arguments) { [double('argument'), double('argument')] }

      it 'raises unsupported error' do
        expect { subject }.to raise_error(
          described_class::UnsupportedInterfaceError,
          '#where interface with 2 argument is unsupported'
        )
      end
    end

    context 'with no arguments' do
      let(:arguments) { [] }

      it 'raises unsupported error' do
        expect { subject }.to raise_error(
          described_class::UnsupportedInterfaceError,
          '#where interface with 0 argument is unsupported'
        )
      end
    end
  end

  describe '#exists?' do
    subject { object.exists? }

    context 'when there are no members' do
      let(:base) { [] }

      it { should be(false) }
    end

    context 'when there are members' do
      it { should be(true) }
    end
  end

  describe '#empty?' do
    subject { object.empty? }

    context 'when there are no members' do
      let(:base) { [] }

      it { should be(true) }
    end

    context 'when there are members' do
      it { should be(false) }
    end
  end

  describe '#sum' do
    subject { object.sum(:to_f) }

    it 'returns the sum per attribute' do
      should be(6.0)
    end
  end

  describe '#create!' do
    let(:attributes) { double('attributes') }
    let(:result)     { double('result') }

    subject { object.create!(attributes) }

    it 'forwards arguments to base#create!' do
      expect(base).to receive(:create!).with(attributes).and_return(result)
      should be(result)
    end
  end

  describe '#build' do
    let(:attributes) { double('attributes') }
    let(:result)     { double('result') }

    subject { object.build(attributes) }

    it 'forwards arguments to base#build' do
      expect(base).to receive(:build).with(attributes).and_return(result)
      should be(result)
    end
  end

  describe '#update_all' do
    let(:attributes) { double('attributes') }

    let(:base) { [double('member a'), double('member b')] }

    subject { object.update_all(attributes) }

    it 'calls #update_columns on all members' do
      base.each do |member|
        expect(member).to receive(:update_columns).with(attributes)
      end
      should be(2)
    end
  end

  describe '#delete_all' do
    subject { object.delete_all }

    let(:base) { [double('member a', id: 1), double('member b', id: 2)] }

    it 'calls #delete_all on member #id based relation and #reset base' do
      relation      = double('relation')
      rows_affected = double('rows affected')

      expect(base).to receive(:where).with(id: [1, 2]).and_return(relation).ordered
      expect(relation).to receive(:delete_all).and_return(rows_affected).ordered
      expect(base).to receive(:reset).ordered
      should be(rows_affected)
    end
  end

  describe '#destroy_all' do
    subject { object.destroy_all }

    let(:base) { [double('member a', id: 1), double('member b', id: 2)] }

    it 'calls #delete_all on member #id based relation and #reset base' do
      relation          = double('relation')
      objects_destroyed = double('objects destroyed')

      expect(base).to receive(:where).with(id: [1, 2]).and_return(relation).ordered
      expect(relation).to receive(:destroy_all).and_return(objects_destroyed).ordered
      expect(base).to receive(:reset).ordered
      should be(objects_destroyed)
    end
  end

  describe '#find' do
    subject { object.find(argument) }
    let(:base) { [double('member a', id: 1), double('member b', id: 2)] }

    context 'when member with matching id as Fixnum is found' do
      let(:argument) { 2 }

      it { should be(base.at(1)) }
    end

    context 'when member with matching id as String is found' do
      let(:argument) { '2' }

      it { should be(base.at(1)) }
    end

    context 'when member with matching id as String containing trailing garbadge is found' do
      let(:argument) { '2-foo' }

      it { should be(base.at(1)) }
    end

    context 'when member with matching id is NOT found' do
      let(:argument) { 100 }

      let(:base) do
        double(
          'association',
          proxy_association: double(
             reflection: double(
               inverse_of: double(
                 active_record: double(
                   to_s: 'Spree::SomeModel'
                 )
               )
             )
          ),
          each: nil
        )
      end

      it 'should raise an error' do
        expect { subject }.to raise_error(
          ActiveRecord::RecordNotFound,
          %q(Couldn't find Spree::SomeModel with 'id'=100)
        )
      end
    end
  end

  describe '#pluck' do
    let(:base) { [double('member a', id: 1), double('member b', id: 2)] }

    subject { object.pluck(:id) }

    it 'returns an array of attributes of members' do
      should eql([1, 2])
    end
  end

  describe '#inspect' do
    subject { object.inspect}

    it { should eql("<Spree::MemoryScope @base=#{base.inspect} @predicate=#{parent_predicate.inspect}>") }
  end
end
