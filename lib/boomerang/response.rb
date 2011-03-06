class Boomerang
  class Response
    def initialize(body)
      @body = body
    end
    
    def parse(prefix, *elements)
      xml = REXML::Document.new(@body)
      parse_and_fail_with_errors_if_any(xml)
      parse_response(xml, prefix, elements)
    end
    
    #######
    private
    #######
    
    def parse_and_fail_with_errors_if_any(xml)
      errors = [ ]
      xml.elements.each("/Response/Errors/Error") do |error|
        if (code    = error.elements["Code"]) and
           (message = error.elements["Message"])
          errors << Errors.const_get(code.text).new(message.text)
        end
      end
      unless errors.empty?
        first_error              = errors.first
        first_error.other_errors = Array(errors[1..-1])
        if node = xml.elements["/Response/RequestID"]
          first_error.request_id = node.text
        end
        fail first_error
      end
    end
    
    def parse_response(xml, prefix, elements)
      Hash[ elements.map { |field|
        if node = xml.elements["#{prefix}#{field}"]
          [Utilities.snake_case(field[/\w+\z/]).to_sym, node.text]
        end
      }.compact ]
    end
  end
end
