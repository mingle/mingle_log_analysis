
desc "Show all requests that completed time is larger than given threshold"
task :slow_requests, [:threshold] do |_, args|
  threshold = args.threshold.to_i * 1000
  stream = MingleSaasLogParser.new.actions_stream.select{|a| a[:response][:completed_time].to_i > threshold}.each do |a|
    puts "#{a[:request][:timestamp]} #{a[:request][:controller]}##{a[:request][:action]} => #{a[:response][:completed_time]}"
    puts "\t#{a[:request][:remote_addr]}"
    puts "\t#{a[:response][:url]}"
  end
end

task :apis_sites do
  sum_cta = 0
  all = 0
  MingleSaasLogParser.new.actions_stream.select do |a|
    a[:request][:format] == 'xml'
  end.group_by do |a|
    a[:logs][0][:tenant]
  end.sort_by do |_, actions|
    actions.size
  end.each do |tenant, actions|
    ag = actions.group_by do |a|
      a[:request][:remote_addr] =~ /^72.52.94/ || a[:request][:remote_addr] =~ /^65.49.44/ ? 'CTA' : a[:request][:remote_addr]
    end
    sum_cta += Array(ag['CTA']).size
    all += ag.values.map{|as| as.size}.reduce(:+)
    ags = ag.map do |t, as|
      "#{t}: #{as.size}"
    end
    puts "#{tenant}: #{ags.join("; ")}"
  end
  puts "all: #{all}"
  puts "cta: #{sum_cta}, #{"%.0f%" % (100.0 * sum_cta/all)}"
end

task :requests_by_remote_addr do
  time_window = 3600
  threshold = 600
  sites_data = Hash.new{|h,k| h[k]=0}
  stream = MingleSaasLogParser.new.sliced_actions_stream(time_window).each do |range, actions|
    groups = actions.group_by { |a| a[:request][:remote_addr] }.
      reject{|g, as| as.size < threshold}.
      sort_by {|g, as| as.size}.
      reverse

    puts "#{range} (top 5 > #{threshold} calls): "
    groups.first(5).each do |g, as|
      # next if g == '206.123.77.253'
      sites = as.map{|a|as.first[:logs].first[:tenant]}.uniq.inspect
      actions = as.map{|a|"#{a[:request][:controller]}##{a[:request][:action]}"}
      actions_count = actions.uniq.size
      actions = actions.group_by{|a| a}.map{|a,ag| [a, ag.size]}.sort_by{|a,size| size}.reverse

      as.each do |a|
        sites_data[as.first[:logs].first[:tenant]] += 1
      end

      puts "\t#{g}: #{as.size} requests across #{sites} sites\n\t\tactions (top 5): #{actions.first(5).map{|a| a.join(": ")}.join(", ")}"
    end
  end

  sites_data.to_a.sort_by{|s, c| c}.reverse.each do |s, count|
    puts "#{s}: #{count}"
  end
end
