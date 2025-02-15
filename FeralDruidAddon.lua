-----------------------------
-- FeralDruidAddon for Turtle WoW 1.12.1
-----------------------------

FDA = FDA or {}

-- Initialize saved variables table
FDA_Settings = FDA_Settings or {}
FDA_Settings.UseInnervate = FDA_Settings.UseInnervate or true  -- Default to true if not set
FDA_Settings.UseBloodFrenzy = FDA_Settings.UseBloodFrenzy or true -- Default to true
FDA_Settings.StaticMainHandSpeed = FDA_Settings.StaticMainHandSpeed or nil -- Default to nil

-- Blood Frenzy event tracking variables
FDA.BF_LastGainTime = 0    -- Set when "You gain Blood Frenzy." is detected
FDA.BF_LastFadeTime = 0    -- Set when "Blood Frenzy fades from you." is detected
FDA.BF_ReadyTime    = 0    -- Set when "You can Blood Frenzy." is detected

-- Clearcasting event tracking variable
FDA.CC_IsActive = false    -- True when "You gain Clearcasting." is seen; false when it fades

FDA.DEBUG = false

-- Function to print messages to the chat frame
function FDA.tp_print(msg)
    if type(msg) == "boolean" then
        msg = msg and "true" or "false"
    end
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- Debug print function
function FDA.debug_print(msg)
    if FDA.DEBUG then
        FDA.tp_print(msg)
    end
end

-- Function to toggle DEBUG mode
function FDA.ToggleDebugMode()
    FDA.DEBUG = not FDA.DEBUG
    local status = FDA.DEBUG and "|cff00ff00enabled|r" or "|cffff0000disabled|r"
    FDA.tp_print("DEBUG mode is now " .. status .. ".")
end

-- Slash command for toggling DEBUG mode
SLASH_FDADEBUG1 = "/fdadebug"
SlashCmdList["FDADEBUG"] = FDA.ToggleDebugMode

-- Spell names and energy costs
FDA.SHRED_NAME = "Shred"
FDA.FEROCIOUS_BITE_NAME = "Ferocious Bite"
FDA.FAERIE_FIRE_FERAL_NAME = "Faerie Fire (Feral)(Rank 4)"
FDA.CAT_FORM_NAME = "Cat Form"
FDA.TIGERS_FURY_NAME = "Tiger's Fury(Rank 4)"
FDA.INNERVATE_NAME = "Innervate"

FDA.SHRED_ENERGY = 48
FDA.FEROCIOUS_BITE_ENERGY = 35

-- Buff and debuff textures
FDA.FAERIE_FIRE_TEXTURE = "Interface\\Icons\\Spell_Nature_FaerieFire"
FDA.CLEARCASTING_TEXTURE = "Interface\\Icons\\Spell_Shadow_ManaBurn"
FDA.BLOOD_FRENZY_TEXTURE = "Interface\\Icons\\Ability_GhoulFrenzy"  -- Blood Frenzy texture

-----------------------------
-- Utility Functions
-----------------------------

