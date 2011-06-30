#!/usr/bin/env ruby

require 'test/unit'
require 'plist'

class TestBplistParser < Test::Unit::TestCase
  def test_Plist_parse_bplist
    # result = Plist::parse "test/assets/example_data_bin.plist"
    # puts result.inspect

    # result = Plist::parse "test/assets/AlbumData_bin.plist"
    # puts result.inspect
    
    result = Plist::parse "test/assets/Cookies_bin.plist"
    puts result.inspect
  end
  
  def test_Plist_parse_bplist_to_plist
    result = Plist::parse "test/assets/Cookies_bin.plist"
    puts result.to_plist
  end

end

__END__
