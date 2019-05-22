#!/usr/local/bin/ruby -w

# = read-scene.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018-2019 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'pp'

$: << '.'

ROLES_CONFIG_FILE = 'roles.ini'.freeze
SUBS_CONFIG_FILE = 'subs.ini'.freeze
PUPPET_POOL_FILE = 'puppet_pool.csv'.freeze
HTML_HEADER_FILE = 'header.html'.freeze
MATCH_NAME = '[A-Za-z0-9_-]+'.freeze
MATCH_SNAME = '[A-Za-z0-9_ \'-]+'.freeze

$nat_sort = false

# put buffer to file
def file_put_contents( filename, line, mode = 'w+' )
  File.open( filename, mode ) do |f|
    f.write( line )
    f.close
  end
end

# sort arry by natural order
def nat_sort_list( list )
  if $nat_sort
    list.sort_by { |e| e.downcase.split( /(\d+)/ ).map { |a| a =~ /\d+/ ? a.to_i : a } }
  else
    list.sort_by( &:downcase )
  end
end

# sort arry by first element by natural order
def nat_sort_hash( hash )
  if $nat_sort
    hash.sort_by { |e| e[ 0 ].downcase.split( /(\d+)/ ).map { |a| a =~ /\d+/ ? a.to_i : a } }
  else
    hash.sort_by { |e| e[ 0 ].downcase }
  end
end

# quote a string
def quoted( text )
  '"' + text.gsub( '"', '\"' ) + '"'
end

def read_subs( filename )
  subs = {}
  File.read( filename ).split( "\n" ).each do |line|
    next if /^#/ =~ line

    pattern, text = line.split( ';', 2 )
    subs[ pattern ] = text
  end
  subs
end

# === Class Functions
#   RolesConfig.new( filename )
#   RolesConfig.map_roles( name )
class RolesConfig
  def initialize( filenmae )
    @roles_map = {}
    return unless File.exist?( filenmae )

    File.read( filenmae ).split( "\n" ).each do |line|
      next if /^#/ =~ line

      list = line.split( ';' )
      @roles_map[ list[ 0 ] ] = list[ 1 .. -1 ]
    end
  end

  def add_roles( name, list )
    @roles_map[ name ] = list
  end

  def map_roles( name )
    return [ name ] unless @roles_map.key?( name )

    @roles_map[ name ]
  end
end

# === Class Functions
#   QScript.new
#   QScript.lines
#   QScript.puts( line )
#   QScript.puts_key( key, name, text = nil )
#   QScript.puts_key_token( key, token, name, text = nil )
#   QScript.puts_list( key, list )
#   QScript.save( filename )
class QScript
  attr_accessor :lines

  def initialize
    @script = ''
    @lines = 0
  end

  def puts( line )
    @script << line
    @script << "\n"
    @lines += 1
  end

  def puts_key( key, name, text = nil )
    ename = quoted( name )
    if text.nil?
      puts "\t#{key} #{ename}"
    else
      etext = quoted( text )
      puts "\t#{key} #{ename} #{etext}"
    end
  end

  def puts_key_token( key, token, name, text = nil )
    puts_key( "#{key}#{token}", name, text )
  end

  def puts_list( key, list )
    text = "\t#{key}"
    list.each do |item|
      text << " #{quoted( item )}"
    end
    puts text
  end

  def save( filename )
    file_put_contents( filename, @script )
  end
end

# === Class Timeframe
#   Timeframe.new( fields )
#   Timeframe.scene( title )
#   Timeframe.seen?( key, name )
#   Timeframe.add( key, val )
#   Timeframe.add_once( key, val )
#   Timeframe.fields
#   Timeframe.timeframes
#   Timeframe.this_timeframe
#   Timeframe.add_hash( hashkey, key, val )
#   Timeframe.add_list_text( key, reportkey, name, text )
#   Timeframe.add_list( key, reportkey, token, name )
#   Timeframe.add_spoken( name )
#   Timeframe.list( key )
class Timeframe
  attr_accessor :fields
  attr_accessor :timeframes
  attr_accessor :timeframes_lines

  def initialize( fields )
    @timeframe = nil
    @timeframes = {}
    @timeframes_lines = {}
    @fields = fields
  end

  def scene( title )
    @timeframe = title
    @timeframes[ @timeframe ] = {}
  end

  def this_timeframe
    @timeframes[ @timeframe ]
  end

  def seen?( key, name )
    return false unless @timeframes[ @timeframe ].key?( key )
    return false unless @timeframes[ @timeframe ][ key ].include?( name )

    true
  end

  def add( key, val )
    raise if val.nil?

    unless @timeframes[ @timeframe ].key?( key )
      @timeframes[ @timeframe ][ key ] = []
    end
    @timeframes[ @timeframe ][ key ].push( val )
  end

  def add_once( key, val )
    raise if val.nil?

    unless @timeframes[ @timeframe ].key?( key )
      @timeframes[ @timeframe ][ key ] = []
    end
    return if @timeframes[ @timeframe ][ key ].include?( val )

    @timeframes[ @timeframe ][ key ].push( val )
  end

  def add_hash( hashkey, key, val )
    unless @timeframes[ @timeframe ].key?( hashkey )
      @timeframes[ @timeframe ][ hashkey ] = {}
    end
    @timeframes[ @timeframe ][ hashkey ][ key ] = val
  end

  def add_list_text( key, reportkey, name, text )
    unless @timeframes_lines.key?( key )
      @timeframes_lines[ key ] = {}
    end
    unless @timeframes_lines[ key ].key?( name )
      @timeframes_lines[ key ][ name ] = []
    end
    @timeframes_lines[ key ][ name ].push( "#{@timeframe}: #{reportkey} #{text}" )
  end

  def add_list( key, reportkey, token, name, owner = nil )
    reportkey2 = "#{reportkey}#{token}"
    line =
      if owner.nil?
        name.to_s
      else
        "#{owner} #{name}"
      end
    unless owner.nil?
      add_list_text( 'person', reportkey2, owner, line )
    end
    add_list_text( key, reportkey2, name, line )
  end

  def count_spoken( key, name )
    @timeframes_lines[ key ] = {} unless @timeframes_lines.key?( key )
    if @timeframes_lines[ key ].key?( name )
      pos = @timeframes_lines[ key ][ name ].index( '#' )
      return unless pos.nil?

      @timeframes_lines[ key ][ name ].push( '#' )
      return
    end
    @timeframes_lines[ key ][ name ] = [ '#' ]
  end

  def add_spoken( name, collection )
    hashkey = 'spoken'
    add_list_text( hashkey, 'Spokn', name, nil )
    unless @timeframes[ @timeframe ].key?( hashkey )
      @timeframes[ @timeframe ][ hashkey ] = {}
      @timeframes[ @timeframe ][ hashkey ][ name ] = 1
      return
    end
    unless @timeframes[ @timeframe ][ hashkey ].key?( name )
      @timeframes[ @timeframe ][ hashkey ][ name ] = 1
      return
    end
    @timeframes[ @timeframe ][ hashkey ][ name ] += 1
    count_spoken( 'person', name )
    count_spoken( 'people', name )

    puppet = collection[ 'person_puppets' ][ name ]
    return if puppet.nil?

    count_spoken( 'puppets', puppet )
  end

  def try_fix_entry( key, name, text )
    return unless @timeframes_lines.key?( key )
    return unless @timeframes_lines[ key ].key?( name )

    pos = @timeframes_lines[ key ][ name ].index( '#' )
    return if pos.nil?

    @timeframes_lines[ key ][ name ][ pos ] = text
  end

  def remove_one_entry( list, match )
    position = list.index( match )
    list.delete_at( position ) unless position.nil?
  end

  def sum_spoken( collection )
    return unless @timeframes[ @timeframe ].key?( 'spoken' )

    @timeframes[ @timeframe ][ 'spoken' ].each_pair do |name, count|
      # p [ name, count, @timeframes[ @timeframe ][ 'spoken' ][ name ] ]
      text = "#{count}x spoken"
      entry = "#{@timeframe}: #{text}"
      try_fix_entry( 'person', name, entry )
      try_fix_entry( 'people', name, entry )
      match = "#{@timeframe}: Spokn "
      remove_one_entry( @timeframes_lines[ 'spoken' ][ name ], match )
      puppet = collection[ 'person_puppets' ][ name ]
      next if puppet.nil?

      try_fix_entry( 'puppets', puppet, entry )
    end
  end

  def list( key )
    return [] unless @timeframes[ @timeframe ].key?( key )

    timeframes[ @timeframe ][ key ]
  end
