Scriptname wmag_Config extends SKI_ConfigBase

wmag_Main Property Main Auto
bool Property Enabled
	bool Function get()
		return Main.IsRunning()
	EndFunction
EndProperty

bool Property IsModStarting Auto Hidden

int Function GetVersion()
	return 8
EndFunction

;; REMOVE THESE
 ; int Property OffensiveQueueMaxLength = 3 Auto
 ; int Property DefensiveQueueMaxLength = 6 Auto

 ;bool Property EnableContinousCasting = true Auto ;While blocking, cast all non-concentration spells in queue sequentially.
 ;float Property ContinousCastingCooldown = 1.0 Auto ;Cooldown between defensive spells while blocking.
 ;bool Property AllowDefensiveHotCasting = true Auto
 ;bool Property AutoReleaseSpell = true Auto
;bool Property AllowStackingSpells = false Auto ;Allow stacking offensive concentration spells by bashing
;---

; int Property SpellChargeMode = 2 Auto
; float Property MinimumChargeTime = 0.5 Auto
; float Property MaximumChargeTime = 1.0 Auto

;; AUTOCAST FLAGS
; int Property AUTOCAST_DISABLED = 0x00000000 Auto
; int Property AUTOCAST_INSTANT = 0x00000001 Auto
; int Property AUTOCAST_CONCENTRATION = 0x00000002 Auto
;int Property AUTOCAST_WEAPONDRAWN = 0x00000004 Auto

; REMOVE THESE
; int Property OffensiveQueueAuto = 0x00000000 Auto
; int Property DefensiveQueueAuto = 0x00000003 Auto

; bool Property OffensiveConcentrationToggle = true Auto
; bool Property OffensiveConcentrationShaderPersist = true Auto
; bool Property DefensiveConcentrationToggle = false Auto
; ---

bool Property EnableJumpAttackHack = true Auto
bool Property EnableSweepingAttacks = true Auto

;; Spell Cost Settings
; int Property SPELLCOST_NONE = 0 Auto Hidden ;No cost for spells.
; int Property SPELLCOST_MAGICKA = 1 Auto Hidden ;Spells cost magicka
; int Property SPELLCOST_STAMINA = 2 Auto Hidden ;Spells cost stamina
; int Property SPELLCOST_MAGICKA_OVERFLOW = 3 Auto Hidden ;Spells cost magicka, if player doesn't have enough magicka, use stamina for remaining cost.
; int Property SPELLCOST_MAGICKA_ADJUST_MAGNITUDE = 4 Auto Hidden; Spells cost magicka, remaining cost reduces magnitude.

; int Property SpellCostMode = 1 Auto


string sliderMaxFormat = "+{0} Max"
string percentageFormat = "{0}%"
string hoursFormat = "{0} hour(s)"
string secondsFormat = "{2}s"
string timesFormat = "X{1}"

string[] chargeModes
string[] releaseModes
string[] logLevelMenuEntries
string[] castingTypes
string[] targetTypes
Event OnConfigInit()
	Main.Log("OnConfigInit() - Enter")
	Pages = new string[2]
	Pages[0] = "$General"
	Pages[1] = "$Spells"
	
	ModName = Main.ModName

	chargeModes = new string[3]
	chargeModes[0] = "$Instant"
	chargeModes[1] = "$Cast Time"
	chargeModes[2] = "$Magicka Cost"

	releaseModes = new string[3]
	releaseModes[0] = "$Manual"
	releaseModes[1] = "$On Key Release"
	releaseModes[2] = "$Automatic"

	logLevelMenuEntries = new string[5]
	logLevelMenuEntries[0] = "$Disabled"
	logLevelMenuEntries[1] = "$Disk"
	logLevelMenuEntries[2] = "$Console"
	logLevelMenuEntries[3] = "$Notification"
	logLevelMenuEntries[4] = "$Message Box"

	castingTypes = new string[3]
	castingTypes[0] = "Constant"
	castingTypes[1] = "Fire and Forget"
	castingTypes[2] = "Concentration"

	targetTypes = new string[5]
	targetTypes[0] = "Self"
	targetTypes[1] = "Contact"
	targetTypes[2] = "Aimed"
	targetTypes[3] = "Actor"
	targetTypes[4] = "Location"

	If !Enabled
		;Utility.Wait(1.5)
		bool started = Main.Start()
		Main.Log("Started " + modName + " = " + started)
	EndIf

	Main.Log("OnConfigInit() - Exit")
EndEvent

bool mcmOpen
Event OnConfigOpen()
	RegisterForModEvent("WMAG_ENABLE", "OnWMAGEnable")
	RegisterForModEvent("WMAG_BuildSpellCache", "OnBuildSpellCache")
	mcmOpen = true
EndEvent

Event OnConfigClose()
	UnregisterForAllModEvents()
	Main.Reset()

	mcmOpen = false
EndEvent

Function ResetSpellsCache()
	learnedSpellsCached = false
EndFunction

;/ Event OnConfigRegister()
	Main.Log("MCM Registered", Main.LogLevel_Notification)
EndEvent /;

