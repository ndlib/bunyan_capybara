# BunyanCapybara

## To Do List

- [x] Transfer over ExampleLogging module core code
- [x] Transfer and rename the example_varibable_extractor.rb file into lib/bunyan/
- [x] Test if Bunyan module is working
- [x] Transfer the Capybara injections (click, trigger, etc.) from ExampleLogging
- [x] **if needed**: transfer and rename the example_logging_constants file to lib/bunyan/
- [ ] Organize file/folder names and organization as per convention (Jeremy's assistance likely needed)
- [ ] Final test for complete functionality of Bunyan Gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bunyan_capybara'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install bunyan_capybara

## Usage

In order to use the bunyan_capybara gem, you musts first add the following to your spec_helper.rb file.

At the top of your spec_helper add this line...

    $ require 'bunyan_capybara'

Then, below this, but before your configuration block, add these two lines...

    $ spec_path = File.expand_path('../', __FILE__)
    $ Bunyan.instantiate_all_loggers!(config: ENV, path: spec_path)
    
These will allow the gem to create a bunyan_logs folder in your ~/ directory with a .log file for each of the files and folders in your spec directory.

Next, either create or update your config.before block to have the following lines...

    $ @current_logger = Bunyan.start(example: rspec_example, config: ENV, test_handler: self)
    $ Bunyan.current_logger = @current_logger

Finally, either create or update your config.after block to have the following lines...

    $ @current_logger.stop()
    $ Bunyan.reset_current_logger!

Now you are ready to use the Bunyan logger!
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).
