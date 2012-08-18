#include <sourcemod>
#include <left4downtown>//update will be soon

#define DEBUG		0
#define MAX_INDEX	3

//punches:
//40 - uppercut, 43 - right hook, 45 - left hook
//46 and 47 - pounding the ground

//throws:
//48 - (not used unless tank_overhead_percent is changed) undercut
//49 - 1handed overhand, 50 - throw from the hip, 51 - 2handed overhand

static const index_to_sequence[MAX_INDEX] = {40, 43, 45};

static allowed_sequences[MAX_INDEX];
static gNumAllowedSeqMinusOne;
static gAllowedTankPunches;
static Handle:cvarAllowedTankPunches = INVALID_HANDLE;

static g_iQueuedThrow[MAXPLAYERS + 1] = 0;

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
	
	cvarAllowedTankPunches = CreateConVar("l4d2_allowed_tank_punches", "3",
	"Which server-side punch animation for tank is allowed (bitmask: 1 - uppercut, 2 - right hook, 4 - left hook)",
	FCVAR_PLUGIN | FCVAR_SPONLY);
	
	gAllowedTankPunches = GetConVarInt(cvarAllowedTankPunches);
	if (!IsValidCvarValue(gAllowedTankPunches))
	{
		ResetConVar(cvarAllowedTankPunches);
		gAllowedTankPunches = GetConVarInt(cvarAllowedTankPunches);
	}
	MappingRecalc();
	HookConVarChange(cvarAllowedTankPunches, OnCvarChange);
}

public OnCvarChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new newValInt = StringToInt(newVal);
	if (newValInt == gAllowedTankPunches) return;
	if (IsValidCvarValue(newValInt))
	{
		gAllowedTankPunches = newValInt;
		MappingRecalc();
	}
	else
	{
		PrintToServer("Incorrect value of 'sm_allowed_tank_punches'! min: 1, max: %d", (1 << MAX_INDEX) - 1);
		SetConVarString(cvar, oldVal);
	}
}

stock bool:IsValidCvarValue(value)
{
	return ((value >= 1) && (value < (1 << MAX_INDEX)));
}

stock MappingRecalc()
{
	gNumAllowedSeqMinusOne = -1;
	for (new i = 0; i < MAX_INDEX; i++)
	{
		if (IsAllowedIndex(i))
		{
			allowed_sequences[++gNumAllowedSeqMinusOne] = index_to_sequence[i];
			#if DEBUG
				PrintToServer("[DEBUG] Sequence %d is allowed", index_to_sequence[i]);
			#endif
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 3
		|| GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
			return Plugin_Continue;
	if ((buttons | IN_ATTACK2) !=0 )
	{
		if ((buttons & IN_RELOAD) != 0)
			g_iQueuedThrow[client] = 1;
		else if ((buttons & IN_USE) != 0)
			g_iQueuedThrow[client] = 2;
		else
			g_iQueuedThrow[client] = 3;
	}
	return Plugin_Continue;
}

/*public Action:L4D_OnCThrowActivate(ability)
{
	new client = GetEntPropEnt(ability, Prop_Data, "m_hOwnerEntity");
	//ability = MakeCompatEntRef(GetEntProp(client, Prop_Send, "m_customAbility"));
	if (GetClientButtons(client) & IN_ATTACK)
	{
		//blocking punch+rock
		return Plugin_Handled;
	}
	return Plugin_Continue;
}*/

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
				sequence = allowed_sequences[GetRandomInt(0, gNumAllowedSeqMinusOne)];
				#if DEBUG
					PrintToServer("[DEBUG] Sequence isn't allowed. Overriding it with %d", sequence);
				#endif
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

stock SequenceToIndex(sequence)
{
	for (new i = 0; i < MAX_INDEX; i++)
	{
		if (index_to_sequence[i] == sequence)
			return i;
	}
	return -1;
}

stock bool:IsAllowedIndex(index)
{
	if ((1 << index) & gAllowedTankPunches)
		return true;
	else
		return false;
}