Feature: build
  As a Ruby application developer
  I want to build my application into a tarball
  So that I can deploy my applications to Linux servers.

  Background:
    Given I use a fixture named "basic-app"

  Scenario: Build a basic app (no native extensions)
    When I successfully run `rake build`
    Then the output should contain "Created build.tar.gz"
    And a file named "build.tar.gz" should exist

  Scenario: Build a basic app as a debian package
    Given I append to "Rakefile" with:
    """
    Microbus::RakeTask.new(:deb) do |opts|
      opts.type = :deb
    end
    """
    When I successfully run `rake deb`
    Then the output should contain "Created basic_0.0.1_amd64.deb"
    And a file named "basic_0.0.1_amd64.deb" should exist
