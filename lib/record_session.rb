require "optparse"
require "pty"
require "json"
require 'termios'

LFLAG_MASK = ~(Termios::ISIG   |
               Termios::ICANON |
               Termios::IEXTEN |
               Termios::ECHO   |
               Termios::ECHOE  |
               Termios::ECHOK  |
               Termios::ECHONL) 

IFLAG_MASK = ~(Termios::IGNBRK | 
               Termios::BRKINT | 
               Termios::PARMRK | 
               Termios::ISTRIP | 
               Termios::INLCR  | 
               Termios::IGNCR  |
               Termios::ICRNL  |
               Termios::IXON)

class RecordSession

  UTF = Encoding.find "utf-8"

  def initialize(argv = ARGV)
    parse_options(argv)
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
    @last_time = timestamp
    master, slave = PTY.open
    setup_tty(slave) do
      output_pid = fork do
        Signal.trap("CHLD") do
          master.close
        end
        fork do
          master.close
          Process.setsid
          slave.ioctl(536900705, 0)

          handle_shell(slave)
        end
        STDIN.close
        slave.close
        handle_output(master)
      end
      input_pid = fork do 
        slave.close
        handle_input(master)
      end
      Process.wait(output_pid)
      Process.kill("KILL", input_pid)
      Process.wait(input_pid)
    end
    puts "Session recorded to #@outfile_name"
  end

  def setup_tty(slave)
    save_state = Termios.tcgetattr(STDIN)
    Termios.tcsetattr(slave, Termios::TCSAFLUSH, save_state)

    new_state = save_state.clone

    new_state.iflag &= 0#IFLAG_MASK
    new_state.lflag &= LFLAG_MASK
    new_state.oflag = Termios::OPOST
    new_state.cflag &= ~(Termios::CSIZE || Termios::PARENB)
    new_state.cflag |= Termios::CS8
    new_state.cc[Termios::VINTR]  =
    new_state.cc[Termios::VQUIT]  =
    new_state.cc[Termios::VERASE] =
    new_state.cc[Termios::VKILL]  = Termios::POSIX_VDISABLE
    new_state.cc[Termios::VEOF]   = 1
    new_state.cc[Termios::VEOL]   = 0
    Termios::tcsetattr(STDIN, Termios::TCSAFLUSH, new_state)

    begin
      yield save_state
    ensure
      Termios.tcsetattr(STDIN, Termios::TCSAFLUSH, save_state)
    end
  end
    
  def handle_shell(slave)
    STDIN.reopen(slave)
    STDOUT.reopen(slave)
    STDERR.reopen(slave)
    slave.close

    shell = ENV["SHELL"] || "/bin/sh"
    opts = ["-i" ]
    if shell =~ /zsh/
      opts << "+o" << "prompt_sp"
    end
    exec(shell, *opts)
  end

  def handle_input(master)
    master.syswrite("tput clear\n")
    loop do
      data = STDIN.sysread(1000)
      master.syswrite(data)
    end
  rescue SystemCallError 
    raise
  rescue EOFError
    # exit
  end

  class Result
    def initialize(terminal_size)
      @stream = []
      @result = { size: terminal_size, stream: @stream }
    end

    def add_output(delay, chars)
      if delay <= 0 && @stream.size > 0
        @stream.last[:val] << chars
      else
        @stream << { t: "op", d: delay, val: chars }
      end
    end

    def write(outfile_name)
      File.open(outfile_name, "w:utf-8") do |op|
        op.puts("the_recording_data(")
        op.puts(JSON.generate(@result))
        op.puts(")")
      end
    end

  end

  def handle_output(master)
    STDOUT.sync = true
    result = Result.new(terminal_size)

    begin
      loop do
        data = master.sysread(1000)
        data.force_encoding(UTF)
        STDOUT.write(data)
        time = timestamp
        result.add_output(time - @last_time, data)
        @last_time = time
      end
    rescue EOFError, Errno::EBADF
      result.write(@outfile_name)
    rescue Exception => e
      STDERR.puts e.inspect
    end
  end


  def log_data(data)
    @outfile.syswrite(JSON.generate([timestamp - @start_time, data]))
    @outfile.syswrite("\n")
  end

  def timestamp
    (Time.now.to_r * 1000).to_i
  end
  

  def terminal_size
    IO.console.winsize
  rescue
    [80, 25]
  end

  def display_help_and_exit
    STDERR.puts %{
   
       record_session [ -o output_file ]

     Record a terminal session to output_file (default terminal.record).
     %}  

    exit(1)
  end
end

