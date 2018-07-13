require 'digest'
require 'fpm'
require 'fpm/command'

module Microbus
  # Handle creation of the package.
  class Packager
    include Rake::FileUtilsExt

    attr_reader :opts, :arch

    def initialize(opts, arch:)
      @opts = opts
      @arch = arch
      # Default filename for tar because fpm chooses compression by filename
      # and for backwards compatibility.
      @filename = opts.filename
      @filename ||= 'build.tar.gz' if opts.type == :tar
      # Don't include the prefix for tar for backwards compatibility. Prefix
      # might be a bad idea for tar regardless.
      @prefix = opts.type == :tar ? nil : opts.deployment_path
    end

    def run # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      # Make it a package - note we exclude lots of redundant files, caches
      # and tests to reduce the size.
      fpm_opts = [
        "--name=#{opts.name}",
        "--version=#{opts.version}",
        '-s dir',
        "-t #{opts.type}",
        "-C #{opts.build_path}",
        "-a #{arch}",
        '-x **/*.gem',
        '-x **/*.c',
        '-x **/*.h',
        '-x **/*.o',
        '-x **/.DS_Store',
        '-x **/*.bundle',
        '-x vendor/bundle/ruby/*[0-9]/gems/*-*[0-9]/spec',
        '-x vendor/bundle/ruby/*[0-9]/gems/*-*[0-9]/test',
        '-x vendor/cache/extensions',
        '--force'
      ]
      fpm_opts << "--prefix=#{@prefix}" if @prefix
      fpm_opts << "--package=#{@filename}" if @filename
      fpm_opts.concat(opts.fpm_options)

      file = fpm('.', fpm_opts)

      puts "Created #{file}"
      write_checksum && validate_checksum_file if opts.checksum
      file
    end

    private

    def checksum
      Digest::MD5.file(@filename).hexdigest
    end

    # Generates a checksum of the build file and writes it to a new file.
    #
    # @return [String] MD5 checksum.
    def write_checksum
      File.write(checksum_file, checksum)
      puts "Created #{checksum_file}"
    end

    def validate_checksum_file
      raise 'Unexpected checksum file contents' \
        unless checksum == File.read(checksum_file)
    end

    def checksum_file
      @checksum_file ||= begin
        ext = opts.type == :tar ? '.tar.gz' : File.extname(@filename)
        basename = File.basename(@filename, ext)
        "#{basename}.md5"
      end
    end

    def fpm(args, opts = [])
      fpm_events = []
      Cabin::Channel.get.subscribe(fpm_events)

      args = "#{opts.join(' ')} #{args}"
      warn "fpm #{args}"
      code = ::FPM::Command.new('fpm').run(args.split(' '))
      raise 'fpm exited nonzero' unless code.zero?
      event = fpm_events.find do |e|
        e[:message] == 'Created package'
      end
      event.fetch(:path)
    end
  end
end
