#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_sound>
#include <cstrike>
#include <hiddenmode>
#include <CustomPlayerSkins>

#pragma semicolon 1

#define charsmax(%1) sizeof(%1)-1

#define MAX_FILE_LEN 80

// Cvar Handle
Handle pCvar_iTimeCountdown;
Handle pCvar_iHiddenHP;
Handle pCvar_bShowHiddenHP;
Handle pCvar_fHiddenSpeedMul;
Handle pCvar_fHiddenGravityMul;
Handle pCvar_fJumpPower;
Handle pCvar_fSkillCountdown;
//Handle pCvar_bShowHiddenBlood;
//Handle pCvar_bPainShock;
//Handle pCvar_iVisibleTime;

Handle pCvar_dia;


// Timer Handle
//Handle Timer_Countdown = null;
//Handle Timer_ShowHiddenHP = null;
Handle Timer_SkillCountDown = null;
Handle Timer_SetHiddenVisible = null;

// Global variables
bool bRoundStart = false;
bool bGameBegin = false;
bool bRoundEnd = false;
bool gHiddenAttack = false;
//bool gHiddenIsVisible = false;

int gMaxPlayers;
int gHiddenIndex;
int gTimer;
int gAlpha;
float gVisibleInterval = 0.5;
float gSkillCountdown;

new PlayerClass:gPlayerClass[MAXPLAYERS + 1];

// Sounds
char gSound_Countdown[][] =  {
	"*/hidden/cd/1.mp3", 
	"*/hidden/cd/2.mp3", 
	"*/hidden/cd/3.mp3", 
	"*/hidden/cd/4.mp3", 
	"*/hidden/cd/5.mp3", 
	"*/hidden/cd/6.mp3", 
	"*/hidden/cd/7.mp3", 
	"*/hidden/cd/8.mp3", 
	"*/hidden/cd/9.mp3", 
	"*/hidden/cd/10.mp3"
};

char gSound_HiddenAppear[] = "*/hidden/hidden_laugh.mp3";
char gSound_HiddenKill[] = "*/hidden/hidden_kill.mp3";
char gSound_HiddenDeath[] = "*/hidden/hidden_death.mp3";

char gHungryBarVmt[][] = {
	"materials/overlays/hm/lvl_1_hud.vmt",
	"materials/overlays/hm/lvl_2_hud.vmt",
	"materials/overlays/hm/lvl_3_hud.vmt",
	"materials/overlays/hm/lvl_4_hud.vmt",
	"materials/overlays/hm/lvl_5_hud.vmt",
	"materials/overlays/hm/lvl_6_hud.vmt",
	"materials/overlays/hm/lvl_7_hud.vmt",
	"materials/overlays/hm/lvl_8_hud.vmt",
	"materials/overlays/hm/lvl_9_hud.vmt",
	"materials/overlays/hm/lvl_10_hud.vmt"
};

char gHungryBarVtf[][] = {
	"materials/overlays/hm/lvl_1_hud.vtf",
	"materials/overlays/hm/lvl_2_hud.vtf",
	"materials/overlays/hm/lvl_3_hud.vtf",
	"materials/overlays/hm/lvl_4_hud.vtf",
	"materials/overlays/hm/lvl_5_hud.vtf",
	"materials/overlays/hm/lvl_6_hud.vtf",
	"materials/overlays/hm/lvl_7_hud.vtf",
	"materials/overlays/hm/lvl_8_hud.vtf",
	"materials/overlays/hm/lvl_9_hud.vtf",
	"materials/overlays/hm/lvl_10_hud.vtf"
};

public Plugin myinfo =  {
	name = "[CSGO] The Hidden: Gamemode", 
	author = "Locdt", 
	description = "", 
	version = "1.0", 
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("HM_IsPlayerHidden", Native_IsPlayerHidden);
	CreateNative("HM_IsPlayerHuman", Native_IsPlayerHuman);
	CreateNative("HM_SetPlayerClass", Native_SetPlayerClass);
	
	// Register mod library
	RegPluginLibrary("hiddenmode");
	return APLRes_Success;
}

