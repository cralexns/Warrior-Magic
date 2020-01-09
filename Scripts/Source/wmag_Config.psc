Scriptname wmag_Config extends SKI_ConfigBase

wmag_Main Property Main Auto
bool Property Enabled
	bool Function get()
		return Main.IsRunning()
	EndFunction
EndProperty

bool Property IsModStarting Auto Hidden

int Function GetVersion()
	return 7
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

;; Spell Charging Settings
int Property SPELLCHARGE_NONE = 0 Auto Hidden ;No spell charging - everything charges instantly.
int Property SPELLCHARGE_SPELLBASED = 1 Auto Hidden ;Spell charge time is based on the cast time of the spell.
int Property SPELLCHARGE_MAXMAGIC = 2 Auto Hidden ;Spell charge time is based on the amount of magicka required versus magicka pool

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
bool Property ConcentrationCastingFix = false Auto
bool Property EnableSweepingAttacks = true Auto
bool Property DisableChargeAnimation = true Auto

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
	Pages[0] = "General "
	Pages[1] = "Spells "
	
	ModName = Main.ModName

	chargeModes = new string[3]
	chargeModes[0] = "Instant"
	chargeModes[1] = "Cast Time"
	chargeModes[2] = "Magicka Cost"

	releaseModes = new string[3]
	releaseModes[0] = "Manual "
	releaseModes[1] = "On Key Release"
	releaseModes[2] = "Automatic"

	logLevelMenuEntries = new string[5]
	logLevelMenuEntries[0] = "Disabled"
	logLevelMenuEntries[1] = "Disk"
	logLevelMenuEntries[2] = "Console"
	logLevelMenuEntries[3] = "Notification"
	logLevelMenuEntries[4] = "Message Box"

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

Event OnConfigOpen()
	RegisterForModEvent("WMAG_ENABLE", "OnWMAGEnable")
	RegisterForModEvent("WMAG_BuildSpellCache", "OnBuildSpellCache")
EndEvent

Event OnConfigClose()
	learnedSpellsCached = false
	UnregisterForAllModEvents()
	Main.Reset()
EndEvent

;/ Event OnConfigRegister()
	Main.Log("MCM Registered", Main.LogLevel_Notification)
EndEvent /;

Event OnVersionUpdate(int version)
	Main.Log("version="+version+", CurrentVersion="+CurrentVersion)
	If version > CurrentVersion && CurrentVersion > 0
		OnConfigInit()
	EndIf
EndEvent

int totalSpells
int processedSpells
Spell lastLearnedSpell
bool updatingSpellCache
Form[] Function GetLearnedSpells(Actor akActor, bool forceUpdate = false)
	If updatingSpellCache
		Main.Log("Aborting GetLearnedSpells(), spell cache update in progress.. ("+processedSpells+"/"+totalSpells+")", Main.LogSeverity_Error)
		return PapyrusUtil.FormArray(0)
	EndIf
	updatingSpellCache = true

	ActorBase basePlayer = akActor.GetActorBase()

	int numRefSpells = akActor.GetSpellCount()
	int numBaseSpells = basePlayer.GetSpellCount()
	; If learnedSpellCache != None && numRefSpells+numBaseSpells == totalSpells
	; 	Main.Log("Skipping cache refresh, player total spell count is the same.")
	; 	return learnedSpellCache
	; EndIf
	;Form[] mappedSpells = Main.GetAllMappedSpells()

	If lastLearnedSpell != None && !forceUpdate
		Spell currentLastLearnedSpell = akActor.GetNthSpell(numRefSpells - 1)
		If lastLearnedSpell == currentLastLearnedSpell
			Main.Log("Skipping cache refresh, last learned spell is the same as last time.")
			updatingSpellCache = false
			return learnedSpellCache
		EndIf
	EndIf

	totalSpells = numRefSpells + numBaseSpells
	Form[] learnedSpells = PapyrusUtil.FormArray(totalSpells)

	int spellCount = 0
	int idx = 0
	bool peInstalled = Main.PapyrusExtenderInstalled

	While idx < numBaseSpells + numRefSpells
		If idx < numBaseSpells
			Spell baseSpell = basePlayer.GetNthSpell(idx)
			If IsSpell(baseSpell, akActor)
				learnedSpells[spellCount] = baseSpell
				spellCount += 1
			EndIf
		EndIf
		If idx < numRefSpells
			Spell refSpell = akActor.GetNthSpell(idx)
			If IsSpell(refSpell, akActor)
				learnedSpells[spellCount] = refSpell
				spellCount += 1
			EndIf
		EndIf

		idx += 1
		processedSpells = idx
	EndWhile

	lastLearnedSpell = learnedSpells[learnedSpells.length - 1] as Spell
	updatingSpellCache = false

	return PapyrusUtil.SliceFormArray(learnedSpells, 0, spellCount - 1)
