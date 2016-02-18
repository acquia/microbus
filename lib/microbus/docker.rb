module Microbus
  # Handle creation and execution inside a docker image.
  class Docker
    include Rake::FileUtilsExt

    def initialize(path:, tag:, work_dir:, local_dir:, cache_dir: nil)
      @path = path
      @tag = tag
      @work_dir = work_dir
      @local_dir = local_dir
      # Gather uid and gid so we can match file ownership on Linux hosts.
      @gid = Process::Sys.getegid
      @uid = Process::Sys.geteuid
      @cache_dir = cache_dir
    end

    def prepare
      check_docker
      restore_docker_cache if @cache_dir
      build_docker_image(@path, @tag)
    end

    def run(cmd)
      cmds = [
        # Create a user that matches the current user's UID and GID.
        "groupadd -f -g #{@gid} dgroup",
        "useradd -u #{@uid} -g dgroup duser",
        cmd,
        # chown entire working dir, so that build
        # can be accessed as unprivileged user on Linux.
        "chown -R duser:dgroup #{@work_dir}"
      ]
      docker(cmds.join(' && '))
    end

    def teardown
      update_docker_cache if @cache_dir
    end

    private

    def build_docker_image(path, tag)
      # Use docker to install, building native extensions on an OS similar to
      # our deployment environment.
      sh("docker build -t #{tag} #{path}/.")
    end

    def check_docker
      # Check for docker
      unless system('docker info > /dev/null')
        raise 'Docker is not installed or unavailable.'
      end
    end

    def docker(cmd)
      # Run everything in Docker.
      sh('docker run' \
              ' --interactive=false' \
              ' --rm' \
              " --volume \"#{@local_dir}\":#{@work_dir}" \
              " --workdir #{@work_dir}" \
              " #{@tag}" \
              " bash -l -c '#{cmd}'")
    end

    def docker_cache_filename
      "#{@cache_dir}/image.tar"
    end

    def restore_docker_cache
      FileUtils.mkdir_p(cache_dir)
      if File.exist?(docker_cache_filename)
        sh("docker load < #{docker_cache_filename}")
        @cache_image_id = `docker images -q #{@tag}`.strip!
        puts "Loaded #{@cache_image_id}" if @cache_image_id
      end
    end

    def update_docker_cache
      image_id = `docker images -q #{@tag}`.strip!
      if image_id && image_id != @cache_image_id
        sh("docker save #{@tag} > #{docker_cache_filename}")
        puts "Cached #{image_id}"
      end
    end
  end
end
