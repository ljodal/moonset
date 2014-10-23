#
# # Generator.rb
#

# This is the main file of the script. It handles reading
# of the configuration file, parsing of all files and
# writing output files.
#
# It requires Redcarpet for rendering Markdown and tilt for
# rendering ERB files. The template files used can be
# changed through the config file,
require 'colorize'
require 'redcarpet'
require 'tilt'

require './lib/moonset/helpers/url'
require './lib/moonset/rocco'
require './lib/moonset/job_manager'

# This is a part of the Moonset module
module Moonset

  # The generator class extends the Redcarpet HTML renderer
  # so that is can handle special URLs
  class Generator < Redcarpet::Render::HTML

    # We need a couple of helpers, these are located in
    # separate modules and included here.
    include URLHelpers

    #
    # Initialize an object of the documentation generator.
    # The passed argument should be a hash of configuration
    # options. See the documentation for possible
    # configuration options.
    #
    def initialize(opts = {})
      # Call super to initialize the Markdown rendering
      super()

      # We also need to know which files have already been
      # rendered, so we have an array for that too. This
      # way we can check if a requested input file has
      # already been rendered
      @rendered_files = []

      # Initialize the Markdown rendering object
      @md = Redcarpet::Markdown.new(self)

      # This is the default rendering template, used for
      # all output files. It includes a header and a footer
      @layout = Tilt.new("./templates/layout.erb")

      # We default to not using workers, this can be
      # changed through the configuration file, see
      # [config.rb](ref:config.rb).
      @use_workers = false
      @worker_count = 2

      # If a configuration file is specified, parse it
      parse_config(opts[:config_file]) if opts[:config_file]

      # We need an empty hash for the files to be parsed
      # During parsing, any new files found will be added
      # to this array and then in turned parsed so that all
      # internal links will be valid
      @manager = JobManager.new use_workers: @use_workers
    end

    def run
      # First parse the menu, and add all files referenced
      # there to the `@files` array.
      parse_menu(@menu_items)

      # Next start parsing all files in the list of files.
      # If any new files are discovered during parsing,
      # e.g. through a ref: link in a file, it will be
      # added to the file list.
      #
      # If use_workers is set to true, we now fork and run
      # multiple threads to process the files.
      if @use_workers
        fork do
          @worker_count.times do
            fork do
              # Connect to the Rinda server
              @manager.connect

              # Parse files
              parse_files

              @manager.disconnect
              exit
            end
          end

          Process.wait
          exit
        end

        # Wait for all child processes to finish their work
        Process.wait

        # Stop the DRb service
        DRb.stop_service
      else
        parse_files
      end
    end

    def erb(template, output, content)
      puts "Writing #{output}"
      f = File.open(output, "w")
      f.write @layout.render(self, {file: output}) {
        Tilt.new("./#{template}.erb").render(self, {content: content})
      }
      f.sync
      f.close
    end

    #
    # Set the items to be shown in the main menu.
    #
    def menu_item(items)
      @menu_items = items
    end

    #
    # Set the directory to write the generated files to
    #
    def output_directory(path)
      @out = path
    end

    #
    # Set the erb file to use for general layout
    #
    def layout_template(path)
      @layout = Tilt.new(path)
    end

    #
    # Use workers. If this is set to truw, the worker will
    # perform a fork and process files in parallel.
    #
    def use_workers(bool)
      @use_workers = bool
    end

    def worker_count(num)
      @worker_count = num
    end

    #
    # ## Markdown rendering overrides
    #

    # We override the link generating code to detect
    # possible internal references, and if so, detect
    # them and add them to the list of tiles
    def link(link, title, content)
      if link.start_with? "ref:"
        input = link[4..-1]
        output = "#{input}.html"

        # Add the file to the list of files to be parsed
        @manager.add_file input, output

        # Change the link location
        link = output
      end

      if title
        "<a title=\"#{title}\" href=\"#{link}\">#{content}</a>"
      else
        "<a href=\"#{link}\">#{content}</a>"
      end
    end


    #
    # Methods below here are defined as private because
    # they should not be callable from the configuration
    # file
    #
    private

    #
    # Parse the configuration file given
    #
    def parse_config(path)
      abort "Configuration doesn't exist." unless File.exists? path

      instance_eval(File.read(path))
    end

    #
    # Parse the menu array. This will add the referenced
    # files to the file array, and add the output files to
    # the menu structure, so they can be referenced
    # correctly when generating files.
    #
    def parse_menu(items)
      # Check that items is an array
      return unless items.is_a? Array

      # Parse each item in the list
      for item in items

        if item[:files]
          # If it's a list of files, parse recursively
          parse_menu(item[:files])
        elsif item[:file]
          output = "#{item[:file]}.html"

          # Add the file to the list of output files.
          @manager.add_file item[:file], output

          # Set the output path of the item
          item[:output] = output
        end
      end
    end

    #
    # Render and write output as long as there's items in
    # the @files array
    #
    def parse_files
      while not @manager.empty?
        # Get the first file from the list
        input, output = @manager.get_file

        unless input and output
          break
        end

        # Check that the file exists
        unless File.exists? input
          print "WARNING: ".yellow
          print "Non-existing file referenced: '#{input}', "
          print "one or more links will be broken!\n"
          next
        end

        # Determine type and then call the parse function
        ext = File.extname(input)
        case ext
        when ".rb"
          render_annotated(input, output, 'ruby')
        when ".md"
          render_markdown(input, output)
        when ".rst"
          puts "reStructuredText file"
        else
          puts "Unknown file type"
        end

        #@rendered_files << file

        puts "Finished processing #{input}"
      end
    end

    def render_markdown(input, output)
      # Print debug information
      print "INFO: ".cyan
      print "Rendering markdown file #{input} to #{output}\n"

      # Render the Markdown content
      content = @md.render(File.read(input))

      # Render the ERB template
      erb("templates/simple", "#{@out}/#{output}", content)
    end

    def render_annotated(input, output, type)
      print "INFO: ".cyan
      print "Rendering #{type} file #{input} to #{output}\n"

      begin
        puts "#{input}"
        rocco = Rocco.new(@md, language: type)

        puts "rocco"
        content = rocco.highlight(rocco.parse(File.read(input)))
        puts "template"

        erb("templates/annotated", "#{@out}/#{output}", content)
      rescue => e
        puts "An error occured"
        puts e
        puts $@
      ensure
        puts "We have now finished #{input}"
      end
    end
  end
end
