#!/usr/bin/env ruby

require 'test/unit'
require 'plist'

class TestBplistParser < Test::Unit::TestCase
  def test_Plist_parse_bplist
    result = Plist::parse_bplist("test/assets/example_data_bin.plist")

    puts result.inspect
  end

end

__END__
