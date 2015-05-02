require_relative 'notify'

listen to: :test, ignore: /log\/|tmp\// do |result|
  project = File.basename Dir.pwd
  test_output = result.stdout.lines.grep(/assertions,.* failures,.* errors/).first.strip

  title = if result.status.exitstatus == 0
    "✅ tests pass for #{project}"
  else
    "👻 test failures for #{project}"
  end

  notify title: title, message: test_output
end
