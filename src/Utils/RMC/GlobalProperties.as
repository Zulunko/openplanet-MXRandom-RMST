namespace RMC
{
	bool ShowTimer = false;
	bool IsStarting = false;
	bool IsRunning = false;
	bool IsPaused = false;
	bool ClickedOnSkip = false;
	bool GotGoalMedalOnCurrentMap = false;
	bool GotBelowMedalOnCurrentMap = false;
	int GoalMedalCount = 0;

	int LoadedRemainingTime = 0;

	int RunStartTimestamp = 0;
	int SpawnedMapTimestamp = 0;

	int TimeSpentMap = 0;
	int TimePaused = 0;
	int TimePlayed = 0;

	int PauseBeginningTimestamp = 0;

	Json::Value CurrentMapJsonData = Json::Object();
	Json::Value CurrentRunData = Json::Object();

	bool ContinueSavedRun = false;
	bool IsInited = false;
	bool HasCompletedCheckbox = false;
	int StartTimeCopyForSaveData = 0;
	int EndTimeCopyForSaveData = 0;
	RMCConfig@ config;
	int CurrentTimeOnMap = 0; // for autosaves on PBs

	array<string> Medals = {
		"Bronze",
		"Silver",
		"Gold",
		"Author"
#if TMNEXT
		,"World Record"
#endif
	};

	const array<string> allowedMapLengths = {
		"15 secs",
		"30 secs",
		"45 secs",
		"1 min",
		"1 m 15 s",
		"1 m 30 s",
		"1 m 45 s",
		"2 min",
		"2 m 30 s",
		"3 min"
	};

	RMC@ Challenge;
	RMS@ Survival;
	RMObjective@ Objective;
	RMT@ Together;
	RMTS@ TogetherSurvival;

	enum GameMode {
		Challenge,
		Survival,
		ChallengeChaos,
		SurvivalChaos,
		Objective,
		Together,
		TogetherSurvival
	};
	GameMode selectedGameMode;



	void FetchConfig() {
		Log::Trace("Fetching RMC configs from openplanet.dev...");
		string url = "https://openplanet.dev/plugin/mxrandom/config/rmc-config";
		RMCConfigs@ cfgs = RMCConfigs(API::GetAsync(url));
#if TMNEXT
		@config = cfgs.cfgNext;
#else
		@config = cfgs.cfgMP4;
#endif
		Log::Trace("Fetched and loaded RMC configs!", IS_DEV_MODE);
	}

	void InitModes() {
		@Challenge = RMC();
		@Survival = RMS();
		@Objective = RMObjective();
		@Together = RMT();
		@TogetherSurvival = RMTS();
	}

	string FormatTimer(int time) {
		int hundreths = time % 1000 / 10;
		time /= 1000;
		int hours = time / 60 / 60;
		int minutes = (time / 60) % 60;
		int seconds = time % 60;

		string result = "";

		if (hours > 0) {
			result += Text::Format("%02d", hours) + ":";
		}
		if (minutes > 0 || (hours > 0 && minutes < 10)) {
			result += Text::Format("%02d", minutes) + ":";
		}
		result += Text::Format("%02d", seconds) + "." + Text::Format("%02d", hundreths);

		return result;
	}

	void Start() {
		IsInited = false;
		ShowTimer = true;
		IsStarting = true;
		ClickedOnSkip = false;
		ContinueSavedRun = false;
		HasCompletedCheckbox = false;


		
		if (RMC::selectedGameMode == GameMode::Challenge || RMC::selectedGameMode == GameMode::Survival) {
			bool b_hasRun = DataManager::LoadRunData();
			if (!b_hasRun) {
				DataManager::CreateSaveFile();
			} else {
				Renderables::Add(ContinueSavedRunModalDialog());
				while (!HasCompletedCheckbox) sleep(100);
			}
		}
		if (RMC::ContinueSavedRun) RMC::CurrentMapJsonData = CurrentRunData["MapData"];
		
		if (!(MX::preloadedMap is null)) @MX::preloadedMap = null;

		MX::LoadRandomMap();
		while (!TM::IsMapLoaded()) sleep(100);
		
		while (true){
			yield();
			CGamePlayground@ GamePlayground = cast<CGamePlayground>(GetApp().CurrentPlayground);
			if (GamePlayground !is null){
				if (!IsInited) {
					ResetValuesGlobal();
					if (ContinueSavedRun) LoadSavedStateGlobal();
					IsInited = true;
				}
#if MP4
				CTrackManiaPlayer@ player = cast<CTrackManiaPlayer>(GamePlayground.GameTerminals[0].GUIPlayer);
#elif TMNEXT
				CSmPlayer@ player = cast<CSmPlayer>(GamePlayground.GameTerminals[0].GUIPlayer);
#endif
				if (player !is null){
#if MP4
					while (player.RaceState != CTrackManiaPlayer::ERaceState::Running) yield();
#elif TMNEXT
					CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
					while (playerScriptAPI.Post == 0) yield();
#endif
					StartGameTimer();
					

					UI::ShowNotification("\\$080Random Map "+ tostring(RMC::selectedGameMode) + " started!", "Good Luck!");
					
					// Clear the currently saved data so you cannot load into the same state multiple times
					DataManager::RemoveCurrentSaveFile();
					DataManager::CreateSaveFile();
					IsStarting = false;
					SpawnedMapTimestamp = Time::Now;
					MX::PreloadRandomMap();
					break;
				}
			}
		}
	}


	// TODO: Fix this BS way of starting the timer
	void StartGameTimer() {
		if (RMC::selectedGameMode == GameMode::Challenge || RMC::selectedGameMode == GameMode::ChallengeChaos)
			Challenge.StartTimer();
		else if (RMC::selectedGameMode == GameMode::Survival || RMC::selectedGameMode == GameMode::SurvivalChaos)
			Survival.StartTimer();
		else if (RMC::selectedGameMode == GameMode::Objective)
			Objective.StartTimer();
	}

	void ResetValuesGlobal() {
		RunStartTimestamp = Time::Now;
		GoalMedalCount = 0;
		SpawnedMapTimestamp = 0;
	 	TimeSpentMap = 0;
	 	TimePaused = 0;
	 	TimePlayed = 0;
		LoadedRemainingTime = 0;
		GotGoalMedalOnCurrentMap = false;
	}

	void LoadSavedStateGlobal() {
		LoadedRemainingTime = CurrentRunData["TimerRemaining"];
		GoalMedalCount = CurrentRunData["PrimaryCounterValue"];
		GotGoalMedalOnCurrentMap = CurrentRunData["GotGoalMedalOnMap"];
		CurrentTimeOnMap = CurrentRunData["PBOnMap"];
	}

	void PauseRun() {
		PauseBeginningTimestamp = Time::Now;
		IsPaused = true;
	}

	void UnpauseRun() {
		// add the time spent in pause mode to the counter variable
		TimePaused += Time::Now - PauseBeginningTimestamp;
		IsPaused = false;
	}

	int GetCurrentMapMedal() {
		auto app = cast<CTrackMania>(GetApp());
		auto map = app.RootMap;
		CGamePlayground@ GamePlayground = cast<CGamePlayground>(app.CurrentPlayground);
		int medal = -1;
		if (map !is null && GamePlayground !is null){
			int worldRecordTime = TM::GetWorldRecordFromCache(map.MapInfo.MapUid);
			int authorTime = map.TMObjective_AuthorTime;
			int goldTime = map.TMObjective_GoldTime;
			int silverTime = map.TMObjective_SilverTime;
			int bronzeTime = map.TMObjective_BronzeTime;
			int playerTime = -1;
#if MP4
			CGameCtnPlayground@ GameCtnPlayground = cast<CGameCtnPlayground>(app.CurrentPlayground);
			if (GameCtnPlayground.PlayerRecordedGhost !is null)
				playerTime = GameCtnPlayground.PlayerRecordedGhost.RaceTime;
			
#elif TMNEXT
			CSmArenaRulesMode@ PlaygroundScript = cast<CSmArenaRulesMode>(app.PlaygroundScript);
			if (PlaygroundScript !is null && GamePlayground.GameTerminals.Length > 0) {
				CSmPlayer@ player = cast<CSmPlayer>(GamePlayground.GameTerminals[0].ControlledPlayer);
				if (GamePlayground.GameTerminals[0].UISequence_Current == SGamePlaygroundUIConfig::EUISequence::Finish && player !is null) {
					CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
					auto ghost = PlaygroundScript.Ghost_RetrieveFromPlayer(playerScriptAPI);
					if (ghost !is null) {
						if (ghost.Result.Time > 0 && ghost.Result.Time < 4294967295) 
							playerTime = ghost.Result.Time;
						PlaygroundScript.DataFileMgr.Ghost_Release(ghost.Id);
					}
				}
			}
#endif
			if (playerTime != -1){
				// run finished
				if(playerTime <= worldRecordTime) medal = 4;
				else if(playerTime <= authorTime) medal = 3;
				else if(playerTime <= goldTime) medal = 2;
				else if(playerTime <= silverTime) medal = 1;
				else if(playerTime <= bronzeTime) medal = 0;
				
				if (IS_DEV_MODE) {
					Log::Trace("Run finished with time " + FormatTimer(playerTime));
					Log::Trace("World Record time: " + FormatTimer(worldRecordTime));
					Log::Trace("Author time: " + FormatTimer(authorTime));
					Log::Trace("Gold time: " + FormatTimer(goldTime));
					Log::Trace("Silver time: " + FormatTimer(silverTime));
					Log::Trace("Bronze time: " + FormatTimer(bronzeTime));
					Log::Trace("Medal: " + medal);
				}

				// new PB
				if (CurrentTimeOnMap > playerTime) {
					CurrentTimeOnMap = playerTime;
					CreateSave();
				}
			}
		}
		return medal;
	}

	void CreateSave(bool b_endRun = false) {
		CurrentRunData["MapData"] = CurrentMapJsonData;
		CurrentRunData["TimeSpentOnMap"] = RMC::TimeSpentMap;
		CurrentRunData["PrimaryCounterValue"] = GoalMedalCount;
		CurrentRunData["SecondaryCounterValue"] = selectedGameMode == GameMode::Challenge ? Challenge.BelowMedalCount : Survival.Skips;
		CurrentRunData["GotGoalMedalOnMap"] = RMC::GotGoalMedalOnCurrentMap;
		CurrentRunData["PBOnMap"] = RMC::CurrentTimeOnMap;

		if (RMC::selectedGameMode == RMC::GameMode::Survival) {
			CurrentRunData["CurrentRunTime"] = RMC::Survival.SurvivedTime();
		} else {
			CurrentRunData["GotBelowMedalOnMap"] = RMC::GotBelowMedalOnCurrentMap;
			CurrentRunData["CurrentRunTime"] = RMC::RunStartTimestamp;
		}

		if (b_endRun) {
			CurrentRunData["TimerRemaining"] = RMC::EndTimeCopyForSaveData - RMC::StartTimeCopyForSaveData;
		} else {
			// don't use the copies here, they are only updated for game end.
			if (selectedGameMode == GameMode::Challenge) 
				CurrentRunData["TimerRemaining"] = Challenge.RunRemainingTime();
			else if (selectedGameMode == GameMode::Survival) 
				CurrentRunData["TimerRemaining"] = Survival.RunRemainingTime();
		}


		DataManager::SaveCurrentRunData();
	}

	void SwitchMap() {
		PauseRun();
		MX::LoadRandomMap();
		while (!TM::IsMapLoaded()){
			sleep(100);
		}
		

#if TMNEXT
		// Wait for player to spawn in map and start driving before resuming timer
		while (GetApp().CurrentPlayground is null) yield();
		CGamePlayground@ GamePlayground = cast<CGamePlayground>(GetApp().CurrentPlayground);
		while (GamePlayground.GameTerminals.Length < 0) yield();
		while (GamePlayground.GameTerminals[0] is null) yield();
		while (GamePlayground.GameTerminals[0].ControlledPlayer is null) yield();
		CSmPlayer@ player = cast<CSmPlayer>(GamePlayground.GameTerminals[0].ControlledPlayer);
		while (player.ScriptAPI is null) yield();
		CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
		while (playerScriptAPI.Post == 0) yield();
#endif

		GotGoalMedalOnCurrentMap = false;
		GotBelowMedalOnCurrentMap = false;
		SpawnedMapTimestamp = Time::Now;
		ClickedOnSkip = false;
		UnpauseRun();

		MX::PreloadRandomMap();
	}
}