require 'spec_helper'
require 'pry'
require 'user'

RSpec.describe Palette::ElasticSearch do
  it 'has a version number' do
    expect(Palette::ElasticSearch::VERSION).not_to be nil
  end

  describe 'test query_partial_for' do

    let(:query) { nil }
    let(:fields) { nil }

    context 'query dose not have a space' do
      let(:query) { 'Steve' }
      let(:fields) { ['name'] }
      it 'single AND query is generated' do
        res = ::Palette::ElasticSearch::QueryFactory.send(:query_partial_for, query, fields)
        expect(res[:bool][:must].size == 1).to eq(true)
      end
    end

    context 'query has a space' do
      let(:query) { 'Steve Jobs' }
      let(:fields) { 'name' }
      it 'multiple AND query is generated' do
        res = ::Palette::ElasticSearch::QueryFactory.send(:query_partial_for, query, field)
        expect(res[:bool][:must].size > 1).to eq(true)
      end
    end
  end

  describe 'test full_match_for' do

  end

  describe 'get_query_pattern' do

  end

end
