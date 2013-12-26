require "optparse"
require "pty"
require "json"

class RecordSession

  UTF = Encoding.find "utf-8"

  def initialize(argv = ARGV)
    parse_options(argv)
    @outfile = File.open(@outfile_name, "w:utf-8")
    @outfile.syswrite("session = {\nsize: #{terminal_size.inspect},\n")
    @outfile.syswrite("data: [\n")
  end

  def parse_options(argv)
    @outfile_name = "terminal.record"
    options = OptionParser.new do |opts|
      opts.banner = "usage: record_teminal [ -o output_file ]"

      opts.on("-o", "--output-to [name]",
              "Where to record session (default: terminal.record)") do |name|
        @outfile_name = name
      end

      opts.on("-h", "--help",
              "Display usage information") do 
        display_help_and_exit
      end
    end

    options.parse!(argv)
  end

  def record
    @start_time = timestamp
    master, slave = PTY.open
    setup_tty do
#      Process.daemon
      output_pid = fork do
        Signal.trap("CHLD") do
          @outfile.syswrite "]}\n"
          @outfile.close
          exit
        end
        fork do
          master.close
          handle_shell(slave)
        end
        handle_output(master)
      end
      input_pid = fork do 
        handle_input(master)
      end
      Process.wait(output_pid)
      Process.kill("KILL", input_pid)
      Process.wait(input_pid)
    end
    puts "Session recorded to #@outfile_name"
  end

  def setup_tty
    save_state = %x{stty -g}
    %x{stty raw}
    begin
      yield
    ensure
      %x{stty "#{save_state}"}
    end
  end
    
  def handle_shell(slave)
    shell = ENV["SHELL"] || "/bin/sh"
    
    @outfile.close
    STDIN.reopen(slave)
    STDOUT.reopen(slave)
    STDERR.reopen(slave)
    slave.close
    exec(shell, "-i")
  end

  def handle_input(master)
    @outfile.close
    loop do
      data = STDIN.sysread(1000)
      master.syswrite(data)
    end
  rescue SystemCallError 
    raise
  rescue EOFError
    # exit
  end

  def handle_output(master)
    STDOUT.sync = true
    loop do
      data = master.sysread(1000).force_encoding(UTF)
      STDOUT.write(data)
      log_data(data)
    end
  rescue SystemCallError 
    raise
  rescue EOFError
    @outfile.close
  end

  def log_data(data)
    @outfile.syswrite(JSON.generate([timestamp - @start_time, data]))
    @outfile.syswrite("\n")
  end

  def timestamp
    (Time.now.to_r * 1000).to_i
  end
  

  # From Gabriel Horner  (cldwalker)
  def terminal_size
    if (ENV['COLUMNS'] =~ /^\d+$/) && (ENV['LINES'] =~ /^\d+$/)
      return [ENV['COLUMNS'].to_i, ENV['LINES'].to_i]
    elsif (RUBY_PLATFORM =~ /java/ || (!STDIN.tty? && ENV['TERM'])) && command_exists?('tput')
      [`tput cols`.to_i, `tput lines`.to_i]
    elsif STDIN.tty? && command_exists?('stty')
      `stty size`.scan(/\d+/).map { |s| s.to_i }.reverse
    else
      nil
    end
  rescue
    nil
  end

  def display_help_and_exit
    STDERR.puts %{
   
       record_session [ -o output_file ]

     Record a terminal session to output_file (default terminal.record).
     %}  

    exit(1)
  end
end

