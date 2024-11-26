class RMS : RMC
{
	int Skips = 0;
	int GoalTimerIncrease = 3 * 60 * 1000;
	int OverflowAdjustmentTime = 0;
	int LoadedSurvivedTime = 0;

	UI::Texture@ SkipTex = UI::LoadTexture("src/Assets/Images/YEPSkip.png");

	string GetModeName() override { return "Random Map Survival";}

	int TimeLimit() override { return PluginSettings::RMC_SurvivalMaxTime * 60 * 1000; }

	int RunEndTimestamp() override { 
		int InitialLimit = RMC::ContinueSavedRun ? TimeLimit() - RMC::LoadedRemainingTime : TimeLimit();
		int MaxTime = TimeLimit() - (Skips * 60 * 1000);
		int BonusTime = (GoalTimerIncrease * RMC::GoalMedalCount) - OverflowAdjustmentTime;
		int FinalTimestamp = RMC::RunStartTimestamp + InitialLimit + RMC::TimePaused + BonusTime;
		int OverflowTime = Time::Now + MaxTime;
		if (FinalTimestamp > OverflowTime) {
			OverflowAdjustmentTime += FinalTimestamp - OverflowTime;
			BonusTime = (GoalTimerIncrease * RMC::GoalMedalCount) - OverflowAdjustmentTime;
			FinalTimestamp = RMC::RunStartTimestamp + InitialLimit + RMC::TimePaused + BonusTime;
		} 
		return FinalTimestamp;
	}

	int SurvivedTime() {
		return RMC::TimePlayed + LoadedSurvivedTime;
	}

	void RenderGameModeSpecificDebug() override {
		if(LoadedSurvivedTime > 0) UI::Text("LoadedSurvivedTime: " + LoadedSurvivedTime);
	}

	void RenderTimer() override {	
		UI::PushFont(TimerFont);
		if (RMC::IsRunning) {
			// display time remaining in run
			if (RMC::IsPaused) UI::TextDisabled(RMC::FormatTimer(RunRemainingTime()));
			else UI::Text(RMC::FormatTimer(RunRemainingTime()));

			// display overall time spent playing on maps
			if (SurvivedTime() > 0 && PluginSettings::RMC_SurvivalShowSurvivedTime) {
				UI::PopFont();
				UI::Dummy(vec2(0, 8));
				UI::PushFont(g_fontHeaderSub);
				UI::Text(RMC::FormatTimer(SurvivedTime()));
				UI::SetPreviousTooltip("Total time survived");
			} else {
				UI::Dummy(vec2(0, 8));
			}

			// display time spent playing on current map
			if (PluginSettings::RMC_DisplayMapTimeSpent) {
				if(SurvivedTime() > 0 && PluginSettings::RMC_SurvivalShowSurvivedTime) {
					UI::SameLine();
				}
				UI::PushFont(g_fontHeaderSub);
				UI::Text(Icons::Map + " " + RMC::FormatTimer(RMC::TimeSpentMap));
				UI::SetPreviousTooltip("Time spent on this map");
				UI::PopFont();
			}
		} else {
			UI::TextDisabled(RMC::FormatTimer(TimeLimit()));
			UI::Dummy(vec2(0, 8));
		}
		
		UI::PopFont();
	}

	void RenderBelowGoalMedal() override {
		UI::Image(SkipTex, vec2(PluginSettings::RMC_ImageSize*2,PluginSettings::RMC_ImageSize*2));
		UI::SameLine();
		vec2 pos_orig = UI::GetCursorPos();
		UI::SetCursorPos(vec2(pos_orig.x, pos_orig.y+8));
		UI::PushFont(TimerFont);
		UI::Text(tostring(Skips));
		UI::PopFont();
		UI::SetCursorPos(pos_orig);
	}

	void SkipButtons() override {
		UI::BeginDisabled(TM::IsPauseMenuDisplayed() || RMC::ClickedOnSkip);
		if (UI::Button(Icons::PlayCircleO + " Skip")) {
			RMC::PauseRun();
			RMC::ClickedOnSkip = true;
			Skips += 1;
			Log::Trace(GetModeNameShort()+": Skipping map");
			UI::ShowNotification("Please wait...");
			startnew(RMC::SwitchMap);
		}

		if (UI::OrangeButton(Icons::PlayCircleO + " Skip Broken Map")) {
			RMC::PauseRun();
			if (!UI::IsOverlayShown()) UI::ShowOverlay();
			Renderables::Add(BrokenMapSkipWarnModalDialog());
		}

		if (TM::IsPauseMenuDisplayed()) UI::SetPreviousTooltip("To skip the map, please exit the pause menu.");
		UI::EndDisabled();
	}

	void ResetValues() override {
		RMC::ResetValues();
		Skips = 0;
		LoadedSurvivedTime = 0;
		OverflowAdjustmentTime = 0;
	}

	void LoadSavedState() override {
		RMC::LoadSavedState();
		// TODO(80Ltrumpet): These are completely wrong (see `RMC::LoadSavedState`).
		Skips = RMC::CurrentRunData["SecondaryCounterValue"];
		LoadedSurvivedTime = RMC::CurrentRunData["CurrentRunTime"];
	}

	void GameEndNotification() override	{
		UI::ShowNotification(
			"\\$0f0" + GetModeName() + " ended!",
			"You survived with a time of " + RMC::FormatTimer(SurvivedTime()) +
			".\nYou got "+ RMC::GoalMedalCount + " " + tostring(PluginSettings::RMC_GoalMedal) +
			" medals and " + RMC::Survival.Skips + " skips."
		);
#if DEPENDENCY_CHAOSMODE
		if (RMC::selectedGameMode == RMC::GameMode::SurvivalChaos) ChaosMode::SetRMCMode(false);
#endif
	}

	void GotGoalMedalNotification() override {
		Log::Trace(GetModeNameShort()+ ": Got "+ tostring(PluginSettings::RMC_GoalMedal) + " medal!");
		UI::ShowNotification("\\$071" + Icons::Trophy + " You got " + tostring(PluginSettings::RMC_GoalMedal) + " time!", PluginSettings::RMC_AutoSwitch ? "Searching for next map...":"Click 'Next map' to change the map");
		if (PluginSettings::RMC_AutoSwitch) startnew(RMC::SwitchMap);
	}

	void GotBelowGoalMedalNotification() override {}
};
