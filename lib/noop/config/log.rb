require 'logger'

module Noop
  module Config
    def self.log_destination
      return ENV['SPEC_DEBUG_LOG'] if ENV['SPEC_DEBUG_LOG']
      STDOUT
    end

    def self.log_level
      if ENV['SPEC_TASK_DEBUG']
        Logger::DEBUG
      else
        Logger::WARN
      end
    end

    def self.log
      return @log if @log
      @log = Logger.new log_destination
      @log.level = log_level
      @log.progname = 'noop_manager'
      @log
    end
  end
end
