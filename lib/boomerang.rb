require "erb"
require "net/https"
require "openssl"
require "rexml/document"
require "uri"

require "boomerang/errors"
require "boomerang/utilities"
require "boomerang/signature"
require "boomerang/api_call"
require "boomerang/response"

class Boomerang
  VERSION   = "0.0.3"
  ENDPOINTS = { cbui:         "https://authorize.payments.amazon.com/" +
                              "cobranded-ui/actions/start",
                cbui_sandbox: "https://authorize.payments-sandbox.amazon.com/" +
                              "cobranded-ui/actions/start",
                fps:          "https://fps.amazonaws.com",
                fps_sandbox:  "https://fps.sandbox.amazonaws.com" }
  PIPELINES = %w[ SingleUse     MultiUse Recurring Recipient SetupPrepaid
                  SetupPostpaid EditToken ]
  
  def initialize(access_key_id, secret_access_key, use_sandbox)
    @access_key_id     = access_key_id
    @secret_access_key = secret_access_key
    @use_sandbox       = use_sandbox
  end
  
  def use_sandbox?
    @use_sandbox
  end
  alias_method :using_sandbox?, :use_sandbox?
  
  def cbui_form(pipeline, parameters)
    submit_tag = parameters.delete(:submit_tag) || %Q{<input type="submit">}
    pipeline   = Utilities.CamelCase(pipeline)
    parameters = Utilities.camelCase(parameters).merge(
      "version"      => "2009-01-09",
      "pipelineName" => pipeline
    )
    fail ArgumentError, "parameters must be a Hash" unless parameters.is_a? Hash
    unless PIPELINES.include? pipeline
      choices = "#{PIPELINES[0..-2].join(', ')}, or #{PIPELINES[-1]}"
      fail ArgumentError, "pipline must be one of #{choices}"
    end
    unless parameters["returnUrl"]
      fail ArgumentError, "returnUrl is a required parameter"
    end
    required_fields = case pipeline
                      when "Recipient"
                        %w[callerReference recipientPaysFee]
                      when "Recurring"
                        %w[callerReference recurringPeriod transactionAmount]
                      when "SingleUse"
                        %w[callerReference recipientToken transactionAmount]
                      when "MultiUse"
                        %w[callerReference globalAmountLimit recipientTokenList]
                      end
    required_fields.each do |required_field|
      unless parameters[required_field]
        fail ArgumentError, "#{required_field} is a required parameter"
      end
    end
    
    if pipeline == "MultiUse" and
       parameters["recipientTokenList"].is_a? Array
      parameters["recipientTokenList"] =
        parameters["recipientTokenList"].join(",")
    end

    url        = ENDPOINTS[use_sandbox? ? :cbui_sandbox : :cbui]
    signature  = Signature.new("GET", url, parameters)
    signature.sign(@access_key_id, @secret_access_key)
    
    form = %Q{<form action="#{url}" method="GET">}
    signature.signed_fields.each do |name, value|
      form << %Q{<input type="hidden" } +
              %Q{name="#{ERB::Util.h name}" value="#{ERB::Util.h value}">}
    end
    form << %Q{#{submit_tag}</form>}
  end
  
  def pay(parameters)
    %w[marketplace_fixed_fee transaction_amount].each do |amount|
      if dollars = parameters.delete(amount.to_sym)
        parameters["#{amount}.currency_code"] = "USD"
        parameters["#{amount}.value"]         = dollars
      end
    end
    parameters = Utilities.CamelCase(parameters)
    %w[ CallerReference SenderTokenId TransactionAmount.CurrencyCode
        TransactionAmount.Value ].each do |required_field|
      unless parameters[required_field]
        fail ArgumentError, "#{required_field} is a required parameter"
      end
    end
    
    call = APICall.new( ENDPOINTS[use_sandbox? ? :fps_sandbox : :fps],
                        :pay,
                        parameters )
    call.sign(@access_key_id, @secret_access_key)

    Response.new(call.response)
            .parse( "/xmlns:PayResponse/",
                    "PayResult/TransactionId",
                    "PayResult/TransactionStatus",
                    "ResponseMetadata/RequestId" )
  end
  
  def get_transaction_status(transaction_id)
    call = APICall.new( ENDPOINTS[use_sandbox? ? :fps_sandbox : :fps],
                        :get_transaction_status,
                        transaction_id: transaction_id )
    call.sign(@access_key_id, @secret_access_key)

    Response.new(call.response)
            .parse( "/xmlns:GetTransactionStatusResponse/",
                    "GetTransactionStatusResult/TransactionId",
                    "GetTransactionStatusResult/TransactionStatus",
                    "GetTransactionStatusResult/CallerReference",
                    "GetTransactionStatusResult/StatusCode",
                    "GetTransactionStatusResult/StatusMessage",
                    "ResponseMetadata/RequestId" )
  end
  
  def verify_signature?(url, parameters)
    parameters = parameters.is_a?(Hash) ? Utilities.build_query(parameters) :
                                          parameters.to_s

    call = APICall.new( ENDPOINTS[use_sandbox? ? :fps_sandbox : :fps],
                        :verify_signature,
                        url_end_point:   url,
                        http_parameters: parameters )

    parsed = Response.new(call.response)
                     .parse( "/xmlns:VerifySignatureResponse/",
                             "VerifySignatureResult/VerificationStatus",
                             "ResponseMetadata/RequestId" )
    parsed[:verification_status] == "Success"
  end
end
