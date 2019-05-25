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

$nat_sort = false
$compat = true

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

# === Class Item
#   Item.index
#   Item.type
#   Item.key?( name )
#   Item.add( name )
#   Item.add_play( name, hash )
#   Item.pp( name )
#   Item.new( name )
#   Item.play( obj )
class Item
  @number = 0
  @index = {}
  @type = 'Item'
  @tag = nil

  class << self
    attr_accessor :number
    attr_reader :index
    attr_reader :type
    attr_reader :loc
    attr_reader :tag

    def key?( name )
      @index.key?( name )
    end

    def fetch( name )
      return @index[ name ] if @index.key?( name )

      nil
    end

    def add( name )
      return @index[ name ] if @index.key?( name )

      new( name )
    end

    def add_play( name, hash )
      obj = add( name )
      obj.play( hash )
    end

    def pp
      @index.each do |name, item|
        PP.pp [ name, item ]
      end
    end
  end

  attr_reader :name
  attr_reader :list
  attr_reader :ref

  def make_ref
    @ref = "item#{self.class.loc}_#{self.class.number}"
    self.class.number += 1
  end

  def initialize( name )
    if self.class.index.key?( name )
      STDERR.puts "Error: #{self.class.type} #{name} not unique"
      name << ( self.class.number + 1 ).to_s
    end
    self.class.index[ name ] = self
    make_ref
    @name = name
    @list = []
  end

  def play( obj )
    @list.push( obj ) unless obj.nil?
  end

  def to_html
    "<a href=\"##{@ref}\">#{html_escape( @name )}</a>"
  end
end

# === Class FrontProp
class FrontProp < Item
  @number = 0
  @index = {}
  @type = 'FrontProp'
  @loc = '0'
  @tag = 'fp'
end

# === Class SecondLevelProp
class SecondLevelProp < Item
  @number = 0
  @index = {}
  @type = 'SecondLevelProp'
  @loc = '1'
  @tag = 'sp'
end

# === Class Backdrop
class Backdrop < Item
  @number = 0
  @index = {}
  @type = 'Backdrop'
  @loc = '2'
end

# === Class Light
class Light < Item
  @number = 0
  @index = {}
  @type = 'Light'
  @loc = '3'
end

# === Class Ambience
class Ambience < Item
  @number = 0
  @index = {}
  @type = 'Ambience'
  @loc = '4'
end

# === Class Sound
class Sound < Item
  @number = 0
  @index = {}
  @type = 'Sound'
  @loc = '5'
end

# === Class Video
class Video < Item
  @number = 0
  @index = {}
  @type = 'Video'
  @loc = '6'
end

# === Class Fog
class Fog < Item
  @number = 0
  @index = {}
  @type = 'Fog'
  @loc = '7'
end

# === Class Actor
class Actor < Item
  @number = 0
  @index = {}
  @type = 'Actor'
  @loc = '9'
end

# === Class Puppet
class Puppet < Item
  @number = 0
  @index = {}
  @type = 'Puppet'
  @loc = '10'
end

# === Class Clothing
class Clothing < Item
  @number = 0
  @index = {}
  @type = 'Clothing'
  @loc = '11'
end

# === Class PersonalProp
class PersonalProp < Item
  @number = 0
  @index = {}
  @type = 'PersonalProp'
  @loc = '12'
  @tag = 'pp'
end

# === Class HandProp
class HandProp < Item
  @number = 0
  @index = {}
  @type = 'HandProp'
  @loc = '13'
  @tag = 'hp'
end

# 14 = Todos

