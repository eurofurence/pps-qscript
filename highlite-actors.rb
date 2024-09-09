#!/usr/local/bin/ruby

# = highlite-actors.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2020-2023 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'cgi'
require 'yaml'
require 'json'
require 'fileutils'

$: << '.'

# wiki config file
CONFIG_FILE = 'wiki-config.yml'.freeze
# list of patterns with different color
COLOR_CONFIG_FILE = 'colors.wiki'.freeze
# input for actors to wiki lines
WIKI_ACTORS = 'wiki-actors.json'.freeze
# input html
INPUT_HTML = 'all.html'.freeze
# old input html
CHANGED_HTML = 'all.html.orig'.freeze
# output directory
ACTORS_DIR = 'actors'.freeze
# output index for pdf
ACTORS_PDF_INDEX = 'actors.wiki'.freeze
# output index for html
ACTORS_HTML_INDEX = 'actors-html.wiki'.freeze
# regular expression for matching names
# U+0430, 0xD0 0xB0, Cyrillic Small Letter A
MATCH_NAME = "[A-Za-z0-9\u0430_'-]+".freeze
# css highlite with color
# HIGHLITE = ' style="background-color:#FFFF00;"'.freeze
HIGHLITE = ' class="highlite"'.freeze
# css changed highlite with color
NEWHIGHLITE = ' class="newhighlite"'.freeze
# css highlite with color
CHANGED = ' class="changed"'.freeze

$debug = 0
@ignore_changed = true

# read wiki paths
def read_yaml( filename, default = {} )
  config = default
  return config unless File.exist?( filename )

  config.merge!( YAML.load_file( filename ) )
end

# read patters for color replacements from given file
def read_colors( filename )
  @colors = {}
  return unless File.exist?( filename )

  File.read( filename ).split( "\n" ).each do |line|
    next if line =~ /^#/
    next if line =~ /^<[\/]*file/
    next unless line.include?( '|' )

    script, pattern, color = line.split( '|', 3 )
    @colors[ script ] = {} unless @colors.key?( script )
    @colors[ script ][ pattern ] = color
  end
end

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

# add line with prefixed tag
def add_tag_line( line, tag )
  @out << tag
  @out << line
end

# add normal line
def add_line( line )
  add_tag_line( line, '<p>' )
end

# save actor HTML file
def save_actor( actor )
  # U+2019, 0xe2 0x80 0x99, RIGHT SINGLE QUOTATION MARK
  actor2 = actor.downcase.delete( "'\u2019" )
  actor2.delete!( ' #' )
  filename = "#{ACTORS_DIR}/#{actor2}.html"
  @seen_output[ filename ] = true
  file_put_contents( filename, @out )
end

