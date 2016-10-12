/**
  Implementations of Discord events.
*/

module dscord.gateway.events;

import std.algorithm,
       std.string,
       std.stdio,
       std.datetime,
       std.array,
       std.conv;

import dscord.types,
       dscord.gateway,
       dscord.bot.command;

/**
  A wrapper type for delegates that can be attached to an event, and run after
  all listeners are executed. This can be used to ensure an event has fully passed
  through all listeners, or to avoid having function/stack pointers within plugin
  code (which allows for dynamically reloading the plugin).
*/
alias EventDeferredFunc = void delegate();

/**
  Base template for events from discord. Handles basic initilization, and some
  deferred-function code.
*/
mixin template Event() {
  Client client;

  /**
    Array of functions to be ran when this event has completed its pass through
    the any listeners, and is ready to be destroyed.
  */
  EventDeferredFunc[] deferred;

  this(Client c, JSONDecoder obj) {
    version (TIMING) {
      auto sw = StopWatch(AutoStart.yes);
      c.log.tracef("Starting create event for %s", this.toString);
    }

    this.client = c;
    this.load(obj);

    version (TIMING) {
      this.client.log.tracef("Create event for %s took %sms", this.toString,
        sw.peek().to!("msecs", real));
    }
  }

  /**
    Used to defer a functions execution until after this event has passed through
    all listeners, and is ready to be destroyed.
  */
  void defer(EventDeferredFunc f) {
    this.deferred ~= f;
  }

  /**
    Calls all deferred functions.
  */
  void resolveDeferreds() {
    foreach (ref f; this.deferred) {
      f();
    }
  }
}

/**
  Sent when we initially connect, contains base state and connection information.
*/
class Ready {
  mixin Event;

  ushort     ver;
  string     sessionID;
  User       me;
  Guild[]    guilds;
  Channel[]  dms;

  void load(JSONDecoder obj) {
    obj.keySwitch!("v", "session_id", "user", "guilds")(
      { this.ver = obj.read!ushort; },
      { this.sessionID = obj.read!string; },
      { this.me = new User(this.client, obj); },
      { loadMany!Guild(this.client, obj, (g) { this.guilds ~= g; }); },
    );
  }
}

/**
  Sent when we've completed a reconnect/resume sequence.
*/
class Resumed {
  mixin Event;

  void load(JSONDecoder obj) {}
}

/**
  Sent when a channel is created.
*/
class ChannelCreate {
  mixin Event;

  Channel  channel;

  void load(JSONDecoder obj) {
    this.channel = new Channel(this.client, obj);
  }
}

/**
  Sent when a channel is updated.
*/
class ChannelUpdate {
  mixin Event;

  Channel  channel;

  void load(JSONDecoder obj) {
    this.channel = new Channel(this.client, obj);
  }
}

/**
  Sent when a channel is deleted.
*/
class ChannelDelete {
  mixin Event;

  Channel  channel;

  void load(JSONDecoder obj) {
    this.channel = new Channel(this.client, obj);
  }
}

/**
  Sent when a guild is created (often on startup).
*/
class GuildCreate {
  mixin Event;

  Guild  guild;

  void load(JSONDecoder obj) {
    this.guild = new Guild(this.client, obj);
  }
}

/**
  Sent when a guild is updated
*/
class GuildUpdate {
  mixin Event;

  Guild  guild;

  void load(JSONDecoder obj) {
    this.guild = new Guild(this.client, obj);
  }
}

/**
  Sent when a guild is deleted (or becomes unavailable)
*/
class GuildDelete {
  mixin Event;

  Snowflake  guildID;
  bool       unavailable;

  void load(JSONDecoder obj) {
    obj.keySwitch!("guild_id", "unavailable")(
      { this.guildID = readSnowflake(obj); },
      { this.unavailable = obj.read!bool; },
    );
  }
}

/**
  Sent when a guild ban is added.
*/
class GuildBanAdd {
  mixin Event;

  User  user;

  void load(JSONDecoder obj) {
    this.user = new User(this.client, obj);
  }
}

/**
  Sent when a guild ban is removed.
*/
class GuildBanRemove {
  mixin Event;

  User  user;

  void load(JSONDecoder obj) {
    this.user = new User(this.client, obj);
  }
}

/**
  Sent when a guilds emojis are updated.
*/
class GuildEmojisUpdate {
  mixin Event;

  void load(JSONDecoder obj) {}
}

/**
  Sent when a guilds integrations are updated.
*/
class GuildIntegrationsUpdate {
  mixin Event;

  void load(JSONDecoder obj) {}
}

/**
  Sent in response to RequestGuildMembers.
*/

class GuildMembersChunk {
  mixin Event;

  Snowflake guildID;
  GuildMember[] members;

  void load(JSONDecoder obj) {
    obj.keySwitch!("guild_id", "members")(
      { this.guildID = readSnowflake(obj); },
      { loadMany!GuildMember(this.client, obj, (m) { this.members ~= m; }); },
    );

    auto guild = this.client.state.guilds.get(this.guildID);
    foreach (member; this.members) {
      member.guild = guild;
    }
  }
}

/**
  Sent when a member is added to a guild.
*/
class GuildMemberAdd {
  mixin Event;

  GuildMember  member;

