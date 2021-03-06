BunyanVariable = Struct.new(:application_name_under_test, :test_type, :path_to_spec_directory, :environment_under_test)

module BunyanVariableExtractor
  # @param path [String] The path to the spec file that is being tested
  # @return [ExampleStruct] An object that responds to #application_name_under_test and #test_type
  # @note If we start nesting our specs, this may need to be revisited.
  def self.call(path:, config:)
    if path.include?('rspec-core')
      application_name_under_test = ARGV[0].split('/')[1]
      BunyanVariable.new(application_name_under_test, "suite", nil, nil)
    else
      spec_sub_directory = path.match('spec/').post_match.split('/')
      application_name_under_test = spec_sub_directory[0]
      test_type = spec_sub_directory[1]
      path_to_spec_directory = path.match(application_name_under_test).pre_match
      environment_under_test = config.fetch('ENVIRONMENT', Bunyan::DEFAULT_ENVIRONMENT)
      BunyanVariable.new(application_name_under_test, test_type, path_to_spec_directory, environment_under_test)
    end
  end
end
