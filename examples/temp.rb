# frozen_string_literal: true

require "debug_me"
include DebugMe

require "rmagick"

image_path = "gen_jack.jpeg"

image = Magick::Image.read(image_path).first

these_methods =
  %i[
    columns
    filename
    filesize
    mime_type
    number_colors
    rows
  ]

these_methods.each do |method|
  print "#{method}: "
  puts image.send(method)
end
