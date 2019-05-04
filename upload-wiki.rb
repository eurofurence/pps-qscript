#!/usr/local/bin/ruby -w

# = upload-wiki.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018 - 2019 Dirk Meyer
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
EFPATH = 'ef25:events:pps:qscript'.freeze
EFPATH2 = EFPATH.gsub( ':', '%3A' ).freeze
EFPATH3 = "#{EFPATH2}:index&do=media&ns=#{EFPATH2}".freeze
EFUPLOAD = "#{EFSITE}/lib/exe/ajax.php?tab_files=files&tab_details=view&do=media&ns=#{EFPATH2}".freeze

EFCOOKIES = 'cookies.txt'.freeze
UPLOAD_DIR = 'UPLOAD'.freeze

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

def uploaded?( filename, buffer )
  savedfile = "#{UPLOAD_DIR}/#{filename}"
  return false unless File.exist?( savedfile )

  old =  File.read( savedfile )
  return true if buffer == old

  false
end

def upload_media_file( filename )
  p filename
  headers = {
    'Content-Type' => 'application/octet-stream',
    'X-File-Name' => filename
  }
  url = "#{EFUPLOAD}&sectok=#{$sectok}&mediaid=&call=mediaupload"
  url << "&qqfile=#{filename}&ow=true"
  p url
  wait_second
  my_page = $agent.post( url, raw, headers )
  pp my_page
  print system( "cp -pv '#{filename}' 'UPLOAD/'" )
end

def upload_wiki_file( filename )
  raw = File.read( filename ).gsub( "\n", "\r\n" )
  basename = filename.sub( /[.]wiki$/, '' )
  path = "#{EFPATH}:#{basename}"
  url = EFDOKU + path + '&do=edit'
  p url
  wait_second
  my_page = $agent.get( url )
  # pp my_page
  f = my_page.form_with( id: 'dw__editform' )
  p f.field_with( name: 'wikitext' ).value = raw
  p f.field_with( name: 'summary' ).value = 'automated by qscript'
  button = f.button_with( name: 'do[save]' )
  pp $agent.submit( f, button )
  print system( "cp -pv '#{filename}' 'UPLOAD/'" )
end

def upload_file( filename )
  p filename
  raw = File.read( filename )
  return if uploaded?( filename, raw )

  case filename
  when /[.]wiki$/
    upload_wiki_file( filename )
  else
    upload_media_file( filename )
  end
end

user, pass = NetRc.login_data( EFHOST )
exit if user.nil?

$cookies = nil
$sectok = nil
my_page = nil
Timeout.timeout( 300 ) do
  $agent = Mechanize.new
  $agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  $agent.agent.http.reuse_ssl_sessions = false
  # $agent.agent.http.ca_file = ca_path
  if $cookies.nil?
    p EFDOKU + EFPATH
    wait_second
    page = $agent.get( EFDOKU + EFPATH )
    pp page
    # Submit the login form
    wait_second
    my_page = page.form_with( id: 'dw__login' ) do |f|
      f.field_with( name: 'u' ).value = user
      f.field_with( name: 'p' ).value = pass
      f.checkbox_with( name: 'r' ).check
    end.click_button
    # pp my_page
    # pp my_page.forms
    pp my_page.forms[ 1 ]
    f = my_page.forms[ 1 ]
    pp f
    $sectok = f.field_with( name: 'sectok' ).value
    pp $sectok
    $agent.cookie_jar.save( EFCOOKIES )
  else
    # p cookies
    $agent.cookie_jar.load( EFCOOKIES )
  end
end

unless ARGV.empty?
  ARGV.each do |filename|
    upload_file( filename )
  end
  exit 0
end

[ 'qscript.txt', 'out.html', 'out.txt' ].each do |filename|
  upload_file( filename )
end

exit 0
# eof
