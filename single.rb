#!/usr/local/bin/ruby

# = single.rb
#
# Author::    Dirk Meyer
# Copyright:: Copyright (c) 2020-2026 Dirk Meyer
# License::   Distributes under the same terms as Ruby
#

require 'yaml'
require 'fileutils'

$: << '.'

# wiki config file
CONFIG_FILE = 'wiki-config.yml'.freeze
# list of patterns with different color
# output index for pdf
SINGLE_PDF_INDEX = 'single.wiki'.freeze

# read wiki paths
def read_yaml( filename, default = {} )
  config = default
  return config unless File.exist?( filename )

  config.merge!( YAML.load_file( filename ) )
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

  puts "Write: #{filename}"
  File.open( filename, mode ) do |f|
    f.write( buffer )
    f.close
  end
end

$config = read_yaml( CONFIG_FILE )

namespace = $config[ 'qspath' ].gsub( ':', '%3A' )
url = "https://#{$config[ 'host' ]}/doku.php?id=#{$config[ 'qspath' ]}&do=media&ns=#{namespace}"
wiki = "====== Single Scene Scripts as PDF ======

Get your script via the
[[#{url}||Media_Manager]]

"

@seen = {}
$config[ 'scenes' ].each do |scene|
  next if scene == 'index'

  @seen[ "single_#{scene}.html" ] = true
  @seen[ "single_#{scene}.pdf" ] = true
  wiki << "Script for {{:#{$config[ 'qspath' ]}:single_#{scene}.pdf|#{scene}}}\\\\\n"
end
file_put_contents( SINGLE_PDF_INDEX, wiki )

Dir.glob( 'single_*' ).each do |filename|
  case filename
  when /[.]html$/, /[.]pdf$/
    next if @seen[ filename ]

    puts "removing old file: #{filename}"
    # File.unlink( filename )
  end
end

exit 0
# eof
