#!/usr/local/bin/ruby -w

# = wiki-fetch.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'rubygems'
require 'http-cookie'
require 'mechanize'
require 'pp'

$: << '.'

require 'netrc'

EFHOST = 'wiki.eurofurence.org'.freeze
EFSITE = "https://#{EFHOST}/".freeze
EFDOKU = "#{EFSITE}doku.php?id=".freeze
EFMEDIA = "#{EFSITE}lib/exe/fetch.php?cache=&media=".freeze

# EFPATH = 'ef25:events:pps:qfscripttest'.freeze
# EFPATH = 'ef25:events:pps:qscript'.freeze
# EFPATH2 = 'team:pps:puppet_pool'.freeze
EFPATH = 'ef25:events:pps:script:'.freeze

MEDIA_DIR = 'media'.freeze
EFCOOKIES = 'cookies.txt'.freeze

$lastpage = nil
def wait_second
  now = Time.now.to_i
  # p [ 'wait_second', now, $lastpage ]
  unless $lastpage.nil?
    if now <= $lastpage + 2
      sleep 2
      now = Time.now.to_i
    end
  end
  $lastpage = now
end

def file_put_contents( filename, line, mode = 'w+' )
  File.open( filename, mode ) do |f|
    f.write( line )
    f.close
  end
end

def fetch_wiki_doku( my_page, filename )
  f = my_page.form_with( id: 'dw__editform' )
  wikitext = f.field_with( name: 'wikitext' ).value.delete( "\r" )
  file_put_contents( filename, wikitext )
  button = f.button_with( name: 'do[draftdel]' )
  $agent.submit( f, button )
end

def fetch_wiki_page( path )
  filename = path.split( ':' ).last
  case path
  when /.jpg/
    url = EFMEDIA + path
    filename = "#{MEDIA_DIR}/#{filename}"
  else
    url = EFDOKU + path + '&do=edit'
    filename << '.wiki'
  end
  p url
  wait_second
  my_page = $agent.get( url )
  # pp my_page
  case path
  when /.jpg/
    file_put_contents( filename, my_page.body )
  else
    fetch_wiki_doku( my_page, filename )
  end
end

user, pass = NetRc.login_data( EFHOST )
exit if user.nil?

$cookies = nil
my_page = nil
Timeout.timeout( 300 ) do
  $agent = Mechanize.new
  $agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  $agent.agent.http.reuse_ssl_sessions = false
  # $agent.agent.http.ca_file = ca_path
  if $cookies.nil?
    p EFDOKU + EFPATH
    wait_second
    page = $agent.get( EFDOKU + EFPATH + 'scene11' )
    # pp page
    # Submit the login form
    wait_second
    my_page = page.form_with( id: 'dw__login' ) do |f|
      f.field_with( name: 'u' ).value = user
      f.field_with( name: 'p' ).value = pass
      f.checkbox_with( name: 'r' ).check
    end.click_button
    # pp my_page
    $agent.cookie_jar.save( EFCOOKIES )
  else
    # p cookies
    $agent.cookie_jar.load( EFCOOKIES )
  end
end

unless ARGV[ 0 ].nil?
  fetch_wiki_page( ARGV[ 0 ] )
  exit 0
end

# [ 'scene11_fixed' ].each do |nexturl|
[
  'scene11', 'scene12', 'scene13', 'scene14',
  'scene21', 'scene22', 'scene23', 'scene24',
  'scene31', 'scene32', 'scene33'
].each do |nexturl|
  fetch_wiki_page( EFPATH + nexturl )
end

exit 0
# eof
