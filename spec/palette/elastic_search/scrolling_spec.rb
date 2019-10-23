require 'spec_helper'

RSpec.describe Palette::ElasticSearch::Scrolling do
  describe '.find_each' do
    before do
      allow(User.__elasticsearch__).to receive(:client).and_return Elasticsearch::Client.new(url: 'http://dummy-host')

      # @note ESのレスポンス自体をstubしてテスト
      search_stub
      scroll_stub
    end
    let(:search_stub) do
      stub_request(:get, "http://dummy-host/development_sample_database_users/user/_search?preference=_primary_first&scroll=1m&size=1")
        .to_return(status: 200, body: search_stub_response.to_json, headers: {content_type: 'application/json'})
    end
    let(:scroll_stub) do
      stub_request(:get, "http://dummy-host/_search/scroll?scroll=1m&scroll_id=DXF1ZXJ5QW5kRmV0Y2gBAAAAAAAAiWcWNkw0MXluZE9TWnF4UHJfRml6aVBDZw==")
        .to_return(status: 200, body: scroll_stub_response.to_json, headers: {content_type: 'application/json'})
    end
    let(:search_stub_response) do
      {
        "_scroll_id": "DXF1ZXJ5QW5kRmV0Y2gBAAAAAAAAiWcWNkw0MXluZE9TWnF4UHJfRml6aVBDZw==",
        "took": 1,
        "timed_out": false,
        "_shards": {"total": 1, "successful": 1, "skipped": 0, "failed": 0},
        "hits": {
          "total": total,
          "max_score": 1.0,
          "hits": [
            {"_index": "development_sample_database_users", "_type": "user", "_id": "1", "_score": 1.0, "_source": {"id": "1"}}
          ]
        }
      }
    end
    let(:scroll_stub_response) do
      {
        "_scroll_id": "DXF1ZXJ5QW5kRmV0Y2gBAAAAAAAAiWcWNkw0MXluZE9TWnF4UHJfRml6aVBDZw==",
        "took": 1,
        "timed_out": false,
        "_shards": {"total": 1, "successful": 1, "skipped": 0, "failed": 0},
        "hits": {
          "total": total,
          "max_score": 1.0,
          "hits": [
            {"_index": "development_sample_database_users", "_type": "user", "_id": "2", "_score": 1.0, "_source": {"id": "2"}}
          ]
        }
      }
    end
    let(:total) { 1 }

    context 'no results' do
      let(:search_stub_response) do
        {
          "_scroll_id": "DXF1ZXJ5QW5kRmV0Y2gBAAAAAAAAiWcWNkw0MXluZE9TWnF4UHJfRml6aVBDZw==",
          "took": 1,
          "timed_out": false,
          "_shards": {"total": 1, "successful": 1, "skipped": 0, "failed": 0},
          "hits": {
            "total": 0,
            "max_score": 1.0,
            "hits": []
          }
        }
      end

      it do
        User.search({}).find_in_batches(batch_size: 1) do |response|
          expect(response).to be_an_instance_of ::Elasticsearch::Model::Response::Response
        end
        expect(search_stub).to have_been_requested
        expect(scroll_stub).not_to have_been_requested
      end
    end

    context '1 page' do
      let(:total) { 1 }

      it do
        User.search({}).find_in_batches(batch_size: 1) do |response|
          expect(response).to be_an_instance_of ::Elasticsearch::Model::Response::Response
        end
        expect(search_stub).to have_been_requested
        expect(scroll_stub).not_to have_been_requested
      end
    end

    context '2 page' do
      let(:total) { 2 }

      it do
        User.search({}).find_in_batches(batch_size: 1) do |response|
          expect(response).to be_an_instance_of ::Elasticsearch::Model::Response::Response
          # @note call api explicitly
          response.response
        end
        expect(search_stub).to have_been_requested
        expect(scroll_stub).to have_been_requested
      end
    end

    context '3 page' do
      let(:total) { 3 }

      it do
        User.search({}).find_in_batches(batch_size: 1) do |response|
          expect(response).to be_an_instance_of ::Elasticsearch::Model::Response::Response
          # @note call api explicitly
          response.response
        end
        expect(search_stub).to have_been_requested
        expect(scroll_stub).to have_been_requested.twice
      end
    end

    context 'without block' do
      let(:total) { 2 }

      it do
        User.search({}).find_in_batches(batch_size: 1).with_index do |response, index|
          expect(response).to be_an_instance_of ::Elasticsearch::Model::Response::Response
          # @note call api explicitly
          response.response
        end
        expect(search_stub).to have_been_requested
        expect(scroll_stub).to have_been_requested
      end
    end
  end
end
