#!/usr/local/bin/ruby -w

# = read-scene.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018-2019 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'cgi'
require 'pp'

$: << '.'

ROLES_CONFIG_FILE = 'roles.ini'.freeze
SUBS_CONFIG_FILE = 'subs.ini'.freeze
PUPPET_POOL_FILE = 'puppet_pool.csv'.freeze
HTML_HEADER_FILE = 'header.html'.freeze
MATCH_NAME = '[A-Za-z0-9_-]+'.freeze
MATCH_SNAME = '[A-Za-z0-9_ \'-]+'.freeze

$nat_sort = true
$compat = false
$compat2 = true

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
    list.sort_by do |e|
      e.downcase.split( /(\d+)/ ).map { |a| a =~ /\d+/ ? a.to_i : a }
    end
  else
    list.sort_by( &:downcase )
  end
end

# sort arry by first element by natural order
def nat_sort_hash( hash )
  if $nat_sort
    hash.sort_by do |e|
      e[ 0 ].downcase.split( /(\d+)/ ).map { |a| a =~ /\d+/ ? a.to_i : a }
    end
  else
    hash.sort_by { |e| e[ 0 ].downcase }
  end
end

# quote a string
def quoted( text )
  '"' + text.gsub( '"', '\"' ) + '"'
end

# quote a string
def quoted_noescape( text )
  '"' + text + '"'
end

def html_escape( text )
  html = text.dup
  html.gsub!( '<', '&#60;' )
  html.gsub!( "\xe2\x80\x8b", '&#8203;' )
  html.gsub!( "\xe2\x80\x93", '&#8211;' )
  html.gsub!( "\xe2\x80\x99", '&#8217;' )
  html.gsub!( "\xe2\x80\x9c", '&#8220;' )
  html.gsub!( "\xe2\x80\x9d", '&#8221;' )
  if $compat
    html.gsub!( "\xc3\xb6", '&#246;' )
    html.gsub!( "\xc3\xbc", '&#252;' )
  end
  # p [ 'html_escape', text, html ] if text != html
  html
end

def tname( type, name )
  { type: type, name: name }
end

def role( name )
  { type: 'Role', name: name }
end

def actor( name )
  { type: 'Actor', name: name }
end

def puppet( name )
  { type: 'Puppet', name: name }
end

def clothing( name )
  { type: 'Clothing', name: name }
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
#   QScript.puts_list( arr )
#   QScript.puts_key_list( key, list )
#   QScript.puts_key( key, name, text = nil )
#   QScript.puts_key_token( key, token, name, text = nil )
#   QScript.save( filename )
class QScript
  attr_reader :lines

  def initialize
    @script = ''
    @lines = 0
  end

  def puts( line )
    @script << line
    @script << "\n"
    @lines += 1
  end

  def puts_list( list )
    key = list.shift
    text = "\t#{key}"
    list.each do |item|
      next if item.nil?

      item = item[ :name ] if item.respond_to?( :key? )
      text << " #{quoted( item )}"
    end
    puts text
  end

  def puts_key_list( key, list )
    puts_list( [ key ].concat( list ) )
  end

  def puts_key( key, name, text = nil )
    puts_list( [ key, name, text ] )
  end

  def puts_key_token( key, token, name, text = nil )
    puts_list( [ "#{key}#{token}", name, text ] )
  end

  def save( filename )
    file_put_contents( filename, @script )
  end
end

# === Class Timeframe
#   Timeframe.new( qscript )
#   Timeframe.qscript
#   Timeframe.timeframe
#   Timeframe.timeframe_count
#   Timeframe.timeframes_lines
#   Timeframe.timeframes_lines
#   Timeframe.scene( title )
#   Timeframe.this_timeframe
#   Timeframe.seen?( key, name )
#   Timeframe.add( key, val )
#   Timeframe.add_once( key, val )
#   Timeframe.add_hash( hashkey, key, val )
#   Timeframe.add_table( hashkey, table )
#   Timeframe.add_list_text( storekey, reportkey, name, text )
#   Timeframe.add_list( storekey, reportkey, token, name )
#   Timeframe.add_prop( storekey, reportkey, token, list )
#   Timeframe.count_spoken( key, name )
#   Timeframe.add_spoken( name )
#   Timeframe.list( key )
class Timeframe
  TIMEFRAME_FIELDS = {
    'Front props' => 'FrontProp',
    'Second level props' => 'SecondLevelProp',
    'Backdrop panels' => 'Backdrop',
    'Lights' => 'Light',
    'Ambiences' => 'Ambience',
    'Sounds' => 'Sound',
    'Videos' => 'Video',
    'Effects' => 'Effect',
    'Roles' => 'Role',
    'Person' => 'Actor',
    'Puppets' => 'Puppet',
    'Clothes' => 'Clothing',
    'Personal props' => 'PersonalProp',
    'Hand props' => 'HandProp',
    'Todos' => 'Todo'
  }.freeze

  attr_reader :qscript
  attr_reader :timeframe
  attr_reader :timeframe_count
  attr_reader :timeframes
  attr_reader :timeframes_lines

  def initialize( qscript )
    @timeframe = nil
    @timeframe_count = -1
    @timeframes = {}
    @timeframes_lines = {}
    @qscript = qscript
  end

  def scene( title )
    @timeframe = title
    @timeframe_count += 1
    @timeframes[ @timeframe ] = { number: @timeframe_count }
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

    @timeframes[ @timeframe ][ key ] = [] \
      unless @timeframes[ @timeframe ].key?( key )
    @timeframes[ @timeframe ][ key ].push( val )
  end

  def add_once( key, val )
    raise if val.nil?

    @timeframes[ @timeframe ][ key ] = [] \
      unless @timeframes[ @timeframe ].key?( key )
    return if @timeframes[ @timeframe ][ key ].include?( val )

    @timeframes[ @timeframe ][ key ].push( val )
  end

  def add_hash( hashkey, key, val )
    @timeframes[ @timeframe ][ hashkey ] = {} \
      unless @timeframes[ @timeframe ].key?( hashkey )
    @timeframes[ @timeframe ][ hashkey ][ key ] = val
  end

  def add_table( hashkey, table )
    @timeframes[ @timeframe ][ hashkey ] = table
  end

  def add_list_text( storekey, reportkey, name, text )
    @timeframes_lines[ storekey ] = {} unless @timeframes_lines.key?( storekey )
    @timeframes_lines[ storekey ][ name ] = [] \
      unless @timeframes_lines[ storekey ].key?( name )
    @timeframes_lines[ storekey ][ name ].push(
      loc: "loc#{@qscript.lines}_2", scene: @timeframe,
      key: reportkey, text: text
    )
  end

  def add_list( storekey, reportkey, token, name )
    reportkey2 = "#{reportkey}#{token}"
    add_list_text( storekey, reportkey2, name, tname( storekey, name ) )
  end

  def add_prop( storekey, reportkey, token, list )
    name, owner, puppet = list
    reportkey2 = "#{reportkey}#{token}"
    line = [ role( owner ), tname( storekey, name ) ]
    add_list_text( storekey, reportkey2, name, line )
    add_list_text( 'Role', reportkey2, owner, line )
    return if puppet.nil?
    return if reportkey == 'HanP'

    add_list_text( 'Puppet', reportkey2, puppet, line )
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

  def add_spoken( type, name )
    add_list_text( type + '_sum_spoken', 'Spokn', name, nil )
  end

  def list( key )
    return [] unless @timeframes[ @timeframe ].key?( key )

    timeframes[ @timeframe ][ key ]
  end
end