  void load(JSONDecoder obj) {
    this.member = new GuildMember(this.client, obj);
  }
}

/**
  Sent when a member is removed from a guild.
*/
class GuildMemberRemove {
  mixin Event;

  Snowflake  guildID;
  User       user;

  void load(JSONDecoder obj) {
    obj.keySwitch!("guild_id", "user")(
      { this.guildID = readSnowflake(obj); },
      { this.user = new User(this.client, obj); },
    );
  }
}

/**
  Sent when a guild member is updated.
*/
class GuildMemberUpdate {
  mixin Event;

  Snowflake    guildID;
  User         user;
  Snowflake[]  roles;

  void load(JSONDecoder obj) {
    obj.keySwitch!("guild_id", "user", "roles")(
      { this.guildID = readSnowflake(obj); },
      { this.user = new User(this.client, obj); },
      { this.roles = obj.readArray!(string).map!((c) => c.to!Snowflake).array; },
    );
  }
}

/**
  Sent when a guild role is created.
*/
class GuildRoleCreate {
  mixin Event;

  Snowflake  guildID;
  Role       role;

  void load(JSONDecoder obj) {
    obj.keySwitch!("guild_id", "role")(
      { this.guildID = readSnowflake(obj); },
      { this.role = new Role(this.client, obj); },
    );
  }
}

/**
  Sent when a guild role is updated.
*/
class GuildRoleUpdate {
  mixin Event;

  Snowflake  guildID;
  Role       role;

  void load(JSONDecoder obj) {
    obj.keySwitch!("guild_id", "role")(
      { this.guildID = readSnowflake(obj); },
      { this.role = new Role(this.client, obj); },
    );
  }
}

/**
  Sent when a guild role is deleted.
*/
class GuildRoleDelete {
  mixin Event;

  Snowflake  guildID;
  Role       role;

  void load(JSONDecoder obj) {
    obj.keySwitch!("guild_id", "role")(
      { this.guildID = readSnowflake(obj); },
      { this.role = new Role(this.client, obj); },
    );
  }
}

/**
  Sent when a message is created.
*/
class MessageCreate {
  mixin Event;

  Message  message;

  // Reference to the command event
  CommandEvent commandEvent;

  void load(JSONDecoder obj) {
    this.message = new Message(this.client, obj);
  }
}

/**
  Sent when a message is updated.
*/
class MessageUpdate {
  mixin Event;

  Message  message;

  void load(JSONDecoder obj) {
    this.message = new Message(this.client, obj);
  }
}

/**
  Sent when a message is deleted.
*/
class MessageDelete {
  mixin Event;

  Snowflake  id;
  Snowflake  channelID;

  void load(JSONDecoder obj) {
    obj.keySwitch!("id", "channel_id")(
      { this.id = readSnowflake(obj); },
      { this.channelID = readSnowflake(obj); },
    );
  }
}

/**
  Sent when a users presence is updated.
*/
class PresenceUpdate {
  mixin Event;

  Presence presence;

  void load(JSONDecoder obj) {
    this.presence = new Presence(this.client, obj);
  }
}

/**
  Sent when a user starts typing.
*/
class TypingStart {
  mixin Event;

  Snowflake  channelID;
  Snowflake  userID;
  ulong      timestamp;

  void load(JSONDecoder obj) {
    obj.keySwitch!("channel_id", "user_id", "timestamp")(
      { this.channelID = readSnowflake(obj); },
      { this.userID = readSnowflake(obj); },
      { this.timestamp = obj.read!ulong; },
    );
  }
}

/**
  Sent when this users settings are updated.
*/
class UserSettingsUpdate {
  mixin Event;

  void load(JSONDecoder obj) {};
}

/**
  Sent when this user is updated.
*/
class UserUpdate {
  mixin Event;

  void load(JSONDecoder obj) {};
}

/**
  Sent when a voice state is updated.
*/
class VoiceStateUpdate {
  mixin Event;

  VoiceState  state;

  void load(JSONDecoder obj) {
    this.state = new VoiceState(this.client, obj);
  }
}

/**
  Sent when a voice server is updated.
*/
class VoiceServerUpdate {
  mixin Event;

  string     token;
  string     endpoint;
  Snowflake  guildID;

  void load(JSONDecoder obj) {
    obj.keySwitch!("token", "endpoint", "guild_id")(
      { this.token = obj.read!string; },
      { this.endpoint = obj.read!string; },
      { this.guildID = readSnowflake(obj); },
    );
  }
}

/**
  Sent when a channels pins are updated.
*/
class ChannelPinsUpdate {
  mixin Event;

  Snowflake  channelID;
  string     lastPinTimestamp;

  void load(JSONDecoder obj) {
    obj.keySwitch!("channel_id", "last_pin_timestamp")(
      { this.channelID = readSnowflake(obj); },
      { this.lastPinTimestamp = obj.read!string; },
    );
  }
}

/**
  Sent when a bulk set of messages gets deleted from a channel.
*/
class MessageDeleteBulk {
  mixin Event;

  Snowflake channelID;
  Snowflake[] ids;

  void load(JSONDecoder obj) {
    obj.keySwitch!("channel_id", "ids")(
      { this.channelID = readSnowflake(obj); },
      { this.ids = obj.readArray!(string).map!((c) => c.to!Snowflake).array; },
    );
  }
}
