require "minitest/autorun"
require_relative "../lib/fly-ruby"

ENV["TESTING"] = "1"

class FlyTest < Minitest::Test
  def test_configuration
    assert_kind_of Fly::Configuration, Fly.configuration
  end

  def test_configuration_can_be_reset
    old_configuration = Fly.configuration
    Fly.configuration = nil

    assert_kind_of Fly::Configuration, Fly.configuration
    refute_same old_configuration, Fly.configuration
  end

  def test_configure
    configuration_from_block = nil
    Fly.configure { |configuration| configuration_from_block = configuration }

    assert_same Fly.configuration, configuration_from_block
  end

  def test_configure_preserves_configuration
    configuration_before_block = Fly.configuration
    Fly.configure { }

    assert_same configuration_before_block, Fly.configuration
  end
end
