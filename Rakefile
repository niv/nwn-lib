require "rake"
require "rake/clean"
require "rake/gempackagetask"
require "hanna/rdoctask" rescue require "rake/rdoctask"
require "fileutils"
include FileUtils

##############################################################################
# Configuration
##############################################################################
NAME = "nwn-lib"
VERS = "0.4.9"
CLEAN.include ["**/.*.sw?", "pkg", ".config", "rdoc", "coverage"]
RDOC_OPTS = ["--quiet", "--line-numbers", "--inline-source", '--title', \
  'nwn-lib: a ruby library for accessing NWN resource files', \
  '--main', 'README']

DOCS = ["README", "BINARIES", "HOWTO", "SCRIPTING", "SETTINGS", "CHEATSHEET", "CHANGELOG", "COPYING"]

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += RDOC_OPTS
  rdoc.rdoc_files.add DOCS + ["doc/*.rdoc", "lib/**/*.rb"]
end

desc "Packages up nwn-lib"
task :package => [:clean]

spec = Gem::Specification.new do |s|
  s.name = NAME
  s.rubyforge_project = 'nwn-lib'
  s.version = VERS
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = DOCS + Dir["doc/*.rdoc"]
  s.rdoc_options += RDOC_OPTS + ["--exclude", "^(examples|extras)\/"]
  s.summary = "a ruby library for accessing Neverwinter Nights resource files"
  s.description = s.summary
  s.author = "Bernhard Stoeckner"
  s.email = "elven@swordcoast.net"
  s.homepage = "http://nwn-lib.elv.es"
  s.executables = ["nwn-gff", "nwn-erf", "nwn-dsl", "nwn-irb"]
  s.required_ruby_version = ">= 1.8.4"
  s.files = %w(COPYING CHANGELOG README Rakefile) + Dir.glob("{bin,doc,spec,lib,tools,scripts,data}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
end

Rake::GemPackageTask.new(spec) do |p|
  p.need_tar = true
  p.gem_spec = spec
end

desc "Install nwn-lib gem"
task :install do
  sh %{rake package}
  sh %{sudo gem1.8 install pkg/#{NAME}-#{VERS}}
end

desc "Install nwn-lib gem without docs"
task :install_no_docs do
  sh %{rake package}
  sh %{sudo gem1.8 install pkg/#{NAME}-#{VERS} --no-rdoc --no-ri}
end

desc "Uninstall nwn-lib gem"
task :uninstall => [:clean] do
  sh %{sudo gem1.8 uninstall #{NAME}}
end

desc "Upload nwn-lib gem to rubyforge"
task :release => [:package] do
  sh %{rubyforge login}
  sh %{rubyforge add_release nwn-lib #{NAME} #{VERS} pkg/#{NAME}-#{VERS}.tgz}
  sh %{rubyforge add_file nwn-lib #{NAME} #{VERS} pkg/#{NAME}-#{VERS}.gem}
end

require "spec/rake/spectask"

desc "Run specs with coverage"
Spec::Rake::SpecTask.new("spec") do |t|
  t.spec_files = FileList["spec/*_spec.rb"]
  t.spec_opts  = File.read("spec/spec.opts").split("\n")
  t.rcov_opts  = File.read("spec/rcov.opts").split("\n")
  t.rcov = true
end

desc "Run specs without coverage"
task :default => [:spec_no_cov]
Spec::Rake::SpecTask.new("spec_no_cov") do |t|
  t.spec_files = FileList["spec/*_spec.rb"]
  t.spec_opts  = File.read("spec/spec.opts").split("\n")
end

desc "Run rcov only"
Spec::Rake::SpecTask.new("rcov") do |t|
  t.rcov_opts  = File.read("spec/rcov.opts").split("\n")
  t.spec_opts  = File.read("spec/spec.opts").split("\n")
  t.spec_files = FileList["spec/*_spec.rb"]
  t.rcov = true
end

desc "check documentation coverage"
task :dcov do
  sh "find lib -name '*.rb' | xargs dcov"
end
