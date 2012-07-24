#pragma semicolon 1

#include <sourcemod>
#include <l4d2_direct>

new bool:g_bShouldRemoveGodframe = false;
new bool:g_bGodframedPlayers[MAXPLAYERS + 1] = false;

public Plugin:myinfo = 
{
	name = "YAGFR",
	author = "vintik",
	description = "Yet Another GodFrames Remover",
	version = "1.0",
	url = "https://github.com/thevintik/sm_plugins"
}

public OnPluginStart()
{
	HookEvent("pounce_end", OnAttackEnd);
	HookEvent("jockey_ride_end", OnAttackEnd);
	HookEvent("tongue_release", OnAttackEnd);
	HookEvent("charger_pummel_end", OnAttackEnd);
}

public Action:OnAttackEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim_userid = GetEventInt(event, "victim");
	if (victim_userid <= 0) return Plugin_Continue;
	new victim = GetClientOfUserId(victim_userid);
	if (victim <= 0 || victim > MaxClients) return Plugin_Continue;
	g_bShouldRemoveGodframe = true;
	g_bGodframedPlayers[victim] = true;
		
	return Plugin_Continue;
}

public OnGameFrame()
{
	if (g_bShouldRemoveGodframe)
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (g_bGodframedPlayers[i])
			{
				L4D2Direct_SetGodFrameEndTime(i, -1.0);
				g_bGodframedPlayers[i] = false;
			}
		}
		g_bShouldRemoveGodframe = false;
	}
}