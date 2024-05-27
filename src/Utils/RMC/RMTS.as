// Everything copy-pasted with minor modifications from RMT unless noted otherwise
class RMTS : RMS {
#if TMNEXT
	string LobbyMapUID = "";
	NadeoServices::ClubRoom@ RMTRoom;
	MX::MapInfo@ currentMap;
	MX::MapInfo@ nextMap;
	uint lastPbUpdate = 0;
	array<PBTime@> m_mapPersonalBests;
	array<RMTPlayerScore@> m_playerScores;
	bool m_CurrentlyLoadingRecords = false;
	PBTime@ playerGotGoalActualMap;
	PBTime@ playerGotBelowGoalActualMap;
	uint RMTTimerMapChange = 0;
	bool isSwitchingMap = false;
	bool pressedStopButton = false;
	bool isFetchingNextMap = false;
	dictionary seenMaps;

    //RMS
	int TimeLimit() override { return PluginSettings::RMC_SurvivalMaxTime * 60 * 1000; }

	string GetModeName() override { return "Random Map Together Survival (WIP)";}

    // From RMS
	int RunEndTimestamp() override { 
		int InitialLimit = RMC::ContinueSavedRun ? (RMC::LoadedRemainingTime - TimeLimit()) * -1 : TimeLimit();
		int MaxTime = TimeLimit() - (Skips * 60 * 1000);
		int BonusTime = (GoalTimerIncrease * RMC::GoalMedalCount) - OverflowAdjustmentTime;
		int FinalTimestamp = RMC::RunStartTimestamp + InitialLimit + RMC::TimePaused + BonusTime;
		if (FinalTimestamp > Time::Now + MaxTime) {
			OverflowAdjustmentTime += FinalTimestamp - (Time::Now + MaxTime);
			BonusTime = (GoalTimerIncrease * RMC::GoalMedalCount) - OverflowAdjustmentTime;
			FinalTimestamp = RMC::RunStartTimestamp + InitialLimit + RMC::TimePaused + BonusTime;
		} 
		return FinalTimestamp;
	}


	void Render() override
	{
		if (UI::IsOverlayShown() || (!UI::IsOverlayShown() && PluginSettings::RMC_AlwaysShowBtns)) {
			if (UI::RedButton(Icons::Times + " Stop " + GetModeNameShort()))
			{
				pressedStopButton = true;
				RMC::IsRunning = false;
				@nextMap = null;
				@MX::preloadedMap = null;
#if DEPENDENCY_BETTERCHAT
				BetterChat::SendChatMessage(Icons::Users + " " + GetModeName() + " stopped");
				startnew(CoroutineFunc(BetterChatSendLeaderboard));
#endif
				startnew(CoroutineFunc(ResetToLobbyMap));
			}

			RenderCustomSearchWarning();
			UI::Separator();
		}

		RenderTimer();
		UI::Separator();
		vec2 pos_orig = UI::GetCursorPos();
		RenderGoalMedal();
		vec2 pos_orig_goal = UI::GetCursorPos();
		UI::SetCursorPos(vec2(pos_orig_goal.x+50, pos_orig_goal.y));
		RenderBelowGoalMedal();
		UI::SetCursorPos(vec2(pos_orig.x, pos_orig.y+60));

		RenderMVPPlayer();
		UI::Separator();
		RenderScores();
		
		if (PluginSettings::RMC_DisplayCurrentMap)
		{
			RenderCurrentMap();
		}

		UI::Separator();
		if (RMC::IsRunning && (UI::IsOverlayShown() || (!UI::IsOverlayShown() && PluginSettings::RMC_AlwaysShowBtns))) {
			RenderPlayingButtons();
			UI::Separator();
		}
		DrawPlayerProgress();
	}

