# Go API

Go API

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'goapi'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install goapi

## Usage

### Initialize with Basic Auth for SaaS Mingle site

    require 'goapi'

    go = GoAPI.new('server-url', basic_auth: [username, password])

### Fetch artifacts

    # All artifacts for pipeline and stage
    # You will get an lazy enumerator, which means it won't do anything
    # until you really access the data.
    # And they are order by time, latest first.
    artifacts = go.artifacts(pipeline, stage)

    # For example, get the latest build artifacts
    artifacts.first(2).each do |artifact|
      ....
    end

## API design

1. flat: one level API, you can find all APIs definition in class Mingle.
2. data: all APIs return data object only, they are:
   1. Primitive type in Ruby
   2. OpenStruct object, with primitive type values (rule #1 flat)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake false` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/goapi.

