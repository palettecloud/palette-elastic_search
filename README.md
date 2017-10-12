# Palette::ElasticSearch

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/palette/elastic_search`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'palette-elastic_search', github: 'machikoe/palette-elastic_search'
```

And then execute:

    $ bundle

## Usage

```ruby
class User < ActiveRecord::Base
  include Palette::ElasticSearch::Searchable
  
  attribute :name, String
  attribute :age, Integer
  
  settings do
    mapping _source: { enabled: true }, _all: { enabled: true }, dynamic: false do
      indexes :name, type: 'string', analyzer: 'bingram'    
      indexes :age, type: 'number', analyzer: 'keyword_analyzer'
    end
  end  
      
end
```

Then mapping scheme based `AND` query can be create by `Palette::ElasticSearch::QueryFactory`

```ruby
models = [User]
attributes = { name: 'Jobs', age: 25 }
query = Palette::ElasticSearch::QueryFactory.build(models, attributes)
puts query.to_s # => {:query=>{:bool=>{:must=>[{:bool=>{:must=>[{:match=>{\"name\"=>{:query=>\"Jobs\", :analyzer=>\"bigram\"}}}]}}, {:bool=>{:must=>[{:match=>{\"age\"=>{:query=>\"25\", :analyzer=>\"keyword_analyzer\"}}}]}}], :filter=>{}}}}
```

If attribute value includes space, value is divided and `AND` query is generated.
  
```ruby
attributes = { name: 'Stebe Jobs', age: 25 }
query = Palette::ElasticSearch::QueryFactory.build(models, attributes)
puts query.to_s # => "{:query=>{:bool=>{:must=>[{:bool=>{:must=>[{:simple_query_string=>{:query=>\"Steve\", :fields=>[\"name\"], :analyzer=>\"bigram\"}}, {:simple_query_string=>{:query=>\"Jobs\", :fields=>[\"name\"], :analyzer=>\"bigram\"}}]}}], :filter=>{}}}}" 
```

## Analyzer

- `bigram`
- `kana`
- `keyword_analyzer`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/palette-elastic_search. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Palette::ElasticSearch project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/palette-elastic_search/blob/master/CODE_OF_CONDUCT.md).
