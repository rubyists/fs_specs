module CustomMatcher
  def contain_abort_or_goodbye_in(fs_playback_file)
    simple_matcher("contain abort or goodbye in #{fs_playback_file}") do |actual|
      actual.should match("#{expected_playback_file[:abort]}" || "#{expected_playback_file[:abort]}")
    end
  end
end

