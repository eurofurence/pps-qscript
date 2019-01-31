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
MATCH_NAME = '[A-Za-z0-9_]+'.freeze

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
#   QScript.puts( line )
#   QScript.puts_key( key, name, text = nil )
#   QScript.puts_key_token( key, token, name, text = nil )
#   QScript.puts_list( key, list )
#   QScript.save( filename )
class QScript
  def initialize
    @qscript = ''
  end

  def puts( line )
    @qscript << line
    @qscript << "\n"
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
    file_put_contents( filename, @qscript )
  end
end

# === Class Timeframe
#   Timeframe.new( fields )
#   Timeframe.scene( title )
#   Timeframe.add( key, val )
#   Timeframe.add_once( key, val )
#   Timeframe.fields
#   Timeframe.timeframes
#   Timeframe.add_hash( hashkey, key, val )
#   Timeframe.add_list_text( key, reportkey, name, text )
#   Timeframe.add_list( key, reportkey, token, name )
#   Timeframe.add_spoken( name )
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

  def add_spoken( name )
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
  end

  def insert_head( list, line )
    return [ line ] if list.nil?

    list.unshift( line )
  end

  def try_add_entry( key, name, text )
    return unless @timeframes_lines.key?( key )
    return unless @timeframes_lines[ key ].key?( name )

    @timeframes_lines[ key ][ name ] =
      insert_head( @timeframes_lines[ key ][ name ], text )
  end

  def remove_one_entry( list, match )
    position = list.index( match )
    list.delete_at( position ) unless position.nil?
  end

  def sum_spoken( collection )
    @timeframes[ @timeframe ][ 'spoken' ].each_pair do |name, count|
      # p [ name, count, @timeframes[ @timeframe ][ 'spoken' ][ name ] ]
      text = "#{count}x spoken"
      entry = "#{@timeframe}: #{text}"
      try_add_entry( 'person', name, entry )
      try_add_entry( 'people', name, entry )
      match = "#{@timeframe}: Spokn "
      remove_one_entry( @timeframes_lines[ 'spoken' ][ name ], match )
      puppet = collection[ 'person_puppets' ][ name ]
      next if puppet.nil?

      try_add_entry( 'puppets', puppet, entry )
    end
  end
end

# === Class Store
#   Store.new( timeframe )
#   Store.add( collection, key, val )
#   Store.count( collection, key )
#   Store.uniq_player( key, player )
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
    'person_props',
    'person_puppets',
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

  def initialize( timeframe )
    @collection = {}
    COLLECTION_FIELDS.each do |collection|
      @collection[ collection ] = {}
    end
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

  def uniq_player( key, player, prefix )
    if player.nil?
      count = @collection[ key ].size + 1
      player = "#{prefix}#{count}"
    else
      player.strip!
    end
    return player unless @ignore.key?( player )

    @ignore[ player ] += 1
    "#{player}#{@ignore[ player ]}"
  end

  def add_person( name, what, player, prefix )
    player = uniq_player( 'person', player, prefix )
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
    puppet = uniq_player( 'puppets', puppet, 'Puppet' )
    add( 'person_puppets', name, puppet )
    add( 'puppets', puppet, name )
    @timeframe.add( 'Puppet', puppet )
    @timeframe.add_list_text( 'person', 'Pupp+', name, "#{name} #{puppet}" )
    @timeframe.add_list_text( 'puppets', 'Pupp+', puppet, "#{name} #{puppet}" )
    puppet
  end

  def add_clothing( name, clothing )
    clothing = uniq_player( 'clothes', clothing, 'Costume' )
    add( 'person_clothes', name, clothing )
    add( 'clothes', clothing, name )
    @timeframe.add( 'Clothing', clothing )
    @timeframe.add_list_text( 'person', 'Clth+', name, "#{name} #{clothing}" )
    puppet = @collection[ 'person_puppets' ][ name ]
    @timeframe.add_list_text( 'puppets', 'Clth+', puppet, "#{name} #{clothing}" )
    @timeframe.add_list_text( 'clothes', 'Clth+', clothing, "#{name} #{clothing}" )
  end

  def add_role( name, list )
    if @collection[ 'person' ].key?( name )
      STDERR.puts "duplicate Role: '#{name}'"
      STDERR.puts @collection[ 'person' ][ name ].inspect
    end
    count( 'roles', name )
    add( 'person', name, {} )
    @timeframe.add( 'Role', name )
    player, hands, voice, puppet, clothing = list
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
    @collection[ 'backdrops_position' ][ position ] = backdrop
    unless @collection[ 'backdrops' ].key?( backdrop )
      count( 'backdrops', backdrop )
      @timeframe.add( 'Backdrop panel', backdrop )
      return backdrop
    end
    count( 'backdrops', backdrop )
    backdrop2 = backdrop + @collection[ 'backdrops' ][ backdrop ].to_s
    @timeframe.add( 'Backdrop panel', backdrop2 )
    backdrop2
  end
