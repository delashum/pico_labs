ruleset wovyn_base {
  meta {
    shares __testing
    use module io.picolabs.twilio_keys
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "post", "type": "test",
                              "attrs": [ "temp", "baro" ] },
                              {
                                "domain": "wovyn", "type": "threshold_violation"
                              } ] }
    temperature_threshold = 70
    to_number = "8013692448"
    from_number = "3853360777"
  }
 
  rule process_heartbeat {
    select when wovyn heartbeat where event:attr("genericThing") != null
    pre {
      data = event:attrs
      temp = data{"genericThing"}{"data"}{"temperature"}[0]{"temperatureF"}
    }
    send_directive("heartbeat",{"msg":"heartbeat received","temp":temp})
    fired {
      raise wovyn event "new_temperature_reading" attributes {
        "timestamp": time:now(),
        "temperature": temp
      }
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    
    pre {
      data = event:attrs
      msg = data{"temperature"} > temperature_threshold => "Temperature threshold exceeded" | "Temperature below threshold"
    }
    send_directive("threshold check",{"msg":msg});
    fired {
        raise wovyn event "threshold_violation" attributes {
          "temperature": data{"temperature"}
        }
    }
  }
  
   rule threshold_notification {
    select when wovyn threshold_violation where event:attr("temperature") > 70
    
    pre {
      data = event:attrs.klog();
    }
    twilio:send_sms(to_number,from_number,data{"temperature"});
  }
}