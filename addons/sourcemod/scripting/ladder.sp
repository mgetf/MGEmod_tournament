
bool LoadSpawnPoints()
{
    char txtfile[256];
    BuildPath(Path_SM, txtfile, sizeof(txtfile), g_spawnFile);

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
                            KvGetSectionName(kv, g_sArenaOriginalName[g_iArenaCount], 64);
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
                                        SetFailState("Error in cfg file. Wrong number of parametrs (%d) on spawn <%i> in arena <%s>",count,g_iArenaSpawns[g_iArenaCount],g_sArenaOriginalName[g_iArenaCount]);
                                    }
                                } while (KvGetNameSymbol(kv, intstr2, id));
                                LogMessage("Loaded %d spawns on arena %s.",g_iArenaSpawns[g_iArenaCount], g_sArenaOriginalName[g_iArenaCount]);
                            } else {
                                LogError("Could not load spawns on arena %s.", g_sArenaOriginalName[g_iArenaCount]);
                            }

                            if (KvGetNameSymbol(kv, "cap", id)) {
                                KvGetString(kv, "cap",  g_sArenaCap[g_iArenaCount], 64);
                                g_bArenaHasCap[g_iArenaCount] = true;

                                LogMessage("Found cap point on arena %s.", g_sArenaOriginalName[g_iArenaCount]);
                            } else {
                                g_bArenaHasCap[g_iArenaCount] = false;
                            }

                            if (KvGetNameSymbol(kv, "cap_trigger", id)) {
                                KvGetString(kv, "cap_trigger",  g_sArenaCapTrigger[g_iArenaCount], 64);
                                g_bArenaHasCapTrigger[g_iArenaCount] = true;
                            }

                            //optional parametrs
                            g_iArenaMgelimit[g_iArenaCount] = MMUSEFRAGLIMIT ? MMFRAGLIMIT : KvGetNum(kv, "fraglimit", g_iDefaultFragLimit);
                            g_iArenaCaplimit[g_iArenaCount] = KvGetNum(kv, "caplimit", g_iDefaultFragLimit);
                            g_iArenaMinRating[g_iArenaCount] = KvGetNum(kv, "minrating", -1);
                            g_iArenaMaxRating[g_iArenaCount] = KvGetNum(kv, "maxrating", -1);
                            g_bArenaMidair[g_iArenaCount] = KvGetNum(kv, "midair", 0) ? true : false ;
                            g_iArenaCdTime[g_iArenaCount] = KvGetNum(kv, "cdtime", DEFAULT_CDTIME);
                            g_bArenaMGE[g_iArenaCount] = KvGetNum(kv, "mge", 0) ? true : false ;
                            g_fArenaHPRatio[g_iArenaCount] = KvGetFloat(kv, "hpratio", 1.5);
                            g_bArenaEndif[g_iArenaCount] = KvGetNum(kv, "endif", 0) ? true : false ;
                            g_iArenaAirshotHeight[g_iArenaCount] = KvGetNum(kv, "airshotheight", 250);
                            g_bArenaBoostVectors[g_iArenaCount] = KvGetNum(kv, "boostvectors", 0) ? true : false ;
                            g_bArenaBBall[g_iArenaCount] = KvGetNum(kv, "bball", 0) ? true : false ;
                            g_bVisibleHoops[g_iArenaCount] = KvGetNum(kv, "vishoop", 0) ? true : false ;
                            g_iArenaEarlyLeave[g_iArenaCount] = KvGetNum(kv, "earlyleave", 0);
                            g_bArenaInfAmmo[g_iArenaCount] = KvGetNum(kv, "infammo", 1) ? true : false ;
                            g_bArenaShowHPToPlayers[g_iArenaCount] = KvGetNum(kv, "showhp", 1) ? true : false ;
                            g_fArenaMinSpawnDist[g_iArenaCount] = KvGetFloat(kv, "mindist", 100.0);
                            g_bFourPersonArena[g_iArenaCount] = KvGetNum(kv, "4player", 0) ? true : false;
                            g_bArenaAllowChange[g_iArenaCount] = KvGetNum(kv, "allowchange", 0) ? true : false;
                            g_bArenaAllowKoth[g_iArenaCount] = KvGetNum(kv, "allowkoth", 0) ? true : false;
                            g_bArenaKothTeamSpawn[g_iArenaCount] = KvGetNum(kv, "kothteamspawn", 0) ? true : false;
                            g_fArenaRespawnTime[g_iArenaCount] = KvGetFloat(kv, "respawntime", 0.1);
                            g_bArenaAmmomod[g_iArenaCount] = KvGetNum(kv, "ammomod", 0) ? true : false;
                            g_bArenaUltiduo[g_iArenaCount] = KvGetNum(kv, "ultiduo", 0) ? true : false;
                            g_bArenaKoth[g_iArenaCount] = KvGetNum(kv, "koth", 0) ? true : false;
                            g_bArenaTurris[g_iArenaCount] = KvGetNum(kv, "turris", 0) ? true : false;
                            g_iDefaultCapTime[g_iArenaCount] = KvGetNum(kv, "timer", 180);
                            //parsing allowed classes for current arena
                            char sAllowedClasses[128];
                            KvGetString(kv, "classes", sAllowedClasses, sizeof(sAllowedClasses));
                            LogMessage("%s classes: <%s>", g_sArenaOriginalName[g_iArenaCount], sAllowedClasses);
                            ParseAllowedClasses(sAllowedClasses,g_tfctArenaAllowedClasses[g_iArenaCount]);
                            g_iArenaFraglimit[g_iArenaCount] = g_iArenaMgelimit[g_iArenaCount];
                            UpdateArenaName(g_iArenaCount);
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

