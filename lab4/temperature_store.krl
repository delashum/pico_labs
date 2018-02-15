ruleset temperature_store {
  meta {
    shares __testing, temperatures, threshold_violations, inrange_temperatures
    provides temperatures, threshold_violations, inrange_temperatures
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] };
                  
    temperatures = function() {
      ent:temperatures;
    }
    
    threshold_violations = function() {
      ent:above_temperatures;
    }
    
    inrange_temperatures = function(thresh) {
      temperature_arr = temperatures();
      temperature_arr.filter(function(x) {x{"temperature"} < thresh})
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre {
      data = event:attrs
      timestamp = data{"timestamp"}
      temp = data{"temperature"}
    }
    always {
      ent:temperatures.defaultsTo([]);
      ent:temperatures := ent:temperatures.append({
        "timestamp": timestamp,
        "temperature": temp
      })
    }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    
    pre {
      data = event:attrs
      timestamp = data{"timestamp"}
      temp = data{"temperature"}
    }
    
    always {
      ent:above_temperatures.defaultsTo([]);
      ent:above_temperatures := ent:above_temperatures.append({
        "timestamp": timestamp,
        "temperature": temp
      })
    }
  }
  
   rule clear_temeratures {
    select when sensor reading_reset
    
    send_directive("logging ent variables", {
      "temperatures": temperatures(),
      "above_threshold": threshold_violations(),
      "below_threshold": inrange_temperatures(75)
    });
    
    always {
      ent:above_temperatures := [];
      ent:temperatures := [];
    }
  }
}