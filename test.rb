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
  # highlight slow tests
  delta = "\e[7m#{delta}\e[27m" if (Time.now - start) > 0.1
  puts "#{delta}: #{descr}"
end

def eq(a, b)
  _a = "#{a}".gsub /^/, "\e[33m> "
  _b = "#{b}".gsub /^/, "\e[36m< "
  raise "\"#{$test_description}\"\n#{_a}\e[39m#{_b}\e[39m" unless b === a
end

# Setup
$altpath = "stubs:" + ENV['PATH']
$systmp = `mktemp -d /tmp/ephemeralpg-test.XXXXXX`.chomp
`mkdir -p #{$systmp}/ephemeralpg.XXXXXX/9.4`
`touch #{$systmp}/ephemeralpg.XXXXXX/NEW`
at_exit { `rm -r #{$systmp}` }

$usage_text = \
    "release: 2.0\n" +
    "usage: pg_tmp [-w timeout] [-t] [-o extra-options] [-d datadir]\n"

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
  eq err.gsub(/invalid|illegal/,'unknown').gsub('\'', ''),
    "getopt: unknown option -- z\n" + $usage_text
  eq out.empty?, true
  eq status.success?, false
end

try "Bogus arguments mixed with valid positional" do
  cmd = "./pg_tmp -t -z initdb -w 20"
  out, err, status = Open3.capture3(cmd)
  eq err.gsub(/invalid|illegal/,'unknown').gsub('\'', ''),
    "getopt: unknown option -- z\n" + $usage_text
  eq out.empty?, true
  eq status.success?, false
end

try "Run with missing Postgres binaries" do
  cmd = "./pg_tmp"
  out, err, status = Open3.capture3({'PATH'=>"/bin:/usr/bin"}, cmd)
  eq err, /.+initdb:.+not found/
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

try "Start a new instance with a specified datadir and multiple options" do
  `: > #{$systmp}/nice.trace`
  cmd = "./pg_tmp start -d #{$systmp}/ephemeralpg.XXXXXX -o '-c track_commit_timestamp=true -c shared_buffers = 12MB'"
  out, err, status = Open3.capture3({'SYSTMP'=>$systmp, 'PATH'=>$altpath}, cmd)
  out.gsub!(/ephemeralpg-test\.[a-zA-Z0-9]{6}%2F/, '')
  eq out, "postgresql:///test?host=%2Ftmp%2Fephemeralpg.XXXXXX"
  eq err, <<-eos
rm #{$systmp}/ephemeralpg.XXXXXX/NEW
pg_ctl -o " -c track_commit_timestamp=true -c shared_buffers = 12MB"\
 -s -D #{$systmp}/ephemeralpg.XXXXXX/9.4 -l #{$systmp}/ephemeralpg.XXXXXX/9.4/postgres.log start
sleep 0.1
  eos
  eq status.success?, true
  # background tasks kicked off by starting an instance
  nice = `cat #{$systmp}/nice.trace | sort`
  nice.gsub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq nice, <<-eos
nice ./pg_tmp -w 60 -d #{$systmp}/ephemeralpg.012345 -p 5432 stop
  eos
end

try "Start a new instance on a TCP port using a specified datadir" do
  `: > #{$systmp}/nice.trace`
  cmd = "./pg_tmp start -d #{$systmp}/ephemeralpg.XXXXXX -t"
  out, err, status = Open3.capture3({'SYSTMP'=>$systmp, 'PATH'=>$altpath}, cmd)
  eq out, "postgresql://127.0.0.1:55550/test"
  eq err, <<-eos
rm #{$systmp}/ephemeralpg.XXXXXX/NEW
pg_ctl -o "-c listen_addresses='127.0.0.1' -c port=55550 "\
 -s -D #{$systmp}/ephemeralpg.XXXXXX/9.4 -l #{$systmp}/ephemeralpg.XXXXXX/9.4/postgres.log start
sleep 0.1
  eos
  eq status.success?, true
  # background tasks kicked off by starting an instance
  nice = `cat #{$systmp}/nice.trace | sort`
  nice.gsub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq nice, <<-eos
