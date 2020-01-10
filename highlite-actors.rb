#!/usr/local/bin/ruby -w

# = tag-actors.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2020-2020 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'cgi'
require 'json'
require 'fileutils'
require 'pp'

$: << '.'

# input for actors to wiki lines
WIKI_ACTORS = 'wiki_actors.json'.freeze
# input html
INPUT_HTML = 'all.html'.freeze
# output directory
ACTORS_DIR = 'actors'.freeze
# output index
ACTORS_INDEX = 'actors.wiki'.freeze
# regular expression for matching names
MATCH_NAME = '[A-Za-z0-9_-]+'.freeze
# hostname of EF dokuwiki
EFHOST = 'wiki.eurofurence.org'.freeze
# path inside EF dokuwiki
EFPATH = 'ef26:events:pps:qscript'.freeze
# css highlite with color
HIGHLITE = ' style="background-color:#FFFF00;"'.freeze

$debug = 0

# check if downloaded file has changed
def downloaded?( filename, buffer )
  return false unless File.exist?( filename )

  old = File.read( filename )
  return true if buffer == old

  false
end

# write buffer to file
def file_put_contents( filename, buffer, mode = 'w+' )
  return if downloaded?( filename, buffer )

  File.open( filename, mode ) do |f|
    f.write( buffer )
    f.close
  end
end

def add_tag_line( line, tag )
  @out << tag
  @out << line
end

def add_line( line )
  add_tag_line( line, '<p>' )
end

def save_actor( actor )
  filename = ACTORS_DIR + '/' + actor.downcase.delete( "'" ) + '.html'
  @seen_output[ filename ] = true
  file_put_contents( filename, @out )
end

def parse_role_name( text )
  rest = text.gsub( / *\[[^\]]*\]/, '' )
  rest.gsub!( /^The /, '' )
  list = []
  while /^#{MATCH_NAME}( and |, *)/ =~ rest
    name, rest = rest.split( / and |, */, 2 )
    list.push( name )
  end
  name = rest.split( ' ', 2 )[ 0 ]
  case name
  when /^#{MATCH_NAME}[:]*$/
    list.push( name.sub( ':', '' ) )
  else
    STDERR.puts "Error in Role: '#{name}', #{text}"
  end
  # p [ 'parse_role_name', list, text ]
  list
end

def debug( scene, actor, pattern, line )
  return if $debug.zero?

  p [ scene, actor, pattern ]
  p line
  puts
end

def match_pattern( scene, actor, line )
  return false unless @wiki_highlite[ scene ].key?( actor )

  @wiki_highlite[ scene ][ actor ].each do |pattern|
    next unless /[^a-z0-9]#{pattern}[^a-z0-9]/i =~ line

    debug( scene, actor, pattern, line )
    return true
  end
  false
end

def match_list( scene, actor, pattern, line2 )
  return false if line2 == ''

  list = parse_role_name( line2 )
  list.each do |role|
    next unless /#{pattern}/i =~ role

    debug( scene, actor, pattern, line2 )
    return true
  end
  false
end

def match_pattern2( scene, actor, line )
  return false unless @wiki_highlite[ scene ].key?( actor )

  @wiki_highlite[ scene ][ actor ].each do |pattern|
    if pattern[ 0 ] == pattern[ 0 ].downcase
      next unless /[^a-z0-9]#{pattern}[^a-z0-9]/i =~ line

      debug( scene, actor, pattern, line )
      return true
    end
    case line
    when /%(ATT)%/
      if /[^a-z0-9]#{pattern}[^a-z0-9]/i =~ line
        debug( scene, actor, pattern, line )
        return true
      end
      if /[^a-z0-9]#{actor}[^a-z0-9]/i =~ line
        debug( scene, actor, pattern, line )
        return true
      end
      next
    when /%(HND|FOG|SPT)%/, /Setting:/
      if /[^a-z0-9]#{actor}[^a-z0-9]/i =~ line
        debug( scene, actor, pattern, line )
        return true
      end
      next
    when /%ACT%/
      line2 = line.sub( /[\n]*.*%ACT%[^>]*> */, '' )
      next unless match_list( scene, actor, pattern, line2 )

      return true
    end
    line2 = line.sub( /^[\n]/, '' )
    next if /^###/ =~ line2

    return true if match_list( scene, actor, pattern, line2 )
  end
  false
end

def parse_patterns( scene, actor, line )
  unless @wiki_highlite[ scene ].key?( actor )
    add_line( line )
    return
  end

  found = match_pattern2( scene, actor, line )
  if found
    add_tag_line( line, '<p' + HIGHLITE + '>' )
  else
    add_line( line )
  end
end

def table_line( scene, actor, line )
  sections = line.split( '<table' )
  line2 = sections.first
  parse_patterns( scene, actor, line2 )
  sections[ 1 .. -1 ].each do |table|
    rows = table.split( '<tr' )
    add_tag_line( rows.first, '<table' )
    rows[ 1 .. -1 ].each do |row|
      if /[^a-z0-9]#{actor}[^a-z0-9]/i =~ row
        add_tag_line( row, '<tr' + HIGHLITE )
      else
        add_tag_line( row, '<tr' )
      end
    end
  end
end

def build_output( actor )
  scene = nil
  @out = ''
  lines = File.read( INPUT_HTML ).split( '<p>' )
  lines.each do |line|
    case line
    when /<!-- TOC START -->/
      add_tag_line( line, '' )
      next
    when /"plugin_include_content /
      add_line( line )
      scene = line.slice( /"plugin_include_content [^ {]+/ )
      scene = scene.split( ':' ).last.delete( '"' ).capitalize
      scene.sub!( /([0-9])([0-9])/, ' \1-\2' )
      next
    end
    if scene.nil?
      add_line( line )
      next
    end
    unless @wiki_highlite.key?( scene )
      STDERR.puts "not found in cache: '#{scene}'"
      exit 1
    end

    case line
    when /table/
      table_line( scene, actor, line )
      next
    when /%(AMB|LIG|MIX|MUS|PRE|SND|VID)%/
      add_line( line )
      next
    end

    parse_patterns( scene, actor, line )
  end
  save_actor( actor )
end

@wiki_highlite = JSON.parse( File.read( WIKI_ACTORS ) )
# pp @wiki_highlite
@seen_actors = {}
@seen_output = {}
@wiki_highlite.each_pair do |scene, h|
  h.keys.each do |actor|
    next if actor == :skip
    next if @seen_actors.key?( actor )
    next if /_SH$/ =~ actor

    @seen_actors[ actor ] = scene
    build_output( actor )
  end
end

Dir.entries( ACTORS_DIR ).each do |file|
  case file
  when /[.]html$/
    filename = ACTORS_DIR + '/' + file
    next if @seen_output[ filename ]

    puts "removing old file: #{filename}"
    File.unlink( filename )
  end
end

namespace = EFPATH.gsub( ':', '%3A' )
url = "https://#{EFHOST}/doku.php?id=#{EFPATH}&do=media&ns=#{namespace}"
wiki = "====== Actors Scripts as PDF ======

Get your script via the
[[#{url}||Media_Manager]]

"
@seen_output.keys.sort.each do |file|
  actor = file.split( '/' ).last.sub( /[.]html$/, '' )
  wiki << "Script for {{:#{EFPATH}:#{actor}.pdf|#{actor}}}\\\\\n"
end
file_put_contents( ACTORS_INDEX, wiki )

FileUtils.touch( ACTORS_DIR + '/run.log' )

exit 0
# eof