end

# === Class Store
#   Store.new( timeframe )
#   Store.add( collection, key, val )
#   Store.count( collection, key )
#   Store.uniq_player( key, player, name )
#   Store.add_person( name, what, player, prefix )
#   Store.add_voice( name, voice )
#   Store.add_puppet( name, puppet )
#   Store.add_clothing( name, clothing )
#   Store.add_role( name, list )
#   Store.add_backdrop( position, backdrop )
class Store
  COLLECTION_FIELDS = [
    'ambiences',
    'backdrops',
    'backdrops_position',
    'clothes',
    'effects',
    'frontprops',
    'lights',
    'notes',
    'people',
    'person',
    'person_clothes',
    'person_old_clothes',
    'person_props',
    'person_puppets',
    'owned_props',
    'props',
    'props_owner',
    'puppets',
    'roles',
    'secondprops',
    'sounds',
    'stagehand',
    'todos',
    'videos'
  ].freeze
  attr_accessor :collection
  attr_accessor :timeframe
  attr_accessor :ignore

  def initialize( timeframe )
    @collection = {}
    COLLECTION_FIELDS.each do |collection|
      @collection[ collection ] = {}
    end
    @roles = {}
    @uniq_player_seen = {}
    @timeframe = timeframe
    @ignore = {
      'Actor' => 0,
      'Hands' => 0,
      'Puppet' => 0,
      'Costume' => 0
    }
  end

  def add( collection, key, val )
    @collection[ collection ][ key ] = val
  end

  def count( collection, key )
    if @collection[ collection ].key?( key )
      @collection[ collection ][ key ] += 1
    else
      @collection[ collection ][ key ] = 1
    end
  end

  def uniq_player( player, prefix, name )
    if player.nil?
      @ignore[ prefix ] += 1
      count = @ignore[ prefix ]
      player = "#{prefix}#{count}"
    else
      player.strip!
    end
    return player unless @ignore.key?( player )

    seen_key = "#{player} #{prefix} #{name}"
    if @uniq_player_seen.key?( seen_key )
      return @uniq_player_seen[ seen_key ]
    end

    @ignore[ player ] += 1
    result = "#{player}#{@ignore[ player ]}"
    @uniq_player_seen[ seen_key ] = result
    result
  end

  def add_person( name, what, player, prefix )
    player = uniq_player( player, prefix, name )
    @collection[ 'person' ][ name ][ what ] = player
    add( 'people', player, name )
    if what == 'voice'
      if @collection[ 'person' ][ name ][ 'player' ] != player
        @timeframe.add( 'Person', player )
      end
    else
      @timeframe.add( 'Person', player )
    end
    @timeframe.add_list_text( 'person', 'Pers+', name, "#{name}.#{what} #{player}" )
    @timeframe.add_list_text( 'people', 'Pers+', player, "#{name}.#{what} #{player}" )
    player
  end

  def add_voice( name, voice )
    voice.strip!
    voice.sub!( /^Voice: */, '' )
    add_person( name, 'voice', voice, 'Actor' )
  end

  def add_puppet( name, puppet )
    puppet = uniq_player( puppet, 'Puppet', name )
    add( 'person_puppets', name, puppet )
    add( 'puppets', puppet, name )
    @timeframe.add( 'Puppet', puppet )
    @timeframe.add_list_text( 'person', 'Pupp+', name, "#{name} #{puppet}" )
    @timeframe.add_list_text( 'puppets', 'Pupp+', puppet, "#{name} #{puppet}" )
    puppet
  end

  def add_clothing( name, clothing )
    clothing = uniq_player( clothing, 'Costume', name )
    return if clothing == 'None'

    add( 'person_clothes', name, clothing )
    add( 'clothes', clothing, name )
    @timeframe.add( 'Clothing', clothing )
    @timeframe.add_list_text( 'person', 'Clth+', name, "#{name} #{clothing}" )
    puppet = @collection[ 'person_puppets' ][ name ]
    @timeframe.add_list_text( 'puppets', 'Clth+', puppet, "#{name} #{clothing}" )
    @timeframe.add_list_text( 'clothes', 'Clth+', clothing, "#{name} #{clothing}" )
  end

  def change_clothing( name, puppet, clothing )
    old = @collection[ 'person_clothes' ][ name ]
    return nil if old.nil?

    if clothing == old
      return nil if clothing == 'None'

      add( 'person_old_clothes', name, old )
      @timeframe.add_list_text( 'person', 'Clth=', name, "#{name} #{clothing}" )
      @timeframe.add_list_text( 'puppets', 'Clth=', puppet, "#{name} #{clothing}" )
      @timeframe.add_list_text( 'clothes', 'Clth=', clothing, "#{name} #{clothing}" )
      return old
    end

    @collection[ 'person_clothes' ][ name ] = clothing
    @timeframe.add_list_text( 'person', 'Clth-', name, "#{name} #{old}" )
    @timeframe.add_list_text( 'puppets', 'Clth-', puppet, "#{name} #{old}" )
    @timeframe.add_list_text( 'clothes', 'Clth-', clothing, "#{name} #{old}" )
    add( 'person_old_clothes', name, old )
    add_clothing( name, clothing )
    old
  end

  def add_role( name, list )
    count( 'roles', name )
    add( 'person', name, {} )
    @timeframe.add( 'Role', name )
    player, hands, voice, puppet, clothing = list
    hands = nil if hands == '---'
    hands = nil if hands == 'None'
    uplayer = add_person( name, 'player', player, 'Actor' )
    voice = voice.nil? ? uplayer : voice
    hands = hands.nil? ? uplayer : hands
    uvoice = add_voice( name, voice )
    uhands = add_person( name, 'hands', hands, 'Hands' )
    upuppet = add_puppet( name, puppet )
    uclothing = add_clothing( name, clothing )
    @timeframe.add_hash( 'puppet_plays', upuppet, [ name, uplayer, uhands, uvoice, uclothing ] )
  end

  def add_backdrop( position, backdrop )
    key = "#{backdrop} #{position}"
    count( 'backdrops', key )
    @collection[ 'backdrops_position' ][ position ] = key
    @timeframe.add( 'Backdrop panel', key )
    key
  end
end

