Scriptname wmag_Main extends Quest Conditional
import zen_Util

string Property ModName = "Warrior Magic" Auto
Actor Property PlayerRef Auto
Float Property Version Auto Hidden
int Property LogLevel = 2 Auto

wmag_Main Function Current() Global
	return (Quest.GetQuest("wmag_Main") as Quest) as wmag_Main
EndFunction

bool Property PapyrusExtenderInstalled Auto

wmag_Config Property Config Auto
;wmag_Player Property PlayerAlias Auto

FormList Property TestSpells Auto

FormList Property EffectShaders Auto
FormList Property SoundEffects Auto ;0 = Default, 1 = Success, 2 = Fail, 3 = Alt, 4 = Con, 5 = Des Ice, 6 = Des Fire, 7 = Ill, 8 = Res
FormList Property ModSpellsDuration Auto
FormList Property ModSpellsMagnitude Auto

Idle Property IdleStop_Loose Auto
Spell Property BindingAbility Auto

Perk Property SweepingAttacks Auto
Perk Property SpellMod Auto

bool Property IsCharging Auto Conditional

bool Property DisableChargeAnimation = true Auto
bool Property ConcentrationCastingFix = false Auto

;; Spell Release Settings
int Property RELEASEMODE_MANUAL = 0 Auto
int Property RELEASEMODE_KEYUP = 1 Auto
int Property RELEASEMODE_AUTOMATIC = 2 Auto

;; Spell Charging Settings
int Property SPELLCHARGE_NONE = 0 Auto Hidden ;No spell charging - everything charges instantly.
int Property SPELLCHARGE_SPELLBASED = 1 Auto Hidden ;Spell charge time is based on the cast time of the spell.
int Property SPELLCHARGE_MAXMAGIC = 2 Auto Hidden ;Spell charge time is based on the amount of magicka required versus magicka pool

int[] Property SpellReleaseMode Auto
int[] Property SpellChargeMode Auto
float[] Property MinimumChargeTime Auto
float[] Property MaximumChargeTime Auto

float Property MaximumDurationModifier = 3.0 Auto
float Property MaximumMagnitudeModifier = 1.5 Auto

int Property DispelKeyModifier = 56 Auto

string Property KeyBindingIndexName = "KeyBindingIndex" Auto Hidden ; TODO: Add cycle spells to keybindings.

string Property ChargedBeginLatencyName = "Latency1" Auto
string Property ChargedDoneLatencyName = "Latency2" Auto

bool Property SkipNonEssentialsForPerformance = false Auto
float Property HighLatencyThreshold = 200.0 Auto

int[] validWeaponTypes

;/
	TODO:
	2. Consider adding support for modifiers in keybindings.
/;

Event OnInit()
	Version = 0.9
	validWeaponTypes = StringToIntArray("1,2,3,4,5,6,10", ",")

	If SpellChargeMode.Length < 2 || SpellReleaseMode.Length < 2 || MaximumChargeTime.Length < 2 || MinimumChargeTime.Length < 2
		SpellChargeMode = new int[2]
		SpellChargeMode[0] = SPELLCHARGE_NONE
		SpellChargeMode[1] = SPELLCHARGE_SPELLBASED

		SpellReleaseMode = new int[2]
		SpellReleaseMode[0] = RELEASEMODE_AUTOMATIC
		SpellReleaseMode[1] = RELEASEMODE_KEYUP

		MaximumChargeTime = new float[2]
		MaximumChargeTime[0] = 5
		MaximumChargeTime[1] = 5

		MinimumChargeTime = new float[2]
		MinimumChargeTime[0] = 0.25
		MinimumChargeTime[1] = 0.25
	EndIf
EndEvent

bool initStarted = false
Function Initialize()
	Log("Initialize()", LogSeverity_Debug)
	If initStarted || !IsRunning()
		Log("Aborting Initialize (initStarted="+initStarted+", IsRunning="+IsRunning()+") ..")
		Return
	EndIf
	initStarted = true

	RegisterEvents()
	
	string versionText = StringUtil.Substring(Version as string, 0, StringUtil.Find(Version as string, ".")+3)
	Log(ModName+" ("+versionText+") installed.", LogLevel_Notification)

	(self.GetNthAlias(0) as wmag_Player).OnInit()

	OnPlayerLoadGame()
EndFunction

bool Function Start()
	Log("Starting..", LogSeverity_Debug)
	bool bStart = parent.Start()
	If bStart
		Initialize()
		GoToState("Normal")
	Else
		Log("Failed to start " + self.GetName() + " Quest.. ?", LogSeverity_Debug)
	EndIf
	return bStart
EndFunction

Function Stop()
	Log("Stopping.. State="+GetState()+" ("+chargedState+","+chargedSpell+","+isBusy+","+keyCodeInterruptCast+")", LogSeverity_Debug)
	
	StorageUtil.ClearAllPrefix("WMAG_CACHE")

	StorageUtil.ClearAllObjPrefix(self, ChargedBeginLatencyName)
	StorageUtil.ClearAllObjPrefix(self, ChargedDoneLatencyName)
	Config.ResetSpellsCache()

	GoToState("Disabled")
	parent.Stop()
EndFunction

Function Reset()
	GoToState("")
	GoToState("Normal")
	ValidateEquipped()
EndFunction

Event OnPlayerLoadGame()
	If !CheckIfPapyrusUtilInstalled()
		Log("Warrior Magic couldn't find PapyrusUtil, please make sure you've installed PapyrusUtil - you can find this requirement on the mod page on Nexus.", LogSeverity_Error)
		GoToState("Disabled")
		return
	EndIf

	RegisterEvents()
	RegisterKeys()
	CheckIfPapyrusExtenderInstalled()

	;IsCharging = true

	ToggleSweepingPerk(Config.EnableSweepingAttacks)

	If !PlayerRef.HasPerk(SpellMod)
		PlayerRef.AddPerk(SpellMod)
	EndIf

	If GetState() != "Normal"
		Reset()
	EndIf

	; ; DEBUGGING -- ! REMOVE ME !
	; int idx = 0
	; While idx < TestSpells.GetSize()
	; 	PlayerRef.AddSpell(TestSpells.GetAt(idx) as Spell)
	; 	idx += 1
	; EndWhile

	StorageUtil.IntListClear(self, ChargedBeginLatencyName)
	StorageUtil.IntListClear(self, ChargedDoneLatencyName)
EndEvent

