class Boomerang
  class Signature
    SHA1_ALGORITHM   = OpenSSL::Digest::Digest.new("sha1")
    SHA256_ALGORITHM = OpenSSL::Digest::Digest.new("sha256")
    
    def initialize(http_verb, url, parameters, algorithm = SHA256_ALGORITHM)
      @fps        = !!(url =~ /\bfps\b/)
      @http_verb  = http_verb
      @url        = URI.parse(url)
      @parameters = parameters.merge(
        Utilities.camel_case(
          { :signature_version => "2",
            :signature_method  => algorithm == SHA256_ALGORITHM ?
                                  "HmacSHA256"                  :
                                  "HmacSHA1" },
          fps?
        )
      )
      if fps?
        @parameters["Timestamp"] = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      end
      @algorithm  = algorithm
      @signature  = nil
    end
    
    def sign(access_key_id, secret_access_key)
      @parameters[ fps? ? "AWSAccessKeyId" :
                          "callerKey" ] = access_key_id
      @signature                        = hash(secret_access_key)
    end
    
    def signed_fields
      @parameters.merge(Utilities.camel_case(:signature, fps?) => @signature)
    end
    
    #######
    private
    #######
    
    def fps?
      @fps
    end
    
    def canonicalized_query_string
      @parameters.keys
                 .map(&Utilities.method(:utf8))
                 .sort
                 .map { |name| [
                   Utilities.url_encode(name),
                   Utilities.url_encode(Utilities.utf8(@parameters[name]))
                 ].join("=") }
                 .join("&")
    end
    
    def value_of_host_header_in_lowercase
      @url.host
    end
    
    def http_request_uri
      path = @url.path
      path.nil? || path.empty? ? "/" : path
    end
    
    def string_to_sign
      [ @http_verb,
        value_of_host_header_in_lowercase,
        http_request_uri,
        canonicalized_query_string ].join("\n")
    end
    
    def hash(secret_access_key)
      [ OpenSSL::HMAC.digest( @algorithm,
                              secret_access_key,
                              string_to_sign ) ].pack("m").chomp
    end
  end
end
