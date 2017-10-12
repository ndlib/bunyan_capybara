require "bunyan_capybara/version"
require "bunyan_capybara/bunyan_variable_extractor"
require "bunyan_capybara/bunyan_constants"

require "capybara/node/element"
class Capybara::Node::Element
  # As much as I would like to leverage a module mixin and `super`, I am not able to get this to work
  # Instead I am using an alternative mechanism to `super`:
  # * Get the trigger_method
  # * Define a new trigger method
  # * Bind and call the old trigger method but add additional behavior
  trigger_method = instance_method(:trigger)
  define_method :trigger do |method_name, *args|
    trigger_method.bind(self).call(method_name, *args).tap do |obj|
      Bunyan.current_logger.info(context: "trigger('#{method_name}')", path: @session.current_path, host: Capybara.app_host)
    end
  end
end

module Bunyan
  # Given that we want to send logs to different locations based on application,
  # we need to initialize different loggers. We also don't want to keep adding
  # appenders, so this is a means of instantiating all of those loggers before
  # we run any of the examples.
  #
  # @note Call this method no more than once per spec
  def self.instantiate_all_loggers!(config: ENV, path:)
    raise "You already called instantiate_all_loggers!" if @called
    @called = true
    layout = Logging.layouts.pattern(format_as: :json, date_pattern: "%Y-%m-%d %H:%M:%S.%L")
    Logging.appenders.stdout(layout: layout)
    if !File.exist?(File.expand_path('~/bunyan_logs'))
      Dir.mkdir(File.expand_path('~/bunyan_logs'))
    end
    entries = Dir.glob(File.expand_path(path + '/*', __FILE__))
    entries.each do |entry|
      application_name_under_test = entry.split('/').last
      logger = Logging.logger[application_name_under_test]
      log_filename = File.expand_path("~/bunyan_logs/#{application_name_under_test}.log", __FILE__)
      logger.add_appenders('stdout', Logging.appenders.file(log_filename, layout: layout))
      logger.level = config.fetch('LOG_LEVEL', DEFAULT_LOG_LEVEL).to_sym
    end
  end

  def self.start(**kwargs)
    BunyanWrapperWithLogging.new(**kwargs).start
  end

  # Expose the current logger as a class method; Note this will mean we cannot
  # run our specs in parallel (at least without some other consideration)
  def self.current_logger
    @current_logger
  end

  # Allow the ExampleLogging.current_logger to be set
  def self.current_logger=(value)
    @current_logger = value
  end

  def self.reset_current_logger!
    @current_logger = nil
  end

  def current_logger
    @current_logger
  end

  # This module injects logging behavior whenever Capybara does the following:
  #  * clicks
  #  * visits
  #  * submits
  module CapybaraInjection
    def click(*args, &block)
      super.tap { log_url_action(context: __method__) }
    end

    def submit(*args, &block)
      super.tap { log_url_action(context: __method__) }
    end

    def visit(*arg, &block)
      super.tap { log_url_action(context: __method__) }
    end

    def trigger(*arg, &block)
      super.tap { log_url_action(context: __method__) }
    end

    private

      def log_url_action(context:)
        @current_logger.info(context: context, path: current_path, host: Capybara.app_host)
      end
  end

  # Responsible for wrapping the testing process within a predicatable logging environment.
  # The wrapper behaves like the underlying logger.
  class BunyanWrapperWithLogging
    extend Forwardable

    # @return [ExampleVariable]
    attr_reader :example_variable

    # @!attribute [r] test_type
    #   The type of test (e.g. integration or functional) that is being run.
    #   @example 'integration'
    #   @return [String]
    def_delegator :example_variable, :test_type

    # @!attribute [r] application_name_under_test
    #   This repository tests multiple applications. Each named application is a subdirectory of './spec/'
    #   @example 'curate'
    #   @return [String]
    def_delegator :example_variable, :application_name_under_test

    # Used to configure the specifics of this application
    # @example ENV
    # @return [Hash]
    attr_reader :config

    # The current logger for the given scenario
    # @return [ExampleLogging::CurrentLogger]
    attr_reader :current_logger

    # The Environment in which we are running our tests against
    # @example 'prod'
    # @return [String]
    attr_reader :environment_under_test

    # The Rspec example that will be run
    # @return [RSpec::Core::Example]
    attr_reader :example

    # Where can we find the global spec_helper.rb file?
    # @return [String]
    attr_reader :path_to_spec_directory

    # The context in which the tests are actually run. From here we can make assertions/expections.
    # @return [#expect]
    attr_reader :test_handler

    # The name of the driver in which the scenario is run.
    # @example :poltergeist
    # @return [Symbol]
    attr_reader :capybara_driver_name

    def initialize(example:, test_handler:, config: ENV)
      @example = example
      @config = config
      @test_handler = test_handler
      @environment_under_test = config.fetch('ENVIRONMENT', DEFAULT_ENVIRONMENT)
      @path_to_spec_directory = File.expand_path('../../', __FILE__)
      initialize_example_variables!
      @current_logger = Logging.logger[application_name_under_test]
    end

    # Responsible for logging the start of a test
    # @return [ExampleLogging::ExampleWrapper]
    def start
      if example.description.include?('suite')
        self
      else
        info(context: "BEGIN example", example: example.full_description, location: example.location)
        self
      end
    end

    # Responsible for consistent logging of the end steps of a test
    # @return [ExampleLogging::ExampleWrapper]
    def stop
      if !example.description.include?('suite')
        info(context: "END example", example: example.full_description, location: example.location)
      end
    end

    public

    # Log a "debug" level event
    # @param context [#to_s] The context of what is being logged
    # @param kwargs [Hash] The other key/value pair information to log
    # @yield If a block is given, it will log the begining, then yield, then log the ending
    def debug(context:, **kwargs, &block)
      log(severity: __method__, context: context, **kwargs, &block)
    end

    # Log an "info" level event
    # @param context [#to_s] The context of what is being logged
    # @param kwargs [Hash] The other key/value pair information to log
    # @yield If a block is given, it will log the begining, then yield, then log the ending
    def info(context:, **kwargs, &block)
      log(severity: __method__, context: context, **kwargs, &block)
    end

    # Log a "warn" level event
    # @param context [#to_s] The context of what is being logged
    # @param kwargs [Hash] The other key/value pair information to log
    # @yield If a block is given, it will log the begining, then yield, then log the ending
    def warn(context:, **kwargs, &block)
      log(severity: __method__, context: context, **kwargs, &block)
    end

    # Log a "error" level event
    # @param context [#to_s] The context of what is being logged
    # @param kwargs [Hash] The other key/value pair information to log
    # @yield If a block is given, it will log the begining, then yield, then log the ending
    def error(context:, **kwargs, &block)
      log(severity: __method__, context: context, **kwargs, &block)
    end

    # Log a "fatal" level event
    # @param context [#to_s] The context of what is being logged
    # @param kwargs [Hash] The other key/value pair information to log
    # @yield If a block is given, it will log the begining, then yield, then log the ending
    def fatal(context:, **kwargs, &block)
      log(severity: __method__, context: context, **kwargs, &block)
    end

    private

      def log(severity:, context:, **kwargs)
        message = ""
        kwargs.each { |key, value| message += %(#{key}: #{value.inspect}\t) }
        if block_given?
          @current_logger.public_send(severity, %(test_type: #{test_type}\t runID: #{RunIdentifier.get}\t context: "BEGIN #{context}\t#{message}).strip)
          yield
          @current_logger.public_send(severity, %(test_type: #{test_type}\t runID: #{RunIdentifier.get}\t context: "END #{context}\t#{message}).strip)
        else
          @current_logger.public_send(severity, %(test_type: #{test_type}\t runID: #{RunIdentifier.get}\t context: "#{context}"\t#{message}).strip)
        end
      end

      def initialize_example_variables!
        @example_variable = BunyanVariableExtractor.call(path: @example.metadata.fetch(:absolute_file_path), config: config)
      end
  end
  private_constant :BunyanWrapperWithLogging
end
