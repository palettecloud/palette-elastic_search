require 'spec_helper'
require 'pry'
require 'user'

RSpec.describe Palette::ElasticSearch::QueryFactory do

  it 'has a version number' do
    expect(Palette::ElasticSearch::VERSION).not_to be nil
  end

  describe 'json' do
    let(:attributes) do
      {
          name: 'Steve Jobs',
          name_prefix: 'Steve Jobs',
          age: 50,
          is_admin: true,
          geo_point: {
              distance: '1km',
              latitude: '41.12',
              longitude: '-71.34'
          },
          'phone_numbers.number': '+81 01-2345-6789',
          created_at: Date.parse('2018-1-1')
      }
    end

    let(:result) do
      {
          query: {
              bool: {
                  must: [
                      {
                          bool: {
                              must: [
                                  {match: {name: {query: "Steve Jobs", analyzer: :ngram}}}
                              ]
                          }
                      },
                      {
                          bool: {
                              must: [
                                  {match: {name_prefix: {query: "Steve Jobs", analyzer: "whitespace"}}}
                              ]
                          }
                      },
                      {
                          nested: {
                              path: "phone_numbers",
                              query: {
                                  bool: {
                                      must: [
                                          {match: {"phone_numbers.number": {query: "+81 01-2345-6789", analyzer: :keyword_analyzer}}}
                                      ]
                                  }
                              }
                          }
                      },
                      {
                          range: {
                              created_at: {
                                  gte: Time.parse("2018-01-01 00:00:00.000000000 +0900"),
                                  lte: Time.parse("2018-01-01 23:59:59.999999999 +0900")
                              }
                          }
                      }
                  ],
                  filter: [
                      { term: { age: 50 } },
                      { term: { is_admin: true } },
                      { geo_distance: {distance: '1km', location: "41.12,-71.34"} }
                  ]
              }
          }
      }
    end

    subject do
      ::Palette::ElasticSearch::QueryFactory.build([User], attributes)
    end

    it 'jsonが一致すること' do
      expect(subject).to eq result
    end
  end

  shared_examples_for 'AND query is generated as much as the number of attributes' do
    it do
      res = ::Palette::ElasticSearch::QueryFactory.build([User], attributes)
      expect(res[:query][:bool][:must].size + res[:query][:bool][:filter].size).to eq(attributes.keys.size)
    end
  end

  describe 'build' do
    let(:attributes) {
      {
          name: 'Steve Jobs',
          name_prefix: 'Steve Jobs',
          age: 50,
          'phone_numbers.number': '+81 01-2345-6789',
          created_at: Date.today
      }
    }
    it_behaves_like 'AND query is generated as much as the number of attributes'
  end

  describe 'check date search query parameter' do
    let(:created_at) {nil}
    let(:attributes) {
      {
          name: 'Steve Jobs',
          name_prefix: 'Steve Jobs',
          age: 50,
          'phone_numbers.number': '+81 01-2345-6789',
          created_at: created_at
      }
    }
    context 'Hash object' do
      context 'only gte' do
        let(:created_at) {{gte: Date.yesterday}}
        it_behaves_like 'AND query is generated as much as the number of attributes'
      end
      context 'only lte' do
        let(:created_at) {{lte: Date.tomorrow}}
        it_behaves_like 'AND query is generated as much as the number of attributes'
      end
      context 'both gte and lte' do
        let(:created_at) {{"gte" => Date.yesterday, "lte" => Date.tomorrow}}
        it_behaves_like 'AND query is generated as much as the number of attributes'
      end
      context 'neither gte and lte' do
        let(:created_at) {{gte: nil, lte: nil}}
        it_behaves_like 'AND query is generated as much as the number of attributes'
      end
    end

    context 'Range object' do
      let(:created_at) {Date.yesterday..Date.today}
      it_behaves_like 'AND query is generated as much as the number of attributes'
    end

    context 'Date object' do
      let(:created_at) {Date.today}
      it_behaves_like 'AND query is generated as much as the number of attributes'
    end
  end

  describe 'test query_partial_for' do

    let(:query) {nil}
    let(:fields) {nil}
    let(:builder) { ::Palette::ElasticSearch::QueryFactory.new([User])}

    context 'query dose not have a space' do
      let(:query) {'Steve'}
      let(:field) {'name'}
      it 'single AND query is generated' do
        res = builder.send :query_partial_for, query, field
        expect(res[:bool][:must].size == 1).to eq(true)
      end
    end

    context 'query has a space' do
      let(:query) {'Steve Jobs'}
      let(:field) {'name'}
      it 'multiple AND query is generated' do
        res = builder.send :query_partial_for, query, field
        expect(res[:bool][:must].size > 1).to eq(true)
      end
    end
  end

  describe 'test nested_for' do
    let(:query) {'+81 01-2345-6789'}
    let(:field) {'phone_numbers.number'}
    let(:builder) { ::Palette::ElasticSearch::QueryFactory.new([User])}

    it 'nested query is generated' do
      res = builder.send :nested_for, query, field
      expect(res[:nested].present?).to eq(true)
      expect(res[:nested][:path].to_s).to eq(field.to_s.split('.').first.to_s)
    end
  end

  describe 'get_query_pattern' do
    let(:builder) { ::Palette::ElasticSearch::QueryFactory.new([User])}

    context 'type is nested' do
      let(:field) {:'phone_numbers.number'}
      it 'nested is returned' do
        res = builder.send :get_query_pattern, field
        expect(res[:pattern]).to eq(:nested)
      end
    end

    context 'type is date' do
      let(:field) {:created_at}
      it 'date is returned' do
        res = builder.send :get_query_pattern, field
        expect(res[:pattern]).to eq(:date)
      end
    end

    context 'full_match_with_analyzer' do
      let(:field) {:name}
      it 'full_match_with_analyzer is returned' do
        res = builder.send :get_query_pattern, field
        expect(res[:pattern]).to eq(:full_match_with_analyzer)
      end
    end

    context 'type is integer' do
      let(:field) {:age}
      it 'integer is returned' do
        res = builder.send :get_query_pattern, field
        expect(res[:pattern]).to eq(:integer)
      end
    end

    context 'type is boolean' do
      let(:field) {:is_admin}
      it 'integer is returned' do
        res = builder.send :get_query_pattern, field
        expect(res[:pattern]).to eq(:boolean)
      end
    end

    context 'type is geo_point' do
      let(:field) {:location}
      it 'geo_point is returned' do
        res = builder.send :get_query_pattern, field
        expect(res[:pattern]).to eq(:geo_point)
      end
    end

    context 'prefix_match' do
      let(:field) {:name_prefix}
      it 'prefix_match is returned' do
        res = builder.send :get_query_pattern, field
        expect(res[:pattern]).to eq(:prefix_match)
      end
    end
  end
end
