module Facebooker
  @@logger = nil
  def self.logger=(logger)
    @@logger = logger
  end
  def self.logger
    @@logger
  end

  module Logging
    def self.log_fb_api(method, params)
      message = method # might customize later
      dump = format_fb_params(params)
      if block_given?
        result = nil
        seconds = Benchmark.realtime { result = yield }
        log_info(message, dump, seconds)
        result
      else
        log_info(message, dump)
        nil
      end
    rescue Exception => e
      exception = "#{e.class.name}: #{e.message}: #{dump}"
      log_info(message, exception)
      raise
    end
    
    def self.format_fb_params(params)
      params.map { |key,value| "#{key} = #{value}" }.join(', ')
    end
    
    def self.log_info(message, dump, seconds = 0)
      return unless Facebooker.logger
      log_message = "#{message} (#{seconds}) #{dump}"
      Facebooker.logger.debug(log_message)
    end
    
  end  
end