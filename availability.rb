#!/usr/local/bin/ruby

# = availability.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018-2023 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#
# Read list of available people.
# Generates tables for each rehearsal and the show.
# Show unassigned roles.
# Show if assigned people are absent.
# Allow temporary overwrite for a specific event.
# The goal is to make all tables empty.

require 'json'
require 'csv'
require 'cgi'

$: << '.'

# input for people list
PEOPLE_LIST_FILE = 'people.json'.freeze
# input availabe people list
AVAILABILITY_LIST_FILE = 'media/availability.csv'.freeze
# general header for html output files
HTML_HEADER_FILE = 'header.html'.freeze

# output for assignments
OUTPUT_HTML_FILE = 'availability.html'.freeze

# check if downloaded file has changed
def downloaded?( filename, buffer )
  return false unless File.exist?( filename )

  old =  File.read( filename )
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

def read_csv( filename )
  list = []
  CSV.foreach( filename, encoding: 'bom|UTF-8', col_sep: ';' ) do |row|
    list.push( row )
  end
  list
end

def people_hash
  h = {}
  fields = []
  @people.each do |row|
    name = row.first
    if name.nil?
      fields = row
      next
    end

    h[ name ] = {}
    fields.each_index do |i|
      next if fields[ i ].nil?
      next if row[ i ].nil?

      h[ name ][ fields[ i ] ] = true
    end
  end
  h
end

def availability_hash
  h = {}
  fields = []
  @availability.each do |row|
    name = row.first
    if name.nil?
      fields = row
      fields.push( 'Show' )
      next
    end

    h[ name ] = {}
    fields.each_index do |i|
      next if fields[ i ].nil?
      next if row[ i ].nil?
      next if row[ i ] != 'Yes'

      h[ name ][ fields[ i ] ] = true
    end
    h[ name ][ 'Show' ] = true
  end
  fields.shift
  @events = fields
  h
end

def columns_and_rows( event )
  list1 = []
  list2 = []
  @people.each do |row|
    name = row.first
    next if name.nil?
    next if name == ''

    if name.include?( '_' ) || !@availability2[ name ].key?( event )
      list1.push( name )
    else
      list2.push( name )
    end
  end
  @availability2.each_key do |name|
    next if name.nil?
    next if name == ''
    next if list2.include?( name )

    if @availability2[ name ].key?( event )
      list2.push( name )
    else
      list1.push( name )
    end
  end
  [ list1, list2 ]
end

def conflict?(  name2, name1 )
  return false unless @people2.key?( name2 )
  return false unless @people2.key?( name1 )

  @people2[ name2 ].each_key do |scene|
    return true if @people2[ name1 ].key?( scene )
  end
  @people2[ name1 ].each_key do |scene|
    return true if @people2[ name2 ].key?( scene )
  end

  false
end

def match_names( name2, name1, event )
  return '' unless @availability2[ name2 ].key?( event )
  return '' if conflict?( name2, name1 )

  'f'
end

def color_red( text )
  "<span style=\"color:red\">#{text}</span>"
end

def missing_people( name2, event )
  return [ color_red( name2 ) ] \
         unless @availability2[ name2 ].key?( event )

  [ name2 ]
end

def availble?( name, event )
  return true unless @availability2.key?( name )
  return true if @availability2[ name ].key?( event )

  false
end

def make_columns( list1, event )
  list = [ nil ]
  list1.each do |name|
    if availble?( name, event )
      list.push( name )
    else
      list.push( color_red( name ) )
    end
  end
  list
end

def make_table( event )
  list = []
  list1, list2 = columns_and_rows( event )
  # pp [ list1, list2 ]
  list.push( make_columns( list1, event ) )
  list2.each do |name2|
    # pp [ :list2, name2 ]
    next if name2.nil?

    row = missing_people( name2, event )
    list1.each do |name1|
      # pp [ :list1, name1 ]
      next if name1.nil?

      # pp [ name2, name1, event ]
      row.push( match_names( name2, name1, event ) )
    end
    list.push( row )
  end
  list
end

def write_csv( filename, list )
  CSV.open( filename, 'wb', col_sep: ';' ) do |csv|
    list.each do |row|
      csv << row
    end
  end
end

# capitalize and strip a text to an identifier
def capitalize( item )
  item.tr( ' ', '_' ).gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase ).delete( '_"' )
end

# generate a list head
def html_u_ref_item( ref, item )
  "<u id=\"#{ref}\">#{item}</u>"
end

def table_caption( title )
  href = "tab#{capitalize( title )}"
  html_u_ref_item( href, title )
end

def html_table_r( table, title, tag = '', head_row = nil )
  html = table_caption( title )
  html << "\n#{tag}<table>"
  unless head_row.nil?
    html << '<tr>'
    head_row.each do |column|
      html << '<td colspan="'
      html << column.first.to_s
      html << '">'
      html << column.last
      html << '</td>'
    end
    html << "</tr>\n"
  end
  first_row = true
  table.each do |row|
    html << '<tr>'
    row.each do |column|
      case column
      when nil
        html << '<td/>'
      when 'x'
        html << '<td class="x">'
        html << column.to_s
        html << '</td>'
      else
        if first_row
          html << '<td class="r"><div><div><div>'
          html << column.to_s
          html << '</div></div></div>'
        else
          html << '<td>'
          html << column.to_s
        end
        html << '</td>'
      end
    end
    first_row = false
    html << "</tr>\n"
  end
  html << "</table><br/>\n"
  html << tag.sub( '<', '</' )
  html
end

@people = JSON.parse( File.read( PEOPLE_LIST_FILE ) )
# pp @people
@people2 = people_hash
# pp @people2
@availability = read_csv( AVAILABILITY_LIST_FILE )
# pp @availability
@availability2 = availability_hash
# pp @availability2
# pp @events
@html_report = ''
@events.each do |event|
  table = make_table( event )
  # write_csv( 'availability.csv', table )
  # system( "cat availability.csv" )
  @html_report << html_table_r( table, event )
end

@html_head = File.read( HTML_HEADER_FILE )
file_put_contents( OUTPUT_HTML_FILE, "#{@html_head}<body>#{@html_report}</body></html>\n" )

exit 0
# eof
