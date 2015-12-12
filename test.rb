#!/usr/bin/env ruby
require "open3"

# Test Utilities
$tests = 0
$test_description = 0

def try(descr)
  start = Time.now
  $tests += 1
  $test_description = descr
  yield
  delta = "%.3f" % (Time.now - start)
  puts "#{delta}: #{descr}"
end

def eq(a, b)
  raise "\"#{$test_description}\"\n#{a} != #{b}" unless a === b
end

# Setup
$altpath = "stubs:" + ENV['PATH']
$systmp = `mktemp -d /tmp/ephemeralpg-test.XXXXXX`.chomp
`mkdir -p #{$systmp}/ephemeralpg.XXXXXX/9.4`
`touch #{$systmp}/ephemeralpg.XXXXXX/NEW`
at_exit { `rm -r #{$systmp}` }

$usage_text = \
    "release: 1.7\n" +
    "usage: pg_tmp [-w timeout] [-t] [-o options]\n"

# TCP port selection

try "Fetch a random, unused port" do
  cmd = "./getsocket"
  out, err, status = Open3.capture3(cmd)
  port = out.to_i
  eq (port > 1024 and port <= 65536), true
  eq err.empty?, true
  eq status.success?, true
end

try "Ensure a new port is picked each time" do
  cmd = "./getsocket"
  out1, err1, status1 = Open3.capture3(cmd)
  out2, err2, status2 = Open3.capture3(cmd)
  eq (out1 == out2), false
  eq status1.success?, true
  eq status2.success?, true
end

# Option Parsing

try "Catch unknown options" do
  cmd = "./pg_tmp -t -z"
  out, err, status = Open3.capture3(cmd)
  eq "getopt: unknown option -- z\n" + $usage_text, err
  eq out.empty?, true
  eq status.success?, false
end

try "Bogus arguments mixed with valid positional" do cmd = "./pg_tmp -t -z initdb -w 20"
  out, err, status = Open3.capture3(cmd)
  eq "getopt: unknown option -- z\n" + $usage_text, err
  eq out.empty?, true
  eq status.success?, false
end

try "Run with missing Postgres binaries" do
  cmd = "./pg_tmp"
  out, err, status = Open3.capture3({'PATH'=>"/bin:/usr/bin"}, cmd)
  eq /.+initdb: not found/, err
  eq out.empty?, true
  eq status.success?, false
end

# Invocation Traces

try "Create a new database on disk" do
  cmd = "./pg_tmp initdb"
  out, err, status = Open3.capture3({'SYSTMP'=>$systmp, 'PATH'=>$altpath}, cmd)
  err.gsub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  out.gsub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq out, "#{$systmp}/ephemeralpg.012345\n"
  eq err, <<-eos
initdb --nosync -D #{$systmp}/ephemeralpg.012345/9.4 -E UNICODE -A trust
  eos
  eq status.success?, true
end

try "Start a new instance" do
  cmd = "./pg_tmp start -d #{$systmp}/ephemeralpg.XXXXXX"
  out, err, status = Open3.capture3({'SYSTMP'=>$systmp, 'PATH'=>$altpath}, cmd)
  out.gsub!(/ephemeralpg-test\.[a-zA-Z0-9]{6}%2F/, '')
  eq out, "postgresql://%2Ftmp%2Fephemeralpg.XXXXXX/test"
  eq err, <<-eos
rm #{$systmp}/ephemeralpg.XXXXXX/NEW
pg_ctl -o -s -D #{$systmp}/ephemeralpg.XXXXXX/9.4 -l #{$systmp}/ephemeralpg.XXXXXX/9.4/postgres.log start
sleep 0.1
  eos
  eq status.success?, true
end

try "Stop a running instance" do
  cmd = "./pg_tmp stop -d #{$systmp}/ephemeralpg.XXXXXX"
  out, err, status = Open3.capture3({'PATH'=>$altpath}, cmd)
  eq out.empty?, true
  eq err, <<-eos
sleep 60
psql test -At -c SELECT count(*) FROM pg_stat_activity;
pg_ctl -D #{$systmp}/ephemeralpg.XXXXXX/9.4 stop
sleep 2
  eos
  eq status.success?, true
end

try "Stop a running instance and remove tmp datadir" do
  `touch #{$systmp}/ephemeralpg.XXXXXX/9.4/postgresql.auto.conf`
  cmd = "./pg_tmp stop -d #{$systmp}/ephemeralpg.XXXXXX"
  out, err, status = Open3.capture3({'PATH'=>$altpath}, cmd)
  eq out.empty?, true
  eq err, <<-eos
sleep 60
psql test -At -c SELECT count(*) FROM pg_stat_activity;
pg_ctl -D #{$systmp}/ephemeralpg.XXXXXX/9.4 stop
sleep 2
rm -rf #{$systmp}/ephemeralpg.XXXXXX
  eos
  eq status.success?, true
  `rm #{$systmp}/ephemeralpg.XXXXXX/9.4/postgresql.auto.conf`
end

puts "\n#{$tests} tests PASSED"