	void StartRMTS()
	{
		m_mapPersonalBests = {};
		m_playerScores = {};
		RMC::GoalMedalCount = 0;
		BelowMedalCount = 0;
		RMC::ShowTimer = true;
		RMC::ClickedOnSkip = false;
		pressedStopButton = false;
		Log::Trace(GetModeNameShort() + ": Getting lobby map UID from the room...");
		MXNadeoServicesGlobal::CheckNadeoRoomAsync();
		yield();
		@RMTRoom = MXNadeoServicesGlobal::foundRoom;
		LobbyMapUID = RMTRoom.room.currentMapUid;
		Log::Trace(GetModeNameShort() + ": Lobby map UID: " + LobbyMapUID);
#if DEPENDENCY_BETTERCHAT
		BetterChat::SendChatMessage(Icons::Users + " Starting " + GetModeName() + ".\nGoal medal: " + tostring(PluginSettings::RMC_GoalMedal) + ". Have Fun!");
#endif
		SetupMapStart();
	}

	void SetupMapStart() {
		RMC::IsStarting = true;
		isSwitchingMap = true;
		// Fetch a map
		Log::Trace(GetModeNameShort() + ": Fetching a random map...");
		Json::Value res;
		try {
			res = API::GetAsync(MX::CreateQueryURL())["results"][0];
		} catch {
			Log::Error("ManiaExchange API returned an error, retrying...", true);
			SetupMapStart();
			return;
		}
		Json::Value playedAt = Json::Object();
		Time::Info date = Time::Parse();
		playedAt["Year"] = date.Year;
		playedAt["Month"] = date.Month;
		playedAt["Day"] = date.Day;
		playedAt["Hour"] = date.Hour;
		playedAt["Minute"] = date.Minute;
		playedAt["Second"] = date.Second;
		res["PlayedAt"] = playedAt;
		@currentMap = MX::MapInfo(res);

		// Check for map existence on NadeoServers
		// // // is this rly needed?
		if(!CheckMapValidity()) {
			SetupMapStart();
			return;
		}
		
		SetServerMap();

		// Pause until the correct map is loaded
		while (!TM::IsMapCorrect(currentMap.TrackUID)) sleep(500);

		SetServerTime();

		while (GetApp().CurrentPlayground is null) yield();
		CGamePlayground@ GamePlayground = cast<CGamePlayground>(GetApp().CurrentPlayground);
		while (GamePlayground.GameTerminals.Length < 0) yield();
		while (GamePlayground.GameTerminals[0] is null) yield();
		while (GamePlayground.GameTerminals[0].ControlledPlayer is null) yield();
		CSmPlayer@ player = cast<CSmPlayer>(GamePlayground.GameTerminals[0].ControlledPlayer);
		while (player.ScriptAPI is null) yield();
		CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
		while (playerScriptAPI.Post == 0) yield();
		RMC::RunStartTimestamp = Time::Now;
		RMC::IsRunning = true;
		RMC::IsPaused = false;
		RMC::GotGoalMedalOnCurrentMap = false;
		RMC::GotBelowMedalOnCurrentMap = false;
		startnew(CoroutineFunc(TimerYield));
		startnew(CoroutineFunc(UpdateRecordsLoop));
		RMC::SpawnedMapTimestamp = Time::Now;
		isSwitchingMap = false;
		RMC::IsStarting = false;
		startnew(CoroutineFunc(RMTFetchNextMap));
	}

	void RMTFetchNextMap() {
		isFetchingNextMap = true;
		// Fetch a map
		Log::Trace(GetModeNameShort() + ": Fetching a random map...");
		Json::Value res;
		try {
			res = API::GetAsync(MX::CreateQueryURL())["results"][0];
		} catch {
			Log::Error("ManiaExchange API returned an error, retrying...");
			RMTFetchNextMap();
			return;
		}
		Json::Value playedAt = Json::Object();
		Time::Info date = Time::Parse();
		playedAt["Year"] = date.Year;
		playedAt["Month"] = date.Month;
		playedAt["Day"] = date.Day;
		playedAt["Hour"] = date.Hour;
		playedAt["Minute"] = date.Minute;
		playedAt["Second"] = date.Second;
		res["PlayedAt"] = playedAt;
		@nextMap = MX::MapInfo(res);
		Log::Trace(GetModeNameShort() + ": Next Random map: " + nextMap.Name + " (" + nextMap.TrackID + ")");

		if (PluginSettings::SkipSeenMaps) {
			if (seenMaps.Exists(nextMap.TrackUID)) {
				Log::Trace("Map has been seen, retrying...");
				RMTFetchNextMap();
				return;
			}

			seenMaps[nextMap.TrackUID] = nextMap.TrackUID;
		}

		if (!MXNadeoServicesGlobal::CheckIfMapExistsAsync(nextMap.TrackUID)) {
			Log::Trace(GetModeNameShort() + ": Next map is not on NadeoServices, retrying...");
			@nextMap = null;
			RMTFetchNextMap();
			return;
		}

		isFetchingNextMap = false;
	}

