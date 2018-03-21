ruleset temperature_store {
  meta {
    shares __testing, temperatures, threshold_violations, inrange_temperatures
    provides temperatures, threshold_violations, inrange_temperatures
    use module sensor_profile alias sensor
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] };
                  
    temperatures = function() {
      ent:temperatures.defaultsTo([]);
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
      ent:temperatures := ent:temperatures.defaultsTo([]).append({
        "timestamp": timestamp,
        "temperature": temp
      })
    }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation  where event:attr("temperature") > sensor:get_profile(){"threshold"}
    
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
    
    always {
      ent:above_temperatures := [];
      ent:temperatures := [];
    }
  }
  
  rule get_report_data {
    select when sensor get_report
    pre {
      data = temperatures();
      id = event:attrs{"id"};
      eci = event:attrs{"eci"};
    }
    every {
      event:send(
      { "eci": eci, "eid": id,
        "domain": "wovyn", "type": "report_results",
        "attrs": {
          "id": id,
          "data": data,
          "eci": meta:eci
        }
      }
    )
    }
  }
  
  rule get_temperatures {
    select when wovyn get_temps
    
    pre {
      data = temperatures()
      violation_data = threshold_violations()
    }
    
    send_directive("temperatures",{
      "temps": data,
      "violations": violation_data
    })
  }
  
}