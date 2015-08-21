# Go API

[Go](http://www.go.cd) API Ruby client.

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

### Initialize with Go server url and Basic Auth credentials

    require 'goapi'

    go = GoAPI.new('server-url', basic_auth: [username, password])

### Fetch pipeline stages history

    require 'goapi'
    go = GoAPI.new('server-url', basic_auth: [username, password])
    go.stages(pipeline_name, stage_name)

### Fetch artifacts

    require 'goapi'
    go = GoAPI.new('server-url', basic_auth: [username, password])
    stages = go.stages(pipeline_name, stage_name)
    artifacts = go.artifacts(stages[0], job_name)
    artifacts.map do |artifact|
      if artifact.type == 'file'
        go.artifact(artifact)
      else # when type == 'folder'
        ....
      end
    end

More complex examples please checkout [examples](examples) directory in codebase

## API design

1. flat: one level API, you can find all APIs definition in class GoAPI.
2. data: all APIs return data object only, they are:
   1. Primitive type in Ruby
   2. OpenStruct object, with primitive type values (rule #1 flat)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake false` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ThoughtWorksStudios/goapi.

