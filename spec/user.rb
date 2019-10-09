require "sqlite3"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'test.sqlite3')

if ActiveRecord::Base.connection.table_exists? :users
  ActiveRecord::Migration.drop_table :users
end

ActiveRecord::Migration.create_table :users do |t|
  t.string  :name
  t.timestamp :created_at, :null => false
end

class ActiveRecord::ConnectionAdapters::SQLite3Adapter
  def current_database
    'sample_database'
  end
end

class User < ActiveRecord::Base
  include ::Palette::ElasticSearch::Searchable

  settings do
    mapping _source: { enabled: true }, _all: { enabled: true }, dynamic: false do
      indexes :name, type: 'string', analyzer: 'ngram'
      indexes :name_prefix, analyzer: 'autocomplete_analyzer'
      indexes :sex, analyzer: 'keyword_analyzer'
      indexes :age, type: 'integer'
      indexes :is_admin, type: 'boolean'
      indexes :location, type: 'geo_point'
      indexes :address, type: 'string', analyzer: 'ngram'
      indexes :phone_numbers, type: 'nested' do
        indexes :number, analyzer: 'keyword_analyzer'
      end
      indexes :created_at, type: 'date'
      indexes :updated_at, type: 'date'
    end
  end

end
