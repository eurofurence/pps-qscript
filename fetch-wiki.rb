#!/usr/local/bin/ruby -w

# = fetch-wiki.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018 - 2019 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'pp'

$: << '.'

require 'netrc'
require 'dokuwiki'

# hostname of EF dokuwiki
EFHOST = 'wiki.eurofurence.org'.freeze
# path inside EF dokuwiki
EFPATH = 'ef25:events:pps:script:'.freeze

user, pass = NetRc.login_data( EFHOST )
# p [ user, pass ]
exit if user.nil?

dokuwiki = DokuWiki::DokuWikiAccess.new( EFHOST )
dokuwiki.login( 'ef25:events:pps:qscript', user, pass )
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
  'scene11', 'scene12', 'scene13', 'scene14',
  'scene21', 'scene22', 'scene23', 'scene24',
  'scene31', 'scene32', 'scene33'
].each do |nexturl|
  dokuwiki.save_wiki_path( EFPATH + nexturl )
end
dokuwiki.save_wiki_path( 'team:pps:puppet_pool' )

exit 0
# eof
