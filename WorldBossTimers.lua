-- ----------------------------------------------------------------------------
--  A persistent timer for World Bosses.
-- ----------------------------------------------------------------------------

local _, L = ...;

WBT = LibStub("AceAddon-3.0"):NewAddon("WBT", "AceConsole-3.0");

local gui;
local boss_death_frame;
local boss_combat_frame;

local defaults = {
    global = {
        boss = {},
        gui = nil,
        sound_enabled = true,
        sound_type = "fancy",
    },
    char = {
        boss = {},
    },
};

local REALM_TYPE_PVE = "PvE";
local REALM_TYPE_PVP = "PvP";

local BASE_COLOR = "|cffffffff";
local INDENT = "--";
local CHAT_MSG_TIMER_REQUEST = "Could you please share WorldBossTimers kill data?";
local SERVER_DEATH_TIME_PREFIX = "WorldBossTimers:"; -- Free advertising.
local MAX_RESPAWN_TIME = 15*60 - 1; -- Minus 1, since they tend to spawn after 14:58.
--local MAX_RESPAWN_TIME = 50 - 1; -- Minus 1, since they tend to spawn after 14:58.
local SOUND_DIR = "Interface\\AddOns\\WorldBossTimers\\resources\\sound\\";
local DEFAULT_SOUND_FILE = "Sound\\Event Sounds\\Event_wardrum_ogre.ogg";


local REGISTERED_BOSSES = {
    ["Oondasta"] = {
        name = "Oondasta",
        color = "|cff21ffa3",
        zone = "Isle of Giants",
        soundfile = SOUND_DIR .. "oondasta3.mp3",
    },
    ["Rukhmar"] = {
        name = "Rukhmar",
        color = "|cfffa6e06",
        zone = "Spires of Arak",
        soundfile = SOUND_DIR .. "rukhmar1.mp3",
    },
    ["Galleon"] = {
        name = "Galleon",
        color = "|cffc1f973",
        zone = "Valley of the Four Winds",
        soundfile = DEFAULT_SOUND_FILE,
    },
    ["Nalak"] = {
        name = "Nalak",
        color = "|cff0081cc",
        zone = "Isle of Thunder",
        soundfile = DEFAULT_SOUND_FILE,
    },
    ["Sha of Anger"] = {
        name = "Sha of Anger",
        color = "|cff8a1a9f",
        zone = "Valley of the Four Winds",
        soundfile = DEFAULT_SOUND_FILE,
    },
    ["Vale Moth"] = {
        name = "Vale Moth",
        color = "|cff1f3d4a",
        zone = "Azuremyst Isle",
        soundfile = SOUND_DIR .. "vale_moth1.mp3",
    },
    ["Grellkin"] = {
        name = "Grellkin",
        color = "|cffffff00",
        zone = "Shadowglen",
        soundfile = SOUND_DIR .. "grellkin2.mp3",
    },
    ["Young Nightsaber"] = {
        name = "Young Nightsaber",
        color = "|cffff3d4a",
        zone =  "Shadowglen",
        soundfile = SOUND_DIR .. "vale_moth1.mp3",
    },
}

local function GetColoredBossName(name)
    return REGISTERED_BOSSES[name].color .. REGISTERED_BOSSES[name].name .. BASE_COLOR;
end

local function SetContainsKey(set, key)
    return set[key] ~= nil;
end

local function TableIsEmpty(tbl)
    return next(tbl) == nil
end

local function SetContainsValue(set, value)
    for k, v in pairs(set) do
        if v == value then
            return true;
        end
    end

    return false;
end

local function IsBoss(name)
    return SetContainsKey(REGISTERED_BOSSES, name);
end

local function IsInZoneOfBoss(name)
    return GetZoneText() == REGISTERED_BOSSES[name].zone;
end

local function BossesInCurrentZone()
    local bosses_in_zone = {}
    for name, boss in pairs(REGISTERED_BOSSES) do
        if IsInZoneOfBoss(name) then
            bosses_in_zone[name] = name;
        end
    end

    return bosses_in_zone;
