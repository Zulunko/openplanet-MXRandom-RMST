class RMTS : RMT
{
// #if TMNEXT
// 	int Skips = 0;
// 	int GoalTimerIncreaseMinutes = 3;
	
// 	UI::Texture@ SkipTex = UI::LoadTexture("src/Assets/Images/YEPSkip.png");

// 	string GetModeName() override { return "Random Map Together Survival";}

// 	int TimeLimit() override { return PluginSettings::RMC_SurvivalMaxTime * 60 * 1000; }

// 	int RunEndTimestamp() override { 
// 		int InitialLimit = RMC::ContinueSavedRun ? RMC::LoadedRemainingTime : TimeLimit();
// 		int BonusTime = 60 * 1000 * GoalTimerIncreaseMinutes * RMC::GoalMedalCount;
// 		int MaxTime = (PluginSettings::RMC_SurvivalMaxTime - Skips) * 60 * 1000;
// 		int finalTime = RMC::RunStartTimestamp + InitialLimit + RMC::TimePaused + BonusTime;
		
// 		if (finalTime > MaxTime) return Time::Now + MaxTime;
// 		else return finalTime;
// 	}

// 	int SurvivedTime() {
// 		return (RMC::RunStartTimestamp - RunEndTimestamp() - RMC::TimePaused + LoadedSurvivedTime);
// 	}

// 	void RenderTimer() override {
// 		UI::PushFont(TimerFont);
// 		if (RMC::IsRunning) {
// 			// display time remaining in run
// 			if (RMC::IsPaused) UI::TextDisabled(RMC::FormatTimer(RunRemainingTime()));
// 			else UI::Text(RMC::FormatTimer(RunRemainingTime()));

// 			// display overall time spent playing on maps
// 			if (SurvivedTime() > 0 && PluginSettings::RMC_SurvivalShowSurvivedTime) {
// 				UI::PopFont();
// 				UI::Dummy(vec2(0, 8));
// 				UI::PushFont(g_fontHeaderSub);
// 				UI::Text(RMC::FormatTimer(SurvivedTime()));
// 				UI::SetPreviousTooltip("Total time survived");
// 			} else {
// 				UI::Dummy(vec2(0, 8));
// 			}

// 			// display time spent playing on current map
// 			if (PluginSettings::RMC_DisplayMapTimeSpent) {
// 				if(SurvivedTime() > 0 && PluginSettings::RMC_SurvivalShowSurvivedTime) {
// 					UI::SameLine();
// 				}
// 				UI::PushFont(g_fontHeaderSub);
// 				UI::Text(Icons::Map + " " + RMC::FormatTimer(RMC::TimeSpentMap));
// 				UI::SetPreviousTooltip("Time spent on this map");
// 				UI::PopFont();
// 			}
// 		} else {
// 			UI::TextDisabled(RMC::FormatTimer(TimeLimit()));
// 			UI::Dummy(vec2(0, 8));
// 		}
		
// 		if(IS_DEV_MODE) {
// 			UI::Separator();
// 			UI::Text("LoadedSurvivedTime: " + LoadedSurvivedTime);
// 			UI::Text("LoadedRemainingTime: " + RMC::LoadedRemainingTime);
// 		}

// 		UI::PopFont();
// 	}

// 	void TimerYield() override
// 	{
// 		while (RMC::IsRunning){
// 			yield();
// 			if (!RMC::IsPaused) {
// 				CGameCtnChallenge@ currentMapChallenge = cast<CGameCtnChallenge>(GetApp().RootMap);
// 				if (currentMapChallenge !is null) {
// 					CGameCtnChallengeInfo@ currentMapInfo = currentMapChallenge.MapInfo;
// 					if (currentMapInfo !is null) {
// 						RMC::TimeSpentMap = Time::Now - RMC::SpawnedMapTimestamp;

// 						if (!pressedStopButton && (Time::Now > RMC::RunEndTimestamp() || !RMC::IsRunning)) {
// 							RMC::IsRunning = false;
// 							GameEndNotification();
// 							@nextMap = null;
// 							@MX::preloadedMap = null;
// 							m_playerScores.SortDesc();
// #if DEPENDENCY_BETTERCHAT
// 							BetterChatSendLeaderboard();
// 							sleep(200);
// 							BetterChat::SendChatMessage(Icons::Users + " Random Map Together Survival ended, thanks for playing!");
// #endif
// 							ResetToLobbyMap();
// 						}
// 					}
// 				}

// 				if (isObjectiveCompleted() && !RMC::GotGoalMedalOnCurrentMap) {
// 					RMC::PauseRun();
// 					Log::Log(playerGotGoalActualMap.name + " got goal medal with a time of " + playerGotGoalActualMap.time);
// 					UI::ShowNotification(Icons::Trophy + " " + playerGotGoalActualMap.name + " got "+tostring(PluginSettings::RMC_GoalMedal)+" medal with a time of " + playerGotGoalActualMap.timeStr, "Switching map...", Text::ParseHexColor("#01660f"));
// 					RMC::GoalMedalCount += 1;
// 					RMC::GotGoalMedalOnCurrentMap = true;
// 					RMTPlayerScore@ playerScored = findOrCreatePlayerScore(playerGotGoalActualMap);
// 					playerScored.AddGoal();
// 					m_playerScores.SortDesc();

// #if DEPENDENCY_BETTERCHAT
// 					BetterChat::SendChatMessage(Icons::Trophy + " " + playerGotGoalActualMap.name + " got "+tostring(PluginSettings::RMC_GoalMedal)+" medal with a time of " + playerGotGoalActualMap.timeStr + " Switching map...");
// #endif

// 					RMTSwitchMap();
// 				}
// 			}
// 		}
// 	}

// 	void RenderBelowGoalMedal() override
// 	{
// 		UI::Image(SkipTex, vec2(PluginSettings::RMC_ImageSize*2,PluginSettings::RMC_ImageSize*2));
// 		UI::SameLine();
//    	vec2 pos_orig = UI::GetCursorPos();
//    	UI::SetCursorPos(vec2(pos_orig.x, pos_orig.y+8));
//    	UI::PushFont(TimerFont);
//    	UI::Text(tostring(Skips));
//    	UI::PopFont();
//    	UI::SetCursorPos(pos_orig);
// 	}


// 	void SkipButtons() override
// 	{
// 		UI::BeginDisabled(RMC::ClickedOnSkip || isSwitchingMap);

// 		if(UI::Button(Icons::PlayCircleO + " Skip (-1 min)")) {
// 			RMC::PauseRun();
// 			RMC::ClickedOnSkip = true;
// 			Skips += 1;
			
// #if DEPENDENCY_BETTERCHAT
// 			BetterChat::SendChatMessage(Icons::Users + " Skipping map...");
// #endif
// 			startnew(CoroutineFunc(RMTSwitchMap));
// 		}
// 		RenderBrokenButton();

// 		UI::EndDisabled();
// 	}

// 	void BetterChatSendLeaderboard() override {
// #if DEPENDENCY_BETTERCHAT
// 		sleep(200);
// 		if (m_playerScores.Length > 0) {
// 			string currentStatsChat = Icons::Users + " " + GetModeNameShort() + " Score: " + tostring(RMC::GoalMedalCount) + " " + tostring(PluginSettings::RMC_GoalMedal) + " medals" + "\nLeaderboard:\n";
// 			for (uint i = 0; i < m_playerScores.Length; i++) {
// 				RMTPlayerScore@ p = m_playerScores[i];
// 				currentStatsChat += tostring(i+1) + ". " + p.name + ": " + p.goals + " " + tostring(PluginSettings::RMC_GoalMedal) + "\n";
// 			}
// 			BetterChat::SendChatMessage(currentStatsChat);
// 		}
// #endif
// 	}


// #else
// 	string GetModeName() override { return "Random Map Together Survival (NOT SUPPORTED ON THIS GAME)";}
// #endif
};