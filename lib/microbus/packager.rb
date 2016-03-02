module Microbus
  # Handle creation of the package.
  class Packager
    include Rake::FileUtilsExt

    attr_reader :opts

    def initialize(opts)
      @opts = opts
    end

    def run # rubocop:disable MethodLength, AbcSize
      # Make it a package - note we exclude lots of redundant files, caches
      # and tests to reduce the size.
      pkg_cmd = ['bundle exec fpm',
                 "--name=#{opts.gem_helper.gemspec.name}",
                 '-s dir',
                 '-t tar',
                 '-C build',
                 '--exclude="**.c" --exclude="**.h" --exclude="**.o"',
                 '--exclude="**.gem" --exclude="**.DS_Store"',
                 '--exclude=".bundle"',
                 '--exclude="vendor/bundle/ruby/*[0-9]/gems/*-*[0-9]/ext"',
                 '--exclude="vendor/bundle/ruby/*[0-9]/gems/*-*[0-9]/spec"',
                 '--exclude="vendor/bundle/ruby/*[0-9]/gems/*-*[0-9]/test"',
                 '--exclude="vendor/bundle/ruby/*[0-9]/extensions"',
                 '--exclude="vendor/cache/extensions"',
                 "--prefix=#{opts.deployment_path}"
                 ]
      pkg_cmd << "--package=#{opts.filename}" if opts.filename
      pkg_cmd << '.'
      sh(pkg_cmd.join(' '))

      puts "Created #{opts.filename}"
      opts.filename
    end
  end
end
