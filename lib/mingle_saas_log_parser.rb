require 'evidence'

class MingleSaasLogParser
  include Evidence

  def sliced_actions_stream(time_window)
    actions_stream | slice_stream(lambda {|action| action[:request][:timestamp]}, time_window)
  end

  def actions_stream
    request_log_stream | rails_action_parser(pid, message) | request_timestamp_parser
  end

  def hourly_logs
    lambda do |output|
      lambda do |dir|
        logs = Dir["#{dir}/*"].select{|f| f=~/mingle-cluster/}.reject(&background_log_files).map do |f|
          stream(File.new(f)) | log_parser(request_log_pattern)
        end
        merge_streams(logs, lambda {|log1, log2| log1[:timestamp] <=> log2[:timestamp]}).each(&output)
      end
    end
  end

  def request_log_stream
    stream(Dir['log/dumpling/*'].sort) | hourly_logs
  end

  def background_log_files
    lambda do |f|
      File.new(f).first(100).any? do |l|
        l =~ background_log_pattern
      end
    end
  end

  def pid
    lambda {|log| "#{log[:host_name]}-#{log[:thread_label]}"}
  end

  def message
    lambda {|log| log[:message]}
  end

  def request_log_pattern
    /^
      \w{3}\s+\d+\s+\d{2}\:\d{2}\:\d{2}\s+
      (?<host_name>[^\s]+)\s+
      [\w-_]+\:\s+
      INFO\s+
      \[(?<timestamp>[^\]]+)\]\s+
      \[(?<thread_label>[^\]]+)\]\s+
      \[(?<log4j_label>[^\]]+)\]\s+
      \[tenant\:(?<tenant>[^\]]*)\]\s+
      (?<message>.*)
    $/x
  end

  def background_log_pattern
    /^
      \w{3}\s+\d+\s+\d{2}\:\d{2}\:\d{2}\s+
      (?<host_name>[^\s]+)\s+
      [\w-_]+\:\s+
      INFO\s+
      \[(?<timestamp>[^\]]+)\]\s+
      \[[\w-_\d]+\[(?<thread_label>[^\]]+)\]\]\s+
      \[(?<log4j_label>[^\]]+)\]\s+
      \[tenant\:(?<tenant>[^\]]*)\]\s+
      (?<message>.*)
    $/x
  end
end
