#!/usr/local/bin/ruby

# = read-scene.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2018-2023 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'cgi'
require 'json'
require 'csv'
require 'pp'

$: << '.'

# config file for groups of roles
ROLES_CONFIG_FILE = 'roles.ini'.freeze
# config file for patterns to replace
SUBS_CONFIG_FILE = 'subs.ini'.freeze
# list of puppets and image html code
PUPPET_POOL_FILE = 'puppet_pool.csv'.freeze
# general header for html output files
HTML_HEADER_FILE = 'header.html'.freeze
# output for actors to wiki lines
WIKI_ACTORS_FILE = 'wiki_actors.json'.freeze
# output for todo list
TODO_LIST_FILE = 'todo-list.csv'.freeze
# header for todo list
TODO_LIST_HEADER = [ 'Scene', 'Category', 'Item' ].freeze
# output for assignment list
ASSIGNMENT_LIST_FILE = 'assignment-list.csv'.freeze
# regular expression for matching names
MATCH_NAME = '[A-Za-z0-9_-]+'.freeze
# regular expression for matching names within a tag
MATCH_SNAME = '[^<]+'.freeze

$nat_sort = true
$compat = false
$compat2 = true
$debug = 0
$debug = 1

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
  "\"#{text.gsub( '"', '\"' )}\""
end

# quote a string
def quoted_noescape( text )
  "\"#{text}\""
end

# convert special characters to html codes
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

# make a hash with name and given type
def tname( type, name )
  { type: type, name: name }
end

# make a hash with name and Role type
def role( name )
  { type: 'Role', name: name }
end

# make a hash with name and Actor type
def actor( name )
  { type: 'Actor', name: name }
end

# make a hash with name and Puppet type
def puppet( name )
  { type: 'Puppet', name: name }
end

# make a hash with name and Costume type
def clothing( name )
  { type: 'Costume', name: name }
end

# read patters for replacements from given file
def read_subs( filename )
  $subs = {}
  $subs_count = {}
  scene = 'global'
  File.read( filename ).split( "\n" ).each do |line|
    next if line =~ /^#/

    unless line.include?( ';' )
      scene = line.delete( '[]' )
      next
    end

    pattern, text = line.split( ';', 2 )
    $subs[ scene ] = {} unless $subs.key?( scene )
    $subs[ scene ][ pattern ] = text
    $subs_count[ pattern ] = 0
  end
end

# read puppet data from given file
def read_puppet( filename ) 
  $puppet_pool = {}
  $puppet_builders = {}
  File.read( filename ).split( "\n" ).each do |line|
    next if /^#/ =~ line

    name, builder, image = line.split( ';', 3 )
    $puppet_pool[ name ] = image
    $puppet_builders[ name ] = builder
  end
end

# === Class Functions
#   RolesConfig.new( scene, filename )
#   RolesConfig.roles_map
#   RolesConfig.add_roles( name, list )
#   RolesConfig.map_roles( name )
#   RolesConfig.ununsed
class RolesConfig
  # get the raw hash
  attr_accessor :roles_map

  # create a mapping table
  def initialize( scene, filename )
    @roles_map = {}
    @roles_seen = {}
    return unless File.exist?( filename )

    File.read( filename ).split( "\n" ).each do |line|
      next if /^#/ =~ line

      list = line.split( ';' )
      scene2, group = list[ 0 .. 1 ]
      next if scene2 != scene

      roles = list[ 2 .. -1 ]
      p [ scene, group, '=', roles ]
      @roles_map[ group ] = roles
      @roles_seen[ group ] = 0
    end
  end

  # add a mapping to the table
  def add_roles( name, list )
    @roles_map[ name ] = list
    @roles_seen[ name ] = 0
  end

  # read a mapping from the table
  def map_roles( name )
    return [ name ] unless @roles_map.key?( name )

    @roles_seen[ name ] += 1
    @roles_map[ name ]
  end

  # show unused entries
  def unused
    @roles_seen.each_pair do |name, count|
      next if count.positive?

      puts "Role Group #{name} is not used."
    end
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
  # current line number of qscript
  attr_reader :lines

  # create a qscript buffer
  def initialize
    @script = ''
    @lines = 0
  end

  # add a line to qscript
  def puts( line )
    @script << line
    @script << "\n"
    @lines += 1
  end

  # build a line from given list and add the line to qscript
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

  # merge key and list, then add the line to qscript
  def puts_key_list( key, list )
    puts_list( [ key ].concat( list ) )
  end

  # merge key, list and text, then add the line to qscript
  def puts_key( key, name, text = nil )
    puts_list( [ key, name, text ] )
  end

  # merge key, token, name and text, then add the line to qscript
  def puts_key_token( key, token, name, text = nil )
    puts_list( [ "#{key}#{token}", name, text ] )
  end

  # write the final qscript into the given file
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
#   Timeframe.wiki_highlite
#   Timeframe.scene( title, filename )
#   Timeframe.this_timeframe
#   Timeframe.add_wiki_actor_for( actor, role )
#   Timeframe.add_wiki_group_for( roles, group )
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
  # List of items to monitor per timeframe
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
    'Costumes' => 'Costume',
    'Personal props' => 'PersonalProp',
    'Hand props' => 'HandProp',
    'Tech props' => 'TechProp',
    'Special effect' => 'SpecialEffect',
    'Todos' => 'Todo'
  }.freeze

  # the current qscript object
  attr_reader :qscript
  # the current timeframe
  attr_reader :timeframe
  # the current timeframe number
  attr_reader :timeframe_count
  # the full timeframe list
  attr_reader :timeframes
  # the full timeframe lines
  attr_reader :timeframes_lines
  # the full wiki_highlite
  attr_reader :wiki_highlite

  # create a timeframe
  def initialize( qscript )
    @timeframe = nil
    @timeframe_count = -1
    @timeframes = {}
    @timeframes_lines = {}
    @qscript = qscript
    @wiki_highlite = {}
  end

  # start a new scene
  def scene( title, filename )
    @timeframe = title
    @timeframe_count += 1
    @timeframes[ @timeframe ] = { number: @timeframe_count, filename: filename }
    @wiki_highlite[ filename ] = {}
  end

  # get the list of the current timeframe
  def this_timeframe
    @timeframes[ @timeframe ]
  end

  # add an actor for highlite in wiki
  def add_wiki_actor_for( actor, pattern )
    filename = @timeframes[ @timeframe ][ :filename ]
    @wiki_highlite[ filename ][ actor ] = [] \
      unless @wiki_highlite[ filename ].key?( actor )
    @wiki_highlite[ filename ][ actor ].push( pattern ) \
      unless @wiki_highlite[ filename ][ actor ].include?( pattern )
  end

  # add an group for highlite in wiki
  def add_wiki_group_for( roles, group )
    filename = @timeframes[ @timeframe ][ :filename ]
    @wiki_highlite[ filename ].each_pair do |actor, list|
      roles.each do |role|
        next unless list.include?( role )

        puts "Adding: #{actor}: role=#{role}, group=#{group} " \
          unless $debug.zero?
        add_wiki_actor_for( actor, group )
      end
    end
  end

  # check if we have a new item in the current timeframe
  def seen?( key, name )
    return false unless @timeframes[ @timeframe ].key?( key )
    return false unless @timeframes[ @timeframe ][ key ].include?( name )

    true
  end

  # add an new item to the current timeframe
  def add( key, val )
    if val.nil?
      pp @error_line
      warn @error_line
    end
    raise if val.nil?

    @timeframes[ @timeframe ][ key ] = [] \
      unless @timeframes[ @timeframe ].key?( key )
    @timeframes[ @timeframe ][ key ].push( val )
  end

  # add an item to the current timeframe if it is new
  def add_once( key, val )
    raise if val.nil?

    @timeframes[ @timeframe ][ key ] = [] \
      unless @timeframes[ @timeframe ].key?( key )
    return if @timeframes[ @timeframe ][ key ].include?( val )

    @timeframes[ @timeframe ][ key ].push( val )
  end

  # add a hash to the current timeframe
  def add_hash( hashkey, key, val )
    @timeframes[ @timeframe ][ hashkey ] = {} \
      unless @timeframes[ @timeframe ].key?( hashkey )
    @timeframes[ @timeframe ][ hashkey ][ key ] = val
  end

  # add a table to the current timeframe
  def add_table( hashkey, table )
    @timeframes[ @timeframe ][ hashkey ] = table
  end

  # add an full entry to the timeframes lines
  def add_list_text( storekey, reportkey, name, text )
    @timeframes_lines[ storekey ] = {} unless @timeframes_lines.key?( storekey )
    @timeframes_lines[ storekey ][ name ] = [] \
      unless @timeframes_lines[ storekey ].key?( name )
    @timeframes_lines[ storekey ][ name ].push(
      loc: "loc#{@qscript.lines}_2", scene: @timeframe,
      key: reportkey, text: text
    )
  end

  # add an item to the timeframes lines
  def add_list( storekey, reportkey, token, name )
    reportkey2 = "#{reportkey}#{token}"
    add_list_text( storekey, reportkey2, name, tname( storekey, name ) )
  end

  # add an prop to the timeframes lines
  def add_prop( storekey, reportkey, token, list )
    name, owner, hands, puppet = list
    reportkey2 = "#{reportkey}#{token}"
    line = [ role( owner ), tname( storekey, name ) ]
    add_list_text( storekey, reportkey2, name, line )
    add_list_text( 'Role', reportkey2, owner, line )
    unless hands.nil?
      hands.each do |hand|
        next if hand.casecmp( 'none' ).zero?

        add( 'Actor', hand )
        add_list_text( 'Actor', reportkey2, hand, line )
        add_wiki_actor_for( hand, name )
      end
    end

    return if puppet.nil?
    return if reportkey == 'HanP'

    add_list_text( 'Puppet', reportkey2, puppet, line )
  end

  # count a spoken line
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

  # add a spoken line to the current timeframe
  def add_spoken( type, name )
    add_list_text( "#{type}_sum_spoken", 'Spokn', name, nil )
  end

  # add a full list or hash to the current timeframe
  def list( key )
    return [] unless @timeframes[ @timeframe ].key?( key )

    timeframes[ @timeframe ][ key ]
  end
end

