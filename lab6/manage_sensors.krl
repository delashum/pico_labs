ruleset manage_sensors {
  meta {
    shares __testing, sensors,get_all_temperatures
    provides sensors, get_all_temperatures
    use module io.picolabs.wrangler alias wrangler
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
                  
    sensors = function() {
      ent:sensors
    }
    
    get_all_temperatures = function() {
      children = wrangler:children().klog("children");
      child_map = children.collect(function(e){ e{"name"}});
      data = child_map.map(function(e) {
        wrangler:skyQuery(
          e[0]{"eci"},
          "temperature_store",
          "temperatures",
          {}
        );
      });
      data.klog("RETURNNNN")
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
      "rids":["temperature_store","wovyn_base","sensor_profile"]
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
      get_all_temperatures();
      event:send({"eci":eci, "domain":"sensor", "type":"profile_updated", "attrs":{
        "name":name
      }})
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
}
