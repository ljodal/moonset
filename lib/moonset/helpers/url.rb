require 'pathname'

module Moonset
  module URLHelpers

    #
    # Return the path to the stylesheet relative to the
    # current file.
    #
    def stylesheet_url(file)
      relative_link(file, "public/style.css")
    end

    #
    # Return a relative path from one file to another.
    #
    def relative_link(file, link)
      f = Pathname.new(file).dirname
      l = Pathname.new("#{@out}/#{link}")
      l.relative_path_from f
    end

    #
    # Check if a path is the current path
    #
    def is_current_path(file, link)
      f = Pathname.new(file).cleanpath
      l = Pathname.new("#{@out}/#{link}").cleanpath
      return f == l
    end
  end
end
