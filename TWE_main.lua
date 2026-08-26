-- TrueWarchiefExperience (TWE) — Warrior class voice pack for WoW Midnight (12.x)
-- Only load for Warriors (classId 1)
local _, _, classId = UnitClass("player")
if classId ~= 1 then return end

local TWE_settings = TWE_settings or {}
local TWE_soundEnabled = TWE_settings.soundEnabled ~= false
local TWE_debugEnabled = TWE_settings.debugEnabled == true
local TWE_GLOBAL_CD = TWE_settings.globalCD or 0

local function TWE_Debug(msg)
    if TWE_debugEnabled then
        print("|cffFF8000[TWE] DEBUG|r " .. msg)
    end
end

local TWE_lastSoundTime = 0
local TWE_playLock = 0
local TWE_currentHandle  = nil
local TWE_currentIsForce = false
local TWE_currentIsLowPriority = false

-- Separate from TWE_playLock: a short grace window after ANY force/normal
-- sound starts, during which lowPriority sounds are blocked from playing at
-- all. This is what stops a filler from overlapping a normal/force sound that
-- has no explicit protect, without making normal sounds unable to cut each
-- other (which giving them all a real protect would do).
local TWE_normalGraceUntil = 0
local TWE_LOWPRIORITY_GRACE = 1.5

local function CanPlay()
    local now = GetTime()
    if now < TWE_playLock then return false end
    if (now - TWE_lastSoundTime) < TWE_GLOBAL_CD then return false end
    TWE_lastSoundTime = now
    return true
end

local TWE_lastPlayed = {}

local ADDON_PATH = "Interface\\AddOns\\TrueWarchiefExperience\\sounds\\"

