// A 2v2 ladder duo queue TF2 server where players can only enter matches with a mutually selected partner. Matches run in synchronized rounds: all matches start together, and the next round only begins once every match ends. Winners move up the ladder, losers move down. Top-rank match winners earn ladder points. Duo queue is enforced via a command-based opt-in system (!add + mutual acceptance).

// Duo team structure
enum struct DuoTeam {
    int player1;           // First player's client index
    int player2;           // Second player's client index
    char player1SteamID[64]; // For persistence between connects/disconnects
    char player2SteamID[64]; // For persistence between connects/disconnects
    int ladderPosition;    // Current position on ladder
    int ladderPoints;      // Accumulated ladder points
    bool inMatch;          // Whether currently in a match
    int currentArena;      // Arena they're currently in (if in a match)
    int wins;              // Total wins for stats
    int losses;            // Total losses for stats
}

// Match structure
enum struct LadderMatch {
    int team1Index;        // Index in g_DuoTeams array for team 1
    int team2Index;        // Index in g_DuoTeams array for team 2
    int arenaIndex;        // Arena where match is taking place
    int team1Score;        // Current score for team 1
    int team2Score;        // Current score for team 2
    bool isComplete;       // Whether match is complete
}

// Global arrays and variables
#define MAX_DUO_TEAMS 32   // Maximum number of duo teams
#define MAX_MATCHES 16     // Maximum concurrent matches (arenas)

DuoTeam g_DuoTeams[MAX_DUO_TEAMS];          // Array of all duo teams
int g_DuoTeamCount = 0;                     // Current number of duo teams
LadderMatch g_CurrentMatches[MAX_MATCHES];  // Current active matches
int g_MatchCount = 0;                       // Number of active matches
bool g_RoundInProgress = false;             // Whether a round is currently in progress
bool g_WaitingForMatchesComplete = false;   // Whether we're waiting for all matches to complete

// Command: Player requests to form a duo with another player
public Action Command_RequestDuo(int client, int args) {
    if (!IsValidClient(client))
        return Plugin_Handled;
        
    // If already in a duo, can't request another
    if (IsPlayerInDuo(client)) {
        PrintToChat(client, "You are already in a duo team. Use !leaveduo first.");
        return Plugin_Handled;
    }
    
    // Get target player from command args
    char targetName[MAX_NAME_LENGTH];
    GetCmdArg(1, targetName, sizeof(targetName));
    
    int targetClient = FindTarget(client, targetName, true, false);
    if (targetClient == -1)
        return Plugin_Handled; // FindTarget will provide appropriate error message
    
    // Can't request yourself
    if (targetClient == client) {
        PrintToChat(client, "You cannot form a duo with yourself.");
        return Plugin_Handled;
    }
    
    // Target player is already in a duo
    if (IsPlayerInDuo(targetClient)) {
        PrintToChat(client, "%N is already in a duo team.", targetClient);
        return Plugin_Handled;
    }
    
    // Send request to target player
    g_PendingDuoRequests[targetClient] = client;
    PrintToChat(targetClient, "%N has requested to form a duo with you. Type !acceptduo to accept.", client);
    PrintToChat(client, "Duo request sent to %N.", targetClient);
    
    return Plugin_Handled;
}

// Command: Accept a duo request
public Action Command_AcceptDuo(int client, int args) {
    if (!IsValidClient(client))
        return Plugin_Handled;
        
    // No pending request
    if (g_PendingDuoRequests[client] == 0) {
        PrintToChat(client, "You have no pending duo requests.");
        return Plugin_Handled;
    }
    
    int requester = g_PendingDuoRequests[client];
    
    // Requester no longer valid
    if (!IsValidClient(requester)) {
        PrintToChat(client, "The player who requested a duo is no longer available.");
        g_PendingDuoRequests[client] = 0;
        return Plugin_Handled;
    }
    
    // Create the duo team
    if (g_DuoTeamCount >= MAX_DUO_TEAMS) {
        PrintToChat(client, "Maximum number of duo teams reached.");
        return Plugin_Handled;
    }
    
    // Create new duo team
    DuoTeam newTeam;
    newTeam.player1 = requester;
    newTeam.player2 = client;
    GetClientAuthId(requester, AuthId_Steam2, newTeam.player1SteamID, sizeof(newTeam.player1SteamID));
    GetClientAuthId(client, AuthId_Steam2, newTeam.player2SteamID, sizeof(newTeam.player2SteamID));
    newTeam.ladderPosition = g_DuoTeamCount + 1; // Start at bottom of ladder
    newTeam.ladderPoints = 0;
    newTeam.inMatch = false;
    
    g_DuoTeams[g_DuoTeamCount++] = newTeam;
    
    // Notify players
    PrintToChat(requester, "Duo team formed with %N!", client);
    PrintToChat(client, "Duo team formed with %N!", requester);
    
    // Clear request
    g_PendingDuoRequests[client] = 0;
    
    // If round is not in progress, add to queue for next round
    if (!g_RoundInProgress) {
        AddDuoToMatchQueue(g_DuoTeamCount - 1);
    }
    
    return Plugin_Handled;
}