int ResetPlayer(int client)
{
    int arena_index = g_iPlayerArena[client];
    int player_slot = g_iPlayerSlot[client];

    if (!arena_index || !player_slot)
    {
        return 0;
    }

    g_iPlayerSpecTarget[client] = 0;

    if (player_slot == SLOT_ONE || player_slot == SLOT_THREE)
        ChangeClientTeam(client, TEAM_RED);
    else
        ChangeClientTeam(client, TEAM_BLU);

    //This logic doesn't work with 2v2's
    //new team = GetClientTeam(client);
    //if (player_slot - team != SLOT_ONE - TEAM_RED)
    //  ChangeClientTeam(client, player_slot + TEAM_RED - SLOT_ONE);

    TFClassType class;
    class = g_tfctPlayerClass[client] ? g_tfctPlayerClass[client] : TFClass_Soldier;

    if (!IsPlayerAlive(client) || g_bArenaBBall[arena_index])
    {
        if (class != TF2_GetPlayerClass(client))
            TF2_SetPlayerClass(client, class);

        TF2_RespawnPlayer(client);
    } else {
        TF2_RegeneratePlayer(client);
        ExtinguishEntity(client);
    }

    g_iPlayerMaxHP[client] = GetEntProp(client, Prop_Data, "m_iMaxHealth");

    if (g_bArenaMidair[arena_index])
        g_iPlayerHP[client] = g_iMidairHP;
    else
        g_iPlayerHP[client] = g_iPlayerHandicap[client] ? g_iPlayerHandicap[client] : RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]);

    if (g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index])
        SetEntProp(client, Prop_Data, "m_iHealth", g_iPlayerHandicap[client] ? g_iPlayerHandicap[client] : RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]));

    ShowPlayerHud(client);
    ResetClientAmmoCounts(client);
    CreateTimer(0.1, Timer_Tele, GetClientUserId(client));

    return 1;
}

public Action Timer_Tele(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    int arena_index = g_iPlayerArena[client];

    if (!arena_index)
        return;

    int player_slot = g_iPlayerSlot[client];
    if ((!g_bFourPersonArena[arena_index] && player_slot > SLOT_TWO) || (g_bFourPersonArena[arena_index] && player_slot > SLOT_FOUR))
    {
        return;
    }

    float vel[3] =  { 0.0, 0.0, 0.0 };


    int random_int;
    int offset_high, offset_low;
    if (g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE)
    {
        offset_high = ((g_iArenaSpawns[arena_index]) / 2);
        random_int = GetRandomInt(1, offset_high); //The first half of the player spawns are for slot one and three.
    } else {
        offset_high = (g_iArenaSpawns[arena_index]);
        offset_low = (((g_iArenaSpawns[arena_index]) / 2) + 1);
        random_int = GetRandomInt(offset_low, offset_high);
    }

    TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][random_int], g_fArenaSpawnAngles[arena_index][random_int], vel);
    EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][random_int], _, SNDLEVEL_NORMAL, _, 1.0);
    ShowPlayerHud(client);
    return;

}