# === Class Store
#   Store.new( timeframe )
#   Store.items
#   Store.collection
#   Store.timeframe
#   Store.ignore
#   Store.add( collection, key, val )
#   Store.count( collection, key )
#   Store.add_item( type, name, hash )
#   Store.error_mesage( list )
#   Store.check_actor( name )
#   Store.uniq_player( player, prefix, name )
#   Store.add_person( name, what, player, prefix )
#   Store.add_voice( name, voice )
#   Store.add_puppet( name, puppet )
#   Store.add_clothing( name, clothing )
#   Store.add_role( name, list )
#   Store.add_backdrop( position, backdrop )
class Store
  ITEM_TYPE_INDEX = {
    'FrontProp' => 0,
    'SecondLevelProp' => 1,
    'Backdrop' => 2,
    'Light' => 3,
    'Ambience' => 4,
    'Sound' => 5,
    'Video' => 6,
    'Effect' => 7,
    'Role' => 8,
    'Actor' => 9,
    'Puppet' => 10,
    'Clothing' => 11,
    'PersonalProp' => 12,
    'HandProp' => 13,
    'Todo' => 14
  }.freeze
  COLLECTION_FIELDS = [
    'notes',
    'role_puppets',
    'role_clothes',
    'role_old_clothes',
    'owned_props',
    'PersonalProp_owner',
    'HandProp_owner',
    'stagehand',
    'todos'
  ].freeze

  attr_reader :items
  attr_reader :collection
  attr_reader :timeframe
  attr_reader :ignore

  def initialize( timeframe )
    @items = {}
    @collection = {}
    ITEM_TYPE_INDEX.each_key do |key|
      @items[ key ] = {}
      @collection[ key ] = {}
      @collection[ key + '_count' ] = {}
    end
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
    storekey = collection + '_count'
    @collection[ storekey ] = {} unless @collection.key?( storekey )
    if @collection[ storekey ].key?( key )
      @collection[ storekey ][ key ] += 1
    else
      @collection[ storekey ][ key ] = 1
    end
  end

  def add_item( type, name, hash )
    unless @items[ type ].key?( name )
      count = @items[ type ].size
      item_index = ITEM_TYPE_INDEX[ type ]
      @items[ type ][ name ] = {}
      @items[ type ][ name ][ :ref ] = "item#{item_index}_#{count}"
      @items[ type ][ name ][ :list ] = []
    end
    play = {
      loc: "loc#{@timeframe.qscript.lines}_2",
      scene: @timeframe.timeframe
    }.merge( hash )
    @items[ type ][ name ][ :list ] << play
  end

  def error_mesage( *list )
    text = 'TODO: '
    text << list.join( ' ' )
    text
  end

  def check_actor( name )
    return nil unless @items[ 'Actor' ].key?( name )

    seen = {}
    # pp @items[ 'Actor' ][ name ]
    # pp @items[ 'Actor' ][ name ][ :list ]
    @items[ 'Actor' ][ name ][ :list ].each do |item|
      next if item[ :scene ] != @timeframe.timeframe

      if item.key?( :stagehand )
        if seen.key?( :player )
          return error_mesage(
            "Person #{name} can't act as a stagehand",
            "for #{item[ :prop ]} here",
            "because it's already .player/hands",
            "of role #{seen[ :player ].join( ',' )}"
          )
        end

        seen[ :stagehand ] = [] unless seen.key?( :stagehand )
        seen[ :stagehand ].push( item[ :prop ] )
        next
      end

      next if !item.key?( :player ) && !item.key?( :hands )

      if seen.key?( :stagehand )
        return error_mesage(
          "#{item[ :role ]}.player/hands can't be set to #{name}",
          "because it's already a stagehand",
          "for #{seen[ :stagehand ].join( ',' )}"
        )
      end

      seen[ :player ] = [] unless seen.key?( :player )
      seen[ :player ].push( item[ :role ] )
      if seen[ :player ].uniq.size > 1
        return error_mesage(
          "#{item[ :role ]}.player/hands can't be set",
          "because it's already a .player/hands",
          "of role #{seen[ :player ].join( ',' )}"
        )
      end
    end
    nil
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
    return @uniq_player_seen[ seen_key ] if @uniq_player_seen.key?( seen_key )

    @ignore[ player ] += 1
    result = "#{player}#{@ignore[ player ]}"
    @uniq_player_seen[ seen_key ] = result
    result
  end

  def add_person( name, what, player, prefix )
    player = uniq_player( player, prefix, name )
    @collection[ 'Role' ][ name ][ what ] = player
    add( 'Actor', player, name )
    if what == 'voice'
      @timeframe.add( 'Actor', player ) \
        if @collection[ 'Role' ][ name ][ 'player' ] != player
    else
      @timeframe.add( 'Actor', player )
    end
    @timeframe.add_list_text(
      'Role', 'Pers+', name, [ [ role( name ), what ], actor( player ) ]
    )
    @timeframe.add_list_text(
      'Actor', 'Pers+', player, [ [ role( name ), what ], actor( player ) ]
    )
    player
  end

  def add_voice( name, voice )
    add_person( name, 'voice', voice, 'Actor' )
  end

  def add_puppet( name, puppet )
    puppet = uniq_player( puppet, 'Puppet', name )
    add( 'role_puppets', name, puppet )
    add( 'Puppet', puppet, name )
    @timeframe.add( 'Puppet', puppet )
    @timeframe.add_list_text(
      'Role', 'Pupp+', name, [ role( name ), puppet( puppet ) ]
    )
    @timeframe.add_list_text(
      'Puppet', 'Pupp+', puppet, [ role( name ), puppet( puppet ) ]
    )
    puppet
  end

  def add_clothing( name, clothing )
    clothing = uniq_player( clothing, 'Costume', name )
    return nil if clothing == 'None'

    add( 'role_clothes', name, clothing )
    add( 'Clothing', clothing, name )
    @timeframe.add( 'Clothing', clothing )
    @timeframe.add_list_text( 'Role', 'Clth+', name, [ name, clothing ] )
    puppet = @collection[ 'role_puppets' ][ name ]
    @timeframe.add_list_text(
      'Puppet', 'Clth+', puppet, [ name, clothing ]
    )
    @timeframe.add_list_text(
      'Clothing', 'Clth+', clothing, [ name, clothing ]
    )
    clothing
  end

  def drop_one_clothing( role, puppet, clothing )
    # p [ 'drop_one_clothing', role, puppet, clothing ]
    collection[ 'role_old_clothes' ][ role ] = clothing
    add( 'role_old_clothes', role, clothing )
    @timeframe.add_list_text(
      'Role', 'Clth-', role, [ role( role ), clothing( clothing ) ]
    )
    @timeframe.add_list_text(
      'Clothing', 'Clth-', clothing, [ role( role ), clothing( clothing ) ]
    )
    puppet = @collection[ 'role_puppets' ][ role ] if puppet.nil?
    return if puppet.nil?

    @timeframe.add_list_text(
      'Puppet', 'Clth-', puppet, [ role( role ), clothing( clothing ) ]
    )
  end

  def store_role( name, list )
    player, hands, voice, puppet, clothing = list
    voice = voice.nil? ? player : voice
    hands = hands.nil? ? player : hands
    add_item(
      'Role', name,
      player: player, hands: hands, voice: voice,
      puppet: puppet, clothing: clothing
    )
    add_item( 'Actor', player, role: name, player: true )
    add_item( 'Actor', voice, role: name, voice: true ) \
      unless voice == 'None'
    add_item( 'Actor', hands, role: name, hands: true )
    add_item( 'Puppet', puppet, role: name, clothing: clothing )
    return if clothing.nil?

    add_item( 'Clothing', clothing, role: name, puppet: puppet )
  end

  def add_role( name, list )
    count( 'Role', name )
    add( 'Role', name, {} )
    @timeframe.add( 'Role', name )
    player, hands, voice, puppet, clothing = list
    uplayer = add_person( name, 'player', player, 'Actor' )
    voice = voice.nil? ? uplayer : voice
    uvoice =
      if voice == 'None'
        voice
      else
        add_voice( name, voice )
      end
    hands = hands.nil? ? uplayer : hands
    uhands =
      if hands == 'None'
        hands
      else
        add_person( name, 'hands', hands, 'Hands' )
      end
    upuppet = add_puppet( name, puppet )
    uclothing = add_clothing( name, clothing )
    @timeframe.add_hash(
      'puppet_plays', upuppet, [ name, uplayer, uhands, uvoice, uclothing ]
    )
    store_role( name, [ uplayer, uhands, uvoice, upuppet, uclothing ] )
  end

  def add_backdrop( position, backdrop )
    key = "#{backdrop} #{position}"
    count( 'Backdrop', key )
    @timeframe.add( 'Backdrop', key )
    add_item( 'Backdrop', key, position: position )
    key
  end
end