-- Roll a weighted-random file from a category pool.
-- Returns chosen file and its per-file protect (s[3]).
local function RollSound(sounds, category)
    -- Micro-optimization: single-file categories skip the weighting loop entirely.
    if #sounds == 1 then
        return sounds[1][1], sounds[1][3]
    end

    local lastFile = TWE_lastPlayed[category]
    local totalWeight = 0
    for _, s in ipairs(sounds) do
        local w = s[2] or 1
        if s[1] == lastFile then w = w * 0.1 end
        totalWeight = totalWeight + w
    end

    local roll = math.random() * totalWeight
    local chosen, chosenProtect
    local cumulative = 0
    for _, s in ipairs(sounds) do
        local w = s[2] or 1
        if s[1] == lastFile then w = w * 0.1 end
        cumulative = cumulative + w
        if roll <= cumulative then
            chosen = s[1]
            chosenProtect = s[3]
            break
        end
    end
    if not chosen then
        chosen = sounds[#sounds][1]
        chosenProtect = sounds[#sounds][3]
    end
    return chosen, chosenProtect
end

local function PlayRandom(category, force, protectDuration, lowPriority)
    if not TWE_soundEnabled then return end
    local now = GetTime()

    if force then
        -- Force sounds update the global-CD stamp anyway
        TWE_lastSoundTime = now
    else
        if now < TWE_playLock then
            TWE_Debug("[" .. category .. "] blocked: protect window active")
            return
        end
        if not CanPlay() then
            TWE_Debug("[" .. category .. "] blocked: global CD not elapsed")
            return
        end
    end

    -- lowPriority-only grace check: blocks a filler from starting while a
    -- normal/force sound is still within its short grace window, without
    -- giving that normal/force sound a real protect (which would also stop
    -- it from being cut by another normal sound).
    if lowPriority and now < TWE_normalGraceUntil then
        TWE_Debug("[" .. category .. "] blocked: normal/force grace window active")
        return
    end

    local sounds = TWE_Sounds[category]
    if not sounds or #sounds == 0 then return end

    local chosen, chosenProtect = RollSound(sounds, category)
    TWE_lastPlayed[category] = chosen

    -- Force: stop whatever is playing and clear the protect lock.
    -- Low-priority: only stops another currently-playing low-priority sound
    -- (never a force/normal one). StopSound is called with an explicit 0ms
    -- fadeout so the cut is immediate, not a crossfade — a default/omitted
    -- fadeout was the actual cause of audible overlap between back-to-back
    -- sounds.
    -- Normal (non-force, non-low-priority): cuts any other non-force sound.
    if force then
        if TWE_currentHandle then pcall(StopSound, TWE_currentHandle, 0) end
        TWE_playLock = 0
    elseif lowPriority then
        if TWE_currentIsLowPriority and TWE_currentHandle then
            pcall(StopSound, TWE_currentHandle, 0)
        end
    elseif not TWE_currentIsForce and TWE_currentHandle then
        pcall(StopSound, TWE_currentHandle, 0)
    end

    TWE_Debug("[" .. category .. "] playing: " .. chosen)
    local ok, success, handle = pcall(PlaySoundFile, ADDON_PATH .. chosen, "Dialog")
    TWE_currentHandle  = (ok and success) and handle or nil
    TWE_currentIsForce = force or false
    TWE_currentIsLowPriority = (not force) and lowPriority or false
    if not lowPriority then
        TWE_normalGraceUntil = now + TWE_LOWPRIORITY_GRACE
    end
    local effectiveProtect = chosenProtect or protectDuration
    if effectiveProtect then TWE_playLock = now + effectiveProtect end
end

-- ===========================================================================
-- Sound pools (files live under sounds/<category>/, referenced by relative path)
-- ===========================================================================
TWE_Sounds = {
    -- Ambient
    LOGIN  = { {"login\\login_1.ogg", 1, 9.1} }, -- protect = own runtime (8.935s) + buffer
    SELECT = {
        {"select\\select_1.ogg", 1}, {"select\\select_2.ogg", 1}, {"select\\select_3.ogg", 1},
        {"select\\select_4.ogg", 1}, {"select\\select_5.ogg", 1}, {"select\\select_6.ogg", 1},
    },
    AGGRO = {
        {"aggro\\aggro_1.ogg", 1}, {"aggro\\aggro_2.ogg", 1}, {"aggro\\aggro_3.ogg", 1},
    },
    DEATH = {
        {"death\\death_1.ogg", 1, 14.1}, {"death\\death_2.ogg", 1, 15.8},
    },
    REVIVE = { -- ambient: player coming back to life (canlanma -> revive, translated + camelCased)
        -- protect (3rd value) = each file's own runtime + small buffer, so it always plays out in full
        {"revive\\revive_1.ogg", 1, 4.6}, {"revive\\revive_2.ogg", 1, 3.8},
        {"revive\\revive_3.ogg", 1, 8.1}, {"revive\\revive_4.ogg", 1, 11.2},
        {"revive\\revive_5.ogg", 1, 10.9}, {"revive\\revive_6.ogg", 1, 7.7},
    },
    MOUNT = {
        {"mount\\mount_1.ogg", 1}, {"mount\\mount_2.ogg", 1}, {"mount\\mount_3.ogg", 1},
        {"mount\\mount_4.ogg", 1}, {"mount\\mount_5.ogg", 1}, {"mount\\mount_6.ogg", 1},
    },
    -- AFK: afkStart_1.mp3 (measured ~166.78s -- see AFK_STINGER_DURATION below)
    -- plays on entering AFK, then loops itself for as long as the player stays
    -- AFK. Played via direct pcall, not PlayRandom.
    AFK_START = { {"afkStart\\afkStart_1.mp3", 1} },

    -- Spell categories
    AVATAR              = { {"avatar\\avatar_1.ogg", 1, 4.9} }, -- protect = own runtime + buffer
    BATTLE_SHOUT         = {
        {"battleShout\\battleShout_1.ogg", 1}, {"battleShout\\battleShout_2.ogg", 1},
        {"battleShout\\battleShout_3.ogg", 1},
    },
    BERSERKER_RAGE       = { {"berserkerRage\\berserkerRage_1.ogg", 1} },
    BLADESTORM           = { {"bladestorm\\bladestorm_1.ogg", 1, 2.9} }, -- protect = own runtime + buffer
    CHAMPIONS_SPEAR      = { {"championsSpear\\championsSpear_1.ogg", 1} },
    CHARGE               = {
        {"charge\\charge_1.ogg", 1}, {"charge\\charge_2.ogg", 1}, {"charge\\charge_3.ogg", 1},
    },
    COLOSSUS_SMASH       = { {"colossusSmash\\colossusSmash_1.ogg", 1} },
    COMMANDING_SHOUT     = {
        {"commandingShout\\commandingShout_1.ogg", 1}, {"commandingShout\\commandingShout_2.ogg", 1},
        {"commandingShout\\commandingShout_3.ogg", 1},
    },
    DEATH_WISH           = { {"deathWish\\deathWish_1.ogg", 1, 6.5} }, -- protect = own runtime + buffer
    DEMOLISH             = { {"demolish\\demolish_1.ogg", 1, 2.6} }, -- protect = own runtime + buffer
    DEMORALIZING_SHOUT   = { {"demoralizingShout\\demoralizingShout_1.ogg", 1} },
    DISARM               = { {"disarm\\disarm_1.ogg", 1} },
    DISRUPTING_SHOUT     = { {"disruptingShout\\disruptingShout_1.ogg", 1} },
    DRAGON_CHARGE        = { {"dragonCharge\\dragonCharge_1.ogg", 1} },
    -- DUEL: sound file exists but is currently unwired — see README/sounds_list for why.
    DUEL                 = { {"duel\\duel_1.ogg", 1} },
    EXECUTE              = { {"execute\\execute_1.ogg", 1, 2.2} }, -- protect = own runtime (1.959s) + buffer
    HAMSTRING            = { {"hamstring\\hamstring_1.ogg", 1} },
    HEROIC_LEAP          = { {"heroicLeap\\heroicLeap_1.ogg", 1} },
    HEROIC_THROW         = { {"heroicThrow\\heroicThrow_1.ogg", 1} },
    IMPENDING_VICTORY    = { {"impendingVictory\\impendingVictory_1.ogg", 1} },
    INTERRUPT            = { {"interrupt\\interrupt_1.ogg", 1} }, -- Pummel
    INTERVENE            = {
        {"intervene\\intervene_1.ogg", 1}, {"intervene\\intervene_2.ogg", 1},
    },
    INTIMIDATING_SHOUT   = {
        {"intimidatingShout\\intimidatingShout_1.ogg", 1}, {"intimidatingShout\\intimidatingShout_2.ogg", 1},
        {"intimidatingShout\\intimidatingShout_3.ogg", 1}, {"intimidatingShout\\intimidatingShout_4.ogg", 1},
        {"intimidatingShout\\intimidatingShout_5.ogg", 1},
    },
    KILL_OR_BE_KILLED    = { {"killOrBeKilled\\killOrBeKilled_1.ogg", 1, 4.2} }, -- protect = own runtime + buffer
    ODYNS_FURY           = { {"odynsFury\\odynsFury_1.ogg", 1, 4.8} }, -- protect = own runtime + buffer
    OPPRESSOR            = { {"oppressor\\oppressor_1.ogg", 1} },
    PIERCING_HOWL        = { {"piercingHowl\\piercingHowl_1.ogg", 1} },
    RAVAGER              = { {"ravager\\ravager_1.ogg", 1, 4.4} }, -- protect = own runtime + buffer
    RECKLESSNESS         = { {"recklessness\\recklessness_1.ogg", 1, 5.9} }, -- protect = own runtime + buffer
    -- Shared bundle: Retaliation + Enraged Regeneration (see sounds_list.md for the judgment call)
    RETALIATION_ENRAGED_REGEN = { {"retaliationEnragedRegen\\retaliationEnragedRegen_1.ogg", 1, 5.0} }, -- protect = own runtime + buffer
    SHATTERING_THROW     = { {"shatteringThrow\\shatteringThrow_1.ogg", 1} },
    SHIELD_BLOCK         = { {"shieldBlock\\shieldBlock_1.ogg", 1} },
    SHIELD_WALL          = { {"shieldWall\\shieldWall_1.ogg", 1, 5.7} }, -- protect = own runtime + buffer
    SHOCKWAVE            = { {"shockwave\\shockwave_1.ogg", 1} },
    SPELL_REFLECTION     = { {"spellReflection\\spellReflection_1.ogg", 1} },
    STANCE               = { {"stance\\stance_1.ogg", 1} },
    STORM_BOLT           = { {"stormBolt\\stormBolt_1.ogg", 1} },
    TAUNT                = { {"taunt\\taunt_1.ogg", 1} },
}

-- ===========================================================================
-- Spell -> sound mapping
-- fields: cat, prob, force, protect, onCastStart, requiresSpell
-- ===========================================================================
local SpellToSound = {
    -- Major cooldowns (force: cut through everything, protect is dynamic/measured)
    [1719]    = { cat = "RECKLESSNESS",  prob = 1.0, force = true }, -- Recklessness
    [107574]  = { cat = "AVATAR",        prob = 1.0, force = true }, -- Avatar
    [871]     = { cat = "SHIELD_WALL",   prob = 1.0, force = true }, -- Shield Wall
    [227847]  = { cat = "BLADESTORM",    prob = 1.0, force = true }, -- Bladestorm
    [385059]  = { cat = "ODYNS_FURY",    prob = 1.0, force = true }, -- Odyn's Fury
    [228920]  = { cat = "RAVAGER",       prob = 1.0, force = true }, -- Ravager
    [436358]  = { cat = "DEMOLISH",      prob = 1.0, force = true }, -- Demolish (Protection capstone)
    [12292]   = { cat = "DEATH_WISH",    prob = 1.0}, -- Death Wish
    [1265361] = { cat = "KILL_OR_BE_KILLED", prob = 1.0, force = true }, -- Kill or Be Killed (Fury, death-prevention proc)
    [264085]  = { cat = "RETALIATION_ENRAGED_REGEN", prob = 1.0, force = true }, -- Retaliation
    [184364]  = { cat = "RETALIATION_ENRAGED_REGEN", prob = 1.0, force = true }, -- Enraged Regeneration, shares Retaliation's bucket

    -- Core rotational / offense
    [163201] = { cat = "EXECUTE", prob = 0.4 }, -- Execute (Arms)
    [5308]   = { cat = "EXECUTE", prob = 0.4 }, -- Execute (Fury/Protection), shares Execute's sound
    [167105] = { cat = "COLOSSUS_SMASH", prob = 1.0 }, -- Colossus Smash
    [206572] = { cat = "DRAGON_CHARGE",  prob = 1.0 }, -- Dragon Charge
    [107570] = { cat = "STORM_BOLT",     prob = 1.0 }, -- Storm Bolt
    [376079] = { cat = "CHAMPIONS_SPEAR", prob = 1.0 }, -- Champion's Spear
    [64382]  = { cat = "SHATTERING_THROW", prob = 1.0 }, -- Shattering Throw

    -- Movement
    [100]   = { cat = "CHARGE",       prob = 1.0 }, -- Charge
    [6544]  = { cat = "HEROIC_LEAP",  prob = 1.0 }, -- Heroic Leap
    [57755] = { cat = "HEROIC_THROW", prob = 1.0 }, -- Heroic Throw
    [3411]  = { cat = "INTERVENE",    prob = 1.0 }, -- Intervene

    -- Control / utility
    [6552]   = { cat = "INTERRUPT", prob = 1.0 }, -- Pummel
    [1715]   = { cat = "HAMSTRING", prob = 0.3 }, -- Hamstring
    [676]    = { cat = "DISARM",    prob = 1.0 }, -- Disarm
    [5246]   = { cat = "INTIMIDATING_SHOUT", prob = 1.0 }, -- Intimidating Shout
    [12323]  = { cat = "PIERCING_HOWL", prob = 1.0 }, -- Piercing Howl
    [46968]  = { cat = "SHOCKWAVE", prob = 1.0 }, -- Shockwave
    [386071] = { cat = "DISRUPTING_SHOUT", prob = 1.0 }, -- Disrupting Shout
    [205800] = { cat = "OPPRESSOR", prob = 1.0 }, -- Oppressor (Protection PvP talent)
    [355]    = { cat = "TAUNT", prob = 1.0 }, -- Taunt

    -- Defensive / sustain
    [2565]   = { cat = "SHIELD_BLOCK", prob = 1.0 }, -- Shield Block
    [23920]  = { cat = "SPELL_REFLECTION", prob = 1.0 }, -- Spell Reflection
    [202168] = { cat = "IMPENDING_VICTORY", prob = 1.0 }, -- Impending Victory

    -- Shouts
    [6673]   = { cat = "BATTLE_SHOUT", prob = 1.0 }, -- Battle Shout
    [225998] = { cat = "COMMANDING_SHOUT", prob = 1.0 }, -- Commanding Shout
    [1160]   = { cat = "DEMORALIZING_SHOUT", prob = 1.0 }, -- Demoralizing Shout
    [18499]  = { cat = "BERSERKER_RAGE", prob = 1.0 }, -- Berserker Rage

    -- Stances -- TODO verify spell IDs against live Midnight data; Wowhead direct
    -- fetches returned HTTP 403 in this session (see sounds_list.md), so these are
    -- best-current-knowledge placeholders, not independently confirmed for 12.x.
    [386164] = { cat = "STANCE", prob = 1.0 }, -- TODO verify: Battle Stance
    [386196] = { cat = "STANCE", prob = 1.0 }, -- TODO verify: Berserker Stance
    [1270826] = { cat = "STANCE", prob = 1.0 }, -- TODO verify: Defensive Stance (Midnight NPC-ability-style ID; unconfirmed as player-castable)
}

-- Spell IDs whose FAILED/INTERRUPTED cast should trigger an interrupt-miss line.
-- No dedicated interrupt-fail sound file ships in this pack, so this table is
-- currently empty; kept for architectural parity / future expansion.
local InterruptFailSpells = {}

local AGGRO_CD = 20 -- own cooldown, independent of the protect-lock system
local aggroLastPlayed = 0

-- Warrior spec IDs: 71 Arms, 72 Fury, 73 Protection
local function CurrentSpecID()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local specID = GetSpecializationInfo(specIndex)
    return specID
end

local function HandleResolvedSpell(spellID, fromCastStart)
    local cfg = SpellToSound[spellID]
    if not cfg then
        TWE_Debug("unmapped spellID=" .. tostring(spellID) .. (fromCastStart and " (castStart)" or " (succeeded)"))
        return
    end
    if fromCastStart and not cfg.onCastStart then
        TWE_Debug("spell=" .. tostring(spellID) .. " skipped: castStart event, cfg wants succeeded")
        return
    end
    if not fromCastStart and cfg.onCastStart then
        TWE_Debug("spell=" .. tostring(spellID) .. " skipped: succeeded event, cfg wants castStart")
        return
    end
    if cfg.requiresSpell and not IsPlayerSpell(cfg.requiresSpell) then return end
    local prob = cfg.prob
    if cfg.probBySpec then
        local specID = CurrentSpecID()
        if specID and cfg.probBySpec[specID] then
            prob = cfg.probBySpec[specID]
        end
    end
    if math.random() > prob then
        TWE_Debug("spell=" .. tostring(spellID) .. " -> " .. cfg.cat .. " (prob gate failed)")
        return
    end
    TWE_Debug("spell=" .. tostring(spellID) .. " -> " .. cfg.cat)
    PlayRandom(cfg.cat, cfg.force, cfg.protect, cfg.lowPriority)
end

-- ===========================================================================
-- Ambient state tracking
-- ===========================================================================
local prevDead       = false
local prevCombat     = false
local prevMounted    = false
local prevAFK        = false
local prevSelfTarget = false
local afkSoundHandle = nil
local afkMusicTimer  = nil -- shared: stinger->music AND every music->music reschedule
local pollTimer      = 0
local POLL           = 0.2

local AFK_STINGER_DURATION = 166.98 -- afkStart_1.mp3 measured runtime (166.776s) + buffer

local function IsStillAFK()
    local ok, isAFK = pcall(function()
        return UnitIsAFK("player") and true or false
    end)
    return ok and isAFK
end

-- AFK: plays afkStart_1.mp3 (direct pcall, not through PlayRandom -- it never
-- needs to cut anything, and normal/force sounds are still free to play over
-- it), then reschedules itself using AFK_STINGER_DURATION for as long as the
-- player is still AFK.
local function PlayAFKStart()
    if not TWE_soundEnabled then return end
    local pool = TWE_Sounds.AFK_START
    local chosen = RollSound(pool, "AFK_START")
    TWE_lastPlayed.AFK_START = chosen
    local ok, success, handle = pcall(PlaySoundFile, ADDON_PATH .. chosen, "Dialog")
    afkSoundHandle = (ok and success) and handle or nil
    TWE_Debug("AFK start playing: " .. chosen)

    afkMusicTimer = C_Timer.NewTimer(AFK_STINGER_DURATION, function()
        afkMusicTimer = nil
        if IsStillAFK() then
            PlayAFKStart()
        end
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

local loginLastPlayed = nil
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        prevMounted = IsMounted()
        local now = GetTime()
        if not loginLastPlayed or (now - loginLastPlayed) >= 3600 then
            loginLastPlayed = now
            TWE_Debug("state: LOGIN")
            PlayRandom("LOGIN", true)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then HandleResolvedSpell(spellID, false) end
    elseif event == "UNIT_SPELLCAST_START" then
        local unit, _, spellID = ...
        if unit == "player" then HandleResolvedSpell(spellID, true) end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit, _, spellID = ...
        if unit == "player" and InterruptFailSpells[spellID] then
            TWE_Debug("interrupt miss: spellID=" .. tostring(spellID) .. " (no INTERRUPT_FAIL sound file in this pack)")
        end
    end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
    pollTimer = pollTimer + elapsed
    if pollTimer < POLL then return end
    pollTimer = 0

    -- Death / Revive (ambient)
    local isDead = UnitIsDeadOrGhost("player")
    if isDead and not prevDead then
        TWE_Debug("state: DEATH")
        PlayRandom("DEATH", true)
    elseif not isDead and prevDead then
        TWE_Debug("state: REVIVE")
        PlayRandom("REVIVE", true)
    end
    prevDead = isDead

    -- Combat enter
    local inCombat = InCombatLockdown()
    if inCombat and not prevCombat then
        TWE_Debug("state: ENTER COMBAT")
        local nowAggro = GetTime()
        if nowAggro - aggroLastPlayed >= AGGRO_CD then
            aggroLastPlayed = nowAggro
            PlayRandom("AGGRO")
        else
            TWE_Debug("AGGRO blocked (own 20s CD)")
        end
    end
    prevCombat = inCombat

    -- Mount
    local mounted = IsMounted()
    if mounted and not prevMounted then
        TWE_Debug("state: MOUNT")
        PlayRandom("MOUNT")
    end
    prevMounted = mounted

    -- AFK
    local okAFK, afkEvent = pcall(function()
        local isAFK = UnitIsAFK("player")
        if isAFK and not prevAFK then
            prevAFK = true
            return "AFKSTART"
        elseif not isAFK and prevAFK then
            prevAFK = false
            return "AFKEND"
        end
    end)
    if okAFK and afkEvent == "AFKSTART" then
        TWE_Debug("state: AFK START")
        PlayAFKStart()
    elseif okAFK and afkEvent == "AFKEND" then
        TWE_Debug("state: AFK END")
        if afkMusicTimer then
            afkMusicTimer:Cancel()
            afkMusicTimer = nil
        end
        if afkSoundHandle then
            pcall(StopSound, afkSoundHandle, 0)
            afkSoundHandle = nil
        end
    end

    -- Self-target
    local selfTarget = UnitExists("target") and UnitIsUnit("target", "player")
    if selfTarget and not prevSelfTarget then
        TWE_Debug("state: SELF-TARGET")
        PlayRandom("SELECT")
    end
    prevSelfTarget = selfTarget
end)

-- ===========================================================================
-- Slash command: /twe on | off | debug | cd <seconds>
-- ===========================================================================
SLASH_TWE1 = "/twe"
SlashCmdList["TWE"] = function(msg)
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    if not cmd then cmd = "" end
    cmd = cmd:lower()

    if cmd == "on" then
        TWE_soundEnabled = true
        TWE_settings.soundEnabled = true
        print("|cffFF8000True Warchief Experience:|r Sounds |cff00FF00enabled|r.")
    elseif cmd == "off" then
        TWE_soundEnabled = false
        TWE_settings.soundEnabled = false
        print("|cffFF8000True Warchief Experience:|r Sounds |cffFF0000disabled|r.")
    elseif cmd == "debug" then
        TWE_debugEnabled = not TWE_debugEnabled
        TWE_settings.debugEnabled = TWE_debugEnabled
        print("|cffFF8000True Warchief Experience:|r Debug " .. (TWE_debugEnabled and "|cff00FF00on|r" or "|cffFF0000off|r") .. ".")
    elseif cmd == "cd" then
        local val = tonumber(arg)
        if val and val >= 0 then
            TWE_GLOBAL_CD = val
            TWE_settings.globalCD = val
            print("|cffFF8000True Warchief Experience:|r Global cooldown set to |cffFFFF00" .. val .. "|r seconds.")
        else
            print("|cffFF8000True Warchief Experience:|r Usage: /twe cd <seconds>")
        end
    else
        print("|cffFF8000True Warchief Experience:|r Commands:")
        print("  /twe on    -- enable sounds")
        print("  /twe off   -- disable sounds")
        print("  /twe debug -- toggle debug output")
        print("  /twe cd <seconds> -- set global cooldown between sounds")
    end
end