EndFunction

bool Function IsSpell(Spell aSpell, Actor akActor)
	If aSpell.GetMagickaCost() <= 0
		return False 
	ElseIf Main.PapyrusExtenderInstalled && PO3_SKSEFunctions.GetSpellType(aSpell) != 0
		return False
	ElseIf aSpell.GetNthEffectMagicEffect(aSpell.GetCostliestEffectIndex()).IsEffectFlagSet(0x00008000)
		return False
	EndIf
	return true
EndFunction

Event OnWMAGEnable(string eventName, string strArg, float numArg, Form sender)
	IsModStarting = true
	Main.Start()
	IsModStarting = false
EndEvent


bool learnedSpellsCached
Form[] learnedSpellCache
Event OnBuildSpellCache(string eventName, string strArg, float numArg, Form sender)
	Main.Log("OnBuildSpellCache()")

	If !learnedSpellsCached
		Main.Log("Populating spell cache...")
		Utility.WaitMenuMode(0.5)
		Form[] spellCache = GetLearnedSpells(Main.PlayerRef)
		If spellCache.length > 0
			learnedSpellCache = spellCache
			learnedSpellsCached = true
		EndIf
		Main.Log("Finished populating spell cache.")
	EndIf
EndEvent


Event OnPageReset(string page)
	Main.Log("OnPageReset("+page+") - Enter")
	If page == Pages[0] || !Enabled || page == ""
		SetCursorFillMode(LEFT_TO_RIGHT)
		AddToggleOptionST("ToggleMod", "Mod Enabled", Enabled)

		If !Enabled
			If IsModStarting
				SetCursorPosition(0)
				AddTextOption("Mod Enabled", "[Pending Activation]")
			EndIf
			Return
		EndIf

		AddMenuOptionST("LogLevel", "Debug Log Level", logLevelMenuEntries[Main.LogLevel])

		float[] autoCastTimes = StorageUtil.FloatListToArray(Main, Main.ChargedDoneLatencyName)
		float averageAutoCast = zen_Util.GetFloatArraySum(autoCastTimes) / zen_Util.Max(autoCastTimes.length, 1)

		float[] queueTimes = StorageUtil.FloatListToArray(Main, Main.ChargedBeginLatencyName)
		float averageQueue = zen_Util.GetFloatArraySum(queueTimes) / zen_Util.Max(queueTimes.length, 1)

		SetCursorFillMode(TOP_TO_BOTTOM)
		SetCursorPosition(3)
		AddTextOptionST("LatencyAutoText", "Latency (CB)", (averageAutoCast * 1000) as int+" ms")
		AddTextOptionST("LatencyQueueText", "Latency (CD)", (averageQueue * 1000) as int+" ms")

		SetCursorPosition(4)
		AddToggleOptionST("DisableChargeAnimationToggle", "Disable Charge Animation", DisableChargeAnimation)
		AddToggleOptionST("ConcentrationCastingFixToggle", "Concentration Casting Fix", ConcentrationCastingFix)
		AddSliderOptionST("MaximumDurationModSlider", "Duration Extension Max", Main.MaximumDurationModifier, timesFormat)
		AddKeyMapOptionST("DispelKeyModifierKeyMap", "Dispel Key Modifier", Main.DispelKeyModifier)

		SetCursorPosition(9)
		AddToggleOptionST("JumpAttackToggle", "Enable Jump Attack", EnableJumpAttackHack)
		AddToggleOptionST("EnableSweepingAttacksToggle", "Enable Sweeping Attacks /w 1H", EnableSweepingAttacks)
		
		SetCursorPosition(14)
		AddHeaderOption("Offensive Casting", IsOptionDisabled(true))
		AddMenuOptionST("SpellChargeModeMenuO", "Charge Mode", chargeModes[Main.SpellChargeMode[1]])
		AddSliderOptionST("MinimumChargeTimeSliderO", "Min. Charge Time", Main.MinimumChargeTime[1], secondsFormat, IsOptionDisabled(Main.SpellChargeMode[1] == SPELLCHARGE_NONE))
		AddSliderOptionST("MaximumChargeTimeSliderO", "Max. Charge Time", Main.MaximumChargeTime[1], secondsFormat, IsOptionDisabled(Main.SpellChargeMode[1] == SPELLCHARGE_NONE))
		AddMenuOptionST("SpellReleaseModeO", "Release Mode", releaseModes[Main.SpellReleaseMode[1]])

		SetCursorPosition(15)
		AddHeaderOption("Defensive Casting", IsOptionDisabled(true))
		AddMenuOptionST("SpellChargeModeMenuD", "Charge Mode", chargeModes[Main.SpellChargeMode[0]])
		AddSliderOptionST("MinimumChargeTimeSliderD", "Min. Charge Time", Main.MinimumChargeTime[0], secondsFormat, IsOptionDisabled(Main.SpellChargeMode[0] == SPELLCHARGE_NONE))
		AddSliderOptionST("MaximumChargeTimeSliderD", "Max. Charge Time", Main.MaximumChargeTime[0], secondsFormat, IsOptionDisabled(Main.SpellChargeMode[0] == SPELLCHARGE_NONE))
		AddMenuOptionST("SpellReleaseModeD", "Release Mode", releaseModes[Main.SpellReleaseMode[0]])


	ElseIf page == Pages[1]
		SendModEvent("WMAG_BuildSpellCache")
		BuildSpellsPage()
	EndIf

	Main.Log("OnPageReset("+page+") - Exit")
