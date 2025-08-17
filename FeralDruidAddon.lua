FDA = FDA or {}

-- Initialize saved variables table
FDA_Settings = FDA_Settings or {}
FDA_Settings.UseInnervate = FDA_Settings.UseInnervate or true  -- Default to true if not set
FDA_Settings.UseTigersFury = FDA_Settings.UseTigersFury or true -- Default to true
FDA_Settings.StaticMainHandSpeed = FDA_Settings.StaticMainHandSpeed or nil -- Default to nil

-- Debuff tracking variables
FDA.playerCasts = {}  -- Store our recent casts with timestamps
FDA.CAST_TIMEOUT = 30  -- How long to remember casts (30 seconds for safety)

-- Get player GUID from UnitExists (argument 2)
FDA.playerGUID = nil
function FDA.GetPlayerGUID()
    if not FDA.playerGUID then
        local exists, guid = UnitExists("player")
        FDA.playerGUID = guid
    end
    return FDA.playerGUID
end

-- Get target GUID from UnitExists (argument 2)
function FDA.GetTargetGUID()
    if UnitExists("target") then
        local exists, guid = UnitExists("target")
        return guid
    end
    return nil
end

-- Frame for event handling
FDA.DebuffTrackerFrame = CreateFrame("Frame")

-- Function to clean up old cast data
function FDA.CleanupOldCasts()
    local currentTime = GetTime()
    for guid, casts in pairs(FDA.playerCasts) do
        for i = table.getn(casts), 1, -1 do
            if currentTime - casts[i].timestamp > FDA.CAST_TIMEOUT then
                table.remove(casts, i)
            end
        end
        -- Remove empty GUID entries
        if table.getn(casts) == 0 then
            FDA.playerCasts[guid] = nil
        end
    end
end

-- Function to record our casts with proper durations
function FDA.RecordPlayerCast(spellID, targetGUID, comboPoints)
    if not FDA.playerCasts[targetGUID] then
        FDA.playerCasts[targetGUID] = {}
    end
    
    -- Set static durations based on spell mechanics
    local duration = 0
    if spellID == FDA.RAKE_SPELL_ID then
        duration = 9  -- Rake is always 9 seconds
    elseif spellID == FDA.RIP_SPELL_ID then
        duration = 18  -- Rip at 5 combo points is 18 seconds
    end
    
    table.insert(FDA.playerCasts[targetGUID], {
        spellID = spellID,
        timestamp = GetTime(),
        duration = duration
    })
    
    -- Clean up old data
    FDA.CleanupOldCasts()
    
    -- Debug output
    if FDA.DEBUG then
        FDA.debug_print("Recorded cast: Spell "..spellID.." on target "..targetGUID.." - Duration: "..duration.." seconds")
    end
end

-- Function to check if we cast a specific spell on a target recently and get remaining time
function FDA.DidWeCastSpell(spellID, targetGUID)
    if not FDA.playerCasts[targetGUID] then
        return false, 0
    end
    
    local currentTime = GetTime()
    for _, cast in ipairs(FDA.playerCasts[targetGUID]) do
        if cast.spellID == spellID then
            local timeElapsed = currentTime - cast.timestamp
            local timeRemaining = cast.duration - timeElapsed
            
            if timeRemaining > 0 then
                return true, timeRemaining
            end
        end
    end
    return false, 0
end

-- Event handler function
function FDA.OnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
    if not event then
        return
    end
    
    if event == "UNIT_CASTEVENT" then
        local casterGUID = arg1
        local targetGUID = arg2
        local castEvent = arg3
        local spellID = arg4
        local castDuration = arg5
        
        -- Check if this is our cast by comparing GUIDs
        if casterGUID == FDA.GetPlayerGUID() and castEvent == "CAST" and spellID then
            -- Only track Rake and Rip casts
            if spellID == FDA.RAKE_SPELL_ID or spellID == FDA.RIP_SPELL_ID then
                local comboPoints = FDA.GetCurrentComboPoints()
                FDA.RecordPlayerCast(spellID, targetGUID, comboPoints)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        -- Initialize player GUID
        FDA.playerGUID = FDA.GetPlayerGUID()
        if FDA.DEBUG then
            FDA.debug_print("FDA Debuff Tracker loaded. Player GUID: "..tostring(FDA.playerGUID))
        end
    end
end

