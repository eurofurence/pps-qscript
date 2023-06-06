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

[
  'index',
  '11_scene', '12_scene', '13_scene', '14_scene',
  '13_intro', '14_intro',
  '21_scene', '22_scene', '23_scene', '24_scene',
  '22_intro', '22_intro', '23_intro',
  '31_scene', '32_scene', '33_scene', '34_scene',
  '32_intro', '33_intro',
].each do |nexturl|
  dokuwiki.save_wiki_path( "#{$config[ 'path' ]}:#{nexturl}" )
end
dokuwiki.save_wiki_path( $config[ 'puppets' ] )
dokuwiki.save_wiki_path( "#{$config[ 'qspath' ]}:availability.csv" )

exit 0
# eof