EndEvent

; string[] ruleSlotNames
; int[] ruleSlotChargeOptionId
; int[] ruleSlotReleaseOptionId
; int[] ruleSlotChannelOptionId
; int[] ruleSlotRemoveId

; bool createRuleIsHostile
; int createRuleCastingType
; int createRuleCastingTarget
; Function BuildRules()
; 	ruleSlotChargeOptionId = Utility.CreateIntArray(10, -1)
; 	ruleSlotReleaseOptionId = Utility.CreateIntArray(10, -1)
; 	ruleSlotChannelOptionId = Utility.CreateIntArray(10, -1)
; 	ruleSlotRemoveId = Utility.CreateIntArray(10, -1)

; 	SetCursorFillMode(LEFT_TO_RIGHT)

; 	int idx = 0
; 	While idx < ruleSlotNames.Length
; 		string[] qualifiers = PapyrusUtil.StringSplit(ruleSlotNames[idx], ":")
; 		Main.Log(PapyrusUtil.StringJoin(qualifiers))

; 		bool isHostile = qualifiers[0] as int
; 		int castingType = qualifiers[1] as int
; 		int castingTarget = qualifiers[2] as int

; 		string name = GetNameForRule(isHostile, castingType, castingTarget)
; 		string ruleIdentifier = "WMAG_RULE_"+ruleSlotNames[idx]
; 		int chargeMode = StorageUtil.GetIntValue(Main, ruleIdentifier+"_CHARGE", 0)
; 		int releaseMode = StorageUtil.GetIntValue(Main, ruleIdentifier+"_RELEASE", 0)
; 		AddHeaderOption("Rule: " + name)
; 		AddEmptyOption()
; 		ruleSlotChargeOptionId[idx] = AddMenuOption("Charge", chargeModes[chargeMode])
; 		ruleSlotReleaseOptionId[idx] = AddMenuOption("Release", releaseModes[releaseMode])

; 		idx += 1
; 	EndWhile

; 	SetCursorFillMode(TOP_TO_BOTTOM)

; 	createRuleIsHostile = False
; 	createRuleCastingType = -1
; 	createRuleCastingTarget = -1

;     AddEmptyOption()
; 	AddHeaderOption("Custom Casting Rule")
; 	AddToggleOptionST("CreateRuleIsHostile", "Hostile", false)
; 	AddMenuOptionST("CreateRuleCastingType", "Type", "")
; 	AddMenuOptionST("CreateRuleCastingTarget", "Target", "")
; 	AddTextOptionST("CreateRule", "", "[Create Rule]")
; EndFunction

; string Function GetNameForRule(bool isHostile, int type, int target)
; 	string name = ""
; 	If isHostile
; 		name += "Hostile"
; 	Else
; 		name += "Friendly"
; 	EndIf

; 	name += " " + castingTypes[type] + " " + targetTypes[target]

; 	return name
; EndFunction

