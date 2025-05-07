#!/usr/local/bin/ruby

# = puppet_pool.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2019-2025 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'json'

$: << '.'

# input filename with dokuwiki syntax
INPUT_FILE = 'puppet_pool.wiki'.freeze
# output filename in JSON format
OUTPUT_FILE = 'puppet_pool.json'.freeze

# dokuwiki syntax:
# {{:team:pps:puppet_pictures:bobcat.jpg?100}}
# URL of image:
# https://wiki.eurofurence.org/lib/exe/detail.php? \
#   id=team%3Apps%3Apuppet_pool&media=team:pps:puppet_pictures:bobcat.jpg
# URL of preview:
# https://wiki.eurofurence.org/lib/exe/fetch.php? \
#   w=100&tok=3b65e8&media=team:pps:puppet_pictures:bobcat.jpg
# image html tag:
# <img src="/lib/exe/fetch.php? \
#   w=100&amp;tok=3b65e8&amp;media=team:pps:puppet_pictures:bobcat.jpg" \
#   class="media" title="bobcat.jpg" alt="bobcat.jpg" width="100" /></a>

# dokuwiki syntax:
# {{:team:pps:puppet_pictures:aurelia_01_closeup_head.jpg?90x81}}{{:...
# URL of image:
# https://wiki.eurofurence.org/lib/exe/fetch.php?w=90&h=81&tok=39e115 \
#   &media=team:pps:puppet_pictures:aurelia_01_closeup_head.jpg
# image html tag:
# <img src="/lib/exe/fetch.php?w=90&amp;h=81&amp;tok=39e115 \
#   &amp;media=team:pps:puppet_pictures:aurelia_01_closeup_head.jpg" \
#   class="media" title="ASCII" alt="ASCII" width="90" height="81" />

# parse picture entry and return url
def parse_picture( picture )
  image, size = picture.sub( '{{:', '' ).sub( '}}', '' ).split( '?', 2 )
  size3 =
    case size
    when /x/
      w, h = size.split( 'x', 2 )
      " width=\"#{w}\" height=\"#{h}\""
    else
      " width=\"#{size}\""
    end
  basename = image.split( ':' ).last
  url = "/lib/exe/fetch.php?cache=&media=#{image}"
  "src=\"#{url}\" class=\"media\" title=\"#{image}\" alt=\"#{basename}\"#{size3}"
end

# parse pictures from dokuwiki row
def parse_pictures( pictures )
  result = []
  pictures.split( '}}{{' ).each do |picture|
    image = parse_picture( picture )
    result.push( image )
  end
  result
end

# serch for all alias names of a puppet
def find_alias( text )
  # p text
  text.gsub( /EF[0-9][0-9]*: */, '' ).gsub( '\\\\', ',' ).split( ', ' )
end

# parse a list of names
def find_list( text )
  return [] if text == '' # empty

  text.split( /[,\/]/ ).map( &:strip )
end

# parse a row from dokuwiki table
def parse_row( fields, list )
  h = {}
  list.each_index do |index|
    case fields[ index ]
    when nil, ''
      next
    when 'Pictures'
      next if list[ index ] == ''
      next if list[ index ] == '…'

      h[ fields[ index ] ] = parse_pictures( list[ index ] )
    when 'Previous roles'
      h[ fields[ index ] ] = find_alias( list[ index ] )
    when 'Internal name' # list
      found = find_list( list[ index ] )
      return nil if found.empty? # empty row

      h[ fields[ index ] ] = list[ index ].split( /[,\/]/ ).map( &:strip )
      h[ fields[ index ] ] = found
    when 'Builder' # list
      h[ fields[ index ] ] = find_list( list[ index ] )
    else
      h[ fields[ index ] ] = list[ index ]
    end
  end
  h
end

# search for all alias names of a puppet
def read_pool( filename )
  result = []
  p filename
  count = 0
  fields = []
  File.read( filename ).split( "\n" ).each do |line|
    case line[ 0 .. 0 ]
    when '^' # head
      fields = line.split( '^' ).map( &:strip )
      next
    when '|' # data
      list = line.split( '|' ).map( &:strip )
      count += 1
    else
      next
    end
    # pp list
    h = parse_row( fields, list )
    # pp h
    result.push( h ) unless h.nil?
  end
  if @debug
    pp result
    pp [ count, result.size ]
  end
  result
end

@debug = ARGV.include?( 'debug' )
list = read_pool( INPUT_FILE )
File.write( OUTPUT_FILE, JSON.pretty_generate( list ) )

exit 0
# eof