end

local function GetRealmType()
    local pvpStyle = GetZonePVPInfo();
    if pvpStyle == nil then
        return REALM_TYPE_PVE;
    end

    return REALM_TYPE_PVP;
end

local function GetKillInfoFromZone()
    local current_zone = GetZoneText();
    for name, kill_info in pairs(REGISTERED_BOSSES) do
        if kill_info.zone == current_zone then
            return WBT.db.global.boss[kill_info.name];
        end
    end

    return nil;
end

-- The data for the kill can be incorrect. This might happen
-- when a player records a kill and then appear on another
-- server shard.
-- If this happens, we don't want the data to propagate
-- to other players.
local function IsKillInfoSafe(error_msgs)

    local kill_info = GetKillInfoFromZone();

    -- It's possible to have one char with war mode, and one
    -- without on the same server.
    local realm_type = GetRealmType();
    local realmName = GetRealmName();

    if not kill_info.safe then
        table.insert(error_msgs, "Player was in a group during previous kill.");
    end
    if not kill_info.realm_type == realm_type then
        table.insert(error_msgs, "Kill was made on a " .. kill_info.realm_type .. " realm, but are now on a " .. realm_type .. " realm.");
    end
    if not kill_info.realmName == realmName then
        table.insert(error_msgs, "Kill was made on " .. kill_info.realmName .. ", but are now on " .. realmName .. ".");
    end

    if TableIsEmpty(error_msgs) then
        return true;
    end

    return false;
end

local function SetDeathTime(time, name)
    if WBT.db.global.boss[name] == nil then
        local boss = {};
        WBT.db.global.boss[name] = boss;
    end
    WBT.db.global.boss[name].t_death = time;
    WBT.db.global.boss[name].name = name;
    WBT.db.global.boss[name].realmName = GetRealmName();
    WBT.db.global.boss[name].realm_type = GetRealmType();
    WBT.db.global.boss[name].safe = not IsInGroup();
end

local function GetServerDeathTime(name)
    return WBT.db.global.boss[name].t_death;
end

local function KillUpdateFrame(frame)
    frame:SetScript("OnUpdate", nil);
end

local function FormatTimeSeconds(seconds)
    local mins = math.floor(seconds / 60);
    local secs = math.floor(seconds % 60);
    if mins > 0 then
        return mins .. "m " .. secs .. "s";
    else
        return secs .. "s";
    end
end

local function GetSpawnTimeSec(name)
    local boss = WBT.db.global.boss[name]
    if boss ~= nil then
        return boss.t_death + MAX_RESPAWN_TIME - GetServerTime();
    end
end

local function GetSpawnTime(name)
    local spawnTimeSec = GetSpawnTimeSec(name);
    if spawnTimeSec == nil or spawnTimeSec < 0 then
        return -1;
    end
    return FormatTimeSeconds(spawnTimeSec);
end

local function IsBossZone()
    local current_zone = GetZoneText();

    local is_boss_zone = false;
    for name, boss in pairs(REGISTERED_BOSSES) do
        if boss.zone == current_zone then
            is_boss_zone = true;
        end
    end

    return is_boss_zone;
end

local function IsDead(name)
    if WBT.db.global.boss[name] == nil then
        return false;
    end
    return GetSpawnTimeSec(name) >= 0;
end

local function AnyDead()
    local any_dead = false;
    for name, boss in pairs(REGISTERED_BOSSES) do
        if IsDead(name) then
            any_dead = true;
        end
    end
    return any_dead;
end

local function ShouldShowGUI()
    return AnyDead() or IsBossZone();
end

local function GetBossNames()
    local boss_names = {};
    local i = 1; -- Don't start on index = 0... >-<
    for name, _ in pairs(REGISTERED_BOSSES) do
        boss_names[i] = name;
        i = i + 1;
    end

    return boss_names;
end

