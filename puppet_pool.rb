#!/usr/local/bin/ruby

# = puppet_pool.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2019-2023 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

$: << '.'

# input filename with dokuwiki syntax
INPUT_FILE = 'puppet_pool.wiki'.freeze
# output filename in CSV format
OUTPUT_FILE = 'puppet_pool.csv'.freeze

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

# get fist picture from dokuwiki row
def get_first_picture( pictures )
  picture = pictures.split( ':team:pps:puppet_pictures:' )[ 1 ]
  return nil if picture.nil?

  image, size = picture.sub( /}}.*/, '' ).split( '?', 2 )
  size3 =
    case size
    when /x/
      w, h = size.split( 'x', 2 )
      " width=\"#{w}\" height=\"#{h}\""
    else
      " width=\"#{size}\""
    end
  url = "/lib/exe/fetch.php?cache=&media=team:pps:puppet_pictures:#{image}"
  "src=\"#{url}\" class=\"media\" title=\"#{image}\" alt=\"#{image}\"#{size3}"
end

# serch for all alias names of a puppet
def find_alias( text )
  # p text
  text.gsub( /EF[0-9][0-9]*: */, '' ).gsub( '\\\\', ',' ).split( ', ' )
end

# search for all alias names of a puppet
def read_pool( filename )
  result = [ [ 'Internal name', 'Builder', 'Picture' ] ]
  p filename
  fields = []
  seen = {}
  File.read( filename ).split( "\n" ).each do |line|
    case line[ 0 .. 0 ]
    when '^' # head
      fields = line.split( '^' ).map( &:strip )
      next
    when '|' # data
      list = line.split( '|' ).map( &:strip )
    else
      next
    end
    # pp list
    h = {}
    list.each_index do |index|
      h[ fields[ index ] ] = list[ index ]
    end
    # pp h
    # p [ h[ 'Internal name' ], h[ 'Pictures' ] ]
    # p [ h[ 'Internal name' ], get_first_picture( h[ 'Pictures' ] ) ]
    iname = h[ 'Internal name' ]
    builder = h[ 'Builder' ]
    next if iname.nil?
    next if seen.key?( iname )

    names = iname.split( ', ' )
    names.concat( find_alias( h[ 'Previous roles' ] ) )
    names.each do |name|
      next if seen.key?( name )

      seen[ name ] = true
      result.push( [ name, builder, get_first_picture( h[ 'Pictures' ] ) ] )
    end
  end
  # pp result
  result
end

# put buffer to file
def file_put_contents( filename, line, mode = 'w+' )
  File.open( filename, mode ) do |f|
    f.write( line )
    f.close
  end
end

# convert list to CSV text
def list_to_text( list )
  result = ''
  list.each do |row|
    result << row.join( ';' )
    result << "\n"
  end
  result
end

list = read_pool( INPUT_FILE )
buffer = list_to_text( list )
file_put_contents( OUTPUT_FILE, buffer )

exit 0
# eof
