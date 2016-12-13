require 'bundler/setup'
require 'English'
require 'json'

# This tool is to be run after a bundle install to remove unused git files.
# We do this by loading bundler it iterating through each git gems gemspec file
# list.
# @note We only use bundler and files available in Ruby standard libs.
class Minimize
  def initialize
    @bundler = Bundler.load
  end

  # Detect full path to git gems.
  def git_dir
    standalone = "#{Gem.dir}/../../../cache"
    dir = File.directory?(standalone) ? standalone : "#{Gem.dir}/bundler/gems"
    Pathname.new(dir).realpath.to_s
  end

  # List all files contained in git gems directory.
  def git_files
    Dir["#{git_dir}/*/**/{.[^\\.]*,*}"].reject do |p|
      File.directory?(p)
    end
  end

  # List all runtime specifications.
  # @return [Array<Gem::Specification>]
  def runtime_specs
    @bundler.specs.materialize(@bundler.dependencies_for(:default))
  end

  # List all files declared by runtime git gem gemspecs.
  def spec_git_files
    spec_git_files = []

    runtime_specs.each do |spec|
      # Check if this is a git gem.
      md = %r{(.+(bundler/gems|vendor/cache)\/.+-[a-f0-9]{7,12})}
           .match(spec.full_gem_path)
      next unless md

      spec_git_files.concat(spec.files.map do |name|
        Pathname.new("#{spec.full_gem_path}/#{name}").realpath.to_s
      end)
    end

    spec_git_files
  end

  # Remove inactive git gem files.
  def clean_git_files
    rm_list = git_files - spec_git_files
    FileUtils.rm_f(rm_list)
    warn "#{File.basename($PROGRAM_NAME)}: Deleted #{rm_list.length} files."
    # Use GNU find to prune empty directories.
    cmd = "find #{git_dir} -type d -empty -delete"
    Kernel.system(cmd)
    return unless $CHILD_STATUS.exitstatus.nonzero?
    raise "#{cmd} exited #{$CHILD_STATUS.exitstatus}"
  end
end

# The big remaining problem... this breaks the build directory.
Minimize.new.clean_git_files