	void RMTSwitchMap() {
		RMC::PauseRun();
		m_playerScores.SortDesc();
		isSwitchingMap = true;
		m_mapPersonalBests = {};
		RMC::GotGoalMedalOnCurrentMap = false;
		RMC::GotBelowMedalOnCurrentMap = false;
		if (nextMap is null && !isFetchingNextMap) RMTFetchNextMap();
		while (isFetchingNextMap) yield();
		@currentMap = nextMap;
		@nextMap = null;

		// Check for map existence on NadeoServers
		// // // is this rly needed?
		if(!CheckMapValidity()){
			 RMTSwitchMap();
			 return;
		}
		// Change map and Wait for confirmation it has changed
		SetServerMap();
		while (!TM::IsMapCorrect(currentMap.TrackUID)) sleep(500);
		
		// Restore the proper remaining time
		SetServerTime();
		RMC::UnpauseRun();

		while (GetApp().CurrentPlayground is null) yield();
		CGamePlayground@ GamePlayground = cast<CGamePlayground>(GetApp().CurrentPlayground);
		while (GamePlayground.GameTerminals.Length < 0) yield();
		while (GamePlayground.GameTerminals[0] is null) yield();
		while (GamePlayground.GameTerminals[0].ControlledPlayer is null) yield();
		CSmPlayer@ player = cast<CSmPlayer>(GamePlayground.GameTerminals[0].ControlledPlayer);
		while (player.ScriptAPI is null) yield();
		m_playerScores.SortDesc();
#if DEPENDENCY_BETTERCHAT
		BetterChatSendLeaderboard();
#endif
		CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
		while (playerScriptAPI.Post == 0) yield();
		RMC::SpawnedMapTimestamp = Time::Now;
		
		isSwitchingMap = false;
		RMC::ClickedOnSkip = false;
		startnew(CoroutineFunc(RMTFetchNextMap));
	}

	bool CheckMapValidity() {
		if (!MXNadeoServicesGlobal::CheckIfMapExistsAsync(currentMap.TrackUID)) {
			Log::Trace(GetModeNameShort() + ": Map is not on NadeoServices, retrying...");
			return false;
		}
		return true;
	}

	void SetServerMap(){
		Log::Trace(GetModeNameShort() + ": Random map: " + currentMap.Name + " (" + currentMap.TrackID + ")");
		UI::ShowNotification(Icons::InfoCircle + " " + GetModeNameShort() + " - Information on map switching", "Nadeo prevent sometimes when switching map too often and will not change map.\nIf after 10 seconds the podium screen is not shown, you can start a vote to change to next map in the game pause menu.", Text::ParseHexColor("#991703"));
		DataManager::SaveMapToRecentlyPlayed(currentMap);
		MXNadeoServicesGlobal::ClubRoomSetMapAndSwitchAsync(RMTRoom, currentMap.TrackUID);
	}

	void SetServerTime() {
		// set the server time to have a little bit more time to make sure the plugin catches up
		uint ServerRemainingTime = (RunRemainingTime() / 1000) + 5;
		MXNadeoServicesGlobal::ClubRoomSetCountdownTimer(RMTRoom, ServerRemainingTime);
	}

	void ResetToLobbyMap() {
		if (LobbyMapUID != "") {
			UI::ShowNotification("Returning to lobby map", "Please wait...", Text::ParseHexColor("#993f03"));
#if DEPENDENCY_BETTERCHAT
			sleep(200);
			BetterChat::SendChatMessage(Icons::Users + " Returning to lobby map...");
#endif
			MXNadeoServicesGlobal::SetMapToClubRoomAsync(RMTRoom, LobbyMapUID);
			if (pressedStopButton) MXNadeoServicesGlobal::ClubRoomSwitchMapAsync(RMTRoom);
			while (!TM::IsMapCorrect(LobbyMapUID)) sleep(500);
			pressedStopButton = false;
		}
		MXNadeoServicesGlobal::ClubRoomSetCountdownTimer(RMTRoom, 0);
	}