Event OnVersionUpdate(int version)
	Main.Log("version="+version+", CurrentVersion="+CurrentVersion)
	If version == 8 && CurrentVersion == 7
		; Reinstall..
		Main.Log("Updating to new version..", Main.LogSeverity_Warning)
		Main.Stop()
		Utility.WaitMenuMode(0.5)
		Main.Start()
	ElseIf version > CurrentVersion && CurrentVersion > 0
		OnConfigInit()
	EndIf
EndEvent

int totalSpells
int processedSpells
Form[] Function GetLearnedSpells(Actor akActor)
	ActorBase basePlayer = akActor.GetActorBase()

	int numRefSpells = akActor.GetSpellCount()
	int numBaseSpells = basePlayer.GetSpellCount()

	; If learnedSpellCache.length > 0 && lastLearnedSpell != None
	; 	Spell currentLastLearnedSpell = akActor.GetNthSpell(numRefSpells - 1)
	; 	If lastLearnedSpell == currentLastLearnedSpell && numRefSpells+numBaseSpells == totalSpells
	; 		Main.Log("Skipping cache refresh, spell count and last learned spell is the same as last time.")
	; 		return PapyrusUtil.FormArray(0)
	; 	EndIf
	; EndIf

	totalSpells = numRefSpells + numBaseSpells
	Form[] learnedSpells = PapyrusUtil.FormArray(totalSpells)

	int spellCount = 0
	int idx = 0
	bool peInstalled = Main.PapyrusExtenderInstalled

	Spell spellToCheck = None
	While idx < numBaseSpells + numRefSpells
		If idx < numBaseSpells
			spellToCheck = basePlayer.GetNthSpell(idx)
		Else
			spellToCheck = akActor.GetNthSpell(idx - numBaseSpells)
		EndIf

		If (peInstalled && PO3_SKSEFunctions.GetSpellType(spellToCheck) != 0) || spellToCheck.GetMagickaCost() <= 0 || spellToCheck.GetNthEffectMagicEffect(spellToCheck.GetCostliestEffectIndex()).IsEffectFlagSet(0x00008000)
			; continue
		Else
			learnedSpells[spellCount] = spellToCheck
			spellCount += 1
		EndIf

		idx += 1
		processedSpells = idx
	EndWhile

	return PapyrusUtil.SliceFormArray(learnedSpells, 0, spellCount - 1)
EndFunction

Event OnWMAGEnable(string eventName, string strArg, float numArg, Form sender)
	IsModStarting = true
	Main.Start()
	IsModStarting = false
EndEvent


bool learnedSpellsCached
bool updatingSpellCache
Form[] learnedSpellCache
Event OnBuildSpellCache(string eventName, string strArg, float numArg, Form sender)
	Main.Log("OnBuildSpellCache()")

	If !learnedSpellsCached
		Utility.WaitMenuMode(0.5)

		If forceRefreshCacheId != 0
			SetOptionFlags(forceRefreshCacheId, IsOptionDisabled(true), true)
			SetTextOptionValue(forceRefreshCacheId, "$WMAG_SPELLCACHEREFRESHING")
		EndIf

		BuildSpellCache()

		If forceRefreshCacheId != 0
			SetTextOptionValue(forceRefreshCacheId, "$WMAG_SPELLCACHEREFRESHED")
		EndIf
	EndIf
EndEvent

Function BuildSpellCache()
	Main.Log("BuildSpellCache() - updatingSpellCache="+updatingSpellCache)
	If !updatingSpellCache
		updatingSpellCache = true

		Main.Log("Populating spell cache...", Main.LogLevel_Notification)

		Form[] spellCache = GetLearnedSpells(Main.PlayerRef)
		learnedSpellCache = spellCache
		learnedSpellsCached = true

		Main.Log("Finished populating spell cache.", Main.LogLevel_Notification)

		updatingSpellCache = false
	EndIf
EndFunction


