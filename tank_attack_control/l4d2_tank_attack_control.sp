#include <sourcemod>
#include <left4downtown>

#define DEBUG		0
#define NUM_PUNCHES	3

//punches:
//40 - uppercut, 43 - right hook, 45 - left hook
//46 and 47 - pounding the ground
//throws:
//48 - (not used unless tank_overhead_percent is changed) undercut
//49 - 1handed overhand, 50 - throw from the hip, 51 - 2handed overhand

new const punch_sequence[NUM_PUNCHES] = {40, 43, 45};

new g_iAllowedPunchSequences[NUM_PUNCHES];
new g_iMaxAllowedPunchIndex;
new g_iAllowedTankPunches;
new g_iQueuedThrow[MAXPLAYERS + 1];
new Handle:g_hCvarAllowedTankPunches = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "Tank Attack Control",
	author = "vintik",
	description = "",
	version = "0.1",
	url = "https://github.com/thevintik/sm_plugins"
}

public OnPluginStart()
{
	decl String:sGame[256];
	GetGameFolderName(sGame, sizeof(sGame));
	if (!StrEqual(sGame, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	
	g_hCvarAllowedTankPunches = CreateConVar("l4d2_allowed_tank_punches", "3",
	"Which server-side punch animation for tank is allowed (bitmask: 1 - uppercut, 2 - right hook, 4 - left hook)",
	FCVAR_PLUGIN | FCVAR_SPONLY);
	
	g_iAllowedTankPunches = GetConVarInt(g_hCvarAllowedTankPunches);
	if (!IsValidCvarValue(g_iAllowedTankPunches))
	{
		ResetConVar(g_hCvarAllowedTankPunches);
		g_iAllowedTankPunches = GetConVarInt(g_hCvarAllowedTankPunches);
	}
	MappingRecalc();
	HookConVarChange(g_hCvarAllowedTankPunches, OnCvarChange);
}

public OnCvarChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new iNewVal = StringToInt(newVal);
	if (iNewVal == g_iAllowedTankPunches) return;
	if (IsValidCvarValue(iNewVal))
	{
		g_iAllowedTankPunches = iNewVal;
		MappingRecalc();
	}
	else
	{
		PrintToServer("Incorrect value of 'sm_allowed_tank_punches'! min: 1, max: %d", (1 << NUM_PUNCHES) - 1);
		SetConVarString(cvar, oldVal);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 3
		|| GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
			return Plugin_Continue;
	if ((buttons | IN_ATTACK2) !=0 )
	{
		if (buttons & IN_RELOAD)
			g_iQueuedThrow[client] = 1;
		else if (buttons & IN_USE)
			g_iQueuedThrow[client] = 2;
		else
			g_iQueuedThrow[client] = 3;
	}
	return Plugin_Continue;
}

public Action:L4D_OnCThrowActivate(ability)
{
	if (!IsValidEntity(ability))
	{
		LogMessage("Invalid 'ability_throw' index: %d. Continuing throwing.", ability);
		return Plugin_Continue;
	}
	new client = GetEntPropEnt(ability, Prop_Data, "m_hOwnerEntity");
	//ability = MakeCompatEntRef(GetEntProp(client, Prop_Send, "m_customAbility"));
	if (GetClientButtons(client) & IN_ATTACK)
	{
		//blocking punch+rock
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:L4D2_OnSelectTankAttack(client, &sequence)
{
	if (sequence > 48)
	{
		//rock throw
		if (g_iQueuedThrow[client])
		{
			sequence = g_iQueuedThrow[client] + 48;
			return Plugin_Handled;
		}
	}
	else
	{
		//likely it's a punch
		new index = SequenceToIndex(sequence);
		#if DEBUG
			PrintToServer("[DEBUG] Selected sequence is %d, its index: %d", sequence, index);
		#endif
		if (index != -1)
		{
			if (!IsAllowedIndex(index))
			{
				sequence = g_iAllowedPunchSequences[GetRandomInt(0, g_iMaxAllowedPunchIndex)];
				#if DEBUG
					PrintToServer("[DEBUG] Sequence isn't allowed. Overriding it with %d", sequence);
				#endif
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

bool:IsValidCvarValue(value)
{
	return ((value >= 1) && (value < (1 << NUM_PUNCHES)));
}

MappingRecalc()
{
	g_iMaxAllowedPunchIndex = -1;
	for (new i = 0; i < NUM_PUNCHES; i++)
	{
		if (IsAllowedIndex(i))
		{
			g_iAllowedPunchSequences[++g_iMaxAllowedPunchIndex] = punch_sequence[i];
			#if DEBUG
				PrintToServer("[DEBUG] Sequence %d is allowed", punch_sequence[i]);
			#endif
		}
	}
}

SequenceToIndex(sequence)
{
	for (new i = 0; i < NUM_PUNCHES; i++)
	{
		if (punch_sequence[i] == sequence)
			return i;
	}
	return -1;
}

bool:IsAllowedIndex(index)
{
	if ((1 << index) & g_iAllowedTankPunches)
		return true;
	else
		return false;
}