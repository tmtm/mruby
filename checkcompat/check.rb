#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'term/ansicolor'

class String
  include Term::ANSIColor
end

$pwd = Dir.pwd
$workdir = File.expand_path(File.dirname($0))

$opts = {}

class Mruby
  def initialize name, url, branch=nil
    @name    = name
    @url     = url
    @branch  = branch

    @dir = File.join($workdir, @name)
    @upadted = false
  end

  attr_reader :dir
  attr_reader :name

  def clean
    system "rm -rf #{@dir}/build" unless $opts[:update]
  end

  def update
    return if @updated
    if Dir.exists? @dir
      Dir.chdir @dir
      system "git pull"
    else
      branch = @branch ? "--branch "+@branch : ""
      system "git clone #{branch} #{@url} #{@dir}"
    end
    @updated = true
  end
end

class Mrbgem
  def initialize name, url, *deps
    @name = name
    @url  = url
    @deps = deps

    @dir = File.join($workdir, @name)
    @updated = false
  end

  def self.new2 repo, *deps
    name = repo.sub(/^.*\//, "")
    url = "git@github.com:#{repo}.git"
    self.new name, url, *deps
  end

  def self.local name, dir, *deps
    g = self.new name, "", *deps
    g.set_dir File.join($pwd, dir)
    g
  end

  attr_reader :deps
  attr_reader :dir
  attr_reader :name

  def set_dir dir
    @dir = dir
  end

  def update
    return if @updated
    if Dir.exists? @dir
      Dir.chdir @dir
      system "git fetch --depth 1 origin"
      system "git checkout master"
    else
      system "git clone --depth 1 #{@url} #{@dir}"
    end
    @updated = true
  end
end

class Build
  def initialize mruby, gem
    @dir = File.join($workdir, "build", mruby.name, gem.name)
    @mruby = mruby
    @gem = gem

    @config_path = File.join(@dir, "build_config.rb")
    @log_all = File.join(@dir, "all.txt")
    @log_test = File.join(@dir, "test.txt")

    FileUtils.makedirs @dir
  end

  attr_reader :config_path
  attr_reader :gem
  attr_reader :log_all
  attr_reader :log_test
  attr_reader :mruby
  attr_reader :result_all
  attr_reader :result_test

  def build
    Dir.chdir @mruby.dir

    env = { "MRUBY_CONFIG" => self.config_path }

    mruby.clean
    #$stdout.write "mruby/#{@gem.name}: rake all..."
    #$stdout.flush
    puts "#{@mruby.name}/#{@gem.name}: rake all"
    File.open(@log_all, "w") { |f|
      pid = Process.spawn(env, "rake all", { 1=>f, 2=>f })
      Process.waitpid pid
      if $?.success?
        @result_all = :success
      else
        @result_all = :failure
      end
    }
    #$stdout.write "mruby/#{@gem.name}: rake all..."
    #$stdout.flush

    puts "#{@mruby.name}/#{@gem.name}: rake test"
    if @result_all
      File.open(@log_test, "w") { |f|
        pid = Process.spawn(env, "rake test", { 1=>f, 2=>f })
        Process.waitpid pid
        if $?.success?
          @result_test = :success
        else
          @result_test = :failure
        end
      }
    else
      @result_test = :skipped
    end
  end

  def write_build_config
    File.open(self.config_path, "w") { |f|
      f.puts "MRuby::Build.new do |conf|"
      f.puts "  toolchain :gcc"
      f.puts "  conf.gembox 'default'"
      if @gem
        @gem.deps.each do |g|
          f.puts "  conf.gem :github => '#{g}'"
        end
        f.puts "  conf.gem '#{@gem.dir}'"
      end
      f.puts "end"
    }
  end
end

opt = OptionParser.new
opt.on('-a', '--all', 'build all combinations.') { |v| $opts[:all] = v }
opt.on('-b MRUBY', '--base MRUBY') { |v| $opts[:base] = v }
opt.on('-g GEM', '--gem GEM') { |v| $opts[:gem] = v }
opt.on('-u', '--update') { |v| $opts[:update] = true }
opt.parse! ARGV

unless $opts[:all] or $opts[:base] or $opts[:gem] or ARGV.size > 0
  puts opt.help
  exit
end


base = []
base << Mruby.new("mruby",  'git@github.com:mruby/mruby.git')
base << Mruby.new("forum",  'git@github.com:mruby-Forum/mruby.git')
base << Mruby.new("iij",    'git@github.com:iij/mruby.git')
base << Mruby.new("stable", 'git@github.com:iij/mruby.git', 'stable_1_0')

mrbgems = []
mrbgems << Mrbgem.new("mruby-digest", 'git@github.com:iij/mruby-digest.git')
mrbgems << Mrbgem.new("mruby-dir", 'git@github.com:iij/mruby-dir.git')
mrbgems << Mrbgem.new("mruby-env", 'git@github.com:iij/mruby-env.git',
                     'iij/mruby-mtest', 'iij/mruby-regexp-pcre')
mrbgems << Mrbgem.new("mruby-errno", 'git@github.com:iij/mruby-errno.git')
mrbgems << Mrbgem.new("mruby-mdebug", 'git@github.com:iij/mruby-mdebug.git')
mrbgems << Mrbgem.new2("iij/mruby-mock")
mrbgems << Mrbgem.new("mruby-iijson", 'git@github.com:iij/mruby-iijson.git')
mrbgems << Mrbgem.new("mruby-io", 'git@github.com:iij/mruby-io.git')
mrbgems << Mrbgem.new("mruby-ipaddr", 'git@github.com:iij/mruby-ipaddr.git',
                      'iij/mruby-io', 'iij/mruby-pack', 'iij/mruby-socket',
                      'iij/mruby-env')
mrbgems << Mrbgem.new2("iij/mruby-pack")
mrbgems << Mrbgem.new2("iij/mruby-pcap")
mrbgems << Mrbgem.new2("iij/mruby-process")
mrbgems << Mrbgem.new2("iij/mruby-regexp-pcre")
mrbgems << Mrbgem.new2("iij/mruby-require", 'iij/mruby-io', 'iij/mruby-dir',
                       'iij/mruby-tempfile')
mrbgems << Mrbgem.new2("iij/mruby-simple-random")
mrbgems << Mrbgem.new2("iij/mruby-socket", 'iij/mruby-io')
mrbgems << Mrbgem.new("mruby-syslog", 'git@github.com:iij/mruby-syslog.git',
                      'iij/mruby-io')
mrbgems << Mrbgem.new2("iij/mruby-tempfile", 'iij/mruby-io', 'iij/mruby-env')

if $opts[:base]
  base.delete_if { |m| m.name != $opts[:base] }
end

if $opts[:gem]
  mrbgems.delete_if { |g| g.name != $opts[:gem] }
end

if ARGV.size > 0
  dir = ARGV.shift
  name = File.basename(dir)
  g = Mrbgem.local name, dir, *ARGV
  mrbgems = [g]
end

base.each do |m|
  puts "* updating #{m.name}/mruby".yellow
  m.update
end

mrbgems.each do |g|
  puts "* updating #{g.name}".yellow
  g.update
end

puts
puts "* Build and test".yellow
builds = []
base.each { |m|
  mrbgems.each { |g|
    b = Build.new m, g
    b.write_build_config
    b.build
    builds << b
  }
}

# show results

def result_to_str result
  case result 
  when :success
    "ok      ".green
  when :failure
    "failed  ".red
  when :skipped
    "skipped ".magenta
  else
    "???     ".on_blue
  end
end

puts
puts "Build Results:".yellow
puts "%-7s %-20s %-8s%s" % [ "mruby", "mrbgem", "build", "test" ]
puts "-" * 40

builds.sort! { |a, b|
  if a.gem.name == b.gem.name
    a.mruby.name <=> b.mruby.name 
  else
    a.gem.name <=> b.gem.name
  end
}
for b in builds
  l =  "%-7s " % b.mruby.name
  l += "%-20s " % b.gem.name
  l += result_to_str(b.result_all) + result_to_str(b.result_test)
  puts l
end
