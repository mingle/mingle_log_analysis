
def warn(msg)
  # puts msg
end

def log_dirs(args)
  args.log_dirs || 'log/dumpling/**/*'
end

def output(name, data)
  FileUtils.mkdir_p('out')
  File.open("out/#{name}", 'w') do |f|
    case data
    when String
      f.write(data)
    when Array
      data.each do |line|
        f.write("#{line}\n")
      end
    else
      raise "Unknown data type #{data.class}"
    end
  end
end