public void OnPluginStart() {
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("player_death", OnPlayerDeath);
	//HookEvent("weapon_fire", OnWeaponFire);
	
	AddCommandListener(OnLookWeaponPressed, "+lookatweapon");
	
	pCvar_iTimeCountdown = CreateConVar("hm_cdtime", "15");
	//pCvar_bFallDamage 		= CreateConVar("hm_falldamage", "0");
	
	pCvar_iHiddenHP = CreateConVar("hm_hiddenhp", "5000");
	pCvar_bShowHiddenHP = CreateConVar("hm_showhiddenhp", "1");
	pCvar_fHiddenSpeedMul = CreateConVar("hm_hiddenspeedmul", "2.0");
	pCvar_fHiddenGravityMul = CreateConVar("hm_hiddengravitymul", "0.5");
	pCvar_fJumpPower = CreateConVar("hm_jumppower", "1000.0");
	pCvar_fSkillCountdown = CreateConVar("hm_skillcd", "5.0");
	
	pCvar_dia = FindConVar("sv_disable_immunity_alpha");
	if (pCvar_dia == INVALID_HANDLE)
		return;
	SetConVarInt(pCvar_dia, 1);
	
	HookConVarChange(pCvar_dia, ConVarChanged);
	//HookConVarChange(pCvar_bShowHiddenBlood, HiddenBloodConVarChanged);
	//HookConVarChange(pCvar_bPainShock, HiddenBloodConVarChanged);
}

public void OnMapStart() {
	int arraySize = ByteCountToCells(PLATFORM_MAX_PATH);
	ArrayList soundList = new ArrayList(arraySize);
	
	for (int i = 0; i < sizeof(gSound_Countdown); i++) {
		soundList.PushString(gSound_Countdown[i]);
	}
	
	soundList.PushString(gSound_HiddenAppear);
	soundList.PushString(gSound_HiddenKill);
	soundList.PushString(gSound_HiddenDeath);
	
	for (int i = 0; i < soundList.Length; i++) {
		char buffer[MAX_FILE_LEN];
		soundList.GetString(i, buffer, charsmax(buffer));
		AddToStringTable(FindStringTable("soundprecache"), buffer);
		ReplaceString(buffer, charsmax(buffer), "*/", "", false);
		Format(buffer, charsmax(buffer), "sound/%s", buffer);
		PrintToServer("%s", buffer);
		AddFileToDownloadsTable(buffer);
	}
	
	for (int i = 0; i < sizeof(gHungryBarVtf); i++) {
		AddFileToDownloadsTable(gHungryBarVtf[i]);
	}
	
	for (int i = 0; i < sizeof(gHungryBarVmt); i++) {
		AddFileToDownloadsTable(gHungryBarVmt[i]);
		PrecacheModel(gHungryBarVmt[i]);
	}
}
/**
 * Declare native
 */
public Native_IsPlayerHidden(Handle plugin, int numParams) {
	int iClient = GetNativeCell(1);
	return gPlayerClass[iClient] == TEAM_HIDDEN ? true : false;
}

public Native_IsPlayerHuman(Handle plugin, int numParams) {
	int iClient = GetNativeCell(1);
	return gPlayerClass[iClient] == TEAM_HUMAN ? true : false;
}

public Native_SetPlayerClass(Handle plugin, int numParams) {
	int iClient = GetNativeCell(1);
	new PlayerClass:class = GetNativeCell(2);
	
	gPlayerClass[iClient] = class;
}

/**
 * Hook event function
 */
public void ConVarChanged(Handle:cvar, const String:oldVal[], const String:newVal[]) {
	SetConVarInt(pCvar_dia, 1);
}