-- Register events
FDA.DebuffTrackerFrame:RegisterEvent("UNIT_CASTEVENT")
FDA.DebuffTrackerFrame:RegisterEvent("PLAYER_LOGIN")
FDA.DebuffTrackerFrame:SetScript("OnEvent", function() FDA.OnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10) end)

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
FDA.RAKE_NAME = "Rake"
FDA.RIP_NAME = "Rip"
FDA.RESHIFT_NAME = "Reshift"

FDA.SHRED_ENERGY = 48
FDA.FEROCIOUS_BITE_ENERGY = 35
FDA.RAKE_ENERGY = 40
FDA.RIP_ENERGY = 30

-- Spell IDs for tracking
FDA.RAKE_SPELL_ID = 9904
FDA.RIP_SPELL_ID = 9896

-- Buff and debuff textures
FDA.FAERIE_FIRE_TEXTURE = "Interface\\Icons\\Spell_Nature_FaerieFire"
FDA.CLEARCASTING_TEXTURE = "Interface\\Icons\\Spell_Shadow_ManaBurn"
FDA.BLOOD_FRENZY_TEXTURE = "Interface\\Icons\\Ability_GhoulFrenzy"
FDA.RAKE_TEXTURE = "Interface\\Icons\\Ability_Druid_Disembowel"
FDA.RIP_TEXTURE = "Interface\\Icons\\Ability_GhoulFrenzy"

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

-- Function to check if our Rake debuff is on the target and get remaining time
function FDA.HasOurRakeDebuff()
    local targetGUID = FDA.GetTargetGUID()
    if not targetGUID then
        return false, 0
    end
    
    return FDA.DidWeCastSpell(FDA.RAKE_SPELL_ID, targetGUID)
end

-- Function to check if our Rip debuff is on the target and get remaining time
function FDA.HasOurRipDebuff()
    local targetGUID = FDA.GetTargetGUID()
    if not targetGUID then
        return false, 0
    end
    
    return FDA.DidWeCastSpell(FDA.RIP_SPELL_ID, targetGUID)
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

function FDA.ReshiftIfLowEnergy()
    local energy = FDA.GetEnergy()
    local currentMana = AceLibrary("DruidManaLib-1.0"):GetMana()

    if energy < 11 and currentMana >= 306 and not FDA.HasClearcastingBuff() then
        FDA.CastSpell(FDA.RESHIFT_NAME)
    end
end

function FDA.CastShred()
    local currentEnergy = FDA.GetEnergy()

    if currentEnergy >= FDA.SHRED_ENERGY or FDA.HasClearcastingBuff() then
        FDA.CastSpell(FDA.SHRED_NAME)
    end
end

function FDA.CastRake()
    local currentEnergy = FDA.GetEnergy()

    if currentEnergy >= FDA.RAKE_ENERGY or FDA.HasClearcastingBuff() then
        FDA.CastSpell(FDA.RAKE_NAME)
        
        -- Manually record the cast with our static timer since we know we cast it
        local targetGUID = FDA.GetTargetGUID()
        if targetGUID then
            FDA.RecordPlayerCast(FDA.RAKE_SPELL_ID, targetGUID, 0)
        end
        return true
    end
    return false
end

function FDA.CastRip()
    local currentEnergy = FDA.GetEnergy()
    local comboPoints = FDA.GetCurrentComboPoints()

    if comboPoints == 5 and (currentEnergy >= FDA.RIP_ENERGY or FDA.HasClearcastingBuff()) then
        FDA.CastSpell(FDA.RIP_NAME)
        
        -- Manually record the cast with our static timer since we know we cast it
        local targetGUID = FDA.GetTargetGUID()
        if targetGUID then
            FDA.RecordPlayerCast(FDA.RIP_SPELL_ID, targetGUID, comboPoints)
        end
        return true
    end
    return false
end

function FDA.CastFerociousBite()
    local currentEnergy = FDA.GetEnergy()
    local comboPoints = FDA.GetCurrentComboPoints()

    if comboPoints == 5 and (currentEnergy < 79 and currentEnergy >= FDA.FEROCIOUS_BITE_ENERGY) or FDA.HasClearcastingBuff() then
        FDA.CastSpell(FDA.FEROCIOUS_BITE_NAME)
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