; bool Function CreateNewRule()
; 	Main.Log("CreateNewRule, castingType="+createRuleCastingType+", castingTarget="+createRuleCastingTarget)
; 	If createRuleCastingType != -1 && createRuleCastingTarget != -1 && ruleSlotNames.Length < 10
; 		string newRule = (createRuleIsHostile as int) + ":" + createRuleCastingType + ":" + createRuleCastingTarget
; 		If ruleSlotNames.Find(newRule) == -1
; 			ruleSlotNames = PapyrusUtil.PushString(ruleSlotNames, newRule)
; 			StorageUtil.SetIntValue(Main, "WMAG_RULE_"+newRule+"_CHARGE", 0)
; 			StorageUtil.SetIntValue(Main, "WMAG_RULE_"+newRule+"_RELEASE", 0)
; 			return true
; 		EndIf
; 	EndIf
; 	return false
; EndFunction

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
				int keyOptionId = AddKeyMapOption("KEY", keyCode)
				SetCursorFillMode(TOP_TO_BOTTOM)
				While sIdx < spells.Length
					spellSlotIndex[ssIdx] = slotIdx
					spellSlotSpellIndex[ssIdx] = sIdx
					spellSlotKeyOptionId[ssIdx] = keyOptionId
					If sIdx+1 == spells.Length
						SetCursorFillMode(LEFT_TO_RIGHT)
					EndIf
					spellSlotSpellOptionId[ssIdx] = AddMenuOption("SPELL", spells[sIdx].GetName())
					If sIdx+1 == spells.Length && StorageUtil.CountObjIntValuePrefix(Main, "WMAG_OVERRIDE_"+keyCode+"_") >= 1
						int chargeOverrideIndex = StorageUtil.GetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_CHARGE", -1)
						int releaseOverrideIndex = StorageUtil.GetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_RELEASE", -1)

						If chargeOverrideIndex >= 0
							spellSlotOverrideChargeId[ssIdx] = AddMenuOption("Charge Override", chargeModes[chargeOverrideIndex])
						Else
							StorageUtil.UnsetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_CHARGE")
							AddEmptyOption()
						EndIf
						
						If releaseOverrideIndex >= 0
							spellSlotOverrideReleaseId[ssIdx] = AddMenuOption("Release Override", releaseModes[releaseOverrideIndex])
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

		; int slotIdx = 0
		; While slotIdx < spellSlots
		; 	int keyCode = StorageUtil.IntListGet(Main, Main.KeyBindingIndexName, slotIdx)
		; 	Spell s = StorageUtil.FormListGet(Main, Main.KeyBindingIndexName, slotIdx) as Spell
		; 	If keyCode > 0 && s
		; 		spellSlotsKeyIndex[slotIdx] = AddKeyMapOption("KEY", keyCode)
		; 		spellSlotsSpellIndex[slotIdx] = AddMenuOption("SPELL", s.GetName())
		; 	EndIf
		; 	slotIdx += 1
		; EndWhile
	EndIf

	AddEmptyOption()
	AddEmptyOption()
	AddHeaderOption("Create a spell keybind")
	AddEmptyOption()

	SetCursorFillMode(TOP_TO_BOTTOM)

	enableOverride = false
	AddToggleOptionST("EnableOverride", "Enable Override", enableOverride)

	;SetCursorFillMode(LEFT_TO_RIGHT)
	spellSlotCreateIndex = AddKeyMapOption("Click to bind key", -1)
	
	;forceRefreshCacheId = AddTextOption("", "[Force refresh spell cache]")
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

	Main.Log("Didn't find unmapped spell, returning first available learned spell..")
	return learnedSpellCache[0] as Spell
EndFunction

Event OnOptionKeyMapChange(int option, int keyCode, string conflictControl, string conflictName)
	If AbortKeybinding(conflictControl, conflictName)
		Return
	EndIf

	int displayIndex = spellSlotKeyOptionId.Find(option)
	If option == spellSlotCreateIndex && keyCode != -1
		Spell defaultSpell = FindFirstUnmappedSpell(keyCode)
		If defaultSpell
			Main.BindSpellToKey(keyCode, defaultSpell)
			ForcePageReset()
		EndIf
		If enableOverride && StorageUtil.CountIntValuePrefix("WMAG_OVERRIDE_"+keyCode+"_") < 2
			StorageUtil.SetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_CHARGE", 0)
			StorageUtil.SetIntValue(Main, "WMAG_OVERRIDE_"+keyCode+"_RELEASE", 0)
		EndIf
	ElseIf displayIndex != -1
		int slotIndex = spellSlotIndex[displayIndex]
		int currentKeyCode = Main.GetKeyCodeByIndex(slotIndex)

		; Spell currentSpell = Main.GetSpellByIndex(slotIndex)
		; Spell otherSpell = Main.GetSpellByKey(keyCode)

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
		; If currentKeyCode > -1 && currentSpell && Main.UnbindKey(currentKeyCode)
		; 	If Main.BindSpellToKey(keyCode, currentSpell)
		; 		If otherSpell
		; 			Main.BindSpellToKey(currentKeyCode, otherSpell)
		; 		EndIf
		; 		ForcePageReset()
		; 	EndIf
		; EndIf
	EndIf
EndEvent

Event OnOptionSelect(int option)
	If option == forceRefreshCacheId
		learnedSpellsCached = false
		SendModEvent("WMAG_BuildSpellCache")
	EndIf
EndEvent