function strsplit(delim, str, maxNb, onlyLast)
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gfind(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then break end
    end
    if nb ~= maxNb then
        result[nb+1] = string.sub(str, lastPos)
    end
    if onlyLast then
        return result[nb+1]
    else
        return result[1], result[2]
    end
end

-----------------------------
-- Innervate Toggle and Command
-----------------------------

function FDA.ToggleInnervateUsage(status)
    if status == "on" then
        FDA_Settings.UseInnervate = true
        FDA.tp_print("Innervate usage enabled.")
    elseif status == "off" then
        FDA_Settings.UseInnervate = false
        FDA.tp_print("Innervate usage disabled.")
    else
        FDA.tp_print("Invalid command. Use /fda innervate on, /fda innervate off, or /fda innervate to view the current state.")
    end
end

SLASH_FDAINNERVATE1 = "/fda"
SlashCmdList["FDAINNERVATE"] = function(msg)
    local command, param = strsplit(" ", msg)
    if command == "innervate" then
        if param == "on" or param == "off" then
            FDA.ToggleInnervateUsage(param)
        else
            local status = FDA_Settings.UseInnervate and "enabled" or "disabled"
            FDA.tp_print("Innervate usage is currently " .. status .. ".")
            FDA.tp_print("Use /fda innervate on or /fda innervate off to change this setting.")
        end
    else
        FDA.tp_print("Available commands: /fda innervate on, /fda innervate off, or /fda innervate to view the current state.")
        FDA.tp_print("/recordas to record your STATIC ATTACK SPEED. Use this when in Cat form WITHOUT BLOOD FRENZY ACTIVE. This will use your attack speed as a reference for recasting Tiger's Fury.")
    end
end

-----------------------------
-- Spell/Cooldown and Buff Functions
-----------------------------

function FDA.GetSpellCooldownByName(spellName)
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = offset + 1, offset + numSpells do
            local spell = GetSpellName(i, BOOKTYPE_SPELL)
            if spell == spellName then
                local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
                return start or 0, duration or 0, enabled or 0
            end
        end
    end
    return 0, 0, 0
end

function FDA.CastInnervateIfLowMana()
    if not FDA_Settings.UseInnervate then
        return false
    end

    local currentMana, maxMana = AceLibrary("DruidManaLib-1.0"):GetMana()

    local start, duration, enabled = FDA.GetSpellCooldownByName(FDA.INNERVATE_NAME)
    if start > 0 and duration > 0 then
        local cooldownRemaining = start + duration - GetTime()
        return false
    end

    if currentMana < 600 then
        FDA.CastSpell(FDA.INNERVATE_NAME)
        return true
    end

    return false
end

-- Toggle Blood Frenzy usage (i.e. whether to use Tiger's Fury to trigger Blood Frenzy)
function FDA.ToggleBloodFrenzy()
    FDA_Settings.UseBloodFrenzy = not FDA_Settings.UseBloodFrenzy
    local status = FDA_Settings.UseBloodFrenzy and "|cff00ff00enabled|r" or "|cffff0000disabled|r"
    DEFAULT_CHAT_FRAME:AddMessage("Blood Frenzy usage is now " .. status .. ".")
end

function FDA.GetEnergy()
    if FDA.IsInCatForm() then
        return UnitMana("player") or 0
    end
    return 0
end

function FDA.GetCurrentComboPoints()
    return GetComboPoints("player", "target") or 0
end

-- New Clearcasting tracking: simply return the event-tracked flag.
function FDA.HasClearcastingBuff()
    return FDA.CC_IsActive
end

function FDA.HasFaerieFireDebuff()
    for i = 1, 40 do
        local texture = UnitDebuff("target", i)
        if texture == FDA.FAERIE_FIRE_TEXTURE then
            return true
        end
    end
    return false
end

function FDA.RecordStaticAttackSpeed()
    local mainHandSpeed = UnitAttackSpeed("player")
    if mainHandSpeed then
        FDA_Settings.StaticMainHandSpeed = mainHandSpeed
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "Static main-hand attack speed saved: %.2f",
            mainHandSpeed
        ))
    else
        DEFAULT_CHAT_FRAME:AddMessage("Failed to record static attack speed. Ensure you have no buffs active.")
    end
end

SLASH_RECORDSTATICAS1 = "/recordas"
SlashCmdList["RECORDSTATICAS"] = FDA.RecordStaticAttackSpeed

function FDA.CastSpell(spellName)
    if spellName then
        CastSpellByName(spellName)
    end
end

function FDA.IsInCatForm()
    local _, _, active = GetShapeshiftFormInfo(3)
    return active or false
end

function FDA.CastFaerieFire()
    if not FDA.HasFaerieFireDebuff() then
        FDA.CastSpell(FDA.FAERIE_FIRE_FERAL_NAME)
    end
end

-----------------------------
-- Blood Frenzy and Clearcasting Event Tracking Functions
-----------------------------
function FDA.OnEvent(self, event, arg1)
    if event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        if arg1 and string.find(arg1, "You gain Blood Frenzy") then
            FDA.BF_LastGainTime = GetTime()
            FDA.debug_print("Blood Frenzy gained at: " .. FDA.BF_LastGainTime)
        elseif arg1 and string.find(arg1, "You can Blood Frenzy") then
            FDA.BF_ReadyTime = GetTime()
            FDA.debug_print("Blood Frenzy ready timer started at: " .. FDA.BF_ReadyTime)
        end
        if arg1 and string.find(arg1, "You gain Clearcasting") then
            FDA.CC_IsActive = true
            FDA.debug_print("Clearcasting gained at: " .. GetTime())
        end
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        if arg1 and string.find(arg1, "Blood Frenzy fades from you") then
            FDA.BF_LastFadeTime = GetTime()
            FDA.debug_print("Blood Frenzy faded at: " .. FDA.BF_LastFadeTime)
        end
        if arg1 and string.find(arg1, "Clearcasting fades from you") then
            FDA.CC_IsActive = false
            FDA.debug_print("Clearcasting faded at: " .. GetTime())
        end
    end
end

-- Updated refresh logic for Blood Frenzy:
-- If Blood Frenzy is not active OR it’s been active for 15+ seconds (i.e. within 3 seconds of its 18 sec duration), return true.
function FDA.ShouldCastBloodFrenzy()
    if not FDA_Settings.UseBloodFrenzy then
        return false
    end
    local now = GetTime()
    local isActive = (FDA.BF_LastGainTime > 0 and (now - FDA.BF_LastGainTime < 18) and (FDA.BF_LastFadeTime <= FDA.BF_LastGainTime))
    if not isActive then
        return true
    end
    if now - FDA.BF_LastGainTime >= 15 then
        return true
    end
    return false
