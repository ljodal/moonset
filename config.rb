#
# # Documentation configuration
#

#
# ## Menu items
#

#
# This specifies the items in the main menu. All items
# should be a hash with two properties; name and file. The
# name should be the display name of the item in the menu
# and the file should be the source file of the target.
#
# You can also create sub-menus by creating an array
# hashes.
#
menu_item [
  {
    name: "Home",
    file: "index.md"
  },
  {
    name: "This script",
    file: "generator.rb"
  },
  {
    name: "API documentation",
    file: "api/index.md"
  },
  {
    name: "Annotated source",
    files: [
      {
        name: "test.rb",
        file: "test.rb"
      }
    ]
  }
]

#
# ## Output directory
#

#
# Set the directory to output the html files to. This
# directory will be created relative to the current
# directory if a full path is not given. Defaults to "doc"
#
output_directory "docs"

#
# ## Workers
#

#
# This will enable workers, allowing multiple processes to
# run in parallel and process files. This way the
# time it takes to generate the output will be greatly
# reduced for larger projects, especially if annotated
# source files are used.
#
use_workers false
worker_count 1
