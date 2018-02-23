ruleset sensor_profile {
  meta {
    shares __testing, get_profile
    provides get_profile
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
                  
    get_profile = function() {
      ent:profile.defaultsTo({
        "name": "Sensor",
        "location": "Everywhere",
        "threshold": 75,
        "number": "8013692448"
      });
    }
    
  }
  
  rule profile_updated {
    select when sensor profile_updated
    pre {
      data = event:attrs
    }
    always {
      ent:profile := {
        "name": data{"name"}.defaultsTo("Sensor"),
        "location": data{"location"}.defaultsTo("Everywhere"),
        "threshold": data{"threshold"}.defaultsTo(75),
        "number": data{"number"}.defaultsTo("8013692448")
      }
    }
  }
  
  rule profile_query {
    select when sensor get_profile
    pre {
      data = event:attrs
    }
    send_directive("profile",{
      "profile": get_profile()
    })
  }
}
