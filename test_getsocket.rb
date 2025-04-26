#!/usr/bin/env ruby

require 'open3'

# Test Utilities
@tests = 0
@test_description = 0

def try(descr)
  start = Time.now
  @tests += 1
  @test_description = descr
  yield
  delta = format('%.3f', Time.now - start)
  # highlight slow tests
  delta = "\e[7m#{delta}\e[27m" if (Time.now - start) > 0.1
  puts "#{delta}: #{descr}"
end

def eq(result, expected)
  a = result.to_s.gsub(/^/, '> ')
  b = expected.to_s.gsub(/^/, '< ')
  raise "\"#{@test_description}\"\n#{a}\n#{b}" unless result == expected
end

# Setup

puts "\e[32m---\e[39m"

# TCP port selection

try 'Fetch a random, unused port' do
  cmd = './getsocket'
  out, err, status = Open3.capture3(cmd)
  port = out.to_i
  eq (port > 1024 and port <= 65_536), true
  eq err.empty?, true
  eq status.success?, true
end

try 'Ensure a new port is picked each time' do
  cmd = './getsocket'
  out1, _, status1 = Open3.capture3(cmd)
  out2, _, status2 = Open3.capture3(cmd)
  eq (out1 == out2), false
  eq status1.success?, true
  eq status2.success?, true
end

puts "#{@tests} tests PASSED"