end

function FDA.CastBloodFrenzy()
    if FDA_Settings.UseBloodFrenzy and FDA.ShouldCastBloodFrenzy() then
        FDA.CastSpell(FDA.TIGERS_FURY_NAME)
        FDA.BF_LastGainTime = GetTime()
        FDA.BF_LastFadeTime = 0
        FDA.BF_ReadyTime = 0
        return true
    end
    return false
end

-----------------------------
-- Powershift Function
-----------------------------
function FDA.PowershiftIfLowEnergy()
    local energy = FDA.GetEnergy()
    local currentMana = AceLibrary("DruidManaLib-1.0"):GetMana()
    if energy < 11 and currentMana >= 306 and not FDA.HasClearcastingBuff() then
        if FDA.IsInCatForm() then
            FDA.CastSpell(FDA.CAT_FORM_NAME)
        end
        FDA.CastSpell(FDA.CAT_FORM_NAME)
    end
end

-----------------------------
-- Rotation Functions
-----------------------------
-- Shred-based (behind target) rotation
function FDA.FeralDruidRotation()
    if FDA_Settings.UseInnervate and FDA.CastInnervateIfLowMana() then
        return
    end
    if not FDA.IsInCatForm() then
        FDA.CastSpell(FDA.CAT_FORM_NAME)
        return
    end
    if FDA.CastBloodFrenzy() then
        return -- Exit if Blood Frenzy (triggered by Tiger's Fury) was cast
    end
    FDA.CastFaerieFire()
    if FDA.HasClearcastingBuff() then
        FDA.CastSpell(FDA.SHRED_NAME) -- Immediate Shred with Clearcasting
        return
    end
    local comboPoints = FDA.GetCurrentComboPoints()
    local currentEnergy = FDA.GetEnergy()
    if comboPoints < 5 then
        FDA.CastSpell(FDA.SHRED_NAME)
    elseif comboPoints == 5 and currentEnergy >= 80 then
        FDA.CastSpell(FDA.SHRED_NAME)
    else
        if not FDA.HasClearcastingBuff() and currentEnergy >= FDA.FEROCIOUS_BITE_ENERGY then
            FDA.CastSpell(FDA.FEROCIOUS_BITE_NAME)
        end
    end
    FDA.PowershiftIfLowEnergy()
end

-- Claw-based (not behind target) rotation
function FDA.FeralDruidClawRotation()
    if FDA_Settings.UseInnervate and FDA.CastInnervateIfLowMana() then
        return
    end
    if not FDA.IsInCatForm() then
        FDA.CastSpell(FDA.CAT_FORM_NAME)
        return
    end
    if FDA.CastBloodFrenzy() then
        return -- Exit if Blood Frenzy was cast
    end
    FDA.CastFaerieFire()
    if FDA.HasClearcastingBuff() then
        FDA.CastSpell("Claw")
        return
    end
    local comboPoints = FDA.GetCurrentComboPoints()
    local currentEnergy = FDA.GetEnergy()
    if comboPoints < 5 then
        FDA.CastSpell("Claw")
    elseif comboPoints == 5 and currentEnergy >= 80 then
        FDA.CastSpell(FDA.FEROCIOUS_BITE_NAME)
    else
        if currentEnergy >= FDA.FEROCIOUS_BITE_ENERGY then
            FDA.CastSpell(FDA.FEROCIOUS_BITE_NAME)
        end
    end
    FDA.PowershiftIfLowEnergy()
end

-- Combined rotation function:
-- Uses UnitXP("behind", "player", "target") to choose between shred and claw rotations.
function FDA.FeralDruidCombinedRotation()
    local isBehind = UnitXP("behind", "player", "target")
    if isBehind then
        FDA.FeralDruidRotation()
    else
        FDA.FeralDruidClawRotation()
    end
end

-----------------------------
-- Slash Commands
-----------------------------
SLASH_FERALCLAW1 = "/feralclaw"
SlashCmdList["FERALCLAW"] = FDA.FeralDruidClawRotation

SLASH_FERALATTACK1 = "/feralattack"
SlashCmdList["FERALATTACK"] = FDA.FeralDruidRotation

SLASH_TOGGLETS1 = "/ts"
SlashCmdList["TOGGLETS"] = FDA.ToggleBloodFrenzy

SLASH_FERALCOMBINED1 = "/feralcombined"
SlashCmdList["FERALCOMBINED"] = FDA.FeralDruidCombinedRotation

-----------------------------
-- Event Registration for Blood Frenzy and Clearcasting Tracking
-----------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
f:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
f:SetScript("OnEvent", function(self, event, arg1)
    FDA.OnEvent(self, event, arg1)
end)
