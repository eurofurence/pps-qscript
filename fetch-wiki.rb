#!/usr/local/bin/ruby

# = fetch-wiki.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018-2023 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

$: << '.'

require 'netrc'
require 'dokuwiki'

# hostname of EF dokuwiki
EFHOST = 'wiki.eurofurence.org'.freeze
# path inside EF dokuwiki
EFPATH = 'ef27:events:pps:script'.freeze
QSPATH = 'ef27:events:pps:qscript'.freeze

user, pass = NetRc.login_data( EFHOST )
# p [ user, pass ]
exit if user.nil?

dokuwiki = DokuWiki::DokuWikiAccess.new( EFHOST )
dokuwiki.login( QSPATH, user, pass )
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
  '31_scene', '32_scene', '33_scene', '34_scene'
].each do |nexturl|
  dokuwiki.save_wiki_path( "#{EFPATH}:#{nexturl}" )
end
dokuwiki.save_wiki_path( 'team:pps:puppet_pool' )
dokuwiki.save_wiki_path( "#{QSPATH}:availability.csv" )

exit 0
# eof