int spellMenuDisplayIndex = -1
int ruleDisplayIndex = -1
Event OnOptionMenuOpen(int option)
	If CurrentPage == Pages[1]
		spellMenuDisplayIndex = spellSlotSpellOptionId.Find(option)
		If spellMenuDisplayIndex >= 0

			float timeout = 10
			float interval = 0.1
			While timeout > 0 && !learnedSpellsCached ; - (totalSpells * 0.3)
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
				ShowMessage("Loading spells timed out.. If you have a lot of spells, abilities etc. it can take a while to filter, wait a little and try again.", false)
			EndIf

			LoadSpellsInSpellMenu(spellMenuDisplayIndex)
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
		SetInfoText("Click to change keybound spell, set default to remove spell.")
	ElseIf spellSlotKeyOptionId.Find(option) != -1
		;; Key Menu
		SetInfoText("Click to change keybinding, set default to clear keybinding and all spells.")
	ElseIf spellSlotCreateIndex == option
		;; Create
		SetInfoText("Enter an unbound key to create a new keybinding or an existing key to add another spell to that key.")
	ElseIf spellSlotOverrideChargeId.Find(option) != -1
		SetInfoText("Set a charge mode override for this specific keybinding, set default (R) to remove override.")
	ElseIf spellSlotOverrideReleaseId.Find(option) != -1
		SetInfoText("Set a release mode override for this specific keybinding, set default (R) to remove override.")
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
	If learnedSpellCache
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
		If displayIndex >= 0
			spellMenuDisplayIndex = -1
			int slotIndex = spellSlotIndex[displayIndex]
			int spellIndex = spellSlotSpellIndex[displayIndex]
			int keyCode = Main.GetKeyCodeByIndex(slotIndex)
			If index == -1
				If Main.UnbindKey(keyCode, spellIndex)
					ForcePageReset()
				EndIf
				return
			EndIf

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
			ShowMessage("Exit all menus to allow the mod to start.", false)
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
			SetInfoText("Exit all menus to allow the mod to start.")
		ElseIf Enabled
			SetInfoText("Disable all functions of the mod.")
		Else
			SetInfoText("Re-enable all functions of the mod.")
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
		SetInfoText("Set log level, setting this to 'Disabled' disables all debug related logging. Info, Warning and Errors will still be displayed and/or logged.")
	EndEvent
EndState

State LatencyAutoText
	Event OnSelectST()
		Main.LatencyMaintenance(Main.ChargedDoneLatencyName, 0, true)
		ForcePageReset()
	EndEvent

	Event OnHighlightST()
		SetInfoText("The average time it takes the script to process spells from the time a button press is registered until spell is ready for casting. Click to reset averages.")
	EndEvent
EndState

State LatencyQueueText
	Event OnSelectST()
		Main.LatencyMaintenance(Main.ChargedBeginLatencyName, 0, true)
		ForcePageReset()
	EndEvent

	Event OnHighlightST()
		SetInfoText("The average time it takes to prepare non-essentials after a spell is charged. Click to reset averages.")
	EndEvent
EndState

; State SpellChargeModeMenu
; 	Event OnMenuOpenST()
; 		SetMenuDialogStartIndex(SpellChargeMode)
; 		SetMenuDialogDefaultIndex(0)
; 		SetMenuDialogOptions(chargeModes)
; 	EndEvent

; 	Event OnMenuAcceptST(int index)
; 		SpellChargeMode = index
; 		SetMenuOptionValueST(chargeModes[index])
; 		SetOptionFlagsST(IsOptionDisabled(SpellChargeMode == 0), true, "MinimumChargeTimeSlider")
; 		SetOptionFlagsST(IsOptionDisabled(SpellChargeMode == 0), false, "MaximumChargeTimeSlider")
; 	EndEvent

; 	Event OnDefaultST()
; 		SpellChargeMode = 2
; 		SetMenuOptionValueST(chargeModes[SpellChargeMode])
; 		SetOptionFlagsST(IsOptionDisabled(SpellChargeMode == 0), true, "MinimumChargeTimeSlider")
; 		SetOptionFlagsST(IsOptionDisabled(SpellChargeMode == 0), false, "MaximumChargeTimeSlider")
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Set the behaviour of spell queue charging. Instant (1), based on the spell's Cast Time (2) or on the spell's Magicka Cost (3) relative to your maximum magicka.")
; 	EndEvent
; EndState