Function RegisterEvents()
	string[] animationEvents = StringUtil.Split("HitFrame,blockStartOut,SoundPlay.NPCHumanCombatShieldBlock,blockStop,SoundPlay.NPCHumanCombatShieldRelease,attackStop,PowerAttack_Start_end,weaponSwing,weaponLeftSwing,staggerStart", ",")
	Log("Register " + animationEvents.length + " combat related animations..", LogSeverity_Debug)

	int idx = 0
	While (idx < animationEvents.length)
		RegisterForAnimationEvent(PlayerRef, animationEvents[idx])
		idx += 1
	EndWhile

	Log("Events registered!")
EndFunction

Function RegisterKeys()
	int idx = 0
	While idx < StorageUtil.IntListCount(self, KeyBindingIndexName)
		int keyCode = StorageUtil.IntListGet(self, KeyBindingIndexName, idx)
		RegisterForKey(keyCode)
		Log("Registered KeyCode = " + keyCode, LogSeverity_Debug)
		idx += 1
	EndWhile

	Log("Keys registered!")
EndFunction

Function CheckIfPapyrusExtenderInstalled()
	Spell spellTest = TestSpells.GetAt(0) as Spell
	If (spellTest != None)
		MagicEffect m = spellTest.GetNthEffectMagicEffect(0)
		If (m != None)
			Log("Checking if PapyrusExtender is installed...", LogSeverity_Debug)
			SoundDescriptor snd = PO3_SKSEfunctions.GetMagicEffectSound(m, 1)
			PapyrusExtenderInstalled = snd != None
			Log("PapyrusExtenderInstalled = " + PapyrusExtenderInstalled, LogSeverity_Debug)
		EndIf
	EndIf
EndFunction

bool Function CheckIfPapyrusUtilInstalled()
	Log("Checking if PapyrusUtil is installed..", LogSeverity_Debug)
	string[] testArray = PapyrusUtil.StringArray(1, "PUTest")
	If testArray.Length == 1 && testArray[0] == "PUTest"
		return True
	EndIf
	return False
EndFunction


;/  ----
	SPELL BINDING FUNCTIONS	
/;

string Function GetKeyNameForIndex(int keyIndex)
	return KeyBindingIndexName + "_"+keyIndex+"_Spells"
EndFunction

bool Function SetKeyByIndex(int keyIndex, int keyCode)
	return StorageUtil.IntListSet(self, KeyBindingIndexName, keyIndex, keyCode)
EndFunction

bool Function BindSpellToKey(int keyCode, Spell aSpell, int spellIndex = -1)
	int keyIndex = StorageUtil.IntListFind(self, KeyBindingIndexName, keyCode)
	
	If keyIndex == -1
		keyIndex = StorageUtil.IntListAdd(self, KeyBindingIndexName, keyCode, true)
		RegisterForKey(keyCode)
	EndIf

	string keyName = GetKeyNameForIndex(keyIndex)
	int spellCount = StorageUtil.FormListCount(self, keyName)
	If spellCount > 1 || (spellCount == 1 && spellIndex != 0)
		Spell firstSpell = StorageUtil.FormListGet(self, keyName, 0) as Spell
		If firstSpell.IsHostile() != aSpell.IsHostile()
			Log("It's not possible to put offensive and defensive spells into the same key binding.", LogSeverity_Warning)
			return false
		EndIf
	EndIf

	If spellCount > 1 && spellIndex != 1
		int existingSpellIndex = StorageUtil.FormListFind(self, keyName, aSpell)
		If existingSpellIndex != -1
			Spell originalSpell = StorageUtil.FormListGet(self, keyName, spellIndex) as Spell
			StorageUtil.FormListSet(self, keyName, existingSpellIndex, originalSpell)
		EndIf
	EndIf

	If ((spellIndex == -1 || spellIndex >= spellCount) && StorageUtil.FormListAdd(self, keyName, aSpell, false) != -1) || StorageUtil.FormListSet(self, keyName, spellIndex, aSpell)
		Log("BindSpellToKey ("+aSpell.GetName()+") = " + keyCode + " #" + keyIndex + ", position =" + spellIndex)
		return true
	EndIf

	Log("Critical Error in Spell Binding Data .. (keyCode="+keyCode+",keyIndex="+keyIndex+", position="+spellIndex+")", LogSeverity_Error)
	StorageUtil.ClearAllObjPrefix(self, KeyBindingIndexName)
	return false
	
EndFunction

bool Function UnbindKey(int keyCode, int spellIndex)
	int keyIndex = StorageUtil.IntListFind(self, KeyBindingIndexName, keyCode)
	If keyIndex != -1
		string keyName = GetKeyNameForIndex(keyIndex)
		int spellCount = StorageUtil.FormListCount(self, keyName)
		If spellCount > 1 && spellIndex != -1 && StorageUtil.FormListRemoveAt(self, keyName, spellIndex)
			return true
		ElseIf StorageUtil.IntListRemoveAt(self, KeyBindingIndexName, keyIndex) && StorageUtil.FormListClear(self, keyName)
			return true
		EndIf
	EndIf
	return false
EndFunction

Spell Function GetSpellByIndex(int keyIndex, int spellIndex)
	return StorageUtil.FormListGet(self, GetKeyNameForIndex(keyIndex), spellIndex) as Spell
EndFunction

Form[] Function GetSpellsByIndex(int keyIndex)
	return StorageUtil.FormListToArray(self, GetKeyNameForIndex(keyIndex))
EndFunction

int Function GetKeyCodeByIndex(int index)
	return StorageUtil.IntListGet(self, KeyBindingIndexName, index)
EndFunction

int Function GetIndexByKeyCode(int keyCode)
	return StorageUtil.IntListFind(self, KeyBindingIndexName, keyCode)
EndFunction

Form[] Function GetSpellsByKey(int keyCode)
	int keyIndex = GetIndexByKeyCode(keyCode)
	If keyIndex != -1
		return StorageUtil.FormListToArray(self, GetKeyNameForIndex(keyIndex))
	EndIf
	return Utility.CreateFormArray(0)
EndFunction

