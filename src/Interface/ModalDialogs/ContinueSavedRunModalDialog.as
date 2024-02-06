class ContinueSavedRunModalDialog : ModalDialog {
	ContinueSavedRunModalDialog() {
		super("\\$f90" + Icons::ExclamationTriangle + " \\$zContinue Saved Run?");
		m_size = vec2(400, 160);
	}

	void RenderDialog() override {
		float scale = UI::GetScale();
		UI::BeginChild("Content", vec2(0, -32) * scale);
		int PrimaryCounterValue = RMC::CurrentRunData["PrimaryCounterValue"];
		UI::Text(
			"You already have a saved " + tostring(RMC::selectedGameMode) + " run with " + tostring(PrimaryCounterValue) + " " + PluginSettings::RMC_GoalMedal + "s"
			"\n\nDo you want to continue this run or start a new one?"
			"\n\nNOTE: Starting a new run will delete the current save!"
		);
		UI::EndChild();
		if (UI::RedButton(Icons::Times + " New Run (delete save)")) {
			RMC::ContinueSavedRun = false;
			DataManager::RemoveCurrentSaveFile();
			Close();
			RMC::HasCompletedCheckbox = true;
		}
		UI::SameLine();
		UI::SetCursorPos(vec2(UI::GetWindowSize().x - 100 * scale, UI::GetCursorPos().y));
		if (UI::GreenButton(Icons::PlayCircleO + " Continue saved run")) {
			RMC::ContinueSavedRun = true;
			Close();
			RMC::HasCompletedCheckbox = true;
		}
	}
};