// Start a new synchronized round
void StartSynchronizedRound() {
    if (g_RoundInProgress || g_WaitingForMatchesComplete) {
        LogError("Attempted to start a new round while previous round wasn't fully complete");
        return;
    }
    
    // Calculate how many matches we can create
    int availableTeams = GetAvailableDuoTeamCount();
    int possibleMatches = availableTeams / 2;
    
    if (possibleMatches == 0) {
        PrintToChatAll("Not enough teams for a round. Use !duorequest to form teams.");
        return;
    }
    
    // Limit to available arenas
    int matchesToCreate = possibleMatches;
    if (matchesToCreate > MAX_MATCHES) 
        matchesToCreate = MAX_MATCHES;
    
    // Sort teams by ladder position
    SortDuoTeamsByLadderPosition();
    
    // Create matches pairing teams of similar ladder position
    g_MatchCount = 0;
    for (int i = 0; i < matchesToCreate; i++) {
        // Get the next two available teams
        int team1Index = GetNextAvailableDuoTeam(-1);
        int team2Index = GetNextAvailableDuoTeam(team1Index);
        
        if (team1Index == -1 || team2Index == -1)
            break;
            
        // Create the match
        LadderMatch newMatch;
        newMatch.team1Index = team1Index;
        newMatch.team2Index = team2Index;
        newMatch.arenaIndex = i + 1; // Assuming arenas are 1-indexed
        newMatch.team1Score = 0;
        newMatch.team2Score = 0;
        newMatch.isComplete = false;
        
        g_CurrentMatches[g_MatchCount++] = newMatch;
        
        // Mark teams as in a match
        g_DuoTeams[team1Index].inMatch = true;
        g_DuoTeams[team1Index].currentArena = i + 1;
        g_DuoTeams[team2Index].inMatch = true;
        g_DuoTeams[team2Index].currentArena = i + 1;
        
        // Move players to the arena and set up the match
        SetupMatch(newMatch);
    }
    
    g_RoundInProgress = true;
    
    // Announce the start of the round
    PrintToChatAll("Round starting with %d matches!", g_MatchCount);
    
    // Start global countdown
    CreateTimer(3.0, Timer_StartMatchCountdown);
}

// Timer to start all matches with a countdown
public Action Timer_StartMatchCountdown(Handle timer) {
    static int countdown = 3;
    
    if (countdown > 0) {
        PrintToChatAll("Round starts in %d...", countdown);
        countdown--;
        return Plugin_Continue;
    }
    
    // Start all matches
    PrintToChatAll("FIGHT!");
    
    // Enable player movement and abilities in all matches
    for (int i = 0; i < g_MatchCount; i++) {
        EnableMatch(g_CurrentMatches[i]);
    }
    
    countdown = 3; // Reset for next time
    return Plugin_Stop;
}

// Mark a match as complete
void CompleteMatch(int matchIndex, int winningTeamIndex) {
    if (matchIndex < 0 || matchIndex >= g_MatchCount)
        return;
        
    LadderMatch match = g_CurrentMatches[matchIndex];
    
    // Match already marked complete
    if (match.isComplete)
        return;
        
    // Mark match as complete
    g_CurrentMatches[matchIndex].isComplete = true;
    
    // Update team stats
    int losingTeamIndex = (winningTeamIndex == match.team1Index) ? match.team2Index : match.team1Index;
    
    g_DuoTeams[winningTeamIndex].wins++;
    g_DuoTeams[losingTeamIndex].losses++;
    
    // Mark teams as no longer in a match
    g_DuoTeams[match.team1Index].inMatch = false;
    g_DuoTeams[match.team2Index].inMatch = false;
    
    // Announce result
    char team1Name[128], team2Name[128];
    GetDuoTeamName(match.team1Index, team1Name, sizeof(team1Name));
    GetDuoTeamName(match.team2Index, team2Name, sizeof(team2Name));
    
    if (winningTeamIndex == match.team1Index) {
        PrintToChatAll("Match %d result: %s defeated %s %d-%d", 
            matchIndex + 1, team1Name, team2Name, 
            match.team1Score, match.team2Score);
    } else {
        PrintToChatAll("Match %d result: %s defeated %s %d-%d", 
            matchIndex + 1, team2Name, team1Name, 
            match.team2Score, match.team1Score);
    }
    
    // Check if all matches are complete
    CheckAllMatchesComplete();
}

// Check if all matches are complete
void CheckAllMatchesComplete() {
    if (!g_RoundInProgress)
        return;
        
    for (int i = 0; i < g_MatchCount; i++) {
        if (!g_CurrentMatches[i].isComplete)
            return; // Still have incomplete matches
    }
    
    // All matches complete - process round end and update ladder
    g_RoundInProgress = false;
    g_WaitingForMatchesComplete = false;
    
    // Update ladder positions based on results
    UpdateLadderPositions();
    
    // Announce new ladder standings
    PrintToChatAll("Round complete! Updated ladder standings:");
    for (int i = 0; i < g_DuoTeamCount; i++) {
        char teamName[128];
        GetDuoTeamName(i, teamName, sizeof(teamName));
        PrintToChatAll("%d. %s - %d points", 
            g_DuoTeams[i].ladderPosition, teamName, g_DuoTeams[i].ladderPoints);
    }
    
    // Start a new round after a delay
    CreateTimer(10.0, Timer_StartNextRound);
}