Event OnPageReset(string page)
	Main.Log("OnPageReset("+page+") - Enter")

	If page == Pages[0] || !Enabled || page == ""
		SetCursorFillMode(LEFT_TO_RIGHT)
		AddToggleOptionST("ToggleMod", "$Mod Enabled", Enabled)

		If !Enabled
			If IsModStarting
				SetCursorPosition(0)
				AddTextOption("Mod Enabled", "$WMAG_PENDINGACTIVATE")
			EndIf
			Return
		EndIf

		AddMenuOptionST("LogLevel", "$WMAG_LOGLEVEL", logLevelMenuEntries[Main.LogLevel])

		float[] autoCastTimes = StorageUtil.FloatListToArray(Main, Main.ChargedDoneLatencyName)
		float averageAutoCast = zen_Util.GetFloatArraySum(autoCastTimes) / zen_Util.Max(autoCastTimes.length, 1)

		float[] queueTimes = StorageUtil.FloatListToArray(Main, Main.ChargedBeginLatencyName)
		float averageQueue = zen_Util.GetFloatArraySum(queueTimes) / zen_Util.Max(queueTimes.length, 1)

		SetCursorFillMode(TOP_TO_BOTTOM)
		SetCursorPosition(3)
		AddTextOptionST("LatencyText", "$WMAG_LAT", (averageAutoCast * 1000) as int+" ms (+" + (averageQueue * 1000) as int + "ms)")
		AddToggleOptionST("SkipNonEssentialsToggle", "$WMAG_SKIPNONESSENTIALS", Main.SkipNonEssentialsForPerformance)

		SetCursorPosition(4)
		AddToggleOptionST("DisableChargeAnimationToggle", "$WMAG_DISCHARGEANIM", Main.DisableChargeAnimation)
		;AddToggleOptionST("ConcentrationCastingFixToggle", "$WMAG_CONCCASTFIX", Main.ConcentrationCastingFix, IsOptionDisabled(true))
		AddSliderOptionST("MaximumDurationModSlider", "$WMAG_DUREXTMAX", Main.MaximumDurationModifier, timesFormat)
		AddKeyMapOptionST("DispelKeyModifierKeyMap", "$WMAG_DISPKEYMOD", Main.DispelKeyModifier)

		SetCursorPosition(9)
		AddToggleOptionST("JumpAttackToggle", "$WMAG_JUMPATTACK", EnableJumpAttackHack)
		AddToggleOptionST("EnableSweepingAttacksToggle", "$WMAG_SWEEPATTACK", EnableSweepingAttacks)
		
		SetCursorPosition(14)
		AddHeaderOption("$Offensive Casting", IsOptionDisabled(true))
		AddMenuOptionST("SpellChargeModeMenuO", "$WMAG_CHARGEMODE", chargeModes[Main.SpellChargeMode[1]])
		AddSliderOptionST("MinimumChargeTimeSliderO", "$WMAG_MINCHARGETIME", Main.MinimumChargeTime[1], secondsFormat, IsOptionDisabled(Main.SpellChargeMode[1] != Main.SPELLCHARGE_MAXMAGIC))
		AddSliderOptionST("MaximumChargeTimeSliderO", "$WMAG_MAXCHARGETIME", Main.MaximumChargeTime[1], secondsFormat, IsOptionDisabled(Main.SpellChargeMode[1] != Main.SPELLCHARGE_MAXMAGIC))
		AddMenuOptionST("SpellReleaseModeO", "$WMAG_RELEASEMODE", releaseModes[Main.SpellReleaseMode[1]])

		SetCursorPosition(15)
		AddHeaderOption("Defensive Casting", IsOptionDisabled(true))
		AddMenuOptionST("SpellChargeModeMenuD", "$WMAG_CHARGEMODE", chargeModes[Main.SpellChargeMode[0]])
		AddSliderOptionST("MinimumChargeTimeSliderD", "$WMAG_MINCHARGETIME", Main.MinimumChargeTime[0], secondsFormat, IsOptionDisabled(Main.SpellChargeMode[0] != Main.SPELLCHARGE_MAXMAGIC))
		AddSliderOptionST("MaximumChargeTimeSliderD", "$WMAG_MAXCHARGETIME", Main.MaximumChargeTime[0], secondsFormat, IsOptionDisabled(Main.SpellChargeMode[0] != Main.SPELLCHARGE_MAXMAGIC))
		AddMenuOptionST("SpellReleaseModeD", "$WMAG_RELEASEMODE", releaseModes[Main.SpellReleaseMode[0]])


	ElseIf page == Pages[1]
		BuildSpellsPage()
		SendModEvent("WMAG_BuildSpellCache")
	EndIf

	Main.Log("OnPageReset("+page+") - Exit")
EndEvent

int[] spellSlotIndex
int[] spellSlotSpellIndex
int[] spellSlotKeyOptionId
int[] spellSlotSpellOptionId
int[] spellSlotOverrideChargeId
int[] spellSlotOverrideReleaseId

