module main;

import std.stdio,
       std.algorithm,
       std.string,
       std.format,
       std.conv,
       std.array,
       std.process,
       core.time;

import vibe.core.core;
import vibe.http.client;
import dcad.types : DCAFile;

import dscord.core,
       dscord.util.process,
       dscord.util.emitter,
       dscord.voice.youtubedl;

import core.sys.posix.signal;
import etc.linux.memoryerror;


class BasicPlugin : Plugin {
  DCAFile sound;

  this() {
    super();
  }

  @Command("test")
  @CommandDescription("HI")
  void onTestCommand(CommandEvent event) {
    auto chan = this.userVoiceChannel(event.msg.guild, event.msg.author);

    if (!chan) {
      event.msg.reply("You are not in a voice channel!");
      return;
    }

    auto sound = new DCAPlayable(new DCAFile(File("test.dca", "r")));
    auto vc = chan.joinVoice();

    if (vc.connect()) {
      event.msg.replyf("OK: %s", vc);
      vc.play(sound).disconnect();
    } else {
      event.msg.reply("it dont work");
    }
  }

  @Command("whereami")
  void onWhereAmI(CommandEvent event) {
    auto chan = this.userVoiceChannel(event.msg.guild, event.msg.author);
    if (chan) {
      event.msg.reply(format("Your in channel `%s`", chan.name));
    } else {
      event.msg.reply("You are not in a voice channel!");
    }
  }

  @Command("spam")
  void spam(CommandEvent event) {
    for (int i = 0; i < 30; i++) {
      this.client.updateStatus(0, new Game(format("Test #%s", i)));
      sleep(250.msecs);
      this.log.infof("%s", i);
    }
  }

  Channel userVoiceChannel(Guild guild, User user) {
    auto state = guild.voiceStates.pick(s => s.userID == user.id);
    if (!state) return null;
    return state.channel;
  }

  @Listener!VoiceStateUpdate(EmitterOrder.AFTER)
  void onVoiceStateUpdate(VoiceStateUpdate e) {
    auto beore = this.client.state.guilds.get(e.state.guildID).voiceStates.get(e.state.sessionID);
  }
}


void main(string[] args) {
  static if (is(typeof(registerMemoryErrorHandler)))
      registerMemoryErrorHandler();

  if (args.length <= 1) {
    writefln("Usage: %s <token>", args[0]);
    return;
  }

  BotConfig config;
  config.token = args[1];
  config.cmdPrefix = "";
  Bot bot = new Bot(config, LogLevel.trace);
  bot.loadPlugin(new BasicPlugin);
  bot.run();
  runEventLoop();
  return;
}