// Timer to start the next round
public Action Timer_StartNextRound(Handle timer) {
    StartSynchronizedRound();
    return Plugin_Stop;
}

// Update ladder positions after a round completes
void UpdateLadderPositions() {
    // First, process ladder points for top teams
    // Assuming top 3 teams get ladder points
    int pointsAwarded[3] = {3, 2, 1}; // Points for 1st, 2nd, 3rd place
    
    for (int i = 0; i < 3 && i < g_DuoTeamCount; i++) {
        int topTeamIndex = GetTeamByLadderPosition(i + 1);
        if (topTeamIndex != -1) {
            // Only award points if the team won their match
            bool teamWon = false;
            for (int j = 0; j < g_MatchCount; j++) {
                if ((g_CurrentMatches[j].team1Index == topTeamIndex && 
                     g_CurrentMatches[j].team1Score > g_CurrentMatches[j].team2Score) ||
                    (g_CurrentMatches[j].team2Index == topTeamIndex && 
                     g_CurrentMatches[j].team2Score > g_CurrentMatches[j].team1Score)) {
                    teamWon = true;
                    break;
                }
            }
            
            if (teamWon) {
                g_DuoTeams[topTeamIndex].ladderPoints += pointsAwarded[i];
                
                char teamName[128];
                GetDuoTeamName(topTeamIndex, teamName, sizeof(teamName));
                PrintToChatAll("%s earned %d ladder points for winning in position %d!", 
                    teamName, pointsAwarded[i], i + 1);
            }
        }
    }
    
    // Now adjust ladder positions based on match results
    for (int i = 0; i < g_MatchCount; i++) {
        int team1Index = g_CurrentMatches[i].team1Index;
        int team2Index = g_CurrentMatches[i].team2Index;
        
        int winnerIndex, loserIndex;
        
        if (g_CurrentMatches[i].team1Score > g_CurrentMatches[i].team2Score) {
            winnerIndex = team1Index;
            loserIndex = team2Index;
        } else {
            winnerIndex = team2Index;
            loserIndex = team1Index;
        }
        
        // If winner is below loser in ladder, swap them
        if (g_DuoTeams[winnerIndex].ladderPosition > g_DuoTeams[loserIndex].ladderPosition) {
            int temp = g_DuoTeams[winnerIndex].ladderPosition;
            g_DuoTeams[winnerIndex].ladderPosition = g_DuoTeams[loserIndex].ladderPosition;
            g_DuoTeams[loserIndex].ladderPosition = temp;
            
            char winnerName[128], loserName[128];
            GetDuoTeamName(winnerIndex, winnerName, sizeof(winnerName));
            GetDuoTeamName(loserIndex, loserName, sizeof(loserName));
            
            PrintToChatAll("%s moves up to position %d, %s moves down to position %d", 
                winnerName, g_DuoTeams[winnerIndex].ladderPosition,
                loserName, g_DuoTeams[loserIndex].ladderPosition);
        }
    }
    
    // Finally, sort teams by ladder position to ensure consistency
    SortDuoTeamsByLadderPosition();
}

// When a player dies in a match
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if (!IsValidClient(victim) || !IsValidClient(attacker))
        return Plugin_Continue;
        
    // Find which match this is part of
    int matchIndex = GetMatchIndexByPlayer(victim);
    if (matchIndex == -1)
        return Plugin_Continue;
        
    LadderMatch match = g_CurrentMatches[matchIndex];
    
    // Determine which team scored
    int victimTeamIndex = GetDuoTeamByPlayer(victim);
    int attackerTeamIndex = GetDuoTeamByPlayer(attacker);
    
    if (victimTeamIndex == -1 || attackerTeamIndex == -1)
        return Plugin_Continue;
        
    // Don't count team kills
    if (victimTeamIndex == attackerTeamIndex)
        return Plugin_Continue;
        
    // Update score
    if (attackerTeamIndex == match.team1Index)
        g_CurrentMatches[matchIndex].team1Score++;
    else if (attackerTeamIndex == match.team2Index)
        g_CurrentMatches[matchIndex].team2Score++;
        
    // Check if match is complete (reached frag limit)
    int fraglimit = GetConVarInt(g_hCvarFragLimit);
    
    if (g_CurrentMatches[matchIndex].team1Score >= fraglimit) {
        CompleteMatch(matchIndex, match.team1Index);
    } else if (g_CurrentMatches[matchIndex].team2Score >= fraglimit) {
        CompleteMatch(matchIndex, match.team2Index);
    }
    
    // Update match HUD
    UpdateMatchHUD(matchIndex);
    
    return Plugin_Continue;
}