int spellSlotCreateIndex
bool enableOverride
int forceRefreshCacheId
Function BuildSpellsPage()
	int spellSlots = StorageUtil.IntListCount(Main, Main.KeyBindingIndexName)
	If spellSlots > 0
		spellSlotIndex = Utility.CreateIntArray(128, -1)
		spellSlotSpellIndex = Utility.CreateIntArray(128, -1)
		spellSlotKeyOptionId = Utility.CreateIntArray(128, -1)
		spellSlotSpellOptionId = Utility.CreateIntArray(128, -1)
		spellSlotOverrideChargeId = Utility.CreateIntArray(128, -1)
		spellSlotOverrideReleaseId = Utility.CreateIntArray(128, -1)

		int[] sortedKeys = StorageUtil.IntListToArray(Main, Main.KeyBindingIndexName)
		PapyrusUtil.SortIntArray(sortedKeys)

		int idx = 0
		int ssIdx = 0
		While idx < sortedKeys.Length
			int keyCode = sortedKeys[idx]
			int slotIdx = StorageUtil.IntListFind(Main, Main.KeyBindingIndexName, keyCode)
			;Spell s = StorageUtil.FormListGet(Main, Main.KeyBindingIndexName, slotIdx) as Spell
			Form[] spells = StorageUtil.FormListToArray(Main, Main.GetKeyNameForIndex(slotIdx))

			If keyCode > 0 && spells.length > 0
				int sIdx = 0
				int keyOptionId = AddKeyMapOption("$WMAG_KEY", keyCode)
				SetCursorFillMode(TOP_TO_BOTTOM)
				While sIdx < spells.Length
					spellSlotIndex[ssIdx] = slotIdx
					spellSlotSpellIndex[ssIdx] = sIdx
					spellSlotKeyOptionId[ssIdx] = keyOptionId
					If sIdx+1 == spells.Length
						SetCursorFillMode(LEFT_TO_RIGHT)
					EndIf
					spellSlotSpellOptionId[ssIdx] = AddMenuOption("$WMAG_SPELL", spells[sIdx].GetName())
					If sIdx+1 == spells.Length && StorageUtil.CountObjIntValuePrefix(Main, "WMAG_OVERRIDE_"+keyCode+"_") >= 1
						int chargeOverrideIndex = StorageUtil.GetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_CHARGE", -1)
						int releaseOverrideIndex = StorageUtil.GetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_RELEASE", -1)

						If chargeOverrideIndex >= 0
							spellSlotOverrideChargeId[ssIdx] = AddMenuOption("$WMAG_CHARGEOVERRIDE", chargeModes[chargeOverrideIndex])
						Else
							StorageUtil.UnsetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_CHARGE")
							AddEmptyOption()
						EndIf
						
						If releaseOverrideIndex >= 0
							spellSlotOverrideReleaseId[ssIdx] = AddMenuOption("$WMAG_RELEASEOVERRIDE", releaseModes[releaseOverrideIndex])
						Else
							StorageUtil.UnsetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_RELEASE")
							AddEmptyOption()
						EndIf
					EndIf
					sIdx += 1
					ssIdx += 1
				EndWhile
				
			EndIf
			idx += 1
		EndWhile
	EndIf

	AddEmptyOption()
	AddEmptyOption()
	AddHeaderOption("$Create a spell keybind")
	AddEmptyOption()

	SetCursorFillMode(TOP_TO_BOTTOM)

	enableOverride = false
	AddToggleOptionST("EnableOverride", "$WMAG_ENABLEOVERRIDE", enableOverride)

	SetCursorFillMode(LEFT_TO_RIGHT)
	spellSlotCreateIndex = AddKeyMapOption("$WMAG_BINDCREATE", -1)
	
	forceRefreshCacheId = AddTextOption("", "$WMAG_REFRESHSPELLCACHE")
EndFunction

int Function IsOptionDisabled(bool disabled = true)
	If disabled
		return OPTION_FLAG_DISABLED
	EndIf
	return OPTION_FLAG_NONE
EndFunction

int Function IsOptionHidden(bool isHidden = true)
	If isHidden
		return OPTION_FLAG_HIDDEN
	EndIf
	return OPTION_FLAG_NONE
EndFunction

bool Function AbortKeybinding(string conflictControl, string conflictName)
	bool continue = true
	if (conflictControl != "")
		string msg
		if (conflictName != "")
			msg = "This key is already mapped to:\n\"" + conflictControl + "\"\n(" + conflictName + ")\n\nAre you sure you want to continue?"
		else
			msg = "This key is already mapped to:\n\"" + conflictControl + "\"\n\nAre you sure you want to continue?"
		endIf

		return !ShowMessage(msg, true, "$Yes", "$No")
	endIf
	return false
EndFunction

string function GetCustomControl(int keyCode)
	If Main.GetSpellsByKey(keyCode) == None
		Return ""
	EndIf

	Form[] mappedSpells = Main.GetSpellsByKey(keyCode)
	string spellNames = ""
	If mappedSpells != None
		int idx = 0
		While idx < mappedSpells.length
			spellNames += mappedSpells[idx].GetName()
			If idx+1 < mappedSpells.Length
				spellNames += ", "
			EndIf
			idx += 1
		EndWhile
	EndIf
	return spellNames
endFunction

Spell Function FindFirstUnmappedSpell(int keyCode)
	int keyIndex = Main.GetIndexByKeyCode(keyCode)
	Spell firstMappedSpell = Main.GetSpellByIndex(keyIndex, 0)
	int filter = 0
	If firstMappedSpell != None
		If firstMappedSpell.IsHostile()
			filter = 1
		Else
			filter = 2
		EndIf
	EndIf

	int idx = 0
	Form[] mappedSpells = Main.GetAllMappedSpells()
	While idx < learnedSpellCache.Length
		Form learned = learnedSpellCache[idx]
		If mappedSpells.Find(learned) == -1 && (filter == 0 || (filter == 1 && (learned as Spell).IsHostile()) || (filter == 2 && !(learned as Spell).IsHostile()))
			Main.Log("Found unmapped spell = " + learned.GetName() + ", filter = " + filter)
			return learned as Spell
		EndIf
		idx += 1
	EndWhile

	Spell default = learnedSpellCache[0] as Spell

	If default == None
		Main.Log("Failed to find unmapped or learned spell (maybe cache is still processing?), defaulting to Flames (0x00012FCD)", Main.LogSeverity_Warning)
		return Game.GetForm(0x00012FCD) as Spell
	EndIf

	Main.Log("Didn't find unmapped spell, returning first available learned spell..")
	return default
EndFunction

