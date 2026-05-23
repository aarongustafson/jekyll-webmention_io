# frozen_string_literal: true

require 'socket'
require 'webrick'

module SmokeTest
  # Grab an ephemeral port from the OS and immediately release it. There's a
  # small TOCTOU window before our server claims it, but it's good enough for a
  # localhost test harness and beats hard-coding ports that collide in CI.
  def self.free_port
    socket = TCPServer.new('127.0.0.1', 0)
    socket.addr[1]
  ensure
    socket&.close
  end

  # Shared start/stop plumbing for the throwaway WEBrick servers used by the
  # integration suite. Mixing classes provide a configured @server.
  module ServerControl
    READINESS_TIMEOUT = 5 # seconds

    def start
      @thread = Thread.new { @server.start }
      wait_until_listening
      self
    end

    def stop
      @server&.shutdown
      @thread&.join
    end

    # Quiet WEBrick down -- the suite's output is noisy enough already.
    def self.quiet_options
      { Logger: WEBrick::Log.new(File::NULL), AccessLog: [] }
    end

    private

    # WEBrick binds its listening socket in the constructor, but the accept loop
    # only spins up in #start. Poll a real connection so callers never race the
    # server's first request.
    def wait_until_listening
      deadline = Time.now + READINESS_TIMEOUT

      loop do
        TCPSocket.new('127.0.0.1', @port).close
        return
      rescue Errno::ECONNREFUSED
        raise "server on port #{@port} never came up" if Time.now > deadline

        sleep 0.05
      end
    end
  end
end
