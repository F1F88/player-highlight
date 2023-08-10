#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	   "1.0.0"

public Plugin myinfo =
{
    name        = "Player highlight",
    author      = "F1F88",
    description = "allows players to highlight",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/player-highlight"
};

bool    g_plugin_late;

int     cv_ph_color_r
        , cv_ph_color_g
        , cv_ph_color_b;

float   cv_ph_timer_interval;
Handle  g_ph_timer;

int     g_old_glow_color[MAXPLAYERS + 1];
float   g_old_glow_dist[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_plugin_late = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    ConVar convar;
    (convar = CreateConVar("sm_ph_color_r",                 "10",   "The red color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_r = convar.IntValue;
    (convar = CreateConVar("sm_ph_color_g",                 "224",  "The green color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_g = convar.IntValue;
    (convar = CreateConVar("sm_ph_color_b",                 "247",  "The blue color for player")).AddChangeHook(OnConVarChange);
    cv_ph_color_b = convar.IntValue;
    (convar = CreateConVar("sm_ph_timer_interval",          "0.0",  "Highlight players every so many times. 0.0=disabled (if highlight does not work sometimes, you can try setting it to above 0.0)")).AddChangeHook(OnConVarChange);
    cv_ph_timer_interval = convar.FloatValue;

    CreateConVar("sm_player_highlight_version",             PLUGIN_VERSION);
    AutoExecConfig(true,                                    "player-highlight");

    HookEvent("nmrih_reset_map",    On_nmrih_reset_map,     EventHookMode_PostNoCopy);  // Only nmrih
    HookEvent("player_spawn",       On_player_spawn,        EventHookMode_Post);
    HookEvent("player_death",       On_player_death,        EventHookMode_Post);
    HookEvent("player_extracted",   On_player_extracted,    EventHookMode_Post);        // Only nmrih ?

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
        if( g_ph_timer != INVALID_HANDLE ) {
            delete g_ph_timer;
        }
        g_ph_timer = CreateTimer(cv_ph_timer_interval, Timer_check_player_highlight, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void OnMapStart()
{
    if( cv_ph_timer_interval != 0.0 )
    {
        if( g_ph_timer == INVALID_HANDLE)
        {
            g_ph_timer = CreateTimer(cv_ph_timer_interval, Timer_check_player_highlight, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

Action Timer_check_player_highlight(Handle timer, any data)
{
    UnhighlightAllPlayers();
    HighlightAllPlayers();
    return Plugin_Continue;
}

void On_nmrih_reset_map(Event event, const char[] name, bool dontBroadcast)
{
    UnhighlightAllPlayers();
    HighlightAllPlayers();
}

void On_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    RequestFrame(HighlightPlayer, GetClientUserId(client));
}

void On_player_death(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    RequestFrame(UnhighlightPlayer, GetClientUserId(client));
}

void On_player_extracted(Event event, const char[] name, bool dontBroadcast)
{
    int client = event.GetInt("player_id");
    RequestFrame(UnhighlightPlayer, GetClientUserId(client));
}


void HighlightAllPlayers()
{
    for(int client=1; client <= MaxClients; ++client)
    {
        if( IsClientInGame(client) )
        {
            RequestFrame(HighlightPlayer, GetClientUserId(client));
        }
    }
}

bool CouldEntityGlow(int entity)
{
    return IsValidEdict(entity) && HasEntProp(entity, Prop_Send, "m_bGlowing") && HasEntProp(entity, Prop_Data, "m_bIsGlowable") && HasEntProp(entity, Prop_Data, "m_clrGlowColor") && HasEntProp(entity, Prop_Data, "m_flGlowDistance");
}

void HighlightPlayer(int user_id)
{
    int client = GetClientOfUserId(user_id);
    // Don't glow if we are already glowing
    if( ! IsPlayerAlive(client) || ! CouldEntityGlow(client) || GetEntProp(client, Prop_Send, "m_bGlowing") != 0 )
    {
        return ;
    }

    char rgb[12];
    FormatEx(rgb, sizeof(rgb), "%d %d %d", cv_ph_color_r, cv_ph_color_g, cv_ph_color_b);

    g_old_glow_color[client] = GetEntProp(client, Prop_Send, "m_clrGlowColor");
    g_old_glow_dist[client]  = GetEntPropFloat(client, Prop_Send, "m_flGlowDistance");

    DispatchKeyValue(client, "glowable", "1");
    DispatchKeyValue(client, "glowdistance", "-1");
    DispatchKeyValue(client, "glowcolor", rgb);
    AcceptEntityInput(client, "EnableGlow", client, client);
}

void UnhighlightAllPlayers()
{
    for(int client=1; client <= MaxClients; ++client)
    {
        if( IsClientInGame(client) )
        {
            RequestFrame(UnhighlightPlayer, GetClientUserId(client));
        }
    }
}

void UnhighlightPlayer(int user_id)
{
    int client = GetClientOfUserId(user_id);
    if( client != -1 && CouldEntityGlow(client) )
    {
        SetEntProp(client, Prop_Send, "m_clrGlowColor", g_old_glow_color[client]);
        SetEntPropFloat(client, Prop_Send, "m_flGlowDistance", g_old_glow_dist[client]);

        AcceptEntityInput(client, "DisableGlow", client, client);
    }
}