State SpellChargeModeMenuD
	Event OnMenuOpenST()
		SetMenuDialogStartIndex(Main.SpellChargeMode[0])
		SetMenuDialogDefaultIndex(0)
		SetMenuDialogOptions(chargeModes)
	EndEvent

	Event OnMenuAcceptST(int index)
		Main.SpellChargeMode[0] = index
		SetMenuOptionValueST(chargeModes[index])
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[0] == 0), true, "MinimumChargeTimeSliderD")
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[0] == 0), false, "MaximumChargeTimeSliderD")
	EndEvent

	Event OnDefaultST()
		Main.SpellChargeMode[0] = 0
		SetMenuOptionValueST(chargeModes[Main.SpellChargeMode[0]])
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[0] == 0), true, "MinimumChargeTimeSliderD")
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[0] == 0), false, "MaximumChargeTimeSliderD")
	EndEvent

	Event OnHighlightST()
		SetInfoText("Set the behaviour of spell queue charging. Instant (1), based on the spell's Cast Time (2) or on the spell's Magicka Cost (3) relative to your maximum magicka.")
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
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[1] == 0), true, "MinimumChargeTimeSliderO")
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[1] == 0), false, "MaximumChargeTimeSliderO")
	EndEvent

	Event OnDefaultST()
		Main.SpellChargeMode[1] = 1
		SetMenuOptionValueST(chargeModes[Main.SpellChargeMode[1]])
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[1] == 0), true, "MinimumChargeTimeSliderO")
		SetOptionFlagsST(IsOptionDisabled(Main.SpellChargeMode[1] == 0), false, "MaximumChargeTimeSliderO")
	EndEvent

	Event OnHighlightST()
		SetInfoText("Set the behaviour of spell queue charging. Instant (1), based on the spell's Cast Time (2) or on the spell's Magicka Cost (3) relative to your maximum magicka.")
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
		SetInfoText("Set the minimum charge time in seconds, spells will never charge faster than this value.")
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
		SetInfoText("Set the maximum charge time in seconds, spells will never charge slower than this value.")
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
		SetInfoText("Set the minimum charge time in seconds, spells will never charge faster than this value.")
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
		SetInfoText("Set the maximum charge time in seconds, spells will never charge slower than this value.")
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
		SetInfoText("Set the behaviour of spell release after charging: Manual (on attack or block), after releasing charge key (2), or automatically once charged (3)")
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
		SetInfoText("Set the behaviour of spell release after charging: Manual (on attack or block), after releasing charge key (2), or automatically once charged (3)")
	EndEvent
EndState

State JumpAttackToggle
	Event OnSelectST()
		EnableJumpAttackHack = !EnableJumpAttackHack
		SetToggleOptionValueST(EnableJumpAttackHack)
	EndEvent

	Event OnHighlightST()
		SetInfoText("Enable the ability to attack while jumping. (This is an experimental hack)")
	EndEvent
EndState

State ConcentrationCastingFixToggle
	Event OnSelectST()
		ConcentrationCastingFix = !ConcentrationCastingFix
		SetToggleOptionValueST(ConcentrationCastingFix)
	EndEvent

	Event OnHighlightST()
		SetInfoText("Enable a fix for concentration spells getting interrupted prematurely. (Mods calling [Cast - Spell] or [DispelSpell - Actor] can cause this)")
	EndEvent
EndState

State EnableSweepingAttacksToggle
	Event OnSelectST()
		EnableSweepingAttacks = !EnableSweepingAttacks
		SetToggleOptionValueST(EnableSweepingAttacks)
		Main.ToggleSweepingPerk(EnableSweepingAttacks)
	EndEvent

	Event OnHighlightST()
		SetInfoText("Allow sweeping attacks with 1H weapons. (Disabled in towns)")
	EndEvent
EndState

State DisableChargeAnimationToggle
	Event OnSelectST()
		DisableChargeAnimation = !DisableChargeAnimation
		SetToggleOptionValueST(DisableChargeAnimation)
	EndEvent

	Event OnHighlightST()
		SetInfoText("Disable charging animation allowing you to move while charging a spell.")
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
		SetInfoText("Recasting a spell on yourself extends it's duration up to selected a maximum of selected value times the spell's original duration. Set to 0 to disable this feature.")
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
		SetInfoText("Hold this key in conjunction with a keybinding to dispel that keybound spell.")
	EndEvent
EndState

State EnableOverride
	Event OnSelectST()
		enableOverride = !enableOverride
		SetToggleOptionValueST(enableOverride)
	EndEvent

	Event OnHighlightST()
		SetInfoText("Enable charge/release override setting for this keybind.")
	EndEvent
EndState

; State CreateRuleIsHostile
; 	Event OnSelectST()
; 		createRuleIsHostile = !createRuleIsHostile
; 		SetToggleOptionValueST(createRuleIsHostile)

; 		If CreateNewRule()
; 			ForcePageReset()
; 		EndIf
; 	EndEvent

