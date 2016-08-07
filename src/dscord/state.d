module dscord.state;

import std.functional,
       std.stdio,
       std.algorithm.iteration,
       std.experimental.logger;

import dscord.client,
       dscord.api.client,
       dscord.gateway.client,
       dscord.gateway.events,
       dscord.gateway.packets,
       dscord.types.all,
       dscord.util.emitter;

enum StateFeatures {
  GUILDS = 1 << 0,
  CHANNELS = 1 << 1,
  VOICE = 1 << 2,
}

const StateFeatures DEFAULT_STATE_FEATURES =
  StateFeatures.GUILDS |
  StateFeatures.CHANNELS |
  StateFeatures.VOICE;


/**
  The State class is used to track and maintain client state.
*/
class State : Emitter {
  // Client
  Client         client;
  APIClient      api;
  GatewayClient  gw;

  // Storage
  User        me;

  private {
    Logger  log;
    ulong  onReadyGuildCount;
    StateFeatures  features;
    EventListenerArray  listeners;

    UserMap     _users;
    GuildMap    _guilds;
    ChannelMap  _channels;
  }

  this(Client client, StateFeatures features = DEFAULT_STATE_FEATURES) {
    this.features = features;
    this.client = client;
    this.log = client.log;
    this.api = client.api;
    this.gw = client.gw;

    this._guilds = new GuildMap;
    this._channels = new ChannelMap;
    this._users = new UserMap;

    // Finally bind all events we want
    this.bindListeners();
  }

  void setFeatures(StateFeatures features) {
    this.features = features;
    this.bindListeners();
  }

  private void listen(Ty...)() {
    foreach (T; Ty) {
      this.listeners ~= this.client.events.listen!T(mixin("&this.on" ~ T.stringof));
    }
  }

  private void bindListeners() {
    // Unbind all listeners
    this.listeners.each!((l) => l.unbind());

    // Always listen for ready payload
    this.listen!Ready;

    // Guilds
    if (this.features & StateFeatures.GUILDS) {
      this.listen!(GuildCreate, GuildUpdate, GuildDelete);
    }

    // Channels
    if (this.features & StateFeatures.CHANNELS) {
      this.listen!(ChannelCreate, ChannelUpdate, ChannelDelete);
    }

    // Voice State
    if (this.features & StateFeatures.VOICE) {
      this.listen!VoiceStateUpdate;
    }
  }

  void onReady(Ready r) {
    this.me = r.me;
    this.onReadyGuildCount = r.guilds.length;
  }

  void onGuildCreate(GuildCreate c) {
    this._guilds[c.guild.id] = c.guild;

    if (this._guilds.length % 100 == 0)
      this.log.infof("GUILD_CREATE, now have %s guilds", this.guilds.length);

    // Add channels
    if (this.features & StateFeatures.CHANNELS) {
      c.guild.channels.each((c) {
        this._channels[c.id] = c;
      });
    }
  }

  void onGuildUpdate(GuildUpdate c) {
    this.log.warning("Hit onGuildUpdate leaving state stale");
    // TODO: handle state changes in here
    // this.guilds[c.guild.id].load(c.payload);
  }

  void onGuildDelete(GuildDelete c) {
    if (!this._guilds.has(c.guildID)) return;

    destroy(this._guilds[c.guildID]);
    this._guilds.remove(c.guildID);

    // TODO: channels?
  }

  void onChannelCreate(ChannelCreate c) {
    this._channels[c.channel.id] = c.channel;
  }

  void onChannelUpdate(ChannelUpdate c) {
    this._channels[c.channel.id] = c.channel;
  }

  void onChannelDelete(ChannelDelete c) {
    if (this._channels.has(c.channel.id)) {
      destroy(this._channels[c.channel.id]);
      this._channels.remove(c.channel.id);
    }
  }

  void onVoiceStateUpdate(VoiceStateUpdate u) {
    // TODO: shallow tracking, don't require guilds
    auto guild = this._guilds.get(u.state.guildID);

    if (!u.state.channelID) {
      guild.voiceStates.remove(u.state.sessionID);
    } else {
      guild.voiceStates[u.state.sessionID] = u.state;
    }
  }

  @property GuildMap guilds() {
    return this._guilds;
  }

  @property ChannelMap channels() {
    return this._channels;
  }

  @property UserMap users() {
    return this._users;
  }
}
