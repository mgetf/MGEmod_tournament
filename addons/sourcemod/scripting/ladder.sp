#pragma semicolon 1
#include <sourcemod>
#include <ripext>

#define MAXARENAS 63
#define MAXSPAWNS 15
#define MAPCONFIGFILE "configs/mgemod_spawns.cfg"

WebSocket g_hWebSocket; 

// Global Variables
char g_sMapName[64];

int g_iArenaCount;
int g_iArenaSpawns[MAXARENAS + 1];

char g_sArenaName[MAXARENAS + 1][64];

float g_fArenaSpawnOrigin     [MAXARENAS + 1][MAXSPAWNS+1][3];
float g_fArenaSpawnAngles     [MAXARENAS + 1][MAXSPAWNS+1][3];

bool LoadSpawnPoints() {
    char txtfile[256];
    BuildPath(Path_SM, txtfile, sizeof(txtfile), MAPCONFIGFILE);

    char spawn[64];
    GetCurrentMap(g_sMapName, sizeof(g_sMapName));

    KeyValues kv = new KeyValues("SpawnConfig");

    char spawnCo[6][16];
    char kvmap[32];
    int count;
    int i;
    g_iArenaCount = 0;

    for (int j = 0; j <= MAXARENAS; j++)
    {
        g_iArenaSpawns[j] = 0;
    }

    if (FileToKeyValues(kv, txtfile))
    {
        if (KvGotoFirstSubKey(kv))
        {
            do
            {
                KvGetSectionName(kv, kvmap, 64);
                if (StrEqual(g_sMapName, kvmap, false))
                {
                    if (KvGotoFirstSubKey(kv))
                    {
                        do
                        {
                            g_iArenaCount++;
                            KvGetSectionName(kv, g_sArenaName[g_iArenaCount], 64);
                            int id;
                            if (KvGetNameSymbol(kv, "1", id))
                            {
                                char intstr[4];
                                char intstr2[4];
                                do
                                {
                                    g_iArenaSpawns[g_iArenaCount]++;
                                    IntToString(g_iArenaSpawns[g_iArenaCount], intstr, sizeof(intstr));
                                    IntToString(g_iArenaSpawns[g_iArenaCount]+1, intstr2, sizeof(intstr2));
                                    KvGetString(kv, intstr, spawn, sizeof(spawn));
                                    count = ExplodeString(spawn, " ", spawnCo, 6, 16);
                                    if (count==6)
                                    {
                                        for (i=0; i<3; i++)
                                        {
                                            g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i] = StringToFloat(spawnCo[i]);
                                        }
                                        for (i=3; i<6; i++)
                                        {
                                            g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i-3] = StringToFloat(spawnCo[i]);
                                        }
                                    } else if(count==4) {
                                        for (i=0; i<3; i++)
                                        {
                                            g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i] = StringToFloat(spawnCo[i]);
                                        }
                                        g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][0] = 0.0;
                                        g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][1] = StringToFloat(spawnCo[3]);
                                        g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][2] = 0.0;
                                    } else {
                                        SetFailState("Error in cfg file. Wrong number of parametrs (%d) on spawn <%i> in arena <%s>",count,g_iArenaSpawns[g_iArenaCount],g_sArenaName[g_iArenaCount]);
                                    }
                                } while (KvGetNameSymbol(kv, intstr2, id));
                                LogMessage("Loaded %d spawns on arena %s.",g_iArenaSpawns[g_iArenaCount], g_sArenaName[g_iArenaCount]);
                            } else {
                                LogError("Could not load spawns on arena %s.", g_sArenaName[g_iArenaCount]);
                            }
                        } while (KvGotoNextKey(kv));
                    }
                    break;
                }
            } while (KvGotoNextKey(kv));
            if (g_iArenaCount)
            {
                LogMessage("Loaded %d arenas. MGEMod enabled.",g_iArenaCount);
                CloseHandle(kv);
                return true;
            } else {
                CloseHandle(kv);
                return false;
            }
        } else {
            LogError("Error in cfg file.");
            return false;
        }
    } else {
        LogError("Error. Can't find cfg file");
        return false;
    }
}

public void OnPluginStart()
{
	PrintToServer("---------------------------------------------------------");
	PrintToServer("---------------------------------------------------------");
	PrintToServer("------------ladder plugin starting-----------------------");
	PrintToServer("---------------------------------------------------------");
	PrintToServer("---------------------------------------------------------");
}

