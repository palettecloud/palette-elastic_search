require 'spec_helper'
require 'pry'
require 'user'

RSpec.describe Palette::ElasticSearch do

  it 'has a version number' do
    expect(Palette::ElasticSearch::VERSION).not_to be nil
  end

  # @note callback indexingの自動設定削除が完了したら消す
  describe 'callbacks' do
    let(:user) do
      User.new.tap do |user|
        # do not request toward es instance
        allow(user.__elasticsearch__).to receive(:index_document)
        allow(user.__elasticsearch__).to receive(:update_document)
        allow(user.__elasticsearch__).to receive(:delete_document)
      end
    end

    shared_context 'configured to true' do
      before do
        ::Palette::ElasticSearch.configure do |config|
          config.run_callbacks = true
        end
      end
    end

    shared_context 'configured to false' do
      before do
        ::Palette::ElasticSearch.configure do |config|
          config.run_callbacks = false
        end
      end
    end

    describe 'on create' do
      subject { user.save! }

      context 'run_callbacks configured to true' do
        include_context 'configured to true'

        specify 'run callbacks' do
          expect(user.__elasticsearch__).not_to receive(:index_document)
          subject
        end
      end

      context 'run_callbacks configured to false' do
        include_context 'configured to false'

        specify 'run callbacks' do
          expect(user.__elasticsearch__).not_to receive(:index_document)
          subject
        end
      end
    end

    describe 'on update' do
      before { user.save! }
      subject { user.save! }

      context 'run_callbacks configured to true' do
        include_context 'configured to true'

        specify 'run callbacks' do
          expect(user.__elasticsearch__).not_to receive(:update_document)
          subject
        end
      end

      context 'run_callbacks configured to false' do
        include_context 'configured to false'

        specify 'run callbacks' do
          expect(user.__elasticsearch__).not_to receive(:update_document)
          subject
        end
      end
    end

    describe 'on destroy' do
      before { user.save! }
      subject { user.destroy! }

      context 'run_callbacks configured to true' do
        include_context 'configured to true'

        specify 'run callbacks' do
          expect(user.__elasticsearch__).not_to receive(:delete_document)
          subject
        end
      end

      context 'run_callbacks configured to false' do
        include_context 'configured to false'

        specify 'run callbacks' do
          expect(user.__elasticsearch__).not_to receive(:delete_document)
          subject
        end
      end
    end
  end
end