Spell Function GetSpellByKey(int keyCode, bool allowHostile = true, bool usePreviousCycleIndex = false)
	int keyIndex = StorageUtil.IntListFind(self, KeyBindingIndexName, keyCode)
	;Log("GetSpellByKey ("+keyCode+") => " + keyIndex)
	If keyIndex != -1
		string keyName = GetKeyNameForIndex(keyIndex)
		int cycleIndex = StorageUtil.GetIntValue(self, keyName, 0)
		int maxLength = StorageUtil.FormListCount(self, keyName)
		If cycleIndex >= maxLength || cycleIndex < 0
			cycleIndex = 0
		EndIf

		If usePreviousCycleIndex && cycleIndex == 0 && maxLength > 1
			cycleIndex = maxLength - 1
		ElseIf usePreviousCycleIndex && cycleIndex > 0
			cycleIndex -= 1
		EndIf

		Spell nextSpell = StorageUtil.FormListGet(self, keyName, cycleIndex) as Spell
		If allowHostile || !nextSpell.IsHostile()
			StorageUtil.SetIntValue(self, keyName, cycleIndex+1)
			return nextSpell
		EndIf
		;return StorageUtil.FormListGet(self, KeyBindingIndexName, keyIndex) as Spell
	EndIf
	return None
EndFunction

int Function ReverseCycleByKey(int keyCode)
	int keyIndex = StorageUtil.IntListFind(self, KeyBindingIndexName, keyCode)
	If keyIndex != -1
		return StorageUtil.AdjustIntValue(self, GetKeyNameForIndex(keyIndex), -1)
	EndIf
	return -1
EndFunction

Form[] Function GetAllMappedSpells()
	Form[] mappedSpells = new Form[128]
	int[] keys = StorageUtil.IntListToArray(self, KeyBindingIndexName)
	int idx = 0
	int mIdx = 0
	While idx < keys.length
		Form[] spells = StorageUtil.FormListToArray(self, GetKeyNameForIndex(idx))
		int sIdx = 0
		While sIdx < spells.Length
			mappedSpells[mIdx] = spells[sIdx]
			mIdx += 1
			sIdx += 1
		EndWhile
		idx += 1
	EndWhile
	return PapyrusUtil.SliceFormArray(mappedSpells, 0, mIdx)
	;return StorageUtil.FormListToArray(self, KeyBindingIndexName)
EndFunction

;/  ----
	UTILITY FUNCTIONS
/;

int Property CASTINGTYPE_CONSTANT = 0 Auto Hidden
int Property CASTINGTYPE_FIREANDFORGET = 1 Auto Hidden
int Property CASTINGTYPE_CONCENTRATION = 2 Auto Hidden

int Property DELIVERYTYPE_SELF = 0 Auto Hidden
int Property DELIVERYTYPE_CONTACT = 1 Auto Hidden
int Property DELIVERYTYPE_AIMED = 2 Auto Hidden
int Property DELIVERYTYPE_ACTOR = 3 Auto Hidden
int Property DELIVERYTYPE_LOCATION = 4 Auto Hidden

EffectShader Function GetEffectShaderForMGEF(MagicEffect mgef)
	string effectLookup = mgef.GetResistance()
	If effectLookup == ""
		effectLookup = mgef.GetAssociatedSkill()
	EndIf

	;Log("Effect ("+mgef.GetName()+") Lookup Data, Res="+mgef.GetResistance()+", Skill="+mgef.GetAssociatedSkill() + ", lookup = " + effectLookup)

	If effectLookup == "DamageResist"
		return EffectShaders.GetAt(1) as EffectShader
	ElseIf effectLookup == "MagicResist"
		return EffectShaders.GetAt(18) as EffectShader
	ElseIf effectLookup == "PoisonResist"
		return EffectShaders.GetAt(19) as EffectShader
	ElseIf effectLookup == "FireResist"
		return EffectShaders.GetAt(4) as EffectShader
	ElseIf effectLookup == "FrostResist"
		return EffectShaders.GetAt(6) as EffectShader
	ElseIf effectLookup == "ElectricResist"
		return EffectShaders.GetAt(9) as EffectShader
	ElseIf effectLookup == "Alteration"
		return EffectShaders.GetAt(20) as EffectShader
	ElseIf effectLookup == "Conjuration"
		return EffectShaders.GetAt(23) as EffectShader
	ElseIf effectLookup == "Destruction"
		return EffectShaders.GetAt(16) as EffectShader
	ElseIf effectLookup == "Illusion"
		return EffectShaders.GetAt(26) as EffectShader
	ElseIf effectLookup == "Restoration"
	EndIf

	return EffectShaders.GetAt(13) as EffectShader
EndFunction

int Property SOUNDEFFECT_CHARGE = 1 Auto Hidden
int Property SOUNDEFFECT_READY = 2 Auto Hidden
int Property SOUNDEFFECT_RELEASE = 3 Auto Hidden
int Property SOUNDEFFECT_CASTLOOP = 4 Auto Hidden

Sound Function GetSoundEffectFor(MagicEffect mgef, int soundEffectType)
	If PapyrusExtenderInstalled
		Sound chargeSound = (SoundEffects.GetAt(soundEffectType+2) as Sound)
		SoundDescriptor snd = PO3_SKSEfunctions.GetMagicEffectSound(mgef, soundEffectType)
		If snd != None
			PO3_SKSEfunctions.SetSoundDescriptor(chargeSound, snd)
			;Log("Found SND: " + snd + " returning in sound: " + chargeSound)
			return chargeSound
		EndIf
	EndIf

	If soundEffectType != 1
		return None
	EndIf

	string soundLookup = mgef.GetResistance()
	If soundLookup == "FireResist"
		return SoundEffects.GetAt(6) as Sound
	ElseIf soundLookup == "FrostResist"
		return SoundEffects.GetAt(5) as Sound
	EndIf

	soundLookup = mgef.GetAssociatedSkill()
	;Log("Sound ("+mgef.GetName()+") Lookup Data, Res="+mgef.GetResistance()+", Skill="+mgef.GetAssociatedSkill() + ", lookup = " + soundLookup)

	If soundLookup == "Alteration"
		return SoundEffects.GetAt(3) as Sound
	ElseIf soundLookup == "Conjuration"
		return SoundEffects.GetAt(4) as Sound
	ElseIf soundLookup == "Destruction"
		return SoundEffects.GetAt(6) as Sound
	ElseIf soundLookup == "Illusion"
		return SoundEffects.GetAt(7) as Sound
	ElseIf soundLookup == "Restoration"
		return SoundEffects.GetAt(8) as Sound
	EndIf

	return SoundEffects.GetAt(0) as Sound
EndFunction

