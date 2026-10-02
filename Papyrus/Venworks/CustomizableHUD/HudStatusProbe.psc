ScriptName Venworks:CustomizableHUD:HudStatusProbe Hidden

; Playtest probe. One ability or potion per generic class.
; The watch log then shows which of those PersonalEffectsData actually records.
; Console: cgf "Venworks:CustomizableHUD:HudStatusProbe.ApplyGenericSet"
; Clear:   cgf "Venworks:CustomizableHUD:HudStatusProbe.ClearGenericSet"
Function ApplyGenericSet() Global
  Actor player = Game.GetPlayer()
  If (player == None)
    Debug.Trace("VWHUD STATUS PROBE | Apply | Player=None")
    Return
  EndIf
  AddAbility(player, 0x313252, "Malnourished")
  AddAbility(player, 0x313259, "Dehydrated")
  AddAbility(player, 0x2BDD19, "Thermal")
  AddAbility(player, 0x2BDD1F, "Cold")
  AddAbility(player, 0x2BDD25, "Poison")
  AddAbility(player, 0x2BDD27, "Radiation")
  AddAbility(player, 0x03859E, "Bleeding")
  AddAbility(player, 0x2BDD13, "Infection")
  AddAbility(player, 0x2BDD23, "Injury")
  CastSpellOnPlayer(player, 0x05C528, "Well Rested")
  UsePotion(player, 0x313281, "Fed")
  UsePotion(player, 0x2EE98F, "Hydrated")
  Debug.Trace("VWHUD STATUS PROBE | Apply | Done")
EndFunction

; Removes the ability spells and dispels Well Rested. Fed and Hydrated are consumed potions and wear off on their own.
Function ClearGenericSet() Global
  Actor player = Game.GetPlayer()
  If (player == None)
    Debug.Trace("VWHUD STATUS PROBE | Clear | Player=None")
    Return
  EndIf
  RemoveAbility(player, 0x313252, "Malnourished")
  RemoveAbility(player, 0x313259, "Dehydrated")
  RemoveAbility(player, 0x2BDD19, "Thermal")
  RemoveAbility(player, 0x2BDD1F, "Cold")
  RemoveAbility(player, 0x2BDD25, "Poison")
  RemoveAbility(player, 0x2BDD27, "Radiation")
  RemoveAbility(player, 0x03859E, "Bleeding")
  RemoveAbility(player, 0x2BDD13, "Infection")
  RemoveAbility(player, 0x2BDD23, "Injury")
  DispelNamedSpell(player, 0x05C528, "Well Rested")
  Debug.Trace("VWHUD STATUS PROBE | Clear | Done | Fed and Hydrated potions wear off on their own")
EndFunction

Function AddAbility(Actor player, Int formId, String label) Global
  Spell ability = Game.GetFormFromFile(formId, "Starfield.esm") as Spell
  If (ability == None)
    Debug.Trace("VWHUD STATUS PROBE | AddSpell | Missing | " + label)
    Return
  EndIf
  Bool added = player.AddSpell(ability, False)
  Debug.Trace("VWHUD STATUS PROBE | AddSpell | " + label + " | Added=" + added)
EndFunction

Function RemoveAbility(Actor player, Int formId, String label) Global
  Spell ability = Game.GetFormFromFile(formId, "Starfield.esm") as Spell
  If (ability == None)
    Debug.Trace("VWHUD STATUS PROBE | RemoveSpell | Missing | " + label)
    Return
  EndIf
  Bool removed = player.RemoveSpell(ability)
  Debug.Trace("VWHUD STATUS PROBE | RemoveSpell | " + label + " | Removed=" + removed)
EndFunction

Function CastSpellOnPlayer(Actor player, Int formId, String label) Global
  Spell effectSpell = Game.GetFormFromFile(formId, "Starfield.esm") as Spell
  If (effectSpell == None)
    Debug.Trace("VWHUD STATUS PROBE | Cast | Missing | " + label)
    Return
  EndIf
  effectSpell.Cast(player, player)
  Debug.Trace("VWHUD STATUS PROBE | Cast | " + label)
EndFunction

Function DispelNamedSpell(Actor player, Int formId, String label) Global
  Spell effectSpell = Game.GetFormFromFile(formId, "Starfield.esm") as Spell
  If (effectSpell == None)
    Debug.Trace("VWHUD STATUS PROBE | Dispel | Missing | " + label)
    Return
  EndIf
  Bool dispelled = player.DispelSpell(effectSpell)
  Debug.Trace("VWHUD STATUS PROBE | Dispel | " + label + " | Dispelled=" + dispelled)
EndFunction

Function UsePotion(Actor player, Int formId, String label) Global
  Form itemForm = Game.GetFormFromFile(formId, "Starfield.esm")
  If (itemForm == None)
    Debug.Trace("VWHUD STATUS PROBE | UsePotion | Missing | " + label)
    Return
  EndIf
  player.AddItem(itemForm, 1, True)
  player.EquipItem(itemForm, False, True)
  Debug.Trace("VWHUD STATUS PROBE | UsePotion | " + label)
EndFunction
