ruleset wovyn_base {
  meta {
    shares __testing
    use module io.picolabs.twilio_keys
    use module sensor_profile alias sensor
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "post", "type": "test",
                              "attrs": [ "temp", "baro" ] },
                              {
                                "domain": "wovyn", "type": "threshold_violation"
                              } ] }
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
          "timestamp": time:now(),
          "temperature": data{"temperature"}
        }
    }
  }
  
   rule threshold_notification {
    select when wovyn threshold_violation where event:attr("temperature") > sensor:get_profile(){"threshold"}
    
    pre {
      data = event:attrs
      parent_info = subscription:established("Rx_role", "manager")[0]
    }
    // twilio:send_sms(sensor:get_profile(){"number"},from_number,data{"temperature"});
    event:send({"eci": parent_info{"Tx"}, "eid": "subscription",
        "domain": "manager", "type": "send_sms",
        "attrs": { "data": data
        }})
  }
  
  rule auto_accept {
  select when wrangler inbound_pending_subscription_added
  fired {
    raise wrangler event "pending_subscription_approval"
      attributes event:attrs
  }
}
}