# get list of roles from wiki text
def parse_role_name( text )
  rest = text.gsub( / *\[[^\]]*\]/, '' )
  rest.gsub!( '&#039;', "'" )
  rest.gsub!( /^The /, '' )
  rest.gsub!( /^A /, '' )
  list = []
  while /^#{MATCH_NAME}( and |, *)/ =~ rest
    name, rest = rest.split( / and |, */, 2 )
    name.sub!( /'s$/, '' )
    list.push( name )
  end
  # Scene Sketches
  name = rest.split( ' ', 2 )[ 0 ]
  case name
  when /^#{MATCH_NAME}'s:*$/
    name.sub!( /'s$/, '' )
    list.push( name.sub( ':', '' ) )
  when /^#{MATCH_NAME}:*$/
    list.push( name.sub( ':', '' ) )
  when /^#{MATCH_NAME} *=*$/
    # ignore group
  else
    warn "Error in Role: '#{name}', #{text}"
  end
  # p [ 'parse_role_name', list, text ]
  list
end

# show some debug info
def debug( scene, actor, pattern, line )
  return if $debug.zero?
  return unless actor == 'Eisfuchs'

  p [ scene, actor, pattern ]
  p line
  puts
end

# match the patterns for an actor anywhere in the line
def match_pattern( scene, actor, line )
  return false unless @wiki_highlite[ scene ].key?( actor )

  @wiki_highlite[ scene ][ actor ].each do |pattern|
    next unless /[^a-z0-9]#{pattern}[^a-z0-9]/i =~ line

    debug( scene, actor, pattern, line )
    return true
  end
  false
end

# match the patterns for an actor in dialog lines
def match_list( scene, actor, pattern, line2 )
  return false if line2 == ''
  return false if line2 =~ /<a href=/

  list = parse_role_name( line2 )
  list.each do |role|
    next unless /#{pattern}/i =~ role

    debug( scene, actor, pattern, line2 )
    return true
  end
  false
end

# search wiki text for actor in the line
def match_pattern2( scene, actor, line )
  return nil unless @wiki_highlite[ scene ].key?( actor )

  @wiki_highlite[ scene ][ actor ].each do |pattern|
    # item
    if pattern[ 0 ] == pattern[ 0 ].downcase
      # next unless /[^a-z0-9]#{pattern}[^a-z0-9]/i =~ line
      next unless /[^a-z0-9]#{pattern} *</i =~ line

      debug( scene, actor, pattern, line )
      return pattern
    end

    case line
    when /%(ATT)%/
      if /[^a-z0-9]#{pattern}[^a-z0-9]/i =~ line
        debug( scene, actor, pattern, line )
        return pattern
      end
      if /[^a-z0-9]#{actor}[^a-z0-9]/i =~ line
        debug( scene, actor, pattern, line )
        return pattern
      end
      next
    when /%(SND)%/
      if /[^a-z0-9]#{pattern}[^a-z0-9].*:/i =~ line
        debug( scene, actor, pattern, line )
        return pattern
      end
      next
    when /%(HND|FOG|SPT)%/, /Setting:/
      if /[^a-z0-9]#{actor}[^a-z0-9]/i =~ line
        debug( scene, actor, pattern, line )
        return pattern
      end
      next
    when /%ACT%/
      line2 = line.sub( /\n*.*%ACT%[^>]*> */, '' )
      next unless match_list( scene, actor, pattern, line2 )

      return pattern
    end
    line2 = line.sub( /^\n/, '' )
    next if /^###/ =~ line2

    return pattern if match_list( scene, actor, pattern, line2 )
  end
  nil
end

# find out the color for highlite
def find_highlite_color( actor, pattern )
  return HIGHLITE unless @colors.key?( actor )
  return HIGHLITE unless @colors[ actor ].key?( pattern )

  " class=\"#{@colors[ actor ][ pattern ]}\""
end

# modify line when an actor was found
def parse_patterns( scene, actor, line )
  return '' unless @wiki_highlite[ scene ].key?( actor )

  pattern = match_pattern2( scene, actor, line )
  return '' if pattern.nil?

  find_highlite_color( actor, pattern )
end

# modify line where script changed
def parse_changed( scene, line )
  return '' if @ignore_changed
  return '' if @changed[ scene ].key?( line )

  CHANGED
end

# decide what to highlite
def highlite_patterns( scene, actor, line )
  changed = parse_changed( scene, line )
  highlite = parse_patterns( scene, actor, line )
  if changed == ''
    if highlite == ''
      add_line( line )
      return
    end
    add_tag_line( line, "<p#{highlite}>" )
    return
  end
  if highlite == ''
    add_tag_line( line, "<p#{changed}>" )
    return
  end

  add_tag_line( line, "<p#{NEWHIGHLITE}>" )
end

# @changed[ scene ][ line ]

# modify table row when an actor was found
def table_line( scene, actor, line )
  sections = line.split( '<table' )
  line2 = sections.first
  highlite_patterns( scene, actor, line2 )
  sections[ 1 .. ].each do |table|
    rows = table.split( '<tr' )
    add_tag_line( rows.first, '<table' )
    rows[ 1 .. ].each do |row|
      if /[^a-z0-9]#{actor}[^a-z0-9]/i =~ row
        add_tag_line( row, "<tr#{HIGHLITE}" )
        next
      end

      if actor =~ /'/
        pattern2 = actor.gsub( "'", '&#039;' )
        if /[^a-z0-9]#{pattern2}[^a-z0-9]/i =~ row
          add_tag_line( row, "<tr#{HIGHLITE}" )
          next
        end
      end

      add_tag_line( row, '<tr' )
    end
  end
end

# read old script foir changes
def read_changed
  @changed = {}
  scene = nil
  lines = File.read( CHANGED_HTML ).split( '<p>' )
  lines.each do |line|
    case line
    when /class="plugin_include_content /
      scene = line.slice( /"plugin_include_content [^ {]+/ )
      scene = scene.split( ':' ).last.delete( '"' )
      scene << '.wiki'
      next
    end
    next if scene.nil?

    @changed[ scene ] = {} unless @changed.key?( scene )
    @changed[ scene ][ line ] = true
  end
end

# generate HTML output for an actor
def build_output( actor )
  scene = nil
  @out = ''
  @linenumber = 0
  version = File.stat( INPUT_HTML ).mtime.strftime( '%Y-%m-%d %H:%M' )
  lines = File.read( INPUT_HTML ).split( '<p>' )
  lines.each do |line|
    @linenumber += 1
    case line
    when /<title>/
      add_tag_line( line.sub( ':all', ":#{actor}:#{version}" ), '' )
      next
    when /<!-- TOC START -->/
      add_tag_line( line, '' )
      next
    when /class="plugin_include_content /
      add_line( line )
      scene = line.slice( /"plugin_include_content [^ {]+/ )
      scene = scene.split( ':' ).last.delete( '"' )
      # scene.sub!( /([0-9])([0-9])/, ' \1-\2' )
      scene << '.wiki'
      next
    end
    if scene.nil?
      add_line( line )
      next
    end
    unless @wiki_highlite.key?( scene )
      warn "not found in cache: '#{scene}'"
      warn @wiki_highlite.keys.inspect
      exit 1
    end

    case line
    when /<div class="level1">/
      add_line( line )
      add_line( "#{version}</p>" )
      next
    when /table/
      table_line( scene, actor, line )
      next
    when /%(AMB|LIG|MIX|MUS|PRE|VID)%/
      add_line( line )
      next
    end

    highlite_patterns( scene, actor, line )
  end
  save_actor( actor )
end

$config = read_yaml( CONFIG_FILE )
read_colors( COLOR_CONFIG_FILE )
read_changed
@wiki_highlite = JSON.parse( File.read( WIKI_ACTORS ) )
# pp @wiki_highlite
@seen_actors = {}
@seen_output = {}
@wiki_highlite.each_pair do |scene, h|
  h.each_key do |actor|
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
    filename = "#{ACTORS_DIR}/#{file}"
    next if @seen_output[ filename ]

    puts "removing old file: #{filename}"
    File.unlink( filename )
  when /[.]pdf$/
    filename = "#{ACTORS_DIR}/#{file}"
    htmlname = filename.sub( /[.]pdf$/, '.html' )
    next if File.exist?( htmlname )

    puts "removing old file: #{filename}"
    File.unlink( filename )
  end
end

namespace = $config[ 'qspath' ].gsub( ':', '%3A' )
url = "https://#{$config[ 'host' ]}/doku.php?id=#{$config[ 'qspath' ]}&do=media&ns=#{namespace}"
wiki = "====== Actors Scripts as PDF ======

Get your script via the
[[#{url}||Media_Manager]]

"
@seen_output.keys.sort.each do |file|
  actor = file.split( '/' ).last.sub( /[.]html$/, '' )
  wiki << "Script for {{:#{$config[ 'qspath' ]}:actors:#{actor}.pdf|#{actor}}}\\\\\n"
end
file_put_contents( ACTORS_PDF_INDEX, wiki )

url = "https://#{$config[ 'host' ]}/doku.php?id=#{$config[ 'qspath' ]}&do=media&ns=#{namespace}"
wiki = "====== Actors Scripts as HTML ======

Get your script via the
[[#{url}||Media_Manager]]

"
@seen_output.keys.sort.each do |file|
  actor = file.split( '/' ).last.sub( /[.]html$/, '' )
  wiki << "Script for {{:#{$config[ 'qspath' ]}:actors:#{actor}.html|#{actor}}}\\\\\n"
end
file_put_contents( ACTORS_HTML_INDEX, wiki )

FileUtils.touch( "#{ACTORS_DIR}/run.log" )

exit 0
# eof
