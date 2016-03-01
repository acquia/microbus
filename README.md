# ![Microbus van](https://cloud.githubusercontent.com/assets/202230/13436627/d753eb9a-dfa5-11e5-8e97-ec3db22846e4.png) Microbus

[![Build Status](https://travis-ci.com/acquia/microbus.svg?token=oagyQubkw12Sp9ziGMif&branch=master)](https://travis-ci.com/acquia/microbus)

Takes a Ruby project and quickly turns it into a small tarball suitable for
deployment to Linux servers.

## Dependencies

  - Docker installed and running.
  - A Dockerfile to create a build environment (default: `./docker/Dockerfile`).
  - A Ruby project with a `.gemspec` and `Gemfile`.
    * NOTE: What is deployed is defined in your gemspec. Make sure spec.files,
      spec.bindir and spec.executables are correct and complete.

## Usage

Microbus provides rake tasks, which may be configured. For example, to create
Microbus' tasks as the `build` namespace, add the following to your `Rakefile`:

```ruby
require 'microbus/rake_task'

Microbus::RakeTask.new(:build) do |opts|
  opts.deployment_path = "/opt/myorg/#{opts.gem_helper.gemspec.name}"
  opts.smoke_test_cmd = 'myapp --help'
end
```

To build, run this in your project's directory:

```
rake build
```

To cleanup, run this in your project's directory:

```
rake build:cleanup
```

## Inspiration

Microbus is a play on [Omnibus](https://github.com/chef/omnibus) with the
intention of being simpler and faster because it creates small tarballs for
configured Linux servers (rather than multi-platform, multi-purpose tools).
Microbus doesn't support arbitrary build environments (VMs), only supports Linux
as a target and doesn't include a Ruby interpreter in it's builds.

## Development

```
bundle install
rake
```

To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/acquia/microbus.


## License

The gem is available as open source under the terms of the
[Apache 2.0](http://opensource.org/licenses/MIT).