; 	Event OnHighlightST()
; 		;SetInfoText("Enable the ability to attack while jumping. (This is an experimental hack)")
; 	EndEvent
; EndState

; State CreateRuleCastingType
; 	Event OnMenuOpenST()
; 		SetMenuDialogStartIndex(0)
; 		SetMenuDialogDefaultIndex(0)
; 		SetMenuDialogOptions(castingTypes)
; 	EndEvent

; 	Event OnMenuAcceptST(int index)
; 		createRuleCastingType = index
; 		SetMenuOptionValueST(castingTypes[index])
; 	EndEvent

; 	; Event OnDefaultST()
; 	; 	Main.SpellReleaseModeOffensive = Main.RELEASEMODE_KEYUP
; 	; 	SetMenuOptionValueST(releaseModes[Main.SpellReleaseModeOffensive])
; 	; EndEvent

; 	Event OnHighlightST()
; 		;SetInfoText("Set the behaviour of spell release after charging: Release on offensive (weapon swing) or defensive (block) action (1), after releasing charge key (2), hostile spells automatically (3), defensive spells automatically (4) or all spells automatically (5)")
; 	EndEvent
; EndState

; State CreateRuleCastingTarget
; 	Event OnMenuOpenST()
; 		SetMenuDialogStartIndex(0)
; 		SetMenuDialogDefaultIndex(0)
; 		SetMenuDialogOptions(targetTypes)
; 	EndEvent

; 	Event OnMenuAcceptST(int index)
; 		createRuleCastingTarget = index
; 		SetMenuOptionValueST(targetTypes[index])
; 	EndEvent

; 	; Event OnDefaultST()
; 	; 	Main.SpellReleaseModeOffensive = Main.RELEASEMODE_KEYUP
; 	; 	SetMenuOptionValueST(releaseModes[Main.SpellReleaseModeOffensive])
; 	; EndEvent

; 	Event OnHighlightST()
; 		;SetInfoText("Set the behaviour of spell release after charging: Release on offensive (weapon swing) or defensive (block) action (1), after releasing charge key (2), hostile spells automatically (3), defensive spells automatically (4) or all spells automatically (5)")
; 	EndEvent
; EndState

; State CreateRule
; 	Event OnSelectST()
; 		If CreateNewRule()
; 			ForcePageReset()
; 		EndIf
; 	EndEvent

; 	Event OnHighlightST()
; 		;SetInfoText("Disable charging animation allowing you to move while charging a spell.")
; 	EndEvent
; EndState

; State OffensiveQueueSizeSlider
; 	Event OnSliderOpenST()
; 		SetSliderDialogStartValue(OffensiveQueueMaxLength)
; 		SetSliderDialogDefaultValue(1)
; 		SetSliderDialogRange(1, 10)
; 		SetSliderDialogInterval(1)
; 	EndEvent

; 	Event OnSliderAcceptST(float value)
; 		OffensiveQueueMaxLength = value as int
; 		SetSliderOptionValueST(OffensiveQueueMaxLength)
; 	EndEvent

; 	Event OnDefaultST()
; 		OffensiveQueueMaxLength = 3
; 		SetSliderOptionValueST(OffensiveQueueMaxLength)
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Set the size of the offensive queue, limiting the amount of spells that can be charged before attacking.")
; 	EndEvent
; EndState

; State OffensiveAutoCastDisabledToggle
; 	Event OnSelectST()
; 		If OffensiveQueueAuto != AUTOCAST_DISABLED
; 			SetToggleOptionValueST(false)
; 			OffensiveQueueAuto = AUTOCAST_DISABLED
; 		Else
; 			OffensiveQueueAuto = AUTOCAST_INSTANT
; 			SetToggleOptionValueST(true)
; 		EndIf
; 		SetOptionFlagsST(IsOptionDisabled(OffensiveQueueAuto == AUTOCAST_DISABLED), false, "OffensiveAutoCastConcentrationToggle")
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Enable the ability to auto-cast offensive spells (attack) by holding down the associated key while weapons are drawn.")
; 	EndEvent
; EndState

; State OffensiveAutoCastConcentrationToggle
; 	Event OnSelectST()
; 		If Math.LogicalAnd(OffensiveQueueAuto, AUTOCAST_CONCENTRATION) == AUTOCAST_CONCENTRATION
; 			OffensiveQueueAuto = Math.LogicalXor(OffensiveQueueAuto, AUTOCAST_CONCENTRATION)
; 			SetToggleOptionValueST(false)
; 		Else
; 			OffensiveQueueAuto = Math.LogicalOr(OffensiveQueueAuto, AUTOCAST_CONCENTRATION)
; 			SetToggleOptionValueST(true)
; 		EndIf
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Only auto-cast offensive concentration spells.")
; 	EndEvent
; EndState

