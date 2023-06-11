#!/usr/local/bin/ruby

# = fetch-wiki.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018-2023 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

$: << '.'

require 'yaml'
require 'netrc'
require 'dokuwiki'

# wiki config file
CONFIG_FILE = 'wiki-config.yml'.freeze

# read wiki paths
def read_yaml( filename, default = {} )
  config = default
  return config unless File.exist?( filename )

  config.merge!( YAML.load_file( filename ) )
end

$config = read_yaml( CONFIG_FILE )

user, pass = NetRc.login_data( $config[ 'host' ] )
exit if user.nil?

dokuwiki = DokuWiki::DokuWikiAccess.new( $config[ 'host' ] )
dokuwiki.login( $config[ 'qspath' ], user, pass )
dokuwiki.media_dir = 'media'

# example paths:
# ef25:events:pps:qscript
# team:pps:puppet_pool
# ef25:events:pps:qscript:all
unless ARGV.empty?
  ARGV.each do |filename|
    dokuwiki.save_wiki_path( filename )
  end
  exit 0
end

$config[ 'scenes' ].each do |nexturl|
  dokuwiki.save_wiki_path( "#{$config[ 'path' ]}:#{nexturl}" )
end
dokuwiki.save_wiki_path( $config[ 'puppets' ] )
$config[ 'qsfiles' ].each do |nexturl|
  dokuwiki.save_wiki_path( "#{$config[ 'qspath' ]}:#{nexturl}" )
end

exit 0
# eof
