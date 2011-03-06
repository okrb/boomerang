Boomerang
=========

Boomerang is a library for working through the often very back-and-forth process
of Amazon.com FPS payment transactions.  In particular, this library was
developed for and is most helpful to building "marketplace applications."

Install
-------

If you want to use this code in a Rails application, just add it to your
Gemfile:

    gem "boomerang"

To use the code in a non-Rails application, first install the gem:

    gem install boomerang

Then require the library in your code:

    require "boomerang"

Either way, you will want to setup Boomerang as your application loads.  I
recommend just setting a constant you can then refer to throughout your
application.  In Rails, I would put the following code in
`config/initializers/boomerang.rb`.  Setup is easy, just add you AWS
credentials:

    FPS = Boomerang.new( "ACCESS_KEY_ID",
                         "SECRET_ACCESS_KEY",
                         true )  # use sandbox (false sends to production)

Usage
-----

Boomerang can generate Co-branded UI forms for your views.  These are used to
bounce a user over to Amazon.com to agree to some terms of payment.  Amazon.com
will send them back to the specified `:return_url` with key parameters like 
`tokenID` and `refundTokenID` (for Recipient tokens).

You would create a form for a Recipient token like this:

    <%= FPS.cbui_form( :recipient,
                       return_url:         "http://youapp.com/receive_tokens",
                       caller_reference:   "YOUR_ID_FOR_THE_TRANSACTION",
                       max_fixed_fee:      "10.00",
                       recipient_pays_fee: "True" ) %>

You are free to use any other
[Recipient token parameters](http://docs.amazonwebservices.com/AmazonFPS/latest/FPSAdvancedGuide/index.html?CBUIapiMerchant.html)
in the camelCase Amazon.com expects or in the snake_case more natural to
Rubyists.

A form for a Recurring sender token is similar:

    <%= FPS.cbui_form( :recurring,
                       return_url:         "http://youapp.com/receive_tokens",
                       caller_reference:   "YOUR_ID_FOR_THE_TRANSACTION",
                       recipient_token:    "RECIPIENT_TOKEN",
                       recurring_period:   "1 month",
                       transaction_amount: "100.00" ) %>

Again, use any
[Recurring token parameters](http://docs.amazonwebservices.com/AmazonFPS/latest/FPSAdvancedGuide/index.html?RecurringUseTokenInstallation.html)
in camelCase or snake_case.

As the requests come back to your application, you need to verify the data with
Amazon.com to ensure it has not been tampered with.  Boomerang has a method for
that:

    valid = FPS.verify_signature?( request.url[/\A[^?]+/],  # or :return_url
                                   params )

When the time comes, Boomerang will help you use the various tokens you have
collected to start a payment transaction:

    payment = FPS.pay( caller_reference:      "YOUR_ID_FOR_THE_TRANSACTION",
                       charge_fee_to:         "Recipient",
                       marketplace_fixed_fee: "10.00",
                       recipient_token_id:    "RECIPIENT_TOKEN",
                       sender_token_id:       "RECURRING_TOKEN",
                       transaction_amount:    "100.00" )

The returned `Hash` contains important details like the `:transaction_id` that
you can later use to check up on the payment:

    { :transaction_id     => "AMAZON_PAYMENT_ID",
      :transaction_status => "Pending",
      :request_id         => "AMAZON_REQUEST_ID" }

Finally, you can check up on your payment to see when it clears or is declined:

    status = FPS.get_transaction_status("AMAZON_PAYMENT_ID")

Again, you get a `Hash` with all the key details:

    { :transaction_id     => "AMAZON_PAYMENT_ID",
      :transaction_status => "Success",
      :caller_reference   => "YOUR_ID_FOR_THE_TRANSACTION",
      :status_code        => "Success",
      :status_message     => "HUMAN_READABLE_STATUS_MESSAGE",
      :request_id         => "AMAZON_REQUEST_ID" }