Event OnOptionKeyMapChange(int option, int keyCode, string conflictControl, string conflictName)
	If updatingSpellCache
		ShowMessage("$WMAG_KEYBINDBLOCKEDBYCACHEREFRESH")
		return
	EndIf

	If AbortKeybinding(conflictControl, conflictName)
		Return
	EndIf

	int displayIndex = spellSlotKeyOptionId.Find(option)
	If option == spellSlotCreateIndex && keyCode != -1
		Spell defaultSpell = FindFirstUnmappedSpell(keyCode)
		If defaultSpell
			Main.BindSpellToKey(keyCode, defaultSpell)

			If enableOverride && StorageUtil.CountIntValuePrefix("WMAG_OVERRIDE_"+keyCode+"_") < 2
				StorageUtil.SetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_CHARGE", 0)
				StorageUtil.SetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_RELEASE", 0)
			EndIf

			ForcePageReset()
		EndIf
	ElseIf displayIndex != -1
		int slotIndex = spellSlotIndex[displayIndex]
		int currentKeyCode = Main.GetKeyCodeByIndex(slotIndex)

		int existingIndex = Main.GetIndexByKeyCode(keyCode)
		If existingIndex != -1 && !Main.SetKeyByIndex(existingIndex, currentKeyCode)
			Main.Log("Failed to reassign existing keybinding on keyIndex="+existingIndex+", aborting..", Main.LogSeverity_Warning)
			return
		EndIf

		If !Main.SetKeyByIndex(slotIndex, keyCode)
			Main.SetKeyByIndex(existingIndex, keyCode)
			Main.Log("Failed to assign existing keybinding on keyIndex="+slotIndex+", aborting..", Main.LogSeverity_Warning)
			return
		EndIf

		ForcePageReset()
	EndIf
EndEvent

Event OnOptionSelect(int option)
	If option == forceRefreshCacheId
		If updatingSpellCache
			ShowMessage("$WMAG_UPDATINGSPELLCACHE")
			return
		EndIf

		If ShowMessage("$WMAG_UPDATESPELLCACHE", true, "$Refresh", "$Abort")
			learnedSpellsCached = false
			ForcePageReset()
		EndIf
	EndIf
EndEvent

int spellMenuDisplayIndex = -1
int ruleDisplayIndex = -1
Event OnOptionMenuOpen(int option)
	If CurrentPage == Pages[1]
		spellMenuDisplayIndex = spellSlotSpellOptionId.Find(option)
		If spellMenuDisplayIndex >= 0

			float timeout = 30
			float interval = 0.1
			SetOptionFlags(option, IsOptionDisabled(true))
			While timeout > 0 && !learnedSpellsCached && mcmOpen ; - (totalSpells * 0.3)
				; If timeout as int % 2 == 0
				; 	SetMenuOptionValue(option, ". Loading ("+processedSpells+"/"+totalSpells+")")
				; Else
				; 	SetMenuOptionValue(option, ".. Loading ("+processedSpells+"/"+totalSpells+")")
				; EndIf
				Utility.WaitMenuMode(interval)
				SetMenuOptionValue(option, "Loading ("+processedSpells+"/"+totalSpells+")")
				timeout -= interval
			EndWhile

			If !learnedSpellsCached
				ShowMessage("$WMAG_LOADTIMEOUT", false)
			Else
				SetMenuOptionValue(option, "$WMAG_UPDATINGMENU")
			EndIf

			LoadSpellsInSpellMenu(spellMenuDisplayIndex)
			SetOptionFlags(option, IsOptionDisabled(false))
			return
		EndIf

		spellMenuDisplayIndex = spellSlotOverrideChargeId.Find(option)
		If spellMenuDisplayIndex >= 0
			OpenOverrideMenu(spellMenuDisplayIndex, chargeModes, "CHARGE")
			return
		EndIf

		spellMenuDisplayIndex = spellSlotOverrideReleaseId.Find(option)
		If spellMenuDisplayIndex >= 0
			OpenOverrideMenu(spellMenuDisplayIndex, releaseModes, "RELEASE")
			return
		EndIf
	EndIf
EndEvent

Function OpenOverrideMenu(int displayIndex, string[] options, string suffix)
	int slotIndex = spellSlotIndex[displayIndex]
	int keyCode = Main.GetKeyCodeByIndex(slotIndex)

	SetMenuDialogOptions(options)
	int index = StorageUtil.GetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_"+suffix, 0)
	SetMenuDialogStartIndex(index)
EndFunction

Function SetOverrideMenu(int displayIndex, int index, string suffix)
	int slotIndex = spellSlotIndex[displayIndex]
	int keyCode = Main.GetKeyCodeByIndex(slotIndex)

	Main.Log("DI="+displayIndex+", slotIdx="+slotIndex+", keyCode="+keyCode)
	StorageUtil.SetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_"+suffix, index)
EndFunction

Function ClearOverrideMenu(int displayIndex, string suffix)
	int slotIndex = spellSlotIndex[displayIndex]
	int keyCode = Main.GetKeyCodeByIndex(slotIndex)

	StorageUtil.UnsetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_"+suffix)
EndFunction

Event OnOptionHighlight(int option)
	If spellSlotSpellOptionId.Find(option) != -1
		;; Spell Menu
		SetInfoText("$WMAG_SPELL_INFO")
	ElseIf spellSlotKeyOptionId.Find(option) != -1
		;; Key Menu
		SetInfoText("$WMAG_KEY_INFO")
	ElseIf spellSlotCreateIndex == option
		;; Create
		SetInfoText("$WMAG_BINDCREATE_INFO")
	ElseIf spellSlotOverrideChargeId.Find(option) != -1
		SetInfoText("$WMAG_CHARGEOVERRIDE_INFO")
	ElseIf spellSlotOverrideReleaseId.Find(option) != -1
		SetInfoText("$WMAG_RELEASEOVERRIDE_INFO")
	EndIf