public void OnClientPutInServer(client) {
	//SDKHook(client, SDKHook_TraceAttack, OnTraceAttack); 
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
    
	gPlayerClass[client] = TEAM_HUMAN;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
	if (!IsValidEntity(weapon))
		return Plugin_Continue;
	
	char weaponclassname[PLATFORM_MAX_PATH];
	GetEntityClassname(weapon, weaponclassname, charsmax(weaponclassname));
	
	if (StrEqual(weaponclassname, "weapon_knife")) {
		if (buttons & IN_ATTACK2 || buttons & IN_ATTACK) {
			// Hidden attack
			gHiddenAttack = true;
			
			//if (gHiddenIndex != 0)
			//PrintToChatAll("Set hidden visible again!");
			//SetEntityRenderColor(gHiddenIndex, 255, 255, 255, 255);
			//Timer_SetHiddenVisible = CreateTimer(1.0, TimerSetVisible, _, TIMER_REPEAT); 
		}
	}
	return Plugin_Continue;
}

public OnRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	bRoundStart = true;
	bGameBegin = false;
	bRoundEnd = false;
	
	// Reset timer
	gTimer = GetConVarInt(pCvar_iTimeCountdown);
	CreateTimer(1.0, TimerCountdown, _, TIMER_REPEAT);
}

public OnRoundEnd(Handle event, const char[] name, bool dontBroadcast) {
	bRoundStart = false;
	bGameBegin = false;
	bRoundEnd = true;
	
	// Set timer
	
	// Unhook to make player visible
	SDKUnhook(gHiddenIndex, SDKHook_SetTransmit, Hook_SetTransmit);
	
	// Reset player gravity
	SetEntityGravity(gHiddenIndex, 1.0);
	
	// Disable wall seeing
	DisablePlayerGlow();
	
	// Reset everything is done. Finally reset The Hidden
	gPlayerClass[gHiddenIndex] = TEAM_HUMAN;
	gHiddenIndex = 0;
	
	// And balance team
	FuncBalanceTeam();
}

public OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (gPlayerClass[iClient] == TEAM_HIDDEN) {
		PrintToChatAll("Well done! The Hidden is dead!");
		EmitSoundToAll(gSound_HiddenDeath);
	}
	else if (IsClientValid(iClient) && gPlayerClass[iClient] == TEAM_HUMAN) {
		Dissolve(iClient, 3);
		EmitSoundToAll(gSound_HiddenKill);
	}
}

public Action OnLookWeaponPressed(int client, const char[] command, int argc) {
	
	if (gHiddenIndex == 0 || client != gHiddenIndex) return Plugin_Handled;
	
	if (gSkillCountdown == 0.0) {
		if (Timer_SkillCountDown == INVALID_HANDLE) {
			DoSkill(client);
			gSkillCountdown = GetConVarFloat(pCvar_fSkillCountdown);
			Timer_SkillCountDown = CreateTimer(1.0, OnSkillCountdown, _, TIMER_REPEAT);
		}
	}
	
	return Plugin_Handled;
}

/**
 * SDK Hook Function
 */
/*
public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &ammoType, int hitBox, int hitGroup) {
	// Ignore all damage send to player if game is not begin
	if (!bRoundStart || !bGameBegin || bRoundEnd) return Plugin_Handled;
	
	// Game begin
	if (bRoundStart && bGameBegin) {
		if (attacker == 0) return Plugin_Continue;
		
		if (victim == gHiddenIndex && IsClientValid(attacker)) {
			if (Timer_SetHiddenVisible != null) {
				// Kill the timer
				KillTimer(Timer_SetHiddenVisible);
				Timer_SetHiddenVisible = null;
			}
						
			// Set timer again
			SetEntityRenderColor(gHiddenIndex, 255, 255, 255, 255);
			gAlpha = 255;
			Timer_SetHiddenVisible = CreateTimer(gVisibleInterval, TimerSetVisible, _, TIMER_REPEAT);
			
			if(!GetConVarBool(pCvar_bShowHiddenBlood)) {
				int health = GetEntProp(victim, Prop_Send, "m_iHealth");
				health -= RoundFloat(damage);
				SetEntProp(victim, Prop_Data, "m_iHealth", health);
				
				return Plugin_Handled;
			}
			else return Plugin_Continue;
		}
		
		if (attacker == gHiddenIndex && victim > 0 && victim <= MaxClients)
			return Plugin_Continue;
		
		if (attacker < 0 || attacker > MaxClients) return Plugin_Handled;
	}
	return Plugin_Handled;
}
*/

