class Boomerang
  module Errors
    class BoomerangError < RuntimeError
      # do nothing:  just creating a base error type
    end
    
    class ConnectionError < BoomerangError
      attr_accessor :original_error
    end
    
    class HTTPError < BoomerangError
      attr_accessor :http_response, :original_error
    end

    class AWSError < BoomerangError
      attr_accessor :other_errors, :request_id
    end
    
    def self.const_missing(error_name)  # :nodoc:
      const_set(error_name, Class.new(AWSError))
    end
  end
end