# === Class Role
#   Role.set( scene, list )
class Role < Item
  @number = 0
  @index = {}
  @type = 'Role'
  @loc = '8'

  attr_reader :player
  attr_reader :voice
  attr_reader :hands
  attr_reader :puppet
  attr_reader :clothing

  def set( scene, list )
    player, hands, voice, puppet, clothing = list
    voice = voice.nil? ? player : voice
    hands = hands.nil? ? player : hands
    @player = Actor.add( player )
    @player.play( scene: scene, role: @name, player: true )
    @voice = Actor.add( voice )
    @voice.play( scene: scene, role: @name, voice: true )
    @hands = Actor.add( hands )
    @hands.play( scene: scene, role: @name, hands: true )
    @puppet = Puppet.add( puppet )
    @puppet.play( scene: scene, role: @name, clothing: clothing )
    @clothing = Clothing.add( clothing )
    @clothing.play( scene: scene, role: @name, puppet: puppet )
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
#   Timeframe.add_table( hashkey, table )
#   Timeframe.add_list_text( key, reportkey, name, text )
#   Timeframe.add_list( key, reportkey, token, name )
#   Timeframe.add_spoken( name )
#   Timeframe.list( key )
class Timeframe
  attr_reader :fields
  attr_reader :timeframe
  attr_reader :timeframes
  attr_reader :timeframes_lines

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

  def add_table( hashkey, table )
    @timeframes[ @timeframe ][ hashkey ] = table
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
  attr_reader :collection
  attr_reader :timeframe
  attr_reader :ignore

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
    return nil if clothing == 'None'

    add( 'person_clothes', name, clothing )
    add( 'clothes', clothing, name )
    @timeframe.add( 'Clothing', clothing )
    @timeframe.add_list_text( 'person', 'Clth+', name, "#{name} #{clothing}" )
    puppet = @collection[ 'person_puppets' ][ name ]
    @timeframe.add_list_text( 'puppets', 'Clth+', puppet, "#{name} #{clothing}" )
    @timeframe.add_list_text( 'clothes', 'Clth+', clothing, "#{name} #{clothing}" )
    clothing
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
    @timeframe.add_hash( 'puppet_plays', upuppet, [ name, uplayer, uhands, uvoice, uclothing ] )
    role = Role.add( name )
    role.set( @timeframe.timeframe, [ uplayer, uhands, uvoice, upuppet, uclothing ] )
  end

  def add_backdrop( position, backdrop )
    key = "#{backdrop} #{position}"
    count( 'backdrops', key )
    @collection[ 'backdrops_position' ][ position ] = key
    @timeframe.add( 'Backdrop panel', key )
    Backdrop.add_play( key, scene: @timeframe.timeframe, position: position )
    key
  end
end

# === Class Functions
#   Report.new( qscript )
#   Report.puts( line )
#   Report.puts2( line )
#   Report.puts2_key( key, name, text = nil )
#   Report.puts2_key_token( key, token, name, text = nil )
#   Report.puts3_key_token( key, token, name, text = nil )
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
    'Effects',
    'Front prop',
    'Second level prop',
    'Personal prop',
    'Hand prop'
  ].freeze
  REPORT_HANDS = [
    'Effects',
    'Front prop',
    'Second level prop',
    'Personal prop',
    'Hand prop'
  ].freeze
  ITEM_LIST = [
    FrontProp,
    SecondLevelProp,
    Backdrop,
    Light,
    Ambience,
    Sound,
    Video,
    Fog,
    Role,
    Actor,
    Puppet,
    Clothing,
    PersonalProp,
    HandProp
  ].freeze

  attr_accessor :timeframe_count

  def initialize( qscript )
    @qscript = qscript
    @head = "   ^  Table of contents\n"
    @cgi = CGI.new( 'html5' )
    @html_head = File.read( HTML_HEADER_FILE )
    @html_head << "<body><a href=\"#top\">^&nbsp;</a> <u>Table of contents</u>\n"
    @html_head << '<ul>'
    @script = "\n   Script\n"
    @timeframe_count = 0
    @counters = {}
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

  def object_name( name )
    case name.class
    when *ITEM_LIST
      return name.name
    end
    name
  end

  def puts_p( arr )
    key = arr.shift
    text = '    ' + key
    arr.each do |item|
      text << ' '
      if item.class == Array
        text << object_name( item.shift )
        item.each do |sub|
          text << '.'
          text << object_name( sub )
        end
      else
        text << object_name( item )
      end
    end
    puts2 text
  end

  def html_object_ref( name )
    case name.class
    when *ITEM_LIST
      return name.ref
    end
    ITEM_LIST.each do |type|
      obj = type.fetch( name )
      return obj.ref unless obj.nil?
    end
    nil
  end

  def html_object_name( name )
    case name.class
    when *ITEM_LIST
      return name.to_html
    end
    ITEM_LIST.each do |type|
      obj = type.fetch( name )
      return obj.to_html unless obj.nil?
    end
    html_escape( name )
  end

  def html_p( arr )
    loc = "loc#{@qscript.lines}_2"
    key = arr.shift
    text = '&nbsp;' + key
    arr.each do |item|
      text << ' '
      if item.class == Array
        text << html_object_name( item.shift )
        item.each do |sub|
          text << '.'
          text << html_object_name( sub )
        end
      else
        text << html_object_name( item )
      end
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
      puts_p( [ key, name ] )
      html_p( [ key, name ] )
    else
      puts_p( [ key, name, text ] )
      html_p( [ key, name, text ] )
    end
  end

  def puts2_key_token( key, token, name, text = nil )
    puts2_key( key + token, name, text )
  end

  def text_item( item )
    "     * #{item}\n"
  end

  def capitalize( item )
    item.tr( ' ', '_' ).gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase ).delete( '_"' )
  end

  def href( item )
    citem = capitalize( item )
    if $compat
      case citem
      when 'CatalogItemDetails'
        return 'catDetails'
      when /^TimeframeScene/
        return "timeframe#{@timeframe_count}"
      end
    end

    item[ 0 .. 0 ].downcase + citem[ 1 .. -1 ].delete( ' "-' )
  end

  def html_li_ref_item( ref, item )
    "<li><a href=\"##{ref}\">#{item}</a></li>\n"
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
    @head << text_item( item )
    @html_head << html_li_item( item )
    @html_report << html_u_item( item ) + "\n"
    puts "   #{item}"
  end

  def add_script( item )
    @script << text_item( item )
    @html_script << html_li_item( item )
    puts2 "   #{item}"
    @html_report << html_u_item( item ) + "<br/>\n"
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
        @html_report << html_li_ref_item( html_object_ref( prop ), html_escape(prop) ) + "\n"
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
    @html_report << "<br/>\n"
    add_head( 'Catalog' )
    count = 0
    @html_report << '<ul>'
    REPORT_CATALOG.each_key do |key|
      @html_report << html_li_ref_item( "catalog#{count}", key )
      count += 1
      puts "     * #{key}"
    end
    @html_report << "</ul><br/>\n"
    puts ''

    count = 0
    REPORT_CATALOG.each_pair do |key, listname|
      @html_report << html_u_ref_item( "catalog#{count}", "Catalog: #{key}" ) + "\n<ul>"
      puts "   Catalog: #{key}"
      count += 1
      list( collection[ listname ] )
      @html_report << "</ul><br/>\n"
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

  def hand_props_actors( timeframe, scene, prop_type )
    scene_props_hands = timeframe.timeframes[ scene ][ 'props_hands' ]
    props = timeframe.timeframes[ scene ][ prop_type ]
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

  def list_hand_props( timeframe )
    hands = {}
    timeframe.timeframes.each_key do |scene|
      hands[ scene ] = []
      REPORT_HANDS.each do |name|
        next unless timeframe.timeframes[ scene ].key?( name )

        hand_props_actors( timeframe, scene, name ).each do |arr|
          hands[ scene ].push( [ name ].concat( arr ) )
        end
      end
    end
    hands
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

  def table_caption( title )
    href = capitalize( title )
    "<u id=\"tab#{href}\">#{title}</u>\n<table>"
  end

  def html_table( table, title )
    html = table_caption( title )
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

  def html_list( caption, title, hash, seperator = '</td><td>' )
    html = table_caption( caption + ' ' + title )
