require 'spec_helper'

RSpec.describe Palette::ElasticSearch::Logger do
  describe 'logging_adapter' do
    shared_context 'std logging adapter' do
      before do
        ::Palette::ElasticSearch.configure do |config|
          config.logging_adapter = :std
        end
      end
    end

    shared_context 'new_relic logging_adapter' do
      before do
        ::Palette::ElasticSearch.configure do |config|
          config.logging_adapter = :new_relic
        end
      end
    end

    context 'logging adapter is std' do
      include_context 'std logging adapter'
      it do
        expect(::Palette::ElasticSearch::Logger.instance.adapter).to be_instance_of(::Palette::ElasticSearch::StdLoggingAdapter)
      end

      it do
        expect(::Palette::ElasticSearch::Logger.instance.error(StandardError.new('test'))).to eq(true)
      end
    end

    context 'logging adapter is new_relic' do
      include_context 'new_relic logging_adapter'
      it do
        expect(::Palette::ElasticSearch::Logger.instance.adapter).to be_instance_of(::Palette::ElasticSearch::NewRelicLoggingAdapter)
      end

      it do
        expect(::Palette::ElasticSearch::Logger.instance.error(StandardError.new('test'))).to eq(nil)
      end
    end
  end
end