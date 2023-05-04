#!/usr/local/bin/ruby

# = upload-wiki.rb
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
dokuwiki.upload_dir = 'UPLOAD'

old = Dir.getwd
unless ARGV.empty?
  ARGV.each do |filename|
    path = $config[ 'qspath' ].to_s
    if filename.include?( '/' )
      dir = filename.split( '/' ).first
      path << ':'
      path << dir
      filename = filename.split( '/' ).last
      Dir.chdir( dir )
    end
    dokuwiki.upload_file( path, filename )
    Dir.chdir( old )
  end
  exit 0
end

[
  'qscript.txt',
  'numbered-qscript.txt',
  'subs.txt',
  'roles.txt',
  'out.html',
  'out.txt',
  'all.wiki',
  'clothes.pdf',
  'all.pdf',
  'todo-list.csv',
  'assignment-list.csv',
  'availability.html'
].each do |filename|
  dokuwiki.upload_file( $config[ 'qspath' ], filename )
end

exit 0
# eof