# === Class Store
#   Store.new( timeframe )
#   Store.items
#   Store.collection
#   Store.current_roles
#   Store.timeframe
#   Store.ignore
#   Store.add( collection, key, val )
#   Store.count( collection, key )
#   Store.add_item( type, name, hash )
#   Store.error_message( list )
#   Store.check_actor( name )
#   Store.check_puppet( role, name )
#   Store.check_clothing( puppet, name )
#   Store.uniq_player( player, prefix, name )
#   Store.last_role( role, what )
#   Store.add_role_collection( name, what, player )
#   Store.add_person( name, what, player, prefix )
#   Store.add_voice( name, voice )
#   Store.add_puppet( name, puppet )
#   Store.add_clothing( name, clothing )
#   Store.add_role( name, list )
#   Store.add_backdrop( position, backdrop )
class Store
  # map items type to location index
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
    'Costume' => 11,
    'PersonalProp' => 12,
    'HandProp' => 13,
    'TechProp' => 13,
    'SpecialEffect' => 14,
    'Todo' => 15
  }.freeze
  # list we will collect over all scenes
  COLLECTION_FIELDS = [
    'notes',
    'role_puppets',
    'role_costumes',
    'role_old_costumes',
    'owned_props',
    'PersonalProp_owner',
    'HandProp_owner',
    'TechProp_owner',
    'SpecialEffect_owner',
    'stagehand',
    'todos'
  ].freeze

  # items list
  attr_reader :items
  # collection list
  attr_reader :collection
  # current roles list
  attr_reader :current_roles
  # timeframe object
  attr_reader :timeframe
  # hash of placeholder names
  attr_reader :ignore

  # create a store
  def initialize( timeframe )
    @items = {}
    @collection = {}
    @current_roles = {}
    ITEM_TYPE_INDEX.each_key do |key|
      @items[ key ] = {}
      @collection[ key ] = {}
      @collection[ "#{key}_count" ] = {}
    end
    COLLECTION_FIELDS.each do |field|
      @collection[ field ] = {}
    end
    @roles = {}
    @timeframe = timeframe
    @ignore = {
      'Actor' => 0,
      'Hands' => 0,
      'Puppet' => 0,
      'Costume' => 0,
      nil => 0
    }
  end

  # add an item to the collection
  def add( collection, key, val )
    @collection[ collection ][ key ] = val
  end

  # count an item in the collection
  def count( collection, key )
    storekey = "#{collection}_count"
    @collection[ storekey ] = {} unless @collection.key?( storekey )
    if @collection[ storekey ].key?( key )
      @collection[ storekey ][ key ] += 1
    else
      @collection[ storekey ][ key ] = 1
    end
  end

  # add an item to the collection
  def add_item( type, name, hash )
    unless @items[ type ].key?( name )
      count = @items[ type ].size
      item_index = ITEM_TYPE_INDEX[ type ]
      @items[ type ][ name ] = {}
      @items[ type ][ name ][ :ref ] = "item#{item_index}_#{count}"
      @items[ type ][ name ][ :list ] = []
      # @items[ type ][ name ][ :name ] = name
    end
    play = {
      loc: "loc#{@timeframe.qscript.lines}_2",
      scene: @timeframe.timeframe
    }.merge( hash )
    @items[ type ][ name ][ :name ] = hash[ :text ] \
      unless @items[ type ][ name ].key?( :name )
    @items[ type ][ name ][ :list ] << play
  end

  # add an error_message
  def error_message( *list )
    list.join( ' ' )
  end

  # check an actor for collisions
  def check_actor( name )
    return nil unless @items[ 'Actor' ].key?( name )

    seen = {}
    # pp @items[ 'Actor' ][ name ]
    # pp @items[ 'Actor' ][ name ][ :list ]
    @items[ 'Actor' ][ name ][ :list ].each do |item|
      next if item[ :scene ] != @timeframe.timeframe

      if item.key?( :stagehand )
        unless $debug.zero?
          if seen.key?( :player )
            return error_message(
              "Person '#{name}' can't act as a stagehand",
              "for '#{item[ :prop ]}',",
              "because it's already Player/Hands",
              "for '#{seen[ :player ].join( ',' )}'"
            )
          end

          seen[ :stagehand ] = [] unless seen.key?( :stagehand )
          seen[ :stagehand ].push( item[ :prop ] )
        end
        next
      end

      next if !item.key?( :player ) && !item.key?( :hands )

      unless $debug.zero?
        if seen.key?( :stagehand )
          return error_message(
            "Player/Hands for '#{item[ :role ]}' can't be set to '#{name}',",
            "because it's already a stagehand",
            "for '#{seen[ :stagehand ].join( ',' )}'"
          )
        end
      end

      seen[ :player ] = [] unless seen.key?( :player )
      seen[ :player ].push( item[ :role ] )
      if seen[ :player ].uniq.size > 1
        return error_message(
          "Player/Hands for '#{item[ :role ]}' can't be set to '#{name}',",
          "because it's already a Player/Hands",
          "of role '#{seen[ :player ].join( ',' )}'"
        )
      end
    end
    nil
  end

  def check_puppet( role, name )
    return nil unless @items[ 'Costume' ].key?( name )

    seen = []
    @items[ 'Costume' ][ name ][ :list ].each do |item|
      next if item[ :scene ] != @timeframe.timeframe

      seen.push( item[ :role ] )
    end
    if seen.uniq.size > 1
      return error_message(
        "Puppet for '#{role}' can't be set to '#{name}',",
        "because it's already a Puppet",
        "of role '#{seen.join( ',' )}'"
      )
    end
    nil
  end

  def check_clothing( puppet, name )
    return nil unless @items[ 'Costume' ].key?( name )
    return nil if name.casecmp( 'none' ).zero?

    seen = {}
    @items[ 'Costume' ][ name ][ :list ].each do |item|
      next if item[ :scene ] != @timeframe.timeframe

      seen[ :puppet ] = [] unless seen.key?( :puppet )
      seen[ :puppet ].push( item[ :puppet ] )
    end

    if seen[ :puppet ].uniq.size > 1
      return error_message(
        "Costume for '#{puppet}' can't be set to '#{name}',",
        "because it's already a Costume",
        "of puppet '#{seen[ :puppet ].join( ',' )}'"
      )
    end
    nil
  end

  # create a uniq player name if needed
  def uniq_player( player, prefix, name )
    if player.nil? || @ignore.key?( player )
      @ignore[ prefix ] += 1
      return "#{prefix}_#{name}"
    end
    player.strip!
    player.sub( /^\(/, '' ).sub( /\)$/, '' )
  end

  # track changing players
  def add_role_collection( name, what, player )
    @current_roles[ name ] = {} unless @current_roles.key?( name )
    @current_roles[ name ][ what ] = player
    return if player.nil?

    @collection[ 'Role' ][ name ] = {} unless @collection[ 'Role' ].key?( name )
    unless @collection[ 'Role' ][ name ].key?( what )
      @collection[ 'Role' ][ name ][ what ] = [ player ]
      return
    end

    return if @collection[ 'Role' ][ name ][ what ].include?( player )

    @collection[ 'Role' ][ name ][ what ].push( player )
  end

  # get current player
  def last_role( role, what )
    return nil unless @current_roles[ role ].key?( what )

    @current_roles[ role ][ what ]
  end

  # add an actor to a role
  def add_person( name, what, player, prefix )
    player = uniq_player( player, prefix, name )
    return player if player.casecmp( 'none' ).zero?

    add_role_collection( name, what, player )
    add( 'Actor', player, name )
    if what == 'voice'
      if last_role( name, 'player' ) != player
        @timeframe.add( 'Actor', player )
        @timeframe.add_wiki_actor_for( player, name )
      end
    else
      @timeframe.add( 'Actor', player )
      @timeframe.add_wiki_actor_for( player, name )
    end
    @timeframe.add_list_text(
      'Role', 'Pers+', name, [ [ role( name ), what ], actor( player ) ]
    )
    @timeframe.add_list_text(
      'Actor', 'Pers+', player, [ [ role( name ), what ], actor( player ) ]
    )
    player
  end

  # add a hands to a role
  def add_hands( name, hands )
    # p [ 'add_hands', name, hands ]
    uhands = []
    hands.each do |player|
      player = uniq_player( player, 'Hands', name )
      next if player.casecmp( 'none' ).zero?

      uhands.push( player )
      add( 'Actor', player, name )
      @timeframe.add( 'Actor', player )
      @timeframe.add_wiki_actor_for( player, name )
      @timeframe.add_list_text(
        'Role', 'Pers+', name, [ [ role( name ), 'hands' ], actor( player ) ]
      )
      @timeframe.add_list_text(
        'Actor', 'Pers+', player, [ [ role( name ), 'hands' ], actor( player ) ]
      )
    end
    add_role_collection( name, 'hands', uhands )
    uhands
  end

  # add a voice to a role
  def add_voice( name, voice )
    add_person( name, 'voice', voice, 'Actor' )
  end

  # add a puppet to a role
  def add_puppet( name, puppet )
    puppet = uniq_player( puppet, 'Puppet', name )
    return puppet if puppet.casecmp( 'none' ).zero?

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

  # add a clothing to a role
  def add_clothing( name, clothing )
    clothing = uniq_player( clothing, 'Costume', name )
    return clothing if clothing.casecmp( 'none' ).zero?

    add( 'role_costumes', name, clothing )
    add( 'Costume', clothing, name )
    @timeframe.add( 'Costume', clothing )
    @timeframe.add_list_text( 'Role', 'Clth+', name, [ name, clothing ] )
    puppet = @collection[ 'role_puppets' ][ name ]
    @timeframe.add_list_text(
      'Puppet', 'Clth+', puppet, [ name, clothing ]
    )
    @timeframe.add_list_text(
      'Costume', 'Clth+', clothing, [ name, clothing ]
    )
    clothing
  end

  # drop a clothing for a role
  def drop_one_clothing( role, puppet, clothing )
    # p [ 'drop_one_clothing', role, puppet, clothing ]
    collection[ 'role_old_costumes' ][ role ] = clothing
    add( 'role_old_costumes', role, clothing )
    @timeframe.add_list_text(
      'Role', 'Clth-', role, [ role( role ), clothing( clothing ) ]
    )
    @timeframe.add_list_text(
      'Costume', 'Clth-', clothing, [ role( role ), clothing( clothing ) ]
    )
    puppet = @collection[ 'role_puppets' ][ role ] if puppet.nil?
    return if puppet.nil?

    @timeframe.add_list_text(
      'Puppet', 'Clth-', puppet, [ role( role ), clothing( clothing ) ]
    )
  end

  # save a role with all actors, puppet and clothing
  def store_role( name, list )
    player, hands, voice, puppet, clothing = list
    voice = voice.nil? ? player : voice
    hands = hands.nil? ? player : hands
    add_item(
      'Role', name,
      player: player, hands: hands, voice: voice,
      puppet: puppet, clothing: clothing
    )
    add_item( 'Actor', player, role: name, player: true ) \
      unless player.casecmp( 'none' ).zero?
    add_item( 'Actor', voice, role: name, voice: true ) \
      unless voice.casecmp( 'none' ).zero?
    hands.each do |hand|
      next if hand.casecmp( 'none' ).zero?

      add_item( 'Actor', hand, role: name, hands: true )
    end
    add_item( 'Puppet', puppet, role: name, clothing: clothing )
    return if clothing.nil?

    add_item( 'Costume', clothing, role: name, puppet: puppet )
  end

  # add a role
  def add_role( name, list )
    # p [ 'add_role', name, list ]
    count( 'Role', name )
    #add( 'Role', name, {} )
    @timeframe.add( 'Role', name )
    player, hands, voice, puppet, clothing = list
    uplayer = add_person( name, 'player', player, 'Actor' )
    voice = voice.nil? ? uplayer : voice
    uvoice = add_voice( name, voice )
    hands = hands.nil? ? [ uplayer ] : hands
    uhands = add_hands( name, hands )
    upuppet = add_puppet( name, puppet )
    uclothing = add_clothing( name, clothing )
    uhands.each do |uhand|
      @timeframe.add_hash(
        'puppet_plays', upuppet, [ name, uplayer, uhand, uvoice, uclothing ]
      )
    end
    store_role( name, [ uplayer, uhands, uvoice, upuppet, uclothing ] )
  end

  # add a backdrop at given position
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
#   Report.puppet_costumes
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
#   Report.list_builds2
#   Report.hand_props_actors( scene, prop_type )
#   Report.list_hand_props
#   Report.people_assignments( listname, person )
#   Report.merge_merge_plain( assignments, hactor, action )
#   Report.merge_assignments( assignments, actor, action )
#   Report.merge_assignments_role( assignments, actor, entry )
#   Report.list_people_assignments
#   Report.list_people_exports
#   Report.list_people_people( key )
#   Report.list_cast
#   Report.table_caption( title )
#   Report.html_table( table, title, tag = '' )
#   Report.html_table_r( table, title, tag = '', head_row = nil )
#   Report.html_list( caption, title, hash, seperator = '</td><td>' )
#   Report.html_list_hash( title, hash, seperator = '</td><td>' )
#   Report.rows( timeframe, key )
#   Report.columns_and_rows( key )
#   Report.puts_timeframe_table( title, key )
#   Report.find_backdrop( scene, prop )
#   Report.find_scene_backdrops( scene, prop )
#   Report.puts_backdrops_table( title, key )
#   Report.puppet_play_full( title, key )
#   Report.puppet_use_data( key )
#   Report.puppet_use_costumes( key )
#   Report.puts_use_table( title, table )
#   Report.puts_tables
#   Report.puppet_image( puppet )
#   Report.save_html( filename )
class Report
  # map item table names to item type
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
    'Costumes' => 'Costume',
    'Personal props' => 'PersonalProp',
    'Hand props' => 'HandProp',
    'Tech props' => 'TechProp',
    'Special effect' => 'SpecialEffect',
    'Todos' => 'Todo'
  }.freeze
  # map extra table names to item type
  REPORT_TABLES = {
    'Backdrops' => 'Backdrop',
    'Roles' => 'Role',
    'People' => 'Actor',
    'Puppets' => 'Puppet',
    'Puppet plays' => 'Puppet',
    'Puppet use' => 'Puppet',
    'Puppet costumes' => 'Puppet',
    # 'Builds' => nil,
    'Todo List' => nil,
    'Hands' => 'Actor',
    'Assignments' => 'Actor',
    'People people' => 'Actor',
    'People export' => 'Actor',
    'Cast of Characters' => 'Actor'
  }.freeze
  # map build table names to item type
  REPORT_BUILDS = {
    'Backdrop panel' => 'Backdrop',
    'Costume' => 'Costume',
    'Effect' => 'Effect',
    'Front prop' => 'FrontProp',
    'Second level prop' => 'SecondLevelProp',
    'Personal prop' => 'PersonalProp',
    'Puppets' => 'Puppet',
    'Hand prop' => 'HandProp',
    'Tech prop' => 'TechProp',
    'Special effect' => 'SpecialEffect'
  }.freeze
  # map hands table names to item type
  REPORT_HANDS = {
    'Effect' => 'Effect',
    'Front prop' => 'FrontProp',
    'Second level prop' => 'SecondLevelProp',
    'Personal prop' => 'PersonalProp',
    'Hand prop' => 'HandProp',
    'Tech prop' => 'TechProp',
    'Special effect' => 'SpecialEffect'
  }.freeze
  # list of item type
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
    'Costume',
    'PersonalProp',
    'HandProp',
    'TechProp',
    'SpecialEffect',
    'Todo'
  ].freeze
  # list of references to ignore
  ITEM_IGNORE = [
    'player',
    'hands',
    'voice'
  ].freeze

  # table of puppet costumes
  attr_accessor :puppet_costumes
  # table of todo list
  attr_accessor :todo_list
  # table of assignment list
  attr_accessor :assignment_list

  # create a report
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

  # add a line to the report
  def put_html( line )
    @html_report << line
  end

  # add a line with linefeed to the report
  def puts_html( line )
    @html_report << line
    @html_report << "\n"
  end

  # find an item of given type
  def find_item_of_type( name, type )
    if @store.items.key?( type )
      return @store.items[ type ][ name ] if @store.items[ type ].key?( name )
    end

    pp [ 'find_item_of_type not found', name, type ]
    nil
  end

  # find an item of any type
  def find_item( name )
    return nil if ITEM_LIST.include?( name )
    return nil if ITEM_IGNORE.include?( name )
    return nil if REPORT_BUILDS.key?( name )

    ITEM_LIST.each do |key|
      next unless @store.items.key?( key )

      return @store.items[ key ][ name ] if @store.items[ key ].key?( name )
    end

    pp [ 'find_item not found', name ] unless $debug.zero?
    nil
  end

  # get the ref attribute of an item
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

  # create an internal html link
  def to_html( ref, name )
    "<a href=\"##{ref}\">#{html_escape( name )}</a>"
  end

  # create html output or an internal html link to the item
  def html_object_name( name )
    if name.respond_to?( :key? )
      return to_html( name[ :ref ], name[ :name ] ) if name.key?( :ref )
      return html_escape( name[ :name ] ) if name[ :name ].casecmp( 'none' ).zero?

      obj = find_item_of_type( name[ :name ], name[ :type ] )
      return to_html( obj[ :ref ], name[ :name ] )
    end

    obj = find_item( name )
    return to_html( obj[ :ref ], name ) unless obj.nil?

    html_escape( name )
  end

  # print a html line
  def html_p( arr )
    loc = "loc#{@qscript.lines}_2"
    key = arr.shift
    text = "&nbsp;#{key}"
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

  # merge key, name and text, then print a html line
  def puts2_key( key, name, text = nil )
    if text.nil?
      html_p( [ key, name ] )
    else
      html_p( [ key, name, text ] )
    end
  end

  # merge key. token, name and text, then print a html line
  def puts2_key_token( key, token, name, text = nil )
    puts2_key( key + token, name, text )
  end

  # capitalize and strip a text to an identifier
  def capitalize( item )
    item.tr( ' ', '_' ).gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase ).delete( '_"' )
  end

  # generate an identifier for a table
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

  # generate a list entry for an item
  def html_li_ref_item( ref, item )
    "<li>#{to_html( ref, item )}</li>\n"
  end

  # generate a paragraph with an anchor for an item
  def html_li_p_ref_item( ref, item )
    if $compat
      "<li class=\"p\" id=\"#{ref}\">#{item}"
    else
      "<li class=\"p\" id=\"#{ref}\">#{item}\n"
    end
  end

  # generate a paragraph with an link to the scene
  def html_li_p2_ref_item( ref, scene, key, item )
    "<p><a href=\"##{ref}\">#{scene}</a>: #{key} #{item}</p>\n"
  end

  # generate a list entry for an item
  def html_li_item( item )
    html_li_ref_item( href( item ), item )
  end

  # generate a list head
  def html_u_ref_item( ref, item )
    "<u id=\"#{ref}\">#{item}</u>"
  end

  # generate a list head
  def html_u_item( item )
    html_u_ref_item( href( item ), item )
  end

  # add a list entry to html_head and html_report
  def add_head( item )
    @html_head << html_li_item( item )
    @html_report << "#{html_u_item( item )}\n"
  end

  # add a list entry to html_script and html_report
  def add_script( item )
    @html_script << html_li_item( item )
    @html_report << "#{html_u_item( item )}<br/>\n"
  end

  # list titles of timeframes and quote them
  def list_title_quoted( list, prefix )
    return if list.nil?

    count = 0
    @html_report << '<ul>'
    sorted = nat_sort_list( list )
    sorted.each do |prop|
      text = "#{prefix} #{quoted_noescape( prop )}"
      ref = "timeframeC#{count}"
      count += 1
      @html_report << "#{html_li_ref_item( ref, text )}\n"
    end
    @html_report << "</ul><br/>\n"
  end

  # list prop names and quote them
  def list_quoted( list, prefix, type )
    return if list.nil?

    seen = {}
    sorted = nat_sort_list( list )
    sorted.each do |prop|
      next if seen.key?( prop )

      seen[ prop ] = true
      ref = html_object_ref( tname( type, prop ) )
      text = "#{prefix} #{html_escape( quoted_noescape( prop ) )}"
      @html_report << "#{html_li_ref_item( ref, text )}\n"
    end
  end

  # generate a HTML list of items
  def make_unsorted( list, type )
    out = ''
    return out if list.nil?

    list.each do |prop, _count|
      ref =
        if type.nil?
          "tab#{capitalize( prop )}"
        else
          html_object_ref( tname( type, prop ) )
        end
      out << "#{html_li_ref_item( ref, html_escape( prop ) )}\n"
    end
    out
  end

  # add a HTML list of items to the report
  def list_unsorted( list, type )
    return if list.nil?

    @html_report << make_unsorted( list, type )
  end

  # add a HTML list as sorted to the report
  def list( hash, type )
    sorted = nat_sort_hash( hash )
    list_unsorted( sorted, type )
  end

  # add the catalog to the report
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
        "#{html_u_ref_item( "catalog#{count}", "Catalog: #{key}" )}\n<ul>"
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
          html_item << " #{html_object_name( item )}"
          next
        end

        if item.respond_to?( :shift )
          arr = item.dup
          html_item << html_object_name( arr.shift.dup )
          arr.each do |sub|
            html_item << ".#{html_object_name( sub )}"
          end
          next
        end

        html_item << " #{html_object_name( item )}"
      end
    else
      html_item << html_object_name( hash[ :text ] )
    end
    html_item
  end

  def person_scene_count( scene, type, name )
    listname = "#{type}_sum_spoken"
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
            "<p>#{to_html( refa, h[ :scene ] )}: #{text}</p>\n"
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
    return 'Costume' if title == 'Costumes'

    title.sub( /s$/, '' )
  end

  def person_count( listname, name )
    return 0 unless @store.timeframe.timeframes_lines.key?( listname )
    return 0 unless @store.timeframe.timeframes_lines[ listname ].key?( name )

    @store.timeframe.timeframes_lines[ listname ][ name ].size
  end

  def person_spoken_count( type, name )
    listname = "#{type}_sum_spoken"
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
      item = "Timeframe contents #{to_html( refa, quoted( scene ) )}"
      @html_report << "#{html_u_ref_item( refu, item )}\n"
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

  def list_builds2
    builds = {}
    @store.timeframe.timeframes.each_key do |scene|
      REPORT_BUILDS.each_pair do |name, type|
        next unless @store.timeframe.timeframes[ scene ].key?( type )

        @store.timeframe.timeframes[ scene ][ type ].each do |item|
	  key = [ type, item ]
          scenes =
            if builds.key?( key )
              next if builds[ key ].first.include?( scene )

              builds[ key ].first.push( scene )
            else
              [ scene ]
            end
          builds[ key ] = [ scenes, name ]
        end
      end
    end
    result = [ TODO_LIST_HEADER ]
    builds2 = builds.sort_by do |item, data|
      [ data.last, data.first, item.last.downcase ]
    end
    builds2.each do |row|
      scenes = row.last.first.map { |s| s.sub( /^Scene /, '' ) }
      result.push( [ scenes.join( ', ' ), row.last.last, row.first.last ] )
    end
    @todo_list = result
    result
  end

  def search_hands( scene, prop )
    scene_props_hands = @store.timeframe.timeframes[ scene ][ 'props_hands' ]
    return scene_props_hands[ prop ] if scene_props_hands.key?( prop )

    kprop = prop.downcase
    return scene_props_hands[ kprop ] if scene_props_hands.key?( kprop )

    # p [ 'search_hands', scene, prop ]
    # pp scene_props_hands
    []
  end

  def hand_props_actors( scene, prop_type )
    props = @store.timeframe.timeframes[ scene ][ prop_type ]
    return nil if props.nil?

    seen = {}
    list = []
    props.each do |prop|
      next if seen.key?( prop )

      seen[ prop ] = true
      hands = search_hands( scene, prop )
      hands.push( '?' ) if hands.empty?
      act = hands.join( ', ' )
      next if act.casecmp( 'none' ).zero?

      # p [ 'hand_props_actors', scene, prop_type, prop, act ]
      htmlhands = hands.dup.map do |hand|
        if hand == '?'
          hand
        else
          html_object_name( actor( hand ) )
        end
      end
      hprop = html_object_name( tname( prop_type, prop ) )
      # list.push( [ html_escape( prop ), html_object_name( actor( act ) ) ] )
      list.push( [ hprop, htmlhands.join( ', ' ) ] )
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
        task = "#{person}.#{line[ :text ][ 0 ][ 0 ]}"
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

  def merge_merge_plain( assignments, hactor, action )
    if assignments.key?( action )
      assignments[ action ].push( hactor ) \
        unless assignments[ action ].include?( hactor )
    else
      assignments[ action ] = [ hactor ]
    end
  end

  def merge_assignments( assignments, actor, action )
    hactor = actor( actor )
    merge_merge_plain( assignments, hactor, action )
  end

  def merge_builder( assignments, actor, action )
    if assignments.key?( action ) 
      assignments[ action ].push( actor ) \
        unless assignments[ action ].include?( actor )
    else  
      assignments[ action ] = [ actor ]
    end
  end   

  def merge_assignments_role( assignments, actor, entry )
    if entry.key?( :player )
      action = [ entry[ :role ], 'player' ]
      merge_assignments( assignments, actor, action )
      return
    end

    if entry.key?( :hands )
      action = [ entry[ :role ], 'hands' ]
      merge_assignments( assignments, actor, action )
      return
    end

    return unless entry.key?( :voice )

    action = [ entry[ :role ], 'voice' ]
    merge_assignments( assignments, actor, action )
  end

  def list_people_assignments
    assignments = {}
    @store.items[ 'Actor' ].each_pair do |actor, h|
      next if actor.casecmp( 'none' ).zero?

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

  def merge_export( assignments, actor, action )
    hactor = actor( actor )
    if assignments.key?( action )
      assignments[ action ].push( hactor ) \
        unless assignments[ action ].include?( hactor )
    else
      assignments[ action ] = [ hactor ]
    end
  end

  def merge_export_role( assignments, actor, entry )
    if entry.key?( :player )
      action = [ entry[ :role ], 'player' ]
      merge_export( assignments, actor, action )
      return
    end

    if entry.key?( :hands )
      action = [ entry[ :role ], 'hands' ]
      merge_export( assignments, actor, action )
      return
    end

    return unless entry.key?( :voice )

    action = [ entry[ :role ], 'voice' ]
    merge_export( assignments, actor, action )
  end

  def list_people_exports
    assignments = {}
    @store.items[ 'Actor' ].each_pair do |actor, h|
      next if actor.casecmp( 'none' ).zero?

      h[ :list ].each do |entry|
        if entry.key?( :role )
          merge_export_role( assignments, actor, entry )
          next
        end

        next unless entry.key?( :stagehand )

        if entry.key?( :prop )
          action = entry[ :prop ]
          merge_export( assignments, actor, action )
          next
        end

        if entry.key?( :effect )
          action = entry[ :effect ]
          merge_export( assignments, actor, action )
        end
      end
    end
    exports = {}
    assignments.each_pair do |action, actors|
      exports[ action ] = [ 'X' ].concat( actors )
    end
    exports
  end

  def list_item_keys( key )
    list = []
    @store.items[ key ].each_key do |actor|
      next if actor.casecmp( 'none' ).zero?

      list.push( actor )
    end
    list
  end

  def check_people_people( key, actor1, actor2 )
    @store.timeframe.timeframes.each_pair do |_scene, hash|
      next unless hash.key?( key )

      return nil if hash[ key ].include?( actor1 ) &&
                    hash[ key ].include?( actor2 )
    end
    'f'
  end

  def list_people_people( key )
    key_list = list_item_keys( key )
    remove_list = []
    columns = [ nil ]
    key_list.each do |actor2|
      next unless actor2.include?( '_' )

      columns.push( actor2 )
    end
    table = [ columns ]
    key_list.each do |actor|
      next if actor.include?( '_' )

      row = [ actor ]
      key_list.each do |actor2|
        next unless actor2.include?( '_' )

        row.push( check_people_people( key, actor, actor2 ) )
      end
      table.push( row )
    end
    table
  end

  def merge_cast( cast, actor, action )
    return if actor.casecmp( 'none' ).zero?

    merge_assignments( cast, actor, action )
  end

  def list_cast
    cast = {}
    @store.items[ 'Role' ].each_pair do |role, h|
      next if role.casecmp( 'none' ).zero?

      h[ :list ].each do |entry|
        if entry.key?( :player )
          merge_cast( cast, entry[ :player ], role )
        end
        if entry.key?( :hands )
          entry[ :hands ].each do |hand|
            merge_cast( cast, hand, role )
          end
        end
        if entry.key?( :voice )
          merge_cast( cast, entry[ :voice ], role )
        end
      end
    end

    @store.items[ 'Puppet' ].each_pair do |puppet, h|
      next unless $puppet_builders.key?( puppet )

      builder = $puppet_builders[ puppet ]
      merge_merge_plain( cast, builder, 'Puppet Builders' )
    end
    cast
  end

  def table_caption( title )
    href = "tab#{capitalize( title )}"
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
          html << column.to_s unless column.nil?
        end
        html << '</td>'
      end
      html << "</tr>\n"
    end
    html << "</table><br/>\n"
    html
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
        if column.respond_to?( :key? )
          html << '<td class="x">'
          html << html_object_name( column )
        else
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
      end
      first_row = false
      html << "</tr>\n"
    end
    html << "</table><br/>\n"
    html << tag.sub( '<', '</' )
    html
  end

  def html_list( caption, title, hash, seperator = '</td><td>' )
    html = table_caption( "#{caption} #{title}" )
    html << "\n<table>"
    hash.each_pair do |item, h2|
      next if h2.nil?

      seen = {}
      h2.each do |text|
        next if text.nil?
        next if seen.key?( text )

        seen[ text ] = true
        html << '<tr><td>'
        if item.respond_to?( :shift )
          subs = item.dup.map { |i| html_object_name( i ) }
          html << subs.join( '.' )
        else
          html << html_object_name( item )
        end
        html << seperator
        html << html_object_name( text )
        html << "</td></tr>\n"
      end
    end
    html << "</table><br/>\n"
    html
  end

  def html_list_hash( title, hash, seperator = '</td><td>' )
    html = table_caption( title )
    html << "\n<table>"
    hash.each_pair do |item, h2|
      next if h2.nil?

      html << '<tr><td>'
      if item.respond_to?( :shift )
        subs = item.dup.map { |i| html_object_name( i ) }
        html << subs.join( '.' )
      else
        html << html_object_name( item )
      end
      html << '</td><td>'
      html << h2.map { |text| html_object_name( text ) }.join( seperator )
      html << "</td></tr>\n"
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
    @html_report <<
      if $compat
        "#{html_table( table, title, '<ul><li>' )}</li></ul>"
      else
        html_table( table, title )
      end
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
        val << "/#{hash[ 'puppet_plays' ][ puppet ][ 2 ]}" \
          if hash[ 'puppet_plays' ][ puppet ][ 2 ] \
          != hash[ 'puppet_plays' ][ puppet ][ 1 ]
        val << " (#{hash[ 'puppet_plays' ][ puppet ][ 0 ]})"
        row.push( val )
      end
      table.push( row )
    end
    @html_report << html_table( table, title )
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
    table
  end

  def puppet_use_costumes( key )
    table, puppets = columns_and_rows( key )
    table[ 0 ].insert( 1, 'Image' )
    puppets.each do |puppet|
      actors = []
      row = [ puppet, puppet_image( puppet ) ]
      @store.timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( 'puppet_plays' )

        unless hash[ 'puppet_plays' ].key?( puppet )
          row.push( nil )
          next
        end
        role = hash[ 'puppet_plays' ][ puppet ][ 0 ]
        row[ 0 ] = "#{role} (#{puppet})"
        actors.push( hash[ 'puppet_plays' ][ puppet ][ 1 ] )
        row.push( hash[ 'puppet_plays' ][ puppet ][ 4 ] )
      end
      actors.uniq!
      row[ 0 ] << " (#{actors.join( ', ' )})"
      table.push( row )
    end
    @puppet_costumes = table
    table
  end

  def puts_use_table( title, table )
    @html_report << html_table( table, title )
  end

  def puts_builds2_table( title )
    builds = list_builds2
    @html_report << html_table( builds, title )
  end

  def puts_hands_table( title )
    @html_report << table_caption( title )
    @html_report << "<br/>\n"
    hprops = list_hand_props
    hprops.each_pair do |key, h|
      @html_report << html_table( h, "Hands #{key}" )
    end
  end

  def puts_assignments_table( title )
    assignments = list_people_assignments
    @html_report << html_list_hash( title, assignments, ', ' )
  end

  def puts_people_people_table( title, key )
    @html_report << table_caption( 'Disjunct' )
    @html_report << '<br>
