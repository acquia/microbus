Feature: build
  As a Ruby application developer
  I want to build my application into a tarball
  So that I can deploy my applications to Linux servers.

  Scenario: Build a basic app (no native extensions)
    Given I use a fixture named "basic-app"
    When I run `rake build`
    Then the output should contain "Created build.tar.gz"
    And the exit status should be 0
    And a file named "build.tar.gz" should exist
