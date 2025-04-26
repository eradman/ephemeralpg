#!/usr/bin/env ruby

require 'fileutils'
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

ENV['LANG'] = 'C'
@altpath = "stubs:#{ENV['PATH']}"
@systmp = `mktemp -d /tmp/ephemeralpg-test.XXXXXX`.chomp
FileUtils.mkdir_p "#{@systmp}/ephemeralpg.XXXXXX/16.3"
FileUtils.touch "#{@systmp}/ephemeralpg.XXXXXX/NEW"
at_exit { FileUtils.rm_r @systmp }

puts "\e[32m---\e[39m"

# Option Parsing

try 'Catch unknown options' do
  cmd = './pg_tmp -t -z'
  out, _, status = Open3.capture3(cmd)
  eq out.empty?, true
  eq status.exitstatus, 1
end

try 'Bogus arguments mixed with valid positional' do
  cmd = './pg_tmp -t -z initdb -w 20'
  out, _, status = Open3.capture3(cmd)
  eq out.empty?, true
  eq status.exitstatus, 1
end

try 'Run with missing Postgres binaries' do
  getopt_path = File.dirname `which getopt`.chomp
  cmd = './pg_tmp'
  out, err, status = Open3.capture3({ 'PATH' => "/bin:#{getopt_path}" }, cmd)
  err.sub!(/.+initdb.+not found/, 'initdb: not found')
  eq err, "initdb: not found\n"
  eq out.empty?, true
  eq status.success?, false
end

# Invocation Traces

try 'Create a new database on disk' do
  cmd = './pg_tmp initdb'
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  err.sub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  out.sub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq out, "#{@systmp}/ephemeralpg.012345\n"
  eq err, <<~COMMANDS
    initdb --nosync -D #{@systmp}/ephemeralpg.012345/16.3 -E UNICODE -A trust
  COMMANDS
  eq status.success?, true
end

try 'Start a new instance with a specified datadir and multiple options' do
  File.write "#{@systmp}/nice.trace", ''
  cmd = "./pg_tmp start -d #{@systmp}/ephemeralpg.XXXXXX -o '-c track_commit_timestamp=true -c shared_buffers=12MB'"
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  out.sub!(/ephemeralpg-test\.[a-zA-Z0-9]{6}%2F/, '')
  eq out, 'postgresql:///test?host=%2Ftmp%2Fephemeralpg.XXXXXX'
  eq err, <<~COMMANDS
    pg_ctl -W -o " -c track_commit_timestamp=true -c shared_buffers=12MB"\
     -s -D #{@systmp}/ephemeralpg.XXXXXX/16.3 -l #{@systmp}/ephemeralpg.XXXXXX/16.3/postgres.log start
    sleep 0.1
  COMMANDS
  eq status.success?, true
  # background tasks kicked off by starting an instance
  nice = File.readlines("#{@systmp}/nice.trace").sort.join
  nice.sub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq nice, <<~COMMANDS
    nice ./pg_tmp -w 60 -d #{@systmp}/ephemeralpg.012345 -p 5432 stop
  COMMANDS
end

try 'Start a new instance on a TCP port using a specified datadir' do
  File.write "#{@systmp}/nice.trace", ''
  cmd = "./pg_tmp start -d #{@systmp}/ephemeralpg.XXXXXX -t"
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  eq out, 'postgresql://user11@127.0.0.1:55550/test'
  eq err, <<~COMMANDS
    pg_ctl -W -o "-c listen_addresses='*' -c port=55550 "\
     -s -D #{@systmp}/ephemeralpg.XXXXXX/16.3 -l #{@systmp}/ephemeralpg.XXXXXX/16.3/postgres.log start
    sleep 0.1
  COMMANDS
  eq status.success?, true
  # background tasks kicked off by starting an instance
  nice = File.readlines("#{@systmp}/nice.trace").sort.join
  nice.sub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq nice, <<~COMMANDS
    nice ./pg_tmp -w 60 -d #{@systmp}/ephemeralpg.012345 -p 55550 stop
  COMMANDS
end

try 'Start a new instance without a pre-initialized datadir' do
  File.write "#{@systmp}/nice.trace", ''
  cmd = './pg_tmp start '
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  out.sub!(/ephemeralpg-test\.[a-zA-Z0-9]{6}%2F/, '')
  out.sub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  err.gsub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq out, 'postgresql:///test?host=%2Ftmp%2Fephemeralpg.012345'
  eq err, <<~COMMANDS
    initdb --nosync -D #{@systmp}/ephemeralpg.012345/16.3 -E UNICODE -A trust
    rm #{@systmp}/ephemeralpg.012345/NEW
    pg_ctl -W -o " " -s -D #{@systmp}/ephemeralpg.012345/16.3 -l #{@systmp}/ephemeralpg.012345/16.3/postgres.log start
    sleep 0.1
  COMMANDS
  eq status.success?, true
  # background tasks kicked off by starting an instance
  nice = File.readlines("#{@systmp}/nice.trace").sort.join
  nice.sub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq nice, <<~COMMANDS
    nice ./pg_tmp -w 60 -d #{@systmp}/ephemeralpg.012345 -p 5432 stop
    nice ./pg_tmp initdb
  COMMANDS
end

