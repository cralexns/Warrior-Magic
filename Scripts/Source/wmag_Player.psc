Scriptname wmag_Player extends ReferenceAlias
import zen_Util

wmag_Main Property Main Auto
Actor Property PlayerRef Auto

Message Property HelpMessage Auto
bool Property HideHint Auto

float Property DefaultGravityMultHavok Auto
string Property GravityMultIniName = "fInAirFallingCharGravityMult:Havok" Auto

Event OnInit()
	;Main = wmag_Main.Current()
	;PlayerRef = self.GetActorReference()

	DefaultGravityMultHavok = Utility.GetINIFloat(GravityMultIniName)

	If PlayerRef
		RegisterEvents()
		RegisterAttackKeys()
	EndIf
EndEvent

Event OnPlayerLoadGame()
	Main.OnPlayerLoadGame()
	;PlayerRef = self.GetActorReference()
	RegisterEvents()
	RegisterAttackKeys()
EndEvent

int leftAttackKey
int rightAttackKey
Function RegisterAttackKeys()
	leftAttackKey = Input.GetMappedKey("Left Attack/Block")
	rightAttackKey = Input.GetMappedKey("Right Attack/Block")
EndFunction

Function RegisterEvents()
	RegisterForAnimationEvent(PlayerRef, "JumpUp")
	; RegisterForAnimationEvent(PlayerRef, "JumpDown")
	; RegisterForAnimationEvent(PlayerRef, "PowerAttack_Start_end")
	RegisterForAnimationEvent(PlayerRef, "blockStop")
	RegisterForAnimationEvent(PlayerRef, "attackStop")
	RegisterForAnimationEvent(PlayerRef, "preHitFrame")
	RegisterForAnimationEvent(PlayerRef, "HitFrame")
EndFunction

Event OnKeyDown(int keyCode)
	;DUMMY
EndEvent

State Jumping
	Event OnBeginState()
		;Main.Log("Jumping: OnBeginState()")
		RegisterForKey(leftAttackKey)
		RegisterForKey(rightAttackKey)

		int idx = 0
		While idx < StorageUtil.IntListCount(Main, Main.KeyBindingIndexName)
			int keyCode = StorageUtil.IntListGet(Main, Main.KeyBindingIndexName, idx)
			RegisterForKey(keyCode)
			idx += 1
		EndWhile
	EndEvent

	Event OnKeyDown(int keyCode)
		;If keyCode == leftAttackKey || keyCode == rightAttackKey
			If PlayerRef.GetAnimationVariableBool("bInJumpState")
				Debug.SendAnimationEvent(PlayerRef, "JumpLandEnd")
				PlayerRef.SetAnimationVariableBool("bInJumpState", false)
			EndIf
		;EndIf
	EndEvent

	Event OnAnimationEvent(ObjectReference akSource, string asEventName)
		;Main.Log("OnAnimationEvent: " + asEventName)
		If asEventName == "preHitFrame"
			Utility.SetINIFloat(GravityMultIniName, 0.0)
		; ElseIf asEventName == "weaponSwing" || asEventName == "weaponLeftSwing"
		; 	Utility.SetINIFloat(GravityMultIniName, 0.5)
		ElseIf asEventName == "HitFrame" || asEventName == "JumpDown" || asEventName == "blockStop" || asEventName == "attackStop"
			GoToState("")
		EndIf
	EndEvent

	Event OnEndState()
		;Main.Log("Jumping: OnEndState()")
		Utility.SetINIFloat(GravityMultIniName, DefaultGravityMultHavok)
		UnregisterForAllKeys()
		RegisterAttackKeys()
	EndEvent
EndState

Function StartBinding()
	Main.Log("StartBinding()")
	If GetState() != "Binding"
		GoToState("Binding")
	EndIf
EndFunction