#    html << '<tr><td>'
#    html << title
#    html << "</td></tr>\n"
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

  def puts_build_list( caption, title, hash, seperator = "\t" )
    text = "   #{caption} #{title}\n\n"
    hash.each_pair do |item, arr|
      next if arr.nil?

      seen = {}
      arr.each do |name|
        next if seen.key?( name )

        seen[ name ] = true
        text << "   #{item}#{seperator}#{name}\n"
      end
    end
    puts text
  end

  def puts_hands_list( caption, title, table, seperator = "\t" )
    text = "   #{caption} #{title}\n\n"
    table.each do |arr|
      next if arr.nil?

      text << '   '
      text << arr.join( seperator )
      text << "\n"
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
    list_unsorted( REPORT_TABLES.keys << 'Puppet use' )
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

  def puppet_clothes( timeframe )
    table, puppets = columns_and_rows( timeframe, 'Puppet' )
    table[ 0 ].insert( 1, 'Image' )
    puppets.each do |puppet|
      row = [ puppet, puppet_image( puppet ) ]
      timeframe.timeframes.each_pair do |_scene, hash|
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
    puts_table( table )
    table
  end

  def save( filename )
    file_put_contents( filename, @head + @script + @report )
  end

  def save_html( filename, extra = '' )
    file_put_contents(
      filename,
      @html_head +
        @html_script +
        @html_report +
        extra +
        "</body></html>\n" )
  end
end