	void TimerYield() override {
		while (RMC::IsRunning){
			yield();
			if (!RMC::IsPaused) {
				CGameCtnChallenge@ currentMapChallenge = cast<CGameCtnChallenge>(GetApp().RootMap);
				if (currentMapChallenge !is null) {
					CGameCtnChallengeInfo@ currentMapInfo = currentMapChallenge.MapInfo;
					if (currentMapInfo !is null) {
						RMC::TimePlayed = Time::Now - RMC::RunStartTimestamp - RMC::TimePaused;
						RMC::TimeSpentMap = Time::Now - RMC::SpawnedMapTimestamp;

						if (!pressedStopButton && (RMC::RunStartTimestamp > RMC::RunEndTimestamp() || !RMC::IsRunning)) {
							RMC::IsRunning = false;
							GameEndNotification();
							@nextMap = null;
							@MX::preloadedMap = null;
							m_playerScores.SortDesc();
#if DEPENDENCY_BETTERCHAT
							BetterChat::SendChatMessage(Icons::Users + " Random Map Together ended, thanks for playing!");
							sleep(200);
							BetterChatSendLeaderboard();
#endif
							ResetToLobbyMap();
						}
					}
				}

				if (isObjectiveCompleted() && !RMC::GotGoalMedalOnCurrentMap) {
					Log::Log(playerGotGoalActualMap.name + " got goal medal with a time of " + playerGotGoalActualMap.time);
					UI::ShowNotification(Icons::Trophy + " " + playerGotGoalActualMap.name + " got "+tostring(PluginSettings::RMC_GoalMedal)+" medal with a time of " + playerGotGoalActualMap.timeStr, "Switching map...", Text::ParseHexColor("#01660f"));
					RMC::GoalMedalCount += 1;
					RMC::GotGoalMedalOnCurrentMap = true;
					RMTPlayerScore@ playerScored = findOrCreatePlayerScore(playerGotGoalActualMap);
					playerScored.AddGoal();
					m_playerScores.SortDesc();

#if DEPENDENCY_BETTERCHAT
					BetterChat::SendChatMessage(Icons::Trophy + " " + playerGotGoalActualMap.name + " got "+tostring(PluginSettings::RMC_GoalMedal)+" medal with a time of " + playerGotGoalActualMap.timeStr);
					sleep(200);
					BetterChat::SendChatMessage(Icons::Users + " Switching map...");
#endif

					RMTSwitchMap();
				}
				if (isBelowObjectiveCompleted() && !RMC::GotBelowMedalOnCurrentMap && PluginSettings::RMC_GoalMedal != RMC::Medals[0]) {
					Log::Log(playerGotBelowGoalActualMap.name + " got below goal medal with a time of " + playerGotBelowGoalActualMap.time);
					UI::ShowNotification(Icons::Trophy + " " + playerGotBelowGoalActualMap.name + " got "+RMC::Medals[RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1]+" medal with a time of " + playerGotBelowGoalActualMap.timeStr, "You can skip and take " + RMC::Medals[RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1] + " medal", Text::ParseHexColor("#4d3e0a"));
					RMC::GotBelowMedalOnCurrentMap = true;
#if DEPENDENCY_BETTERCHAT
					BetterChat::SendChatMessage(Icons::Trophy + " " + playerGotBelowGoalActualMap.name + " got "+RMC::Medals[RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1]+" medal with a time of " + playerGotBelowGoalActualMap.timeStr);
					sleep(200);
					BetterChat::SendChatMessage(Icons::Users + " You can skip and take " + RMC::Medals[RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1] + " medal");
#endif
				}
			}
		}
	}

	void RenderMVPPlayer() {
		if (m_playerScores.Length > 0) {
			RMTPlayerScore@ p = m_playerScores[0];
			UI::Text("MVP: " + p.name + " (" + p.goals + " medals)");
		}
	}