Form equippedLeft
Form equippedRight
int bindingStage
Form equippedObject
bool magicMenuOpen
State Binding
	Event OnBeginState()
		Main.Log("Binding:OnBeginState()")
		equippedLeft = PlayerRef.GetEquippedObject(0)
		equippedRight = PlayerRef.GetEquippedObject(1)
		bindingStage = 0

		RegisterForMenu("MagicMenu")

		int quickMagicKey = Input.GetMappedKey("Quick Magic")
		Input.TapKey(quickMagicKey)

		If !UI.IsMenuOpen("MagicMenu")
			Main.Log("Open the spell menu!", Main.LogLevel_Notification)
		EndIf

		int choice = HelpMessage.Show()
		If choice == 2
			; Abort
			GoToState("")
		ElseIf choice == 1
			; Hide hint
			HideHint = true
		EndIf
	EndEvent

	Event OnMenuOpen(string menuName)
		Main.Log("Binding:OnMenuOpen()")
		If menuName == "MagicMenu"
			magicMenuOpen = true
		EndIf
	EndEvent

	Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
		Main.Log("Equipped object = " + akBaseObject.GetName())
		If magicMenuOpen && bindingStage == 0 && akBaseObject as Spell != None
			bindingStage = 1
			equippedObject = akBaseObject
			Main.Log("Selected object = " + equippedObject)

			Utility.WaitMenuMode(0.5)

			float timeout = 10
			float interval = 0.1

			int pressedKeyCode = Input.GetNthKeyPressed(0)
			While pressedKeyCode < 0 && timeout > 0
				Utility.WaitMenuMode(interval)
				pressedKeyCode = Input.GetNthKeyPressed(0)
				timeout -= interval
			EndWhile

			If pressedKeyCode != -1
				string keyName = Input.GetMappedControl(pressedKeyCode)

				Main.Log("Pressed key = " + keyName + " (" + pressedKeyCode + ")", Main.LogSeverity_Debug)

				int spellIndex = -1
				int keyIndex = Main.GetIndexByKeyCode(pressedKeyCode)
				If keyIndex != -1 && Main.GetSpellsByIndex(keyIndex).length == 1
					spellIndex = 0
				EndIf
				
				If Main.BindSpellToKey(pressedKeyCode, akBaseObject as Spell, spellIndex)
					Main.Log("Bound '"+keyName+"' ("+pressedKeyCode+") to spell: " + akBaseObject.GetName(), Main.LogSeverity_Info)
				Else
					Main.Log("Failed to bind spell to key.", Main.LogSeverity_Warning)
				EndIf
			Else
				Main.Log("Binding timed out..")
			EndIf

			GoToState("")
		EndIf
	EndEvent

	; Event OnMenuClose(string menuName)
	; 	Main.Log("Binding:OnMenuClose()")
	; 	If menuName == "MagicMenu"
	; 		magicMenuOpen = false
	; 	EndIf
	; 	GoToState("")
	; EndEvent

	Event OnEndState()
		Main.Log("Binding:OnEndState()")
		If UI.IsMenuOpen("MagicMenu")
			int escapeKey = Input.GetMappedKey("Escape")
			Input.TapKey(escapeKey)

			Game.DisablePlayerControls(false, false, false, false, false, true, false, false)
			Game.EnablePlayerControls(false, false, false, false, false, true, false, false)
		EndIf

		; Main.Log(PlayerRef.GetEquippedObject(0) + " vs " + equippedLeft)
		If PlayerRef.GetEquippedObject(0) != equippedLeft
			Main.Log("Re-equipping left hand..")
			PlayerRef.EquipItemEx(equippedLeft, 2, false, false)
		EndIf
		Utility.WaitMenuMode(0.1)

		; Main.Log(PlayerRef.GetEquippedObject(1) + " vs " + equippedRight)
		If PlayerRef.GetEquippedObject(1) != equippedRight
			Main.Log("Re-equipping right hand..")
			PlayerRef.EquipItemEx(equippedRight, 1, false, false)
		EndIf
	EndEvent
EndState

Event OnAnimationEvent(ObjectReference akSource, string asEventName)
	;Main.Log("OnAnimationEvent: " + asEventName)
	If asEventName == "JumpUp" && Main.Config.EnableJumpAttackHack
		GoToState("Jumping")
	EndIf

	; If asEventName == "weaponDraw" && LeftHand == None && RightHand == None
	; 	LeftHand = PlayerRef.GetEquippedWeapon(true)
	; 	RightHand = PlayerRef.GetEquippedWeapon(false)
	; ElseIf asEventName == "weaponSheathe"
	; 	LeftHand = None
	; 	RightHand = None
	; EndIf
EndEvent

Event OnObjectUnEquipped(Form akBaseObject, ObjectReference akReference)
	;Main.Log("OnObjectUnEquipped = " + akBaseObject.GetName() + ", " + akBaseObject.GetType() + " - akReference="+akReference)
	Weapon w = akBaseObject as Weapon
	If w != None
		Main.OnWeaponUnequipped(w)
	EndIf
EndEvent

Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
	;Main.Log("OnObjectEquipped = " + akBaseObject.GetName() + ", " + akBaseObject.GetType() + " - akReference="+akReference)
	Weapon w = akBaseObject as Weapon
	If w != None
		Main.OnWeaponEquipped(w)
		return
	EndIf

	Book b = akBaseObject as Book
	If b != None && b.GetSpell() != None
		Main.OnSpellBookEquipped(b)
	EndIf
EndEvent