float Function LatencyMaintenance(string keyName, int maxSize = 100, bool empty = false)
	int len = StorageUtil.FloatListCount(self, keyName)
	If len == 0
		len = 1
	EndIf

	float sum = GetFloatArraySum(StorageUtil.FloatListToArray(self, keyName))
	float average = sum / len
	If len >= maxSize
		If !empty
			StorageUtil.FloatListClear(self, keyName)
			StorageUtil.FloatListAdd(self, keyName, average)
		Else
			StorageUtil.FloatListClear(self, keyName)
		EndIf
	EndIf
	return average
EndFunction


Function ToggleSweepingPerk(bool isActive)
	If !isActive && PlayerRef.HasPerk(SweepingAttacks)
		PlayerRef.RemovePerk(SweepingAttacks)
	ElseIf isActive && !PlayerRef.HasPerk(SweepingAttacks)
		PlayerRef.AddPerk(SweepingAttacks)
	EndIf
EndFunction


;/  ----
	Global Event handling.
/;

; Event OnAnimationEvent(ObjectReference akSource, string asEventName)
; 	;DUMMY Log("OnAnimationEvent, " + akSource.GetName() + " => " + asEventName)
; EndEvent

float inputRegistrationTime
Event OnKeyDown(int keyCode)
	;Log("OnKeyDown="+keyCode + ", state=" + GetState())

	float inputRegistrated = Utility.GetCurrentRealTime()
	If StorageUtil.IntListFind(self, KeyBindingIndexName, keyCode) >= 0
		If GetState() != "Charging" && !Utility.IsInMenuMode()
			If isBusy
				Log("Attempted to start charging a spell but input isn't ready, aborting..", LogSeverity_Debug)
				return
			ElseIf Input.IsKeyPressed(DispelKeyModifier)
				Spell spellToRemove = GetSpellByKey(keyCode, true, true)
				PlayerRef.DispelSpell(spellToRemove)
				return
			ElseIf GetState() == "Charged" && chargedSpell == GetSpellByKey(keyCode)
				If !AutoCast(true)
					Log("Spell already charged!", LogSeverity_Debug)
				EndIf
				return
			EndIf

			chargeKeyCodeDown = keyCode
			inputRegistrationTime = inputRegistrated
			GoToState("Charging")
		EndIf
	EndIf
EndEvent

Event OnKeyUp(int keyCode, float holdTime)
EndEvent

bool isCasting
bool isSafetyRunning
Spell safetySpell
Event OnCastStart(Actor akCaster, Actor akTarget)
	;Log("OnCastStart()")
	isCasting = true
EndEvent

Event OnCastEnd(Actor akCaster, Actor akTarget)
	isCasting = false
EndEvent

Event OnWeaponUnequipped(Weapon unequipped)
	;Log("OnWeaponUnequipped: " + unequipped)
	ValidateEquipped()
EndEvent

Event OnWeaponEquipped(Weapon equipped)
	;Log("OnWeaponEquipped: " + equipped)
	ValidateEquipped()
EndEvent

Event OnSpellBookEquipped(Book equipped)
	Config.ResetSpellsCache()
	; If UI.IsMenuOpen("InventoryMenu")
	; 	RegisterForMenu("InventoryMenu")
	; Else
	; 	Config.BuildSpellCache()
	; EndIf
EndEvent

; Event OnMenuClose(string MenuName)
; 	UnregisterForMenu("InventoryMenu")
; 	Config.BuildSpellCache()
; EndEvent

bool Function IsEquippedValid()
	int leftType = PlayerRef.GetEquippedItemType(0)
	int rightType = PlayerRef.GetEquippedItemType(1)

	return validWeaponTypes.Find(leftType) != -1 || validWeaponTypes.Find(rightType) != -1
EndFunction

Function ValidateEquipped()
	bool isValid = IsEquippedValid()
	If isValid && GetState() == "Waiting"
		GoToState("Normal")
	ElseIf !isValid && GetState() != "Waiting"
		GoToState("Waiting")
	EndIf
EndFunction

;/  ----
	State: Normal (Default state)
/;

bool isBashing
int keyCodeInterruptCast
bool safetyEnabled
bool highLatency
State Normal
	Event OnBeginState()
		;Log("Normal: OnBeginState()")
		
		If chargedShader != None
			chargedShader.Stop(PlayerRef)
		EndIf

		If concentrationInstanceId != 0
			Sound.StopInstance(concentrationInstanceId)
			concentrationInstanceId = 0
		EndIf

		If readyInstanceId != 0
			Sound.StopInstance(readyInstanceId)
			readyInstanceId = 0
		EndIf

		float highestAvgLatency = MaxFloat(LatencyMaintenance(ChargedBeginLatencyName), LatencyMaintenance(ChargedDoneLatencyName)) * 1000
		If highestAvgLatency >= HighLatencyThreshold && !highLatency
			highLatency = true
			Log("High latency detected ("+highLatency+"), skipping all non-essentials!", LogSeverity_Debug)
		ElseIf highLatency && highestAvgLatency < HighLatencyThreshold - 25
			highLatency = false
			Log("Latency below threshold - 25, no longer skipping non-essentials..", LogSeverity_Debug)
		EndIf
	EndEvent
	Event OnAnimationEvent(ObjectReference akSource, string asEventName)
		;Log("Normal: OnAnimationEvent(), asEventName = " + asEventName)
	EndEvent

	Event OnEndState()
		;Log("Normal: OnEndState()")
	EndEvent
EndState

State Waiting
	Event OnBeginState()
		Log("Entering waiting state..")
	EndEvent
	Event OnKeyDown(int keyCode)
		If !Utility.IsInMenuMode()
			Log("Spell keybinds are disabled, waiting for valid equipped weapon(s).", LogSeverity_Warning)
		EndIf
	EndEvent
	Event OnEndState()
		Log("Exiting waiting state!")
	EndEvent
EndState

;/  ----
	State: CHARGING
	chargingInterval: Controls how fluid magicka is deducted while charging a spell
/;

float chargingInterval = 0.05

