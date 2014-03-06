#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module Teapot

  ### CONSTANTS ### ------------------------------------------------------------

  # Plugin information
  PLUGIN          = self
  PLUGIN_ID       = File.basename( __FILE__ ).freeze
  PLUGIN_NAME     = 'Teapot'.freeze
  PLUGIN_VERSION  = '1.1.1'.freeze

  # Resource paths
  FILENAMESPACE = File.basename( __FILE__, '.*' )
  PATH_ROOT     = File.dirname( __FILE__ ).freeze
  PATH          = File.join( PATH_ROOT, FILENAMESPACE ).freeze
  PATH_ICONS    = File.join( PATH, 'icons' ).freeze


  ### EXTENSION ### ------------------------------------------------------------

  unless file_loaded?( __FILE__ )
    loader = File.join( PATH, 'core.rb' )
    ex = SketchupExtension.new( PLUGIN_NAME, loader )
    ex.description = 'Utah teapot for SketchUp.'
    ex.version     = PLUGIN_VERSION
    ex.copyright   = 'Thomas Thomassen © 2009-2014'
    ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension( ex, true )
  end

  end # module Teapot
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------