nice ./pg_tmp -w 60 -d #{$systmp}/ephemeralpg.012345 -p 55550 stop
  eos
end

try "Start a new instance without a pre-initialized datadir" do
  `: > #{$systmp}/nice.trace`
  cmd = "./pg_tmp start "
  out, err, status = Open3.capture3({'SYSTMP'=>$systmp, 'PATH'=>$altpath}, cmd)
  out.gsub!(/ephemeralpg-test\.[a-zA-Z0-9]{6}%2F/, '')
  out.gsub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  err.gsub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq out, "postgresql:///test?host=%2Ftmp%2Fephemeralpg.012345"
  eq err, <<-eos
initdb --nosync -D #{$systmp}/ephemeralpg.012345/9.4 -E UNICODE -A trust
rm #{$systmp}/ephemeralpg.012345/NEW
pg_ctl -o " " -s -D #{$systmp}/ephemeralpg.012345/9.4 -l #{$systmp}/ephemeralpg.012345/9.4/postgres.log start
sleep 0.1
  eos
  eq status.success?, true
  # background tasks kicked off by starting an instance
  nice = `cat #{$systmp}/nice.trace | sort`
  nice.gsub!(/ephemeralpg\.[a-zA-Z0-9]{6}/, 'ephemeralpg.012345')
  eq nice, <<-eos
nice ./pg_tmp -w 60 -d #{$systmp}/ephemeralpg.012345 -p 5432 stop
nice ./pg_tmp initdb
  eos
end

try "Stop a running instance" do
  `touch #{$systmp}/ephemeralpg.XXXXXX/9.4/postgresql.conf`
  cmd = "./pg_tmp stop -d #{$systmp}/ephemeralpg.XXXXXX"
  out, err, status = Open3.capture3({'SYSTMP'=>$systmp, 'PATH'=>$altpath}, cmd)
  eq out.empty?, true
  eq err, <<-eos
sleep 0
psql test -At -c SELECT count(*) FROM pg_stat_activity;
pg_ctl -D #{$systmp}/ephemeralpg.XXXXXX/9.4 stop
sleep 1
rm -r #{$systmp}/ephemeralpg.XXXXXX
  eos
  eq status.success?, true
end

try "Stop a running instance and remove tmp datadir" do
  `touch #{$systmp}/ephemeralpg.XXXXXX/9.4/postgresql.conf`
  cmd = "./pg_tmp stop -d #{$systmp}/ephemeralpg.XXXXXX -w 60"
  out, err, status = Open3.capture3({'SYSTMP'=>$systmp, 'PATH'=>$altpath}, cmd)
  eq out.empty?, true
  eq err, <<-eos
sleep 60
psql test -At -c SELECT count(*) FROM pg_stat_activity;
pg_ctl -D #{$systmp}/ephemeralpg.XXXXXX/9.4 stop
sleep 1
rm -r #{$systmp}/ephemeralpg.XXXXXX
  eos
  eq status.success?, true
  `rm #{$systmp}/ephemeralpg.XXXXXX/9.4/postgresql.conf`
end

try "Stop a running instance if query fails" do
  `touch #{$systmp}/ephemeralpg.XXXXXX/9.4/postgresql.conf`
  `touch #{$systmp}/ephemeralpg.XXXXXX/STOP`
  cmd = "./pg_tmp stop -d #{$systmp}/ephemeralpg.XXXXXX"
  out, err, status = Open3.capture3({'PATH'=>$altpath}, cmd)
  eq out.empty?, true
  eq err.gsub(/on line \d+/, 'on line 100'), <<-eos
sleep 0
pg_ctl -D #{$systmp}/ephemeralpg.XXXXXX/9.4 stop
sleep 1
rm -r #{$systmp}/ephemeralpg.XXXXXX
  eos
  eq status.success?, true
  `rm #{$systmp}/ephemeralpg.XXXXXX/9.4/postgresql.conf`
end

puts "\n#{$tests} tests PASSED"

