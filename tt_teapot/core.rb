#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new( options )
      w.set_size( 500, 300 )
      w.set_url( "#{url}?plugin=#{File.basename( __FILE__ )}" )
      w.show
      @lib2_update = w
    end
  end
end


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.7.0', 'Teapot' )

# REFERENCES
# * http://www.sjbaker.org/wiki/index.php?title=The_History_of_The_Teapot
# * http://web.cs.wpi.edu/~matt/courses/cs563/talks/surface/bez_surf.html
module TT::Plugins::Teapot

	# Load the datasets
	load File.join( PATH, 'teapot.rb' )
	load File.join( PATH, 'teacup.rb' )
	load File.join( PATH, 'teaspoon.rb' )

	unless file_loaded?( __FILE__ )
		# Commands
		cmd_teapot = UI::Command.new('Teapot') { self.configure_object(@teapot) }
		cmd_teapot.large_icon = File.join(PATH_ICONS, 'teapot_24.png')
		cmd_teapot.small_icon = File.join(PATH_ICONS, 'teapot_16.png')
		cmd_teapot.tooltip = 'Creates a Newell\'s Teapot'
		cmd_teapot.status_bar_text = 'Creates a Newell\'s Teapot'
		
		cmd_teacup = UI::Command.new('Teacup') { self.configure_object(@teacup) }
		cmd_teacup.large_icon = File.join(PATH_ICONS, 'teacup_24.png')
		cmd_teacup.small_icon = File.join(PATH_ICONS, 'teacup_16.png')
		cmd_teacup.tooltip = 'Creates a Newell\'s Teacup'
		cmd_teacup.status_bar_text = 'Creates a Newell\'s Teacup'
		
		cmd_teaspoon = UI::Command.new('Teaspoon') { self.configure_object(@teaspoon) }
		cmd_teaspoon.large_icon = File.join(PATH_ICONS, 'teaspoon_24.png')
		cmd_teaspoon.small_icon = File.join(PATH_ICONS, 'teaspoon_16.png')
		cmd_teaspoon.tooltip = 'Creates a Newell\'s Teaspoon'
		cmd_teaspoon.status_bar_text = 'Creates a Newell\'s Teaspoon'
		
		# Menus
		plugins_menu = UI.menu('Draw')
		teapot_menu = plugins_menu.add_submenu('Teapot')
		teapot_menu.add_item(cmd_teapot)
		teapot_menu.add_item(cmd_teacup)
		teapot_menu.add_item(cmd_teaspoon)
		
		# Toolbar
		toolbar = UI::Toolbar.new('Teapot')
		toolbar.add_item(cmd_teapot)
		toolbar.add_item(cmd_teacup)
		toolbar.add_item(cmd_teaspoon)
		toolbar.show if toolbar.get_last_state == 1

		UI.add_context_menu_handler { |context_menu|
      sel = Sketchup.active_model.selection
      if sel.length == 1
      	entity = sel[0]
      	type = entity.get_attribute(PLUGIN_ID, 'Type')
	      if type && %w[Teapot Teacup Teaspoon].include?(type)
	        context_menu.add_item("Edit #{type}")  { self.edit_object(type) }
	      end
	    end
    }
	end
	
	# Default settings for UI Inputbox'
	@defaults = {}
	
	# Used for profiling
	@timer = []
	
	# Pre Process Patches. Map the vertex indexes to Point3d objects.
	# Generate default values for the UI dialogs.
	def self.pre_process_patches!(patch_object)
		v = patch_object[:vertices]
		
		@defaults[ patch_object[:name] ] = [6, 'Standard', 'Soft + Smooth', 'No']
		patch_object[:parts].each { |key, part|
			@defaults[ patch_object[:name] ] << 'Yes'
			part[:patches].each { |patch|
				patch.map! { |p| v[p] }
			}
		}
	end
	self.pre_process_patches!(@teapot)
	self.pre_process_patches!(@teacup)
	self.pre_process_patches!(@teaspoon)

	
	def self.edit_object(type)
		object = {
			'Teapot'	 => @teapot,
			'Teacup'	 => @teacup,
			'Teaspoon' => @teaspoon
		}[type]
		self.configure_object(object)
	end


	def self.configure_object(patch_object = @teapot)
		model = Sketchup.active_model
		
		type = patch_object[:name]
		defaults = @defaults[type]
		group = nil
		transformation = nil
		smooth_type = {'Hard' => 0, 'Soft' => 4, 'Smooth' => 8, 'Soft + Smooth' => 12}
		
		if model.selection.single_object? && model.selection.first.get_attribute(PLUGIN_ID, 'Type') == type
			group = model.selection.first
			
			defaults = []
			defaults << group.get_attribute(PLUGIN_ID, 'Segments', @defaults[type][0])
			
			value = group.get_attribute(PLUGIN_ID, 'OriginalScale', @defaults[type][1])
			defaults << ( (value) ? 'Original' : 'Standard' )
			
			value = group.get_attribute(PLUGIN_ID, 'Smooth', @defaults[type][2])
			if RUBY_VERSION.to_i > 1
				defaults << smooth_type.key(value) # Ruby 2.0+
			else
				defaults << smooth_type.index(value) # Ruby 1.8
			end

			value = group.get_attribute(PLUGIN_ID, 'Triangulate', @defaults[type][3])
			defaults << ((value) ? 'Yes' : 'No')
			
			patch_object[:parts].each { |key, part|
				value = group.get_attribute(PLUGIN_ID, "P_#{key}", 'Yes')
				defaults << ((value) ? 'Yes' : 'No')
			}

			transformation = group.transformation
		end

		# Prompt for user input
		prompts = ['Segments: ', 'Scale: ', 'Edges: ', 'Triangulate: ']
		list = ['', 'Standard|Original', 'Hard|Soft|Smooth|Soft + Smooth', 'Yes|No']
		patch_object[:parts].each { |key, part|
			prompts << "#{key.to_s.capitalize}: "
			list << 'Yes|No'
		}
		result = UI.inputbox(prompts, defaults, list, type)
		return if result == false # User Cancelled
		
		# Remember last values	
		@defaults[type] = result.clone
		
		# Get general mesh properties
		segments = result.shift
		original_scale = (result.shift == 'Original') ? true : false
		
		smooth = smooth_type[result.shift]
		
		triangulate = (result.shift == 'Yes') ? true : false
		
		# Format values - Build list of parts to generate.
		parts = {}
		patch_object[:parts].each { |key, part|
			parts[key] = (result.shift == 'Yes') ? true : false
		}
		
		# Alert about number of faces, if > 16
		# Complete teapot with 32 segments will generate 32768 faces.
		if segments > 16
			return if UI.messagebox('With such a high segment count, this will take a long time to complete and produce a lot of faces - without giving a notiable better visual result. Are you sure you want to continue?', MB_OKCANCEL) == 2
		end
		# Lets make tea!
		if group.nil?			
			place_tool = PlacePatchTool.new(patch_object, segments, original_scale, parts, smooth, triangulate)
			Sketchup.active_model.tools.push_tool(place_tool)
			#Sketchup.active_model.select_tool(place_tool)
		else
			TT::Model.start_operation("Edit #{patch_object[:name]}")
			group.erase!
			group = self.create_object(patch_object, segments, original_scale, parts, smooth, triangulate)
			group.transformation = transformation
			model.selection.add(group)
			model.commit_operation
		end
	end
	
	
	def self.estimate_point_count(patch_object, segments, parts = Hash.new(true))
		patch_size = (segments+1)**2
		point_count = 0
		patch_object[:parts].each { |key, part|
			point_count += (patch_size * part[:copies] * part[:patches].length) if parts[key]
		}
		return point_count
	end
	
	
	def self.create_object(patch_object = @teapot, segments = 6, original_scale = false, parts = Hash.new(true), smooth = 12, triangulate = false)
		@timer = []
		@timer << "\n--- Generating #{patch_object[:name]} ---\n"
		start_time = Time.now
		
		# Init variables and UI feedback
		model = Sketchup.active_model
		
		#TT::Model.start_operation("Create #{patch_object[:name]}")
		Sketchup.status_text = "Generating #{patch_object[:name]}. Please wait..."
		
		# Generate the groups to add geometry into
		group = model.active_entities.add_group
		group.name = patch_object[:name]
		
		# Estimate the point count
		point_count = self.estimate_point_count(patch_object, segments, parts)
		@timer << "Estimating Point Count: #{point_count}"
		pm = Geom::PolygonMesh.new(point_count)
		
		# Make patches
		patch_object[:parts].each { |key, part|
			self.make_patches(pm, part[:patches], segments, part[:copies], triangulate) if parts[key]
		}
		
		# Scale
		if original_scale
			t = Geom::Transformation.scaling(1.0, 1.0, 1.3)
			pm.transform!(t)
		end
		
		# Insert mesh into the group
		t_mesh = Time.now
		group.entities.fill_from_mesh(pm, true, smooth)
		@timer << "\n> Mesh generated in #{Time.now - t_mesh} seconds"
		@timer << "> #{pm.count_polygons} polygons and #{pm.count_points} points"
		
		# Add attributes
		group.set_attribute(PLUGIN_ID, 'Type', patch_object[:name])
		group.set_attribute(PLUGIN_ID, 'Segments', segments)
		group.set_attribute(PLUGIN_ID, 'OriginalScale', original_scale)
		group.set_attribute(PLUGIN_ID, 'Smooth', smooth)
		group.set_attribute(PLUGIN_ID, 'Triangulate', triangulate)
		patch_object[:parts].each { |key, part|
			group.set_attribute(PLUGIN_ID, "P_#{key.to_s}", parts[key])
		}

		# Complete operation
		#model.commit_operation
		
		feedback = "#{patch_object[:name]} with #{segments} segments generated in #{Time.now - start_time} seconds"
		Sketchup.status_text = feedback
		@timer << feedback
		
		# Output summary to console
		puts @timer.join("\n")
		
		return group
	end
	
	
	def self.make_patches(pm, patches, segments = 3, copies = 1, triangulate = false)
		patches.each { |patch|
			self.make_patch(pm, patch, segments, copies, triangulate)
		}
	end
	
	
	def self.make_patch(pm, patch, segments = 3, copies = 1, triangulate = false)
		# Generate initial patch.
		if segments > 1
			points = TT::Geom3d::Bezier.patch(patch, segments)
		else
			points = patch
		end
		self.patch_to_mesh(pm, points, triangulate)
		# Generate the copies.
		# Four copies means we rotate-copy around ORIGIN
		# Two copies means we mirror the patch.
		if copies == 4
			t_rotate = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)
			3.times {
				points.map! { |p| p.transform(t_rotate) }
				self.patch_to_mesh(pm, points, triangulate)
			}
		elsif copies == 2
			# (!) Must change they way we mirror. This way makes the mirrored patch show the 
			# reverse side out.
			t_mirror = Geom::Transformation.scaling(1, -1, 1)
			points.map! { |p| p.transform(t_mirror) }
			self.patch_to_mesh(pm, points, triangulate, true)
		end
	end
	
	
	# Assume a quadratic set of points
	#
	# Example using a 4x4 set of points:
	#  0  1  2  3
	#  4  5  6  7
	#  8  9 10 11
	# 12 13 14 15
	#
	# Take four points from the set:
	#
	#  0  1
	#  4  5
	#
	# Try to create a quadface if possible, ...
	#
	# 0--1
	# |  |
	# 4--5
	#
	# ... otherwise triangulate.
	# 
	# 0--1    1
	# | /   / |
	# 4    4--5
	#
	# Continue to the next set...
	# 
	#  1  2
	#  5  6
	#
	# ... and repeat.
	#
	# Aruments:
	# * patch is an quadratic array of 3D points.
	# * quads is a boolean that defines if quadfaces should be generated if possible.
	#
	# Returns:
	# * A PolygonMesh on success.
	def self.patch_to_mesh(pm, patch, triangulate = false, mirror = false)
		#puts 'mirror' if mirror
		
		point_index = {}
		patch.each { |i|
			point_index[i] = pm.add_point(i)
		}
		
		# Get the size of the rows/columns.
		size = Math.sqrt(patch.length).to_i
		
		0.upto(size-2) { |i|
			0.upto(size-2) { |j|
				r = i * size # Current row
				
				# Remove all duplicates to avoid errors.
				points = self.point3d_uniq([
						patch[j+r],
						patch[j+1+r],
						patch[j+size+1+r],
						patch[j+size+r]
					])
				
				# Compile array of point indexes.
				indexes = points.collect { |point| point_index[point] }
				indexes.reverse! if mirror

				next unless points.length > 2
				
				if points.length == 3
					pm.add_polygon(indexes)
				else
					# When triangulate is false, try to make quadfaces. Find out if all the points
					# fit on the same plane.
					if triangulate 
						pm.add_polygon([ indexes[0], indexes[1], indexes[2] ])
						pm.add_polygon([ indexes[0], indexes[2], indexes[3] ])
					else
						vector = points[0].vector_to(points[1]) * points[0].vector_to(points[2])
						plane = [ points[0], vector ]
						if points[3].on_plane?(plane)
							pm.add_polygon(indexes)
						else
							pm.add_polygon([ indexes[0], indexes[1], indexes[2] ])
							pm.add_polygon([ indexes[0], indexes[2], indexes[3] ])
						end
					end
				end
			}
		}
	end
	
	# Compare two floats with some tolerance. (Thanks jeff99)
	def self.floats_equal?(float1, float2, epsilon = 0.00000001)
		return (float1 - float2).abs < epsilon
	end

	# Return a set of unique points
	def self.point3d_uniq(points)
		ignore = []
		uniq_points = []
		0.upto(points.length-1) { |pt|
			next if ignore.include?(pt)
			0.upto(points.length-1) { |n|
				next if pt == n || ignore.include?(n)
				#if points[pt].distance(points[n]) == 0.0
				if points[pt] == points[n]
					ignore << n
					break
				end
			}
			uniq_points << points[pt]
		}
		return uniq_points
	end

	
	class PlacePatchTool
	
		def initialize(patch_object, segments, original_scale, parts = Hash.new(true), smooth = 12, triangulate = false)
			# Store values for later when we generate the object.
			@patch_object = patch_object
			@segments = segments
			@original_scale = original_scale
			@parts = parts
			@smooth = smooth
			@triangulate = triangulate
			# Generate preview mesh.
			point_count = PLUGIN.estimate_point_count(patch_object, segments, parts)
			pm = Geom::PolygonMesh.new(point_count)
			patch_object[:parts].each { |key, part|
				PLUGIN.make_patches(pm, part[:patches], 3, part[:copies]) if parts[key]
			}
			# Build the BoundingBox we need for getExtents
			@bb = Geom::BoundingBox.new
			pm.points.each { |p| @bb.add(p) }
			# Build an array with Point3Ds now instead of looking up the points
			# everytime we need to draw the shape.
			@mesh = pm.polygons.collect { |p| p.collect{ |i| pm.point_at(i) } }
		end
		
		def activate
			@state = :pick_origin 
			@origin = nil
		end
		
		def deactivate(view)
			view.invalidate 
		end
		
		def onMouseMove(flags, x, y, view)
			case @state
			when :pick_origin
				@origin = view.inputpoint(x,y)
				view.invalidate
			when :pick_orientation
				@orientation = view.inputpoint(x,y)
				view.invalidate
			end
		end
		
		def onLButtonUp(flags, x, y, view)
			case @state
			when :pick_origin
				@origin = view.inputpoint(x,y)
				@state = :pick_orientation
				view.invalidate
			when :pick_orientation
				# Calculate the transformation to where the mesh should
				# be positioned.
				normal = (@origin.face.nil?) ? Z_AXIS : @origin.face.normal
				x_axis = @origin.position.vector_to(@orientation.position)
				y_axis = x_axis * normal.reverse
				t = Geom::Transformation.new(@origin.position, x_axis, y_axis)
				# Generate the object
				TT::Model.start_operation("Create #{@patch_object[:name]}")
				teapot = PLUGIN.create_object(@patch_object, @segments, @original_scale, @parts, @smooth, @triangulate)
				teapot.transformation = t
				Sketchup.active_model.commit_operation
				# Exit the tool.
				Sketchup.active_model.tools.pop_tool
			end
		end
		
		def draw(view)
			if @state == :pick_origin || @state == :pick_orientation
				return if @origin.nil?
				
				#  Draw the origin and orientation.
				unless @orientation.nil?
					view.set_color_from_line(@origin.position, @orientation.position)
					view.draw_line(@origin.position, @orientation.position)
					@orientation.draw(view)
				end
				@origin.draw(view)
				
				view.drawing_color = 'Purple'
				@mesh.each { |polygon|
					# Calculate Transformation
					normal = (@origin.face.nil?) ? Z_AXIS : @origin.face.normal
					if @orientation.nil? ||
						@origin.position.distance(@orientation.position) == 0.0 ||
						@origin.position.vector_to(@orientation.position).parallel?(normal)
						x_axis = normal.axes.x
						y_axis = normal.axes.y
					else
						x_axis = @origin.position.vector_to(@orientation.position)
						y_axis = x_axis * normal.reverse
					end
					t = Geom::Transformation.new(@origin.position, x_axis, y_axis)
					# Transform
					points = polygon.collect { |p| p.transform(t) }
					# Draw
					view.draw(GL_LINE_LOOP, points)
				}
			end
		end
		
		def getExtents
			return @bb
		end
		
	end # class PlacePatchTool

  ### DEBUG ### ------------------------------------------------------------  
  
  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::AxesTools.reload
  #
  # @param [Boolean] tt_lib Reloads TT_Lib2 if +true+.
  #
  # @return [Integer] Number of files reloaded.
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?( PATH ) && File.exist?( PATH )
      x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
        load file
      }
      x.length + 1
    else
      1
    end
  ensure
    $VERBOSE = original_verbose
  end
  
end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------