EndEvent

Event OnOptionDefault(int option)
	If CurrentPage == Pages[1]
		int kDisplayIndex = spellSlotKeyOptionId.Find(option)
		int mDisplayIndex = spellSlotSpellOptionId.Find(option)
		int keyIndex = -1
		int spellIndex = -1
		If kDisplayIndex != -1
			keyIndex = spellSlotIndex[kDisplayIndex]
		ElseIf mDisplayIndex != -1
			keyIndex = spellSlotIndex[mDisplayIndex]
			spellIndex = spellSlotSpellIndex[mDisplayIndex]
		EndIf

		If keyIndex != -1
			int keyCode = Main.GetKeyCodeByIndex(keyIndex)
			If keyCode != -1 && Main.UnbindKey(keyCode, spellIndex)
				StorageUtil.ClearObjIntValuePrefix(Main, "WMAG_OVERRIDE_"+keyCode+"_")
				ForcePageReset()
				return
			EndIf
		EndIf

		int chargeDisplayIndex = spellSlotOverrideChargeId.Find(option)
		If chargeDisplayIndex >= 0
			ClearOverrideMenu(chargeDisplayIndex, "CHARGE")
			ForcePageReset()
			return
		EndIf

		int releaseDisplayIndex = spellSlotOverrideReleaseId.Find(option)
		If releaseDisplayIndex >= 0
			ClearOverrideMenu(releaseDisplayIndex, "RELEASE")
			ForcePageReset()
			return
		EndIf
	EndIf
EndEvent

Function LoadSpellsInSpellMenu(int displayIndex)
	If learnedSpellsCached
		int slotIndex = spellSlotIndex[displayIndex]
		int spellIndex = spellSlotSpellIndex[displayIndex]
		Spell selectedSpell = Main.GetSpellByIndex(slotIndex, spellIndex)

		string[] options = PapyrusUtil.StringArray(learnedSpellCache.Length)

		int selectedIndex = 0
		int idx = 0
		While idx < options.Length 
			Spell s = learnedSpellCache[idx] as Spell
			options[idx] = s.GetName() + " (" + s.GetEffectiveMagickaCost(Main.PlayerRef) + ")"
			If s == selectedSpell
				selectedIndex = idx
			EndIf
			idx += 1
		EndWhile
		SetMenuDialogOptions(options)
		SetMenuDialogStartIndex(selectedIndex)
		SetMenuOptionValue(spellSlotSpellOptionId[displayIndex], learnedSpellCache[selectedIndex].GetName())
		SetMenuDialogDefaultIndex(-1)
	EndIf
EndFunction

Event OnOptionMenuAccept(int option, int index)
	Main.Log("OnOptionMenuAccept(), page = " + CurrentPage + ", option="+option+", index="+index)
	If CurrentPage == Pages[1]
		int displayIndex = spellSlotSpellOptionId.Find(option)
		If displayIndex >= 0 && index != -1
			spellMenuDisplayIndex = -1
			int slotIndex = spellSlotIndex[displayIndex]
			int spellIndex = spellSlotSpellIndex[displayIndex]
			int keyCode = Main.GetKeyCodeByIndex(slotIndex)
			; If index == -1
			; 	If Main.UnbindKey(keyCode, spellIndex)
			; 		ForcePageReset()
			; 	EndIf
			; 	return
			; EndIf

			Spell selectedSpell = learnedSpellCache[index] as Spell
			If selectedSpell && selectedSpell != Main.GetSpellByIndex(slotIndex, spellIndex)
				If keyCode > 0
					If Main.BindSpellToKey(keyCode, selectedSpell, spellIndex)
						ForcePageReset()
					EndIf
				EndIf
			EndIf
			return
		EndIf

		int chargeDisplayIndex = spellSlotOverrideChargeId.Find(option)
		If chargeDisplayIndex >= 0
			spellMenuDisplayIndex = -1
			SetOverrideMenu(chargeDisplayIndex, index, "CHARGE")
			SetMenuOptionValue(option, chargeModes[index])
			return
		EndIf

		int releaseDisplayIndex = spellSlotOverrideReleaseId.Find(option)
		If releaseDisplayIndex >= 0
			spellMenuDisplayIndex = -1
			SetOverrideMenu(releaseDisplayIndex, index, "RELEASE")
			SetMenuOptionValue(option, releaseModes[index])
			return
		EndIf
	EndIf
EndEvent

State ToggleMod
	Event OnSelectST()
		SetOptionFlagsST(OPTION_FLAG_DISABLED)
		If IsModStarting
			ShowMessage("$WMAG_MODACTIVATEMESSAGE", false)
			return
		ElseIf Enabled
			Main.Stop()
		Else
			SendModEvent("WMAG_ENABLE")
		EndIf

		SetToggleOptionValueST(Enabled)
		ForcePageReset()
	EndEvent

	Event OnHighlightST()
		If IsModStarting
			SetInfoText("$WMAG_MODACTIVATEMESSAGE")
		ElseIf Enabled
			SetInfoText("$WMAG_DISABLEMODINFO")
		Else
			SetInfoText("$WMAG_ENABLEMODINFO")
		EndIf
	EndEvent