public void OnAllPluginsLoaded()
{	
	PrintToServer("----ladder plugin loaded----");

	char szUrl[256];
	Format(szUrl, sizeof(szUrl), "ws://b59a-2601-19b-e83-ad70-1449-5006-3b5d-7a3e.ngrok-free.app/server_ws"); // Hardcoded placeholder URL

	g_hWebSocket = new WebSocket(szUrl);
	if (g_hWebSocket == null)
	{
		LogError("Failed to create WebSocket object.");
		return;
	}

	g_hWebSocket.Connect();
	g_hWebSocket.SetReadCallback(WebSocket_JSON, wsReadCallback);
	g_hWebSocket.SetConnectCallback(wsConnCallback);
	g_hWebSocket.SetDisconnectCallback(wsDisconnCallback);

	PrintToServer("Attempting to connect to WebSocket: %s", szUrl);
	
    int isMapAm = LoadSpawnPoints();
    if (!isMapAm)
    {
        SetFailState("Map not supported. Laddermod disabled.");
        return;
    }
}

public void OnPluginEnd()
{
	if (g_hWebSocket != null)
	{
		g_hWebSocket.Close();
		delete g_hWebSocket; // Make sure to free the memory
		g_hWebSocket = null;
	}
}

public void wsReadCallback(WebSocket sock, JSON message, any data)
{
	JSONObject jsonObj = view_as<JSONObject>(message);

	char typeBuf[30];
	jsonObj.GetString("type", typeBuf, sizeof(typeBuf));
	PrintToServer("WebSocket - Command Type: %s", typeBuf);
	JSONObject payload = view_as<JSONObject>(jsonObj.Get("payload")); // jsonObj.Get() returns a Handle

	char message[64];
	payload.GetString("message", message, sizeof(message));
	PrintToServer("ServerAck says: %s", message);
}

public void wsConnCallback(WebSocket sock, any data)
{
	PrintToServer("connected to ws");
	JSONObject hworld = new JSONObject();
	hworld.SetString("type", "ServerHello");
	JSONObject payload = new JSONObject();
	bool ok = hworld.Set("payload", payload);
	if (!ok)
		PrintToServer("Failed to set json payload");

	char sned[1000];
	hworld.ToString(sned, sizeof(sned));
	sock.WriteString(sned);
	PrintToServer("Sending hello %s", sned);
	delete payload;
	delete hworld;
}

public Action Timer_ConnectToLadder(Handle timer, int data)
{
    PrintToServer("Connecting to Ladder");
    g_hWebSocket.Connect();
}

public void wsDisconnCallback(WebSocket sock, any data)
{
    PrintToServer("disconnected from ws, retrying");
    CreateTimer(5.0, Timer_ConnectToLadder, 0);
}

//------------------------ ingame events
/* OnClientPostAdminCheck(client)
 *
 * Called once a client is fully in-game, and authorized with Steam.
 * Client-specific variables are initialized here.
 * -------------------------------------------------------------------------- */
public void OnClientPostAdminCheck(int client)
{
	JSONObject msg = new JSONObject();
	msg.SetString("type", "PlayerConnected");

    JSONObject payload = new JSONObject();

	char player_64[50];
	GetClientAuthId(client, AuthId_SteamID64, player_64, sizeof(player_64));
	payload.SetString("steam_id", player_64);

	char client_name[MAX_NAME_LENGTH];
	GetClientName(client, client_name, sizeof(client_name));
	payload.SetString("name", client_name);

	msg.Set("payload", payload);

	char send[3000];
	msg.ToString(send, sizeof(send));

	g_hWebSocket.WriteString(send);
}


/* OnClientDisconnect(client)
*
* When a client disconnects from the server.
* Client-specific timers are killed here.
* -------------------------------------------------------------------------- */
public void OnClientDisconnect(int client)
{
	JSONObject msg = new JSONObject();
	msg.SetString("type", "PlayerDisconnected");

    JSONObject payload = new JSONObject();

	char player_64[50];
	GetClientAuthId(client, AuthId_SteamID64, player_64, sizeof(player_64));
	payload.SetString("steam_id", player_64);

	msg.Set("payload", payload);

	char send[3000];
	msg.ToString(send, sizeof(send));

	g_hWebSocket.WriteString(send);
}
