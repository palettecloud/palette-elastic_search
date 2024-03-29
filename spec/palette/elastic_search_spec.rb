require 'spec_helper'
require 'pry'
require 'user'

RSpec.describe Palette::ElasticSearch do

  it 'has a version number' do
    expect(Palette::ElasticSearch::VERSION).not_to be nil
  end

  describe 'callbacks' do
    let(:user) do
      User.new.tap do |user|
        # do not request toward es instance
        allow(user.__elasticsearch__).to receive(:index_document)
        allow(user.__elasticsearch__).to receive(:update_document_attributes)
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
          expect(user.__elasticsearch__).to receive(:index_document)
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
          expect(user.__elasticsearch__).to receive(:update_document_attributes)
          subject
        end

        context 'raise Elasticsearch::Transport::Transport::Errors::NotFound on update' do
          let(:user) do
            User.new.tap do |user|
              # do not request toward es instance
              allow(user.__elasticsearch__).to receive(:index_document)
              allow(user.__elasticsearch__).to receive(:update_document_attributes).and_raise Elasticsearch::Transport::Transport::Errors::NotFound
              allow(user.__elasticsearch__).to receive(:delete_document)
            end
          end

          before do
            allow(User).to receive(:exists?).and_return(false)
          end

          specify 'run callbacks' do
            expect(user.__elasticsearch__).to receive(:update_document_attributes)
            expect(user.__elasticsearch__).to receive(:delete_document)
            subject
          end
        end
      end

      context 'run_callbacks configured to false' do
        include_context 'configured to false'

        specify 'run callbacks' do
          expect(user.__elasticsearch__).not_to receive(:update_document_attributes)
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
          expect(user.__elasticsearch__).to receive(:delete_document)
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
