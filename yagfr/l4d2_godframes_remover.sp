#pragma semicolon 1

#include <sourcemod>
#include <l4d2_direct>
#include <sdkhooks>

#define	L4D_TEAM_SURVIVORS 2
#define	L4D_TEAM_INFECTED 3
#define	CHARGER_CLASS 6

new bool:g_bShouldRemoveEngineGodframes = false;
new bool:g_bEngineGodframedPlayers[MAXPLAYERS + 1] = false;
new bool:g_bLateLoad = false;
new Float:g_fGodframesEndTime[MAXPLAYERS + 1] = -1.0;
new Handle:g_hGodframesIntervalTrie = INVALID_HANDLE;
new Handle:g_hCvarCommonsOverrides = INVALID_HANDLE;
new Handle:g_hCvarChargerOverrides = INVALID_HANDLE;
new Handle:g_hCvarSpitterOverrides = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "GodFrames Control",
	author = "vintik",
	description = "Yet Another GodFrames Remover / GodFrames Controller",
	version = "1.1",
	url = "https://github.com/thevintik/sm_plugins"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:sGame[12];
	GetGameFolderName(sGame, sizeof(sGame));
	if (StrEqual(sGame, "left4dead2"))
	{
		g_bLateLoad=late;
		return APLRes_Success;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports L4D2");
		return APLRes_Failure;
	}
}

public OnPluginStart()
{
	g_hCvarCommonsOverrides = CreateConVar("sm_no_godframes_for_commons", "0", "Should commons make damage in our own godframes?", FCVAR_PLUGIN);
	g_hCvarChargerOverrides = CreateConVar("sm_no_godframes_for_charger", "0", "Should charger make damage in our own godframes?", FCVAR_PLUGIN);
	g_hCvarSpitterOverrides = CreateConVar("sm_no_godframes_for_spitter", "1", "Should spitter's goo make damage in our own godframes?", FCVAR_PLUGIN);
	HookEvent("pounce_end", OnGodframesCreated);
	HookEvent("jockey_ride_end", OnGodframesCreated);
	HookEvent("tongue_release", OnGodframesCreated);
	HookEvent("charger_pummel_end", OnGodframesCreated);
	HookEvent("revive_success", OnGodframesCreated);
	HookEvent("heal_success", OnGodframesCreated);
	g_hGodframesIntervalTrie = BuildGodframesIntervalTrie();
	if(g_bLateLoad)
	{
		for(new i=1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
}

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnGameFrame()
{
	if (g_bShouldRemoveEngineGodframes)
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (g_bEngineGodframedPlayers[i])
			{
				CTimer_Invalidate(L4D2Direct_GetInvulnerabilityTimer(i));
				g_bEngineGodframedPlayers[i] = false;
			}
		}
		g_bShouldRemoveEngineGodframes = false;
	}
}

public Action:OnGodframesCreated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid;
	if (StrEqual(name, "revive_success") || StrEqual(name, "heal_success"))
	{
		userid = GetEventInt(event, "subject");
	}
	else
	{
		userid = GetEventInt(event, "victim");
	}
	
	if (userid <= 0) return Plugin_Continue;
	new player = GetClientOfUserId(userid);
	if (player <= 0 || player > MaxClients) return Plugin_Continue;
	//mark that we should remove engine-based godframes
	g_bShouldRemoveEngineGodframes = true;
	g_bEngineGodframedPlayers[player] = true;
	
	new Float:fGodframesInterval;
	//create our own, controllable godframes
	if (GetTrieValue(g_hGodframesIntervalTrie, name, fGodframesInterval))
	{
		g_fGodframesEndTime[player] = GetGameTime() + fGodframesInterval;
	}
	
	return Plugin_Continue;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim)) return Plugin_Continue;
	if (GetClientTeam(victim) != L4D_TEAM_SURVIVORS) return Plugin_Continue;
	
	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)
		&& GetClientTeam(attacker) == L4D_TEAM_INFECTED
		&& GetZombieClass(attacker) == CHARGER_CLASS)
	{
		if (!GetConVarBool(g_hCvarChargerOverrides) && g_fGodframesEndTime[victim] > GetGameTime())
		{
			return Plugin_Handled;
		}
		else
		{
			return Plugin_Continue;
		}
	}
	
	if (!IsValidEdict(inflictor)) return Plugin_Continue;
	decl String:sInflictor[64];
	GetEdictClassname(inflictor, sInflictor, sizeof(sInflictor));
	if (StrEqual(sInflictor, "insect_swarm") && !GetConVarBool(g_hCvarSpitterOverrides))
	{
		if (g_fGodframesEndTime[victim] > GetGameTime())
		{
			return Plugin_Handled;
		}
		else
		{
			return Plugin_Continue;
		}
	}
	
	if (StrEqual(sInflictor, "infected") && !GetConVarBool(g_hCvarCommonsOverrides))
	{
		if (g_fGodframesEndTime[victim] > GetGameTime())
		{
			return Plugin_Handled;
		}
		else
		{
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;	
}

GetZombieClass(client) return GetEntProp(client, Prop_Send, "m_zombieClass");

Handle:BuildGodframesIntervalTrie()
{
	//set our own godframes in these events
	new Handle: trie = CreateTrie();
	SetTrieValue(trie, "pounce_end", 2.0);
	SetTrieValue(trie, "charger_pummel_end", 2.5);
	return trie;    
}
