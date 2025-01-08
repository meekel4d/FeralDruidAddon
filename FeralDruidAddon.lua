FDA = FDA or {}

-- Initialize saved variables table
FDA_Settings = FDA_Settings or {}
FDA_Settings.UseInnervate = FDA_Settings.UseInnervate or true  -- Default to true if not set
FDA_Settings.UseTigersFury = FDA_Settings.UseTigersFury or true -- Default to true
FDA_Settings.StaticMainHandSpeed = FDA_Settings.StaticMainHandSpeed or nil -- Default to nil


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
    local status = FDA.DEBUG and "|cff00ff00enabled|r" or "|cffff0000disabled|r"  -- Green for enabled, red for disabled
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
FDA.BLOOD_FRENZY_TEXTURE = "Interface\\Icons\\Ability_GhoulFrenzy"

-- Functions

function strsplit(delim, str, maxNb, onlyLast)
	-- Eliminate bad cases...
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
	-- Handle the last field
	if nb ~= maxNb then
		result[nb+1] = string.sub(str, lastPos)
	end
	if onlyLast then
		return result[nb+1]
	else
		return result[1], result[2]
	end
end

-- Function to toggle Innervate usage and show current state
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

-- Slash command to toggle Innervate usage or display current state
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
        FDA.tp_print("/recordas to record your STATIC ATTACK SPEED. Use this when in Cat form WITHOUT TIGER'S FURY ACTIVE. This will use your attack speed as a reference for recasting Tiger's fury.")
    end
end

-- Function to get spell cooldown by name
function FDA.GetSpellCooldownByName(spellName)
    -- Loop through the spellbook to find the spell
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = offset + 1, offset + numSpells do
            local spell = GetSpellName(i, BOOKTYPE_SPELL)
            if spell == spellName then
                -- Get cooldown for the found spell
                local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
                return start or 0, duration or 0, enabled or 0 -- Ensure no nil values
            end
        end
    end
    return 0, 0, 0 -- Spell not found, default cooldown values
end

-- Function to cast Innervate if mana is low and the toggle is enabled
function FDA.CastInnervateIfLowMana()
    if not FDA_Settings.UseInnervate then
        return false  -- Exit if Innervate usage is disabled
    end

    local currentMana, maxMana = AceLibrary("DruidManaLib-1.0"):GetMana()

    local start, duration, enabled = FDA.GetSpellCooldownByName(FDA.INNERVATE_NAME)
    if start > 0 and duration > 0 then
        local cooldownRemaining = start + duration - GetTime()
        return false -- Indicate that Innervate was not cast
    end

    if currentMana < 600 then
        FDA.CastSpell(FDA.INNERVATE_NAME)
        return true -- Indicate that Innervate was cast
    end

    return false
end

function FDA.ToggleTigersFury()
    FDA_Settings.UseTigersFury = not FDA_Settings.UseTigersFury -- Toggle the state
    local status = FDA_Settings.UseTigersFury and "|cff00ff00enabled|r" or "|cffff0000disabled|r" -- Green for enabled, red for disabled
    DEFAULT_CHAT_FRAME:AddMessage("Tiger's Fury usage is now " .. status .. ".")
end

function FDA.GetEnergy()
    if FDA.IsInCatForm() then
        return UnitMana("player") or 0 -- Ensure energy is never nil
    end
    return 0 -- Default to 0 if not in Cat Form
end

function FDA.GetCurrentComboPoints()
    return GetComboPoints("player", "target") or 0 -- Ensure combo points are never nil
end

function FDA.HasClearcastingBuff()
    for i = 0, 31 do
        local id = GetPlayerBuff(i, "HELPFUL|HARMFUL|PASSIVE")
        if id > -1 then
            local texture = GetPlayerBuffTexture(id)
            if texture == FDA.CLEARCASTING_TEXTURE then
                return true
            end
        end
    end
    return false
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

-- Function to record static main-hand attack speed and save it persistently
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

