ruleset manage_sensors {
  meta {
    shares __testing, sensors,get_all_temperatures
    provides sensors, get_all_temperatures
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    use module management_profile alias profile
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
                  
    sensors = function() {
      subscription:established("Tx_role", "sensor")
    }
    
    get_all_temperatures = function() {
      children = sensors();
      child_map = children.collect(function(e){ e{"Tx"}});
      data = child_map.map(function(e) {
        wrangler:skyQuery(
          e[0]{"Tx"},
          "temperature_store",
          "temperatures",
          {},
          e[0]{"Tx_host"}.defaultsTo("http://localhost:8080")
        );
      });
      data
    }
  }
  
  rule new_sensor {
    select when sensor new_sensor
    
    pre {
      eci = meta:eci
      name = event:attrs{"name"}
      exists = ent:sensors.defaultsTo({}) >< name
    }
    if exists then
      send_directive("already exists.", {"name":name})
    notfired {
      ent:sensors := ent:sensors.defaultsTo({}).put(name,eci);
      raise wrangler event "child_creation"
      attributes {
      "name": name,
      "color": "#b56666",
      "rids":["temperature_store","wovyn_base","sensor_profile","io.picolabs.subscription"]
      }
    }
  }
  
  rule on_new_sensor {
    select when wrangler child_initialized
    pre {
      id = event:attrs{"id"}
      eci = event:attrs{"eci"}
      name = event:attrs{"rs_attrs"}{"name"}
    }
    fired {
    raise wrangler event "subscription" attributes
       { "name" : name,
         "Rx_role": "manager",
         "Tx_role": "sensor",
         "channel_type": "subscription",
         "wellKnown_Tx" : eci
       }
    }
  }
  
  rule gen_report {
    select when wovyn gen_report
    pre {
    }
    fired {
      ent:rid := ent:rid.defaultsTo(-1) + 1;
      ent:reports := ent:reports.defaultsTo({}).put(["r"+ent:rid.encode(),"num_responses"],0);
      ent:reports := ent:reports.put(["r"+ent:rid.encode(),"num_children"],sensors().length());
      ent:reports := ent:reports.put(["r"+ent:rid.encode(),"report_id"],"r"+ent:rid.encode());
      raise wovyn event "report_reqs" attributes {
        "id": "r"+ent:rid.encode()
      };
    }
  }
  
  rule send_requests {
    select when wovyn report_reqs
    foreach sensors() setting (subscription)
    pre {
      id = event:attrs{"id"}
    }
    event:send(
      { "eci": subscription{"Tx"}, "eid": id,
        "domain": "sensor", "type": "get_report",
        "attrs": {
          "id": id,
        "eci": meta:eci
        }
      }
    )
  }
  
  rule receive_reports {
    select when wovyn report_results
    pre {
      eci = event:attrs{"eci"}
      id = event:attrs{"id"}
      data = event:attrs{"data"}.klog("DATA")
    }
    fired {
      ent:reports := ent:reports.put([id,"temperatures",eci],data);
      ent:reports := ent:reports.put([id,"num_responses"],ent:reports{id}{"num_responses"}+1);
    }
  }
  
  rule get_reports {
    select when wovyn report
    pre {
      reports = ent:reports.values().reverse();
      short_reports = reports.length() > 4 => reports.slice(4) | reports;
    }
    send_directive("report", {"report": short_reports})
  }
  
  rule on_intro {
    select when wovyn sensor_intro
    pre {
      eci = event:attrs{"eci"}
      name = event:attrs{"name"}.defaultsTo("Nice")
    }
    every {
      event:send({"eci": meta:eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": name,
                   "Rx_role": "manager",
                   "Tx_role": "sensor",
                   "channel_type": "subscription",
                   "wellKnown_Tx": eci,
                   "Tx_host": "http://192.168.1.203:8080"
        }});
    }
  }
  
  rule get_temps {
    select when sensor get_temps
    pre {
      temps = get_all_temperatures()
    }
    send_directive("all temperatures",{"temps":temps})
  }
  
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attrs{"name"}
    }
    fired {
      raise wrangler event "child_deletion"
      attributes {
        "name": name
      }
    }
  }
  
  rule get_threshold {
    select when manager send_sms
    pre {
      data = event:attr{"data"}
    }
    profile:send_sms(data)
  }
  
  rule auto_accept {
  select when wrangler inbound_pending_subscription_added
  fired {
    raise wrangler event "pending_subscription_approval"
      attributes event:attrs
  }
}
}