# === Class Functions
#   Report.new( qscript )
#   Report.puts( line )
#   Report.puts2( line )
#   Report.puts2_key( key, name, text = nil )
#   Report.puts2_key_token( key, token, name, text = nil )
#   Report.text_item( item )
#   Report.add_head( item )
#   Report.add_script( item )
#   Report.list_quoted( list, prefix )
#   Report.list_unsorted( list, prefix = nil )
#   Report.list( hash )
#   Report.catalog( collection )
#   Report.catalog_item( collection, timeframe )
#   Report.puts_timeframe( timeframe )
#   Report.puts_table( table )
#   Report.html_table( table )
#   Report.columns_and_rows( timeframe, key )
#   Report.puts_timeframe_table( timeframe, title, key )
#   Report.save( filename )
#   Report.save_html( filename )
class Report
  REPORT_CATALOG = {
    'Front props' => 'frontprops',
    'Second level props' => 'secondprops',
    'Backdrop panels' => 'backdrops',
    'Lights' => 'lights',
    'Ambiences' => 'ambiences',
    'Sounds' => 'sounds',
    'Videos' => 'videos',
    'Effects' => 'effects',
    'Roles' => 'person',
    'Person' => 'people',
    'Puppets' => 'puppets',
    'Clothes' => 'clothes',
    'Personal props' => 'person_props',
    'Hand props' => 'props',
    'Todos' => 'todos'
  }.freeze
  REPORT_TABLES = {
    'Backdrops' => 'Backdrop panel',
    'Roles' => 'Role',
    'People' => 'Person',
    'Puppets' => 'Puppet',
    'Puppet plays' => 'Puppet'
  }.freeze
  REPORT_BUILDS = [
    'Backdrop panel',
    'Front prop',
    'Second level prop',
    'Personal prop',
    'Hand prop'
  ].freeze

  def initialize( qscript )
    @qscript = qscript
    @head = "   ^  Table of contents\n"
    @html_head = File.read( HTML_HEADER_FILE )
    @html_head << "<body><a href=\"#top\">^&nbsp;</a> <u>Table of contents</u>\n"
    @html_head << '<ul>'
    @script = "\n   Script\n"
    @html_script = "</ul><br/>\n<u id=\"script\">Script</u>\n"
    @html_script << '<ul>'
    @report = "\n"
    @html_report = "</ul><br/>\n"
    @head << text_item( 'Script' )
    @html_head << html_li_item( 'Script' )
  end

  def puts( line )
    @report << line
    @report << "\n"
  end

  def puts2( line )
    puts( line )
    @report << "\n"
  end

  def puts_html( line )
    @html_report << line
    @html_report << "\n"
  end

  def html_p( key, text )
    loc = "loc#{@qscript.lines}_2"
    puts_html( "<p id=\"#{loc}\">&nbsp;#{key} #{text}</p>" )
  end

  def puts2_key( key, name, text = nil )
    if text.nil?
      puts2 "    #{key} #{name}"
      html_p( key, name )
    else
      puts2 "    #{key} #{name} #{text}"
    end
  end

  def puts2_key_token( key, token, name, text = nil )
    puts2_key( "#{key}#{token}", name, text )
  end

  def text_item( item )
    "     * #{item}\n"
  end

  def href( item )
    citem = item.gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase )
    item[ 0 .. 0 ].downcase + citem[ 1 .. -1 ].delete( ' "-' )
  end

  def html_li_item( item )
    href = href( item )
    "<li><a href=\"##{href}\">#{item}</a></li>\n"
  end

  def html_u_item( item )
    href = href( item )
    "<u id=\"#{href}\">#{item}</u><br/>\n"
  end

  def add_head( item )
    @head << text_item( item )
    @html_head << html_li_item( item )
    puts "   #{item}"
  end

  def add_script( item )
    @script << text_item( item )
    @html_script << html_li_item( item )
    puts2 "   #{item}"
    @html_report << html_u_item( item )
  end

  def list_quoted( list, prefix )
    return if list.nil?

    sorted = nat_sort_list( list )
    sorted.each do |prop|
      puts "     * #{prefix} #{quoted( prop )}"
    end
  end

  def list_unsorted( list, prefix = nil )
    return if list.nil?

    list.each do |prop, _count|
      if prefix.nil?
        puts "     * #{prop}"
      else
        puts "     * #{prefix} #{prop}"
      end
    end
    return unless prefix.nil?

    puts '' unless list.empty?
  end

  def list( hash )
    sorted = nat_sort_hash( hash )
    list_unsorted( sorted )
  end

  def catalog( collection )
    add_head( 'Catalog' )
    REPORT_CATALOG.each_key do |key|
      puts "     * #{key}"
    end
    puts ''

    REPORT_CATALOG.each_pair do |key, listname|
      puts "   Catalog: #{key}"
      list( collection[ listname ] )
    end
  end

  def timeframe_list( timeframes_lines, listname, name )
    return unless timeframes_lines.key?( listname )
    return unless timeframes_lines[ listname ].key?( name )

    timeframes_lines[ listname ][ name ].each do |text|
      puts "       #{text}"
    end
  end

  def person_count( timeframes_lines, listname, name )
    return 0 unless timeframes_lines.key?( listname )
    return 0 unless timeframes_lines[ listname ].key?( name )

    timeframes_lines[ listname ][ name ].size
  end

  def catalog_item( collection, timeframe )
    add_head( 'Catalog item details' )
    REPORT_CATALOG.each_pair do |key, listname|
      sorted = nat_sort_hash( collection[ listname ] )
      sorted.each do |name, count|
        prefix = key.sub( /s$/, '' )
        case listname
        when 'person'
          count = person_count( timeframe.timeframes_lines, listname, name )
          count += person_count( timeframe.timeframes_lines, 'spoken', name )
        when 'people'
          count = person_count( timeframe.timeframes_lines, listname, name )
          count += person_count( timeframe.timeframes_lines, 'spoken', name )
        when 'puppets'
          count = person_count( timeframe.timeframes_lines, listname, name )
          count += person_count( timeframe.timeframes_lines, 'spoken', name )
        when 'clothes'
          count = person_count( timeframe.timeframes_lines, listname, name )
          prefix = 'Clothing'
        end
        puts "     * #{prefix} #{quoted( name )} (#{count})"
        timeframe_list( timeframe.timeframes_lines, listname, name )
      end
    end
  end

  def puts_timeframe( timeframe )
    add_head( 'Timeframe contents' )
    list_quoted( timeframe.timeframes.map { |x| x[ 0 ] }, 'Timeframe' )
    timeframe.timeframes.each_key do |scene|
      puts "   Timeframe contents #{quoted( scene )}"
      timeframe.fields.each do |field|
        list_quoted( timeframe.timeframes[ scene ][ field ], field )
      end
    end
    puts ''
  end

  def list_builds( timeframe )
    builds = {}
    timeframe.timeframes.each_key do |scene|
      builds[ scene ] = {}
      REPORT_BUILDS.each do |name|
        builds[ scene ][ name ] = timeframe.timeframes[ scene ][ name ]
      end
    end
    builds
  end

  def people_assignments( timeframe, listname, person )
    found = []
    timeframe.timeframes_lines[ listname ][ person ].each do |line|
      # p line
      case line
      when / Pers[+] /
        task = line.split( ' ', 5 )[ 3 ]
        next if found.include?( task )

        found.push( task )
        next
      when / Stage /
        line.scan( /<.p>(#{MATCH_SNAME})<\/.p>/i ) do |m|
          task = m[ 0 ]
          next if found.include?( task )

          found.push( task )
        end
        next unless found.empty?

        text = line.split( ' ', 5 )[ 4 ]
        found.push( text )
      end
    end
    found
  end

  def list_people_assignments( timeframe )
    listname = 'people'
    assignments = {}
    timeframe.timeframes.each_key do |scene|
      next unless timeframe.timeframes[ scene ].key?( 'Person' )

      people = timeframe.timeframes[ scene ][ 'Person' ]
      people.each do |person|
        next if assignments.key?( person )
        next unless timeframe.timeframes_lines.key?( listname )
        next unless timeframe.timeframes_lines[ listname ].key?( person )

        found = people_assignments( timeframe, listname, person )
        found.each do |text|
          if assignments.key?( text )
            next if assignments[ text ].include?( person )

            # puts "Error Assignments: #{assignments[ text ]}, #{person}"
            assignments[ text ] ||= [ person ]
          else
            assignments[ text ] = [ person ]
          end
        end
      end
    end
    assignments
  end

  def puts_table( table )
    text = "\n"
    table.each do |row|
      text << '  '
      row.each do |column|
        text << ' '
        unless column.nil?
          text << column.to_s
        end
      end
      text << "\n"
    end
    puts text
  end

  def html_table( table )
    html = '<table>'
    table.each do |row|
      html << '<tr>'
      row.each do |column|
        html << '<td>'
        unless column.nil?
          html << column.to_s
        end
        html << '</td>'
      end
      html << "</tr>\n"
    end
    html << "</table><br/>\n"
    html
  end

  def html_list( title, hash, seperator = '</td><td>' )
    html = '<table>'
    html << '<tr><td>'
    html << title
    html << "</td></tr>\n"
    hash.each_pair do |item, h2|
      next if h2.nil?

      seen = {}
      h2.each do |text|
        next if text.nil?
        next if seen.key?( text )

        seen[ text ] = true
        html << '<tr><td>'
        html << item.to_s
        html << seperator
        html << text.to_s
        html << "</td></tr>\n"
      end
    end
    html << "</table><br/>\n"
    html
  end

  def puts_build_list( title, hash, seperator = "\t" )
    text = "   #{title}\n"
    hash.each_pair do |item, arr|
      next if arr.nil?

      seen = {}
      arr.each do |name|
        next if text.nil?
        next if seen.key?( name )

        seen[ name ] = true
        text << "   #{item}#{seperator}#{name}\n"
      end
    end
    puts text
  end

  def rows( timeframe, key )
    rows = []
    timeframe.timeframes.each_pair do |_scene, hash|
      next unless hash.key?( key )

      hash[ key ].each do |puppet|
        next if rows.include?( puppet )

        rows.push( puppet )
      end
    end
    rows
  end

  def columns_and_rows( timeframe, key )
    rows = []
    columns = [ nil ]
    timeframe.timeframes.each_pair do |scene, hash|
      next unless hash.key?( key )

      columns.push( scene )
      hash[ key ].each do |puppet|
        next if rows.include?( puppet )

        rows.push( puppet )
      end
    end
    [ [ columns ], rows ]
  end

  def puts_timeframe_table( timeframe, title, key )
    table, rows = columns_and_rows( timeframe, key )
    rows = nat_sort_list( rows )
    rows.each do |puppet|
      row = [ puppet ]
      timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( key )

        unless hash[ key ].include?( puppet )
          row.push( nil )
          next
        end
        row.push( 'x' )
      end
      table.push( row )
    end
    puts "   #{title}"
    puts_table( table )
    table
  end

  def puts_backdrops_table( timeframe, title, key )
    table = [ [ 'Timeframe', 'Left', 'Middle', 'Right' ] ]
    timeframe.timeframes.each_pair do |scene, hash|
      next unless hash.key?( key )

      table.push( [ scene ] + hash[ key ] )
    end
    puts "   #{title}"
    puts_table( table )
  end

  def puppet_play_full( timeframe, title, key )
    table, puppets = columns_and_rows( timeframe, key )
    puppets.sort.each do |puppet|
      row = [ puppet ]
      timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( 'puppet_plays' )

        unless hash[ 'puppet_plays' ].key?( puppet )
          row.push( nil )
          next
        end
        val = hash[ 'puppet_plays' ][ puppet ][ 1 ].dup
        val << '/' + hash[ 'puppet_plays' ][ puppet ][ 2 ]
        val << ' (' + hash[ 'puppet_plays' ][ puppet ][ 0 ] + ')'
        row.push( val )
      end
      table.push( row )
    end
    puts "   #{title}"
    puts_table( table )
  end

  def puts_tables( timeframe )
    puts ''
    add_head( 'Tables' )
    list_unsorted( REPORT_TABLES.keys )
    REPORT_TABLES.each_pair do |title, key|
      case title
      when 'Backdrops'
        puts_backdrops_table( timeframe, title, key )
      when 'Puppet plays'
        puppet_play_full( timeframe, title, key )
      else
        puts_timeframe_table( timeframe, title, key )
      end
    end
  end

  def puppet_role( timeframe )
    table, puppets = columns_and_rows( timeframe, 'Puppet' )
    puppets.each do |puppet|
      row = [ puppet ]
      timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( 'puppet_plays' )

        unless hash[ 'puppet_plays' ].key?( puppet )
          row.push( nil )
          next
        end
        row.push( hash[ 'puppet_plays' ][ puppet ][ 0 ] )
      end
      table.push( row )
    end
    puts_table( table )
    table
  end

  def puppet_image( puppet )
    return "<img #{$puppet_pool[ puppet ]}/>".gsub( '&', '&amp;' ) \
      if $puppet_pool.key?( puppet )
  end

  def puppet_clothes_list( arr, scene )
    return nil if arr.nil?

    result = []
    arr.each do |entry|
      next unless entry =~ /^#{scene}:/
      next if entry =~ /Clth-/

      name = entry.sub( /^.*Clth. *#{MATCH_NAME} */, '' )
      result.push( name )
    end
    result.uniq!
    # pp [ 'puppet_clothes_list', scene, arr, result ]
    result.join( '<br>' )
  end

  def puppet_clothes( timeframe )
    table, puppets = columns_and_rows( timeframe, 'Puppet' )
    table[ 0 ].insert( 1, 'Image' )
    puppets.each do |puppet|
      row = [ puppet, puppet_image( puppet ) ]
      timeframe.timeframes.each_pair do |scene, hash|
        next unless hash.key?( 'puppet_plays' )

        unless hash[ 'puppet_plays' ].key?( puppet )
          row.push( nil )
          next
        end
        role = hash[ 'puppet_plays' ][ puppet ][ 0 ]
        pp hash[ 'puppet_plays' ][ puppet ][ 0 ]
        row[ 0 ] = "#{role} (#{puppet})"
        row.push( puppet_clothes_list( hash[ 'puppet_plays' ][ puppet ][ 4 ], scene ) )
      end
      table.push( row )
    end
    puts_table( table )
    table
  end

  def save( filename )
    file_put_contents( filename, @head + @script + @report )
  end

  def save_html( filename )
    file_put_contents( filename, @html_head + @html_script + @html_report )
  end
end

# === Class Parser
#   Parser.new( store, qscript, report )
#   Parser.parse_lines( filename, lines )
class Parser
  SIMPLE_MAP = {
    '%AMB%' => [ 'ambience', 'Ambie' ],
    '%ATT%' => [ 'note', 'Note' ],
    '###' => [ 'note', 'Note' ],
    '%LIG%' => [ 'light', 'Light' ],
    '%MUS%' => [ 'ambience', 'Ambie' ],
    '%SND%' => [ 'sound', 'Sound' ],
    '%VID%' => [ 'video', 'Video' ]
  }.freeze
  ROLE_MAP = {
    '%ACT%' => [ 'action', 'Actio' ]
  }.freeze
  FRONTPROP_NAMES = [ 'frontprops', 'frontProp', 'FroP', 'Front prop' ].freeze
  SECONDPROP_NAMES = [ 'secondprops', 'secondLevelProp', 'SecP', 'Second level prop' ].freeze
  JUSTPROP_NAMES = [ 'props', 'just handProp', 'JHanP', 'Hand prop' ].freeze
  HANDPROP_NAMES = [ 'props', 'handProp', 'HanP', 'Hand prop' ].freeze
  BACKDROP_FIELDS2 = [ 'Backdrop_L', 'Backdrop_M', 'Backdrop_R' ].freeze
  BACKDROP_FIELDS = [ 'Left', 'Middle', 'Right' ].freeze

  attr_accessor :store
  attr_accessor :qscript
  attr_accessor :report

  def initialize( store, qscript, report )
    @store = store
    @qscript = qscript
    @report = report
    @backdrops = []
    @scene_props = {}
    @scene_props_hands = {}
    @setting = ''
  end

  def make_title( name )
    out = name.slice( /^[a-z]*/ ).capitalize
    out << ' '
    rest = name.sub( /^[a-z]*/, '' )
    out << rest[ 0 ]
    out << '-'
    out << rest[ 1 ]
    out
  end

  def parse_title( filename )
    name = filename.sub( /.*\//, '' )
    title = make_title( name )
    etitle = quoted( title )
    @store.timeframe.scene( title )
    headline = "timeframe #{etitle} //"
    headline << name.slice( /^[a-z0-9]*/ )
    @qscript.puts headline
    @qscript.puts '{'
    @report.add_script( "Timeframe #{etitle}" )
  end

  def curtain( text )
    @qscript.puts "\tcurtain #{text}"
    @report.puts2_key( 'Curtn', text )
  end

  def add_backdrop_list( list )
    @qscript.puts_list( 'backdrop', list )
    @report.puts2_key( 'Backd', list.join( ' ' ) )
  end

  def parse_single_backdrop( line )
    position, text = line.split( ': ', 2 )
    return if text.nil?

    @backdrops.push( @store.add_backdrop( position, text ) )
    return unless position == 'Right'

    # last Backdrop
    add_backdrop_list( @backdrops )
    @backdrops = []
  end

  def list_one_person( name )
    @qscript.puts ''
    @store.collection[ 'person' ][ name ].each_pair do |key, val|
      @qscript.puts "\tperson+ \"#{name}\".#{key} \"#{val}\""
      @report.puts2_key( 'Pers+', "#{name}.#{key}", val )
    end
    val = @store.collection[ 'person_puppets' ][ name ]
    @qscript.puts_key( 'puppet+', name, val )
    @report.puts2_key( 'Pupp+', name, val )
    clothing = @store.collection[ 'person_clothes' ][ name ]
    return if clothing.nil?

    @qscript.puts_key( 'clothing+', name, clothing )
    @report.puts2_key( 'Clth+', name, clothing )
  end

  def drop_person( name )
    @qscript.puts ''
    @store.collection[ 'person' ][ name ].each_key do |key|
      @qscript.puts "\tperson- \"#{name}\".#{key}"
      @report.puts2_key( 'Pers-', "#{name}.#{key}" )
    end

    val = @store.collection[ 'person_clothes' ][ name ]
    @qscript.puts_key( 'clothing-', name, val ) unless val.nil?

    @store.collection[ 'person_old_clothes' ][ name ] = nil
    if @store.collection[ 'owned_props' ].key?( name )
      @store.collection[ 'owned_props' ][ name ].each do |owner|
        next if owner.nil?

        @qscript.puts_key( 'handProp-', name, owner )
        @store.collection[ 'props_owner' ][ owner ] = nil
      end
      @store.collection[ 'owned_props' ][ name ] = []
    end

    @qscript.puts_key( 'puppet-', name )
    @report.puts2_key( 'Pupp-', name )
  end

  def list_one_person2( name )
    @qscript.puts ''
    # @store.collection[ 'person' ][ name ].each_pair do |key, val|
    #   @report.puts2_key( 'Pers=', "#{name}.#{key}", val )
    # end
    old_clothing = @store.collection[ 'person_old_clothes' ][ name ]
    return if old_clothing.nil?

    clothing = @store.collection[ 'person_clothes' ][ name ]
    if old_clothing == clothing
      @qscript.puts_key( 'clothing=', name, clothing )
      @report.puts2_key( 'Clth=', name, clothing )
      return
    end
    @store.collection[ 'person_old_clothes' ][ name ] = clothing
    @qscript.puts_key( 'clothing-', name, old_clothing )
    @report.puts2_key( 'Clth-', name, old_clothing )
    @qscript.puts_key( 'clothing+', name, clothing )
    @report.puts2_key( 'Clth+', name, clothing )
  end

  def parse_single_puppet( line )
    return if /^ *###/ =~ line

    # "Character (Player, Hands |Puppet |Costume) comment"
    role, text = line.split( / *\(/, 2 )
    # role, text = line.split( / *\(\(*/, 2 )
    list2 =
      if text.nil?
        [
          @store.collection[ 'person' ][ role ][ 'player' ],
          @store.collection[ 'person' ][ role ][ 'hands' ],
          @store.collection[ 'person' ][ role ][ 'voice' ],
          @store.collection[ 'person_puppets' ][ role ],
          @store.collection[ 'person_clothes' ][ role ]
        ]
      else
        text.strip!
        text.sub!( /[)] .*$/, '' )
        case text
        when /[)]$/
          text = text[ 0 .. -2 ]
        when /^[(]/
          text = text[ 1 .. -1 ]
        end
        players, puppet, clothing = text.split( '|', 3 ).map( &:strip )
        player, hand, voice = players.split( ', ' ).map( &:strip )
        voice.sub!( /^Voice: */, '' ) unless voice.nil?
        [ player, hand, voice, puppet, clothing ]
      end

    list = merge_role( role, list2 )
    # if list.nil?
    #   @store.add_role( role, list2 )
    #   list_one_person2( role )
    #   return
    # end
    @store.add_role( role, list )
    list_one_person( role )
  end

  def suffix_props( line, key )
    result = []
    line.scan( /(#{MATCH_NAME})_#{key}/i ) do |m|
      next if m.empty?

      result.concat( m )
    end
    result
  end

  def tagged_props( line, key )
    result = []
    line.scan( /<#{key}>(#{MATCH_SNAME})<\/#{key}>/i ) do |m|
      next if m.empty?

      result.concat( m )
    end
    result
  end

  def parse_single_prop( line, key )
    line.scan( /<#{key}>(#{MATCH_SNAME})<\/#{key}>/i ) do |m|
      next if m.empty?

      m.each do |prop|
        @scene_props[ prop ] = 0
        handtext = line.scan( /[(]([^)]*)[)]/ ) 
        next if handtext.empty?

        p [ 'parse_single_prop', handtext ]
        hands = handtext[ 0 ][ 0 ].split( /, */ )
        p [ 'parse_single_prop', hands ]
        @scene_props_hands[ prop ] = hands
      end
    end
  end

  def parse_section_data( section, line )
    @qscript.puts line.sub( /^    /, "\t//" )
    line.sub!( /^ *[*] /, '' )
    line = replace_text( line )
    case section
    when 'Backdrop', 'Special effects'
      parse_single_backdrop( line )
      [ 'tec', 'sfx' ].each do |key|
        parse_single_prop( line, key )
      end
    when 'Puppets'
      parse_single_puppet( line )
    when 'On 2nd rail', 'On playrail', 'Hand props', 'Props'
      [ 'fp', 'sp', 'fp', 'hp', 'pp' ].each do |key|
        parse_single_prop( line, key )
      end
    end
  end

  def parse_puppets( line )
    # "Character (Player, Hands, Voice |Puppet |Costume)"
    line.split( '), ' ).each do |entry|
      parse_single_puppet( entry )
    end
  end

  def parse_backdrops( line )
    list = line.split( '. ' )
    BACKDROP_FIELDS.each_index do |i|
      next if list[ i ].nil?

      @store.add_backdrop( BACKDROP_FIELDS[ i ], list[ i ] )
    end

    add_backdrop_list( list )
  end

  def parse_effects( line )
    # Stagehands?
    [ 'tec', 'sfx' ].each do |key|
      parse_single_prop( line, key )
    end
  end

  def parse_costumes( line )
    # ignore
  end

  def parse_head( section, line )
    @qscript.puts line.sub( /^    /, "\t//" )
    line.sub!( /^ *[*] #{section}: */, '' )
    return if line == ''

    case section
    when 'Backdrop'
      parse_backdrops( line )
    when 'Puppets'
      parse_puppets( line )
    when 'Costumes'
      parse_costumes( line )
    when 'Setting'
      @setting << replace_text( line )
    when 'Stage setup', 'On 2nd rail', 'On playrail'
      # ignore
    when 'Props', 'Hand props', 'PreRec', 'Special effects'
      # ignore
    else
      p [ 'parse_head', section, line ]
    end
  end

  def add_single_prop( prop, names )
    storekey, qscriptkey, reportkey, timeframekey = names
    @qscript.puts_key_token( qscriptkey, '+', prop )
    @report.puts2_key_token( reportkey, '+', prop )
    @store.count( storekey, prop )
    @store.timeframe.add( timeframekey, prop )
    @store.timeframe.add_list( storekey, reportkey, '+', prop )
  end

  def add_owned_prop( prop, owner, names )
    storekey, qscriptkey, reportkey, timeframekey = names
    ownerkey = "#{storekey}_owner"
    @qscript.puts_key_token( qscriptkey, '+', owner, prop )
    @report.puts2_key_token( reportkey, '+', owner, prop )
    @store.count( storekey, prop )
    @store.add( ownerkey, prop, owner )
    @store.timeframe.add_once( timeframekey, prop )
    @store.timeframe.add_list( storekey, reportkey, '+', prop, owner )
    @store.collection[ 'owned_props' ][ owner ] = [] \
      unless @store.collection[ 'owned_props' ].key?( owner )
    @store.collection[ 'owned_props' ][ owner ].push( prop )
  end

  def remove_owned_prop( prop, owner, names )
    p [ 'remove_owned_prop', prop, owner, names ]
    storekey, qscriptkey, reportkey, _timeframekey = names
    ownerkey = "#{storekey}_owner"
    @qscript.puts_key_token( qscriptkey, '-', owner, prop )
    @report.puts2_key_token( reportkey, '-', owner, prop )
    @store.count( storekey, prop )
    @store.add( ownerkey, prop, nil )
    @store.timeframe.add_list( storekey, reportkey, '-', prop, owner )
    @store.collection[ 'owned_props' ][ owner ].delete( prop )
  end

  def count_single_prop( prop, names )
    storekey, qscriptkey, reportkey, timeframekey = names
    @store.count( storekey, prop )
    @qscript.puts_key_token( qscriptkey, '=', prop )
    @report.puts2_key_token( reportkey, '=', prop )
    @store.timeframe.add( timeframekey, prop )
    @store.timeframe.add_list( storekey, reportkey, '=', prop )
  end

  def count_owned_prop( prop, owner, names )
    storekey, qscriptkey, reportkey, _timeframekey = names
    ownerkey = "#{storekey}_owner"
    old = @store.collection[ ownerkey ][ prop ]
    if old == owner
      @store.count( storekey, prop )
      @qscript.puts_key_token( qscriptkey, '=', owner, prop )
      @report.puts2_key_token( reportkey, '=', owner, prop )
      @store.timeframe.add_list( storekey, reportkey, '=', prop, owner )
      return
    end
    unless old.nil?
      remove_owned_prop( prop, old, names )
    end
    add_owned_prop( prop, owner, names )
  end

  def add_scene_prop( prop )
    if @scene_props.key?( prop )
      @scene_props[ prop ] += 1
    else
      add_note( "TODO: unknown Prop '#{prop}'" )
      @scene_props[ prop ] = 1
    end
  end

  def collect_single_prop( prop, names )
    add_scene_prop( prop )
    storekey = names[ 0 ]
    unless @store.collection[ storekey ].key?( prop )
      add_single_prop( prop, names )
      return
    end
    count_single_prop( prop, names )
  end

  def collect_owned_prop( prop, owner, names )
    add_scene_prop( prop )
    storekey = names[ 0 ]
    unless @store.collection[ storekey ].key?( prop )
      add_owned_prop( prop, owner, names )
      return
    end
    count_owned_prop( prop, owner, names )
  end

  def collect_just_prop( prop, names )
    add_scene_prop( prop )
    storekey, qscriptkey, reportkey, timeframekey = names
    ownerkey = "#{storekey}_owner"
    p [ 'collect_just_prop', ownerkey, @scene_props_hands ]
    if @store.collection.key?( ownerkey )
      old = @store.collection[ ownerkey ][ prop ]
      unless old.nil?
        remove_owned_prop( prop, old, HANDPROP_NAMES )
      end
    end
    @store.count( storekey, prop )
    @store.timeframe.add_once( timeframekey, prop )
    @store.timeframe.add_list( storekey, reportkey, '', prop )
    unless @store.collection[ storekey ].key?( prop )
      @qscript.puts_key( qscriptkey, prop )
      @report.puts2_key( reportkey, prop )
      return
    end
    @qscript.puts_key( qscriptkey, prop )
    @report.puts2_key( reportkey, prop )
  end

  def collect_simple_props( line, suffix, tag, names )
    props = []
    suffix_props( line, suffix ).each do |prop|
      props.push( prop )
      collect_single_prop( prop, names )
    end

    tagged_props( line, tag ).each do |prop|
      props.push( prop )
      collect_single_prop( prop, names )
    end
    props
  end

  def collect_handprop( line, owner )
    props = []
    # p ['collect_handprop', line, owner ]
    suffix_props( line, 'hp' ).each do |prop|
      props.push( prop )
      unless owner.nil?
        collect_owned_prop( prop, owner, HANDPROP_NAMES )
        next
      end
      collect_just_prop( prop, JUSTPROP_NAMES )
    end

    [ 'hp', 'pp', 'sfx', 'tec' ].each do |key|
      tagged_props( line, key ).each do |prop|
        props.push( prop )
        unless owner.nil?
          collect_owned_prop( prop, owner, HANDPROP_NAMES )
          next
        end
        collect_just_prop( prop, JUSTPROP_NAMES )
      end
    end
    props
  end

  def collect_backdrop( line )
    line.scan( /Backdrop_L (.*) Backdrop_M (.*) Backdrop_R (.*)/ ) do |m|
      next if m.empty?

      list = []
      m.each do |prop|
        list.push( add_backdrop( name, prop ) )
      end
      add_backdrop_list( list )
    end
  end

  def collect_prop( line, name )
    return [] if line.nil?

    props = collect_handprop( line, name )
    props.concat( collect_simple_props( line, 'pr', 'fp', FRONTPROP_NAMES ) )
    props.concat( collect_simple_props( line, '2nd', 'sp', SECONDPROP_NAMES ) )
    props
  end

  def new_stagehand
    "stagehand#{@store.collection[ 'stagehand' ].size + 1}"
  end

  def parse_stagehand( name, text, qscriptkey, reportkey )
    @store.count( 'stagehand', name )
    @store.add( 'people', name, 'stagehand' )
    @qscript.puts_key( qscriptkey, name, text )
    @report.puts2_key( reportkey, name, text )
    @store.timeframe.add( 'Person', name )
    @store.timeframe.add_list_text( 'people', reportkey, name, "#{name} #{text}" )
    name
  end

  def print_simple_line( line )
    collect_prop( line, nil )
    SIMPLE_MAP.each_pair do |key, val|
      qscript_key, result_key = val
      case line
      when /^#{key} /
        line.strip!
        text = line.sub( /^#{key}  */, '' )
        storekey = "#{qscript_key}s"
        @qscript.puts_key( qscript_key, text )
        @report.puts2_key( result_key, text )
        @store.count( storekey, text )
        @store.timeframe.add( result_key, text )
        @store.timeframe.add_list( storekey, result_key, '', text )
        return true
      end
    end
    false
  end

  def add_note( line )
    @qscript.puts_key( 'note', line )
    @report.puts2_key( 'Note', line )
    @qscript.puts ''
  end

  def add_error_note( line )
    add_note( line )
    STDERR.puts line
  end

  def change_role_player( role, old_player, player )
    return if old_player.nil?
    return if old_player == ''
    return if old_player == player

    add_error_note( "TODO: Player changed #{role}: #{old_player} -> #{player}" )
  end

  def change_role_hand( role, old_hand, hand )
    return if old_hand.nil?
    return if old_hand == ''
    return if old_hand == hand

    add_error_note( "TODO: Hands changed #{role}: #{old_hand} -> #{hand}" )
  end

  def change_role_voice( role, old_voice, voice )
    return if old_voice.nil?
    return if old_voice == ''
    return if old_voice == voice

    add_error_note( "TODO: Voice changed #{role}: #{old_voice} -> #{voice}" )
  end

  def change_role_puppet( role, old_puppet, puppet )
    return if old_puppet.nil?
    return if old_puppet == ''
    return if old_puppet == puppet

    add_error_note( "TODO: Puppet changed #{role}: #{old_puppet} -> #{puppet}" )
  end

  def old_role( role, list )
    old_list = [
      @store.collection[ 'person' ][ role ][ 'player' ],
      @store.collection[ 'person' ][ role ][ 'hands' ],
      @store.collection[ 'person' ][ role ][ 'voice' ],
      @store.collection[ 'person_puppets' ][ role ],
      @store.collection[ 'person_clothes' ][ role ]
    ]
    player, hand, voice, puppet, clothing = list
    player = old_list[ 0 ] if @store.ignore.key?( player )
    voice = player if voice.nil?
    hand = old_list[ 1 ] if @store.ignore.key?( hand )
    voice = old_list[ 2 ] if @store.ignore.key?( voice )
    puppet = old_list[ 3 ] if @store.ignore.key?( puppet )
    clothing = old_list[ 4 ] if @store.ignore.key?( clothing )
    [ old_list, [ player, hand, voice, puppet, clothing ] ]
  end

  def merge_role( role, list )
    return list unless @store.collection[ 'person' ].key?( role )

    old_list, new_list = old_role( role, list )
    # pp [ 'merge_role', old_list, new_list ]
    @store.change_clothing( role, new_list[ 3 ], new_list[ 4 ] )
    # return nil if old_list[ 0 .. 3 ] == new_list[ 0 .. 3 ]
    return list if old_list[ 0 .. 3 ] == new_list[ 0 .. 3 ]

    change_role_player( role, old_list[ 0 ], new_list[ 0 ] )
    change_role_hand( role, old_list[ 1 ], new_list[ 1 ] )
    change_role_voice( role, old_list[ 2 ], new_list[ 2 ] )
    change_role_puppet( role, old_list[ 3 ], new_list[ 3 ] )
    p old_list
    p list
    # assume nothing changed
    # nil
    list
  end

  def unknown_person( name )
    # return if @store.collection[ 'person' ].key?( name )
    return if @store.timeframe.seen?( 'Role', name )

    p [ 'unknown_person', name ]
    if @section != 'Puppets:'
      add_error_note( "TODO: unknown Role: '#{name}'" )
      STDERR.puts( @store.collection[ 'person' ][ name ] )
    end
    if @store.collection[ 'person' ].key?( name )
      # assume nothing changed
      # @store.update_role( name, @store.collection )
      list = [
        @store.collection[ 'person' ][ name ][ 'player' ],
        @store.collection[ 'person' ][ name ][ 'hands' ],
        @store.collection[ 'person' ][ name ][ 'voice' ],
        @store.collection[ 'person_puppets' ][ name ],
        @store.collection[ 'person_clothes' ][ name ]
      ]
      @store.add_role( name, list )
      list_one_person2( name )
    else
      list = [ nil, nil, nil, nil, nil ]
      @store.add_role( name, list )
      list_one_person( name )
    end
  end

  def parse_position( name, text )
    case text
    when / leaves towards /, / leaves to /
      # drop_person( name )
    end
  end

  def print_role( name, qscript_key, result_key, text )
    unknown_person( name )
    collect_prop( text, name )
    @qscript.puts_key( qscript_key, name, text )
    @report.puts2_key( result_key, name, text )
    @store.timeframe.add_list_text( 'person', result_key, name, name + ' ' + text )
    player = @store.collection[ 'person' ][ name ][ 'player' ]
    @store.timeframe.add_list_text( 'people', result_key, player, name + ' ' + text )
    hands = @store.collection[ 'person' ][ name ][ 'hands' ]
    @store.timeframe.add_list_text( 'people', result_key, hands, name + ' ' + text ) \
      unless hands == player
    puppet = @store.collection[ 'person_puppets' ][ name ]
    @store.timeframe.add_list_text( 'puppets', result_key, puppet, name + ' ' + text )
    parse_position( name, text )
  end

  def print_roles( name, qscript_key, result_key, text )
    $roles_config.map_roles( name ).each do |role|
      next if role == 'and'

      print_role( role, qscript_key, result_key, text )
    end
  end

  def print_roles_list( list, qscript_key, result_key, text )
    list.each do |role|
      print_roles( role, qscript_key, result_key, text )
    end
  end

  def parse_group( line, qscript_key, result_key )
    rest, group = line.split( '=', 2 )
    group, text = group.split( ' ', 2 )
    roles = []
    positions = {}
    rest.scan( /(#{MATCH_NAME}) *([\[][^\]]*[\]])*/ ) do |role, position|
      next if role == 'and'

      roles.push( role )
      position << ' ' unless position.nil?
      position = '' if position.nil?
      positions[ role ] = position
    end
    # pp roles
    # pp positions
    $roles_config.add_roles( group, roles )
    # p [ group, text ]
    roles.each do |role|
      print_role( role, qscript_key, result_key, "#{positions[ role ]}#{text}" )
    end
  end

  def parse_role_name( text )
    rest = text.gsub( / *\[[^\]]*\]/, '' )
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
      add_error_note( "TODO: Error in Role: #{name}, #{text}" )
    end
    # p [ 'parse_role_name', list, text ]
    [ list, text ]
  end

  def parse_action( text, qscript_key, result_key )
    case text
    when /=/ # Grop definition
      parse_group( text, qscript_key, result_key )
    else
      list, text = parse_role_name( text )
      print_roles_list( list, qscript_key, result_key, text )
    end
  end

  def print_role_line( line )
    ROLE_MAP.each_pair do |key, val|
      qscript_key, result_key = val
      case line
      when /^#{key} /
        line.strip!
        text = line.sub( /^#{key}  */, '' )
        parse_action( text, qscript_key, result_key )
        return true
      end
    end
    false
  end

  def print_spoken( name, comment, text )
    unknown_person( name )
    collect_prop( comment, name )
    collect_prop( text, name )
    case text
    when /^".*"$/
      text = text[ 1 .. -2 ]
    end
    @store.timeframe.add_spoken( name, @store.collection )
    player = @store.collection[ 'person' ][ name ][ 'player' ]
    @store.timeframe.add_spoken( player, @store.collection )
    voice = @store.collection[ 'person' ][ name ][ 'voice' ]
    if voice != player
      @store.timeframe.add_spoken( voice, @store.collection )
    end
    puppet = @store.collection[ 'person_puppets' ][ name ]
    @store.timeframe.add_spoken( puppet, @store.collection )
    if comment.nil?
      @qscript.puts_key( 'spoken', name, text )
      @report.puts2_key( 'Spokn', name, text )
      return
    end
    @qscript.puts_key( 'spoken', name, "(#{comment}) #{text}" )
    @report.puts2_key( 'Spokn', name, "(#{comment}) #{text}" )
  end

  def print_spoken_roles( name, comment, text )
    $roles_config.map_roles( name ).each do |role|
      print_spoken( role, comment, text )
    end
  end

  def print_spoken_mutiple( line )
    list, text = parse_role_name( line )
    # p [ list, text ]
    list.each do |sname|
      print_spoken_roles( sname, nil, text )
    end
  end

  def print_title_note( line )
    @qscript.puts_key( 'note', line )
    @qscript.puts ''
    @report.puts2_key( 'Note', line )
  end

  def replace_text( line )
    line.strip!
    $subs.each_pair do |pattern, text|
      line.sub!( /#{pattern}/, text )
    end
    line
  end

  def close_scene
    @store.timeframe.list( 'Role' ).each do |role|
      drop_person( role )
    end
    # pp @scene_props
    @scene_props.each_pair do |prop, count|
      next if count > 0

      add_note( "TODO: Prop unused '#{prop}'" )
    end
    @qscript.puts '}'
    @qscript.puts ''
    @store.timeframe.sum_spoken( @store.collection )
    @scene_props = {}
    @scene_props_hands = {}
    @setting = ''
  end

  def print_unknown_line( line )
    case line
    when '^Part^Time|', /^\|(Intro|Dialogue)\|/, /^\|\*\*Scene Total\*\* \|/,
         /:events:pps:script:/, '== DIALOGUE =='
      return
    end
    add_error_note( "TODO: unknown line '#{line}'" )
  end

  def parse_section( line )
    case line
    when /^<html>/, /^\[\[/
      return true # ignore navigation
    when /^==== / # title note
      print_title_note( line )
      return true
    when /^      [*] / # head data
      parse_section_data( @section, line )
      return true
    when /^    [*] [A-Za-z][A-Za-z0-9_ -]*[:]/ # head comment
      @section = line.slice( /[A-Za-z][A-Za-z0-9_ -]*[:]/ )[ 0 .. -2 ]
      parse_head( @section, line )
      return true
    when '== INTRO =='
      @section = 'INTRO'
      return true
    when '== DIALOGUE =='
      @section = nil
      return true
    when '----', '', '^Part^Time|'
      @section = nil
      return true
    when /^### /
      return false # parse later
    else
      return false if @section.nil?
      return false if @section == 'INTRO'

      p [ 'parse_section', @section, line ]
      add_note( "TODO: unknown header in #{@section}: '#{line}'" )
    end
    false
  end

  def parse_lines( filename, lines )
    @section = nil
    parse_title( filename )
    lines.each do |line|
      line.sub!( /\\\\$/, '' ) # remove DokuWiki linebreak
      line.rstrip!
      next if parse_section( line )

      line = replace_text( line )
      case line
      when ''
        next
      when /Backdrop_L/
        collect_backdrop( line )
        next
      when /^%HND% Curtain - /
        collect_prop( @setting, nil )
        @setting = ''
        # pp @scene_props
        curtain( line.sub( /^%HND% Curtain - */, '' ) )
        next
      when /^%HND% /
        text = line.sub( /^%HND% /, '' )
        props = collect_prop( text, nil )
        props.each do |prop|
          hands =
            if @scene_props_hands.key?( prop )
              @scene_props_hands[ prop ]
            else
              [ new_stagehand ]
            end
          p [ '%HND%', props, hands ]
          hands.each do |hand|
            parse_stagehand( hand, text, 'stagehand', 'Stage' )
          end
        end
        next
      when /^%FOG% /
        text = line.sub( /^%FOG% /, '' )
        parse_stagehand( new_stagehand, text, 'effect', 'Effct' )
        next
      when /^%MIX% /
        @qscript.puts line.sub( /^%MIX%/, "\tnote \"%MIX%" ) + '"'
        next
      when /^#{MATCH_NAME} [(][^:]*[)][:] /
        name, comment, text =
          line.scan( /^(#{MATCH_NAME}) [(]([^:]*)[)][:] (.*)/ )[ 0 ]
        print_spoken_roles( name, comment, text )
        next
      when /^#{MATCH_NAME}[:] /
        name, text = line.split( ': ', 2 )
        print_spoken_roles( name, nil, text )
        next
      when /^#{MATCH_NAME}(, #{MATCH_NAME})*[:] /
        print_spoken_mutiple( line )
        next
      end
      next if print_simple_line( line )
      next if print_role_line( line )

      # if @section == 'INTRO'
      #   add_note( "INTRO: #{line}" )
      #   next
      # end
      print_unknown_line( line )
    end
    close_scene
  end
end

TIMEFRAME_FIELDS = [
  'Front prop',
  'Second level prop',
  'Backdrop panel',
  'Light',
  'Ambience',
  'Sound',
  'Video',
  'Effect',
  'Role',
  'Person',
  'Puppet',
  'Clothing',
  'Personal prop',
  'Hand prop',
  'Todo'
].freeze

$roles_config = RolesConfig.new( ROLES_CONFIG_FILE )
$subs = read_subs( SUBS_CONFIG_FILE )
$puppet_pool = read_subs( PUPPET_POOL_FILE )
qscript = QScript.new
report = Report.new( qscript )
timeframe = Timeframe.new( TIMEFRAME_FIELDS )
store = Store.new( timeframe )
parser = Parser.new( store, qscript, report )

ARGV.each do |filename|
  STDERR.puts filename
  lines = File.read( filename ).split( "\n" )
  parser.parse_lines( filename, lines )
end

qscript.save( 'qscript.txt' )

parser.report.catalog( parser.store.collection )
parser.report.puts_timeframe( parser.store.timeframe )
parser.report.catalog_item( parser.store.collection, parser.store.timeframe )
parser.report.puts_tables( parser.store.timeframe )

table = parser.report.puppet_role( parser.store.timeframe )
table2 = parser.report.puppet_clothes( parser.store.timeframe )
builds = parser.report.list_builds( parser.store.timeframe )
html = parser.report.html_table( table )
clothes = parser.report.html_table( table2 )
html << clothes
builds.each_pair do |key, h|
  html << parser.report.html_list( key, h, '; ' )
  parser.report.puts_build_list( key, h, '; ' )
end
assignments = parser.report.list_people_assignments( parser.store.timeframe )
html << parser.report.html_list( 'Assignments', assignments )
parser.report.puts_build_list( 'Assignments', assignments )

style = File.read( 'style.inc' )
file_put_contents( 'clothes.html', style + clothes )
file_put_contents( 'html.html', html )

parser.report.save( 'test.txt' )
parser.report.save_html( 'test.html' )

exit 0
# eof