<p>legend for table below:<br>
empty = actor busy<br>
f = actor free<br>
</p><br>
'
    people_people = list_people_people( key )
    @html_report << html_table_r( people_people, title, '' )
  end

  def find_export_role( type )
    actions = []
    @store.collection[ 'Role' ].each_pair do |name, entry|
      entry.each_pair do |_key, val|
        case type
        when 'Role (Voice)'
          next unless entry.key?( 'voice' )

          actions.push( [ type, "#{name}.player", val.join( ', ' ) ] )
          break
        when 'Role (No Voice)'
          next if entry.key?( 'voice' )

          actions.push( [ type, "#{name}.player", val.join( ', ' ) ] )
          break
        when 'Role (Hand)'
          if val.respond_to?( :shift )
            next if val.empty?

            val.each do |hand|
              next if entry[ 'player' ] == hand

              actions.push( [ type, "#{name}.hands", hand ] )
            end
          else
            next if entry[ 'player' ] == val

            actions.push( [ type, "#{name}.hands", val ] )
          end
          break
        end
      end
    end
    actions
  end

  def columns_and_rows2( key )
    rows = []
    columns = [ 'Type', 'Name' ]
    [ 'Role (Voice)', 'Role (No Voice)', 'Role (Hand)' ].each do |type|
      list = find_export_role( type )
      list.each do |entry|
        rows.push( entry )
      end
    end
    @store.timeframe.timeframes.each_pair do |scene, hash|
      next unless hash.key?( key )

      columns.push( scene )
    end
    seen = {}
    [
      'HandProp', 'SpecialEffect',
      'FrontProp', 'SecondLevelProp', 'TechProp', 'PersonalProp'
    ].each do |type|
      @store.timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( key )
        next unless hash.key?( type )

        hash[ type ].each do |name|
          next if seen.key?( name )
          next unless hash[ 'props_hands' ].key?( name )

          act = hash[ 'props_hands' ][ name ].join( ', ' )
          next if act.casecmp( 'none' ).zero?

          rows.push( [ type, name, act ] )
          seen[ name ] = true
        end
      end
    end
    columns.push( 'People' )
    [ [ columns ], rows ]
  end

  def puts_people_export( title, key )
    table, rows = columns_and_rows2( key )
    rows.each do |rowinfo|
      type = rowinfo[ 0 ]
      row = [ type ]
      action = rowinfo[ 1 ]
      row.push( action )
      @store.timeframe.timeframes.each_pair do |_scene, hash|
        next unless hash.key?( key )

        unless hash.key?( type )
          case type
          when 'Role (Voice)', 'Role (No Voice)', 'Role (Hand)'
            type = 'Role'
            action = action.split( '.' ).first
          when 'HandProp', 'SpecialEffect',
               'FrontProp', 'SecondLevelProp', 'TechProp', 'PersonalProp'
            type = 'props_hands'
          else
            next
          end
        end

        unless hash[ type ].include?( action )
          row.push( nil )
          next
        end
        row.push( 'x' )
      end
      row.push( rowinfo[ 2 ] )
      table.push( row )
    end
    @assignment_list = table
    @html_report << html_table_r( table, title )
    table
  end

  def puts_cast_table( title )
    cast = list_cast
    @html_report << html_list_hash( title, cast, ', ' )
  end

  def puts_tables
    add_head( 'Tables' )
    tables = make_unsorted( REPORT_TABLES.keys, nil )
    @html_head << tables
    @html_report << '<ul>'
    @html_report << tables
    @html_report << "</ul><br/>\n"
    REPORT_TABLES.each_pair do |title, type|
      case title
      when 'Backdrops'
        puts_backdrops_table( title, type )
      when 'Puppet plays'
        puppet_play_full( title, type )
      when 'Puppet use'
        puts_use_table( title, puppet_use_data( type ) )
      when 'Puppet costumes'
        puts_use_table( title, puppet_use_costumes( type ) )
      when 'Todo List'
        puts_builds2_table( title )
      when 'Hands'
        puts_hands_table( title )
      when 'Assignments'
        puts_assignments_table( title )
      when 'People people'
        puts_people_people_table( title, type )
      when 'People export'
        puts_people_export( title, type )
      when 'Cast of Characters'
        puts_cast_table( title )
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
      "#{@html_head}#{@html_script}#{@html_report}#{extra}</body></html>\n"
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
#   Parser.add_single_backdrop( position, text )
#   Parser.parse_single_backdrop( line )
#   Parser.list_one_person( name )
#   Parser.drop_clothing( name )
#   Parser.drop_person_props( name )
#   Parser.drop_puppet( name )
#   Parser.drop_person( name )
#   Parser.list_one_person2( name )
#   Parser.parse_single_puppet( line )
#   Parser.suffix_props( line, key )
#   Parser.new_stagehand( prop )
#   Parser.tagged_props( line, key )
#   Parser.header_single_prop( prop, hands, names )
#   Parser.parse_single_prop( line, key, type )
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
#   Parser.add_scene_prop( prop, tag )
#   Parser.collect_single_prop( prop, names, tag )
#   Parser.collect_just_prop( prop, names, tag )
#   Parser.collect_owned_prop( prop, owner, names, tag )
#   Parser.search_simple_props( line, suffix, tag )
#   Parser.collect_simple_props( line, suffix, tag, names )
#   Parser.search_handprop( line )
#   Parser.collect_handprop( line, owner )
#   Parser.collect_backdrop( line )
#   Parser.parse_stagehand( name, text, qscriptkey, reportkey )
#   Parser.add_stagehands( hands, text )
#   Parser.add_note( line )
#   Parser.add_todo( line )
#   Parser.add_error_note( line )
#   Parser.strip_none( name )
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
#   Parser.replace_text( line, filename )
#   Parser.close_scene
#   Parser.print_unknown_line( line )
#   Parser.parse_section( line )
#   Parser.get_stagehand( kprop )
#   Parser.parse_hand( text )
#   Parser.parse_spot( text )
#   Parser.parse_fog( text )
#   Parser.parse_curtain( line )
#   Parser.intro_line( line )
#   Parser.parse_script_line( line )
#   Parser.parse_lines( filename, lines, version )
class Parser
  # map simple wiki tag to qscript
  SIMPLE_MAP = {
    '%AMB%' => [ 'ambience', 'Ambie', 'Ambience' ],
    '%MUS%' => [ 'ambience', 'Ambie', 'Ambience' ],
    '%SND%' => [ 'sound', 'Sound', 'Sound' ],
    '%PRE%' => [ 'sound', 'Sound', 'Sound' ],
    '%VID%' => [ 'video', 'Video', 'Video' ],
    '%LIG%' => [ 'light', 'Light', 'Light' ],
    '%ATT%' => [ 'note', 'Note' ],
    # '%MIX%' => [ 'note', 'Note' ],
    '###' => [ 'note', 'Note' ]
  }.freeze
  # map wiki tag with role to qscript
  ROLE_MAP = {
    '%ACT%' => [ 'action', 'Actio' ]
  }.freeze
  # names for prop types
  PROP_NAMES = {
    'FrontProp' => [ 'FrontProp', 'frontProp', 'FroP' ],
    'SecondLevelProp' => [ 'SecondLevelProp', 'secondLevelProp', 'SecP' ],
    'PersonalProp' => [ 'PersonalProp', 'personalProp', 'PerP' ],
    'HandProp' => [ 'HandProp', 'handProp', 'HanP' ],
    'TechProp' => [ 'TechProp', 'techProp', 'TecP' ],
    'SpecialEffect' => [ 'SpecialEffect', 'techProp', 'SfxP' ]
  }.freeze
  # names for FrontProp items
  FRONTPROP_NAMES = PROP_NAMES[ 'FrontProp' ].freeze
  # names for SecondLevelProp items
  SECONDPROP_NAMES = PROP_NAMES[ 'SecondLevelProp' ].freeze
  # names for PersonalProp items
  PERSPROP_NAMES = PROP_NAMES[ 'PersonalProp' ].freeze
  # names for HandProp items
  HANDPROP_NAMES = PROP_NAMES[ 'HandProp' ].freeze
  # names for TechProp PROP_NAMES
  TECHPROP_NAMES = PROP_NAMES[ 'TechProp' ].freeze
  # names for Special effect PROP_NAMES
  SFXPROP_NAMES = PROP_NAMES[ 'SpecialEffect' ].freeze
  # name suffix for backdrops
  BACKDROP_FIELDS = [ 'Left', 'Middle', 'Right' ].freeze
  # map extra <tag> to prop type
  ITEM_TAGS = {
    'fp' => 'FrontProp',
    'pr' => 'FrontProp', # Backward compatible
    'sp' => 'SecondLevelProp',
    '2nd' => 'SecondLevelProp', # Backward compatible
    'pp' => 'PersonalProp',
    'hp' => 'HandProp',
    'tec' => 'TechProp',
    'sfx' => 'SpecialEffect'
  }.freeze
  # Name for Prop to do %FOG%
  FOG_STAGEHEAND = 'Fog'.freeze
  # Lis of section names
  SECTION_NAMES = [
    'Stage setup', 'Backdrop', 'On 2nd rail', 'On playrail',
    'Hand props', 'Special effects', 'PreRec', 'Role'
  ].freeze

  # store object
  attr_reader :store
  # qscript object
  attr_reader :qscript
  # report object
  attr_reader :report

  def initialize( store, qscript, report )
    @store = store
    @qscript = qscript
    @report = report
    @backdrops = []
    @scene_props = {}
    @scene_props_hands = {}
    @scene_props_roles = {}
    @scene_props_names = {}
    @scene_props_fix = {}
    @setting = ''
    @roles_config = nil
  end

  def make_title( name )
    out = name.slice( /^[a-z]*/ ).capitalize
    out << 'Scene' if out == ''
    out << ' '
    rest = name.sub( /^[a-z]*/, '' )
    out << rest[ 0 ]
    out << '-'
    out << rest[ 1 ]
    out
  end

  def parse_title( filename )
    name = filename.sub( /.*\//, '' )
    @title = make_title( name )
    etitle = quoted( @title )
    @store.timeframe.scene( @title, filename )
    @roles_config = RolesConfig.new( @title, ROLES_CONFIG_FILE )
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
      add_todo( "same curtain state: #{text}" ) \
        if text == @store.collection[ 'curtain' ]
    else
      add_todo( "unknown curtain state: #{text}" )
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

  def new_backdrop( _position, text )
    # text.tr( ' ', '_' ).
    # gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase ) + ' ' + position
    text.tr( ' ', '_' ).gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase )
  end

  def add_single_backdrop( position, text )
    return if text.nil?

    text = new_backdrop( position, @title ) if text == ''
    @backdrops.push( @store.add_backdrop( position, text ) )
    return unless position == 'Right'

    # last Backdrop
    add_backdrop_list( @backdrops )
    @backdrops = []
  end

  def parse_single_backdrop( line )
    position, text = line.split( ': ', 2 )
    if text.nil?
      position, text = line.split( ':', 2 )
      if text.nil?
        add_error_note( "Unable to parse backdrop: #{line}" )
      else
        add_error_note( "Backdrop needs space after colon: #{line}" )
      end
    end
    add_single_backdrop( position, text.strip )
  end

  def list_one_person( name )
    @qscript.puts ''
