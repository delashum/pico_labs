ruleset io.picolabs.use_twilio_v2 {
  meta {
    use module io.picolabs.twilio_keys
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
  }
 
  rule test_send_sms {
    select when test new_message
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
 
  rule test_get_sms {
    select when test get_message
    pre {
      response = twilio:messages(event:attr("to").defaultsTo(""),
                    event:attr("from").defaultsTo(""),
                    event:attr("page").defaultsTo(0)
                   );
    }
    send_directive(response);
  }
}