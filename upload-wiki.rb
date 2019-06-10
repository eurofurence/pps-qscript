#!/usr/local/bin/ruby -w

# = upload-wiki.rb
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
EFPATH = 'ef25:events:pps:qscript'.freeze

user, pass = NetRc.login_data( EFHOST )
exit if user.nil?

dokuwiki = DokuWiki::DokuWikiAccess.new( EFHOST )
dokuwiki.login( EFPATH, user, pass )

unless ARGV.empty?
  ARGV.each do |filename|
    dokuwiki.upload_file( EFPATH, filename )
  end
  exit 0
end

[
  'qscript.txt',
  'numbered-qscript.txt',
  'subs.txt',
  'out.html',
  'out.txt',
  'all.wiki',
  'clothes.pdf',
  'all.pdf'
].each do |filename|
  dokuwiki.upload_file( EFPATH, filename )
end

exit 0
# eof