; State OffensiveConcentrationToggle
; 	Event OnSelectST()
; 		OffensiveConcentrationToggle = !OffensiveConcentrationToggle
; 		SetToggleOptionValueST(OffensiveConcentrationToggle)
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Toggle offensive concentration spells.")
; 	EndEvent
; EndState

; State OffensiveConcentrationShaderPersistToggle
; 	Event OnSelectST()
; 		OffensiveConcentrationShaderPersist = !OffensiveConcentrationShaderPersist
; 		SetToggleOptionValueST(OffensiveConcentrationShaderPersist)
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Toggle persisting shader effect for toggled offensive concentration spells.")
; 	EndEvent
; EndState	

; State DefensiveQueueSizeSlider
; 	Event OnSliderOpenST()
; 		SetSliderDialogStartValue(DefensiveQueueMaxLength)
; 		SetSliderDialogDefaultValue(1)
; 		SetSliderDialogRange(1, 10)
; 		SetSliderDialogInterval(1)
; 	EndEvent

; 	Event OnSliderAcceptST(float value)
; 		DefensiveQueueMaxLength = value as int
; 		SetSliderOptionValueST(DefensiveQueueMaxLength)
; 	EndEvent

; 	Event OnDefaultST()
; 		DefensiveQueueMaxLength = 6
; 		SetSliderOptionValueST(DefensiveQueueMaxLength)
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Set the size of the defensive queue, limiting the amount of spells that can be charged before blocking.")
; 	EndEvent
; EndState

; State DefensiveAutoCastDisabledToggle
; 	Event OnSelectST()
; 		If DefensiveQueueAuto != AUTOCAST_DISABLED
; 			SetToggleOptionValueST(false)
; 			DefensiveQueueAuto = AUTOCAST_DISABLED
; 		Else
; 			DefensiveQueueAuto = AUTOCAST_INSTANT
; 			SetToggleOptionValueST(true)
; 		EndIf
; 		SetOptionFlagsST(IsOptionDisabled(DefensiveQueueAuto == AUTOCAST_DISABLED), false, "DefensiveAutoCastConcentrationToggle")
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Enable the ability to auto-cast defensive spells (block) by holding down the associated key while weapons are drawn.")
; 	EndEvent
; EndState

; State DefensiveAutoCastConcentrationToggle
; 	Event OnSelectST()
; 		If Math.LogicalAnd(DefensiveQueueAuto, AUTOCAST_CONCENTRATION) == AUTOCAST_CONCENTRATION
; 			DefensiveQueueAuto = Math.LogicalXor(DefensiveQueueAuto, AUTOCAST_CONCENTRATION)
; 			SetToggleOptionValueST(false)
; 		Else
; 			DefensiveQueueAuto = Math.LogicalOr(DefensiveQueueAuto, AUTOCAST_CONCENTRATION)
; 			SetToggleOptionValueST(true)
; 		EndIf
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Only auto-cast defensive concentration spells.")
; 	EndEvent
; EndState

; State EnableContinousCastingToggle
; 	Event OnSelectST()
; 		EnableContinousCasting = !EnableContinousCasting
; 		SetToggleOptionValueST(EnableContinousCasting)
; 		SetOptionFlagsST(IsOptionDisabled(!EnableContinousCasting), false, "ContinousCastingCooldownSlider")
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Enable continously casting defensive non-concentration spells while blocking.")
; 	EndEvent
; EndState

; State ContinousCastingCooldownSlider
; 	Event OnSliderOpenST()
; 		SetSliderDialogStartValue(ContinousCastingCooldown)
; 		SetSliderDialogDefaultValue(1.0)
; 		SetSliderDialogRange(0.1, 5)
; 		SetSliderDialogInterval(0.05)
; 	EndEvent

; 	Event OnSliderAcceptST(float value)
; 		ContinousCastingCooldown = value
; 		SetSliderOptionValueST(ContinousCastingCooldown, secondsFormat)
; 	EndEvent

; 	Event OnDefaultST()
; 		ContinousCastingCooldown = 1.0
; 		SetSliderOptionValueST(ContinousCastingCooldown, secondsFormat)
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Set the delay before casting the next spell in the defensive queue when continously casting.")
; 	EndEvent
; EndState

; State EnableDefensiveHotCastingToggle
; 	Event OnSelectST()
; 		AllowDefensiveHotCasting = !AllowDefensiveHotCasting
; 		SetToggleOptionValueST(AllowDefensiveHotCasting)
; 	EndEvent

; 	Event OnHighlightST()
; 		SetInfoText("Enable instantly casting a defensive spell by clicking assigned hotkey while actively blocking.")
; 	EndEvent
; EndState