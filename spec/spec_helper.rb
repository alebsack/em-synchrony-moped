$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "rspec"

require 'em-synchrony'

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |f| require f }

SSL_DIR = File.expand_path("../ssl", __FILE__)

RSpec.configure do |config|


end