int chargeKeyCodeDown
Spell chargingSpell
float chargeTimeRequired
float chargingSpellCost
float chargingSpellCostPaid
float chargeStartTime
int chargingSpellCastingType
bool chargingSpellIsHostile
int chargingSpellTarget
bool chargingSuccess
int chargingSoundInstance
bool cancelIdle
int chargeMode
bool isBusy
bool weaponsDrawn
bool isBlocking
bool isAttacking
State Charging
	Event OnBeginState()
		;Log("Charging: OnBeginState(), chargeKeyCodeDown = " + chargeKeyCodeDown)
		isBusy = true
		chargingSuccess = false
		chargingSpell = GetSpellByKey(chargeKeyCodeDown)

		If chargingSpell == None
			Log("Couldn't find spell for keyCode = " + chargeKeyCodeDown, LogSeverity_Debug)
			GoToState("Normal")
			return
		EndIf

		chargingSpellIsHostile = chargingSpell.IsHostile()
		chargeStartTime = Utility.GetCurrentRealTime()

		chargingSpellTarget = StorageUtil.GetIntValue(chargingSpell, "WMAG_CACHE_TARGET", -1) as int
		chargingSpellCastingType = StorageUtil.GetIntValue(chargingSpell, "WMAG_CACHE_CASTINGTYPE", -1) as int

		MagicEffect mEffect = StorageUtil.GetFormValue(chargingSpell, "WMAG_CACHE_MAGEFFECT") as MagicEffect
		If mEffect == None
			int effectIndex = chargingSpell.GetCostliestEffectIndex()
			mEffect = chargingSpell.GetNthEffectMagicEffect(effectIndex)
			StorageUtil.SetFormValue(chargingSpell, "WMAG_CACHE_MAGEFFECT", mEffect)
		EndIf

		If chargingSpellCastingType == -1 || chargingSpellTarget == -1
			chargingSpellCastingType = mEffect.GetCastingType()
			chargingSpellTarget = mEffect.GetDeliveryType()

			StorageUtil.SetIntValue(chargingSpell, "WMAG_CACHE_CASTINGTYPE", chargingSpellCastingType)
			StorageUtil.SetIntValue(chargingSpell, "WMAG_CACHE_TARGET", chargingSpellTarget)
		EndIf

		bool isOffensiveSpell = chargingSpellIsHostile ;&& chargingSpellTarget == 0

		chargeMode = StorageUtil.GetIntValue(self, "WMAG_OVERRIDE_"+chargeKeyCodeDown+"_CHARGE", SpellChargeMode[isOffensiveSpell as int])
		chargedReleaseMode = StorageUtil.GetIntValue(self, "WMAG_OVERRIDE_"+chargeKeyCodeDown+"_RELEASE", SpellReleaseMode[isOffensiveSpell as int])

		;int deliveryType = m.GetDeliveryType()

		;Log("Spell ("+chargingSpell.GetName()+"): Type = " + chargingSpellCastingType + ", Target = " + chargingSpellTarget + " [Sounds] Charge = " + chargingSound + ", Ready = " + readySound)
		
		;Log(chargingSpell.GetName() + " casting type = " + chargingSpellCastingType)

		If chargingSpellCastingType != CASTINGTYPE_CONCENTRATION
			float effectiveCost = chargingSpell.GetEffectiveMagickaCost(PlayerRef)
			float castTime = chargingSpell.GetCastTime()

			If chargeMode == SPELLCHARGE_SPELLBASED
				chargeTimeRequired = castTime
			ElseIf chargeMode == SPELLCHARGE_MAXMAGIC
				float minChargeTime = MinimumChargeTime[isOffensiveSpell as int]
				float maxChargeTime = MaximumChargeTime[isOffensiveSpell as int]

				float maxMagicka = PlayerRef.GetBaseActorValue("Magicka")
				chargeTimeRequired = MaxFloat(maxChargeTime * MinFloat(effectiveCost / maxMagicka, 1.0), minChargeTime)
			Else
				chargeTimeRequired = 0
			EndIf

			;Log("Spell cast time = " + castTime + ", charge time set to = " + chargeTimeRequired)

			chargingSpellCost = effectiveCost			
		Else
			chargeTimeRequired = 0
			chargingSpellCost = 0
		EndIf

		inputRegistrationTime += chargeTimeRequired

		If chargingSpellCost > PlayerRef.GetActorValue("Magicka")
			;Log("Insufficient magicka to charge spell: " + chargingSpell.GetName() + ", required magicka = " + chargingSpellCost, LogSeverity_Info)
			Log("You don't have enough magicka to charge " + chargingSpell.GetName(), LogLevel_Notification)
			UI.Invoke("HUD Menu", "_root.HUDMovieBaseInstance.StartMagickaBlinking")
			;UI.InvokeString("HUD Menu", "_root.HUDMovieBaseInstance.ShowSubtitle", "Not enough magicka")
			GoToState("Normal")
			return
		EndIf

		If !PlayerRef.IsWeaponDrawn()
			float elapsed = 0
			weaponsDrawn = false
			RegisterForAnimationEvent(PlayerRef, "tailCombatState")
			PlayerRef.DrawWeapon()
			While !weaponsDrawn && elapsed < 2
				elapsed += 0.1
				Utility.Wait(0.1)
			EndWhile
			UnregisterForAnimationEvent(PlayerRef, "tailCombatState")
			inputRegistrationTime += elapsed
		EndIf

		If chargeTimeRequired > 0
			If !SkipNonEssentialsForPerformance || !highLatency
				Sound chargingSound = GetSoundEffectFor(mEffect, SOUNDEFFECT_CHARGE)
				If !isBlocking && !DisableChargeAnimation
					Debug.SendAnimationEvent(PlayerRef, "IdleCombatWeaponCheckStart")
					cancelIdle = true
				EndIf

				
				If chargingSound != None
					chargingSoundInstance = chargingSound.Play(PlayerRef)
					Sound.SetInstanceVolume(chargingSoundInstance, 100)
				EndIf
			EndIf

			OnUpdate()
			;; Take magicka gradually over time as we charge spell.
		Else
			;; Take Magicka instantly.
			If chargingSpellCostPaid < chargingSpellCost
				float ownedMagicka = chargingSpellCost-chargingSpellCostPaid
				PlayerRef.DamageActorValue("Magicka", ownedMagicka)
				chargingSpellCostPaid += ownedMagicka
			EndIf
			SetCharged(true)
		EndIf
	EndEvent

	Event OnUpdate()
		float timeSpent = Utility.GetCurrentRealTime() - chargeStartTime
		If !Input.IsKeyPressed(chargeKeyCodeDown)
			return
		EndIf
		;Log("Time Spent Charging = " + timeSpent + ", vs chargeTimeRequired = " + chargeTimeRequired)
		
		If chargingSpellCostPaid < chargingSpellCost
			If timeSpent > chargeTimeRequired
				inputRegistrationTime += (timeSpent - chargeTimeRequired)
				timeSpent = chargeTimeRequired
			EndIf

			float deduction = (chargingSpellCost * (timeSpent / chargeTimeRequired)) - chargingSpellCostPaid ;chargingSpellCost / (chargeTimeRequired / chargingInterval)
			PlayerRef.DamageActorValue("Magicka", deduction)
			chargingSpellCostPaid += deduction
			;Log("Magicka reduced by " + deduction + ", total deduction = " + chargingSpellCostPaid + ", current magicka = " + PlayerRef.GetActorValue("Magicka"))
		EndIf

		If (timeSpent >= chargeTimeRequired)
			SetCharged(true)
		ElseIf GetState() == "Charging"
			RegisterForSingleUpdate(chargingInterval)
		EndIf
	EndEvent

	Event OnKeyUp(int keyCode, float holdTime)
		;Log("Charging: OnKeyUp=" + keyCode + ", chargeTimeRequired="+chargeTimeRequired)
		If keyCode == chargeKeyCodeDown && chargeTimeRequired > 0
			UnregisterForUpdate()

			float timeSpent = Utility.GetCurrentRealTime() - chargeStartTime
			
			float remainingCost = chargingSpellCost - chargingSpellCostPaid
			chargingSuccess = (chargeMode == SPELLCHARGE_NONE || timeSpent >= chargeTimeRequired) && remainingCost < PlayerRef.GetActorValue("Magicka")
			If (chargingSuccess && chargingSpellCostPaid < chargingSpellCost)
				PlayerRef.DamageActorValue("Magicka", remainingCost)
				chargingSpellCostPaid += remainingCost
			EndIf
			SetCharged(chargingSuccess)
		EndIf
	EndEvent

	Function SetCharged(bool isChargeSuccess)
		chargingSuccess = isChargeSuccess
		If isChargeSuccess
			If Input.IsKeyPressed(chargeKeyCodeDown) || chargedReleaseMode == RELEASEMODE_KEYUP 
				keyCodeInterruptCast = chargeKeyCodeDown
			EndIf

			spellCastingType = chargingSpellCastingType
			spellTarget = chargingSpellTarget
			spellIsHostile = chargingSpellIsHostile
			chargedSpell = chargingSpell

			;Log("SetCharged = true -> goto Charged")
			GoToState("Charged")
		Else
			;Log("SetCharged = false -> goto Normal")
			GoToState("Normal")
		EndIf
	EndFunction

	Event OnKeyDown(int keyCode)
		; We're not registering any inputs while charging, gotta cancel charging first.
	EndEvent

	Event OnAnimationEvent(ObjectReference akSource, string asEventName)
		If asEventName == "staggerStart"
			UnregisterForUpdate()
			GoToState("Normal")
		ElseIf asEventName == "tailCombatState"
			weaponsDrawn = true
		EndIf
	EndEvent

	Event OnEndState()
		;Log("Charging: OnEndState(), chargingSuccess = " + chargingSuccess + ", next state = " + GetState())
		If cancelIdle
			PlayerRef.PlayIdle(IdleStop_Loose)
		EndIf

		If chargingSoundInstance != 0
			Sound.StopInstance(chargingSoundInstance)
		EndIf

		If !chargingSuccess
			Sound soundChargeFailure = SoundEffects.GetAt(2) as Sound
			int failureInstanceId = soundChargeFailure.Play(PlayerRef)
			Sound.SetInstanceVolume(failureInstanceId, 1.0)
			ReverseCycleByKey(chargeKeyCodeDown)

			If chargingSpellCostPaid > 0
				PlayerRef.RestoreActorValue("Magicka", chargingSpellCostPaid)
			EndIf
		EndIf

		chargeKeyCodeDown = 0
		chargingSpellCostPaid = 0
		chargingSpellCost = -1
		chargeTimeRequired = -1
		chargeMode = -1
		cancelIdle = false

		If !chargingSuccess
			isBusy = false
		EndIf

		chargingSuccess = false
	EndEvent