-- NEW ROTATION WITH RAKE AND RIP TRACKING
function FDA.FeralDruidRotationTwo()
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
    if FDA_Settings.UseTigersFury and FDA.CastTigersFury() then
        return
    end

    -- Cast Faerie Fire (Feral) if not on the target
    FDA.CastFaerieFire()

    -- Get current combo points and energy
    local comboPoints = FDA.GetCurrentComboPoints()
    local currentEnergy = FDA.GetEnergy()
    
    -- Check our debuff status
    local hasRake, rakeTimeLeft = FDA.HasOurRakeDebuff()
    local hasRip, ripTimeLeft = FDA.HasOurRipDebuff()
    
    -- Debug output
    if FDA.DEBUG then
        FDA.debug_print("Combo Points: " .. comboPoints .. ", Energy: " .. currentEnergy)
        FDA.debug_print("Rake: " .. (hasRake and ("Active, " .. string.format("%.1f", rakeTimeLeft) .. "s left") or "Not active"))
        FDA.debug_print("Rip: " .. (hasRip and ("Active, " .. string.format("%.1f", ripTimeLeft) .. "s left") or "Not active"))
    end

    -- 5 COMBO POINT PRIORITIES (finisher priorities)
    if comboPoints == 5 then
        -- Priority 1: Refresh Rip if it has less than 5 seconds left
        if hasRip and ripTimeLeft < 5 then
            if FDA.CastRip() then
                return
            end
        end
        
        -- Priority 2: Apply Rip if it's not active
        if not hasRip then
            if FDA.CastRip() then
                return
            end
        end
        
        -- Priority 3: High energy finisher - use Shred to not waste energy
        if currentEnergy >= 80 then
            FDA.CastShred()
            return
        end
        
        -- Priority 4: Standard finisher with 5 combo points
        FDA.CastFerociousBite()
        return
    end

    -- COMBO POINT BUILDING PRIORITIES (less than 5 combo points)
    
    -- Priority 1: Use Clearcasting for Shred (most efficient)
    if FDA.HasClearcastingBuff() then
        FDA.CastShred()
        return
    end
    
    -- Priority 2: Apply Rake if it's not active
    if not hasRake then
        if FDA.CastRake() then
            return
        end
    end
    
    -- Priority 3: Refresh Rake if it has less than 2 seconds left
    if hasRake and rakeTimeLeft < 2 then
        if FDA.CastRake() then
            return
        end
    end
    
    -- Priority 4: Build combo points with Shred (Rake is active and maintained)
    FDA.CastShred()

    -- Attempt to powershift if energy is below threshold and no Clearcasting buff
    FDA.ReshiftIfLowEnergy()
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

    -- Attempt to reshift if energy is below threshold and no Clearcasting buff
    FDA.ReshiftIfLowEnergy()
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
        end
    end

    -- Attempt to reshift if energy is below threshold and no Clearcasting buff
    FDA.ReshiftIfLowEnergy()
end

-- Debug command to show current debuff status
SLASH_FDADEBUFFSTATUS1 = "/fdadebuffs"
SlashCmdList["FDADEBUFFSTATUS"] = function()
    if not UnitExists("target") then
        FDA.tp_print("No target selected.")
        return
    end
    
    local hasRake, rakeTimeLeft = FDA.HasOurRakeDebuff()
    local hasRip, ripTimeLeft = FDA.HasOurRipDebuff()
    local targetName = UnitName("target") or "Unknown"
    
    FDA.tp_print("=== Debuff Status on " .. targetName .. " ===")
    FDA.tp_print("Rake: " .. (hasRake and ("Active, " .. string.format("%.1f", rakeTimeLeft) .. " seconds left") or "Not active"))
    FDA.tp_print("Rip: " .. (hasRip and ("Active, " .. string.format("%.1f", ripTimeLeft) .. " seconds left") or "Not active"))
end

-- Slash commands
SLASH_FERALATTACKTWO1 = "/feralattacktwo"
SlashCmdList["FERALATTACKTWO"] = FDA.FeralDruidRotationTwo

SLASH_FERALCLAW1 = "/feralclaw"
SlashCmdList["FERALCLAW"] = FDA.FeralDruidClawRotation

SLASH_FERALATTACK1 = "/feralattack"
SlashCmdList["FERALATTACK"] = FDA.FeralDruidRotation

SLASH_TOGGLETS1 = "/ts"
SlashCmdList["TOGGLETS"] = FDA.ToggleTigersFury
