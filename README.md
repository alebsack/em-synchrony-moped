EM-Synchrony-Moped
=====
[![Gem Version](https://badge.fury.io/rb/em-synchrony-moped.png)](http://badge.fury.io/rb/em-synchrony-moped) [![Dependency Status](https://gemnasium.com/alebsack/em-synchrony-moped.png)](https://gemnasium.com/alebsack/em-synchrony-moped) [![Build Status](https://travis-ci.org/alebsack/em-synchrony-moped.png?branch=master)](https://travis-ci.org/alebsack/em-synchrony-moped) [![Coverage Status](https://coveralls.io/repos/alebsack/em-synchrony-moped/badge.png?branch=master)](https://coveralls.io/r/alebsack/em-synchrony-moped?branch=master) [![Code Climate](https://codeclimate.com/github/alebsack/em-synchrony-moped.png)](https://codeclimate.com/github/alebsack/em-synchrony-moped)

EM-Synchrony-Moped is a [Moped](https://github.com/mongoid/moped) driver patch for [EM-Synchrony](http://github.com/igrigorik/em-synchrony).  Moped is the MongoDB driver for the [Mongoid](http://github.com/mongoid/mongoid) ORM.

## Features
 * Supports SSL connections and server certificate checking
 * Uses an EventMachine-aware DNS lookup
 * Can be included in threaded applications
 * Unit tested against the threaded (original driver) behavior

## Usage

In order to use this driver in an EM-Synchrony environment, simply include the driver.

```ruby
require "em-synchrony/moped"

EventMachine.synchrony do
  node = Moped::Node.new("localhost:27017")
  puts node.primary?
  EM.stop
end

```

To use SSL, just pass an SSL config section to the options.
 
```ruby
require "em-synchrony/moped"

EventMachine.synchrony do
  options = {
    :ssl => {
        :verify_peer => true,                      # false to skip peer verification
        :verify_cert => "../path-to/ca_cert.pem",  # specify a CA certificate to verify against
                                                   # or...
        :cert_store => OpenSSL::X509::Store.new,   # to specify a cached cert store.
        :verify_host => "localhost"                # Hostname to verify against, if you wish
                                                   # to verify the hostname in the certificate.
      }
  }
  node = Moped::Node.new("localhost:27017", options)
  puts node.primary?
  EM.stop
end

```


# License

The MIT License - Copyright (c) 2013 Adam Lebsack