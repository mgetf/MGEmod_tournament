#include <sourcemod>
#include <ripext>

WebSocket g_hWebSocket; // Declare a global WebSocket handle

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
	Format(szUrl, sizeof(szUrl), "ws://b59a-2601-19b-e83-ad70-1449-5006-3b5d-7a3e.ngrok-free.app/endpoint"); // Hardcoded placeholder URL

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
	char tsbuf[1000]; //tostring buf
	message.ToString(tsbuf, sizeof(tsbuf));

	if (StrEqual(tsbuf, "")) {
		PrintToServer("Empty typed json message");
		return;
	}

	// I honestly have no idea how to get a JSONObject from the JSON class. So I have to tostring -> fromstring it.
	JSONObject msg = new JSONObject();
	msg = JSONObject.FromString(tsbuf);
	char typeBuf[30];
	msg.GetString("type", typeBuf, sizeof(typeBuf));
    JSONObject payload = view_as<JSONObject>(msg.Get("payload"));
	PrintToServer("WebSocket - Data: %s", payload);
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