	void BetterChatSendLeaderboard() {
#if DEPENDENCY_BETTERCHAT
		sleep(200);
		if (m_playerScores.Length > 0) {
			string currentStatsChat = Icons::Users + " " + GetModeNameShort() + " Leaderboard: " + tostring(RMC::GoalMedalCount) + " " + tostring(PluginSettings::RMC_GoalMedal) + " medals" + (PluginSettings::RMC_GoalMedal != RMC::Medals[0] ? " - " + BelowMedalCount + " " + RMC::Medals[RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1] + " medals" : "") + "\n\n";
			for (uint i = 0; i < m_playerScores.Length; i++) {
				RMTPlayerScore@ p = m_playerScores[i];
				currentStatsChat += tostring(i+1) + ". " + p.name + ": " + p.goals + " " + tostring(PluginSettings::RMC_GoalMedal) + (PluginSettings::RMC_GoalMedal != RMC::Medals[0] ? " - " + p.belowGoals + " " + RMC::Medals[RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1] : "") + "\n";
			}
			BetterChat::SendChatMessage(currentStatsChat);
		}
#endif
	}

	void RenderCurrentMap() override
	{
		CGameCtnChallenge@ currentMapChallenge = cast<CGameCtnChallenge>(GetApp().RootMap);
		if (!isSwitchingMap && currentMapChallenge !is null) {
			CGameCtnChallengeInfo@ currentMapInfo = currentMapChallenge.MapInfo;
			if (currentMapInfo !is null) {
				UI::Separator();
				if (currentMap !is null) {
					UI::Text(currentMap.Name);
					if (PluginSettings::RMC_ShowAwards) {
						UI::SameLine();
						UI::Text("\\$db4" + Icons::Trophy + "\\$z " + currentMap.AwardCount);
					}
					if(PluginSettings::RMC_DisplayMapDate) {
						UI::TextDisabled(IsoDateToDMY(currentMap.UpdatedAt));
						UI::SameLine();
					}
					UI::TextDisabled("by " + currentMap.Username);
					if (PluginSettings::RMC_PrepatchTagsWarns && RMC::config.isMapHasPrepatchMapTags(currentMap)) {
						RMCConfigMapTag@ prepatchTag = RMC::config.getMapPrepatchMapTag(currentMap);
						UI::Text("\\$f80" + Icons::ExclamationTriangle + "\\$z"+prepatchTag.title);
						UI::SetPreviousTooltip(prepatchTag.reason + (IS_DEV_MODE ? ("\nExeBuild: " + currentMap.ExeBuild) : ""));
					}
					if (PluginSettings::RMC_TagsLength != 0) {
						if (currentMap.Tags.Length == 0) UI::TextDisabled("No tags");
						else {
							uint tagsLength = currentMap.Tags.Length;
							if (currentMap.Tags.Length > PluginSettings::RMC_TagsLength) tagsLength = PluginSettings::RMC_TagsLength;
							for (uint i = 0; i < tagsLength; i++) {
								Render::MapTag(currentMap.Tags[i]);
								UI::SameLine();
							}
							UI::NewLine();
						}
					}
				} else {
					UI::Separator();
					UI::TextDisabled("Map info unavailable");
				}
			}
		} else {
			UI::Separator();
			UI::AlignTextToFramePadding();
			UI::Text(Icons::InfoCircle + "Switching map... (hover for info)");
			UI::SetPreviousTooltip("Nadeo prevent sometimes when switching map too often and will not change map.\nIf after 10 seconds the podium screen is not shown, you can start a vote to change to next map in the game pause menu.");
		}
	}

	void RenderPlayingButtons() override
	{
		CGameCtnChallenge@ currentMap = cast<CGameCtnChallenge>(GetApp().RootMap);
		if (currentMap !is null) {
			SkipButtons();
		}
	}