public Action OnWeaponCanUse(int client, int weapon) 
{
    if(gPlayerClass[client] == TEAM_HIDDEN)
        return Plugin_Handled; 
    
    return Plugin_Continue; 
}

public Action OnWeaponDrop(int client, int weapon) 
{
    if(gPlayerClass[client] == TEAM_HIDDEN)
        return Plugin_Handled; 
    
    return Plugin_Continue; 
}  

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
	// Ignore all damage send to player if game is not begin
	if (!bRoundStart || !bGameBegin || bRoundEnd || gHiddenIndex == 0)return Plugin_Handled;
	
	// Game begin
	if (bRoundStart && bGameBegin) {
		if (attacker == 0)return Plugin_Continue;
		
		if (victim == gHiddenIndex && IsClientValid(attacker)) {
			if (Timer_SetHiddenVisible != null) {
				// Kill the timer
				KillTimer(Timer_SetHiddenVisible);
				Timer_SetHiddenVisible = null;
			}
			
			// Set timer again
			SetEntityRenderColor(gHiddenIndex, 255, 255, 255, 255);
			gAlpha = 255;
			Timer_SetHiddenVisible = CreateTimer(gVisibleInterval, TimerSetVisible, _, TIMER_REPEAT);
			/*
			if (GetConVarBool(pCvar_bShowHiddenBlood)) {
				if (!GetConVarBool(pCvar_bPainShock)) {
					PrintCenterTextAll("Hidden took damage: $f", damage);
					int health = GetEntProp(victim, Prop_Send, "m_iHealth");
					health -= RoundFloat(damage);
					SetEntProp(victim, Prop_Data, "m_iHealth", health);
					
					return Plugin_Handled;
				}
			*/
			return Plugin_Continue;
		}
		
		if (attacker == gHiddenIndex && IsClientValid(victim))
			return Plugin_Continue;
		
		if (!IsClientValid(attacker))return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Hook_SetTransmit(int entity, int client)
{
	if (entity != client && gAlpha <= 0) {
		SetEntityRenderMode(client, RENDER_NORMAL);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnSetTransmit_GlowSkin(int iSkin, int client) {
	if (!IsPlayerAlive(client))return Plugin_Handled;
	
	for (int id = 1; id <= MaxClients; id++) {
		if (id == gHiddenIndex)
			return Plugin_Continue;
		
		if (!IsClientValid(id))
			continue;
		
		if (!CPS_HasSkin(id))
			continue;
		
		if (EntRefToEntIndex(CPS_GetSkin(id)) != iSkin)
			continue;
	}
	
	return Plugin_Handled;
}

void StartHiddenMode() {
	// First, set class Human or Hidden for all of players
	FuncSetPlayerClass();
	
	// Change players team by class
	FuncChangeAllHumanToCT();
	
	// Finally, create The Hidden
	FuncMakeHidden();
}

/** 
 * Timer function 
 */
public Action TimerCountdown(Handle timer) {
	if (gTimer <= 0) {
		gMaxPlayers = FuncCountPlayerConnected();
		//gHiddenIndex = FuncGetRandomPlayerAlive(GetRandomInt(1, gMaxPlayers));
		gHiddenIndex = 1;
		
		bGameBegin = true;
		
		PrintCenterTextAll("Player with ID: %d become The Hidden", gHiddenIndex);
		StartHiddenMode();
		
		return Plugin_Stop;
	}
	
	if (gTimer == 1) {
		EmitSoundToAll(gSound_Countdown[0]);
		PrintCenterTextAll("The Hidden will be selected after 1 second");
	}
	else {
		PrintCenterTextAll("The Hidden will be selected after %d seconds", gTimer);
		if (gTimer <= 10)EmitSoundToAll(gSound_Countdown[gTimer - 1]);
	}
	
	gTimer--;
	
	return Plugin_Continue;
}

public Action OnSkillCountdown(Handle timer) {
	if (gSkillCountdown <= 0.0) {
		Timer_SkillCountDown = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	gSkillCountdown--;
	
	return Plugin_Continue;
}

public Action ShowHiddenHP(Handle timer) {
	if (!bRoundStart || bRoundEnd || gHiddenIndex == 0) {
		//KillTimer(Timer_ShowHiddenHP)
		return Plugin_Stop;
	}
	
	if (bGameBegin) {
		static char name[64];
		GetClientName(gHiddenIndex, name, charsmax(name));
		if (gSkillCountdown > 0.0)
			PrintHintTextToAll("Hidden: %s\nHP: %d\nSkill: <font color='#ff0000'>Boost</font> (Press F) %d", name, GetClientHealth(gHiddenIndex), RoundFloat(gSkillCountdown));
		else
			PrintHintTextToAll("Hidden: %s\nHP: %d\nSkill: Boost (Press F)", name, GetClientHealth(gHiddenIndex));
	}
	
	return Plugin_Continue;
}

public Action TimerSetVisible(Handle timer, Handle data) {
	int subtractionValue = 255 / 2 + 1;
	
	if (gAlpha <= 0) {
		Timer_SetHiddenVisible = null;
		return Plugin_Stop;
	}
	else {
		gAlpha -= subtractionValue;
		SetEntityRenderColor(gHiddenIndex, 255, 255, 255, gAlpha);
		PrintToChatAll("Set Alpha Render: %d", gAlpha);
	}
	
	return Plugin_Continue;
}

/**************************
 **** PRIVATE FUNCTION ****
 **************************/

void FuncMakeHidden() {
	// Change The Hidden to T
	FuncChangeHiddenToT();
	
	// Hidden Appear sound
	EmitSoundToAll(gSound_HiddenAppear);
	
	// Set abilities to The Hidden: HP, Speed, Gravity,....
	SetEntityHealth(gHiddenIndex, GetConVarInt(pCvar_iHiddenHP));
	
	float speedMul = GetConVarFloat(pCvar_fHiddenSpeedMul);
	SetEntPropFloat(gHiddenIndex, Prop_Send, "m_flLaggedMovementValue", speedMul);
	
	float gravityMul = GetConVarFloat(pCvar_fHiddenGravityMul);
	SetEntityGravity(gHiddenIndex, gravityMul);
	
	// Make The Hidden invisible by using hook
	SDKHook(gHiddenIndex, SDKHook_SetTransmit, Hook_SetTransmit);
	SetEntityRenderMode(gHiddenIndex, RENDER_TRANSALPHA);
	
	// The Hidden can see through wall
	for (int id = 1; id <= MaxClients; id++) {
		if (!IsClientValid(id))
			continue;
		
		if (!IsPlayerAlive(id))
			continue;
		
		if (id != gHiddenIndex) {
			SetupGlowSkin(id);
		}
	}
	
	if (GetConVarBool(pCvar_bShowHiddenHP))
		CreateTimer(0.5, ShowHiddenHP, _, TIMER_REPEAT);
	
	// Strip all weapon except knife
	int knife = GetPlayerWeaponSlot(gHiddenIndex, 2);
	if (IsValidEntity(knife)) {
		char knife_name[PLATFORM_MAX_PATH];
		GetEntityClassname(knife, knife_name, charsmax(knife_name));
		Client_RemoveAllWeapons(gHiddenIndex, knife_name, true);
	}
}

void DoSkill(int iClient) {
	// Get current player's velocity
	float fEyeAngles[3], fDirection[3];
	GetClientEyeAngles(iClient, fEyeAngles);
	GetAngleVectors(fEyeAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
	
	float fPower = GetConVarFloat(pCvar_fJumpPower);
	ScaleVector(fDirection, fPower);
	
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, fDirection);
}

void SetupGlowSkin(int client) {
	if (!IsPlayerAlive(client))
		return;
	
	char sModel[PLATFORM_MAX_PATH];
	GetClientModel(client, sModel, sizeof(sModel));
	int iSkin = CPS_SetSkin(client, sModel, CPS_RENDER);
	
	if (iSkin == -1)
		return;
	
	if (SDKHookEx(iSkin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin))
		SetupGlow(client, iSkin);
}

void SetupGlow(int client, int iSkin) {
	int iOffset;
	
	if ((iOffset = GetEntSendPropOffs(iSkin, "m_clrGlow")) == -1)
		return;
	
	SetEntProp(iSkin, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(iSkin, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(iSkin, Prop_Send, "m_flGlowMaxDist", 9999.0);
	
	int iRed = 255;
	int iGreen = 255;
	int iBlue = 255;
	
	SetEntData(iSkin, iOffset, iRed, _, true);
	SetEntData(iSkin, iOffset + 1, iGreen, _, true);
	SetEntData(iSkin, iOffset + 2, iBlue, _, true);
	SetEntData(iSkin, iOffset + 3, 255, _, true);
}

void DisablePlayerGlow() {
	for (int id = 1; id <= MaxClients; id++) {
		if (!IsClientValid(id))
			continue;
		
		if (!IsPlayerAlive(id))
			continue;
		
		if (id != gHiddenIndex) {
			UnhookGlow(id);
		}
	}
}

void UnhookGlow(int client)
{
	if (!IsClientValid(client))
		return;
	
	int iSkin = CPS_GetSkin(client);
	if (IsValidEntity(iSkin))
	{
		SetEntProp(iSkin, Prop_Send, "m_bShouldGlow", false, 1);
		SDKUnhook(iSkin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin);
	}
}

void FuncChangePlayerTeam(int iClient, int newTeam) {
	// Stop if change to CS_TEAM_NONE
	if (newTeam == CS_TEAM_NONE)return;
	
	int curTeam = GetClientTeam(iClient);
	
	// Stop f new team is the current team
	if (curTeam == newTeam)return;
	
	// Change team
	CS_SwitchTeam(iClient, newTeam);
}

void FuncSetPlayerClass() {
	for (int id = 1; id <= MaxClients; id++) {
		if (IsClientConnected(id)) {
			if (id != gHiddenIndex)
				gPlayerClass[id] = TEAM_HUMAN;
			else
				gPlayerClass[id] = TEAM_HIDDEN;
		}
	}
}

void FuncChangeAllHumanToCT() {
	for (int id = 1; id <= MaxClients; id++) {
		if (!IsClientValid(id) || gPlayerClass[id] != TEAM_HUMAN)continue;
		
		if (gPlayerClass[id] == TEAM_HUMAN)
			FuncChangePlayerTeam(id, CS_TEAM_CT);
	}
}

void FuncChangeHiddenToT() {
	// Stop if no The Hidden selected
	if (gHiddenIndex == 0)return;
	
	// Check chosen player is set to The Hidden or not
	if (gPlayerClass[gHiddenIndex] != TEAM_HIDDEN)return;
	
	// Everything is done
	FuncChangePlayerTeam(gHiddenIndex, CS_TEAM_T);
}

int FuncGetRandomPlayerAlive(int n) {
	static iAlive, id;
	iAlive = 0;
	
	for (id = 1; id <= MaxClients; id++) {
		if (IsPlayerAlive(id))iAlive++;
		if (iAlive == n)return id;
	}
	
	return -1;
}


void FuncBalanceTeam() {
	// Get amount of users playing
	static iPlayersNum;
	iPlayersNum = FuncCountPlayerConnected();
	
	// No players, don't bother
	if (iPlayersNum < 1)return;
	
	// Split players evenly
	static iTerrors, iMaxTerrors, id, curTeam;
	iMaxTerrors = iPlayersNum / 2;
	iTerrors = 0;
	
	// First, set everyone to CT
	for (id = 1; id <= MaxClients; id++) {
		// Skip if not connected
		if (!IsClientConnected(id))
			continue;
		
		curTeam = GetClientTeam(id);
		
		// Skip if not playing
		if (curTeam == CS_TEAM_SPECTATOR || curTeam == CS_TEAM_NONE)
			continue;
		
		// Set team
		FuncChangePlayerTeam(id, CS_TEAM_CT);
	}
	
	// Then randomly set half of the players to Terrorists
	while (iTerrors < iMaxTerrors)
	{
		// Keep looping through all players
		if (++id > MaxClients)id = 1;
		
		// Skip if not connected
		if (!IsClientConnected(id))
			continue;
		
		// Skip if not playing or already a Terrorist
		if (GetClientTeam(id) != CS_TEAM_CT)
			continue;
		
		// Random chance
		if (GetRandomInt(0, 1)) {
			FuncChangePlayerTeam(id, CS_TEAM_T);
			iTerrors++;
		}
	}
}

int FuncCountPlayerConnected() {
	static iConnect, id;
	iConnect = 0;
	
	for (id = 1; id <= MaxClients; id++) {
		if (IsClientConnected(id)) {
			iConnect++;
		}
	}
	
	return iConnect;
}

int FuncCountCTsAlive() {
	static iCTs, id;
	iCTs = 0;
	
	for (id = 1; id <= MaxClients; id++) {
		if (IsPlayerAlive(id)) {
			if (GetClientTeam(id) == CS_TEAM_CT) {
				iCTs++;
			}
		}
	}
	
	return iCTs;
}

int FuncCountTsAlive() {
	static iTs, id;
	iTs = 0;
	
	for (id = 1; id <= MaxClients; id++) {
		if (IsPlayerAlive(id)) {
			if (GetClientTeam(id) == CS_TEAM_T) {
				iTs++;
			}
		}
	}
	
	return iTs;
}

bool IsClientValid(int client) {
	return (1 <= client && client <= MaxClients && IsClientInGame(client)) ? true : false;
}

/***************************************************
	* Some of these stocks were extracted from  *
	* SMLib and were changed in order to 		*
	* suitable for this plugin.					* 
	* 	    ___  _____  ____   ____         	*
	* 	   |       |   |    | |      |  /   	*
	* 	   |__     |   |    | |      |/     	*
	* 	      |    |   |    | |      |\     	*
	* 	   ___|    |   |____| |____  |  \  		*
	* 											*
 ***************************************************/
stock void Dissolve(client, type) {
    if (!IsClientConnected(client)) return;

    int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
    if (ragdoll<0) return;

    char dname[32];
    char dtype[32];
    Format(dname, sizeof(dname), "dis_%d", client);
    Format(dtype, sizeof(dtype), "%d", type);
    
    int ent = CreateEntityByName("env_entity_dissolver");
    if (ent>0) {
        DispatchKeyValue(ragdoll, "targetname", dname);
        DispatchKeyValue(ent, "dissolvetype", dtype);
        DispatchKeyValue(ent, "target", dname);
        DispatchKeyValue(ent, "magnitude", "10");
        AcceptEntityInput(ent, "Dissolve", ragdoll, ragdoll);
        AcceptEntityInput(ent, "Kill");
    }
}

stock void DropWeapons(int client)
{
	int weapon;
	for (int i = 0; i < CS_SLOT_C4 && i != 2; i++)
	{
		if ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
		{  
			if (IsValidEdict(weapon))
			{
				CS_DropWeapon(client, weapon, true);
			}
		}
	}
}

/**
 * Gets the Classname of an entity.
 * This is like GetEdictClassname(), except it works for ALL
 * entities, not just edicts.
 *
 * @param entity			Entity index.
 * @param buffer			Return/Output buffer.
 * @param size				Max size of buffer.
 * @return					
 */
stock bool Entity_GetClassName(int entity, char[] buffer, int size)
{
	GetEntPropString(entity, Prop_Data, "m_iClassname", buffer, size);
	
	if (buffer[0] == '\0') {
		return false;
	}
	
	return true;
}

/**
 * Checks if an entity is a player or not.
 * No checks are done if the entity is actually valid,
 * the player is connected or ingame.
 *
 * @param entity			Entity index.
 * @return 				True if the entity is a player, false otherwise.
 */
stock bool Entity_IsPlayer(int entity)
{
	if (entity < 1 || entity > MaxClients) {
		return false;
	}
	
	return true;
}

/**
 * Checks if an entity matches a specific entity class.
 *
 * @param entity		Entity Index.
 * @param class			Classname String.
 * @return				True if the classname matches, false otherwise.
 */
stock bool Entity_ClassNameMatches(int entity, const char[] className, bool partialMatch = false)
{
	decl String:entity_className[64];
	Entity_GetClassName(entity, entity_className, sizeof(entity_className));
	
	if (partialMatch) {
		return (StrContains(entity_className, className) != -1);
	}
	
	return StrEqual(entity_className, className);
}

/**
 * Kills an entity on the next frame (delayed).
 * It is safe to use with entity loops.
 * If the entity is is player ForcePlayerSuicide() is called.
 *
 * @param kenny			Entity index.
 * @return 				True on success, false otherwise
 */
stock bool Entity_Kill(int entity)
{
	if (Entity_IsPlayer(entity)) {
		ForcePlayerSuicide(entity);
		return true;
	}
	
	return AcceptEntityInput(entity, "kill");
}

/**
 * Gets the offset for a client's weapon list (m_hMyWeapons).
 * The offset will saved globally for optimization.
 *
 * @param client		Client Index.
 * @return				Weapon list offset or -1 on failure.
 */
stock int Client_GetWeaponsOffset(int client)
{
	static offset = -1;
	
	if (offset == -1) {
		offset = FindDataMapInfo(client, "m_hMyWeapons");
	}
	
	return offset;
}

/**
 * Removes all weapons of a client.
 * You can specify a weapon it shouldn't remove and if to
 * clear the player's ammo for a weapon when it gets removed.
 *
 * @param client 		Client Index.
 * @param exclude		If not empty, this weapon won't be removed from the client.
 * @param clearAmmo		If true, the ammo the player carries for all removed weapons are set to 0 (primary and secondary).
 * @return				Number of removed weapons.
 */
stock Client_RemoveAllWeapons(int client, const char[] exclude = "", bool clearAmmo = false)
{
	int offset = Client_GetWeaponsOffset(client) - 4;
	
	int numWeaponsRemoved = 0;
	for (int i = 0; i < 48; i++) {
		offset += 4;
		
		int weapon = GetEntDataEnt2(client, offset);
		
		if (!IsValidEdict(weapon)) {
			continue;
		}
		
		if (exclude[0] != '\0' && Entity_ClassNameMatches(weapon, exclude)) {
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", weapon);
			ChangeEdictState(client, FindDataMapInfo(client, "m_hActiveWeapon"));
			continue;
		}
		
		if (clearAmmo) {
			int offset_ammo = FindDataMapInfo(client, "m_iAmmo");
			
			int priOffset = offset_ammo + (GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType") * 4);
			SetEntData(client, priOffset, 0, 4, true);
			
			int secondOffset = offset_ammo + (GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoType") * 4);
			SetEntData(client, secondOffset, 0, 4, true);
		}
		
		if (RemovePlayerItem(client, weapon)) {
			Entity_Kill(weapon);
		}
		
		numWeaponsRemoved++;
	}
	
	return numWeaponsRemoved;
} 