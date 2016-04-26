module dscord.gateway.events;

import std.variant,
       std.stdio,
       std.algorithm,
       std.string;

import dscord.gateway.client,
       dscord.gateway.packets,
       dscord.types.all;

class Event {
  Client client;
  JSONObject payload;

  this(Client c, Dispatch d) {
    this.client = c;
    this.payload = d.data;
  }
}

/*
Object eventToClass(string event) {
  auto parts = event.split("_").map!(capitalize).join("");
  auto name = "dscord.gateway.events." ~ parts;
  writeln(name);
  return Object.factory(parts);
}
*/

Object eventToClass(string name) {
  switch (name) {
    case "READY":
      return typeid(Ready);
    case "GUILD_CREATE":
      return typeid(GuildCreate);
    default:
      return null;
  }
}

// authors note: pretty sure I'm high as fuck right now
string eventName(string clsName) {
  string[] parts;

  string piece = "";
  foreach (chr; clsName) {
    if (chr == chr.toUpper && piece.length > 0) {
      parts ~= piece;
      piece = "";
      piece ~= chr;
    } else {
      piece ~= chr;
    }
  }

  parts ~= piece;
  return join(parts, "_").toUpper;
}

class Ready : Event {
  ushort      ver;
  uint        heartbeat_interval;
  string      session_id;
  User        me;
  Channel[]   dms;
  Guild[]     guilds;

  this(Client c, Dispatch d) {
    super(c, d);

    this.ver = d.data.get!ushort("v");
    this.heartbeat_interval = d.data.get!uint("heartbeat_interval");
    this.session_id = d.data.get!string("session_id");
    this.me = new User(this.client, d.data.get!JSONObject("user"));

    foreach (Variant gobj; d.data.getRaw("guilds")) {
      this.guilds ~= new Guild(this.client, new JSONObject(variantToJSON(gobj)));
    }

    // TODO: dms
  }
}

class ChannelCreate : Event {
  Channel  channel;

  this(Client c, Dispatch d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class ChannelUpdate : Event {
  Channel  channel;

  this(Client c, Dispatch d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class ChannelDelete : Event {
  Channel  channel;

  this(Client c, Dispatch d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class GuildCreate : Event {
  Guild  guild;
  bool   isNew;
  bool   unavailable;

  this(Client c, Dispatch d) {
    super(c, d);
    this.guild = new Guild(this.client, d.data);

    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    } else {
      this.isNew = true;
    }
  }
}

class GuildUpdate : Event {
  Guild  guild;

  this(Client c, Dispatch d) {
    super(c, d);
    this.guild = new Guild(this.client, d.data);
  }
}

class GuildDelete : Event {
  Snowflake  guild_id;
  bool       unavailable;

  this (Client c, Dispatch d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("id");
    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    }
  }
}

class GuildBanAdd : Event {
  User  user;

  this(Client c, Dispatch d) {
    super(c, d);
    // this.user = new User(this.client, d.data);
  }
}

class GuildBanRemove : Event {
  User  user;

  this(Client c, Dispatch d) {
    super(c, d);
    // this.user = new User(this.client, d.data);
  }
}

class GuildEmojisUpdate : Event {
  // TODO
  this(Client c, Dispatch d) {
    super(c, d);
  }
}

class GuildIntegrationsUpdate : Event {
  // TODO
  this(Client c, Dispatch d) {
    super(c, d);
  }
}

class GuildMemberAdd : Event {
  GuildMember  member;

  this (Client c, Dispatch d) {
    super(c, d);
    this.member = new GuildMember(this.client, d.data);
  }
}

class GuildMemberRemove : Event {
  Snowflake  guild_id;
  User       user;

  this (Client c, Dispatch d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.user = new User(this.client, d.data.get!JSONObject("user"));
  }
}

class GuildMemberUpdate : Event {
  Snowflake  guild_id;
  User       user;
  Role[]     roles;

  this (Client c, Dispatch d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.user = new User(this.client, d.data.get!JSONObject("user"));
    // TODO: roles
  }
}

class GuildRoleCreate : Event {
  Snowflake  guild_id;
  Role       role;

  this (Client c, Dispatch d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.role = new Role(this.client, d.data.get!JSONObject("role"));
  }
}

class GuildRoleUpdate : Event {
  Snowflake  guild_id;
  Role       role;

  this (Client c, Dispatch d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.role = new Role(this.client, d.data.get!JSONObject("role"));
  }
}

class GuildRoleDelete : Event {
  Snowflake  guild_id;
  Role       role;

  this (Client c, Dispatch d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    // this.role = new Role(this.client, d.data.get!JSONObject("role"));
  }
}

class MessageCreate : Event {
  Message  message;

  this (Client c, Dispatch d) {
    super(c, d);
    this.message = new Message(this.client, d.data);
  }
}

class MessageUpdate : Event {
  Message message;

  this (Client c, Dispatch d) {
    super(c, d);
    this.message = new Message(this.client, d.data);
  }
}

class MessageDelete : Event {
  Snowflake  id;
  Snowflake  channel_id;

  this (Client c, Dispatch d) {
    super(c, d);
    this.id = d.data.get!Snowflake("id");
    this.channel_id = d.data.get!Snowflake("channel_id");
  }
}

class PresenceUpdate : Event {
  User         user;
  Snowflake    guild_id;
  Snowflake[]  roles;
  string       game;
  string       status;

  this (Client c, Dispatch d) {
    super(c, d);
    // TODO: this lol
  }
}

class TypingStart : Event {
  Snowflake  channel_id;
  Snowflake  user_id;
  string     timestamp;

  this(Client c, Dispatch d) {
    super(c, d);
    this.channel_id = d.data.get!Snowflake("channel_id");
    this.user_id = d.data.get!Snowflake("user_id");
    this.timestamp = d.data.get!string("timestamp");
  }
}

class UserSettingsUpdate : Event {
  this(Client c, Dispatch d) {
    // TODO
    super(c, d);
  }
}

class UserUpdate : Event {
  this(Client c, Dispatch d) {
    // TODO
    super(c, d);
  }
}

class VoiceStateUpdate : Event {
  Snowflake  user_id;
  Snowflake  guild_id;
  Snowflake  channel_id;
  string     session_id;
  bool       self_mute;
  bool       self_deaf;
  bool       mute;
  bool       deaf;

  this(Client c, Dispatch d) {
    super(c, d);

    this.user_id = d.data.get!Snowflake("user_id");
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.channel_id = d.data.maybeGet!Snowflake("channel_id", 0);
    this.session_id = d.data.get!string("session_id");
    this.self_mute = d.data.get!bool("self_mute");
    this.self_deaf = d.data.get!bool("self_deaf");
    this.mute = d.data.get!bool("mute");
    this.deaf = d.data.get!bool("deaf");
  }
}
