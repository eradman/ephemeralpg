#!/usr/bin/env ruby
#
require 'fileutils'
require 'open3'

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
  _a = "#{a}".gsub /^/, "> "
  _b = "#{b}".gsub /^/, "< "
  raise "\"#{$test_description}\"\n#{_a}\n#{_b}" unless b === a
end

# Setup
ENV['LANG'] = "C"
$altpath = "#{Dir.pwd}/stubs:" + ENV['PATH']
$systmp = %x{ mktemp -d /tmp/ephemeralpg-test.XXXXXX }.chomp
ddlx_path = "#{$systmp}/ddlx.sql"
FileUtils.touch ddlx_path
at_exit { FileUtils.rm_r $systmp }
ENV['DDLX'] = ddlx_path

puts "\e[32m---\e[39m"

# Option Parsing

try "Catch unknown options" do
  cmd = "./ddl_compare -z"
  out, err, status = Open3.capture3(cmd)
  eq out.empty?, true
  eq status.exitstatus, 1
end

try "Not enough arguments" do
  cmd = "./ddl_compare -v a.sql"
  out, err, status = Open3.capture3(cmd)
  eq status.exitstatus, 1
  eq out, ""
end

try "Run with missing Postgres binaries" do
  getopt_path = File.dirname %x{ which getopt }.chomp
  cmd = "./ddl_compare a.sql b.sql"
  out, err, status = Open3.capture3({'PATH'=>"/bin:#{getopt_path}"}, cmd)
  eq err, /.+pg_ctl:.+not found/
  eq out.empty?, true
  eq status.success?, false
end

try "Compare a and b" do
  cmd = "#{Dir.pwd}/ddl_compare a.sql b.sql"
  FileUtils.touch "#{$systmp}/a.sql"
  FileUtils.touch "#{$systmp}/b.sql"
  out, err, status = Open3.capture3({'PATH'=>$altpath, 'DDLX'=>"./ddlx.sql"}, cmd, :chdir=>$systmp)
  eq err, <<-eos
rm -rf _a
psql postgresql://user@127.0.0.1:99/test -q -v ON_ERROR_STOP=1 -f ./ddlx.sql
psql postgresql://user@127.0.0.1:99/test -q -v ON_ERROR_STOP=1 -o /dev/null -f a.sql
psql postgresql://user@127.0.0.1:99/test -q --no-psqlrc -At -c SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name
psql postgresql://user@127.0.0.1:99/test -q --no-psqlrc -At -c SELECT ddlx_script('public.1'::regclass)
rm -rf _b
psql postgresql://user@127.0.0.1:99/test -q -v ON_ERROR_STOP=1 -f ./ddlx.sql
psql postgresql://user@127.0.0.1:99/test -q -v ON_ERROR_STOP=1 -o /dev/null -f b.sql
psql postgresql://user@127.0.0.1:99/test -q --no-psqlrc -At -c SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name
psql postgresql://user@127.0.0.1:99/test -q --no-psqlrc -At -c SELECT ddlx_script('public.1'::regclass)
git diff --color --stat=2040,2000,40 _a/ _b/
  eos
  eq status.success?, true
end

puts "#{$tests} tests PASSED"
