#!/usr/local/bin/ruby

# = netrc.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018-2021 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#
# == module NetRc
#
# Namespace for utility methods for easy acceess of .netrc file
#
# === Module Functions
#
#   require 'netrc'
#
#   NetRc.login_data( hostname )
#

# This module reads the .netrc file.
module NetRc
  class << self
    # Path to .netrc file
    NETRC = "#{ENV[ 'HOME' ]}/.netrc".freeze

    # Get login data for hostname
    def login_data( hostname )
      user = nil
      pass = nil
      found = false
      File.read( NETRC ).split( "\n" ).each do |l|
        token, val = l.split
        case token
        when 'machine'
          next unless val == hostname

          found = true
        end
        next unless found

        case token
        when 'login'
          user = val
        when 'password'
          pass = val
          break # first match only
        end
      end
      warn 'Login not found.' if user.nil?
      [ user, pass ]
    end
  end
end

# eof