# === Class Functions
#   Report.new( store, qscript )
#   Report.puppet_plays
#   Report.puppet_clothes
#   Report.put_html( line )
#   Report.puts_html( line )
#   Report.find_item_of_type( name, type )
#   Report.find_item( name )
#   Report.html_object_ref( name )
#   Report.to_html( ref, name )
#   Report.html_object_name( name )
#   Report.html_p( arr )
#   Report.puts2_key( key, name, text = nil )
#   Report.puts2_key_token( key, token, name, text = nil )
#   Report.capitalize( item )
#   Report.href( item )
#   Report.html_a_ref_item( ref, item )
#   Report.html_li_ref_item( ref, item )
#   Report.html_li_p_ref_item( ref, item )
#   Report.html_li_p2_ref_item( ref, scene, key, item )
#   Report.html_li_item( item )
#   Report.html_u_ref_item( ref, item )
#   Report.html_u_item( item )
#   Report.add_head( item )
#   Report.add_script( item )
#   Report.list_title_quoted( list, prefix )
#   Report.list_quoted( list, prefix, type )
#   Report.list_unsorted( list, type )
#   Report.list( hash, type )
#   Report.catalog_item
#   Report.puts_timeframe
#   Report.list_builds
#   Report.hand_props_actors( scene, prop_type )
#   Report.list_hand_props
#   Report.people_assignments( listname, person )
#   Report.merge_assignments( assignments, actor, action )
#   Report.merge_assignments_role( assignments, actor, entry )
#   Report.list_people_assignments
#   Report.table_caption( title )
#   Report.html_table( table, title, tag = '' )
#   Report.html_table_r( table, title, tag = '' )
#   Report.html_list( caption, title, hash, seperator = '</td><td>' )
#   Report.rows( timeframe, key )
#   Report.columns_and_rows( key )
#   Report.puts_timeframe_table( title, key )
#   Report.find_backdrop( scene, prop )
#   Report.find_scene_backdrops( scene, prop )
#   Report.puts_backdrops_table( title, key )
#   Report.puppet_play_full( title, key )
#   Report.puppet_use_data( key )
#   Report.puppet_use_clothes( key )
#   Report.puts_use_table( title, table )
#   Report.puts_tables
#   Report.puppet_image( puppet )
#   Report.save_html( filename )
class Report
  REPORT_CATALOG = {
    'Front props' => 'FrontProp',
    'Second level props' => 'SecondLevelProp',
    'Backdrop panels' => 'Backdrop',
    'Lights' => 'Light',
    'Ambiences' => 'Ambience',
    'Sounds' => 'Sound',
    'Videos' => 'Video',
    'Effects' => 'Effect',
    'Roles' => 'Role',
    'Person' => 'Actor',
    'Puppets' => 'Puppet',
    'Clothes' => 'Clothing',
    'Personal props' => 'PersonalProp',
    'Hand props' => 'HandProp',
    'Todos' => 'Todo'
  }.freeze
  REPORT_TABLES = {
    'Backdrops' => 'Backdrop',
    'Roles' => 'Role',
    'People' => 'Actor',
    'Puppets' => 'Puppet',
    'Puppet plays' => 'Puppet',
    'Puppet use' => 'Puppet',
    'Puppet clothes' => 'Puppet'
  }.freeze
  REPORT_BUILDS = {
    'Backdrop panel' => 'Backdrop',
    'Effect' => 'Effect',
    'Front prop' => 'FrontProp',
    'Second level prop' => 'SecondLevelProp',
    'Personal prop' => 'PersonalProp',
    'Hand prop' => 'HandProp'
  }.freeze
  REPORT_HANDS = {
    'Effect' => 'Effect',
    'Front prop' => 'FrontProp',
    'Second level prop' => 'SecondLevelProp',
    'Personal prop' => 'PersonalProp',
    'Hand prop' => 'HandProp'
  }.freeze
  ITEM_LIST = [
    'FrontProp',
    'SecondLevelProp',
    'Backdrop',
    'Light',
    'Ambience',
    'Sound',
    'Video',
    'Effect',
    'Role',
    'Actor',
    'Puppet',
    'Clothing',
    'PersonalProp',
    'HandProp',
    'Todo'
  ].freeze

  attr_accessor :puppet_plays
  attr_accessor :puppet_clothes

  def initialize( store, qscript )
    @store = store
    @qscript = qscript
    @cgi = CGI.new( 'html5' )
    @html_head = File.read( HTML_HEADER_FILE )
    @html_head <<
      "<body><a href=\"#top\">^&nbsp;</a> <u>Table of contents</u>\n"
    @html_head << '<ul>'
    @counters = {}
    @html_script = "</ul><br/>\n<u id=\"script\">Script</u>\n"
    @html_script << '<ul>'
    @html_report = "</ul><br/>\n"
    @html_head << html_li_item( 'Script' )
  end

  def put_html( line )
    @html_report << line
  end

  def puts_html( line )
    @html_report << line
    @html_report << "\n"
  end

  def find_item_of_type( name, type )
    if @store.items.key?( type )
      return @store.items[ type ][ name ] if @store.items[ type ].key?( name )
    end

    pp [ 'not found', name, type ]
    nil
  end

  def find_item( name )
    ITEM_LIST.each do |key|
      next unless @store.items.key?( key )

      return @store.items[ key ][ name ] if @store.items[ key ].key?( name )
    end

    pp [ 'not found', name ]
    nil
  end

  def html_object_ref( name )
    if name.respond_to?( :key? )
      obj = find_item_of_type( name[ :name ], name[ :type ] )
      # p [ name, obj ]
      return obj[ :ref ]
    end

    obj = find_item( name )
    return obj[ :ref ] unless obj.nil?

    pp [ 'html_object_ref not found', name ]
    nil
  end

  def to_html( ref, name )
    "<a href=\"##{ref}\">#{html_escape( name )}</a>"
  end

  def html_object_name( name )
    if name.respond_to?( :key? )
      return to_html( name[ :ref ], name[ :name ] ) if name.key?( :ref )

      obj = find_item_of_type( name[ :name ], name[ :type ] )
      return to_html( obj[ :ref ], name[ :name ] )
    end

    obj = find_item( name )
    return to_html( obj[ :ref ], name ) unless obj.nil?

    html_escape( name )
  end

  def html_p( arr )
    loc = "loc#{@qscript.lines}_2"
    key = arr.shift
    text = '&nbsp;' + key
    arr.each do |item|
      text << ' '
      if item.respond_to?( :key )
        text << html_object_name( item )
        next
      end
      if item.respond_to?( :shift )
        head = item.shift.dup
        text << html_object_name( head )
        # text << html_object_name( item.shift.dup.to_s )
        item.each do |sub|
          text << '.'
          text << html_object_name( sub )
        end
        next
      end
      text << html_object_name( item )
    end
    html = @cgi.p( 'id' => loc ) { text }
    if $compat
      html.sub!( '<P ', '<p ' )
      html.sub!( '</P>', '</p>' )
    end
    puts_html( html )
  end

  def puts2_key( key, name, text = nil )
    if text.nil?
      html_p( [ key, name ] )
    else
      html_p( [ key, name, text ] )
    end
  end

  def puts2_key_token( key, token, name, text = nil )
    puts2_key( key + token, name, text )
  end

  def capitalize( item )
    item.tr( ' ', '_' ).gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase ).delete( '_"' )
  end

  def href( item )
    citem = capitalize( item )
    if $compat2
      case citem
      when 'CatalogItemDetails'
        return 'catDetails'
      when /^TimeframeScene/
        return "timeframe#{@store.timeframe.timeframe_count}"
      end
    end

    item[ 0 .. 0 ].downcase + citem[ 1 .. -1 ].delete( ' "-' )
  end

  def html_a_ref_item( ref, item )
    "<a href=\"##{ref}\">#{item}</a>"
  end

  def html_li_ref_item( ref, item )
    '<li>' + html_a_ref_item( ref, item ) + "</li>\n"
  end

  def html_li_p_ref_item( ref, item )
    if $compat
      "<li class=\"p\" id=\"#{ref}\">#{item}"
    else
      "<li class=\"p\" id=\"#{ref}\">#{item}\n"
    end
  end

  def html_li_p2_ref_item( ref, scene, key, item )
    "<p><a href=\"##{ref}\">#{scene}</a>: #{key} #{item}</p>\n"
  end

  def html_li_item( item )
    html_li_ref_item( href( item ), item )
  end

  def html_u_ref_item( ref, item )
    "<u id=\"#{ref}\">#{item}</u>"
  end

  def html_u_item( item )
    html_u_ref_item( href( item ), item )
  end

  def add_head( item )
    @html_head << html_li_item( item )
    @html_report << html_u_item( item ) + "\n"
  end

  def add_script( item )
    @html_script << html_li_item( item )
    @html_report << html_u_item( item ) + "<br/>\n"
  end

  def list_title_quoted( list, prefix )
    return if list.nil?

    count = 0
    @html_report << '<ul>'
    sorted = nat_sort_list( list )
    sorted.each do |prop|
      text = "#{prefix} #{quoted_noescape( prop )}"
      ref = "timeframeC#{count}"
      count += 1
      @html_report << html_li_ref_item( ref, text ) + "\n"
    end
    @html_report << "</ul><br/>\n"
  end

  def list_quoted( list, prefix, type )
    return if list.nil?

    seen = {}
    sorted = nat_sort_list( list )
    sorted.each do |prop|
      next if seen.key?( prop )

      seen[ prop ] = true
      ref = html_object_ref( tname( type, prop ) )
      text = "#{prefix} #{html_escape( quoted_noescape( prop ) )}"
      @html_report << html_li_ref_item( ref, text ) + "\n"
    end
  end

  def list_unsorted( list, type )
    return if list.nil?

    list.each do |prop, _count|
      ref =
        if type.nil?
          'tab' + capitalize( prop )
        else
          html_object_ref( tname( type, prop ) )
        end
      @html_report << html_li_ref_item( ref, html_escape( prop ) ) + "\n"
    end
  end

  def list( hash, type )
    sorted = nat_sort_hash( hash )
    list_unsorted( sorted, type )
  end

  def catalog
    @html_report << "<br/>\n"
    add_head( 'Catalog' )
    count = 0
    @html_report << '<ul>'
    Timeframe::TIMEFRAME_FIELDS.each_key do |key|
      @html_report << html_li_ref_item( "catalog#{count}", key )
      count += 1
    end
    @html_report << "</ul><br/>\n"

    count = 0
    Timeframe::TIMEFRAME_FIELDS.each_pair do |key, type|
      @html_report <<
        html_u_ref_item( "catalog#{count}", "Catalog: #{key}" ) + "\n<ul>"
      count += 1
      list( @store.items[ type ], type )
      @html_report << "</ul><br/>\n"
    end
  end

  def timeframe_list_item( hash )
    html_item = ''
    if hash[ :text ].respond_to?( :key )
      html_item << html_object_name( hash[ :text ] )
      return html_item
    end

    if hash[ :text ].respond_to?( :shift )
      hash[ :text ].each do |item|
        if item.respond_to?( :key )
          html_item << ' ' + html_object_name( item )
          next
        end

        if item.respond_to?( :shift )
          arr = item.dup
          html_item << html_object_name( arr.shift.dup )
          arr.each do |sub|
            html_item << '.' + html_object_name( sub )
          end
          next
        end

        html_item << ' ' + html_object_name( item )
      end
    else
      html_item << html_object_name( hash[ :text ] )
    end
    html_item
  end

  def person_scene_count( scene, type, name )
    listname = type + '_sum_spoken'
    return 0 unless @store.timeframe.timeframes_lines.key?( listname )
    return 0 unless @store.timeframe.timeframes_lines[ listname ].key?( name )

    # pp @store.timeframe.timeframes_lines[ listname ][ name ]
    sum = 0
    @store.timeframe.timeframes_lines[ listname ][ name ].each do |h|
      next if h[ :scene ] != scene

      sum += 1
    end
    sum
  end

  def timeframe_list_spoken( type, name, scene )
    case type
    when 'Role', 'Actor', 'Puppet'
      sum = person_scene_count( scene, type, name )
      return nil if sum.zero?

      return "#{sum}x spoken"
    end
    nil
  end

  def timeframe_list( type, name )
    return unless @store.timeframe.timeframes_lines.key?( type )
    return unless @store.timeframe.timeframes_lines[ type ].key?( name )

    html_list = ''
    last_scene = nil
    @store.timeframe.timeframes_lines[ type ][ name ].each do |h|
      if last_scene != h[ :scene ]
        html_list << "<br/>\n" unless last_scene.nil?
        text = timeframe_list_spoken( type, name, h[ :scene ] )
        unless text.nil?
          count = @store.timeframe.timeframes[ h[ :scene ] ][ :number ]
          refa = "timeframe#{count}"
          html_list <<
            '<p>' + html_a_ref_item( refa, h[ :scene ] ) +
            ': ' + text + "</p>\n"
        end
      end
      last_scene = h[ :scene ]
      html_item = timeframe_list_item( h )
      html_more = html_li_p2_ref_item(
        h[ :loc ], h[ :scene ], h[ :key ], html_item
      )
      # p [ type, h, text, html_item ]
      html_list << html_more
    end
    @html_report <<
      if $compat
        html_list[ 0 .. -2 ] # strip lf
      else
        html_list
      end
  end

  def prefix_by_title( title )
    return 'Clothing' if title == 'Clothes'

    title.sub( /s$/, '' )
  end

  def person_count( listname, name )
    return 0 unless @store.timeframe.timeframes_lines.key?( listname )
    return 0 unless @store.timeframe.timeframes_lines[ listname ].key?( name )

    @store.timeframe.timeframes_lines[ listname ][ name ].size
  end

  def person_spoken_count( type, name )
    listname = type + '_sum_spoken'
    return 0 unless @store.timeframe.timeframes_lines.key?( listname )
    return 0 unless @store.timeframe.timeframes_lines[ listname ].key?( name )

    @store.timeframe.timeframes_lines[ listname ][ name ].size
  end

  def catalog_item
    add_head( 'Catalog item details' )
    @html_report << '<ul>'
    Timeframe::TIMEFRAME_FIELDS.each_pair do |key, type|
      prefix = prefix_by_title( key )
      sorted = nat_sort_hash( @store.items[ type ] )
      sorted.each do |name, _h|
        # p h
        count = person_count( type, name )
        case type
        when 'Role', 'Actor', 'Puppet'
          count += person_spoken_count( type, name )
        end
        title = "#{prefix} #{quoted_noescape( name )} (#{count})"
        ref = html_object_ref( tname( type, name ) )
        @html_report << html_li_p_ref_item( ref, html_escape( title ) )
        timeframe_list( type, name )
        @html_report << "</li>\n"
      end
    end
    @html_report << '</ul>'
  end

  def puts_timeframe
    add_head( 'Timeframe contents' )
    list_title_quoted(
      @store.timeframe.timeframes.map { |x| x[ 0 ] }, 'Timeframe'
    )
    @store.timeframe.timeframes.each_key do |scene|
      count = @store.timeframe.timeframes[ scene ][ :number ]
      refu = "timeframeC#{count}"
      refa = "timeframe#{count}"
      item = 'Timeframe contents ' + html_a_ref_item( refa, quoted( scene ) )
      @html_report << html_u_ref_item( refu, item ) + "\n"
      @html_report << '<ul>'
      Timeframe::TIMEFRAME_FIELDS.each_pair do |field, type|
        prefix = prefix_by_title( field )
        list_quoted(
          @store.timeframe.timeframes[ scene ][ type ], prefix, type
        )
      end
      @html_report << "</ul><br/>\n"
    end
  end

  def list_builds
    builds = {}
    @store.timeframe.timeframes.each_key do |scene|
      builds[ scene ] = {}
      REPORT_BUILDS.each_pair do |name, type|
        builds[ scene ][ name ] = @store.timeframe.timeframes[ scene ][ type ]
      end
    end
    builds
  end

  def hand_props_actors( scene, prop_type )
    scene_props_hands = @store.timeframe.timeframes[ scene ][ 'props_hands' ]
    props = @store.timeframe.timeframes[ scene ][ prop_type ]
    return nil if props.nil?

    seen = {}
    list = []
    props.each do |prop|
      next if seen.key?( prop )

      seen[ prop ] = true
      act =
        if scene_props_hands.key?( prop )
          scene_props_hands[ prop ].join( ', ' )
        else
          '?'
        end
      next if act == 'None'

      list.push( [ prop, act ] )
    end
    list
  end

  def list_hand_props
    hands = {}
    @store.timeframe.timeframes.each_key do |scene|
      hands[ scene ] = []
      REPORT_HANDS.each_pair do |name, type|
        next unless @store.timeframe.timeframes[ scene ].key?( type )

        hand_props_actors( scene, type ).each do |arr|
          hands[ scene ].push( [ name ].concat( arr ) )
        end
      end
    end
    hands
  end

  def people_assignments( listname, person )
    found = []
    @store.timeframe.timeframes_lines[ listname ][ person ].each do |line|
      # p line
      case line[ :key ]
      when /^Pers[+]/
        task = person + '.' + line[ :text ][ 0 ][ 0 ]
        next if found.include?( task )

        found.push( task )
        next
      end

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

  def merge_assignments( assignments, actor, action )
    if assignments.key?( action )
      assignments[ action ] ||= [ actor ]
    else
      assignments[ action ] = [ actor ]
    end
  end

  def merge_assignments_role( assignments, actor, entry )
    if entry.key?( :player )
      action = entry[ :role ] + '.player'
      merge_assignments( assignments, actor, action )
      return
    end

    if entry.key?( :hands )
      action = entry[ :role ] + '.hands'
      merge_assignments( assignments, actor, action )
      return
    end

    return unless entry.key?( :voice )

    action = entry[ :role ] + '.voice'
    merge_assignments( assignments, actor, action )
  end

  def list_people_assignments
    assignments = {}
    @store.items[ 'Actor' ].each_pair do |actor, h|
      next if actor == 'None'

      h[ :list ].each do |entry|
        if entry.key?( :role )
          merge_assignments_role( assignments, actor, entry )
          next
        end

        next unless entry.key?( :stagehand )

        if entry.key?( :prop )
          action = entry[ :prop ]
          merge_assignments( assignments, actor, action )
          next
        end

        if entry.key?( :effect )
          action = entry[ :effect ]
          merge_assignments( assignments, actor, action )
        end
      end
    end
    assignments
  end

  def table_caption( title )
    href = 'tab' + capitalize( title )
    html_u_ref_item( href, title )
  end

  def html_table( table, title, tag = '' )
    html = table_caption( title )
    html << "\n#{tag}<table>"
    table.each do |row|
      html << '<tr>'
      row.each do |column|
        html << '<td>'
        if column.respond_to?( :key? )
          html << html_object_name( column )
        else
          html << html_escape( column.to_s ) unless column.nil?
        end
        html << '</td>'
      end
      html << "</tr>\n"
    end
    html << "</table><br/>\n"
    html
  end

  def html_table_r( table, title, tag = '' )
    html = table_caption( title )
    html << "\n#{tag}<table>"
    table.each do |row|
      html << '<tr>'
      row.each do |column|
        if column.respond_to?( :key? )
          html << '<td class="x">'
          html << html_object_name( column )
          html << '</td>'
        else
          case column
          when nil
            html << '<td/>'
          when /^Scene/
            html << '<td class="r"><div><div><div>'
            html << column.to_s
            html << '</div></div></div>'
            html << '</td>'
          when 'x'
            html << '<td class="x">'
            html << column.to_s
            html << '</td>'
          else
            html << '<td>'
            html << column.to_s
            html << '</td>'
          end
        end
      end
      html << "</tr>\n"
    end
    html << "</table><br/>\n"
    html << tag.sub( '<', '</' )
    html
  end

  def html_list( caption, title, hash, seperator = '</td><td>' )
    html = table_caption( caption + ' ' + title )
    html << "\n<table>"
    hash.each_pair do |item, h2|
      next if h2.nil?

      seen = {}
      h2.each do |text|
        next if text.nil?
        next if seen.key?( text )

        seen[ text ] = true
        html << '<tr><td>'
        html << html_escape( item.to_s )
        html << seperator
        html << html_escape( text.to_s )
        html << "</td></tr>\n"
      end
    end
    html << "</table><br/>\n"
    html
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

  def columns_and_rows( key )
    rows = []
    columns = [ nil ]
    @store.timeframe.timeframes.each_pair do |scene, hash|
      next unless hash.key?( key )

      columns.push( scene )
      hash[ key ].each do |puppet|
        next if rows.include?( puppet )

        rows.push( puppet )
      end
    end
    [ [ columns ], rows ]
  end

  def puts_timeframe_table( title, key )
    table, rows = columns_and_rows( key )
    rows = nat_sort_list( rows )
    rows.each do |puppet|
      row = [ puppet ]
      @store.timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( key )

        unless hash[ key ].include?( puppet )
          row.push( nil )
          next
        end
        row.push( 'x' )
      end
      table.push( row )
    end
    @html_report << html_table_r( table, title )
    table
  end

  def find_backdrop( scene, prop )
    uses = @store.items[ 'Backdrop' ][ prop ][ :list ].size
    count = 0
    @store.items[ 'Backdrop' ][ prop ][ :list ].each do |item|
      count += 1
      next if item[ :scene ] != scene

      text = prop.dup
      text << " <b>(use #{count}/#{uses})</b>" if uses > 1
      return text if $compat2

      return { ref: item[ :loc ], name: text }
    end

    prop
  end

  def find_scene_backdrops( scene, prop )
    @store.items[ 'Backdrop' ][ prop ][ :list ].each do |item|
      next if item[ :scene ] != scene

      return { ref: item[ :loc ], name: scene }
    end

    scene
  end

  def puts_backdrops_table( title, key )
    table = [ [ 'Timeframe', 'Left', 'Middle', 'Right' ] ]
    @store.timeframe.timeframes.each_pair do |scene, hash|
      next unless hash.key?( key )

      row = [ find_scene_backdrops( scene, hash[ key ][ 0 ] ) ]
      hash[ key ].each do |prop|
        row.push( find_backdrop( scene, prop ) )
      end
      table.push( row )
    end
    @html_report << html_table( table, title, '<ul><li>' )
    @html_report << '</li></ul>'
  end

  def puppet_play_full( title, key )
    table, puppets = columns_and_rows( key )
    puppets.sort.each do |puppet|
      row = [ puppet ]
      @store.timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( 'puppet_plays' )

        unless hash[ 'puppet_plays' ].key?( puppet )
          row.push( nil )
          next
        end
        val = hash[ 'puppet_plays' ][ puppet ][ 1 ].dup
        val << '/' + hash[ 'puppet_plays' ][ puppet ][ 2 ] \
          if hash[ 'puppet_plays' ][ puppet ][ 2 ] \
          != hash[ 'puppet_plays' ][ puppet ][ 1 ]
        val << ' (' + hash[ 'puppet_plays' ][ puppet ][ 0 ] + ')'
        row.push( val )
      end
      table.push( row )
    end
    @html_report << html_table_r( table, title )
  end

  def puppet_use_data( key )
    table, puppets = columns_and_rows( key )
    puppets.each do |puppet|
      row = [ puppet ]
      @store.timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( 'puppet_plays' )

        unless hash[ 'puppet_plays' ].key?( puppet )
          row.push( nil )
          next
        end
        row.push( hash[ 'puppet_plays' ][ puppet ][ 0 ] )
      end
      table.push( row )
    end
    @puppet_plays = table
    table
  end

  def puppet_use_clothes( key )
    table, puppets = columns_and_rows( key )
    table[ 0 ].insert( 1, 'Image' )
    puppets.each do |puppet|
      row = [ puppet, puppet_image( puppet ) ]
      @store.timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( 'puppet_plays' )

        unless hash[ 'puppet_plays' ].key?( puppet )
          row.push( nil )
          next
        end
        role = hash[ 'puppet_plays' ][ puppet ][ 0 ]
        pp hash[ 'puppet_plays' ][ puppet ][ 0 ]
        row[ 0 ] = "#{role} (#{puppet})"
        row.push( hash[ 'puppet_plays' ][ puppet ][ 4 ] )
      end
      table.push( row )
    end
    @puppet_clothes = table
    table
  end

  def puts_use_table( title, table )
    @html_report << html_table( table, title )
  end

  def puts_tables
    add_head( 'Tables' )
    @html_report << '<ul>'
    list_unsorted( REPORT_TABLES.keys, nil )
    @html_report << "</ul><br/>\n"
    REPORT_TABLES.each_pair do |title, type|
      case title
      when 'Backdrops'
        puts_backdrops_table( title, type )
      when 'Puppet plays'
        puppet_play_full( title, type )
      when 'Puppet use'
        puts_use_table( title, puppet_use_data( type ) )
      when 'Puppet clothes'
        puts_use_table( title, puppet_use_clothes( type ) )
      else
        puts_timeframe_table( title, type )
      end
    end
  end

  def puppet_image( puppet )
    return "<img #{$puppet_pool[ puppet ]}/>".gsub( '&', '&amp;' ) \
      if $puppet_pool.key?( puppet )
  end

  def save_html( filename, extra = '' )
    file_put_contents(
      filename,
      @html_head +
        @html_script +
        @html_report +
        extra +
        "</body></html>\n"
    )
  end