	void SkipButtons() override {		
		string BelowMedal = PluginSettings::RMC_GoalMedal;
		uint medalIdx = RMC::Medals.Find(PluginSettings::RMC_GoalMedal);
		int belowMedalIdx = medalIdx - 1;

		if (belowMedalIdx >= 0) BelowMedal = RMC::Medals[belowMedalIdx];

		UI::BeginDisabled(RMC::ClickedOnSkip || isSwitchingMap);
		if (PluginSettings::RMC_FreeSkipAmount > FreeSkipsUsed){
			int skipsLeft = PluginSettings::RMC_FreeSkipAmount - FreeSkipsUsed;
			if(UI::Button(Icons::PlayCircleO + (RMC::GotBelowMedalOnCurrentMap ? " Take " + BelowMedal + " medal" : "Skip (-1 minute max)"))) {
				RMC::PauseRun();
				RMC::ClickedOnSkip = true;
				if (RMC::GotBelowMedalOnCurrentMap) {
					BelowMedalCount += 1;
					RMTPlayerScore@ playerScored = findOrCreatePlayerScore(playerGotBelowGoalActualMap);
					playerScored.AddBelowGoal();
				} else {
					Skips += 1;
				}
				Log::Trace("RMC: Skipping map");
				UI::ShowNotification("Please wait...");
				startnew(CoroutineFunc(RMTSwitchMap));
			}
		} else if (RMC::GotBelowMedalOnCurrentMap) {
			if (UI::Button(Icons::PlayCircleO + " Take " + BelowMedal + " medal")) {
				RMC::PauseRun();
				RMC::ClickedOnSkip = true;
				Log::Trace("RMC: Skipping map");
				UI::ShowNotification("Please wait...");
				startnew(CoroutineFunc(RMTSwitchMap));
			}
		} else {
			UI::NewLine();
		}
		if (!RMC::GotBelowMedalOnCurrentMap) UI::SetPreviousTooltip(
			"Free Skips are if the map is finishable but you still want to skip it for any reason.\n"+
			"Standard RMC rules allow 1 Free skip. If the map is broken please use the button below."
		);

		RenderBrokenButton();

		UI::EndDisabled();
	}
	void RenderBrokenButton(){
		if (UI::OrangeButton(Icons::PlayCircleO + "Skip broken Map")) {
			RMC::PauseRun();
      	RMC::TimePaused += RMC::TimeSpentMap;
			Log::Trace(GetModeNameShort() + ": Skipping broken map");
			UI::ShowNotification("Please wait...");
#if DEPENDENCY_BETTERCHAT
			BetterChat::SendChatMessage(Icons::Users + " Skipping broken map...");
#endif
			startnew(CoroutineFunc(RMTSwitchMap));
		}
	}