local last_request_time = 0;
local function RequestKillData()
    if GetServerTime() - last_request_time > 5 then
        SendChatMessage(CHAT_MSG_TIMER_REQUEST, "SAY");
        last_request_time = GetServerTime();
    end
end

local function InitGUI()

    local AceGUI = LibStub("AceGUI-3.0"); -- Need to create AceGUI 'OnInit or OnEnabled'
    local gui_container = AceGUI:Create("SimpleGroup");
    gui = AceGUI:Create("Window");

    local width = 200;
    local height = 100;
    gui:SetWidth(width);
    gui:SetHeight(height);
    gui:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end);
    gui:SetTitle("World Boss Timers");
    gui:SetLayout("List");
    gui:EnableResize(false);
    gui.frame:SetFrameStrata("LOW");

    local btn = AceGUI:Create("Button");
    btn:SetWidth(width);
    btn:SetText("Request kill data");
    btn:SetCallback("OnClick", RequestKillData);

    hooksecurefunc(gui, "Hide", function() btn.frame:Hide() end);

    gui_container:AddChild(gui);
    gui_container:AddChild(btn);

    gui_container.frame:SetFrameStrata("LOW");

    function gui:Update()
        self:ReleaseChildren();

        for name, boss in pairs(WBT.db.global.boss) do
            if IsDead(name) then
                local label = AceGUI:Create("InteractiveLabel");
                label:SetWidth(170);
                label:SetText(GetColoredBossName(name) .. ": " .. GetSpawnTime(name));
                label:SetCallback("OnClick", function() WBT:Print(name) end);
                -- Add the button to the container
                self:AddChild(label);
                --WBT:Print(label:IsShown());
            end
        end
    end

    function gui:InitPosition()
        gui_position = WBT.db.char.gui_position;
        local gp;
        if gui_position ~= nil then
            gp = gui_position;
        else
            gp = {
                point = "Center",
                relativeToName = "UIParrent",
                realtivePoint = nil,
                xOfs = 0,
                yOfs = 0,
            }
        end
        self:ClearAllPoints();
        self:SetPoint(gp.point, relativeTo, gp.xOfs, gp.yOfs);
    end

    local function RecordGUIPositioning()
        local function SaveGuiPoint()
            point, relativeTo, relativePoint, xOfs, yOfs = gui:GetPoint();
            WBT.db.char.gui_position = {
                point = point,
                relativeToName = "UIParrent",
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs,
            };
            -- print(WBT.db.char.gui_position.point, WBT.db.char.gui_position.relativeToName, WBT.db.char.gui_position.relativePoint, WBT.db.char.gui_position.xOfs, WBT.db.char.gui_position.yOfs);
        end
        hooksecurefunc(gui.frame, "StopMovingOrSizing", SaveGuiPoint);
    end

    gui:Update();

    gui:InitPosition();

    gui:Show();

    RecordGUIPositioning();
end

local function RegisterEvents()
    boss_death_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    boss_combat_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

local function UnregisterEvents()
    boss_death_frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    boss_combat_frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

local function ShowGUI()
    if gui ~= nil then
        gui:Hide();
        gui = nil;
    end
    InitGUI();
end

local function HideGUI()
    if gui ~= nil then
        gui:Hide();
        gui = nil;
    end
end

local function RestartGUI()
    HideGUI();
    ShowGUI();
end

local function UpdateGUIVisibility()
    if ShouldShowGUI() then
        RegisterEvents();
        RestartGUI();
    else
        UnregisterEvents();
        HideGUI();
    end
end

