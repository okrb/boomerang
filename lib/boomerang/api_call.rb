class Boomerang
  class APICall
    CA_PATH = File.join(File.dirname(__FILE__), *%w[.. .. data ca-bundle.crt])
    
    def initialize(host, action, parameters)
      @host       = host
      @parameters = Utilities.CamelCase(parameters)
                             .merge( "Action"  => Utilities.CamelCase(action),
                                     "Version" => "2008-09-17" )
    end
    
    def sign(access_key_id, secret_access_key)
      signature = Signature.new("GET", @host, @parameters)
      signature.sign(access_key_id, secret_access_key)
      @parameters = signature.signed_fields
    end
    
    def response
      url               = "#{@host}/?#{Utilities.build_query(@parameters)}"
      uri               = URI.parse(url)
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.ca_file      = CA_PATH
      http.verify_mode  = OpenSSL::SSL::VERIFY_PEER
      http.verify_depth = 5
      
      begin
        response = http.start { |session|
          get    = Net::HTTP::Get.new("#{uri.path}?#{uri.query}")
          if (response = session.request(get)).is_a? Net::HTTPSuccess
            begin
              response.body
            rescue StandardError => error
              fail wrap_error( "HTTP",
                               "#{error.message} (#{error.class.name})",
                               http_response:  response,
                               original_error: error )
            end
          else
            fail wrap_error( "HTTP",
                             "#{response.message} (#{response.class.name})",
                             http_response: response )
          end
        }
      rescue Errors::HTTPError
        fail  # pass through already wrapped errors
      rescue StandardError => error
        fail wrap_error( "Connection",
                         "#{error.message} (#{error.class.name})",
                         original_error: error )
      end
    end
    
    #######
    private
    #######
    
    def wrap_error(base, message, additional_fields)
      wrapped_error = Errors.const_get("#{base}Error").new(message)
      additional_fields.each do |field_name, field_data|
        wrapped_error.send("#{field_name}=", field_data)
      end
      wrapped_error
    end
  end
end
