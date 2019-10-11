#!/usr/bin/env ruby
#
# Copyright (c) 2019 Eric Radman <ericshane@eradman.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require 'json'

def usage
  $stderr.puts "usage: flattenjs < input"
  exit(1)
end

color = $stdout.isatty
usage if ARGV.pop
usage if $stdin.isatty

json_in = ""
while path = $stdin.gets
  json_in << path
end

h = JSON.parse(json_in)

# from https://stackoverflow.com/a/10715242/1809872
module Enumerable
  def flatten_with_path(parent_prefix = nil)
    res = {}

    self.each_with_index do |elem, i|
      if elem.is_a?(Array)
        k, v = elem
      else
        k, v = i, elem
      end

      # assign key name for result hash
      key = parent_prefix ? "#{parent_prefix},#{k}" : k

      if v.is_a? Enumerable
        # recursive call to flatten child elements
        res.merge!(v.flatten_with_path(key))
      else
        res[key] = v
      end
    end

    res
  end
end

h.flatten_with_path.each do |path, value|
  if color
    puts "{#{path}} \e[37m#{value}\e[39m"
  else
    puts "{#{path}} #{value}"
  end
end

