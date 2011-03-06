class Boomerang
  module Utilities
    extend self
    
    def camel_case(hash_or_string, first_cap = true)
      if hash_or_string.is_a? Hash
        Hash[hash_or_string.map { |k, v| [camel_case(k, first_cap), v]}]
      else
        string = hash_or_string.to_s
        string = string.gsub(/(\A|\.)[a-z]/) { $&.upcase } if first_cap
        string.gsub(/_([a-z])/) { $1.upcase }
      end
    end
    alias_method :CamelCase, :camel_case
    def camelCase(hash_or_string, first_cap = false)
      camel_case(hash_or_string, first_cap)
    end
    
    def snake_case(hash_or_string)
      if hash_or_string.is_a? Hash
        Hash[hash_or_string.map { |k, v| [snake_case(k), v]}]
      else
        hash_or_string.to_s
                      .gsub(/([a-z])([A-Z])/) { "#{$1}_#{$2.downcase}" }
                      .downcase
      end
    end
    
    def utf8(string)
      string.to_s.encode(Encoding::UTF_8)
    end
    
    def url_encode(string)
      string.chars
            .map { |char| char =~ /\A[-A-Za-z0-9_.~]\z/ ?
                          char                          :
                          char.bytes.map { |byte| "%%%02X" % byte }.join }
            .join
    end
    
    def build_query(parameters)
      parameters.map { |k, v| "#{url_encode k}=#{url_encode v}" }.join("&")
    end
  end
end
