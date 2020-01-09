Scriptname wmag_IsCasting extends ActiveMagicEffect

wmag_Main Property Main Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Main.OnCastStart(akCaster, akTarget)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	Main.OnCastEnd(akCaster, akTarget)
EndEvent