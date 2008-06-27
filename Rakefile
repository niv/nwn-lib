require "rake"
require "rake/clean"
require "rake/gempackagetask"
require "rake/rdoctask"
require "fileutils"
include FileUtils

##############################################################################
# Configuration
##############################################################################
NAME = "nwn-gff"
VERS = "0.1"
CLEAN.include ["**/.*.sw?", "pkg", ".config", "rdoc", "coverage"]
RDOC_OPTS = ["--quiet", "--line-numbers", "--inline-source", '--title', \
  'nwn-gff: a ruby library for accessing NWN gff files', \
  '--main', 'README']

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += RDOC_OPTS
  rdoc.rdoc_files.add ["README", "COPYING", "doc/*.rdoc", "lib/**/*.rb"]
end

desc "Packages up nwn-gff"
task :package => [:clean]

spec = Gem::Specification.new do |s|
  s.name = NAME
  s.rubyforge_project = 'nwn-gff'
  s.version = VERS
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README", "COPYING"] + Dir["doc/*.rdoc"]
  s.rdoc_options += RDOC_OPTS + ["--exclude", "^(examples|extras)\/"]
  s.summary = "a ruby library for accessing Neverwinter Nights gff files"
  s.description = s.summary
  s.author = "Bernhard Stoeckner"
  s.email = "elven@swordcoast.net"
  s.homepage = "http://nwn-gff.elv.es"
  s.executables = [""]
  s.required_ruby_version = ">= 1.8.4"
  s.files = %w(COPYING README Rakefile) + Dir.glob("{bin,doc,spec,lib}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
end

Rake::GemPackageTask.new(spec) do |p|
  p.need_tar = true
  p.gem_spec = spec
end

desc "Install nwn-gff gem"
task :install do
  sh %{rake package}
  sh %{sudo gem install pkg/#{NAME}-#{VERS}}
end

desc "Install nwn-gff gem without docs"
task :install_no_docs do
  sh %{rake package}
  sh %{sudo gem install pkg/#{NAME}-#{VERS} --no-rdoc --no-ri}
end

desc "Uninstall nwn-gff gem"
task :uninstall => [:clean] do
  sh %{sudo gem uninstall #{NAME}}
end

desc "Upload nwn-gff gem to rubyforge"
task :release => [:package] do
  sh %{rubyforge login}
  sh %{rubyforge add_release nwn-gff #{NAME} #{VERS} pkg/#{NAME}-#{VERS}.tgz}
  sh %{rubyforge add_file nwn-gff #{NAME} #{VERS} pkg/#{NAME}-#{VERS}.gem}
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