EndState

State LogLevel
	Event OnMenuOpenST()
		SetMenuDialogStartIndex(Main.LogLevel)
		SetMenuDialogDefaultIndex(0)
		SetMenuDialogOptions(logLevelMenuEntries)
	EndEvent

	Event OnMenuAcceptST(int index)
		Main.LogLevel = index
		SetMenuOptionValueST(logLevelMenuEntries[index])
	EndEvent

	Event OnDefaultST()
		Main.LogLevel = 0
		SetMenuOptionValueST(logLevelMenuEntries[Main.LogLevel])
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_LOGLEVEL_INFO")
	EndEvent
EndState

State LatencyText
	Event OnSelectST()
		Main.LatencyMaintenance(Main.ChargedDoneLatencyName, 0, true)
		Main.LatencyMaintenance(Main.ChargedBeginLatencyName, 0, true)
		Main.Reset()
		ForcePageReset()
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_LAT_INFO")
	EndEvent
EndState

State SkipNonEssentialsToggle
	Event OnSelectST()
		Main.SkipNonEssentialsForPerformance = !Main.SkipNonEssentialsForPerformance
		SetToggleOptionValueST(Main.SkipNonEssentialsForPerformance)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_SKIPNONESSENTIALS_INFO")
	EndEvent
EndState

State SpellChargeModeMenuD
	Event OnMenuOpenST()
		SetMenuDialogStartIndex(Main.SpellChargeMode[0])
		SetMenuDialogDefaultIndex(0)
		SetMenuDialogOptions(chargeModes)
	EndEvent

	Event OnMenuAcceptST(int index)
		Main.SpellChargeMode[0] = index
		SetMenuOptionValueST(chargeModes[index])
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[0] != Main.SPELLCHARGE_MAXMAGIC), true, "MinimumChargeTimeSliderD")
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[0] != Main.SPELLCHARGE_MAXMAGIC), false, "MaximumChargeTimeSliderD")
	EndEvent

	Event OnDefaultST()
		Main.SpellChargeMode[0] = 0
		SetMenuOptionValueST(chargeModes[Main.SpellChargeMode[0]])
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[0] != Main.SPELLCHARGE_MAXMAGIC), true, "MinimumChargeTimeSliderD")
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[0] != Main.SPELLCHARGE_MAXMAGIC), false, "MaximumChargeTimeSliderD")
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_CHARGEMODE_INFO")
	EndEvent
EndState

State SpellChargeModeMenuO
	Event OnMenuOpenST()
		SetMenuDialogStartIndex(Main.SpellChargeMode[1])
		SetMenuDialogDefaultIndex(0)
		SetMenuDialogOptions(chargeModes)
	EndEvent

	Event OnMenuAcceptST(int index)
		Main.SpellChargeMode[1]= index
		SetMenuOptionValueST(chargeModes[index])
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[1] != Main.SPELLCHARGE_MAXMAGIC), true, "MinimumChargeTimeSliderO")
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[1] != Main.SPELLCHARGE_MAXMAGIC), false, "MaximumChargeTimeSliderO")
	EndEvent

	Event OnDefaultST()
		Main.SpellChargeMode[1] = 1
		SetMenuOptionValueST(chargeModes[Main.SpellChargeMode[1]])
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[1] != Main.SPELLCHARGE_MAXMAGIC), true, "MinimumChargeTimeSliderO")
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[1] != Main.SPELLCHARGE_MAXMAGIC), false, "MaximumChargeTimeSliderO")
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_CHARGEMODE_INFO")
	EndEvent
EndState

State MinimumChargeTimeSliderO
	Event OnSliderOpenST()
		SetSliderDialogStartValue(Main.MinimumChargeTime[1])
		SetSliderDialogDefaultValue(0.5)
		SetSliderDialogRange(0, Main.MaximumChargeTime[1])
		SetSliderDialogInterval(0.05)
	EndEvent

	Event OnSliderAcceptST(float value)
		Main.MinimumChargeTime[1] = value
		SetSliderOptionValueST(value, secondsFormat)
	EndEvent

	Event OnDefaultST()
		Main.MinimumChargeTime[1] = 0.5
		SetSliderOptionValueST(Main.MinimumChargeTime[1], secondsFormat)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_MINCHARGETIME_INFO")
	EndEvent
EndState

State MaximumChargeTimeSliderO
	Event OnSliderOpenST()
		SetSliderDialogStartValue(Main.MaximumChargeTime[1])
		SetSliderDialogDefaultValue(1)
		SetSliderDialogRange(Main.MinimumChargeTime[1], 10)
		SetSliderDialogInterval(0.05)
	EndEvent

	Event OnSliderAcceptST(float value)
		Main.MaximumChargeTime[1] = value
		SetSliderOptionValueST(value, secondsFormat)
	EndEvent

	Event OnDefaultST()
		Main.MaximumChargeTime[1] = 1
		SetSliderOptionValueST(Main.MaximumChargeTime[1], secondsFormat)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_MINCHARGETIME_INFO")
	EndEvent
EndState