-- Slash command to manually record static main-hand attack speed
SLASH_RECORDSTATICAS1 = "/recordas"
SlashCmdList["RECORDSTATICAS"] = FDA.RecordStaticAttackSpeed

-- Function to determine if Tiger's Fury needs to be reapplied based on attack speed
function FDA.HasTigersFuryBuff()
    -- Get the current main-hand attack speed
    local currentSpeed = UnitAttackSpeed("player")
    local staticSpeed = FDA_Settings.StaticMainHandSpeed

    -- Check if static speed is saved and valid
    if not staticSpeed then
        DEFAULT_CHAT_FRAME:AddMessage("Tiger's Fury check failed: Static attack speed not recorded. Use /recordas to save it.")
        return false -- Assume Tiger's Fury is not active if no static speed is recorded
    end

    -- Calculate the percentage of current speed vs. static speed
    local speedPercentage = (currentSpeed / staticSpeed) * 100

    -- If the current speed is 84% or lower, Tiger's Fury does NOT need to be reapplied
    if speedPercentage <= 84 then
        return true -- Tiger's Fury effect is active
    else
        return false -- Tiger's Fury needs to be reapplied
    end
end

function FDA.CastSpell(spellName)
    if spellName then
        CastSpellByName(spellName)
    end
end

-- Function to check and cast Innervate if mana is low
function FDA.CastInnervateIfLowMana()
    local currentMana, maxMana = AceLibrary("DruidManaLib-1.0"):GetMana()

    -- Use the cooldown tracking logic
    local start, duration, enabled = FDA.GetSpellCooldownByName(FDA.INNERVATE_NAME)
    if start > 0 and duration > 0 then
        local cooldownRemaining = start + duration - GetTime()
        return false -- Indicate that Innervate was not cast
    end

    if currentMana < 600 then
        FDA.CastSpell(FDA.INNERVATE_NAME)
        return true -- Indicate that Innervate was cast
    end

    return false
end

function FDA.IsInCatForm()
    local _, _, active = GetShapeshiftFormInfo(3)
    return active or false -- Ensure active is never nil
end

function FDA.CastFaerieFire()
    if not FDA.HasFaerieFireDebuff() then
        FDA.CastSpell(FDA.FAERIE_FIRE_FERAL_NAME)
    end
end

function FDA.CastTigersFury()
    if not FDA.HasTigersFuryBuff() then
        FDA.CastSpell(FDA.TIGERS_FURY_NAME)
        return true
    end
    return false
end

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

function FDA.CastShred()
    local currentEnergy = FDA.GetEnergy()

    if currentEnergy >= FDA.SHRED_ENERGY or FDA.HasClearcastingBuff() then
        FDA.CastSpell(FDA.SHRED_NAME)
    else
    end
end

function FDA.CastFerociousBite()
    local currentEnergy = FDA.GetEnergy()
    local comboPoints = FDA.GetCurrentComboPoints()

    if comboPoints == 5 and (currentEnergy < 79 and currentEnergy >= FDA.FEROCIOUS_BITE_ENERGY) or FDA.HasClearcastingBuff() then
        FDA.CastSpell(FDA.FEROCIOUS_BITE_NAME)
    else
    end
end

function FDA.CastShredHighEnergy()
    local currentEnergy = FDA.GetEnergy()
    local comboPoints = FDA.GetCurrentComboPoints()

    -- Cast Shred if combo points are 5 and energy is greater than or equal to 83
    if currentEnergy >= 80 and comboPoints == 5 then
        FDA.CastSpell(FDA.SHRED_NAME) -- Cast Shred using the spell name
    end
end

