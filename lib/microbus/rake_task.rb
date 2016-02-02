require 'bundler/gem_helper'
require 'rake'
require 'rake/tasklib'

module Microbus
  # Provides a custom rake task.
  class RakeTask < Rake::TaskLib
    Options = Struct.new(:build_path, :deployment_path, :docker_path,
                         :docker_image, :filename, :files, :gem_helper,
                         :smoke_test_cmd) do
      class << self
        private :new

        def create(gem_helper, block = nil)
          o = new
          # Set defaults.
          o.build_path = "#{gem_helper.base}/build"
          o.deployment_path = "/opt/#{gem_helper.gemspec.name}"
          o.docker_path = "#{gem_helper.base}/docker"
          o.docker_image = "local/#{gem_helper.gemspec.name}-builder"
          o.filename = ENV['OUTPUT_FILE'] || 'build.tar.gz'
          o.files = gem_helper.gemspec.files
          o.gem_helper = gem_helper
          # Set user overrides.
          block.call(o) if block
          o.freeze
        end
      end
    end

    def initialize(name = :microbus, &block)
      @name = name.to_sym
      @gem_helper = Bundler::GemHelper.new
      @block = block if block_given?
      declare_tasks
    end

    private

    def declare_tasks
      namespace @name do
        declare_build_task
        declare_clean_task
      end
      # Declare a default task.
      desc "Shortcut for #{@name}:build"
      task @name => ["#{@name}:build"]
    end

    def declare_build_task
      desc "Build #{gem_name} tarball"
      task :build do
        Rake::Task["#{@name}:clean"].invoke(false)

        # Copy only files declared in gemspec.
        sh("rsync -R #{opts.files.join(' ')} build")

        check_docker
        build_docker_image

        Dir.chdir(opts.build_path) do
          Bundler.with_clean_env do
            # Package our dependencies, including git dependencies so that
            # docker doesn't need to fetch them all again (or need ssh keys.)
            # Package is much faster than bundle install --path and poses less
            # risk of cross-platform contamination.
            sh('bundle package --all --all-platforms --no-install')
            # Bundle package --all adds a "remembered setting" that causes
            # bundler to keep gems from all groups; delete config to allow
            # bundle install to prune.
            sh('rm .bundle/config')

            # Gather uid and gid so we can match file ownership on Linux hosts.
            gid = Process::Sys.getegid
            uid = Process::Sys.geteuid

            cmds = [
              # Create a user that matches the current user's UID and GID.
              "groupadd -f -g #{gid} dgroup",
              "useradd -u #{uid} -g dgroup duser",
              # @note don't use --deployment because bundler may package OS
              # specific gems, so we allow bundler to fetch alternatives while
              # running in docker if need be.
              # @todo When https://github.com/bundler/bundler/issues/4144
              # is released, --jobs can be increased.
              'bundle install' \
              ' --jobs 1' \
              ' --path vendor/bundle' \
              ' --standalone' \
              ' --binstubs binstubs' \
              ' --without development' \
              ' --clean' \
              ' --frozen',
              # chown all outputs to that user before we return, so that build
              # can be accessed as unprivileged user on Linux.
              "chown -R duser:dgroup #{opts.deployment_path}"
            ]

            cmds << "binstubs/#{opts.smoke_test_cmd}" if opts.smoke_test_cmd

            # Run everything in Docker.
            sh('docker run' \
              " --name #{gem_name}-build" \
              ' --interactive=false' \
              ' --rm' \
              " --volume \"$PWD\":#{opts.deployment_path}" \
              " --workdir #{opts.deployment_path}" \
              " #{opts.docker_image}" \
              " bash -l -c '#{cmds.join(' && ')}'")
          end

          # Make it a tarball - note we exclude lots of redundant files, caches
          # and tests to reduce the size of the tarball.
          sh('tar' \
            ' --exclude="*.c" --exclude="*.h" --exclude="*.o"' \
            ' --exclude="*.gem" --exclude=".DS_Store"' \
            ' --exclude="vendor/bundle/ruby/*[0-9]/gems/*-*[0-9]/ext/"' \
            ' --exclude="vendor/bundle/ruby/*[0-9]/gems/*-*[0-9]/spec/"' \
            ' --exclude="vendor/bundle/ruby/*[0-9]/gems/*-*[0-9]/test/"' \
            ' --exclude="vendor/bundle/ruby/*[0-9]/extensions/"' \
            ' --exclude="vendor/cache/extensions/"' \
            " -czf ../#{opts.filename} *")
        end
      end
    end

    def declare_clean_task
      desc 'Clean build artifacts'
      task :clean, :nuke, :tarball do |_t, args|
        args.with_defaults(nuke: true, tarball: opts.filename)

        # We don't delete the entire vendor so bundler runs faster (avoids
        # expanding gems and compiling native extensions again).
        FileUtils.mkdir('build') unless Dir.exist?('build')
        clean_files = Rake::FileList.new('build/**/*') do |fl|
          fl.exclude('build/vendor')
          fl.exclude('build/vendor/**/*')
        end
        clean_files << args[:tarball]
        clean_files << "#{root}/build/" if args[:nuke]

        FileUtils.rm_rf(clean_files)
      end
    end

    def check_docker
      # Check for docker
      unless system('docker info > /dev/null')
        puts 'Docker is not installed or unavailable.'
        exit 1
      end
    end

    def build_docker_image
      # Use docker to install, building native extensions on an OS similar to
      # our deployment environment.
      sh("docker build -t #{opts.docker_image} #{opts.docker_path}/.")
    end

    def gem_name
      @gem_helper.gemspec.name
    end

    def root
      @gem_helper.base
    end

    # Lazily define opts so we don't slow down other rake tasks.
    # Don't call opts outside a task body.
    def opts
      @opts ||= Options.create(@gem_helper, @block)
    end
  end
end
