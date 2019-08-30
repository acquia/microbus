require 'bundler/gem_helper'
require 'rake'
require 'rake/tasklib'

require_relative 'docker'
require_relative 'packager'

module Microbus
  # Provides a custom rake task.
  class RakeTask < Rake::TaskLib # rubocop:disable Metrics/ClassLength
    Options = Struct.new(:arch, :build_path, :checksum, :deployment_path,
                         :docker_path, :docker_cache, :docker_image, :filename,
                         :files, :fpm_options, :gem_helper, :minimize, :name,
                         :smoke_test_cmd, :type, :version, :binstub_shebang) do
      class << self
        private :new
        # rubocop:disable MethodLength, AbcSize
        def create(gem_helper, block = nil)
          o = new
          # Set defaults.
          o.name = gem_helper.gemspec.name
          o.version = gem_helper.gemspec.version
          o.build_path = "#{gem_helper.base}/build"
          o.deployment_path = "/opt/#{o.name}"
          o.docker_path = "#{gem_helper.base}/docker"
          o.docker_image = "local/#{o.name}-builder"
          o.filename = ENV['OUTPUT_FILE']
          o.files = gem_helper.gemspec.files
          o.gem_helper = gem_helper
          o.type = :tar
          o.fpm_options = []
          o.arch = nil
          o.minimize = false
          o.checksum = false
          o.binstub_shebang = nil
          # Set user overrides.
          block.call(o) if block
          o.freeze
        end
        # rubocop:enable MethodLength, AbcSize
      end
    end

    def initialize(name = :microbus, gem_name: nil, gem_base: nil, &block)
      @name = name.to_sym
      @gem_helper = Bundler::GemHelper.new(gem_base, gem_name)
      @block = block if block_given?
      declare_tasks
    end

    private

    def declare_tasks
      namespace @name do
        declare_build_task
        declare_clean_task
        declare_arch_task
      end
      # Declare a default task.
      desc "Shortcut for #{@name}:build"
      task @name => ["#{@name}:build"]
    end

    def declare_arch_task # rubocop:disable MethodLength, AbcSize
      desc "Determine #{@gem_helper.gemspec.name} architecture"
      task :arch do
        docker = Docker.new(
          path: opts.docker_path,
          tag: opts.docker_image,
          work_dir: opts.deployment_path,
          local_dir: opts.build_path,
          cache_dir: opts.docker_cache
        )
        docker.prepare
        puts "Detected Architecture: #{docker.architecture(opts.type)}"
        puts 'Set the arch option to override.'
      end
    end

    def declare_build_task # rubocop:disable MethodLength, AbcSize
      desc "Build #{@gem_helper.gemspec.name} tarball"
      task :build do # rubocop:disable Metrics/BlockLength
        Rake::Task["#{@name}:clean"].invoke(false)

        # Copy only files declared in gemspec.
        files = opts.files.map { |file| Shellwords.escape(file) }
        sh("rsync -rR #{files.join(' ')} #{opts.build_path}")
        FileUtils.cp("#{__dir__}/minimize.rb", opts.build_path) if opts.minimize

        docker = Docker.new(
          path: opts.docker_path,
          tag: opts.docker_image,
          work_dir: opts.deployment_path,
          local_dir: opts.build_path,
          cache_dir: opts.docker_cache
        )

        docker.prepare

        Dir.chdir(opts.build_path) do
          Bundler.with_clean_env do
            bundle_package

            # @note don't use --deployment because bundler may package OS
            # specific gems, so we allow bundler to fetch alternatives while
            # running in docker if need be.
            # @todo When https://github.com/bundler/bundler/issues/4144
            # is released, --jobs can be increased.
            cmd =
              'bundle install' \
              ' --jobs 1' \
              ' --path vendor/bundle' \
              ' --standalone' \
              ' --binstubs binstubs' \
              ' --without development' \
              ' --clean' \
              ' --frozen'

            cmd << " --shebang #{opts.binstub_shebang}" if opts.binstub_shebang

            cmd << ' && ruby minimize.rb' if opts.minimize
            cmd << " && binstubs/#{opts.smoke_test_cmd}" if opts.smoke_test_cmd

            docker.run(cmd)
          end
        end

        Packager.new(
          opts,
          arch: opts.arch.nil? ? docker.architecture(opts.type) : opts.arch
        ).run

        docker.teardown
      end
    end

    def bundle_package
      bundle_config = '.bundle/config'
      # The below bundle package --all may fail if a pre-existing bundle
      # config exists.
      File.delete(bundle_config) if File.exist?(bundle_config)
      # Package our dependencies, including git dependencies so that
      # docker doesn't need to fetch them all again (or need ssh keys.)
      # Package is much faster than bundle install --path and poses less
      # risk of cross-platform contamination.
      sh('bundle package --all --all-platforms --no-install')
      # Bundle package --all adds a "remembered setting" that causes
      # bundler to keep gems from all groups; delete config to allow
      # bundle install to prune.
      File.delete(bundle_config) if File.exist?(bundle_config)
    end

    def declare_clean_task # rubocop:disable MethodLength, AbcSize
      desc 'Clean build artifacts'
      task :clean, :nuke, :tarball do |_t, args|
        args.with_defaults(nuke: true, tarball: opts.filename)

        # We don't delete the entire vendor so bundler runs faster (avoids
        # expanding gems and compiling native extensions again).
        FileUtils.mkdir(opts.build_path) unless Dir.exist?(opts.build_path)
        clean_files = Rake::FileList.new("#{opts.build_path}/**/*") do |fl|
          fl.exclude("#{opts.build_path}/vendor")
          fl.exclude("#{opts.build_path}/vendor/**/*")
        end
        clean_files << args[:tarball] if args[:tarball]
        clean_files << "#{opts.build_path}/" if args[:nuke]

        FileUtils.rm_rf(clean_files)
      end
    end

    # Lazily define opts so we don't slow down other rake tasks.
    # Don't call opts outside a task body.
    def opts
      @opts ||= Options.create(@gem_helper, @block)
    end
  end
end
