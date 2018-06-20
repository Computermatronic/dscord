module dscord.bot.command;

import std.traits;
import std.string: split;

import dscord.types;

enum string CommandNameType = "name";
enum string CommandDescriptionType = "description";
enum string CommandSyntaxType = "syntax";
enum string CommandPermissionType = "permission";
enum string CommandParamsType = "arguments";
enum string CommandAuthType = "auths";

template CommandConfig(alias CommandType) if(CommandType == CommandNameType) {
	static struct CommandConfig { string name; }
}

template CommandConfig(alias CommandType) if(CommandType == CommandDescriptionType) {
	static struct CommandConfig { string description; }
}

template CommandConfig(alias CommandType) if(CommandType == CommandSyntaxType) {
	static struct CommandConfig { string syntax; }
}

template CommandConfig(alias CommandType) if(CommandType == CommandPermissionType) {
	static struct CommandConfig {
		uint permissions;

		this(Permission[] permissions...) {
			foreach(permission; permissions) {
				this.permissions |= permission;
			}
		}
	}
}

template CommandConfig(alias CommandType) if(CommandType == CommandParamsType) {
	static struct CommandConfig { uint arguments; }
}

template CommandConfig(alias CommandType) if(CommandType == CommandAuthType) {
	static struct CommandConfig {
		uint auths;

		this(uint[] auths...) {
			foreach(auth; auths) {
				this.auths |= auth;
			}
		}
	}
}

alias CommandName = CommandConfig!CommandNameType;
alias CommandDescription = CommandConfig!CommandDescriptionType;
alias CommandSyntax = CommandConfig!CommandSyntaxType;
alias CommandPermission = CommandConfig!CommandPermissionType;
alias CommandParams = CommandConfig!CommandParamsType;
alias CommandAuth = CommandConfig!CommandAuthType;

alias CommandFunction = void delegate(CommandArgs);
alias CommandArgs = CommandEvent;

class Command {
	string name;
	string description;
	string syntax;
	uint permissions;
	uint arguments;
	uint auths;

	bool isEnabled = true;
	CommandFunction command;

	this(Args...)(CommandFunction command, Args args) {
		this.command = command;

		foreach(arg; args) {
			mixin("this." ~ split(typeof(arg).stringof, '"')[1] ~ " = " ~ "(arg.tupleof)[0];");
		}
	}
}

class CommandEvent {
	alias args this;
	
	Command command;
	Message msg;
	string[] args;

	this(Command command, Message m, string[] args) {
		this.command = command;
		this.msg = m;
		this.args = args;
	}
}

Command[] getCommands(Type)(Type object_) {
	Command[] commands;
	static foreach(memberName; __traits(allMembers, Type)) {
		static if(__traits(compiles, __traits(getMember, object_, memberName)) && 
				isFunction!(__traits(getMember, object_, memberName)) && 
				hasUDA!(__traits(getMember, object_, memberName), CommandName)) {
			static assert(Parameters!(__traits(getMember, object_, memberName)).length == 1 && is(Parameters!(mixin("object_." ~ memberName))[0] == CommandArgs), "Commands must take CommandArgs as a paramater.");
			static assert(getUDAs!(__traits(getMember, object_, memberName), CommandName).length <= 1, "Commands can only have one @CommandName UDA.");
			static assert(getUDAs!(__traits(getMember, object_, memberName), CommandDescription).length <= 1, "Commands can only have one @CommandDescription UDA.");
			static assert(getUDAs!(__traits(getMember, object_, memberName), CommandSyntax).length <= 1, "Commands can only have one @CommandSyntax UDA.");
			static assert(getUDAs!(__traits(getMember, object_, memberName), CommandParams).length <= 1, "Commands can only have one @CommandParams UDA.");
			static assert(getUDAs!(__traits(getMember, object_, memberName), CommandPermission).length <= 1, "Commands can only have one @CommandPermission UDA.");
			static assert(getUDAs!(__traits(getMember, object_, memberName), CommandAuth).length <= 1, "Commands can only have one @CommandAuth UDA.");
			commands ~= new Command(&__traits(getMember, object_, memberName), getUDAs!(__traits(getMember, object_, memberName), CommandConfig));
		}
	}
	return commands;
}

class CommandException : Exception {
	this(Args...)(string fmt, Args args) {
		import std.format: format;
		super(format(fmt, args));
	}
}