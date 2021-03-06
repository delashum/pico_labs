ruleset io.picolabs.twilio_v2 {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides send_sms, messages
  }
 
  global {
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }
    
    messages = function(to,from,page=0) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>;
       response = http:get(base_url + "Messages", qs = {
                "from":from,
                "to":to,
                "page":page
            });
       response{"content"};
    }
  }
}