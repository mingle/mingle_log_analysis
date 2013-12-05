
desc "output little's law analysis, default timewindow 3600 seconds"
task :littles_law, [:time_window] do |_, args|
  time_window = (args.time_window || 3600).to_i
  stream = MingleSaasLogParser.new.sliced_actions_stream(time_window).map(&Evidence.littles_law_analysis)
  data = stream.map do |stats|
    t1 = stats[:range].min.strftime("%m-%d %H:%M")
    t2 = stats[:range].max.strftime("%H:%M")
    "#{t1}-#{t2} #{stats[:value]}".tap{|r| puts r}
  end
  output('littles_law', data.to_a)
end