EndState

Spell chargedSpell
bool spellIsHostile
int spellTarget
int spellCastingType
Sound releaseSound
Sound concentrationSound
int concentrationInstanceId
int readyInstanceId
bool isCharged
int chargedReleaseMode
int chargedState
EffectShader chargedShader
Sound readySound
State Charged
	Event OnBeginState()
		isCharged = true
		;Log("Charged["+chargedState+"]: OnBeginState(), spellIsHostile = " + spellIsHostile + ", spellTarget = " + spellTarget)
		chargedState = 1
		If inputRegistrationTime > 0
			StorageUtil.FloatListAdd(self, ChargedBeginLatencyName, Utility.GetCurrentRealTime() - inputRegistrationTime)
			inputRegistrationTime = 0
		EndIf

		float chargedBeginTime = Utility.GetCurrentRealTime()

		If readyInstanceId != 0
			Sound.StopInstance(readyInstanceId)
			readyInstanceId = 0
		EndIf

		If chargedSpell == None
			Log("Charged["+chargedState+"]: OnBeginState() chargedSpell == None. Abort", LogSeverity_Debug)
			chargedState = -1
			GoToState("Normal")
			return
		EndIf

		MagicEffect mEffect = StorageUtil.GetFormValue(chargedSpell, "WMAG_CACHE_MAGEFFECT") as MagicEffect
		If mEffect == None
			int effectIndex = chargedSpell.GetCostliestEffectIndex()
			mEffect = chargedSpell.GetNthEffectMagicEffect(effectIndex)
			StorageUtil.SetFormValue(chargedSpell, "WMAG_CACHE_MAGEFFECT", mEffect)
		EndIf

		If !SkipNonEssentialsForPerformance || !highLatency
			chargedShader = StorageUtil.GetFormValue(chargedSpell, "WMAG_CACHE_SHADER") as EffectShader
			If chargedShader == None
				chargedShader = GetEffectShaderForMGEF(mEffect)
				StorageUtil.SetFormValue(chargedSpell, "WMAG_CACHE_SHADER", chargedShader)
			EndIf

			If chargedShader != None
				chargedShader.Play(PlayerRef)
			EndIf

			readySound = GetSoundEffectFor(mEffect, SOUNDEFFECT_READY)
			If readySound != None
				readyInstanceId = readySound.Play(PlayerRef)
				Sound.SetInstanceVolume(readyInstanceId, 1.0)
			EndIf

			releaseSound = GetSoundEffectFor(mEffect, SOUNDEFFECT_RELEASE)
			concentrationSound = GetSoundEffectFor(mEffect, SOUNDEFFECT_CASTLOOP)
		EndIf

		float chargedDoneTime = Utility.GetCurrentRealTime()

		chargedState = 2
		AutoCast()
		isBusy = false

		StorageUtil.FloatListAdd(self, ChargedDoneLatencyName, chargedDoneTime - chargedBeginTime)
	EndEvent

	bool Function AutoCast(bool ignoreHoldingKey = false)
		bool isDefensiveSpell = !spellIsHostile ;&& spellTarget == 0
		bool autoCast = chargedReleaseMode == RELEASEMODE_AUTOMATIC || (chargedReleaseMode == RELEASEMODE_KEYUP && (!Input.IsKeyPressed(keyCodeInterruptCast) || ignoreHoldingKey))
		If (spellCastingType == CASTINGTYPE_CONCENTRATION && chargedReleaseMode != RELEASEMODE_MANUAL) || autoCast
			If !isDefensiveSpell ;&& !isAttacking
				isAttacking = true
				Debug.SendAnimationEvent(PlayerRef, "attackStart")
				return true
			ElseIf isDefensiveSpell ;&& !isBlocking
				If !PlayerRef.GetAnimationVariableBool("IsBlocking")
					isBlocking = true
					Debug.SendAnimationEvent(PlayerRef, "blockStart")
					return true
				Else
					CastSpell()
					return true
				EndIf
			EndIf
		ElseIf PlayerRef.GetAnimationVariableBool("IsBlocking") && isDefensiveSpell
			CastSpell()
			return true
		EndIf
		return false
	EndFunction

	Event OnAnimationEvent(ObjectReference akSource, string asEventName)
		;Log("Charged["+chargedState+"]: OnAnimationEvent(akSource = " + akSource + ", asEventName = " + asEventName)
		If spellIsHostile ;|| spellTarget != 0
			If asEventName == "HitFrame"
				CastSpell()
			ElseIf asEventName == "attackStop"
				isAttacking = false
				If spellCastingType == CASTINGTYPE_CONCENTRATION && isCharged
					;Log("Charged["+chargedState+"]: OnAnimationEvent() - attackStop => Is Concentration. Go to Normal")
					GoToState("Normal")
				EndIf
			; ElseIf asEventName == "attackStart" || asEventName == "weaponSwing"
			; 	isAttacking = true
			EndIf
		Else
			If asEventName == "blockStart" || asEventName == "blockStartOut"
				;isBlocking = true
				CastSpell()
			ElseIf asEventName == "blockStop"
				isBlocking = false
				; If spellCastingType == CASTINGTYPE_CONCENTRATION && GetState() == "Charged" ;|| (keyCodeInterruptCast != -1 && !Input.IsKeyPressed(keyCodeInterruptCast))
				; 	Log("Charged["+chargedState+"]: OnAnimationEvent() - blockStop => Is Concentration. Go to Normal")
				; 	GoToState("Normal")
				; EndIf
			EndIf
		EndIf
	EndEvent

	Event OnKeyUp(int keyCode, float holdTime)
		;Log("Charged["+chargedState+"]: OnKeyUp() spellIsHostile="+spellIsHostile+", spellTarget="+spellTarget)
		If keyCode == keyCodeInterruptCast && chargedReleaseMode != RELEASEMODE_MANUAL
			If chargedReleaseMode == RELEASEMODE_KEYUP && spellCastingType != CASTINGTYPE_CONCENTRATION
				bool isDefensiveSpell = !spellIsHostile ;&& spellTarget == 0
				If !isAttacking && !isDefensiveSpell
					isAttacking = true
					Debug.SendAnimationEvent(PlayerRef, "attackStart")
				ElseIf !isBlocking && isDefensiveSpell
					isBlocking = true
					Debug.SendAnimationEvent(PlayerRef, "blockStart")
				EndIf
			ElseIf spellCastingType == CASTINGTYPE_CONCENTRATION && isCharged
				;Log("Charged["+chargedState+"]: OnKeyUp() - keyCode == keyCodeInterruptCast AND Is Concentration. Go to Normal")
				GoToState("Normal")
			ElseIf isBlocking
				Debug.SendAnimationEvent(PlayerRef, "blockStop")
			EndIf
		EndIf
	EndEvent

	Function CastSpell()
		chargedState = 3
		;Log("Charged["+chargedState+"]: CastSpell()")
		If readyInstanceId != 0
			Sound.StopInstance(readyInstanceId)
			readyInstanceId = 0
		EndIf

		Spell spellToCast = chargedSpell
		If spellToCast == None
			Log("Charged["+chargedState+"]: CastSpell() chargedSpell == None. Abort.")
			chargedState = 4
			GoToState("Normal")
			Return
		EndIf

		If releaseSound != None && spellCastingType != CASTINGTYPE_CONCENTRATION
			int releaseInstanceId = releaseSound.Play(PlayerRef)
			Sound.SetInstanceVolume(releaseInstanceId, 1.0)
			Sound.StopInstance(releaseInstanceId)
		EndIf

		If MaximumDurationModifier > 0 && spellTarget == DELIVERYTYPE_SELF && spellCastingType == CASTINGTYPE_FIREANDFORGET
			int eIdx = spellToCast.GetCostliestEffectIndex()
			MagicEffect ef = spellToCast.GetNthEffectMagicEffect(eIdx)
			int duration = spellToCast.GetNthEffectDuration(eIdx)

			If PlayerRef.HasMagicEffect(ef) && duration > 0
				int modCount = StorageUtil.AdjustIntValue(spellToCast, "WMAG_MODCOUNT", 1)
				float modAmount = MaximumDurationModifier * (modCount as float / (modCount as float + 0.75))

				;Log("Charging: Modding (#"+modCount+") duration ("+duration+") on charged spell: " + chargingSpell.GetName() + "x" + modAmount, LogSeverity_Debug)
				ModSpellsDuration.AddForm(spellToCast)
				PlayerRef.SetActorValue("Variable05", modAmount)

				Log(chargingSpell.GetName() + " duration X" + modAmount, LogLevel_Notification)
			Else
				StorageUtil.UnsetIntValue(spellToCast, "WMAG_MODCOUNT")
			EndIf
		EndIf

		chargedState = 4

		spellToCast.Cast(PlayerRef)

		If spellCastingType == CASTINGTYPE_CONCENTRATION
			If concentrationSound != None && concentrationInstanceId == 0
				concentrationInstanceId = concentrationSound.Play(PlayerRef)
			EndIf

			OnUpdate()
		Else
			If (keyCodeInterruptCast != 0 && !Input.IsKeyPressed(keyCodeInterruptCast)) || chargedReleaseMode == RELEASEMODE_KEYUP
				;Log("Charged["+chargedState+"]: CastSpell() keyCodeInterruptCast != 0 AND Not Pressed OR ReleaseMode = KEYUP. Go to Normal")
				GoToState("Normal")
			Else
				chargedSpell = None
				If concentrationInstanceId != 0
					Sound.StopInstance(concentrationInstanceId)
					concentrationInstanceId = 0
				EndIf

				If readyInstanceId != 0
					Sound.StopInstance(readyInstanceId)
					readyInstanceId = 0
				EndIf

				If chargedShader != None
					chargedShader.Stop(PlayerRef)
					chargedShader = None
				EndIf
			EndIf

			If isBlocking
				Debug.SendAnimationEvent(PlayerRef, "blockStop")
				isBlocking = false
			EndIf
		EndIf

		
	EndFunction

	Event OnUpdate()
		;Log("Charged["+chargedState+"]: OnUpdate(), Conc Casting Fix=" + Config.ConcentrationCastingFix + ", chargedSpell="+chargedSpell+", castingType="+spellCastingType+", spellTarget="+spellTarget+", ReleaseMode="+chargedReleaseMode)
		Spell spellToCast = chargedSpell
		If spellToCast != None && spellCastingType == CASTINGTYPE_CONCENTRATION
			If !Input.IsKeyPressed(keyCodeInterruptCast) && chargedReleaseMode != RELEASEMODE_MANUAL && isCharged
				;Log("Charged["+chargedState+"]: OnUpdate() keyCodeInterruptCast != 0 AND Not Pressed AND ReleaseMode != MANUAL. Go to Normal")
				GoToState("Normal")
				return
			EndIf

			bool attackBound = spellIsHostile ;|| spellTarget != 0
			If attackBound && chargedReleaseMode != RELEASEMODE_MANUAL
				Debug.SendAnimationEvent(PlayerRef, "attackStart")
			EndIf

			If !attackBound && !PlayerRef.GetAnimationVariableBool("IsBlocking") && isCharged
				;Log("Charged["+chargedState+"]: OnUpdate() Not Blocking. Go to Normal")
				GoToState("Normal")
				return
			EndIf

			;Log("Charged: OnUpdate() -> RegisterForSingleUpdate")
			RegisterForSingleUpdate(0.25)

			If ConcentrationCastingFix && !attackBound
				If !safetyEnabled
					safetyEnabled = true
					;Log("Charged: OnUpdate() Safety Initiated.. State = " + GetState())
					While GetState() == "Charged" && isCharged && safetyEnabled
						;Log("Charged: OnUpdate() Safety -> Cast Spell = " + chargedSpell)
						spellToCast.Cast(PlayerRef)
						Utility.Wait(0.1)
					EndWhile
					safetyEnabled = false
				EndIf
			Else
				spellToCast.Cast(PlayerRef)
			EndIf
		EndIf
	EndEvent

	Event OnEndState()
		isCharged = false
		;Log("Charged["+chargedState+"]: OnEndState(), concentrationInstanceId = " + concentrationInstanceId)

		If chargedState == -1
			return
		EndIf

		isBusy = true

		If MaximumDurationModifier > 0
			ModSpellsDuration.Revert()
			ModSpellsMagnitude.Revert()
		EndIf

		float timeout = 0.35
		While timeout > 0.0 && (chargedState != 2 && chargedState != 4)
			Utility.Wait(0.01)
			timeout -= 0.01
		EndWhile

		If chargedState != 2 && chargedState != 4
			Log("Charged: OnEndState() finalizing while chargedState="+chargedState+", this could be an issue...", LogSeverity_Debug)
		EndIf

		chargedState *= 2

		If isBlocking
			Debug.SendAnimationEvent(PlayerRef, "blockStop")
			isBlocking = false
		EndIf

		If isAttacking
			Debug.SendAnimationEvent(PlayerRef, "attackStop")
			isAttacking = false
		EndIf

		If spellCastingType == CASTINGTYPE_CONCENTRATION
			PlayerRef.InterruptCast()
		EndIf

		If readyInstanceId != 0
			Sound.StopInstance(readyInstanceId)
			readyInstanceId = 0
		EndIf

		If chargedShader != None
			chargedShader.Stop(PlayerRef)
		EndIf

		If concentrationInstanceId != 0
			Sound.StopInstance(concentrationInstanceId)
			concentrationInstanceId = 0
		EndIf

		safetyEnabled = false
		chargedSpell = None
		keyCodeInterruptCast = -1
		chargedState = 0
		isBusy = false
	EndEvent
