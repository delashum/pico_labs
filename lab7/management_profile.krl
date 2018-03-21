ruleset management_profile {
  meta {
    shares __testing, number, send_sms
    provide number, send_sms
    use module io.picolabs.twilio_keys
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
    number = "8013692448"
    from = "3853360777"
    
    send_sms = function(temp) {
      twilio:send_sms(number,from,temp);
    }
  }
}