end

# === Class Functions
#   Report.new
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

  def initialize
    @head = "   ^  Table of contents\n"
    @script = "\n   Script\n"
    @report = "\n"
    @head << text_item( 'Script' )
  end

  def puts( line )
    @report << line
    @report << "\n"
  end

  def puts2( line )
    puts( line )
    @report << "\n"
  end

  def puts2_key( key, name, text = nil )
    if text.nil?
      puts2 "    #{key} #{name}"
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

  def add_head( item )
    @head << text_item( item )
    puts "   #{item}"
  end

  def add_script( item )
    @script << text_item( item )
    puts2 "   #{item}"
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

  def columns_and_rows( timeframe, key )
    rows = []
    columns = [ nil ]
    timeframe.timeframes.each_pair do |scene, hash|
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

  def save( filename )
    file_put_contents( filename, @head + @script + @report )
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
  BACKDROP_FIELDS = [ 'Backdrop_L', 'Backdrop_M', 'Backdrop_R' ].freeze

  attr_accessor :store
  attr_accessor :qscript
  attr_accessor :report

  def initialize( store, qscript, report )
    @store = store
    @qscript = qscript
    @report = report
    @backdrops = []
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
    position, text = line.split( ' ', 2 )
    @backdrops.push( @store.add_backdrop( position, text ) )
    return unless position == 'Backdrop_R'

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
    val = @store.collection[ 'person_clothes' ][ name ]
    @qscript.puts_key( 'clothing+', name, val )
    @report.puts2_key( 'Clth+', name, val )
  end

  def parse_single_puppet( line )
    # "Character (Player, Hands |Puppet |Costume)"
    role, text = line.split( ' (', 2 )
    text.strip!
    case text
    when /[)]$/
      text = text[ 0 .. -2 ]
    end
    players, puppet, clothing = text.split( '|', 3 )
    player, hand, voice = players.split( ', ' )
    list = [ player, hand, voice, puppet, clothing ]
    @store.add_role( role, list )
    list_one_person( role )
  end

  def parse_section( section, line )
    @qscript.puts line.sub( /^    /, "\t//" )
    line.sub!( /^ *[*] /, '' )
    case section
    when 'Backdrop'
      parse_single_backdrop( line )
    when 'Puppets'
      parse_single_puppet( line )
    end
  end

  def parse_puppets( line )
    # "Character (Player, Hands |Puppet |Costume)"
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
    list = line.split( ', ' )
    # Stagehands
    # ignore
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
    when 'Special effects'
      parse_effects( line )
    when 'Puppets'
      parse_puppets( line )
    when 'Costumes'
      parse_costumes( line )
    when 'Setting', 'Stage setup', 'On 2nd rail', 'On playrail'
      # ignore
    when 'Props', 'PreRec'
      # ignore
    else
      p [ section, line ]
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
  end

  def remove_owned_prop( prop, owner, names )
    storekey, qscriptkey, reportkey, _timeframekey = names
    ownerkey = "#{storekey}_owner"
    @qscript.puts_key_token( qscriptkey, '-', owner, prop )
    @report.puts2_key_token( reportkey, '-', owner, prop )
    @store.count( storekey, prop )
    @store.add( ownerkey, prop, nil )
    @store.timeframe.add_list( storekey, reportkey, '-', prop, owner )
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
    remove_owned_prop( prop, old, names )
    add_owned_prop( prop, owner, names )
  end

  def collect_single_prop( prop, names )
    storekey = names[ 0 ]
    unless @store.collection[ storekey ].key?( prop )
      add_single_prop( prop, names )
      return
    end
    count_single_prop( prop, names )
  end

  def collect_owned_prop( prop, owner, names )
    storekey = names[ 0 ]
    unless @store.collection[ storekey ].key?( prop )
      add_owned_prop( prop, owner, names )
      return
    end
    count_owned_prop( prop, owner, names )
  end

  def collect_just_prop( prop, names )
    storekey, qscriptkey, reportkey, timeframekey = names
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

  def collect_frontprop( line )
    line.scan( /(#{MATCH_NAME})_PR[^\/]/ ) do |m|
      next if m.empty?
      m.each do |prop|
        collect_single_prop( prop, FRONTPROP_NAMES )
      end
    end
  end

  def collect_sedcondprop( line )
    line.scan( /(#{MATCH_NAME})_PR\/2nd/ ) do |m|
      next if m.empty?
      m.each do |prop|
        collect_single_prop( prop, SECONDPROP_NAMES )
      end
    end
  end

  def collect_handprop( line, owner )
    line.scan( /(#{MATCH_NAME})_HP/ ) do |m|
      next if m.empty?
      m.each do |prop|
        unless owner.nil?
          collect_owned_prop( prop, owner, HANDPROP_NAMES )
          next
        end
        collect_just_prop( prop, JUSTPROP_NAMES )
      end
    end
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
    return if line.nil?

    collect_handprop( line, name )
    collect_frontprop( line )
    collect_sedcondprop( line )
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
  end

  def print_simple_line( line )
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
    @qscript.puts ''
    @report.puts2_key( 'Note', line )
  end

  def unknown_person( name )
    return if @store.collection[ 'person' ].key?( name )

    if @section != 'Puppets:'
      add_note( "unknown Role: '#{name}'" )
      STDERR.puts "unknown Role: '#{name}'"
    end
    list = [ nil, nil, nil, nil, nil ]
    @store.add_role( name, list )
    list_one_person( name )
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
    @store.timeframe.add_list_text( 'people', result_key, hands, name + ' ' + text )
    puppet = @store.collection[ 'person_puppets' ][ name ]
    @store.timeframe.add_list_text( 'puppets', result_key, puppet, name + ' ' + text )
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

  def parse_action( text, qscript_key, result_key )
    case text
    when /=/ # Grop definition
      parse_group( text, qscript_key, result_key )
    else
      name = text.split( ' ', 2 )[ 0 ]
      list = []
      while /^#{MATCH_NAME},/ =~ name
        list.push( name.sub( ',', '' ) )
        name, text = text.split( ' ', 2 )
      end
      case name
      when /^#{MATCH_NAME}[:]*$/
        list.push( name.sub( ':', '' ) )
      else
        STDERR.puts "Fehler in Role: #{name}"
      end
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
    @store.timeframe.add_spoken( name )
    player = @store.collection[ 'person' ][ name ][ 'player' ]
    @store.timeframe.add_spoken( player )
    voice = @store.collection[ 'person' ][ name ][ 'voice' ]
    if voice != player
      @store.timeframe.add_spoken( voice )
    end
    puppet = @store.collection[ 'person_puppets' ][ name ]
    @store.timeframe.add_spoken( puppet )
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

  def print_title_note( line )
    @qscript.puts_key( 'note', line )
    @qscript.puts ''
    @report.puts2_key( 'Note', line )
  end

  def parse_lines( filename, lines )
    @section = nil
    parse_title( filename )
    lines.each do |line|
      line.sub!( /\\\\$/, '' ) # remove DokuWiki linebreak
      case line
      when /^<html>/, /^\[\[/
        next # ignore navigation
      when /^==== / # title note
        print_title_note( line )
        next
      when /^      [*] / # head data
        parse_section( @section, line )
        next
      when /^    [*] / # head comment
        @section = line.slice( /[A-Za-z][A-Za-z0-9_ -]*[:]/ )[ 0 .. -2 ]
        parse_head( @section, line )
        next
      end
      line.strip!
      case line
      when ''
        next
      when /Backdrop_L/
        collect_backdrop( line )
      when /^%HND% Curtain - /
        curtain( line.sub( /^%HND% Curtain - */, '' ) )
        @section = nil
        next
      when /^%HND% /
        text = line.sub( /^%HND% /, '' )
        parse_stagehand( new_stagehand, text, 'stagehand', 'Stage' )
        collect_prop( text, nil )
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
      end
      next if print_simple_line( line )
      next if print_role_line( line )

      STDERR.puts line
    end
    @qscript.puts '}'
    @store.timeframe.sum_spoken( @store.collection )
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
qscript = QScript.new
report = Report.new
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
html = parser.report.html_table( table )
file_put_contents( 'html.html', html )

parser.report.save( 'test.txt' )

exit 0
# eof