try 'Start a new instance and leave server running' do
  File.write "#{@systmp}/nice.trace", ''
  cmd = "./pg_tmp start -d #{@systmp}/ephemeralpg.XXXXXX -w 0"
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  out.sub!(/ephemeralpg-test\.[a-zA-Z0-9]{6}%2F/, '')
  eq out, 'postgresql:///test?host=%2Ftmp%2Fephemeralpg.XXXXXX'
  eq err, <<~COMMANDS
    pg_ctl -W -o " "\
     -s -D #{@systmp}/ephemeralpg.XXXXXX/16.3 -l #{@systmp}/ephemeralpg.XXXXXX/16.3/postgres.log start
    sleep 0.1
  COMMANDS
  eq status.success?, true
  # background tasks kicked off by starting an instance
  nice = File.readlines("#{@systmp}/nice.trace").sort.join
  nice.sub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq nice, ''
end

try 'Start a new instance and keep the tmp datadir' do
  File.write "#{@systmp}/nice.trace", ''
  cmd = "./pg_tmp start -d #{@systmp}/ephemeralpg.XXXXXX -k"
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  out.sub!(/ephemeralpg-test\.[a-zA-Z0-9]{6}%2F/, '')
  eq out, 'postgresql:///test?host=%2Ftmp%2Fephemeralpg.XXXXXX'
  eq err, <<~COMMANDS
    pg_ctl -W -o " "\
     -s -D #{@systmp}/ephemeralpg.XXXXXX/16.3 -l #{@systmp}/ephemeralpg.XXXXXX/16.3/postgres.log start
    sleep 0.1
  COMMANDS
  eq status.success?, true
  # background tasks kicked off by starting an instance
  nice = File.readlines("#{@systmp}/nice.trace").sort.join
  nice.sub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq nice, <<~COMMANDS
    nice ./pg_tmp -k -w 60 -d #{@systmp}/ephemeralpg.012345 -p 5432 stop
  COMMANDS
end

try 'Stop a running instance' do
  File.write "#{@systmp}/ephemeralpg.XXXXXX/16.3/postgresql.conf", ''
  cmd = "./pg_tmp stop -d #{@systmp}/ephemeralpg.XXXXXX"
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  eq out.empty?, true
  eq err, <<~COMMANDS
    sleep 5
    psql test --no-psqlrc -At -c SELECT count(*) FROM pg_stat_activity WHERE datname IS NOT NULL AND state IS NOT NULL;
    pg_ctl -W -D #{@systmp}/ephemeralpg.XXXXXX/16.3 stop
    sleep 1
    rm -r #{@systmp}/ephemeralpg.XXXXXX
  COMMANDS
  eq status.success?, true
end

try 'Stop a running instance and remove tmp datadir' do
  File.write "#{@systmp}/ephemeralpg.XXXXXX/16.3/postgresql.conf", ''
  cmd = "./pg_tmp stop -d #{@systmp}/ephemeralpg.XXXXXX -w 60"
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  eq out.empty?, true
  eq err, <<~COMMANDS
    sleep 60
    psql test --no-psqlrc -At -c SELECT count(*) FROM pg_stat_activity WHERE datname IS NOT NULL AND state IS NOT NULL;
    pg_ctl -W -D #{@systmp}/ephemeralpg.XXXXXX/16.3 stop
    sleep 1
    rm -r #{@systmp}/ephemeralpg.XXXXXX
  COMMANDS
  eq status.success?, true
  File.unlink "#{@systmp}/ephemeralpg.XXXXXX/16.3/postgresql.conf"
end

try 'Stop a running instance if query fails' do
  File.write "#{@systmp}/ephemeralpg.XXXXXX/16.3/postgresql.conf", ''
  File.write "#{@systmp}/ephemeralpg.XXXXXX/STOP", ''
  cmd = "./pg_tmp stop -d #{@systmp}/ephemeralpg.XXXXXX"
  out, err, status = Open3.capture3({ 'PATH' => @altpath }, cmd)
  eq out.empty?, true
  eq err.sub(/on line \d+/, 'on line 100'), <<~COMMANDS
    sleep 5
    pg_ctl -W -D #{@systmp}/ephemeralpg.XXXXXX/16.3 stop
    sleep 1
    rm -r #{@systmp}/ephemeralpg.XXXXXX
  COMMANDS
  eq status.success?, true
  File.unlink "#{@systmp}/ephemeralpg.XXXXXX/16.3/postgresql.conf"
end

try 'Stop a running instance and keep tmp datadir' do
  File.write "#{@systmp}/ephemeralpg.XXXXXX/16.3/postgresql.conf", ''
  cmd = "./pg_tmp stop -k -d #{@systmp}/ephemeralpg.XXXXXX -w 60"
  out, err, status = Open3.capture3({ 'SYSTMP' => @systmp, 'PATH' => @altpath }, cmd)
  eq out.empty?, true
  eq err, <<~COMMANDS
    sleep 60
    pg_ctl -W -D #{@systmp}/ephemeralpg.XXXXXX/16.3 stop
    sleep 1
  COMMANDS
  eq status.success?, true
  File.unlink "#{@systmp}/ephemeralpg.XXXXXX/16.3/postgresql.conf"
end

puts "#{@tests} tests PASSED"
