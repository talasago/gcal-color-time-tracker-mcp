require 'singleton'
require_relative '../../loggable'

module Infrastructure
  class ConfigurationService
    include Singleton
    include CalendarColorMCP::Loggable
    
    def initialize
      validate_environment
    end
    
    def google_client_id
      @google_client_id ||= ENV.fetch('GOOGLE_CLIENT_ID')
    end
    
    def google_client_secret
      @google_client_secret ||= ENV.fetch('GOOGLE_CLIENT_SECRET')
    end
    
    private
    
    def validate_environment
      missing_vars = []
      
      missing_vars << 'GOOGLE_CLIENT_ID' if env_missing?('GOOGLE_CLIENT_ID')
      missing_vars << 'GOOGLE_CLIENT_SECRET' if env_missing?('GOOGLE_CLIENT_SECRET')
      
      raise_missing_env_error(missing_vars) unless missing_vars.empty?
    end
    
    def env_missing?(var_name)
      ENV[var_name].nil? || ENV[var_name].empty?
    end
    
    def raise_missing_env_error(missing_vars)
      error_msg = build_error_message(missing_vars)
      logger.error error_msg
      raise error_msg
    end
    
    def build_error_message(missing_vars)
      "Missing required environment variables: #{missing_vars.join(', ')}. Please check your .env file."
    end
  end
end