EndState



State Disabled
EndState

; Dummy functions.

bool Function PrepareSpellForCasting(bool isOffensive, Spell spellToCast, int spellToCastType)
	 return false
EndFunction

Function CastSpell()
EndFunction

bool Function AutoCast(bool ignoreHoldingKey = false)
	return false
EndFunction

Function SetCharged(bool isChargeSuccess)
EndFunction

;/  ----
	LOGGING
/;

int Property LogLevel_None = 0 AutoReadOnly Hidden
int Property LogLevel_Disk = 1 AutoReadOnly Hidden
int Property LogLevel_Console = 2 AutoReadOnly Hidden
int Property LogLevel_Notification = 3 AutoReadOnly Hidden
int Property LogLevel_MessageBox = 4 AutoReadOnly Hidden

int Property LogSeverity_Debug = 1 AutoReadOnly Hidden
int Property LogSeverity_Info = 2 AutoReadOnly Hidden
int Property LogSeverity_Warning = 3 AutoReadOnly Hidden
int Property LogSeverity_Error = 4 AutoReadOnly Hidden


string Property LogPrefix = "[WMAG]" Auto
Function Log(string messageToLog, int severity = 0, string additionalPrefix = "")
	messageToLog = LogPrefix + additionalPrefix + ": " + messageToLog
	int selectedLogLevel = Max(LogLevel, severity)
	If selectedLogLevel == 0
		return
	EndIf

	If selectedLogLevel >= 1
		Debug.Trace(messageToLog, Max(0, severity - 2))
	EndIf
	If selectedLogLevel >= 2
		MiscUtil.PrintConsole(messageToLog)
	EndIf
	If selectedLogLevel >= 3
		Debug.Notification(messageToLog)
	EndIf
	If selectedLogLevel >= 4
		Debug.MessageBox(messageToLog)
	EndIf
EndFunction