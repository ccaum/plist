#!/usr/bin/env ruby

require 'test/unit'
require 'plist'

class TestGeneratorCollections < Test::Unit::TestCase
  def test_array
    expected = <<END
<array>
	<integer>1</integer>
	<integer>2</integer>
	<integer>3</integer>
</array>
END
    expected.gsub!(/\s/, '')

    assert_equal expected, [1,2,3].to_plist(false)
  end

  def test_empty_array
    assert_equal "<array/>", [].to_plist(false)
  end

  def test_hash
    # thanks to recent changes in the generator code, hash keys are sorted before emission,
    # so multi-element hash tests should be reliable.  We're testing that here too.
    # ^ Slow production code, removed sorted keys
    plist = {:foo => :bar, :abc => 123}.to_plist(false)

    assert plist.include?("<key>abc</key><integer>123</integer>")
    assert plist.include?("<key>foo</key><string>bar</string>")
  end

  def test_empty_hash
    assert_equal "<dict/>", {}.to_plist(false)
  end

  def test_hash_with_array_element
    expected = <<END
<dict>
	<key>ary</key>
	<array>
		<integer>1</integer>
		<string>b</string>
		<string>3</string>
	</array>
</dict>
END
    expected.gsub!(/\s/, '')
    assert_equal expected, {:ary => [1,:b,'3']}.to_plist(false)
  end

  def test_array_with_hash_element
    expected = <<END
<array>
	<dict>
		<key>foo</key>
		<string>bar</string>
	</dict>
	<string>b</string>
	<integer>3</integer>
</array>
END
    expected.gsub!(/\s/, '')
    assert_equal expected, [{:foo => 'bar'}, :b, 3].to_plist(false)
  end
end
