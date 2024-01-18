#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION	   "1.2.0"
#define PLUGIN_DESCRIPTION "allows players to highlight"

public Plugin myinfo =
{
    name        = "Player highlight",
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/player-highlight"
};

bool    g_plugin_late
        , g_can_highlight;  // 如果在练习时间高亮了玩家, 可能会导致回合重开后玩家不高亮显示的 bug

int     cv_ph_color_r
        , cv_ph_color_g
        , cv_ph_color_b
        , cv_ph_distance;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_plugin_late = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    ConVar convar;
    CreateConVar("sm_player_highlight_version",     PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY | FCVAR_DONTRECORD);
    (convar = CreateConVar("sm_ph_color_r",         "10",   "The red color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_r = convar.IntValue;
    (convar = CreateConVar("sm_ph_color_g",         "224",  "The green color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_g = convar.IntValue;
    (convar = CreateConVar("sm_ph_color_b",         "247",  "The blue color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_b = convar.IntValue;
    (convar = CreateConVar("sm_ph_distance",        "9999",  "glow distance")).AddChangeHook(OnConVarChange);
    cv_ph_distance = convar.IntValue;

    AutoExecConfig(true,                            "player-highlight");

    HookEvent("state_change",                       On_state_change,            EventHookMode_Post);        // Only nmrih
    HookEvent("nmrih_practice_ending",              On_nmrih_practice_ending,   EventHookMode_Pre);         // Only nmrih
    HookEvent("nmrih_reset_map",                    On_nmrih_reset_map,         EventHookMode_PostNoCopy);  // Only nmrih
    HookEvent("game_restarting",                    On_game_restarting,         EventHookMode_Pre);
    HookEvent("player_spawn",                       On_player_spawn,            EventHookMode_Post);
    HookEvent("player_death",                       On_player_death,            EventHookMode_Post);
    HookEvent("player_extracted",                   On_player_extracted,        EventHookMode_Post);        // Only nmrih

    if( g_plugin_late )
    {
        HighlightAllPlayers();
    }
}

void OnConVarChange(ConVar convar, char[] old_value, char[] new_value)
{
    if( convar == INVALID_HANDLE )
    {
        return ;
    }

    char convarName[32];
    convar.GetName(convarName, sizeof(convarName));

    if( strcmp(convarName, "sm_ph_color_r") == 0 )
    {
        cv_ph_color_r = convar.IntValue;
    }
    else if( strcmp(convarName, "sm_ph_color_g") == 0 )
    {
        cv_ph_color_g = convar.IntValue;
    }
    else if( strcmp(convarName, "sm_ph_color_b") == 0 )
    {
        cv_ph_color_b = convar.IntValue;
    }
    else if( ! strcmp(convarName, "cv_ph_distance") )
    {
        cv_ph_distance = convar.IntValue;
    }
}

void On_state_change(Event event, const char[] name, bool dontBroadcast)
{
    int state = event.GetInt("state");
    if( state == 1 )                // STATE_PRACTICE
        g_can_highlight = false;
}

void On_nmrih_practice_ending(Event event, const char[] name, bool dontBroadcast)
{
    g_can_highlight = false;
}

void On_nmrih_reset_map(Event event, const char[] name, bool dontBroadcast)
{
    g_can_highlight = true;
}

void On_game_restarting(Event event, const char[] name, bool dontBroadcast)
{
    UnHighlightAllPlayers();
}

void On_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(1.0, Timer_HighlightPlayer, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void On_player_death(Event event, char[] name, bool dontBroadcast)
{
    UnHighlightEntity(GetClientOfUserId( event.GetInt("userid") ));
}

void On_player_extracted(Event event, const char[] name, bool dontBroadcast)
{
    UnHighlightEntity( event.GetInt("player_id") );
}


Action Timer_HighlightPlayer(Handle timer, int userid)
{
    HighlightEntity(GetClientOfUserId(userid));
    return Plugin_Stop;
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

void HighlightEntity(int entity)
{
    if( IsValidEntity(entity) /* entity <= MaxClients && IsClientInGame(entity) && IsPlayerAlive(entity) */ )
    {
        RequestFrame(Frame_HighlightEntity, EntIndexToEntRef(entity));
    }
}

void Frame_HighlightEntity(int entRef)
{
    int entity = EntRefToEntIndex(entRef);
    if( g_can_highlight && IsValidEntity(entity) )
    {
        // int rgb = (cv_ph_color_r + cv_ph_color_g * 256 + cv_ph_color_b * 65536);
        // SetEntProp(entity, Prop_Send, "m_bGlowing", 1, 1);
        // SetEntProp(entity, Prop_Data, "m_clrGlowColor", rgb);
        // SetEntPropFloat(entity, Prop_Send, "m_flGlowDistance", -1.0);

        char rgb[12];
        char distance[10];
        IntToString(cv_ph_distance, distance, sizeof(distance));
        FormatEx(rgb, sizeof(rgb), "%d %d %d", cv_ph_color_r, cv_ph_color_g, cv_ph_color_b);

        DispatchKeyValue(entity, "glowable", "1");
        DispatchKeyValue(entity, "glowblip", "0");              // 关闭在罗盘上的光标
        DispatchKeyValue(entity, "glowcolor", rgb);
        DispatchKeyValue(entity, "glowdistance", distance);

        SetVariantString("!activator");
        AcceptEntityInput(entity, "EnableGlow");
    }
}


void UnHighlightAllPlayers()
{
    for(int client=1; client <= MaxClients; ++client)
    {
        UnHighlightEntity(client);
    }
}

void UnHighlightEntity(int entity)
{
    if( IsValidEntity(entity) /* entity <= MaxClients && IsClientInGame(entity) && IsPlayerAlive(entity) */ )
    {
        RequestFrame(Frame_UnHighlightEntity, EntIndexToEntRef(entity));
    }
}

void Frame_UnHighlightEntity(int entRef)
{
    int entity = EntRefToEntIndex(entRef);
    if( IsValidEntity(entity) )
    {
        // SetEntProp(entity, Prop_Send, "m_bGlowing", 0, 1);
        // SetEntProp(entity, Prop_Data, "m_clrGlowColor", 0);
        // SetEntPropFloat(entity, Prop_Send, "m_flGlowDistance", 0.0);

        DispatchKeyValue(entity, "glowable", "1");
        DispatchKeyValue(entity, "glowblip", "0");
        DispatchKeyValue(entity, "glowcolor", "0");
        DispatchKeyValue(entity, "glowdistance", "0.0");

        SetVariantString("!activator");
        AcceptEntityInput(entity, "DisableGlow", entity, entity);
    }
}
