#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	   "1.0.0"

public Plugin myinfo =
{
	name		= "Player highlight",
	author		= "F1F88",
	description = "allows players to highlight",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/F1F88/player-highlight"
};

bool    g_plugin_late;

int     cv_ph_color_r
        , cv_ph_color_g
        , cv_ph_color_b;

float   cv_ph_timer_interval;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_plugin_late = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    ConVar convar;
    (convar = CreateConVar("sm_ph_color_r",         "10", "The red color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_r = convar.IntValue;
    (convar = CreateConVar("sm_ph_color_g",         "224", "The green color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_g = convar.IntValue;
    (convar = CreateConVar("sm_ph_color_b",         "247", "The blue color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_b = convar.IntValue;
    (convar = CreateConVar("sm_ph_timer_interval",  "0.0", "")).AddChangeHook(OnConVarChange);
    cv_ph_timer_interval = convar.FloatValue;

    CreateConVar("sm_player_highlight_version",     "1.0.0");
    AutoExecConfig(true,                            "player-highlight");

    HookEvent("player_spawn", On_player_spawn,      EventHookMode_Post);

    if( g_plugin_late )
    {
        HighlightAllPlayers();
    }
}

void OnConVarChange(ConVar convar, char[] old_value, char[] new_value) {
    if( convar == INVALID_HANDLE )
        return ;
    char convar_ame[32];
    convar.GetName(convar_ame, sizeof(convar_ame));

    if( strcmp(convar_ame, "sm_ph_color_r") == 0 ) {
        cv_ph_color_r = convar.IntValue;
    }
    else if( strcmp(convar_ame, "sm_ph_color_g") == 0 ) {
        cv_ph_color_g = convar.IntValue;
    }
    else if( strcmp(convar_ame, "sm_ph_color_b") == 0 ) {
        cv_ph_color_b = convar.IntValue;
    }
    else if( strcmp(convar_ame, "sm_ph_timer_interval") == 0 ) {
        cv_ph_timer_interval = convar.FloatValue;
    }
}

public void OnMapStart()
{
    if( cv_ph_timer_interval != 0.0 )
    {
        CreateTimer(cv_ph_timer_interval, Timer_check_player_highlight, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

Action Timer_check_player_highlight(Handle timer, any data)
{
    HighlightAllPlayers();
    return Plugin_Continue;
}

void On_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    HighlightEntity(client);
}


void HighlightAllPlayers()
{
    for(int client=1; client <= MaxClients; ++client)
    {
        if( IsClientInGame(client) && IsPlayerAlive(client) )
        {
            HighlightEntity(client);
        }
    }
}

bool CouldEntityGlow(int entity)
{
    return IsValidEdict(entity) && HasEntProp(entity, Prop_Send, "m_bGlowing") && HasEntProp(entity, Prop_Data, "m_bIsGlowable") && HasEntProp(entity, Prop_Data, "m_clrGlowColor") && HasEntProp(entity, Prop_Data, "m_flGlowDistance");
}

void HighlightEntity(int entity)
{
    // Don't glow if we are already glowing
    if( ! CouldEntityGlow(entity) || GetEntProp(entity, Prop_Send, "m_bGlowing") != 0 )
    {
        return ;
    }

    char rgb[12];
    FormatEx(rgb, sizeof(rgb), "%d %d %d", cv_ph_color_r, cv_ph_color_g, cv_ph_color_b);

    // int     oldGlowColor = GetEntProp(entity, Prop_Send, "m_clrGlowColor");
    // float   oldGlowDist  = GetEntPropFloat(entity, Prop_Send, "m_flGlowDistance");

    // TODO: Why don't we use above dataprops for these?
    DispatchKeyValue(entity, "glowable", "1");
    DispatchKeyValue(entity, "glowdistance", "-1");
    DispatchKeyValue(entity, "glowcolor", rgb);
    AcceptEntityInput(entity, "EnableGlow", entity, entity);

    // DataPack data;
    // CreateDataTimer((float)(duration), Timer_UnhighlightEntity, data, TIMER_FLAG_O_MAPCHANGE);
    // data.WriteCell(EntIndexToEntRef(entity));
    // data.WriteCell(oldGlowColor);
    // data.WriteFloat(oldGlowDist);
}

stock void UnhighlightEntity(int entity_ref, int oldGlowColor, float oldGlowDist)
{
	int entity = EntRefToEntIndex(entity_ref);
	if( entity != -1 )
	{
		SetEntProp(entity, Prop_Send, "m_clrGlowColor", oldGlowColor);
		SetEntPropFloat(entity, Prop_Send, "m_flGlowDistance", oldGlowDist);

		AcceptEntityInput(entity, "DisableGlow", entity, entity);
	}

	return ;
}