pp @store.current_roles[ name ]
    @store.current_roles[ name ].each_pair do |key, val|
pp [ :list_one_person, key, val ]
      # p [ 'list_one_person', name, key, val ]
      if val.respond_to?( :shift )
        next if val.empty?

        @qscript.puts "\tperson+ \"#{name}\".#{key} \"#{val.join( ', ' )}\""
        val.each do |hand|
          @report.html_p( [ 'Pers+', [ role( name ), key ], actor( hand ) ] )
        end
      else
        next if val.casecmp( 'none' ).zero?

        @qscript.puts "\tperson+ \"#{name}\".#{key} \"#{val}\""
        @report.html_p( [ 'Pers+', [ role( name ), key ], actor( val ) ] )
      end
    end
    val = @store.collection[ 'role_puppets' ][ name ]
    unless val.nil?
      # p [ 'list_one_person', name, val ]
      @qscript.puts_key( 'puppet+', name, val )
      @report.puts2_key( 'Pupp+', role( name ), puppet( val ) )
    end
    clothing = @store.collection[ 'role_costumes' ][ name ]
    return if clothing.nil?

    @qscript.puts_key( 'clothing+', name, clothing )
    @report.puts2_key( 'Clth+', role( name ), clothing( clothing ) )
  end

  def drop_clothing( name )
    val = @store.collection[ 'role_costumes' ][ name ]
    unless val.nil?
      @qscript.puts_key( 'clothing-', name, val )
      @report.puts2_key( 'Clth-', role( name ), clothing( val ) )
      @store.drop_one_clothing( name, nil, val )
    end
    @store.collection[ 'role_old_costumes' ][ name ] = nil
  end

  def drop_person_props( name )
    return unless @store.collection[ 'owned_props' ].key?( name )

    @store.collection[ 'owned_props' ][ name ].each do |h|
      prop = h[ :name ]
      next if prop.nil?

      # remove_owned_prop( prop, name, h[ :names ] )
      storekey, qscriptkey, reportkey = h[ :names ]
      tprop = @store.items[ storekey ][ prop ][ :name ]
      @qscript.puts_key( "#{qscriptkey}-", name, tprop )
      @report.puts2_key(
        "#{reportkey}-", role( name ), tname( storekey, prop )
      )
      @store.collection[ "#{storekey}_owner" ][ prop ] = nil
      @store.timeframe.add_list_text(
        storekey, "#{reportkey}-", prop,
        [ role( name ), tname( storekey, prop ) ]
      )
      @store.timeframe.add_list_text(
        'Role', "#{reportkey}-", name,
        [ role( name ), tname( storekey, prop ) ]
      )
      next if reportkey == 'HanP'

      puppet = @store.collection[ 'role_puppets' ][ name ]
      @store.timeframe.add_list_text(
        'Puppet', "#{reportkey}-", puppet,
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

  def drop_person_player( name, what, players )
    if players.respond_to?( :shift )
      return if players.empty?
    else
      return if players.casecmp( 'none' ).zero?
    end

    @qscript.puts "\tperson- \"#{name}\".#{what}"
    @report.html_p( [ 'Pers-', [ name, what ] ] )
    @store.timeframe.add_list_text(
      'Role', 'Pers-', name, [ [ name, what ] ]
    )
    unless players.respond_to?( :shift )
      @store.timeframe.add_list_text(
        'Actor', 'Pers-', players, [ [ name, what ] ]
      )
      return
    end

    players.each do |player|
      next if player.casecmp( 'none' ).zero?

      @store.timeframe.add_list_text(
        'Actor', 'Pers-', player, [ [ name, what ] ]
      )
    end
  end

  def drop_person( name )
    @qscript.puts ''
    drop_person_props( name )
    @store.current_roles[ name ].each_pair do |what, players|
      drop_person_player( name, what, players )
    end
    clothing = @store.collection[ 'role_costumes' ][ name ]
    drop_clothing( name ) unless clothing.nil?
    puppet = @store.collection[ 'role_puppets' ][ name ]
    drop_puppet( name ) unless puppet.nil?
  end

  def list_one_person2( name )
    @qscript.puts ''
    # @store.collection[ 'person' ][ name ].each_pair do |key, val|
    #   @report.puts2_key( 'Pers=', "#{name}.#{key}", val )
    # end
    old_clothing = @store.collection[ 'role_old_costumes' ][ name ]
    return if old_clothing.nil?

    clothing = @store.collection[ 'role_costumes' ][ name ]
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
    @store.collection[ 'role_costumes' ][ name ] = clothing
  end

  def check_role_list( list )
    add_todo( @store.check_actor( list[ 0 ] ) )
    add_todo( @store.check_actor( list[ 1 ] ) )
    add_todo( @store.check_puppet( list[ 0 ], list[ 3 ] ) )
    add_todo( @store.check_clothing( list[ 3 ], list[ 4 ] ) )
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
          @store.collection[ 'role_costumes' ][ role ]
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
        [ player, [ hand ], voice, puppet, clothing ]
      end

    list = merge_role( role, list2 )
    # if list.nil?
    #   @store.add_role( role, list2 )
    #   list_one_person2( role )
    #   return
    # end
    @store.add_role( role, list )
    check_role_list( list )
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

  def header_single_prop( prop, hands, type )
    if type.nil?
      add_todo( "Type of Prop '#{prop}' unknown." )
      return
    end

    kprop = prop.downcase
    @scene_props[ kprop ] = 0
    @scene_props_names[ kprop ] = PROP_NAMES[ type ]
    @scene_props_hands[ kprop ] = hands
    @scene_props_roles[ kprop ] = nil
    @store.add_item( type, kprop, hands: hands, text: prop )
    hands.each do |hand|
      next if hand.casecmp( 'none' ).zero?

      @store.add_item( 'Actor', hand, prop: kprop, stagehand: true )
      reportkey = PROP_NAMES[ type ][ 2 ]
      next if reportkey.nil?

      @store.timeframe.add_list_text(
        'Actor', reportkey, hand, [ actor( hand ), tname( type, kprop ) ]
      )
      @store.timeframe.add_wiki_actor_for( hand, kprop )
    end
  end

  def new_stagehand( prop )
    prop.tr( ' ', '_' ).gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase ) << '_SH'
  end

  def parse_single_prop( line, key, type )
    line.scan( /<#{key}>(#{MATCH_SNAME})<\/#{key}>/i ) do |m|
      next if m.empty?

      m.each do |prop|
        handtext = line.scan( /[(]([^)]*)[)]/ )
        hands =
          if handtext.empty? || hands.size.zero?
            [ new_stagehand( prop ) ]
          else
            p [ 'parse_single_prop', handtext ]
            handtext[ 0 ][ 0 ].split( /, */ )
          end
        p [ 'parse_single_prop', hands ]
        header_single_prop( prop, hands, type )
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
    case section
    when 'Backdrop', 'Special effects'
      parse_single_backdrop( line )
      parse_all_props( line )
    when 'Puppets'
      parse_single_puppet( line )
    when 'Setting'
      @setting << "\n#{line}"
    when 'On 2nd rail', 'On playrail', 'Hand props', 'Props'
      parse_all_props( line )
    when 'Stage setup'
      @setting << "\n#{line}"
      parse_all_props( line )
    end
  end

  def parse_table_role( line )
    list2 = line.split( '|' ).map( &:strip )
    list2.map! do |f|
      f == '' ? nil : f
    end
    role = list2[ 1 ]
    if role.nil?
      add_error_note( "Skipping Empty Role: #{line}" )
      return
    end
    player = list2[ 2 ]
    list2[ 3 ] = player if list2[ 3 ].nil?
    list2[ 3 ] =
      if list2[ 3 ].nil?
        list2[ 3 ] = nil
      else
        list2[ 3 ].split( ', ' )
      end
    list2[ 4 ] = player if list2[ 4 ].nil?

    list = merge_role( role, list2[ 2 .. -1 ] )
    @store.add_role( role, list )
    # pp [ 'parse_table_role', role, list ]
    {
      0 => 'player',
      1 => 'hands',
      2 => 'voice',
      3 => 'puppet',
      4 => 'clothing'
    }.each_pair do |i, type|
      next unless list[ i ].nil?

      add_todo(
        @store.error_message( "Missing name for #{type} on role '#{role}'" )
      )
    end
    check_role_list( list )
    list_one_person( role )
  end

  def split_dokuwiki_table( line )
    line.split( '|' )[ 1 .. -1 ].map( &:strip )
  end

  def parse_table_prop( line )
    list = split_dokuwiki_table( line )
    hands = list[ 1 ].split( /, */ )
    prop = list[ 0 ].sub( /^[^>]*>/, '' ).sub( /<[^<]*$/, '' )
    found = nil
    ITEM_TAGS.each_pair do |tag, type|
      found = type if list[ 0 ] =~ /<#{tag}>/
    end
    hands.push( new_stagehand( prop ) ) if hands.empty?
    # p [ 'header_single_prop',  prop, hands, found ]
    header_single_prop( prop, hands, found )
    # @setting << "\n" + list[ 0 ] + ' ' + list[ 2 ]
  end

  def parse_table_backdrop( line )
    list = split_dokuwiki_table( line )
    case list[ 0 ]
    when /^[A-Z][a-z]*:/
      parse_single_backdrop( list[ 0 ] )
    when 'Left', 'Middle', 'Right'
      add_single_backdrop( list[ 0 ], list[ 1 ] )
    else
      @setting << "\n#{line}"
      parse_table_prop( line )
    end
  end

  def parse_table_all( line )
    case @section
    when 'Role'
      parse_table_role( line )
    when 'Stage setup'
      parse_table_prop( line )
    when 'Backdrop'
      parse_table_backdrop( line )
    when 'Setting'
      @setting << "\n#{line}"
    when 'On 2nd rail', 'On playrail', 'Hand props', 'Special effects'
      parse_table_prop( line )
    when 'PreRec'
    else
      p [ 'parse_table_all', @section, line ]
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
      @setting << "\n#{line}"
    when 'Stage setup', 'On 2nd rail', 'On playrail'
      # ignore
    when 'Props', 'Hand props', 'PreRec', 'Special effects'
      # ignore
    else
      p [ 'parse_head', section, line ]
    end
  end

  def get_hands( kprop )
    hands = @scene_props_hands[ kprop ]
    hands = [] if hands.nil?
    hands
  end

  def add_prop_hands( prop, names )
    _storekey, _qscriptkey, reportkey = names
    kprop = prop.downcase
    hands = get_hands( kprop )
    return if hands.empty?

    hands.each do |hand|
      next if hand.casecmp( 'none' ).zero?

      @store.timeframe.add( 'Actor', hand )
      @store.timeframe.add_list_text( 'Actor', reportkey, hand, kprop )
      @store.timeframe.add_wiki_actor_for( hand, kprop )
    end
  end

  def add_single_prop( prop, names )
    storekey, qscriptkey, reportkey = names
    kprop = prop.downcase
    tprop =
      if @store.items[ storekey ].key?( kprop )
        @store.items[ storekey ][ kprop ][ :name ]
      else
        prop
      end
    @qscript.puts_key_token( qscriptkey, '+', tprop )
    @report.puts2_key_token( reportkey, '+', kprop )
    hands = get_hands( kprop )
    @store.add_item( storekey, kprop, hands: hands, text: prop, names: names )
    @store.count( storekey, kprop )
    @store.timeframe.add( storekey, kprop )
    @store.timeframe.add_list( storekey, reportkey, '+', kprop )
    @scene_props_names[ kprop ] = names
    add_prop_hands( prop, names )
    hands
  end

  def add_just_prop( prop, names )
    # p [ 'add_just_prop', prop, names ]
    storekey, qscriptkey, reportkey = names
    qscriptkey2 = "just #{qscriptkey}"
    reportkey2 = "J#{reportkey}"
    names2 = [ storekey, qscriptkey2, reportkey2 ]
    kprop = prop.downcase
    @store.count( storekey, kprop )
    @store.timeframe.add_once( storekey, kprop )
    @store.timeframe.add_list( storekey, reportkey2, '', kprop )
    hands = get_hands( kprop )
    @store.add_item( storekey, kprop, hands: hands, text: prop, names: names2 )
    tprop = @store.items[ storekey ][ kprop ][ :name ]
    @qscript.puts_key( qscriptkey2, tprop )
    @report.puts2_key( reportkey2, kprop )
    @scene_props_names[ kprop ] = names2
    add_prop_hands( prop, names2 )
    hands
  end

  def count_single_prop( prop, names )
    storekey, qscriptkey, reportkey = names
    kprop = prop.downcase
    unless @store.items[ storekey ].key?( kprop )
      add_todo(
        "ERROR: prop '#{prop}' changed type " \
        "from '#{@scene_props_names[ kprop ][ 0 ]}' to '#{names[ 0 ]}'"
      )
      names = @scene_props_names[ kprop ]
      storekey, qscriptkey, reportkey = names
      # break is type is not compatible
      return [] if qscriptkey =~ /^just/
    end
    @store.count( storekey, kprop )
    tprop = @store.items[ storekey ][ kprop ][ :name ]
    @qscript.puts_key_token( qscriptkey, '=', tprop )
    @report.puts2_key_token( reportkey, '=', kprop )
    @store.timeframe.add( storekey, kprop )
    @store.timeframe.add_list( storekey, reportkey, '=', kprop )
    add_prop_hands( prop, names )
    get_hands( kprop )
  end

  def drop_single_prop( prop, names )
    storekey, qscriptkey, reportkey = names
    kprop = prop.downcase
    tprop = @store.items[ storekey ][ kprop ][ :name ]
    @qscript.puts_key_token( qscriptkey, '-', tprop )
    @report.puts2_key_token( reportkey, '-', kprop )
    @store.timeframe.add( storekey, kprop )
    @store.timeframe.add_list( storekey, reportkey, '-', kprop )
    add_prop_hands( prop, names )
  end

  def add_owned_prop( prop, owner, names )
    storekey, qscriptkey, reportkey = names
    ownerkey = "#{storekey}_owner"
    kprop = prop.downcase
    tprop =
      if @store.items[ storekey ].key?( kprop )
        @store.items[ storekey ][ kprop ][ :name ]
      else
        prop
      end
    @qscript.puts_key_token( qscriptkey, '+', owner, tprop )
    @store.add_item(
      storekey, kprop,
      type: names[ 0 ], name: owner, hands: owner, text: prop,
      names: names
    )
    @store.count( storekey, kprop )
    @store.add( ownerkey, kprop, owner )
    @store.timeframe.add_once( storekey, kprop )
    unless owner.nil?
      @report.puts2_key_token(
        reportkey, '+', role( owner ), tname( names[ 0 ], kprop )
      )
    end
    puppet = @store.collection[ 'role_puppets' ][ owner ]
    hands = get_hands( kprop )
    @store.timeframe.add_prop(
      storekey, reportkey, '+', [ kprop, owner, hands, puppet ]
    )
    @store.collection[ 'owned_props' ][ owner ] = [] \
      unless @store.collection[ 'owned_props' ].key?( owner )
    @store.collection[ 'owned_props' ][ owner ].push(
      type: names[ 0 ], name: kprop, names: names
    )
    @scene_props_names[ kprop ] = names
    add_prop_hands( prop, names )
    hands
  end

  def remove_owned_prop( prop, owner, names )
    # p [ 'remove_owned_prop', prop, owner, names ]
    storekey, qscriptkey, reportkey = names
    ownerkey = "#{storekey}_owner"
    kprop = prop.downcase
    tprop = @store.items[ storekey ][ kprop ][ :name ]
    # return if qscriptkey =~ /^just /

    @qscript.puts_key_token( qscriptkey, '-', owner, tprop )
    @report.puts2_key(
      "#{reportkey}-", role( owner ), tname( storekey, kprop )
    )
    @store.count( storekey, kprop )
    @store.add( ownerkey, kprop, nil )
    puppet = @store.collection[ 'role_puppets' ][ owner ]
    hands = get_hands( kprop )
    @store.timeframe.add_prop(
      storekey, reportkey, '-', [ kprop, owner, hands, puppet ]
    )
    @store.collection[ 'owned_props' ][ owner ].delete(
      type: names[ 0 ], name: kprop, names: names
    )
    add_prop_hands( prop, names )
  end

  def count_owned_prop( prop, owner, names )
    # p [ 'count_owned_prop', prop, owner, names ]
    storekey, qscriptkey, reportkey = names
    ownerkey = "#{storekey}_owner"
    kprop = prop.downcase
    old = @store.collection[ ownerkey ][ kprop ]
    if old == owner
      @store.count( storekey, kprop )
      tprop = @store.items[ storekey ][ kprop ][ :name ]
      @qscript.puts_key_token( qscriptkey, '=', owner, tprop )
      @report.puts2_key_token( reportkey, '=', owner, kprop )
      puppet = @store.collection[ 'role_puppets' ][ owner ]
      hands = get_hands( kprop )
      @store.timeframe.add_prop(
        storekey, reportkey, '=', [ kprop, owner, hands, puppet ]
      )
      @scene_props_names[ kprop ] = names
      return hands
    end
    old_names =
      if @scene_props_names.key?( kprop )
        @scene_props_names[ kprop ]
      else
        names
      end
    remove_owned_prop( prop, old, old_names ) unless old.nil?
    add_owned_prop( prop, owner, names )
  end

  def remove_scene_prop( prop )
    kprop = prop.downcase
    storekey = @scene_props_names[ kprop ][ 0 ]
    case storekey
    when 'HandProp', 'TechProp', 'SpecialEffect'
      # storekey, qscriptkey, reportkey = @scene_props_names[ kprop ]
      # ownerkey = storekey + '_owner'
      # owner = @store.collection[ ownerkey ][ prop ]
      # also in drop_person()
      # remove_owned_prop( prop, owner, @scene_props_names[ kprop ] )
    when 'PersonalProp'
      # storekey, qscriptkey, reportkey = @scene_props_names[ kprop ]
      # ownerkey = storekey + '_owner'
      # owner = @store.collection[ ownerkey ][ prop ]
      # also in drop_person()
      # remove_owned_prop( prop, owner, @scene_props_names[ kprop ] )
    when nil
      p [ 'remove_scene_prop', prop, @scene_props_names[ kprop ] ]
    else
      drop_single_prop( prop, @scene_props_names[ kprop ] )
    end
  end

  def missing_scene_prop( prop )
    kprop = prop.downcase
    storekey = @scene_props_names[ kprop ][ 0 ]
    add_todo( "#{storekey} unused '#{prop}'" )
    case storekey
    when 'HandProp', 'TechProp', 'SpecialEffect'
      add_just_prop( prop, PROP_NAMES[ storekey ] )
    when 'PersonalProp'
      ownerkey = "#{storekey}_owner"
      owner = @store.collection[ ownerkey ][ kprop ]
      if owner.nil?
        add_single_prop( prop, @scene_props_names[ kprop ] )
      else
        add_owned_prop( prop, owner, @scene_props_names[ kprop ] )
      end
    else
      add_single_prop( prop, @scene_props_names[ kprop ] )
    end
  end

  def add_scene_prop( prop, tag )
    kprop = prop.downcase
    if @scene_props.key?( kprop )
      @scene_props[ kprop ] += 1
      return
    end

    add_todo( "unknown Prop '#{prop}'" )
    add_todo( "| <#{tag}>#{prop}</#{tag}> |  |  |" )
    @scene_props[ kprop ] = 1
    @scene_props_fix[ kprop ] = 1
  end

  def collect_single_prop( prop, names, tag )
    add_scene_prop( prop, tag )
    kprop = prop.downcase
    storekey = "#{names[ 0 ]}_count"
    @store.collection[ storekey ] = {} unless @store.collection.key?( storekey )
    if @scene_props[ kprop ] == 1
      # add_todo( "#{names[ 0 ]} missing in header '#{prop}'" )
      return add_single_prop( prop, names )
    end

    count_single_prop( prop, names )
  end

  def collect_just_prop( prop, names, tag )
    storekey = names[ 0 ]
    ownerkey = "#{storekey}_owner"
    add_scene_prop( prop, tag )
    kprop = prop.downcase
    # p [
    #   'collect_just_prop', prop, ownerkey, @scene_props_hands[ kprop ],
    #   @scene_props_names[ kprop ], @store.collection[ ownerkey ][ kprop ]
    # ]
    if @store.collection.key?( ownerkey )
      old = @store.collection[ ownerkey ][ kprop ]
      remove_owned_prop( prop, old, @scene_props_names[ kprop ] ) \
        unless old.nil?
    end
    add_just_prop( prop, names )
  end

  def collect_owned_prop( prop, owner, names, tag )
    return collect_just_prop( prop, names, tag ) if owner.nil?

    add_scene_prop( prop, tag )
    # p [ 'collect_owned_prop', prop, owner, names, tag ]
    count_owned_prop( prop, owner, names )
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
    hands = []
    suffix_props( line, suffix ).each do |prop|
      hands.concat( collect_single_prop( prop, names, tag ) )
    end

    tagged_props( line, tag ).each do |prop|
      hands.concat( collect_single_prop( prop, names, tag ) )
    end
    hands
  end

  def search_handprop( line )
    props = []
    return props if line.nil?

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

    props.concat( search_simple_props( line, 'pr', 'fp' ) )
    props.concat( search_simple_props( line, '2nd', 'sp' ) )
    props
  end

  def collect_handprop( line, owner )
    hands = []
    return hands if line.nil?

    # p ['collect_handprop', line, owner ]
    [ 'hp' ].each do |key|
      suffix_props( line, key ).each do |prop|
        hands.concat( collect_owned_prop( prop, owner, HANDPROP_NAMES, key ) )
      end
    end

    [ 'pp' ].each do |key|
      tagged_props( line, key ).each do |prop|
        hands.concat( collect_owned_prop( prop, owner, PERSPROP_NAMES, key ) )
      end
    end

    [ 'hp' ].each do |key|
      tagged_props( line, key ).each do |prop|
        hands.concat( collect_owned_prop( prop, owner, HANDPROP_NAMES, key ) )
      end
    end

    [ 'tec' ].each do |key|
      tagged_props( line, key ).each do |prop|
        hands.concat( collect_owned_prop( prop, owner, TECHPROP_NAMES, key ) )
      end
    end

    [ 'sfx' ].each do |key|
      tagged_props( line, key ).each do |prop|
        hands.concat( collect_owned_prop( prop, owner, SFXPROP_NAMES, key ) )
      end
    end

    hands.concat( collect_simple_props( line, 'pr', 'fp', FRONTPROP_NAMES ) )
    hands.concat( collect_simple_props( line, '2nd', 'sp', SECONDPROP_NAMES ) )
    hands
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

  def add_stagehands( hands, text )
    # p [ 'add_stagehands', hands, text ]
    hands.each do |hand|
      next if hand.casecmp( 'none' ).zero?

      @store.add( 'Actor', hand, 'stagehand' )
      add_todo( @store.check_actor( hand ) )
      parse_stagehand( hand, text, 'stagehand', 'Stage' )
    end
  end

  def print_simple_line( line )
    SIMPLE_MAP.each_pair do |key, val|
      qscript_key, result_key, type = val
      case line
      when /^#{key} /
        line.strip!
        text = line.sub( /^#{key}  */, '' )
        stagehands = collect_handprop( text, nil )
        add_stagehands( stagehands, text )
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

  def add_todo( line )
    return if line.nil?

    @qscript.puts_key( 'todo', line )
    @report.puts2_key( 'Todo', line )
    @qscript.puts ''
    @store.add_item( 'Todo', line, text: line )
    @store.timeframe.add( 'Todo', line )
    @store.timeframe.add_list( 'Todo', 'Todo', '', line )
  end

  def add_error_note( line )
    add_todo( line )
    warn line
  end

  def change_role_player( role, old_player, player )
    return if old_player.nil?
    return if old_player == ''
    return if old_player == player
    return if $debug.zero?

    add_error_note(
      "INFO: Player changed for '#{role}': '#{old_player}' -> '#{player}'"
    )
    # set as new default
    @store.add_role_collection( role, 'player', player )
  end

  def change_role_hand( role, old_hand, hand )
    return if old_hand.nil?
    return if old_hand == ''
    return if old_hand == hand
    return if $debug.zero?

    add_error_note(
      "INFO: Hands changed for '#{role}': '#{old_hand.join( ', ' )}' -> '#{hand.join( ', ' )}'"
    )
    # set as new default
    @store.add_role_collection( role, 'hands', hand )
  end

  def change_role_voice( role, old_voice, voice )
    return if old_voice.nil?
    return if old_voice == ''
    return if old_voice == voice
    return if $debug.zero?

    add_error_note(
      "INFO: Voice changed for '#{role}': '#{old_voice}' -> '#{voice}'"
    )
    # set as new default
    @store.add_role_collection( role, 'voice', voice )
  end

  def change_role_puppet( role, old_puppet, puppet )
    return if old_puppet.nil?
    return if old_puppet == ''
    return if old_puppet == puppet
    return if $debug.zero?

    add_error_note(
      "INFO: Puppet changed for '#{role}': '#{old_puppet}' -> '#{puppet}'"
    )
    # set as new default
    puppet = nil if clothing.casecmp( 'none' ).zero?
    @store.collection[ 'role_puppets' ][ role ] = puppet unless puppet.nil?
  end

  def strip_none( name )
    return nil if name.nil?
    return name unless name.respond_to?( :casecmp ) # skip arrays
    return nil if name == ''
    return nil if name.casecmp( 'none' ).zero?

    name
  end

  def change_role_clothing( role, old_clothing, clothing )
    clothing2 = strip_none( clothing )
    old_clothing2 = strip_none( old_clothing )
pp [ :strip_none, clothing, clothing2, old_clothing, old_clothing2 ]
    return if old_clothing2 == clothing2
    return if $debug.zero?

    old_clothing2 = 'None' if old_clothing.nil?
    add_error_note(
      "INFO: Costume changed for '#{role}': '#{old_clothing2}' -> '#{clothing}'"
    )
    # set as new default
    @store.collection[ 'role_costumes' ][ role ] = clothing2
  end

  def old_role( role, list )
    old_list = [
      @store.last_role( role, 'player' ),
      @store.last_role( role, 'hands' ),
      @store.last_role( role, 'voice' ),
      @store.collection[ 'role_puppets' ][ role ],
      @store.collection[ 'role_costumes' ][ role ]
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
    pp [ 'merge_role', role, old_list, list, new_list ] unless $debug.zero?
    new_list
  end

  def unknown_person( name )
    # return if @store.collection[ 'person' ].key?( name )
    return if @store.timeframe.seen?( 'Role', name )

    p [ 'unknown_person', name ]
    if @section != 'Puppets:'
      add_error_note( "unknown Role: '#{name}'" )
      warn( @store.collection[ 'Role' ][ name ] )
    end
    list = [ nil, nil, nil, nil, nil ]
    if @store.collection[ 'Role' ].key?( name )
      # assume nothing changed
      # @store.update_role( name, @store.collection )
      list = [
        @store.last_role( name, 'player' ),
        @store.last_role( name, 'hands' ),
        @store.last_role( name, 'voice' ),
        @store.collection[ 'role_puppets' ][ name ],
        @store.collection[ 'role_costumes' ][ name ]
      ]
    end
    @store.add_role( name, list )
    check_role_list( list )
    list_one_person( name )
  end

  def parse_position( _name, text )
    case text
    when / leaves towards /, / leaves to /
      # drop_person( name )
    end
  end

  def print_role( name, qscript_key, result_key, text )
    unknown_person( name )
    stagehands = collect_handprop( text, name )
    add_stagehands( stagehands, text )
    @qscript.puts_key( qscript_key, name, text )
    @report.puts2_key( result_key, name, text )
    @store.timeframe.add_list_text( 'Role', result_key, name, [ name, text ] )
    player = @store.last_role( name, 'player' )
    @store.timeframe.add_list_text(
      'Actor', result_key, player, [ name, text ]
    )
    hands = @store.last_role( name, 'hands' )
    hands.each do |hand|
      next if hand == player

      @store.timeframe.add_list_text(
        'Actor', result_key, hand, [ name, text ]
      )
    end
    voice = @store.last_role( name, 'voice' )
    if voice != player
      @store.timeframe.add_list_text(
        'Actor', result_key, voice, [ name, text ]
      )
    end
    puppet = @store.collection[ 'role_puppets' ][ name ]
    @store.timeframe.add_list_text(
      'Puppet', result_key, puppet, [ name, text ]
    )
    parse_position( name, text )
  end

  def print_roles( name, qscript_key, result_key, text )
    @roles_config.map_roles( name ).each do |role|
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
    rest.scan( /(#{MATCH_NAME}) *(\[[^\]]*\])*/ ) do |role, position|
      next if role == 'and'

      roles.push( role )
      position << ' ' unless position.nil?
      position = '' if position.nil?
      positions[ role ] = position
    end
    # pp roles
    # pp positions
    @roles_config.add_roles( group, roles )
    # p [ group, text ]
    roles.each do |role|
      print_role( role, qscript_key, result_key, "#{positions[ role ]}#{text}" )
    end
  end

  def parse_role_name( text )
    rest = text.gsub( / *\[[^\]]*\]/, '' )
    rest.gsub!( /^The /, '' )
    rest.gsub!( /^A /, '' )
    list = []
    while /^#{MATCH_NAME}( and |, *)/ =~ rest
      name, rest = rest.split( / and |, */, 2 )
      list.push( name )
    end
    name, rest = rest.split( ' ', 2 )
    case name
    when /^#{MATCH_NAME}:*$/
      list.push( name.sub( ':', '' ) )
    when /^#{MATCH_NAME}'s:*$/
      name = name.sub( '\'s', '' )
      list.push( name.sub( ':', '' ) )
    else
      add_error_note( "Error in Role: '#{name}', #{text}" )
    end
    case rest
    when /^= *#{MATCH_NAME}:/
      group = rest.sub( /^= */, '' ).split( ':' ).first
      @roles_config.add_roles( group, list )
    end
    # p [ 'parse_role_name', list, text ]
    [ list, text ]
  end

  def parse_action( text, qscript_key, result_key )
    case text
    when /=/ # Group definition
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
    stagehands = collect_handprop( comment, name )
    stagehands.concat( collect_handprop( text, name ) )
    add_stagehands( stagehands, text )
    case text.split( ':', 2 ).last
    when /^[^"].*[^"]$/
      add_todo( "spoken line not quoted: #{name}: '#{text}'" )
    end
    if $compat
      text.sub!( /"$/, '' )
      text.sub!( /^"/, '' )
    end
    @store.timeframe.add_spoken( 'Role', name )
    player = @store.last_role( name, 'player' )
    @store.timeframe.add_spoken( 'Actor', player )
    voice = @store.last_role( name, 'voice' )
    if voice != player && !voice.nil?
      @store.timeframe.add_spoken( 'Actor', voice )
    end
    puppet = @store.collection[ 'role_puppets' ][ name ]
    @store.timeframe.add_spoken( 'Puppet', puppet )
    if comment.nil?
      @qscript.puts_key( 'spoken', name, text )
      @report.puts2_key( 'Spokn', name, text )
      return
    end
    @qscript.puts_key( 'spoken', name, "(#{comment}) #{text}" )
    @report.puts2_key( 'Spokn', name, "(#{comment}) #{text}" )
    return unless voice.nil?

    add_todo( "unknown voice for role: #{name}" )
  end

  def print_spoken_roles( name, comment, text )
    @roles_config.map_roles( name ).each do |role|
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

  def replace_text( line, filename )
    return line unless $subs.key?( filename )

    $subs[ filename ].each_pair do |pattern, text|
      # found = line.gsub!( /#{pattern}/, text )
      found = line.gsub!( pattern, text )
      next if found.nil?

      $subs_count[ pattern ] += 1
    end
    line
  end

  def close_scene
    # pp @scene_props
    @scene_props.each_pair do |prop, count|
      storekey = @scene_props_names[ prop ][ 0 ]
      tprop = @store.items[ storekey ][ prop ][ :name ]
      missing_scene_prop( tprop ) if count.zero?
      remove_scene_prop( tprop )
    end
    @store.timeframe.list( 'Role' ).each do |role|
      drop_person( role )
    end
    @qscript.puts '}'
    @qscript.puts ''
    @store.timeframe.add_table( 'props_hands', @scene_props_hands )
    @store.timeframe.add_table( 'props_fix', @scene_props_fix )
    @scene_props = {}
    @scene_props_hands = {}
    @scene_props_roles = {}
    @scene_props_names = {}
    @scene_props_fix = {}
    @setting = ''
    @roles_config.roles_map.each_pair do |group, role|
      @store.timeframe.add_wiki_group_for( role, group )
    end
    @roles_config.unused
    @roles_config = nil
  end

  def print_unknown_line( line )
    case line
    when '^Part^Time|', /^\|(Intro|Dialogue)\|/, /^\|\*\*Scene Total\*\* \|/,
         /:events:pps:script:/
      return
    end
    add_error_note( "unknown line '#{line}'" )
  end

  def parse_table_section( line )
    SECTION_NAMES.each do |key|
      next unless line =~ /^\^ *#{key} /

      @section = key
      return true
    end
    # p [ 'parse_table_section failed', line ]
    false
  end

  def parse_section( line )
    case line
    when '', '----', '^Part^Time|'
      @section = nil if @section != 'INTRO'
      return true
    when /^<html>/, /^\[\[/
      return true # ignore navigation
    when /^==== / # title note
      add_note( line )
      add_note( "INFO: version date #{@version}" )
      return true
    when /^      [*] / # head data
      parse_section_data( @section, line )
      return true
    when /^    [*] [A-Za-z][A-Za-z0-9_ -]*:/ # head comment
      @section = line.slice( /[A-Za-z][A-Za-z0-9_ -]*:/ )[ 0 .. -2 ]
      parse_head( @section, line )
      return true
    when '== INTRO =='
      @section = 'INTRO'
      return true
    when '== DIALOG ==', '== DIALOGUE =='
      @section = nil
      return true
    when '== TECH PREROLL ==', '== TECH PREROLL 🧻 =='
      @section = 'PREROLL'
      return true
    when /^\^/ # table head
      parse_table_section( line )
      return true if @section.nil?

      @qscript.puts "\t//#{line}"
      return true
    when /^\|/ # table data
      return true if @section.nil?

      @qscript.puts "\t//#{line}"
      parse_table_all( line )
      return true
    when /^### /
      return false # parse later
    else
      return false if @section.nil?
      return false if @section == 'INTRO'

      p [ 'parse_section', @section, line ]
      add_todo( "unknown header in #{@section}: '#{line}'" )
    end
    false
  end

  def get_stagehand( kprop )
    unless @scene_props_hands.key?( kprop )
      nhand = new_stagehand( kprop )
      @scene_props_hands[ kprop ] = [ nhand ]
    end
    @scene_props_hands[ kprop ]
  end

  def parse_hand( text )
    props = search_handprop( text )
    props.each do |prop|
      kprop = prop.downcase
      hands = get_stagehand( kprop )
      p [ '%HND%', props, hands ] unless $debug.zero?
      hands.each do |hand|
        next if hand.casecmp( 'none' ).zero?

        @store.add_item( 'Actor', hand, prop: kprop, stagehand: true )
        add_todo( @store.check_actor( hand ) )
        collect_handprop( text, nil )
        parse_stagehand( hand, text, 'stagehand', 'Stage' )
        @store.timeframe.add_wiki_actor_for( hand, kprop )
      end
    end
    return unless props.empty?

    add_todo( "%HND% ohne Prop oder Stagehand: #{text}" )
  end

  def parse_spot( text )
    @store.timeframe.add( 'Effect', text )
    props = search_handprop( text )
    props.each do |prop|
      kprop = prop.downcase
      hands = get_stagehand( kprop )
      @scene_props_hands[ text ] = hands
      p [ '%SPT%', props, hands ] unless $debug.zero?
      hands.each do |hand|
        next if hand.casecmp( 'none' ).zero?

        @store.add_item( 'Actor', hand, effect: kprop, stagehand: true )
        add_todo( @store.check_actor( hand ) )
        collect_handprop( text, nil )
        parse_stagehand( hand, text, 'effect', 'Effct' )
        @store.add_item( 'Effect', kprop, stagehand: hand )
        @store.timeframe.add_list_text(
          'Effect', 'Effct', kprop, [ hand, text ]
        )
        @store.timeframe.add_wiki_actor_for( hand, kprop )
      end
    end
    return unless props.empty?

    add_todo( "%SPT% ohne Prop oder Stagehand: #{text}" )
  end

  def add_fog_hands( text )
    @store.timeframe.add( 'Effect', text )
    hands = get_hands( FOG_STAGEHEAND )
    hands = get_hands( FOG_STAGEHEAND.downcase ) if hands.empty?
    hands = get_stagehand( 'fog' ) if hands.empty?
    @scene_props_hands[ text ] = hands
    hands.each do |hand|
      @store.add_item( 'Actor', hand, effect: text, stagehand: true )
      add_todo( @store.check_actor( hand ) )
      @store.add_item( 'Effect', text, stagehand: hand )
      parse_stagehand( hand, text, 'effect', 'Effct' )
      @store.timeframe.add( 'Effect', text )
      @store.timeframe.add_list_text( 'Effect', 'Effct', text, [ hand, text ] )
      @store.timeframe.add_list_text( 'Actor', 'Effct', text, [ hand, text ] )
      @store.timeframe.add_wiki_actor_for( hand, text )
    end
  end

  def parse_fog( text )
    props = search_handprop( text )
    props.each do |prop|
      kprop = prop.downcase
      hands = get_stagehand( kprop )
      @scene_props_hands[ text ] = hands
      @store.timeframe.add( 'Effect', kprop ) if props.empty?
      p [ '%FOG%', props, hands, text ] unless $debug.zero?
      hands.each do |hand|
        next if hand.casecmp( 'none' ).zero?

        @store.add_item( 'Actor', hand, effect: kprop, stagehand: true )
        add_todo( @store.check_actor( hand ) )
        collect_handprop( text, nil )
        parse_stagehand( hand, text, 'effect', 'Effct' )
        @store.add_item( 'Effect', kprop, stagehand: hand )
        @store.timeframe.add_list_text(
          'Effect', 'Effct', kprop, [ hand, text ]
        )
        @store.timeframe.add_list_text(
          'Actor', 'Effct', kprop, [ hand, text ]
        )
        @store.timeframe.add_wiki_actor_for( hand, kprop )
      end
    end
    return unless props.empty?

    add_fog_hands( text )
  end

  def parse_curtain( line )
    unless @setting == ''
      print "Setting: #{@store.timeframe.timeframe}: "
      stagehands = collect_handprop( @setting, nil )
      add_stagehands( stagehands, 'Setting' )
      pp stagehands
      @setting = ''
      # pp @scene_props
    end
    curtain( line.sub( /^%HND% Curtain - */, '' ) )
  end

  def intro_line( line )
    return false unless @section == 'INTRO'

    print_simple_line( "%PRE% #{line}" )
    true
  end

  def parse_script_line( line )
    case line
    when ''
      return
    when /Backdrop_L/
      collect_backdrop( line )
      return
    when /^Setting:/
      @qscript.puts "\t//#{line}"
      @setting << "\n#{line}"
      @section = 'Setting'
      return
    when /^%HND% Curtain - /
      parse_curtain( line )
      return
    when /^%HND% /
      parse_hand( line.sub( /^%HND% /, '' ) )
      return
    when /^%SPT% /
      parse_spot( line.sub( /^%SPT% /, '' ) )
      return
    when /^%FOG% /
      parse_fog( line.sub( /^%FOG% /, '' ) )
      return
    when /^%MIX% /
      add_note( line )
      return
    when /^#{MATCH_NAME} [(][^:]*[)]: /
      return if intro_line( line )

      name, comment, text =
        line.scan( /^(#{MATCH_NAME}) [(]([^:]*)[)]: (.*)/ )[ 0 ]
      print_spoken_roles( name, comment, text )
      return
    when /^#{MATCH_NAME}: /
      return if intro_line( line )

      name, text = line.split( ': ', 2 )
      print_spoken_roles( name, nil, text )
      return
    when /^#{MATCH_NAME}(, #{MATCH_NAME}| +and +)*: /,
         /^#{MATCH_NAME}(, #{MATCH_NAME}| +and +)* *= *#{MATCH_NAME}: /
      return if intro_line( line )

      print_spoken_mutiple( line )
      return
    end
    return if print_simple_line( line )
    return if print_role_line( line )

    print_unknown_line( line )
  end

  def parse_lines( filename, lines, version )
    @section = nil
    @version = version
    error_linenr = 0
    @error_line = nil
    parse_title( filename )
    lines.each do |line|
      error_linenr += 1
      @error_line = "#{error_linenr}:#{line}"
      puts @error_line unless $debug.zero?
      line.sub!( /\\\\$/, '' ) # remove DokuWiki linebreak
      line.rstrip!
      line = replace_text( line, filename )
      line = replace_text( line, 'global' )
      next if parse_section( line )

      line.strip!
      parse_script_line( line )
    end
    close_scene
  end
end

read_subs( SUBS_CONFIG_FILE )
read_puppet( PUPPET_POOL_FILE )
qscript = QScript.new
timeframe = Timeframe.new( qscript )
store = Store.new( timeframe )
report = Report.new( store, qscript )
parser = Parser.new( store, qscript, report )

ARGV.each do |filename|
  warn filename
  version = File.stat( filename ).mtime.strftime( '%Y-%m-%d %H:%M' )
  lines = File.read( filename ).split( "\n" )
  parser.parse_lines( filename, lines, version )
end

qscript.save( 'qscript.txt' )

parser.report.catalog
parser.report.puts_timeframe
parser.report.catalog_item
parser.report.puts_tables
parser.report.save_html( 'out.html' )

table2 = parser.report.puppet_costumes
costumes = parser.report.html_table( table2, 'Costumes' )
html_costumes = File.read( HTML_HEADER_FILE )
html_costumes << '<body>'
html_costumes << costumes
file_put_contents( 'clothes.html', html_costumes )
file_put_contents( WIKI_ACTORS_FILE,
                   JSON.pretty_generate( parser.store.timeframe.wiki_highlite ) )

CSV.open( TODO_LIST_FILE, 'wb', col_sep: ';' ) do |csv|
  parser.report.todo_list.each do |row|
    csv << row
  end
end

CSV.open( ASSIGNMENT_LIST_FILE, 'wb', col_sep: ';' ) do |csv|
  parser.report.assignment_list.each do |row|
    csv << row
  end
end

$subs_count.each_pair do |pattern, count|
  next unless count.zero?

  puts "unused pattern: #{pattern}"
end

# pp parser.store.items[ 'FrontProp' ]
# pp parser.store.items[ 'Backdrop' ]
# pp parser.store.items[ 'Role' ]
# pp parser.store.items[ 'Costume' ]
# pp parser.store.items[ 'Actor' ]
# pp parser.store.items[ 'Actor' ][ 'Liam' ]
# pp parser.store.items[ 'SecondLevelProp' ]
# pp parser.store.timeframe.wiki_highlite

exit 0
# eof
