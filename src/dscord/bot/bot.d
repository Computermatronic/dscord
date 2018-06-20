module dscord.bot.bot;

import std.string: startsWith, indexOf;
import std.range: front, popFront, empty;
import std.array: Appender;
import std.algorithm: reduce, max;
import vibe.core.core;

import dscord.bot;
import dscord.types;
import dscord.client;
import dscord.gateway;
import dscord.util.emitter;
import dscord.util.errors;

class DiscordBot {
	Client client;
	Logger log;
	string commandPrefix;
	Command[] commands;

	this(this T)(string token, string commandPrefix, LogLevel logLevel = LogLevel.all, ushort shard = 0, ushort totalShards = 1) {
    	this.client = new Client(token, logLevel, new ShardInfo(shard, totalShards));
    	this.log = this.client.log;
		this.client.events.listen!MessageCreate(&this.onMessageCreate, EmitterOrder.BEFORE);
		this.client.events.listen!Ready(&this.onReady, EmitterOrder.AFTER);

		this.commandPrefix = commandPrefix;
		this.loadCommands(cast(T)this);
	}

	void run() {
		client.gw.start();
	}

	void onMessageCreate(MessageCreate m) {
		try this.tryExecuteCommand(m.message);
		catch(Exception e) {
			log.error(e);
			client.gw.start();
		}
	}

	void onReady(Ready r) {
		runTask(&initialize);
	}

	void initialize() {
	}

	void loadCommands(T)(T source) {
		this.commands ~= getCommands(source);
	}

	void tryExecuteCommand(Message m) {
		try {
			if(!m.content.startsWith(commandPrefix)) return;

			Command[] matches;
			foreach(command; this.commands) {
				if (command.isEnabled && m.content[commandPrefix.length..$].startsWith(command.name)) {
					matches ~= command;
				}
			}
			if (matches.length == 0) return;
			auto index = m.content.indexOf(" ");
			auto args = parseArguments(m.content[index == -1 ? $ : index .. $]);

			Command match;
			foreach(command; matches) {
				if (command.arguments == args.length) {
					match = command;
					break;
				}
			}
			if (match is null) {
				m.replyf("**Error:** Incorrect number of paramaters for command %s.", matches[0].name);
				return;
			}
			uint auths;
			if (m.channel.type == ChannelType.GUILD_TEXT) {
				if (!m.channel.can(client.me, match.permissions)) {
					m.reply("**Error:** I have not been permitted to execute that command.");
					return;
				}

				if (!m.channel.can(m.author, match.permissions)) {
					m.reply("**Error:** You are not permitted to execute that command.");
					return;
				}

				foreach(id, role; m.guild.roles.subset(m.guild.members[m.author.id].roles)) {
					auths |= this.getAuth(role);
				}
			}
			auths |= this.getAuth(m.author);
			if ((auths & match.auths) != match.auths) {
				m.reply("**Error:** You are not authorized to execute that command.");
				return;
			}
			match.command(new CommandArgs(match, m, args));
		} catch(CommandException e) {
			m.replyf("**Error:** %s", e.msg);
		} catch(Exception e) {
			log.error(e);
			m.replyf("**Internal Error:** %s", e.msg);
		}
	}

	uint getAuth(Role role) {
		return 0;
	}

	uint getAuth(User user) {
		return 0;
	}
}

string[] parseArguments(string state) {
	string[] args;
	while(!state.empty) {
		if (state.front == '\"' || state.front == '“') args ~= state.parseString();
		else if (state.front == ' ') state.popFront();
		else args ~= state.parseWord();
	}
	return args;
}

string parseString(ref string state) {
	Appender!string result;
	state.popFront();
	while (!state.empty && state.front != '\"' && state.front != '”') {
		result.put(state.front);
		state.popFront();
	}
	if (state.empty) throw new CommandException("Unterminated string in arguments.");
	state.popFront();
	return result.data;
}

string parseWord(ref string state) {
	Appender!string result;
	while (!state.empty && state.front != '\"' && state.front != ' ' && state.front != '“') {
		result.put(state.front);
		state.popFront();
	}
	return result.data;
}