function FDA.FeralDruidRotation()
    if FDA_Settings.UseInnervate and FDA.CastInnervateIfLowMana() then
        return
    end

    if not FDA.IsInCatForm() then
        FDA.CastSpell(FDA.CAT_FORM_NAME)
        return
    end

    if FDA_Settings.UseTigersFury and FDA.CastTigersFury() then
        return
    end

    FDA.CastFaerieFire()

    if FDA.HasClearcastingBuff() then
        FDA.CastShred()
        return
    end

    local comboPoints = FDA.GetCurrentComboPoints()
    local currentEnergy = FDA.GetEnergy()

    if comboPoints < 5 then
        FDA.CastShred()
    elseif comboPoints == 5 and currentEnergy >= 80 then
        FDA.CastShredHighEnergy()
    else
        FDA.CastFerociousBite()
    end

    FDA.PowershiftIfLowEnergy()
end

-- Function to cast Faerie Fire (Feral) if not already applied on the target
function FDA.CastFaerieFire()
    if not FDA.HasFaerieFireDebuff() then
        FDA.CastSpell(FDA.FAERIE_FIRE_FERAL_NAME)
    end
end

-- Function to cast Tiger's Fury if not already active
function FDA.CastTigersFury()
    if not FDA.HasTigersFuryBuff() then
        FDA.CastSpell(FDA.TIGERS_FURY_NAME)
        return true
    end
    return false
end

-- Function to cast Faerie Fire (Feral) if not already applied on the target
function FDA.CastFaerieFire()
    if not FDA.HasFaerieFireDebuff() then
        FDA.CastSpell(FDA.FAERIE_FIRE_FERAL_NAME)
    end
end

-- Function to cast Tiger's Fury if not already active
function FDA.CastTigersFury()
    if not FDA.HasTigersFuryBuff() then
        FDA.CastSpell(FDA.TIGERS_FURY_NAME)
        return true
    end
    return false
end

-- New Claw-based rotation function
function FDA.FeralDruidClawRotation()
    -- Check if mana is low and cast Innervate if needed
    if FDA_Settings.UseInnervate and FDA.CastInnervateIfLowMana() then
        return
    end

    -- Check if not in Cat Form, and shift into it if needed
    if not FDA.IsInCatForm() then
        FDA.CastSpell(FDA.CAT_FORM_NAME)
        return
    end

    -- Prioritize casting Tiger's Fury if the buff is not active
    if FDA.CastTigersFury() then
        return -- Exit the function if Tiger's Fury was cast
    end

    -- Cast Faerie Fire (Feral) if not on the target
    FDA.CastFaerieFire()

    -- Prioritize Clearcasting Claw
    if FDA.HasClearcastingBuff() then
        FDA.CastSpell("Claw") -- Use Claw immediately with Clearcasting
        return
    end

    -- Perform Claw or Ferocious Bite based on combo points and energy
    local comboPoints = FDA.GetCurrentComboPoints()
    local currentEnergy = FDA.GetEnergy()

    if comboPoints < 5 then
        -- Cast Claw if combo points are less than 5
        FDA.CastSpell("Claw")
    elseif comboPoints == 5 and currentEnergy >= 80 then
        -- Cast Ferocious Bite if combo points are 5 and energy >= 80
        FDA.CastSpell(FDA.FEROCIOUS_BITE_NAME)
    else
        -- Cast Ferocious Bite if combo points are 5 and energy is less than 80 but enough to cast
        if currentEnergy >= FDA.FEROCIOUS_BITE_ENERGY then
            FDA.CastSpell(FDA.FEROCIOUS_BITE_NAME)
        else
        end
    end

    -- Attempt to powershift if energy is below threshold and no Clearcasting buff
    FDA.PowershiftIfLowEnergy()
end

-- Slash command for the new Claw-based rotation
SLASH_FERALCLAW1 = "/feralclaw"
SlashCmdList["FERALCLAW"] = FDA.FeralDruidClawRotation

-- Slash commands
SLASH_FERALATTACK1 = "/feralattack"
SlashCmdList["FERALATTACK"] = FDA.FeralDruidRotation

SLASH_TOGGLETS1 = "/ts"
SlashCmdList["TOGGLETS"] = FDA.ToggleTigersFury