# === Class Parser
#   Parser.new( store, qscript, report )
#   Parser.parse_lines( filename, lines )
class Parser
  SIMPLE_MAP = {
    '%AMB%' => [ 'ambience', 'Ambie', Ambience ],
    '%ATT%' => [ 'note', 'Note' ],
    #'%MIX%' => [ 'note', 'Note' ],
    '###' => [ 'note', 'Note' ],
    '%LIG%' => [ 'light', 'Light', Light ],
    '%MUS%' => [ 'ambience', 'Ambie', Ambience ],
    '%SND%' => [ 'sound', 'Sound', Sound ],
    '%VID%' => [ 'video', 'Video', Video ]
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
  end

  def add_backdrop_list( list )
    @qscript.puts_key_list( 'backdrop', list )
    @report.puts_p( [ 'Backd', *list ] )
    @report.html_p( [ 'Backd', *list ] )
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
      @report.puts_p( [ 'Pers+', [ name, key ], val ] )
      @report.html_p( [ 'Pers+', [ name, key ], val ] )
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
      #@report.puts2_key( 'Pers-', "#{name}.#{key}" )
      @report.puts_p( [ 'Pers-', [ name, key ] ] )
      @report.html_p( [ 'Pers-', [ name, key ] ] )
    end

    val = @store.collection[ 'person_clothes' ][ name ]
    @qscript.puts_key( 'clothing-', name, val ) unless val.nil?
    @report.puts2_key( 'Clth-', name, val ) unless val.nil?

    @store.collection[ 'person_old_clothes' ][ name ] = nil
    if @store.collection[ 'owned_props' ].key?( name )
      @store.collection[ 'owned_props' ][ name ].each do |owner|
        next if owner.nil?

        @qscript.puts_key( 'handProp-', name, owner )
        @report.puts2_key( 'HanP-', name, owner )
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
        unless type.nil?
          type.add_play( prop, scene: @store.timeframe.timeframe, hands: hands )
        end
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
    when 'Setting'
      @setting << "\n" + replace_text( line )
    when 'On 2nd rail', 'On playrail', 'Hand props', 'Props'
      [ FrontProp, SecondLevelProp, HandProp, PersonalProp ].each do |type|
        parse_single_prop( line, type.tag, type )
      end
    when 'Stage setup'
      @setting << "\n" + replace_text( line )
      [ 'tec', 'sfx' ].each do |key|
        parse_single_prop( line, key, HandProp )
      end
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
    storekey, qscriptkey, reportkey, timeframekey = names
    HandProp.add_play( prop, scene: @store.timeframe.timeframe, hands: names )
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
    HandProp.add_play( prop, scene: @store.timeframe.timeframe, hands: [] )
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

  def new_stagehand( prop )
    prop.tr( ' ', '_' ).gsub( /^[a-z]|[\s._+-]+[a-z]/, &:upcase ) + '_SH'
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
      qscript_key, result_key, type = val
      case line
      when /^#{key} /
        line.strip!
        text = line.sub( /^#{key}  */, '' )
        storekey = "#{qscript_key}s"
	unless type.nil?
          type.add_play( text, scene: @store.timeframe.timeframe, light: text )
        end
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

  def add_fog( text )
    hand = new_stagehand( 'fog' )
    Actor.add_play( hand, scene: @store.timeframe.timeframe, effect: text, stagehand: true )
    Fog.add_play( text, scene: @store.timeframe.timeframe, stagehand: hand )
    parse_stagehand( hand, text, 'effect', 'Effct' )
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
    @report.puts2_key( 'Note', line )
    @qscript.puts ''
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
    @store.timeframe.add_table( 'props_hands', @scene_props_hands )
    @scene_props = {}
    @scene_props_hands = {}
    @setting = ''
    @report.timeframe_count += 1
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
    when /^[\^] *Role /
      @section = 'Role'
      return true
    when /^\|/ # table data
      return true if @section.nil?

      # p [ 'parse_section', @section, line ]
      @qscript.puts "\t//" + line
      p [ 'parse_section', @section, replace_text( line ) ]
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
              [ new_stagehand( prop ) ]
            end
          p [ '%HND%', props, hands ]
          hands.each do |hand|
            Actor.add_play( hand, scene: @store.timeframe.timeframe, prop: prop, stagehand: true )
            parse_stagehand( hand, text, 'stagehand', 'Stage' )
          end
        end
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
hprops = parser.report.list_hand_props( parser.store.timeframe )
html = parser.report.html_table( table, 'Puppet use' )
clothes = parser.report.html_table( table2, 'Clothes' )
html << clothes
builds.each_pair do |key, h|
  html << parser.report.html_list( 'Builds', key, h, '; ' )
  parser.report.puts_build_list( 'Builds', key, h, '; ' )
end
hprops.each_pair do |key, h|
  html << parser.report.html_table( h, 'Hands' + ' ' + key )
  parser.report.puts_hands_list( 'Hands', key, h )
end

assignments = parser.report.list_people_assignments( parser.store.timeframe )
html << parser.report.html_list( 'All', 'Assignments', assignments )
parser.report.puts_build_list( 'All', 'Assignments', assignments )

style = File.read( 'style.inc' )
file_put_contents( 'clothes.html', style + clothes )
file_put_contents( 'html.html', html )

parser.report.save( 'test.txt' )
parser.report.save_html( 'test.html', html )

# Actor.pp
# Puppet.pp
# Clothing.pp
# Light.pp
# FrontProp.pp
# SecondLevelProp.pp
# Backdrop.pp
# HandProp.pp

# pp Actor.fetch( 'Pan' )
# pp Role.fetch( 'Alice' )

exit 0
# eof
