# hke/lib/hke/log_helper.rb
require "logger"

module Hke
  class LogHelper
    def self.instance
      @instance ||= new
    end

    def initialize
      @debug = true # Rails.env.development?
      @num_errors = 0
      init_logging "api_import_csv"
    end

    def init_logging(filename)
      log_path_info = Rails.root.join("log", "info_#{filename}.log")
      log_path_error = Rails.root.join("log", "error_#{filename}.log")

      @info_logger = ::Logger.new(log_path_info)
      @error_logger = ::Logger.new(log_path_error)

      [@info_logger, @error_logger].each { |logger| logger.datetime_format = "%Y-%m-%d %H:%M" }
    end

    def log_info(msg)
      puts "@@@ INFO: #{msg}" if @debug
      # @info_logger.info(msg)
      @info_logger&.info(msg)
    end

    def log_error(msg)
      puts "@@@ ERROR: #{msg}" if @debug
      @error_logger&.error(msg)
      @num_errors += 1
    end
  end
end

