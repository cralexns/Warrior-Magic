Scriptname wmag_TriggerBindSpell extends ActiveMagicEffect

wmag_Player Property PlayerAlias Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	; Debug.Trace("wmag_TriggerBindSpell: OnEffectStart")
	PlayerAlias.StartBinding()
EndEvent