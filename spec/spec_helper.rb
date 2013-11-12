# encoding: UTF-8

require 'rubygems'
require 'spork'
# uncomment the following line to use spork with the debugger
# require 'spork/ext/ruby-debug'

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.

  ENV['TIMEOUT_HOST'] ||= 'www.google.com'

  require 'rspec'
  require 'simplecov'
  SimpleCov.start do
    add_group 'Lib', 'lib'
    add_filter '/spec/'
  end

  Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

  SSL_DIR = File.expand_path('../ssl', __FILE__)

  RSpec.configure do |config|
    config.treat_symbols_as_metadata_keys_with_true_values = true
    config.run_all_when_everything_filtered = true
    config.filter_run :focus

    # Run specs in random order to surface order dependencies. If you find an
    # order dependency and want to debug it, you can fix the order by providing
    # the seed, which is printed after each run.
    #     --seed 1234
    config.order = 'random'

    # config.before { $stderr.reopen("/dev/null") }
  end

end

Spork.each_run do
  # This code will be run each time you run your specs.

end
