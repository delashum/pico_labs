ruleset gossip_protocol {
  meta {
    shares __testing
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
                  
                  
    getPeer = function() {
      subscriptions = subscription:established("Tx_role", "node");
      
      filtered = subscriptions.filter(function(e) {
        eci = e{"Tx"};
        picoid = engine:getPicoIDByECI(eci);
        ent:peer_seen{picoid}.filter(function(v,k) {
          ent:seen{k}.defaultsTo(0) > v
        }).length() > 0
      });
      
      choosefrom = filtered.length() > 0 => filtered | subscriptions;
      
      choosefrom[random:integer(choosefrom.length()-1)]{"Tx"}
      
    }
    
    prepareMessage = function(state, subscriber,eci) {
      //0 is rumor, 1 is seen
      selection = random:integer(1);
      list = hasnt_seen(ent:peer_seen{engine:getPicoIDByECI(subscriber)});
      message = selection == 0 => list[random:integer(list.length()-1)] | {
        "eci": eci,
        "seen": ent:seen.defaultsTo({})
      };
      {
        "message": message,
        "type": selection == 0 => "rumor" | "seen"
      }
    }
    
    send = defaction(subscriber, msg, type) {
      event:send(
      { "eci": subscriber, "eid": "gossip",
        "domain": "gossip", "type": type,
        "attrs": msg
      })
    }
    
    update = function(msg,subscriber) {
      ent:peer_seen.put([subscriber],ent:peer_seen{subscriber}.put([msg{"SensorID"}],msg{"SeqID"} == ent:peer_seen{subscriber}{msg{"SensorID"}}+1 => msg{"SeqID"} | ent:peer_seen{subscriber}{msg{"SensorID"}}));
    }
    
    update_seen = function() {
      ent:rumors.collect(function(e) {
        e{"SensorID"};
      }).map(function(e) {
        e.map(function(f) {
          f{"SeqID"};
        }).sort("numeric").reduce(function(a,b) {
          a+1 == b => b | a;
        },0);
      }).filter(function(g) {
        g != 0
      });
    }
    
    add_rumor = function(temp,timestamp,picoid,eci) {
      ent:rumors.append({
        "MessageID": [picoid,ent:seqnum].join(":"),
        "SensorID": eci,
        "Temperature": temp,
        "Timestamp": timestamp,
        "SeqID":ent:seqnum
      })
    }
    
    is_duplicate = function(rumor) {
      rumor{"MessageID"}.isnull() || ent:rumors.filter(function(e) {
        e{"MessageID"} == rumor{"MessageID"}
      }).length() > 0
    }
    
    update_peer_seen = function(subscriber,seen) {
      ent:peer_seen.put([subscriber],seen);
    }
    
    hasnt_seen = function(seen) {
      ent:rumors.filter(function(e) {
        seen{e{"SensorID"}}.isnull() || seen{e{"SensorID"}} < e{"SeqID"}
      })
    }
    
    send_many = defaction(messages,subscriber,type) {
      if messages.length() > 0 then
      every {
        send(subscriber,messages[0],type);
        send_many(messages.tail(),subscriber,type);
      }
    }
  }
  
  rule receive_temp {
    select when gossip new
    pre {
      temp = event:attrs{"temperature"}
      timestamp = event:attrs{"timestamp"}
    }
    fired {
      ent:seqnum := ent:seqnum.defaultsTo(0) + 1;
      ent:rumors := ent:rumors.defaultsTo([]);
      ent:rumors := add_rumor(temp,timestamp,meta:picoId,meta:eci);
      ent:seen := update_seen();
    }
  }
  
  rule subscribe {
    select when gossip connect
    pre {
      eci = event:attrs{"eci"}
      name = event:attrs{"name"}.defaultsTo("Lebron")
    }
    fired {
      event:send({"eci": meta:eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": name,
                   "Rx_role": "node",
                   "Tx_role": "node",
                   "channel_type": "subscription",
                   "wellKnown_Tx": eci
                  // "Tx_host": "http://192.168.1.203:8080"
        }});
    }
  }
  
  rule heartbeat {
    select when gossip heartbeat
    pre {
      subscriber = getPeer();
      obj = prepareMessage(state, subscriber, meta:eci);
    }
    if ent:status.defaultsTo(true) then
    every {
      send(subscriber, obj{"message"}, obj{"type"});
    }
    always {
      ent:peer_seen := ent:peer_seen.defaultsTo({});
      ent:peer_seen := ((obj{"type"} == "rumor") => update(obj{"message"},engine:getPicoIDByECI(subscriber)) | ent:peer_seen);
      // schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": 10});
    }
  }
  
  rule seen_message {
    select when gossip seen where ent:status
    pre {
      seen = event:attrs{"seen"}
      should_send = hasnt_seen(seen)
      eci = event:attrs{"eci"}
    }
    send_many(should_send,eci, "rumor");
    fired {
      ent:peer_seen := ent:peer_seen.defaultsTo({});
      ent:peer_seen := update_peer_seen(engine:getPicoIDByECI(eci),seen);
    }
  }
  
  rule rumor_message {
    select when gossip rumor where ent:status
    pre {
      rumor = event:attrs
    }
    if is_duplicate(rumor) then noop();
    notfired {
      ent:rumors := ent:rumors.defaultsTo([]);
      ent:rumors := ent:rumors.append(rumor);
      ent:seen := update_seen();
    }
  }
  
  rule toggle_on_off {
    select when pico switch
    pre {
      current = ent:status.defaultsTo(true)
    }
    fired {
      ent:status := (current => false | true);
    }
  }
}