local function AnnounceSpawnTime(current_zone_only, send_data_for_parsing)

    current_zone_only = string.lower(current_zone_only);

    if current_zone_only == "0" or current_zone_only == "false" or current_zone_only == "all" then
        current_zone_only = false;
    end

    local current_zone = GetZoneText();
    local spawn_timers = {};
    local entries = 0; -- No way to get size of table :(
    for name, boss in pairs(REGISTERED_BOSSES) do
        if (not current_zone_only) or current_zone == boss.zone then
            if IsDead(name) then
                local server_death_time = "";
                if send_data_for_parsing then
                    server_death_time = " (" .. SERVER_DEATH_TIME_PREFIX .. GetServerDeathTime(name) .. ")";
                end
                spawn_timers[name] = {GetSpawnTime(name), server_death_time};
                entries = entries + 1;
            end
        end
    end

    if entries > 0 then
        local channel = "SAY";
        local SKULL = "{skull}";
        for name, timers in pairs(spawn_timers) do
            local spawn_time = timers[1];
            local server_death_time = timers[2];
            local msg = SKULL .. name .. SKULL .. ": " .. spawn_time .. server_death_time;
            SendChatMessage(msg, channel, nil, nil);
        end
    else
        WBT:Print("No spawn timers registered");
    end
end

local function StartWorldBossDeathTimer(...)

    local function MaybeAnnounceSpawnTimer(remaining_time, boss_name)
        local announce_times = {1, 2, 3, 4, 5, 10, 30, 1*60, 5*60, 10*60};
        if SetContainsValue(announce_times, remaining_time)
                and IsInZoneOfBoss(boss_name)
                and IsKillInfoSafe({}) then
            AnnounceSpawnTime("true", false);
        end
    end

    local function HasRespawned(name)
        local t_death = WBT.db.global.boss[name].t_death;
        local t_now = GetServerTime();
        return (t_now - t_death > MAX_RESPAWN_TIME);
    end

    local function StartTimer(boss, time, freq, text)
        -- Always kill the previous frame and start a new one.
        if boss.timer ~= nil then
            boss.timer.kill = true;
        end
        boss.timer = CreateFrame("Frame");
        boss.timer.kill = false;

        local until_time = GetServerTime() + time;
        local UpdateInterval = freq;
        boss.timer:SetScript("OnUpdate", function(self, elapsed)
                if self.TimeSinceLastUpdate == nil then
                    self.TimeSinceLastUpdate = 0;
                end
                self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;

                if (self.TimeSinceLastUpdate > UpdateInterval) then
                    self.remaining_time = until_time - GetServerTime();

                    MaybeAnnounceSpawnTimer(self.remaining_time, boss.name);

                    if self.remaining_time < 0 or self.kill then
                        if IsInZoneOfBoss(boss.name) then
                            FlashClientIcon();
                        end
                        KillUpdateFrame(self);
                        UpdateGUIVisibility();
                    end

                    if gui ~= nil then
                        gui:Update();
                    end
                    self.TimeSinceLastUpdate = 0;
                end
            end);
        return timer;
    end

    for _, name in ipairs({...}) do -- To iterate varargs, note that they have to be in a table. They will be expanded otherwise.
        if WBT.db.global.boss[name] and not HasRespawned(name) then
            local timer_duration = GetSpawnTimeSec(name);
            StartTimer(WBT.db.global.boss[name], timer_duration, 1, REGISTERED_BOSSES[name].color .. name .. BASE_COLOR .. ": ");
        end
    end
end

local function InitDeathTrackerFrame()
    if boss_death_frame ~= nil then
        return
    end

    boss_death_frame = CreateFrame("Frame");
    boss_death_frame:SetScript("OnEvent", function(event, ...)
		--local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, extraArg1, extraArg2, extraArg3, extraArg4, extraArg5, extraArg6, extraArg7, extraArg8, extraArg9, extraArg10 = CombatLogGetCurrentEventInfo()
		local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName = CombatLogGetCurrentEventInfo()

             if eventType == "UNIT_DIED" and IsBoss(destName) then
                 SetDeathTime(GetServerTime(), destName); -- Don't use timestamp from varags. It's not synchronized with server time.
                 StartWorldBossDeathTimer(destName);
             end
        end);
end

local function PlayAlertSound(boss_name)
    local sound_type = WBT.db.global.sound_type;
    local sound_enabled = WBT.db.global.sound_enabled;

    local soundfile = REGISTERED_BOSSES[boss_name].soundfile;
    if sound_type == "classic" then
        soundfile = DEFAULT_SOUND_FILE;
    end

    if sound_enabled then
        PlaySoundFile(soundfile, "Master");
    else
        WBT:Print("Sound is off: enable with /WBT sound enable");
    end
end

local function InitCombatScannerFrame()
    if boss_combat_frame ~= nil then
        return
    end

    boss_combat_frame = CreateFrame("Frame");

    local time_out = 60*2; -- Legacy world bosses SHOULD die in this time.
    boss_combat_frame.t_next = 0;

    function boss_combat_frame:DoScanWorldBossCombat(event, ...)
		local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName = CombatLogGetCurrentEventInfo()

        local t = GetServerTime();

        if IsBoss(destName) and t > self.t_next then
            WBT:Print(GetColoredBossName(destName) .. " is now engaged in combat!");
            PlayAlertSound(destName);
            FlashClientIcon();
            self.t_next = t + time_out;
        end
    end

    boss_combat_frame:SetScript("OnEvent", boss_combat_frame.DoScanWorldBossCombat);
end

function WBT:OnInitialize()
end

local function PrintKilledBosses()
    WBT:Print("Tracked world bosses killed:");

    local none_killed_text = "None";
    local num_saved_world_bosses = GetNumSavedWorldBosses();
    if num_saved_world_bosses == 0 then
        WBT:Print(none_killed_text);
    else
        local none_killed = true;
        for i=1, num_saved_world_bosses do
            local name = GetSavedWorldBossInfo(i);
            if IsBoss(name) then
                none_killed = false;
                WBT:Print(GetColoredBossName(name))
            end
        end
        if none_killed then
            WBT:Print(none_killed_text);
        end
    end
end

local function ResetKillInfo()
    WBT:Print("Reseting all kill info.");
    for k, v in pairs(WBT.db.global.boss) do
        WBT.db.global.boss[k].timer.kill = true;
        WBT.db.global.boss[k] = nil;
    end
end

local function SlashHandler(input)

    -- print(input);
    -- input = input:trim();
    arg1, arg2 = strsplit(" ", input);
    -- print(arg1, arg2);

    local function PrintHelp()
        local indent = "   ";
        WBT:Print("How to use: /wbt <arg1> <arg2>");
        WBT:Print("arg1: \'r\' --> resets all kill info.");
        WBT:Print("arg1: \'s\' --> prints your saved bosses.");
        WBT:Print("arg1: \'a\' --> announces timers for boss in zone (and all if arg2 == \'all\').");
        WBT:Print("arg1: \'show\' --> shows the timers frame.");
        WBT:Print("arg1: \'hide\' --> hides the timers frame.");
        WBT:Print("arg1: \'sound\' --> ...");
        WBT:Print("arg2: " .. indent .. "\'disable\'");
        WBT:Print("arg2: " .. indent .. "\'enable\'");
        WBT:Print("arg2: " .. indent .. "\'classic\' --> War drum alert.");
        WBT:Print("arg2: " .. indent .. "\'fancy\' --> Sometimes custom fancy alerts.");
    end

    if arg1 == "hide" then
        HideGUI();
    elseif arg1 == "show" then
        ShowGUI();
    elseif arg1 == "ann" or arg1 == "a" or arg1 == "announce" or arg1 == "yell" or arg1 == "tell" then
        if arg2 == nil then
            input = "true";
        end
        local error_msgs = {};
        if not IsKillInfoSafe(error_msgs) then
            SendChatMessage("{cross}Warning{cross}: Timer might be incorrect!", "SAY", nil, nil);
            for i, v in ipairs(error_msgs) do
                SendChatMessage("{cross}" .. v .. "{cross}", "SAY", nil, nil);
            end
        end
        AnnounceSpawnTime(input, true);
    elseif arg1 == "r" or arg1 == "reset" or arg1 == "restart" then
        ResetKillInfo();
    elseif arg1 == "s" or arg1 == "saved" or arg1 == "save" then
        PrintKilledBosses();
    elseif arg1 == "request" then
        RequestKillData();
    elseif arg1 == "sound" then
        sound_type_args = {"classic", "fancy"};
        enable_args = {"enable", "unmute"};
        disable_args = {"disable", "mute"};
        if SetContainsValue(sound_type_args, arg2) then
            WBT.db.global.sound_type = arg2;
            WBT:Print("SoundType: " .. arg2);
        elseif SetContainsValue(enable_args, arg2) then
            WBT.db.global.sound_enabled = true;
            WBT:Print("Sound: " .. "enabled");
        elseif SetContainsValue(disable_args, arg2) then
            WBT.db.global.sound_enabled = false;
            WBT:Print("Sound: " .. "disabled");
        else
            PrintHelp();
        end
    else
        PrintHelp();
    end

end

local function StartVisibilityHandler()
    local visibilty_handler_frame = CreateFrame("Frame");
    visibilty_handler_frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
    visibilty_handler_frame:SetScript("OnEvent",
        function(e, ...)
            UpdateGUIVisibility();
        end
    );
end

local function ShareTimers()
    AnnounceSpawnTime("true", true);
end

function WBT:GetGui()
    return gui;
end

function WBT:InitChatParsing()

    local function InitRequestParsing()
        local function PlayerSentRequest(sender)
            -- Since \b and alike doesnt exist: use "frontier pattern": %f[%A]
            return string.match(sender, GetUnitName("player") .. "%f[%A]") ~= nil;
        end

        local request_parser = CreateFrame("Frame");
        local answered_requesters = {};
        request_parser:RegisterEvent("CHAT_MSG_SAY");
        request_parser:SetScript("OnEvent",
            function(self, event, msg, sender)
                if event == "CHAT_MSG_SAY"
                        and msg == CHAT_MSG_TIMER_REQUEST
                        and not SetContainsKey(answered_requesters, sender)
                        and not PlayerSentRequest(sender)
                        and IsKillInfoSafe({}) then

                    ShareTimers();
                    answered_requesters[sender] = sender;
                end
            end
        );
    end

    local function InitSharedTimersParsing()
        local timer_parser = CreateFrame("Frame");
        timer_parser:RegisterEvent("CHAT_MSG_SAY");
        timer_parser:SetScript("OnEvent",
            function(self, event, msg, sender)
                if event == "CHAT_MSG_SAY" and string.match(msg, SERVER_DEATH_TIME_PREFIX) ~= nil then
                    local boss_name, server_death_time = string.match(msg, ".*([A-Z][a-z]+).*" .. SERVER_DEATH_TIME_PREFIX .. "(%d+)");
                    if IsBoss(boss_name) and not IsDead(boss_name) then
                        WBT:Print("Received " .. GetColoredBossName(boss_name) .. " timer from: " .. sender);
                        SetDeathTime(server_death_time, boss_name);
                        StartWorldBossDeathTimer(boss_name);
                    end
                end
            end
        );
    end

    InitRequestParsing();
    InitSharedTimersParsing();

end

function WBT:OnEnable()
	WBT.db = LibStub("AceDB-3.0"):New("WorldBossTimersDB", defaults);
    -- self.db.global = defaults.global; -- Resets the global profile in case I mess up the table
    -- /run for k, v in pairs(WBT.db.global) do WBT.db.global[k] = nil end -- Also resets global profile, but from in-game

    InitDeathTrackerFrame(); -- Todo: make sure this can't be called twice in same session
    InitCombatScannerFrame();
    InitGUI();

    if AnyDead() or IsBossZone() then
        RegisterEvents();
        StartWorldBossDeathTimer(unpack(GetBossNames()));
        ShowGUI();
    else
        HideGUI();
    end

    StartVisibilityHandler();

    self:RegisterChatCommand("wbt", SlashHandler);
    self:RegisterChatCommand("worldbosstimers", SlashHandler);

    self:InitChatParsing();

end

function WBT:OnDisable()
end

