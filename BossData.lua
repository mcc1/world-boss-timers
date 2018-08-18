-- ----------------------------------------------------------------------------
--  A persistent timer for World Bosses.
-- ----------------------------------------------------------------------------

-- addonName, addonTable = ...;
local _, WBT = ...;

local SOUND_CLASSIC = "CLASSIC"
local SOUND_FANCY = "FANCY";

local MAX_RESPAWN = 15*60 - 1; -- Minus 1, since they tend to spawn after 14:59.
-- Conservative guesses. Actual values are not known.
local MIN_RESPAWN_SHA = 12*60;
local MAX_RESPAWN_SHA = 18*60;
local MIN_RESPAWN_NALAK = 12*60;
local MAX_RESPAWN_NALAK = 18*60;
local MIN_RESPAWN_HUOLON = 30*60;
local MAX_RESPAWN_HUOLON = 60*60;

local SOUND_DIR = "Interface\\AddOns\\WorldBossTimers\\resources\\sound\\";
local SOUND_FILE_DEFAULT = "Sound\\Event Sounds\\Event_wardrum_ogre.ogg";
local SOUND_FILE_PREPARE = "Sound\\creature\\EadricThePure\\AC_Eadric_Aggro01.ogg";

local TRACKED_BOSSES = {
    ["Oondasta"] = {
        name = "Oondasta",
        color = "|cff21ffa3",
        zone = "Isle of Giants",
        soundfile = SOUND_DIR .. "oondasta3.mp3",
        min_respawn = MAX_RESPAWN,
        max_respawn = MAX_RESPAWN,
        random_spawn_time = false,
    },
    ["Rukhmar"] = {
        name = "Rukhmar",
        color = "|cfffa6e06",
        zone = "Spires of Arak",
        soundfile = SOUND_DIR .. "rukhmar1.mp3",
        min_respawn = MAX_RESPAWN,
        max_respawn = MAX_RESPAWN,
        random_spawn_time = false,
    },
    ["Galleon"] = {
        name = "Galleon",
        color = "|cffc1f973",
        zone = "Valley of the Four Winds",
        soundfile = SOUND_FILE_DEFAULT,
        min_respawn = MAX_RESPAWN,
        max_respawn = MAX_RESPAWN,
        random_spawn_time = false,
    },
    ["Nalak"] = {
        name = "Nalak",
        color = "|cff0081cc",
        zone = "Isle of Thunder",
        soundfile = SOUND_FILE_DEFAULT,
        min_respawn = MIN_RESPAWN_NALAK,
        max_respawn = MAX_RESPAWN_NALAK,
        random_spawn_time = true,
    },
    ["Sha of Anger"] = {
        name = "Sha of Anger",
        color = "|cff8a1a9f",
        zone = "Kun-Lai Summit",
        soundfile = SOUND_FILE_DEFAULT,
        min_respawn = MIN_RESPAWN_SHA,
        max_respawn = MAX_RESPAWN_SHA,
        random_spawn_time = true,
    },
    ["Huolon"] = {
        name = "Huolon",
        color = "|cfff7f713",
        zone = "Timless Isle",
        soundfile = SOUND_FILE_DEFAULT,
        min_respawn = MIN_RESPAWN_HUOLON,
        max_respawn = MAX_RESPAWN_HUOLON,
        random_spawn_time = true,
    },
    --@do-not-package@
    --[[
    -- Dummy.
    ["Vale Moth"] = {
        name = "Vale Moth",
        color = "|cff1f3d4a",
        zone = "Azuremyst Isle",
        soundfile = SOUND_DIR .. "vale_moth1.mp3",
        min_respawn = MIN_RESPAWN_SHA,
        max_respawn = MAX_RESPAWN_SHA,
        random_spawn_time = false,
    },
    -- Dummy.
    ["Grellkin"] = {
        name = "Grellkin",
        color = "|cffffff00",
        zone = "Shadowglen",
        soundfile = SOUND_DIR .. "grellkin2.mp3",
        min_respawn = MIN_RESPAWN_SHA,
        max_respawn = MAX_RESPAWN_SHA,
        random_spawn_time = true,
    },
    -- Dummy.
    -- This entry won't work for everything since two mobs reside in same zone.
    ["Young Nightsaber"] = {
        name = "Young Nightsaber",
        color = "|cffff3d4a",
        zone =  "_Shadowglen",
        soundfile = SOUND_DIR .. "vale_moth1.mp3",
        min_respawn = MIN_RESPAWN_SHA,
        max_respawn = MIN_RESPAWN_SHA,
        random_spawn_time = false,
    },
    ]]--
    --@end-do-not-package@
}

function WBT.BossData.Get(name)
    return TRACKED_BOSSES[name];
end