State MinimumChargeTimeSliderD
	Event OnSliderOpenST()
		SetSliderDialogStartValue(Main.MinimumChargeTime[0])
		SetSliderDialogDefaultValue(0.5)
		SetSliderDialogRange(0, Main.MaximumChargeTime[0])
		SetSliderDialogInterval(0.05)
	EndEvent

	Event OnSliderAcceptST(float value)
		Main.MinimumChargeTime[0] = value
		SetSliderOptionValueST(value, secondsFormat)
	EndEvent

	Event OnDefaultST()
		Main.MinimumChargeTime[0] = 0.5
		SetSliderOptionValueST(Main.MinimumChargeTime[0], secondsFormat)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_MAXCHARGETIME_INFO")
	EndEvent
EndState

State MaximumChargeTimeSliderD
	Event OnSliderOpenST()
		SetSliderDialogStartValue(Main.MaximumChargeTime[0])
		SetSliderDialogDefaultValue(1)
		SetSliderDialogRange(Main.MinimumChargeTime[0], 10)
		SetSliderDialogInterval(0.05)
	EndEvent

	Event OnSliderAcceptST(float value)
		Main.MaximumChargeTime[0] = value
		SetSliderOptionValueST(value, secondsFormat)
	EndEvent

	Event OnDefaultST()
		Main.MaximumChargeTime[0] = 1
		SetSliderOptionValueST(Main.MaximumChargeTime[0], secondsFormat)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_MAXCHARGETIME_INFO")
	EndEvent
EndState

State SpellReleaseModeD
	Event OnMenuOpenST()
		SetMenuDialogStartIndex(Main.SpellReleaseMode[0])
		SetMenuDialogDefaultIndex(0)
		SetMenuDialogOptions(releaseModes)
	EndEvent

	Event OnMenuAcceptST(int index)
		Main.SpellReleaseMode[0] = index
		SetMenuOptionValueST(releaseModes[index])
	EndEvent

	Event OnDefaultST()
		Main.SpellReleaseMode[0] = Main.RELEASEMODE_KEYUP
		SetMenuOptionValueST(releaseModes[Main.SpellReleaseMode[0]])
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_RELEASEMODE_INFO")
	EndEvent
EndState

State SpellReleaseModeO
	Event OnMenuOpenST()
		SetMenuDialogStartIndex(Main.SpellReleaseMode[1])
		SetMenuDialogDefaultIndex(0)
		SetMenuDialogOptions(releaseModes)
	EndEvent

	Event OnMenuAcceptST(int index)
		Main.SpellReleaseMode[1] = index
		SetMenuOptionValueST(releaseModes[index])
	EndEvent

	Event OnDefaultST()
		Main.SpellReleaseMode[1] = Main.RELEASEMODE_KEYUP
		SetMenuOptionValueST(releaseModes[Main.SpellReleaseMode[1]])
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_RELEASEMODE_INFO")
	EndEvent
EndState

State JumpAttackToggle
	Event OnSelectST()
		EnableJumpAttackHack = !EnableJumpAttackHack
		SetToggleOptionValueST(EnableJumpAttackHack)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_JUMPATTACK_INFO")
	EndEvent
EndState

State ConcentrationCastingFixToggle
	Event OnSelectST()
		Main.ConcentrationCastingFix = !Main.ConcentrationCastingFix
		SetToggleOptionValueST(Main.ConcentrationCastingFix)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_CONCCASTFIX_INFO")
	EndEvent
EndState

State EnableSweepingAttacksToggle
	Event OnSelectST()
		EnableSweepingAttacks = !EnableSweepingAttacks
		SetToggleOptionValueST(EnableSweepingAttacks)
		Main.ToggleSweepingPerk(EnableSweepingAttacks)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_SWEEPATTACK_INFO")
	EndEvent
EndState

State DisableChargeAnimationToggle
	Event OnSelectST()
		Main.DisableChargeAnimation = !Main.DisableChargeAnimation
		SetToggleOptionValueST(Main.DisableChargeAnimation)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_DISCHARGEANIM_INFO")
	EndEvent
EndState

State MaximumDurationModSlider
	Event OnSliderOpenST()
		SetSliderDialogInterval(0.5)
		SetSliderDialogRange(0, 10.0)
		SetSliderDialogStartValue(Main.MaximumDurationModifier)
	EndEvent
	Event OnSliderAcceptST(float value)
		Main.MaximumDurationModifier = value
		SetSliderOptionValueST(value, timesFormat)
	EndEvent
	Event OnHighlightST()
		SetInfoText("$WMAG_DUREXTMAX_INFO")
	EndEvent
EndState

State DispelKeyModifierKeyMap
	Event OnKeyMapChangeST(int keyCode, string conflictControl, string conflictName)
		If AbortKeybinding(conflictControl, conflictName)
			Return
		EndIf

		Main.DispelKeyModifier = keyCode
		SetKeyMapOptionValueST(keyCode)
	EndEvent

	Event OnDefaultST()
		Main.DispelKeyModifier = -1
		SetKeyMapOptionValueST(-1)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_DISPKEYMOD_INFO")
	EndEvent
EndState

State EnableOverride
	Event OnSelectST()
		enableOverride = !enableOverride
		SetToggleOptionValueST(enableOverride)
	EndEvent

	Event OnHighlightST()
		SetInfoText("$WMAG_ENABLEOVERRIDE_INFO")
	EndEvent
EndState