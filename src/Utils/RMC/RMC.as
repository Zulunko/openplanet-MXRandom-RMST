class RMC {
	int FreeSkipsUsed = 0;
	int BelowMedalCount = 0;
	bool UserEndedRun = false;


	int LastUpdatedRemainingTime = 0;

	UI::Font@ TimerFont = UI::LoadFont("src/Assets/Fonts/digital-7.mono.ttf", 20);
	UI::Texture@ WRTex = UI::LoadTexture("src/Assets/Images/WRTrophy.png");
	UI::Texture@ AuthorTex = UI::LoadTexture("src/Assets/Images/Author.png");
	UI::Texture@ GoldTex = UI::LoadTexture("src/Assets/Images/Gold.png");
	UI::Texture@ SilverTex = UI::LoadTexture("src/Assets/Images/Silver.png");
	UI::Texture@ BronzeTex = UI::LoadTexture("src/Assets/Images/Bronze.png");

	array<UI::Texture@> medalsTex = {
		BronzeTex,
		SilverTex,
		GoldTex,
		AuthorTex,
		WRTex
	};

	RMC()	{ print(GetModeName() + " loaded"); }

	string GetModeName() { return "Random Map Challenge";}
	string GetModeNameShort() { return tostring(RMC::selectedGameMode); }
	

	int TimeLimit() { return PluginSettings::RMC_Duration * 60 * 1000; }

	int RunEndTimestamp() { 
		int InitialLimit = RMC::ContinueSavedRun ? RMC::LoadedRemainingTime : TimeLimit();
		return RMC::RunStartTimestamp + RMC::TimePaused + InitialLimit; 
	}

	int RunRemainingTime() { 
		if (!RMC::IsPaused) LastUpdatedRemainingTime = RunEndTimestamp() - Time::Now; 
		return LastUpdatedRemainingTime;
	}

	void RenderGameModeSpecificDebug() {}

	void Render() {
		if (RMC::IsRunning && (UI::IsOverlayShown() || PluginSettings::RMC_AlwaysShowBtns)) 
			RenderStopButton();
		

		RenderTimer();
		
		// DEBUG RENDERING 		
		if(IS_DEV_MODE) {
			UI::Separator();
			UI::Text("DEBUG TIMESTAMPS");
			UI::Text("Time::Now : " + Time::Now);

			if(RMC::RunStartTimestamp > 0) UI::Text("RunStartTimestamp: " + RMC::RunStartTimestamp);
			if(RunEndTimestamp() > 0) UI::Text("RunEndTimestamp: " + RunEndTimestamp());
			if(RMC::SpawnedMapTimestamp > 0) UI::Text("SpawnedMapTimestamp: " + RMC::SpawnedMapTimestamp);
			if(RMC::TimeSpentMap > 0) UI::Text("TimeSpentMap: " + RMC::TimeSpentMap);
			if(RMC::TimePaused > 0) UI::Text("TimePaused: " + RMC::TimePaused);
			if(RMC::TimePlayed > 0) UI::Text("TimePlayed: " + RMC::TimePlayed);
			if(RMC::PauseBeginningTimestamp > 0) UI::Text("PauseBeginningTimestamp: " + RMC::PauseBeginningTimestamp);
			if(RMC::LoadedRemainingTime > 0) UI::Text("LoadedRemainingTime: " + RMC::LoadedRemainingTime);
			
			// render debug info specified by the mode
			RenderGameModeSpecificDebug();
		}

		UI::Separator();
		vec2 pos_orig = UI::GetCursorPos();

		RenderGoalMedal();
		vec2 pos_orig_goal = UI::GetCursorPos();
		UI::SetCursorPos(vec2(pos_orig_goal.x+50, pos_orig_goal.y));
		RenderBelowGoalMedal();
		
		UI::SetCursorPos(vec2(pos_orig.x, pos_orig.y+60));

		if (PluginSettings::RMC_DisplayPace) {
			try {
				float goalPace = RMC::GoalMedalCount * TimeLimit() / RMC::TimePlayed;
				UI::Text("Pace: " + goalPace);
			} catch {
				UI::Text("Pace: 0");
			}
		}

		if (PluginSettings::RMC_DisplayCurrentMap)
		{
			RenderCurrentMap();
		}

		RenderCustomSearchWarning();

		if (RMC::IsRunning && (UI::IsOverlayShown() || (!UI::IsOverlayShown() && PluginSettings::RMC_AlwaysShowBtns))) {
			UI::Separator();
			RenderPlayingButtons();
		}
	}

	void RenderCustomSearchWarning() {
		if ((RMC::IsRunning || RMC::IsStarting) && PluginSettings::CustomRules) {
			UI::Separator();
			UI::Text("\\$fc0"+ Icons::ExclamationTriangle + " \\$zInvalid for official leaderboards ");
			UI::SetPreviousTooltip("This run has custom search parameters enabled, meaning that you only get maps after the settings you configured. \nTo change this, toggle the \"Use these parameters in RMC\" under the \"Searching\" settings");
		}
	}

	void RenderStopButton() {
		if (UI::RedButton(Icons::Times + " Stop " + GetModeNameShort())) {
			UserEndedRun = true;
			RMC::StartTimeCopyForSaveData = RMC::RunStartTimestamp;
			RMC::EndTimeCopyForSaveData = RunEndTimestamp();
			RMC::IsRunning = false;
			@MX::preloadedMap = null;

#if DEPENDENCY_CHAOSMODE
			ChaosMode::SetRMCMode(false);
#endif
			int secondaryCount = RMC::selectedGameMode == RMC::GameMode::Challenge ? BelowMedalCount : RMC::Survival.Skips;
			if (RMC::GoalMedalCount != 0 || secondaryCount != 0 || RMC::GotBelowMedalOnCurrentMap || RMC::GotGoalMedalOnCurrentMap) {
				if (!PluginSettings::RMC_RUN_AUTOSAVE) {
					RMC::PauseRun();
					Renderables::Add(SaveRunQuestionModalDialog());
					// sleeping here to wait for the dialog to be closed crashes the plugin, 
					// hence we just have a copy of the timers to use for the save file
				} else {
					RMC::CreateSave(true);
					vec4 color = UI::HSV(0.25, 1, 0.7);
					UI::ShowNotification(PLUGIN_NAME, "Saved the state of the current run", color, 5000);
				}
			} else {
				// no saves for instant resets
				DataManager::RemoveCurrentSaveFile();
			}
		}
		RMC::ContinueSavedRun = false;
		UI::Separator();
	}

	void RenderTimer() {
		// display current time remaining
		UI::PushFont(TimerFont);
		if (RMC::IsRunning) {
			if (RMC::IsPaused) UI::TextDisabled(RMC::FormatTimer(RunRemainingTime()));
			else UI::Text(RMC::FormatTimer(RunRemainingTime()));
		} else {
			UI::TextDisabled(RMC::FormatTimer(TimeLimit()));
		}
		UI::PopFont();

		// display time spent on map
		UI::Dummy(vec2(0, 8));
		if (PluginSettings::RMC_DisplayMapTimeSpent) {
			UI::PushFont(g_fontHeaderSub);
			UI::Text(Icons::Map + " " + RMC::FormatTimer(RMC::TimeSpentMap));
			UI::SetPreviousTooltip("Time spent on this map");
			UI::PopFont();
		}

		// Display current state of timer if in DevMode
		if (IS_DEV_MODE) {
			if (RMC::IsRunning) {
				if (RMC::IsPaused) UI::Text("Timer paused");
				else UI::Text("Timer running");
			} else UI::Text("Timer ended");
		}
	}

	void RenderGoalMedal() {
		UI::AlignTextToFramePadding();

		// Will work?
		uint medalIdx = RMC::Medals.Find(PluginSettings::RMC_GoalMedal);
		if (medalsTex[medalIdx] !is null) 
			UI::Image(medalsTex[medalIdx], vec2(PluginSettings::RMC_ImageSize*2,PluginSettings::RMC_ImageSize*2));
		else UI::Text(PluginSettings::RMC_GoalMedal);

		UI::SameLine();
		vec2 pos_orig = UI::GetCursorPos();
		UI::SetCursorPos(vec2(pos_orig.x, pos_orig.y+8));
		UI::PushFont(TimerFont);
		UI::Text(tostring(RMC::GoalMedalCount));
		UI::PopFont();
		UI::SetCursorPos(pos_orig);
	}

	void RenderBelowGoalMedal() {
		if (PluginSettings::RMC_GoalMedal != RMC::Medals[0]) {
			UI::AlignTextToFramePadding();

			uint medalIdx = RMC::Medals.Find(PluginSettings::RMC_GoalMedal) - 1;
			if (medalsTex[medalIdx] !is null) 
				UI::Image(medalsTex[medalIdx], vec2(PluginSettings::RMC_ImageSize*2,PluginSettings::RMC_ImageSize*2));
			else UI::Text(PluginSettings::RMC_GoalMedal);

			UI::SameLine();
			vec2 pos_orig = UI::GetCursorPos();
			UI::SetCursorPos(vec2(pos_orig.x, pos_orig.y+8));
			UI::PushFont(TimerFont);
			UI::Text(tostring(BelowMedalCount));
			UI::PopFont();
			UI::SetCursorPos(pos_orig);
		}
	}

	void RenderCurrentMap()	{
		CGameCtnChallenge@ currentMap = cast<CGameCtnChallenge>(GetApp().RootMap);
		if (currentMap !is null) {
			CGameCtnChallengeInfo@ currentMapInfo = currentMap.MapInfo;
			if (currentMapInfo !is null) {
				if (DataJson["recentlyPlayed"].Length > 0 && currentMapInfo.MapUid == DataJson["recentlyPlayed"][0]["TrackUID"]) {
					UI::Separator();
					MX::MapInfo@ CurrentMapFromJson = MX::MapInfo(DataJson["recentlyPlayed"][0]);
					if (CurrentMapFromJson !is null) {
						UI::Text(CurrentMapFromJson.Name);
						if (PluginSettings::RMC_ShowAwards) {
							UI::SameLine();
							UI::Text("\\$db4" + Icons::Trophy + "\\$z " + CurrentMapFromJson.AwardCount);
						}
						if(PluginSettings::RMC_DisplayMapDate) {
							UI::TextDisabled(IsoDateToDMY(CurrentMapFromJson.UpdatedAt));
							UI::SameLine();
						}
						UI::TextDisabled("by " + CurrentMapFromJson.Username);
#if TMNEXT
						if (PluginSettings::RMC_PrepatchTagsWarns && RMC::config.isMapHasPrepatchMapTags(CurrentMapFromJson)) {
							RMCConfigMapTag@ prepatchTag = RMC::config.getMapPrepatchMapTag(CurrentMapFromJson);
							UI::Text("\\$f80" + Icons::ExclamationTriangle + "\\$z"+prepatchTag.title);
							UI::SetPreviousTooltip(prepatchTag.reason + (IS_DEV_MODE ? ("\nExeBuild: " + CurrentMapFromJson.ExeBuild) : ""));
						}
#endif
						if (PluginSettings::RMC_TagsLength != 0) {
							if (CurrentMapFromJson.Tags.Length == 0) UI::TextDisabled("No tags");
							else {
								uint tagsLength = CurrentMapFromJson.Tags.Length;
								if (CurrentMapFromJson.Tags.Length > PluginSettings::RMC_TagsLength) tagsLength = PluginSettings::RMC_TagsLength;
								for (uint i = 0; i < tagsLength; i++) {
									Render::MapTag(CurrentMapFromJson.Tags[i]);
									UI::SameLine();
								}
								UI::NewLine();
							}
						}
					} else {
						UI::Separator();
						UI::TextDisabled("Map info unavailable");
					}
				} else {
					UI::Separator();
					UI::Text("\\$f30" + Icons::ExclamationTriangle + " \\$zActual map is not the same that we got.");
					UI::Text("Please change the map.");
					if (UI::Button("Change map")) startnew(RMC::SwitchMap);
				}
			}
		} else {
			UI::Separator();
			if (RMC::IsPaused) {
				UI::AlignTextToFramePadding();
				UI::Text("Switching map...");
				UI::SameLine();
				if (UI::Button("Force switch")) startnew(RMC::SwitchMap);
			}
			else RMC::IsPaused = true;
		}
	}

	void RenderPlayingButtons() {
		CGameCtnChallenge@ currentMap = cast<CGameCtnChallenge>(GetApp().RootMap);
		if (currentMap !is null) {
			CGameCtnChallengeInfo@ currentMapInfo = currentMap.MapInfo;
			if (DataJson["recentlyPlayed"].Length > 0 && currentMapInfo.MapUid == DataJson["recentlyPlayed"][0]["TrackUID"]) {
				PausePlayButton();
				UI::SameLine();
				SkipButtons();
				if (!PluginSettings::RMC_AutoSwitch && RMC::GotGoalMedalOnCurrentMap) {
					NextMapButton();
				}
			}
		}
	}

	void PausePlayButton() {
		int HourGlassValue = Time::Stamp % 3;
		string Hourglass = (HourGlassValue == 0 ? Icons::HourglassStart : (HourGlassValue == 1 ? Icons::HourglassHalf : Icons::HourglassEnd));
		if (UI::Button((RMC::IsPaused ? Icons::HourglassO + Icons::Play : Hourglass + Icons::Pause))) {
			if (RMC::IsPaused) RMC::UnpauseRun();
			else RMC::PauseRun();
		}
	}


	void SkipButtons() {
		string BelowMedal = PluginSettings::RMC_GoalMedal;
		uint medalIdx = RMC::Medals.Find(PluginSettings::RMC_GoalMedal);
		int belowMedalIdx = medalIdx - 1;

		if (belowMedalIdx >= 0) BelowMedal = RMC::Medals[belowMedalIdx];

		UI::BeginDisabled(TM::IsPauseMenuDisplayed() || RMC::ClickedOnSkip);
		if (PluginSettings::RMC_FreeSkipAmount > FreeSkipsUsed){
			int skipsLeft = PluginSettings::RMC_FreeSkipAmount - FreeSkipsUsed;
			if(UI::Button(Icons::PlayCircleO + (RMC::GotBelowMedalOnCurrentMap ? " Take " + BelowMedal + " medal" : "Free Skip (" + skipsLeft + " left)"))) {
				RMC::PauseRun();
				RMC::ClickedOnSkip = true;
				if (RMC::GotBelowMedalOnCurrentMap) {
					BelowMedalCount += 1;
				} else {
					FreeSkipsUsed += 1;
					RMC::CurrentRunData["FreeSkipsUsed"] = FreeSkipsUsed;
					DataManager::SaveCurrentRunData();
				}
				Log::Trace("RMC: Skipping map");
				UI::ShowNotification("Please wait...");
				startnew(RMC::SwitchMap);
			}
		} else if (RMC::GotBelowMedalOnCurrentMap) {
			if (UI::Button(Icons::PlayCircleO + " Take " + BelowMedal + " medal")) {
				RMC::PauseRun();
				RMC::ClickedOnSkip = true;
				BelowMedalCount += 1;
				Log::Trace("RMC: Skipping map");
				UI::ShowNotification("Please wait...");
				startnew(RMC::SwitchMap);
			}
		} else UI::NewLine();
		
		if (!RMC::GotBelowMedalOnCurrentMap) UI::SetPreviousTooltip(
			"Free Skips are if the map is finishable but you still want to skip it for any reason.\n"+
			"Standard RMC rules allow 1 Free skip. If the map is broken please use the button below."
		);

		if (UI::OrangeButton(Icons::PlayCircleO + "Skip broken Map")) {
			RMC::PauseRun();
			if (!UI::IsOverlayShown()) UI::ShowOverlay();
			Renderables::Add(BrokenMapSkipWarnModalDialog());
		}

		if (TM::IsPauseMenuDisplayed()) UI::SetPreviousTooltip("To skip the map, please exit the pause menu.");
		UI::EndDisabled();
	}

	void NextMapButton()	{
		UI::BeginDisabled(TM::IsPauseMenuDisplayed() || RMC::ClickedOnSkip);
		if(UI::GreenButton(Icons::Play + " Next map")) {
			RMC::ClickedOnSkip = true;
			Log::Trace(GetModeNameShort() + ": Next map");
			UI::ShowNotification("Please wait...");
			startnew(RMC::SwitchMap);
		}
		if (TM::IsPauseMenuDisplayed()) UI::SetPreviousTooltip("To skip the map, please exit the pause menu.");
		UI::EndDisabled();
	}

	void StartTimer() {
		// reset all values
		ResetValues();
		// restore time from savefile
		if (RMC::ContinueSavedRun) LoadSavedState();

		RMC::IsRunning = true;
		RMC::IsPaused = false;
		
		if (RMC::GotBelowMedalOnCurrentMap && RMC::GotGoalMedalOnCurrentMap) RMC::GotBelowMedalOnCurrentMap = false;
		if (RMC::GotBelowMedalOnCurrentMap) GotBelowGoalMedalNotification();
		if (RMC::GotGoalMedalOnCurrentMap) GotGoalMedalNotification();
		startnew(CoroutineFunc(TimerYield));
	}

	void ResetValues() {
		BelowMedalCount = 0;
		FreeSkipsUsed = 0;
		UserEndedRun = false;
	}

	void LoadSavedState () {
		BelowMedalCount = RMC::CurrentRunData["SecondaryCounterValue"];
		FreeSkipsUsed = RMC::CurrentRunData["FreeSkipsUsed"];
	}

	void GameEndNotification()	{
		UI::ShowNotification(
			"\\$0f0" + GetModeName() + " ended!", "You got "+ RMC::GoalMedalCount + " " + tostring(PluginSettings::RMC_GoalMedal) 
			+ PluginSettings::RMC_GoalMedal != RMC::Medals[0]
				? " and " + BelowMedalCount + " " + RMC::Medals[RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1]
				: "" 
			+ " medals!");
#if DEPENDENCY_CHAOSMODE
		if (RMC::selectedGameMode == RMC::GameMode::ChallengeChaos) ChaosMode::SetRMCMode(false);
#endif
	}

	void GotGoalMedalNotification() {
		Log::Trace(GetModeNameShort() + ": Got "+ tostring(PluginSettings::RMC_GoalMedal) + " medal!");
		if (PluginSettings::RMC_AutoSwitch) {
			UI::ShowNotification("\\$071" + Icons::Trophy + " You got "+tostring(PluginSettings::RMC_GoalMedal)+" time!", "We're searching for another map...");
			startnew(RMC::SwitchMap);
		} else UI::ShowNotification("\\$071" + Icons::Trophy + " You got "+tostring(PluginSettings::RMC_GoalMedal)+" time!", "Click 'Next map' to change the map");
	}

	void GotBelowGoalMedalNotification() {
		string Medal = tostring(RMC::Medals[RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1]);
		Log::Trace(GetModeNameShort() + ": Got "+ Medal + " medal!");
		if (!RMC::GotBelowMedalOnCurrentMap)
			UI::ShowNotification(
				"\\$db4" + Icons::Trophy + " You got " + Medal + " medal",
				"You can take the medal and skip the map"
			);
	}

	void TimerYield() {
		bool wasPaused = false;
		while (RMC::IsRunning){
			yield();
#if DEPENDENCY_CHAOSMODE
			ChaosMode::SetRMCPaused(RMC::IsPaused);
#endif
			
			// IF Timer is NOT paused, continue checking medals and current map
			if (!RMC::IsPaused) { 
				CGameCtnChallenge@ currentMap = cast<CGameCtnChallenge>(GetApp().RootMap);
				if (currentMap !is null) {
					CGameCtnChallengeInfo@ currentMapInfo = currentMap.MapInfo;
					if (currentMapInfo !is null) {
						// Check if the current map is the corect one, pause otherwise
						if (DataJson["recentlyPlayed"].Length == 0 || currentMapInfo.MapUid != DataJson["recentlyPlayed"][0]["TrackUID"]) 
							RMC::PauseRun();
						else {
							RMC::TimePlayed = Time::Now - RMC::RunStartTimestamp - RMC::TimePaused;
							RMC::TimeSpentMap = Time::Now - RMC::SpawnedMapTimestamp;

							// Check if the run should end
							if (Time::Now > RunEndTimestamp() || !RMC::IsRunning || RunRemainingTime() < 1) {
								RMC::IsRunning = false;
								RMC::ContinueSavedRun = false;
								GameEndNotification();
								
								// run ended on time -> no point in saving it as it can't be continued
								if (!UserEndedRun) DataManager::RemoveCurrentSaveFile();	
								
								if (PluginSettings::RMC_ExitMapOnEndTime){
									CTrackMania@ app = cast<CTrackMania>(GetApp());
									app.BackToMainMenu();
								}
								@MX::preloadedMap = null;
							}
						}
					}
				}
				CheckReachedMedals();
			} 
		}
	}
	void CheckReachedMedals(){
		bool GoalMedalReached = RMC::GetCurrentMapMedal() >= RMC::Medals.Find(PluginSettings::RMC_GoalMedal);
		bool BelowGoalMedalReached = RMC::GetCurrentMapMedal() >= RMC::Medals.Find(PluginSettings::RMC_GoalMedal)-1;
		if (GoalMedalReached && !RMC::GotGoalMedalOnCurrentMap){
			GotGoalMedalNotification();
			RMC::GoalMedalCount += 1;
			RMC::GotGoalMedalOnCurrentMap = true;
			RMC::CreateSave();
		}
		if (BelowGoalMedalReached && !RMC::GotGoalMedalOnCurrentMap && PluginSettings::RMC_GoalMedal != RMC::Medals[0]) {
			GotBelowGoalMedalNotification();
			RMC::GotBelowMedalOnCurrentMap = true;
			RMC::CreateSave();
		}
	}

	string IsoDateToDMY(const string &in isoDate) {
		string year = isoDate.SubStr(0, 4);
		string month = isoDate.SubStr(5, 2);
		string day = isoDate.SubStr(8, 2);
		return day + "-" + month + "-" + year;
	}
}