	void RenderScores()	{
		string BelowMedal = PluginSettings::RMC_GoalMedal;
		uint medalIdx = RMC::Medals.Find(PluginSettings::RMC_GoalMedal);
		int belowMedalIdx = medalIdx - 1;

		if (belowMedalIdx >= 0) BelowMedal = RMC::Medals[belowMedalIdx];

		int tableCols = 3;
		if (PluginSettings::RMC_GoalMedal == RMC::Medals[0] && RMC::selectedGameMode != RMC::GameMode::TogetherSurvival) tableCols = 2;
		if (UI::CollapsingHeader("Current Scores")) {
			if (UI::BeginTable("RMTScores", tableCols)) {
				UI::TableSetupScrollFreeze(0, 1);
				UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
				UI::TableSetupColumn(PluginSettings::RMC_GoalMedal, UI::TableColumnFlags::WidthFixed, 40);
				if (tableCols == 3) UI::TableSetupColumn(BelowMedal, UI::TableColumnFlags::WidthFixed, 40);
				UI::TableHeadersRow();
	
				UI::ListClipper clipper(m_playerScores.Length);
				while(clipper.Step()) {
					for(int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
					{
						UI::TableNextRow();
						UI::PushID("RMTScore"+i);
						RMTPlayerScore@ s = m_playerScores[i];
						UI::TableSetColumnIndex(0);
						UI::Text(s.name);
						UI::TableSetColumnIndex(1);
						UI::Text(tostring(s.goals));
						if (PluginSettings::RMC_GoalMedal != RMC::Medals[0] && RMC::selectedGameMode != 	RMC::GameMode::TogetherSurvival) {
							UI::TableSetColumnIndex(2);
							UI::Text(tostring(s.belowGoals));
						}
						UI::PopID();
					}
				}
				UI::EndTable();
			}
		}
	}

	bool isObjectiveCompleted()	{
		if (GetApp().RootMap !is null) {
			uint objectiveTime = uint(-1);
			if (PluginSettings::RMC_GoalMedal == RMC::Medals[3]) objectiveTime = GetApp().RootMap.MapInfo.TMObjective_AuthorTime;
			if (PluginSettings::RMC_GoalMedal == RMC::Medals[2]) objectiveTime = GetApp().RootMap.MapInfo.TMObjective_GoldTime;
			if (PluginSettings::RMC_GoalMedal == RMC::Medals[1]) objectiveTime = GetApp().RootMap.MapInfo.TMObjective_SilverTime;
			if (PluginSettings::RMC_GoalMedal == RMC::Medals[0]) objectiveTime = GetApp().RootMap.MapInfo.TMObjective_BronzeTime;


			if (m_mapPersonalBests.Length > 0) {
				for (uint r = 0; r < m_mapPersonalBests.Length; r++) {
					if (m_mapPersonalBests[r].time <= 0) continue;
					if (m_mapPersonalBests[r].time <= objectiveTime) {
						@playerGotGoalActualMap = m_mapPersonalBests[r];
						return true;
					}
				}
			}
		}
		return false;
	}

	bool isBelowObjectiveCompleted()	{
		if (GetApp().RootMap !is null) {
			uint objectiveTime = uint(-1);
			if (PluginSettings::RMC_GoalMedal == RMC::Medals[3]) objectiveTime = GetApp().RootMap.MapInfo.TMObjective_GoldTime;
			if (PluginSettings::RMC_GoalMedal == RMC::Medals[2]) objectiveTime = GetApp().RootMap.MapInfo.TMObjective_SilverTime;
			if (PluginSettings::RMC_GoalMedal == RMC::Medals[1]) objectiveTime = GetApp().RootMap.MapInfo.TMObjective_BronzeTime;


			if (m_mapPersonalBests.Length > 0) {
				for (uint r = 0; r < m_mapPersonalBests.Length; r++) {
					if (m_mapPersonalBests[r].time <= 0) continue;
					if (m_mapPersonalBests[r].time <= objectiveTime) {
						@playerGotBelowGoalActualMap = m_mapPersonalBests[r];
						return true;
					}
				}
			}
		}
		return false;
	}

	void UpdateRecords() {
		lastPbUpdate = Time::Now;
		auto newPBs = GetPlayersPBsMLFeed();
		if (newPBs.Length > 0) // empty arrays are returned on e.g., http error
			m_mapPersonalBests = newPBs;
	}

	string GetLocalPlayerWSID() {
		try {
			return GetApp().Network.ClientManiaAppPlayground.LocalUser.WebServicesUserId;
		} catch {
			return "";
		}
	}

	void StartTimer() override	{
		// reset all values
		ResetValues();

		RMC::IsPaused = false;
		RMC::IsRunning = true;
		
		// Is this check needed?
		if (RMC::GotGoalMedalOnCurrentMap) GotGoalMedalNotification();
		startnew(CoroutineFunc(TimerYield));
	}

	void ResetValues() {
		Skips = 0;
		LoadedSurvivedTime = 0;
	}

	array<PBTime@> GetPlayersPBsMLFeed() {
		array<PBTime@> ret;
#if DEPENDENCY_MLFEEDRACEDATA
		try {
			auto mapg = cast<CTrackMania>(GetApp()).Network.ClientManiaAppPlayground;
			if (mapg is null) return {};
			auto scoreMgr = mapg.ScoreMgr;
			auto userMgr = mapg.UserMgr;
			if (scoreMgr is null || userMgr is null) return {};
			auto raceData = MLFeed::GetRaceData_V2();
			auto players = GetPlayersInServer();
			if (players.Length == 0) return {};
			auto playerWSIDs = MwFastBuffer<wstring>();
			dictionary wsidToPlayer;
			for (uint i = 0; i < players.Length; i++) {
				auto SMPlayer = players[i];
				auto player = raceData.GetPlayer_V2(SMPlayer.User.Name);
				if (player is null) continue;
				if (player.bestTime < 1) continue;
				if (player.BestRaceTimes is null || player.BestRaceTimes.Length != raceData.CPsToFinish) continue;
				auto pbTime = PBTime(SMPlayer, null, SMPlayer.User.WebServicesUserId == GetLocalPlayerWSID());
				pbTime.time = player.bestTime;
				pbTime.recordTs = Time::Stamp;
				pbTime.replayUrl = "";
				pbTime.UpdateCachedStrings();
				ret.InsertLast(pbTime);
			}
			ret.SortAsc();
		} catch {
			warn("Error while getting player PBs: " + getExceptionInfo());
		}
#endif
		return ret;
	}

	array<CSmPlayer@>@ GetPlayersInServer() {
		auto cp = cast<CTrackMania>(GetApp()).CurrentPlayground;
		if (cp is null) return {};
		array<CSmPlayer@> ret;
		for (uint i = 0; i < cp.Players.Length; i++) {
			auto player = cast<CSmPlayer>(cp.Players[i]);
			if (player !is null) ret.InsertLast(player);
		}
		return ret;
	}

	void UpdateRecordsLoop() {
		while (RMC::IsRunning) {
			sleep(500);
			if (!isSwitchingMap) UpdateRecords();
		}
	}

	RMTPlayerScore@ findOrCreatePlayerScore(PBTime@ _player) {
		for (uint i = 0; i < m_playerScores.Length; i++) {
			RMTPlayerScore@ playerScore = m_playerScores[i];
			if (playerScore.wsid == _player.wsid) return playerScore;
		}
		RMTPlayerScore@ newPlayerScore = RMTPlayerScore(_player);
		m_playerScores.InsertLast(newPlayerScore);
		return newPlayerScore;
	}

	void DrawPlayerProgress() {
		if (UI::CollapsingHeader("Current Runs")) {
#if DEPENDENCY_MLFEEDRACEDATA
			UI::Indent();

			auto rd = MLFeed::GetRaceData_V4();
			UI::ListClipper clip(rd.SortedPlayers_TimeAttack.Length);
			if (UI::BeginTable("player-curr-runs", 4, UI::TableFlags::SizingStretchProp | UI::TableFlags::ScrollY)) {
				UI::TableSetupColumn("name", UI::TableColumnFlags::WidthStretch);
				UI::TableSetupColumn("cp", UI::TableColumnFlags::WidthStretch);
				UI::TableSetupColumn("time", UI::TableColumnFlags::WidthStretch);
				UI::TableSetupColumn("delta", UI::TableColumnFlags::WidthStretch);
				// UI::TableHeadersRow();

				while (clip.Step()) {
					for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
						auto p = rd.SortedPlayers_TimeAttack[i];
						UI::PushID(i);

						UI::TableNextRow();

						UI::TableNextColumn();
						UI::Text(p.Name);
						UI::TableNextColumn();
						UI::Text(tostring(p.CpCount));
						UI::TableNextColumn();
						UI::Text(Time::Format(p.LastCpOrRespawnTime));
						UI::TableNextColumn();
						auto best = p.BestRaceTimes;
						if (best !is null && p.CpCount <= int(best.Length)) {
							bool isBehind = false;
							// best player times start with index 0 being CP 1 time
							auto cpBest = p.CpCount == 0 ? 0 : int(best[p.CpCount - 1]);
							auto lastCpTimeVirtual = p.LastCpOrRespawnTime;
							// account for current race time via next cp
							if (p.CpCount < int(best.Length) && p.CurrentRaceTime > best[p.CpCount]) {
								// delta = last CP time - best CP time (for that CP)
								// we are ahead when last < best
								// so if we're behind, last > best, and the minimum difference to our pb is given by (last = current race time, and best = next CP time)
								isBehind = true;
								lastCpTimeVirtual = p.CurrentRaceTime;
								cpBest = best[p.CpCount];
							}
							string time = (p.IsFinished ?  (lastCpTimeVirtual <= cpBest ? "\\$5f5" : "\\$f53") : (lastCpTimeVirtual <= cpBest && !isBehind) ? "\\$48f-" : "\\$f84+")
								+ Time::Format(p.IsFinished ? p.LastCpTime : Math::Abs(lastCpTimeVirtual - cpBest))
								+ (isBehind ? " (*)" : "");
							UI::Text(time);
						} else {
							UI::Text("\\$888-:--.---");
						}
						UI::PopID();
					}
				}
				UI::EndTable();
			}
			UI::Unindent();
#else
			// shouldn't show up, but w/e
			UI::Text("MLFeed required.");
#endif
		}
	}
}
