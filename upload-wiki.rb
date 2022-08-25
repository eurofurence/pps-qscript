#!/usr/local/bin/ruby

# = upload-wiki.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018-2021 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'pp'

$: << '.'

require 'netrc'
require 'dokuwiki'

# hostname of EF dokuwiki
EFHOST = 'wiki.eurofurence.org'.freeze
# path inside EF dokuwiki
EFPATH = 'ef26:events:pps:qscript'.freeze

user, pass = NetRc.login_data( EFHOST )
exit if user.nil?

dokuwiki = DokuWiki::DokuWikiAccess.new( EFHOST )
dokuwiki.login( EFPATH, user, pass )
dokuwiki.upload_dir = 'UPLOAD'

old = Dir.getwd
unless ARGV.empty?
  ARGV.each do |filename|
    path = "#{EFPATH}"
    if /\//i =~ filename
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
  'out.html',
  'out.txt',
  'all.wiki',
  'clothes.pdf',
  'all.pdf',
  'todo-list.csv'
].each do |filename|
  dokuwiki.upload_file( EFPATH, filename )
end

exit 0
# eof