end

# === Class Parser
#   Parser.new( store, qscript, report )
#   Parser.store
#   Parser.qscript
#   Parser.report
#   Parser.make_title( name )
#   Parser.parse_title( filename )
#   Parser.curtain( text )
#   Parser.add_backdrop_list( list )
#   Parser.parse_single_backdrop( line )
#   Parser.list_one_person( name )
#   Parser.drop_clothing( name )
#   Parser.drop_person_props( name )
#   Parser.drop_puppet( name )
#   Parser.drop_person( name )
#   Parser.list_one_person2( name )
#   Parser.parse_single_puppet( line )
#   Parser.suffix_props( line, key )
#   Parser.tagged_props( line, key )
#   Parser.parse_single_prop( line, key, type = nil )
#   Parser.parse_all_props( line )
#   Parser.parse_section_data( section, line )
#   Parser.parse_table_role( line )
#   Parser.parse_puppets( line )
#   Parser.parse_backdrops( line )
#   Parser.parse_effects( line )
#   Parser.parse_costumes( line )
#   Parser.parse_head( section, line )
#   Parser.add_single_prop( prop, names )
#   Parser.add_owned_prop( prop, owner, names )
#   Parser.remove_owned_prop( prop, owner, names )
#   Parser.count_single_prop( prop, names )
#   Parser.count_owned_prop( prop, owner, names )
#   Parser.add_scene_prop( prop )
#   Parser.collect_single_prop( prop, names )
#   Parser.collect_owned_prop( prop, owner, names )
#   Parser.collect_just_prop( prop, names )
#   Parser.search_simple_props( line, suffix, tag )
#   Parser.collect_simple_props( line, suffix, tag, names )
#   Parser.search_handprop( line )
#   Parser.collect_handprop( line, owner )
#   Parser.collect_backdrop( line )
#   Parser.search_prop( line )
#   Parser.collect_prop( line, name )
#   Parser.new_stagehand( prop )
#   Parser.parse_stagehand( name, text, qscriptkey, reportkey )
#   Parser.add_note( line )
#   Parser.add_fog( text )
#   Parser.add_error_note( line )
#   Parser.change_role_player( role, old_player, player )
#   Parser.change_role_hand( role, old_hand, hand )
#   Parser.change_role_voice( role, old_voice, voice )
#   Parser.change_role_puppet( role, old_puppet, puppet )
#   Parser.change_role_clothing( role, old_clothing, clothing )
#   Parser.old_role( role, list )
#   Parser.merge_role( role, list )
#   Parser.unknown_person( name )
#   Parser.parse_position( name, text )
#   Parser.print_role( name, qscript_key, result_key, text )
#   Parser.print_roles( name, qscript_key, result_key, text )
#   Parser.print_roles_list( list, qscript_key, result_key, text )
#   Parser.parse_group( line, qscript_key, result_key )
#   Parser.parse_role_name( text )
#   Parser.parse_action( text, qscript_key, result_key )
#   Parser.print_role_line( line )
#   Parser.print_spoken( name, comment, text )
#   Parser.print_spoken_roles( name, comment, text )
#   Parser.print_spoken_mutiple( line )
#   Parser.replace_text( line )
#   Parser.close_scene
#   Parser.print_unknown_line( line )
#   Parser.parse_section( line )
#   Parser.parse_hand( text )
#   Parser.parse_lines( filename, lines )
class Parser
  SIMPLE_MAP = {
    '%AMB%' => [ 'ambience', 'Ambie', 'Ambience' ],
    '%ATT%' => [ 'note', 'Note' ],
    # '%MIX%' => [ 'note', 'Note' ],
    '###' => [ 'note', 'Note' ],
    '%LIG%' => [ 'light', 'Light', 'Light' ],
    '%MUS%' => [ 'ambience', 'Ambie', 'Ambience' ],
    '%SND%' => [ 'sound', 'Sound', 'Sound' ],
    '%VID%' => [ 'video', 'Video', 'Video' ]
  }.freeze
  ROLE_MAP = {
    '%ACT%' => [ 'action', 'Actio' ]
  }.freeze
  FRONTPROP_NAMES = [ 'FrontProp', 'frontProp', 'FroP' ].freeze
  SECONDPROP_NAMES = [ 'SecondLevelProp', 'secondLevelProp', 'SecP' ].freeze
  JUSTPROP_NAMES = [ 'HandProp', 'just handProp', 'JHanP' ].freeze
  HANDPROP_NAMES = [ 'HandProp', 'handProp', 'HanP' ].freeze
  PERSPROP_NAMES = [ 'PersonalProp', 'personalProp', 'PerP' ].freeze
  JUSTPERS_NAMES = [ 'PersonalProp', 'just personalProp', 'JPerP' ].freeze
  BACKDROP_FIELDS = [ 'Left', 'Middle', 'Right' ].freeze
  ITEM_TAGS = {
    'fp' => 'FrontProp',
    'pr' => 'FrontProp', # Backward compatible
    'sp' => 'SecondLevelProp',
    '2nd' => 'SecondLevelProp', # Backward compatible
    'pp' => 'PersonalProp',
    'hp' => 'HandProp',
    'tec' => 'HandProp',
    'sfx' => 'HandProp'
  }.freeze

  attr_reader :store
  attr_reader :qscript
  attr_reader :report

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
    case text
    when 'open', 'close'
      add_note( "TODO: same curtain state: #{text}" ) \
        if text == @store.collection[ 'curtain' ]
    else
      add_note( "TODO: unknown curtain state: #{text}" )
    end
    @store.collection[ 'curtain' ] = text
  end

  def add_backdrop_list( list )
    @qscript.puts_key_list( 'backdrop', list )
    @report.html_p( [ 'Backd', *list ] )
    list.each do |key|
      @store.timeframe.add_list_text( 'Backdrop', 'Backd', key, list )
    end
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
    @store.collection[ 'Role' ][ name ].each_pair do |key, val|
      @qscript.puts "\tperson+ \"#{name}\".#{key} \"#{val}\""
      @report.html_p( [ 'Pers+', [ role( name ), key ], actor( val ) ] )
    end
    val = @store.collection[ 'role_puppets' ][ name ]
    p [ 'list_one_person', name, val ]
    @qscript.puts_key( 'puppet+', name, val )
    @report.puts2_key( 'Pupp+', role( name ), puppet( val ) )
    clothing = @store.collection[ 'role_clothes' ][ name ]
    return if clothing.nil?

    @qscript.puts_key( 'clothing+', name, clothing )
    @report.puts2_key( 'Clth+', role( name ), clothing( clothing ) )
  end

  def drop_clothing( name )
    val = @store.collection[ 'role_clothes' ][ name ]
    unless val.nil?
      @qscript.puts_key( 'clothing-', name, val )
      @report.puts2_key( 'Clth-', role( name ), clothing( val ) )
      @store.drop_one_clothing( name, nil, val )
    end
    @store.collection[ 'role_old_clothes' ][ name ] = nil
  end

  def drop_person_props( name )
    return unless @store.collection[ 'owned_props' ].key?( name )

    @store.collection[ 'owned_props' ][ name ].each do |h|
      prop = h[ :name ]
      next if prop.nil?

      # remove_owned_prop( prop, name, h[ :names ] )
      storekey, qscriptkey, reportkey = h[ :names ]
      @qscript.puts_key( qscriptkey + '-', name, prop )
      @report.puts2_key(
        reportkey + '-', role( name ), tname( storekey, prop )
      )
      @store.collection[ storekey + '_owner' ][ prop ] = nil
      @store.timeframe.add_list_text(
        storekey, reportkey + '-', prop,
        [ role( name ), tname( storekey, prop ) ]
      )
      @store.timeframe.add_list_text(
        'Role', reportkey + '-', name,
        [ role( name ), tname( storekey, prop ) ]
      )
      next if reportkey == 'HanP'

      puppet = @store.collection[ 'role_puppets' ][ name ]
      @store.timeframe.add_list_text(
        'Puppet', reportkey + '-', puppet,
        [ role( name ), tname( storekey, prop ) ]
      )
    end
    @store.collection[ 'owned_props' ][ name ] = []
  end

  def drop_puppet( name )
    @qscript.puts_key( 'puppet-', name )
    @report.puts2_key( 'Pupp-', role( name ) )
    @store.timeframe.add_list_text(
      'Role', 'Pupp-', name, tname( 'Role', name )
    )
    puppet = @store.collection[ 'role_puppets' ][ name ]
    @store.timeframe.add_list_text(
      'Puppet', 'Pupp-', puppet, tname( 'Role', name )
    )
  end

  def drop_person( name )
    @qscript.puts ''
    @store.collection[ 'Role' ][ name ].each_key do |what|
      @qscript.puts "\tperson- \"#{name}\".#{what}"
      @report.html_p( [ 'Pers-', [ name, what ] ] )
      @store.timeframe.add_list_text(
        'Role', 'Pers-', name, [ [ name, what ] ]
      )
      player = @store.collection[ 'Role' ][ name ][ what ]
      @store.timeframe.add_list_text(
        'Actor', 'Pers-', player, [ [ name, what ] ]
      )
    end
    drop_clothing( name )
    drop_person_props( name )
    drop_puppet( name )
  end

  def list_one_person2( name )
    @qscript.puts ''
    # @store.collection[ 'person' ][ name ].each_pair do |key, val|
    #   @report.puts2_key( 'Pers=', "#{name}.#{key}", val )
    # end
    old_clothing = @store.collection[ 'role_old_clothes' ][ name ]
    return if old_clothing.nil?

    clothing = @store.collection[ 'role_clothes' ][ name ]
    if old_clothing == clothing
      @qscript.puts_key( 'clothing=', name, clothing )
      @report.puts2_key( 'Clth=', name, clothing )
      return
    end
    @qscript.puts_key( 'clothing-', name, old )
    @report.puts2_key( 'Clth-', role( name ), clothing( old ) )
    drop_one_clothing( name, nil, old_clothing )
    @qscript.puts_key( 'clothing+', name, clothing )
    @report.puts2_key( 'Clth+', role( name ), clothing( clothing ) )
    @store.collection[ 'role_clothes' ][ name ] = clothing
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
          @store.collection[ 'role_puppets' ][ role ],
          @store.collection[ 'role_clothes' ][ role ]
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
        case hand
        when '---'
          hand = nil
        when /^Voice: */
          voice = hand.sub( /^Voice: */, '' )
          hand = player
        end
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
    add_note( check_actor( list[ 0 ] ) )
    add_note( check_actor( list[ 1 ] ) )
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

  def parse_single_prop( line, key, type = nil )
    line.scan( /<#{key}>(#{MATCH_SNAME})<\/#{key}>/i ) do |m|
      next if m.empty?

      m.each do |prop|
        @scene_props[ prop ] = 0
        handtext = line.scan( /[(]([^)]*)[)]/ )
        hands =
          if handtext.empty?
            [ new_stagehand( prop ) ]
          else
            p [ 'parse_single_prop', handtext ]
            handtext[ 0 ][ 0 ].split( /, */ )
          end
        p [ 'parse_single_prop', hands ]
        @scene_props_hands[ prop ] = hands
        @store.add_item( type, prop, hands: hands )
      end
    end
  end

  def parse_all_props( line )
    ITEM_TAGS.each_pair do |tag, type|
      parse_single_prop( line, tag, type )
    end
  end

  def parse_section_data( section, line )
    @qscript.puts line.sub( /^    /, "\t//" )
    line.sub!( /^ *[*] /, '' )
    line = replace_text( line )
    case section
    when 'Backdrop', 'Special effects'
      parse_single_backdrop( line )
      parse_all_props( line )
    when 'Puppets'
      parse_single_puppet( line )
    when 'Setting'
      @setting << "\n" + replace_text( line )
    when 'On 2nd rail', 'On playrail', 'Hand props', 'Props'
      parse_all_props( line )
    when 'Stage setup'
      @setting << "\n" + replace_text( line )
      parse_all_props( line )
    end
  end

  def parse_table_role( line )
    list2 = line.split( '|' ).map( &:strip )
    role = list2[ 1 ]
    player = list2[ 2 ]
    list2[ 3 ] = player if list2[ 3 ] == ''
    list2[ 4 ] = player if list2[ 4 ] == ''
    # list2[ 4 ] = list2[ 4 ].split( ',' ).map( &:strip )
    list = merge_role( role, list2[ 2 .. -1 ] )
    @store.add_role( role, list )
    add_note( @store.check_actor( list[ 0 ] ) )
    add_note( @store.check_actor( list[ 1 ] ) )
    list_one_person( role )
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
    parse_all_props( line )
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
      @setting << "\n" + replace_text( line )
    when 'Stage setup', 'On 2nd rail', 'On playrail'
      # ignore
    when 'Props', 'Hand props', 'PreRec', 'Special effects'
      # ignore
    else
      p [ 'parse_head', section, line ]
    end
  end

  def add_single_prop( prop, names )
    storekey, qscriptkey, reportkey = names
    @qscript.puts_key_token( qscriptkey, '+', prop )
    @report.puts2_key_token( reportkey, '+', prop )
    @store.add_item( storekey, prop, type: names[ 0 ], hands: [], names: names )
    @store.count( storekey, prop )
    @store.timeframe.add( storekey, prop )
    @store.timeframe.add_list( storekey, reportkey, '+', prop )
  end

  def add_owned_prop( prop, owner, names )
    storekey, qscriptkey, reportkey = names
    ownerkey = storekey + '_owner'
    @qscript.puts_key_token( qscriptkey, '+', owner, prop )
    @report.puts2_key_token(
      reportkey, '+', role( owner ), tname( names[ 0 ], prop )
    )
    @store.add_item(
      storekey, prop,
      type: names[ 0 ], name: owner, hands: owner, names: names
    )
    @store.count( storekey, prop )
    @store.add( ownerkey, prop, owner )
    @store.timeframe.add_once( storekey, prop )
    puppet = @store.collection[ 'role_puppets' ][ owner ]
    @store.timeframe.add_prop(
      storekey, reportkey, '+', [ prop, owner, puppet ]
    )
    @store.collection[ 'owned_props' ][ owner ] = [] \
      unless @store.collection[ 'owned_props' ].key?( owner )
    @store.collection[ 'owned_props' ][ owner ].push(
      type: names[ 0 ], name: prop, names: names
    )
  end

  def remove_owned_prop( prop, owner, names )
    p [ 'remove_owned_prop', prop, owner, names ]
    storekey, qscriptkey, reportkey = names
    ownerkey = storekey + '_owner'
    return if qscriptkey =~ /^just /

    @qscript.puts_key_token( qscriptkey, '-', owner, prop )
    @report.puts2_key(
      reportkey + '-', role( owner ), tname( storekey, prop )
    )
    @store.count( storekey, prop )
    @store.add( ownerkey, prop, nil )
    puppet = @store.collection[ 'role_puppets' ][ owner ]
    @store.timeframe.add_prop(
      storekey, reportkey, '-', [ prop, owner, puppet ]
    )
    @store.collection[ 'owned_props' ][ owner ].delete(
      type: names[ 0 ], name: prop, names: names
    )
  end

  def count_single_prop( prop, names )
    storekey, qscriptkey, reportkey = names
    @store.count( storekey, prop )
    @qscript.puts_key_token( qscriptkey, '=', prop )
    @report.puts2_key_token( reportkey, '=', prop )
    @store.timeframe.add( storekey, prop )
    @store.timeframe.add_list( storekey, reportkey, '=', prop )
  end

  def count_owned_prop( prop, owner, names )
    storekey, qscriptkey, reportkey = names
    ownerkey = storekey + '_owner'
    old = @store.collection[ ownerkey ][ prop ]
    if old == owner
      @store.count( storekey, prop )
      @qscript.puts_key_token( qscriptkey, '=', owner, prop )
      @report.puts2_key_token( reportkey, '=', owner, prop )
      puppet = @store.collection[ 'role_puppets' ][ owner ]
      @store.timeframe.add_prop(
        storekey, reportkey, '=', [ prop, owner, puppet ]
      )
      return
    end
    remove_owned_prop( prop, old, names ) unless old.nil?
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
    storekey = names[ 0 ] + '_count'
    @store.collection[ storekey ] = {} unless @store.collection.key?( storekey )
    unless @store.collection[ storekey ].key?( prop )
      add_single_prop( prop, names )
      # add_note( "TODO: #{names[ 0 ]} missing in header '#{prop}'" )
      return
    end
    count_single_prop( prop, names )
  end

  def collect_owned_prop( prop, owner, names )
    add_scene_prop( prop )
    storekey = names[ 0 ] + '_count'
    unless @store.collection[ storekey ].key?( prop )
      add_owned_prop( prop, owner, names )
      return
    end
    count_owned_prop( prop, owner, names )
  end

  def collect_just_prop( prop, names )
    add_scene_prop( prop )
    storekey, qscriptkey, reportkey = names
    ownerkey = storekey + '_owner'
    p [ 'collect_just_prop', ownerkey, @scene_props_hands ]
    if @store.collection.key?( ownerkey )
      old = @store.collection[ ownerkey ][ prop ]
      remove_owned_prop( prop, old, names ) unless old.nil?
    end
    @store.count( storekey, prop )
    @store.timeframe.add_once( storekey, prop )
    @store.timeframe.add_list( storekey, reportkey, '', prop )
    @store.add_item( storekey, prop, hands: [] )
    @qscript.puts_key( qscriptkey, prop )
    @report.puts2_key( reportkey, prop )
  end

  def search_simple_props( line, suffix, tag )
    props = []
    suffix_props( line, suffix ).each do |prop|
      props.push( prop )
    end

    tagged_props( line, tag ).each do |prop|
      props.push( prop )
    end
    props
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

  def search_handprop( line )
    props = []
    # p ['search_handprop', line ]
    suffix_props( line, 'hp' ).each do |prop|
      props.push( prop )
    end

    [ 'pp' ].each do |key|
      tagged_props( line, key ).each do |prop|
        props.push( prop )
      end
    end

    [ 'hp', 'sfx', 'tec' ].each do |key|
      tagged_props( line, key ).each do |prop|
        props.push( prop )
      end
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

    [ 'pp' ].each do |key|
      tagged_props( line, key ).each do |prop|
        props.push( prop )
        unless owner.nil?
          collect_owned_prop( prop, owner, PERSPROP_NAMES )
          next
        end
        collect_just_prop( prop, JUSTPERS_NAMES )
      end
    end

    [ 'hp', 'sfx', 'tec' ].each do |key|
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

  def search_prop( line )
    return [] if line.nil?

    props = search_handprop( line )
    props.concat( search_simple_props( line, 'pr', 'fp' ) )
    props.concat( search_simple_props( line, '2nd', 'sp' ) )
    props
  end

  def collect_prop( line, name )
    return [] if line.nil?

    props = collect_handprop( line, name )
    props.concat( collect_simple_props( line, 'pr', 'fp', FRONTPROP_NAMES ) )
    props.concat( collect_simple_props( line, '2nd', 'sp', SECONDPROP_NAMES ) )
    props
  end

  def new_stagehand( prop )
    prop.tr( ' ', '_' ).gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase ) + '_SH'
  end

  def parse_stagehand( name, text, qscriptkey, reportkey )
    @store.count( 'stagehand', name )
    @store.add( 'Actor', name, 'stagehand' )
    @qscript.puts_key( qscriptkey, name, text )
    @report.puts2_key( reportkey, name, text )
    @store.timeframe.add( 'Actor', name )
    @store.timeframe.add_list_text(
      'Actor', reportkey, name, [ actor( name ), text ]
    )
    name
  end

  def print_simple_line( line )
    SIMPLE_MAP.each_pair do |key, val|
      qscript_key, result_key, type = val
      case line
      when /^#{key} /
        line.strip!
        text = line.sub( /^#{key}  */, '' )
        collect_prop( text, nil )
        if type.nil?
          storekey = "#{qscript_key}s"
        else
          storekey = type
          @store.add_item( type, text, text: text )
        end
        @qscript.puts_key( qscript_key, text )
        @report.puts2_key( result_key, text )
        @store.count( storekey, text )
        if type.nil?
          @store.timeframe.add( result_key, text )
        else
          @store.timeframe.add( storekey, text )
        end
        @store.timeframe.add_list( storekey, result_key, '', text )
        return true
      end
    end
    false
  end

  def add_note( line )
    return if line.nil?

    @qscript.puts_key( 'note', line )
    if $compat
      @report.html_p( [ 'Note&nbsp;', line ] )
    else
      @report.puts2_key( 'Note', line )
    end
    @qscript.puts ''
  end

  def add_fog( text )
    hand = new_stagehand( 'fog' )
    @store.add_item( 'Actor', hand, effect: text, stagehand: true )
    @store.add_item( 'Effect', text, stagehand: hand )
    add_note( @store.check_actor( hand ) )
    parse_stagehand( hand, text, 'effect', 'Effct' )
    @store.timeframe.add( 'Effect', text )
    @store.timeframe.add_list_text( 'Effect', 'Effct', text, [ hand, text ] )
  end

  def add_error_note( line )
    add_note( line )
    STDERR.puts line
  end

  def change_role_player( role, old_player, player )
    return if old_player.nil?
    return if old_player == ''
    return if old_player == player

    add_error_note(
      "INFO: Player changed #{role}: #{old_player} -> #{player}"
    )
  end

  def change_role_hand( role, old_hand, hand )
    return if old_hand.nil?
    return if old_hand == ''
    return if old_hand == hand

    add_error_note(
      "INFO: Hands changed #{role}: #{old_hand} -> #{hand}"
    )
  end

  def change_role_voice( role, old_voice, voice )
    return if old_voice.nil?
    return if old_voice == ''
    return if old_voice == voice

    add_error_note(
      "INFO: Voice changed #{role}: #{old_voice} -> #{voice}"
    )
  end

  def change_role_puppet( role, old_puppet, puppet )
    return if old_puppet.nil?
    return if old_puppet == ''
    return if old_puppet == puppet

    add_error_note(
      "INFO: Puppet changed #{role}: #{old_puppet} -> #{puppet}"
    )
  end

  def change_role_clothing( role, old_clothing, clothing )
    return if old_clothing.nil?
    return if old_clothing == ''
    return if old_clothing == clothing

    add_error_note(
      "INFO: Clothing changed #{role}: #{old_clothing} -> #{clothing}"
    )
  end

  def old_role( role, list )
    old_list = [
      @store.collection[ 'Role' ][ role ][ 'player' ],
      @store.collection[ 'Role' ][ role ][ 'hands' ],
      @store.collection[ 'Role' ][ role ][ 'voice' ],
      @store.collection[ 'role_puppets' ][ role ],
      @store.collection[ 'role_clothes' ][ role ]
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
    return list unless @store.collection[ 'Role' ].key?( role )

    old_list, new_list = old_role( role, list )
    change_role_player( role, old_list[ 0 ], new_list[ 0 ] )
    change_role_hand( role, old_list[ 1 ], new_list[ 1 ] )
    change_role_voice( role, old_list[ 2 ], new_list[ 2 ] )
    change_role_puppet( role, old_list[ 3 ], new_list[ 3 ] )
    change_role_clothing( role, old_list[ 4 ], new_list[ 4 ] )
    p old_list
    p list
    list
  end

  def unknown_person( name )
    # return if @store.collection[ 'person' ].key?( name )
    return if @store.timeframe.seen?( 'Role', name )

    p [ 'unknown_person', name ]
    if @section != 'Puppets:'
      add_error_note( "TODO: unknown Role: '#{name}'" )
      STDERR.puts( @store.collection[ 'Role' ][ name ] )
    end
    if @store.collection[ 'person' ].key?( name )
      # assume nothing changed
      # @store.update_role( name, @store.collection )
      list = [
        @store.collection[ 'Role' ][ name ][ 'player' ],
        @store.collection[ 'Role' ][ name ][ 'hands' ],
        @store.collection[ 'Role' ][ name ][ 'voice' ],
        @store.collection[ 'role_puppets' ][ name ],
        @store.collection[ 'role_clothes' ][ name ]
      ]
      @store.add_role( name, list )
      add_note( @store.check_actor( list[ 0 ] ) )
      add_note( @store.check_actor( list[ 1 ] ) )
      list_one_person2( name )
    else
      list = [ nil, nil, nil, nil, nil ]
      @store.add_role( name, list )
      add_note( @store.check_actor( list[ 0 ] ) )
      add_note( @store.check_actor( list[ 1 ] ) )
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
    @store.timeframe.add_list_text( 'Role', result_key, name, [ name, text ] )
    player = @store.collection[ 'Role' ][ name ][ 'player' ]
    @store.timeframe.add_list_text(
      'Actor', result_key, player, [ name, text ]
    )
    hands = @store.collection[ 'Role' ][ name ][ 'hands' ]
    unless hands == player
      @store.timeframe.add_list_text(
        'Actor', result_key, hands, [ name, text ]
      )
    end
    puppet = @store.collection[ 'role_puppets' ][ name ]
    @store.timeframe.add_list_text(
      'Puppet', result_key, puppet, [ name, text ]
    )
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
    @store.timeframe.add_spoken( 'Role', name )
    player = @store.collection[ 'Role' ][ name ][ 'player' ]
    @store.timeframe.add_spoken( 'Actor', player )
    voice = @store.collection[ 'Role' ][ name ][ 'voice' ]
    @store.timeframe.add_spoken( 'Actor', voice ) if voice != player
    puppet = @store.collection[ 'role_puppets' ][ name ]
    @store.timeframe.add_spoken( 'Puppet', puppet )
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
    @store.timeframe.add_table( 'props_hands', @scene_props_hands )
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
      add_note( line )
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
    when /^[\^] *Role /
      @section = 'Role'
      return true
    when /^\|/ # table data
      return true if @section.nil?

      @qscript.puts "\t//" + line
      parse_table_role( replace_text( line ) )
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

  def parse_hand( text )
    props = search_prop( text )
    props.each do |prop|
      hands =
        if @scene_props_hands.key?( prop )
          @scene_props_hands[ prop ]
        else
          [ new_stagehand( prop ) ]
        end
      p [ '%HND%', props, hands ]
      hands.each do |hand|
        @store.add_item( 'Actor', hand, prop: prop, stagehand: true )
        add_note( @store.check_actor( hand ) )
        # collect_prop( text, hand )
        parse_stagehand( hand, text, 'stagehand', 'Stage' )
      end
    end
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
        parse_hand( line.sub( /^%HND% /, '' ) )
        next
      when /^%FOG% /
        add_fog( line.sub( /^%FOG% /, '' ) )
        next
      when /^%MIX% /
        add_note( line )
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

$roles_config = RolesConfig.new( ROLES_CONFIG_FILE )
$subs = read_subs( SUBS_CONFIG_FILE )
$puppet_pool = read_subs( PUPPET_POOL_FILE )
qscript = QScript.new
timeframe = Timeframe.new( qscript )
store = Store.new( timeframe )
report = Report.new( store, qscript )
parser = Parser.new( store, qscript, report )

ARGV.each do |filename|
  STDERR.puts filename
  lines = File.read( filename ).split( "\n" )
  parser.parse_lines( filename, lines )
end

qscript.save( 'qscript.txt' )

parser.report.catalog
parser.report.puts_timeframe
parser.report.catalog_item
parser.report.puts_tables

table = parser.report.puppet_plays
html_append = parser.report.html_table( table, 'Puppet use' )

table2 = parser.report.puppet_clothes
clothes = parser.report.html_table( table2, 'Clothes' )
html_append << clothes

builds = parser.report.list_builds
builds.each_pair do |key, h|
  html = parser.report.html_list( 'Builds', key, h, '; ' )
  html_append << html
  parser.report.put_html( html )
end

hprops = parser.report.list_hand_props
hprops.each_pair do |key, h|
  html = parser.report.html_table( h, 'Hands' + ' ' + key )
  html_append << html
  parser.report.put_html( html )
end

assignments = parser.report.list_people_assignments
html = parser.report.html_list( 'All', 'Assignments', assignments )
html_append << html
parser.report.put_html( html )

html_clothes = File.read( HTML_HEADER_FILE )
html_clothes << '<body>'
html_clothes << clothes
file_put_contents( 'clothes.html', html_clothes )
file_put_contents( 'html.html', html_append )

parser.report.save_html( 'out.html' )

# pp parser.store.items[ 'FrontProp' ]
# pp parser.store.items[ 'Backdrop' ]
# pp parser.store.items[ 'Role' ]
# pp parser.store.items[ 'Clothing' ]
# pp parser.store.items[ 'Actor' ]
# pp parser.store.items[ 'Actor' ][ 'Liam' ]

exit 0
# eof
