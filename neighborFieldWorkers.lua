NeighborFieldWorkers = {
    MOD_NAME = g_currentModName,
    MOD_DIR = g_currentModDirectory,

    SETTINGS_FILENAME = "neighborFieldWorkers.xml",
    SETTINGS_XML_ROOT = "neighborFieldWorkers",
    SETTINGS_VERSION = 1,

    NEIGHBOR_FARM_NAME = "Neighbour Farms",
    NEIGHBOR_FARM_COLOR = 4,

    maxNeighbors = 0,
    maxNeighborsMin = 0,
    maxNeighborsMax = 99,
    allowExistingContractCompetition = false,
    allowForcedFieldPreparation = false,
    transparentSpawnModeEnabled = true,
    fieldEdgeStartModeEnabled = true,
    headlandsFirstModeEnabled = true,
    debugLogsEnabled = false,
    debugLogsInfoEnabled = false,
    debugLogsAttachEnabled = false,
    debugLogsHelperEnabled = false,
    debugLogsMissionEnabled = false,

    savegameDirectory = nil,
    settingsLoadedFromSavegame = false,
    neighborFarmId = nil,

    scanIntervalMs = 30000,
    scanTimerMs = 0,
    scanLogIntervalMs = 30000,
    nextScanLogAtMs = 0,
    assignmentUpdateIntervalMs = 1000,
    assignmentUpdateTimerMs = 0,

    neighborFarmRetryIntervalMs = 30000,
    nextNeighborFarmRetryAtMs = 0,

    settingsHooksInstalled = false,
    missionHooksInstalled = false,
    missionLimitHookInstalled = false,
    missionFieldSpawnHookInstalled = false,
    singleplayerMergeHookInstalled = false,
    singleplayerMergeSuppressed = false,
    originalMergeFarmlandsForSingleplayer = nil,
    inGameMenuHooksInstalled = false,
    inGameMenuPageInstalled = false,
    vehicleResetHookInstalled = false,
    aiJobStopHookInstalled = false,
    originalAIJobStop = nil,
    combineDriveHookInstalled = false,
    fieldCourseDetectionHookInstalled = false,
    fieldCourseDriveHookInstalled = false,
    pendingFieldDetectionByVehicle = {},
    nextPendingFieldDetectionCleanupAtMs = 0,
    missionMoneyHookInstalled = false,
    originalMissionAddMoney = nil,
    originalMissionAddMoneyChange = nil,
    allowNeighborDebit = false,
    nextEconomyMaintenanceAtMs = 0,
    helperBaseCapacity = nil,
    dynamicNeighborHelpersAdded = 0,
    dynamicNeighborHelperIndices = {},
    nextHelperPoolLogAtMs = 0,
    harvestTankResetThresholdPct = 0.80,
    stoneTankResetThresholdPct = 0.80,
    harvestDeepDiagIntervalMs = 3000,
    harvestVehicleRoleCache = {},
    harvestVehicleRoleUncertainCache = {},
    stoneVehicleRoleCache = {},
    stoneVehicleRoleUncertainCache = {},
    vehicleInfoMetaCache = {},
    vehicleInfoSizeCache = {},
    nextHarvestFilterLogAtMs = 0,
    nextStoneFilterLogAtMs = 0,
    helperNamePools = {},
    neighborHelperNamesByIndex = {},
    weedToolSupportedStatesCache = {},
    debugConsoleCommandsRegistered = false,
    readyPrepBlockedCycles = 0,

    settingsValueElement = nil,
    settingsCompetitionElement = nil,
    settingsForcePrepareElement = nil,
    settingsSectionHeaderAdded = false,
    settingsWarnedMissingRefs = false,
    settingsStateUpdateInProgress = false,

    activeAssignments = {},
    savedAssignmentKeys = {},
    savedAssignmentFieldIds = {},
    savedAssignmentsMissingLog = {},

    mergeOverrideFunctions = {},
    lastMergeSuppressLogMs = 0,
    lastMergeSuppressMethod = nil,

    initialReconcileLogged = false,
    shutdownHandled = false
}

local function nfwClamp(value, minValue, maxValue)
    if value == nil then
        return minValue
    end

    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function nfwContainsAny(text, patterns)
    if text == nil or patterns == nil then
        return false
    end

    for _, pattern in ipairs(patterns) do
        if string.find(text, pattern, 1, true) ~= nil then
            return true
        end
    end

    return false
end

local function nfwSortCandidatesByScore(candidates)
    table.sort(candidates, function(a, b)
        return Utils.getNoNil(a ~= nil and a.score or nil, 0) > Utils.getNoNil(b ~= nil and b.score or nil, 0)
    end)
end

local function nfwNormalizeXmlPath(path)
    local normalized = string.lower(tostring(path or ""))
    normalized = string.gsub(normalized, "\\", "/")
    normalized = string.gsub(normalized, "^%$", "")
    normalized = string.gsub(normalized, "^%./", "")
    return normalized
end

local function nfwGetXmlBasename(path)
    local normalized = nfwNormalizeXmlPath(path)
    local base = string.match(normalized, "([^/]+%.xml)$")
    if base == nil then
        base = string.match(normalized, "([^/]+)$")
    end
    return base
end

local function nfwBuildConfigurationsCacheKey(configurations)
    if type(configurations) ~= "table" then
        return ""
    end

    local parts = {}
    for key, value in pairs(configurations) do
        table.insert(parts, string.format("%s=%s", tostring(key), tostring(value)))
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local NFW_INFO_LOG_ENABLED = false
local NFW_ATTACH_DEBUG_LOG_ENABLED = false
local NFW_HELPER_DIAG_LOG_ENABLED = false
local NFW_MISSION_DEBUG_LOG_ENABLED = false
local NFW_ATTACH_STEP_WAIT_MS = 2000
local NFW_ATTACH_FAILED_PASSES_BEFORE_RESPAWN = 1
local NFW_ATTACH_FAILED_PASSES_BEFORE_SIDE_SWAP = 4
local NFW_ATTACH_RETRY_WAIT_MS = 750
local NFW_ATTACH_ATTEMPTS_PER_PASS = 6
local NFW_REAR_IMPLEMENT_BASE_DIST = 4.0
local NFW_FRONT_IMPLEMENT_BASE_DIST = 4.0
local NFW_IMPLEMENT_SPACING_BUFFER = 1.0
local NFW_XT390_FAST_REAR_WAIT_MS = 300
local NFW_ATTACH_SIDE_SCAN_DISTANCE = 30.0
local NFW_INTERNAL_MISSION_GEN_MAX_PER_REQUEST = 1
local NFW_INTERNAL_MISSION_GEN_MAX_FIELDS_TO_PREPARE = 120
local NFW_PENDING_START_BLOCKED_TIMEOUT_MS = 45000
local NFW_READY_PASS_MAX_ROUNDS = 3
local NFW_READY_TYPE_RETRY_BEFORE_PREP = 6
local NFW_READY_PREP_BLOCK_MAX_CYCLES = 3
local NFW_MISSION_GEN_USE_READY_PRECHECK = false
local NFW_FORCE_RELOCATE_SKIP_DISTANCE_M = 0.5
local NFW_FORCE_RELOCATE_SKIP_ROT_RAD = 0.09
local NFW_FORCE_RELOCATE_PRECHECK_DISTANCE_M = 2.0
local NFW_FORCE_RELOCATE_PRECHECK_ROT_RAD = 0.35
local NFW_EDGE_TARGET_INSET_M = 2.5
local NFW_EDGE_FRONT_CLEARANCE_M = 2.0
local NFW_SOW_ZERO_AREA_RECOVERY_TRIGGER_MS = 18000

local function nfwLogInfo(...)
    if NFW_INFO_LOG_ENABLED and Logging ~= nil and Logging.info ~= nil then
        Logging.info(...)
    end
end

local function nfwLogAttachDebug(...)
    if not NFW_ATTACH_DEBUG_LOG_ENABLED or Logging == nil then
        return
    end

    if Logging.warning ~= nil then
        Logging.warning(...)
    elseif Logging.info ~= nil then
        Logging.info(...)
    end
end

local function nfwLogHelperDiag(...)
    if not NFW_HELPER_DIAG_LOG_ENABLED or Logging == nil then
        return
    end

    if Logging.warning ~= nil then
        Logging.warning(...)
    elseif Logging.info ~= nil then
        Logging.info(...)
    end
end

local function nfwLogMissionDebug(...)
    if not NFW_MISSION_DEBUG_LOG_ENABLED or Logging == nil then
        return
    end

    if Logging.warning ~= nil then
        Logging.warning(...)
    elseif Logging.info ~= nil then
        Logging.info(...)
    end
end

function NeighborFieldWorkers:refreshDebugLogAggregateState()
    self.debugLogsEnabled = (NFW_INFO_LOG_ENABLED == true)
        or (NFW_ATTACH_DEBUG_LOG_ENABLED == true)
        or (NFW_HELPER_DIAG_LOG_ENABLED == true)
        or (NFW_MISSION_DEBUG_LOG_ENABLED == true)

    self.debugLogsInfoEnabled = NFW_INFO_LOG_ENABLED == true
    self.debugLogsAttachEnabled = NFW_ATTACH_DEBUG_LOG_ENABLED == true
    self.debugLogsHelperEnabled = NFW_HELPER_DIAG_LOG_ENABLED == true
    self.debugLogsMissionEnabled = NFW_MISSION_DEBUG_LOG_ENABLED == true
end

function NeighborFieldWorkers:getDebugLogStatusText()
    return string.format(
        "info=%s attach=%s helper=%s mission=%s",
        tostring(NFW_INFO_LOG_ENABLED),
        tostring(NFW_ATTACH_DEBUG_LOG_ENABLED),
        tostring(NFW_HELPER_DIAG_LOG_ENABLED),
        tostring(NFW_MISSION_DEBUG_LOG_ENABLED)
    )
end

function NeighborFieldWorkers:setDebugLogsEnabled(enabled)
    local state = enabled == true
    NFW_INFO_LOG_ENABLED = state
    NFW_ATTACH_DEBUG_LOG_ENABLED = state
    NFW_HELPER_DIAG_LOG_ENABLED = state
    NFW_MISSION_DEBUG_LOG_ENABLED = state
    self:refreshDebugLogAggregateState()
end

function NeighborFieldWorkers:setDebugLogChannelEnabled(channel, enabled)
    local channelKey = string.lower(tostring(channel or ""))
    local state = enabled == true

    if channelKey == "info" then
        NFW_INFO_LOG_ENABLED = state
    elseif channelKey == "attach" then
        NFW_ATTACH_DEBUG_LOG_ENABLED = state
    elseif channelKey == "helper" then
        NFW_HELPER_DIAG_LOG_ENABLED = state
    elseif channelKey == "mission" then
        NFW_MISSION_DEBUG_LOG_ENABLED = state
    else
        return false
    end

    self:refreshDebugLogAggregateState()
    return true
end

function NeighborFieldWorkers:getDebugLogChannelEnabled(channel)
    local channelKey = string.lower(tostring(channel or ""))
    if channelKey == "info" then
        return NFW_INFO_LOG_ENABLED == true
    end
    if channelKey == "attach" then
        return NFW_ATTACH_DEBUG_LOG_ENABLED == true
    end
    if channelKey == "helper" then
        return NFW_HELPER_DIAG_LOG_ENABLED == true
    end
    if channelKey == "mission" then
        return NFW_MISSION_DEBUG_LOG_ENABLED == true
    end
    return nil
end

local function nfwParseDebugActionToken(token)
    local value = string.lower(tostring(token or "status"))
    if value == "1" or value == "on" or value == "true" then
        return "set", true
    end
    if value == "0" or value == "off" or value == "false" then
        return "set", false
    end
    if value == "toggle" then
        return "toggle", nil
    end
    if value == "status" or value == "" then
        return "status", nil
    end
    return nil, nil
end

function NeighborFieldWorkers:consoleCommandNfwDebug(mode, value)
    local previousState = self.debugLogsEnabled == true
    local changed = false

    local firstToken = string.lower(tostring(mode or "status"))
    local channelRequested = firstToken == "info"
        or firstToken == "attach"
        or firstToken == "helper"
        or firstToken == "mission"

    if channelRequested then
        local action, actionValue = nfwParseDebugActionToken(value or "status")
        if action == "set" then
            local oldState = self:getDebugLogChannelEnabled(firstToken)
            if self:setDebugLogChannelEnabled(firstToken, actionValue) then
                changed = oldState ~= self:getDebugLogChannelEnabled(firstToken)
            end
        elseif action == "toggle" then
            local oldState = self:getDebugLogChannelEnabled(firstToken)
            if oldState ~= nil and self:setDebugLogChannelEnabled(firstToken, not oldState) then
                changed = true
            end
        elseif action ~= "status" then
            local usage = string.format(
                "[%s] Usage: nfwDebug [on|off|toggle|status] or nfwDebug <info|attach|helper|mission> [on|off|toggle|status]",
                self.MOD_NAME
            )
            if Logging ~= nil and Logging.info ~= nil then
                Logging.info("%s", usage)
            end
            return usage
        end
    else
        local action, actionValue = nfwParseDebugActionToken(firstToken)
        if action == "set" then
            self:setDebugLogsEnabled(actionValue)
            changed = previousState ~= self.debugLogsEnabled
        elseif action == "toggle" then
            local currentlyEnabled = NFW_INFO_LOG_ENABLED
                or NFW_ATTACH_DEBUG_LOG_ENABLED
                or NFW_HELPER_DIAG_LOG_ENABLED
                or NFW_MISSION_DEBUG_LOG_ENABLED
            self:setDebugLogsEnabled(not currentlyEnabled)
            changed = true
        elseif action ~= "status" then
            local usage = string.format(
                "[%s] Usage: nfwDebug [on|off|toggle|status] or nfwDebug <info|attach|helper|mission> [on|off|toggle|status]",
                self.MOD_NAME
            )
            if Logging ~= nil and Logging.info ~= nil then
                Logging.info("%s", usage)
            end
            return usage
        end
    end

    if changed then
        self:saveSettingsToSavegame()
    end

    local message = string.format("[%s] Debug logs: %s", self.MOD_NAME, self:getDebugLogStatusText())
    if Logging ~= nil and Logging.info ~= nil then
        Logging.info("%s", message)
    end
    return message
end

function NeighborFieldWorkers:consoleCommandNfwTransparentMode(mode)
    local action, actionValue = nfwParseDebugActionToken(mode or "status")
    if action == nil then
        local usage = string.format(
            "[%s] Usage: nfwTransparentMode [on|off|toggle|status]",
            self.MOD_NAME
        )
        if Logging ~= nil and Logging.info ~= nil then
            Logging.info("%s", usage)
        end
        return usage
    end

    local changed = false
    local currentState = self.transparentSpawnModeEnabled == true
    if action == "set" then
        self.transparentSpawnModeEnabled = actionValue == true
        changed = currentState ~= self.transparentSpawnModeEnabled
    elseif action == "toggle" then
        self.transparentSpawnModeEnabled = not currentState
        changed = true
    end

    if changed then
        self:saveSettingsToSavegame()
    end

    local message = string.format(
        "[%s] Transparent spawn mode: %s",
        self.MOD_NAME,
        tostring(self.transparentSpawnModeEnabled == true)
    )
    if Logging ~= nil and Logging.info ~= nil then
        Logging.info("%s", message)
    end
    return message
end

function NeighborFieldWorkers:consoleCommandNfwFieldEdgeStart(mode)
    local action, actionValue = nfwParseDebugActionToken(mode or "status")
    if action == nil then
        local usage = string.format(
            "[%s] Usage: nfwFieldEdgeStart [on|off|toggle|status]",
            self.MOD_NAME
        )
        if Logging ~= nil and Logging.info ~= nil then
            Logging.info("%s", usage)
        end
        return usage
    end

    local changed = false
    local currentState = self.fieldEdgeStartModeEnabled == true
    if action == "set" then
        self.fieldEdgeStartModeEnabled = actionValue == true
        changed = currentState ~= self.fieldEdgeStartModeEnabled
    elseif action == "toggle" then
        self.fieldEdgeStartModeEnabled = not currentState
        changed = true
    end

    if changed then
        self:saveSettingsToSavegame()
    end

    local message = string.format(
        "[%s] Field edge start mode: %s",
        self.MOD_NAME,
        tostring(self.fieldEdgeStartModeEnabled == true)
    )
    if Logging ~= nil and Logging.info ~= nil then
        Logging.info("%s", message)
    end
    return message
end

function NeighborFieldWorkers:consoleCommandNfwHeadlandsFirst(mode)
    local action, actionValue = nfwParseDebugActionToken(mode or "status")
    if action == nil then
        local usage = string.format(
            "[%s] Usage: nfwHeadlandsFirst [on|off|toggle|status]",
            self.MOD_NAME
        )
        if Logging ~= nil and Logging.info ~= nil then
            Logging.info("%s", usage)
        end
        return usage
    end

    local changed = false
    local currentState = self.headlandsFirstModeEnabled == true
    if action == "set" then
        self.headlandsFirstModeEnabled = actionValue == true
        changed = currentState ~= self.headlandsFirstModeEnabled
    elseif action == "toggle" then
        self.headlandsFirstModeEnabled = not currentState
        changed = true
    end

    if changed then
        self:saveSettingsToSavegame()
    end

    local message = string.format(
        "[%s] Headlands-first mode: %s",
        self.MOD_NAME,
        tostring(self.headlandsFirstModeEnabled == true)
    )
    if Logging ~= nil and Logging.info ~= nil then
        Logging.info("%s", message)
    end
    return message
end

function NeighborFieldWorkers:registerDebugConsoleCommands()
    if self.debugConsoleCommandsRegistered then
        return
    end
    if addConsoleCommand == nil then
        return
    end

    addConsoleCommand("nfwDebug",
        "Toggle NeighborFieldWorkers debug logs ([on|off|toggle|status] or <info|attach|helper|mission> [on|off|toggle|status])",
        "consoleCommandNfwDebug", self)
    addConsoleCommand("gsNfwDebug",
        "Toggle NeighborFieldWorkers debug logs ([on|off|toggle|status] or <info|attach|helper|mission> [on|off|toggle|status])",
        "consoleCommandNfwDebug", self)
    addConsoleCommand("nfwTransparentMode",
        "Toggle NFW transparent spawn mode ([on|off|toggle|status])",
        "consoleCommandNfwTransparentMode", self)
    addConsoleCommand("gsNfwTransparentMode",
        "Toggle NFW transparent spawn mode ([on|off|toggle|status])",
        "consoleCommandNfwTransparentMode", self)
    addConsoleCommand("nfwFieldEdgeStart",
        "Toggle NFW field-edge start mode ([on|off|toggle|status])",
        "consoleCommandNfwFieldEdgeStart", self)
    addConsoleCommand("gsNfwFieldEdgeStart",
        "Toggle NFW field-edge start mode ([on|off|toggle|status])",
        "consoleCommandNfwFieldEdgeStart", self)
    addConsoleCommand("nfwHeadlandsFirst",
        "Toggle NFW headlands-first mode ([on|off|toggle|status])",
        "consoleCommandNfwHeadlandsFirst", self)
    addConsoleCommand("gsNfwHeadlandsFirst",
        "Toggle NFW headlands-first mode ([on|off|toggle|status])",
        "consoleCommandNfwHeadlandsFirst", self)
    self.debugConsoleCommandsRegistered = true
end

function NeighborFieldWorkers:unregisterDebugConsoleCommands()
    if not self.debugConsoleCommandsRegistered then
        return
    end

    if removeConsoleCommand ~= nil then
        removeConsoleCommand("nfwDebug")
        removeConsoleCommand("gsNfwDebug")
        removeConsoleCommand("nfwTransparentMode")
        removeConsoleCommand("gsNfwTransparentMode")
        removeConsoleCommand("nfwFieldEdgeStart")
        removeConsoleCommand("gsNfwFieldEdgeStart")
        removeConsoleCommand("nfwHeadlandsFirst")
        removeConsoleCommand("gsNfwHeadlandsFirst")
    end
    self.debugConsoleCommandsRegistered = false
end

local function nfwToSingleLineText(value, maxLen)
    local text = tostring(value or "")
    text = string.gsub(text, "[\r\n]+", " ")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if maxLen ~= nil and maxLen > 0 and string.len(text) > maxLen then
        text = string.sub(text, 1, maxLen) .. "..."
    end
    return text
end

local function nfwFormatAiRangeList(ranges, maxEntries)
    if type(ranges) ~= "table" then
        return "none"
    end

    local entries = {}
    local limit = math.min(#ranges, maxEntries or 2)
    for i = 1, limit do
        local value = ranges[i]
        if type(value) == "table" then
            if value.fruitType ~= nil then
                table.insert(
                    entries,
                    string.format(
                        "{fruit=%s min=%s max=%s map=%s}",
                        tostring(value.fruitType),
                        tostring(value.minGrowthState),
                        tostring(value.maxGrowthState),
                        tostring(value.customMapId)
                    )
                )
            elseif value.fillType ~= nil then
                table.insert(entries, string.format("{fillType=%s}", tostring(value.fillType)))
            else
                local v1 = tostring(value[1])
                local v2 = tostring(value[2])
                local v3 = tostring(value[3])
                local v4 = tostring(value[4])
                table.insert(entries, string.format("[%s,%s,%s,%s]", v1, v2, v3, v4))
            end
        else
            table.insert(entries, nfwToSingleLineText(value, 80))
        end
    end

    if #ranges > limit then
        table.insert(entries, string.format("+%d", #ranges - limit))
    end

    if #entries == 0 then
        return "none"
    end

    return table.concat(entries, ";")
end

local function nfwIsXt390XmlPath(path)
    local normalized = nfwNormalizeXmlPath(path)
    if normalized == "" then
        return false
    end

    if string.find(normalized, "/samasz/xt390/", 1, true) ~= nil then
        return true
    end

    local base = nfwGetXmlBasename(normalized)
    return base == "xt390.xml"
end

local function nfwIsGmd8730XmlPath(path)
    local normalized = nfwNormalizeXmlPath(path)
    if normalized == "" then
        return false
    end

    if string.find(normalized, "/kuhn/gmd8730/", 1, true) ~= nil then
        return true
    end

    local base = nfwGetXmlBasename(normalized)
    return base == "gmd8730.xml"
end

local function nfwIsGmd3123FXmlPath(path)
    local normalized = nfwNormalizeXmlPath(path)
    if normalized == "" then
        return false
    end

    if string.find(normalized, "/kuhn/gmd3123f/", 1, true) ~= nil then
        return true
    end

    local base = nfwGetXmlBasename(normalized)
    return base == "gmd3123f.xml"
end

local function nfwIsMcdonR216XmlPath(path)
    local normalized = nfwNormalizeXmlPath(path)
    if normalized == "" then
        return false
    end

    local isMcdonPath = string.find(normalized, "mcdon", 1, true) ~= nil
        or string.find(normalized, "macdon", 1, true) ~= nil
    local hasR216Token = string.find(normalized, "r216sp", 1, true) ~= nil
        or string.find(normalized, "r216_sp", 1, true) ~= nil
        or string.find(normalized, "/r216/", 1, true) ~= nil
        or string.find(normalized, "r216", 1, true) ~= nil
    if isMcdonPath and hasR216Token then
        return true
    end

    local base = nfwGetXmlBasename(normalized)
    return base == "r216sp.xml"
        or base == "r216_sp.xml"
        or base == "r216.xml"
        or (base ~= nil and string.find(base, "r216", 1, true) ~= nil)
end

local function nfwIsMcdonR216DisplayName(name)
    local text = string.lower(tostring(name or ""))
    if text == "" then
        return false
    end

    return string.find(text, "r216 sp", 1, true) ~= nil
        or string.find(text, "r216sp", 1, true) ~= nil
end

local function nfwIsPickUp900Text(value)
    local text = string.lower(tostring(value or ""))
    if text == "" then
        return false
    end

    return string.find(text, "pickup 900", 1, true) ~= nil
        or string.find(text, "pickup900", 1, true) ~= nil
        or string.find(text, "pick up 900", 1, true) ~= nil
        or string.find(text, "pick-up 900", 1, true) ~= nil
end

local NFW_SUPPORTED_LANGUAGES = {
    de = true,
    en = true,
    fr = true,
    pl = true,
    es = true,
    pt = true
}

local NFW_NEIGHBOR_FARM_NAMES = {
    de = "Nachbarfarmen",
    en = "Neighbour Farms",
    fr = "Fermes voisines",
    pl = "Farmy sąsiadów",
    es = "Granjas vecinas",
    pt = "Quintas vizinhas"
}

local NFW_NEIGHBOR_FARM_NAME_ALIASES = {
    "KI Nachbarn",
    "Neighbor Farms",
    "Neighbour Farms",
    "Nachbarfarmen",
    "Fermes voisines",
    "Farmy sąsiadów",
    "Granjas vecinas",
    "Quintas vizinhas"
}

local NFW_NEIGHBOR_HELPER_PREFIX = {
    de = "Nachbar",
    en = "Neighbour",
    fr = "Voisin",
    pl = "Sąsiad",
    es = "Vecino",
    pt = "Vizinho"
}

local NFW_NEIGHBOR_HELPER_FIRST_NAMES = {
    de = {
        male = { "Hans", "Peter", "Klaus", "Johann", "Nico", "Martin", "Josef", "Andreas", "Stefan", "Thomas" },
        female = { "Anna", "Maria", "Katharina", "Eva", "Claudia", "Sabine", "Petra", "Monika", "Johanna", "Lena" }
    },
    en = {
        male = { "John", "William", "James", "George", "Henry", "Thomas", "Robert", "Samuel", "Michael", "David" },
        female = { "Mary", "Sarah", "Emma", "Elizabeth", "Margaret", "Anne", "Rachel", "Emily", "Laura", "Hannah" }
    },
    fr = {
        male = { "Jean", "Pierre", "Jacques", "Michel", "Andre", "Louis", "Marcel", "Francois", "Philippe", "Laurent" },
        female = { "Marie", "Claire", "Sophie", "Anne", "Elodie", "Isabelle", "Nathalie", "Camille", "Juliette", "Celine" }
    },
    pl = {
        male = { "Jan", "Piotr", "Andrzej", "Krzysztof", "Marek", "Tomasz", "Pawel", "Michal", "Stanislaw", "Wojciech" },
        female = { "Anna", "Maria", "Katarzyna", "Agnieszka", "Ewa", "Zofia", "Barbara", "Magdalena", "Joanna", "Dorota" }
    },
    es = {
        male = { "Jose", "Antonio", "Manuel", "Francisco", "Juan", "Pedro", "Miguel", "Javier", "Carlos", "Luis" },
        female = { "Maria", "Carmen", "Ana", "Isabel", "Dolores", "Pilar", "Lucia", "Elena", "Rosa", "Teresa" }
    },
    pt = {
        male = { "Joao", "Jose", "Manuel", "Antonio", "Joaquim", "Carlos", "Luis", "Pedro", "Miguel", "Francisco" },
        female = { "Maria", "Ana", "Teresa", "Joana", "Sofia", "Carolina", "Helena", "Ines", "Catarina", "Rita" }
    }
}

local function nfwNormalizeName(name)
    if name == nil then
        return nil
    end

    local normalized = string.lower(tostring(name))
    normalized = string.gsub(normalized, "^%s+", "")
    normalized = string.gsub(normalized, "%s+$", "")
    return normalized
end

local function nfwSanitizeHelperIdPart(text)
    local value = string.upper(tostring(Utils.getNoNil(text, "")))
    value = string.gsub(value, "[^A-Z0-9]+", "_")
    value = string.gsub(value, "_+", "_")
    value = string.gsub(value, "^_+", "")
    value = string.gsub(value, "_+$", "")
    if value == "" then
        value = "NEIGHBOR"
    end
    return value
end

local function nfwBuildUniqueHelperIdFromDisplayName(displayName, fallbackIndex)
    local base = nfwSanitizeHelperIdPart(displayName)
    if base == nil or base == "" then
        base = string.format("HELPER_%03d", Utils.getNoNil(fallbackIndex, 0))
    end

    if g_helperManager == nil or g_helperManager.nameToIndex == nil then
        return base
    end

    local candidate = base
    local suffix = 2
    while g_helperManager.nameToIndex[string.upper(candidate)] ~= nil and suffix <= 999 do
        candidate = string.format("%s_%d", base, suffix)
        suffix = suffix + 1
    end

    return candidate
end

function NeighborFieldWorkers:getText(key)
    if g_i18n ~= nil and g_i18n.modEnvironments ~= nil then
        local env = g_i18n.modEnvironments[self.MOD_NAME]
        if env ~= nil and env.texts ~= nil and env.texts[key] ~= nil then
            return env.texts[key]
        end
    end

    return key
end

function NeighborFieldWorkers:getActiveLanguageCode()
    local language = g_languageShort or "en"
    language = string.lower(tostring(language))
    if language == "br" then
        language = "pt"
    end
    if string.len(language) > 2 then
        language = string.sub(language, 1, 2)
    end

    if NFW_SUPPORTED_LANGUAGES[language] then
        return language
    end

    return "en"
end

function NeighborFieldWorkers:getLocalizedNeighborFarmName()
    local language = self:getActiveLanguageCode()
    return NFW_NEIGHBOR_FARM_NAMES[language] or NFW_NEIGHBOR_FARM_NAMES.en
end

function NeighborFieldWorkers:isNeighborFarmNameCandidate(name)
    local normalized = nfwNormalizeName(name)
    if normalized == nil or normalized == "" then
        return false
    end

    local localizedName = self:getLocalizedNeighborFarmName()
    if nfwNormalizeName(localizedName) == normalized then
        return true
    end

    for _, knownName in ipairs(NFW_NEIGHBOR_FARM_NAME_ALIASES) do
        if nfwNormalizeName(knownName) == normalized then
            return true
        end
    end

    return false
end

function NeighborFieldWorkers:getLocalizedNeighborHelperPrefix()
    local language = self:getActiveLanguageCode()
    return NFW_NEIGHBOR_HELPER_PREFIX[language] or NFW_NEIGHBOR_HELPER_PREFIX.en
end

function NeighborFieldWorkers:refillNeighborHelperNamePool(language)
    local locale = NFW_NEIGHBOR_HELPER_FIRST_NAMES[language] or NFW_NEIGHBOR_HELPER_FIRST_NAMES.en
    local pool = {}

    if locale ~= nil then
        if locale.male ~= nil then
            for _, firstName in ipairs(locale.male) do
                table.insert(pool, tostring(firstName))
            end
        end
        if locale.female ~= nil then
            for _, firstName in ipairs(locale.female) do
                table.insert(pool, tostring(firstName))
            end
        end
    end

    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    self.helperNamePools[language] = pool
end

function NeighborFieldWorkers:getRandomLocalizedNeighborFirstName()
    local language = self:getActiveLanguageCode()
    if self.helperNamePools == nil then
        self.helperNamePools = {}
    end

    local pool = self.helperNamePools[language]
    if pool == nil or #pool == 0 then
        self:refillNeighborHelperNamePool(language)
        pool = self.helperNamePools[language]
    end

    if pool ~= nil and #pool > 0 then
        return table.remove(pool)
    end

    return "Alex"
end

function NeighborFieldWorkers:getRandomNeighborHelperDisplayName()
    local prefix = self:getLocalizedNeighborHelperPrefix()
    local firstName = self:getRandomLocalizedNeighborFirstName()
    return string.format("%s %s", tostring(prefix), tostring(firstName))
end

function NeighborFieldWorkers:isInvalidNeighborHelperTitle(title)
    local normalized = nfwNormalizeName(title)
    if normalized == nil or normalized == "" then
        return true
    end

    if string.len(normalized) <= 1 then
        return true
    end

    local upperTitle = string.upper(tostring(title))
    if string.find(upperTitle, "NFW_NEIGHBOR_HELPER_", 1, true) ~= nil then
        return true
    end

    if string.find(upperTitle, "NFW_", 1, true) ~= nil then
        return true
    end

    if string.match(upperTitle, "^HELPER_[0-9_]+$") ~= nil then
        return true
    end

    if string.match(upperTitle, "^[A-Z0-9_]+$") ~= nil and string.find(upperTitle, "_", 1, true) ~= nil then
        return true
    end

    return false
end

function NeighborFieldWorkers:getOrCreateNeighborHelperNameForIndex(helperIndex)
    if helperIndex == nil then
        return self:getRandomNeighborHelperDisplayName()
    end

    if self.neighborHelperNamesByIndex == nil then
        self.neighborHelperNamesByIndex = {}
    end

    local indexKey = tostring(helperIndex)
    local cached = self.neighborHelperNamesByIndex[indexKey]
    if cached ~= nil and cached ~= "" then
        return cached
    end

    local generated = self:getRandomNeighborHelperDisplayName()
    self.neighborHelperNamesByIndex[indexKey] = generated
    return generated
end

function NeighborFieldWorkers:forceLocalizedHelperTitle(helper, helperIndex, assignment)
    if helper == nil then
        return nil
    end

    local currentTitle = tostring(Utils.getNoNil(helper.title, ""))
    local forcedTitle = nil

    if assignment ~= nil and assignment.helperDisplayName ~= nil and assignment.helperDisplayName ~= "" then
        forcedTitle = assignment.helperDisplayName
    else
        forcedTitle = self:getOrCreateNeighborHelperNameForIndex(helperIndex)
    end

    if forcedTitle == nil or forcedTitle == "" then
        forcedTitle = self:getRandomNeighborHelperDisplayName()
    end

    if currentTitle ~= forcedTitle or self:isInvalidNeighborHelperTitle(currentTitle) then
        helper.title = forcedTitle
    end
    if tostring(Utils.getNoNil(helper.name, "")) ~= tostring(forcedTitle) then
        helper.name = forcedTitle
    end

    if assignment ~= nil then
        assignment.helperDisplayName = forcedTitle
    end

    return forcedTitle
end

function NeighborFieldWorkers:refreshModHelperTitles()
    if g_helperManager == nil then
        return
    end

    if self.dynamicNeighborHelperIndices ~= nil and g_helperManager.getHelperByIndex ~= nil then
        for helperIndex, _ in pairs(self.dynamicNeighborHelperIndices) do
            local helper = g_helperManager:getHelperByIndex(helperIndex)
            if helper ~= nil then
                local desiredTitle = self:getOrCreateNeighborHelperNameForIndex(helperIndex)
                if self:isInvalidNeighborHelperTitle(helper.title) or tostring(helper.title) ~= tostring(desiredTitle) then
                    helper.title = desiredTitle
                end
                if tostring(Utils.getNoNil(helper.name, "")) ~= tostring(desiredTitle) then
                    helper.name = desiredTitle
                end
            end
        end
    end

    if g_helperManager.helpers == nil then
        return
    end

    for helperName, helper in pairs(g_helperManager.helpers) do
        if helper ~= nil then
            local nameUpper = string.upper(tostring(helperName or helper.name or ""))
            if string.find(nameUpper, "NFW_NEIGHBOR_HELPER_", 1, true) ~= nil
                or string.find(nameUpper, "NFWNH_HELPER_", 1, true) ~= nil then
                local helperIndex = helper.index
                local desiredTitle = self:getOrCreateNeighborHelperNameForIndex(helperIndex)
                if self:isInvalidNeighborHelperTitle(helper.title) or tostring(helper.title) ~= tostring(desiredTitle) then
                    helper.title = desiredTitle
                end
                if tostring(Utils.getNoNil(helper.name, "")) ~= tostring(desiredTitle) then
                    helper.name = desiredTitle
                end
            end
        end
    end
end

function NeighborFieldWorkers:getHelperForAssignment(assignment, vehicle)
    local helper = nil
    local helperIndex = nil

    if assignment ~= nil then
        if assignment.giantsJob ~= nil then
            helperIndex = assignment.giantsJob.helperIndex
        end
        if helperIndex == nil then
            helperIndex = assignment.helperIndex
        end
    end

    local sourceVehicle = vehicle
    if sourceVehicle == nil and assignment ~= nil then
        sourceVehicle = assignment.vehicle
    end

    if helperIndex == nil and sourceVehicle ~= nil and sourceVehicle.getJob ~= nil then
        local okJob, activeJob = pcall(sourceVehicle.getJob, sourceVehicle)
        if okJob and activeJob ~= nil then
            helperIndex = activeJob.helperIndex
        end
    end

    if g_helperManager ~= nil and g_helperManager.getHelperByIndex ~= nil and helperIndex ~= nil then
        helper = g_helperManager:getHelperByIndex(helperIndex)
    end

    if helper == nil and sourceVehicle ~= nil and sourceVehicle.getCurrentHelper ~= nil then
        local okHelper, currentHelper = pcall(sourceVehicle.getCurrentHelper, sourceVehicle)
        if okHelper and currentHelper ~= nil then
            helper = currentHelper
            if helperIndex == nil then
                helperIndex = currentHelper.index
            end
        end
    end

    return helper, helperIndex
end

function NeighborFieldWorkers:assignLocalizedHelperNameToAssignment(assignment, vehicle)
    if assignment == nil then
        return false
    end

    local helper, helperIndex = self:getHelperForAssignment(assignment, vehicle)
    if helper == nil then
        return false
    end

    if assignment.helperIndex ~= helperIndex then
        assignment.helperDisplayName = nil
        assignment.helperOriginalTitle = helper.title
        assignment.helperOriginalName = helper.name
        assignment.helperIndex = helperIndex
    elseif assignment.helperOriginalTitle == nil then
        assignment.helperOriginalTitle = helper.title
        assignment.helperOriginalName = helper.name
    end

    local helperDisplayName = self:forceLocalizedHelperTitle(helper, helperIndex, assignment)
    if helperDisplayName == nil or helperDisplayName == "" then
        return false
    end

    assignment.helperIndex = helperIndex
    return true
end

function NeighborFieldWorkers:getAssignmentHelperDisplayName(assignment)
    if assignment == nil then
        return nil
    end

    if assignment.helperDisplayName ~= nil and assignment.helperDisplayName ~= "" then
        return assignment.helperDisplayName
    end

    if self:assignLocalizedHelperNameToAssignment(assignment, assignment.vehicle) then
        if assignment.helperDisplayName ~= nil and assignment.helperDisplayName ~= "" then
            return assignment.helperDisplayName
        end
    end

    local helper, helperIndex = self:getHelperForAssignment(assignment, assignment.vehicle)
    if helper ~= nil then
        assignment.helperIndex = helperIndex
        local helperDisplayName = self:forceLocalizedHelperTitle(helper, helperIndex, assignment)
        if helperDisplayName ~= nil and helperDisplayName ~= "" then
            assignment.helperDisplayName = tostring(helperDisplayName)
            return assignment.helperDisplayName
        end
    end

    return nil
end

function NeighborFieldWorkers:restoreAssignmentHelperTitle(assignment)
    if assignment == nil then
        return
    end

    if assignment.helperIndex ~= nil
        and assignment.helperOriginalTitle ~= nil
        and g_helperManager ~= nil
        and g_helperManager.getHelperByIndex ~= nil then
        local helper = g_helperManager:getHelperByIndex(assignment.helperIndex)
        if helper ~= nil then
            local assignedTitle = tostring(Utils.getNoNil(assignment.helperDisplayName, ""))
            local currentTitle = tostring(Utils.getNoNil(helper.title, ""))
            if assignedTitle == "" or currentTitle == assignedTitle then
                helper.title = assignment.helperOriginalTitle
            end
            if assignment.helperOriginalName ~= nil and assignment.helperOriginalName ~= "" then
                local currentName = tostring(Utils.getNoNil(helper.name, ""))
                if assignedTitle == "" or currentName == assignedTitle then
                    helper.name = assignment.helperOriginalName
                end
            end
        end
    end

    assignment.helperDisplayName = nil
    assignment.helperOriginalTitle = nil
    assignment.helperOriginalName = nil
    assignment.helperIndex = nil
end

function NeighborFieldWorkers:getSavegameSettingsPath()
    if self.savegameDirectory == nil or self.savegameDirectory == "" then
        return nil
    end

    return self.savegameDirectory .. "/" .. self.SETTINGS_FILENAME
end

function NeighborFieldWorkers:loadSettingsFromSavegame()
    local path = self:getSavegameSettingsPath()
    if path == nil then
        return
    end

    if not fileExists(path) then
        return
    end

    local xmlFile = loadXMLFile("neighborFieldWorkers_settings", path)
    if xmlFile == nil then
        return
    end

    self.maxNeighbors = nfwClamp(
        Utils.getNoNil(getXMLInt(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#maxNeighbors"), 0),
        self.maxNeighborsMin,
        self.maxNeighborsMax
    )
    self.allowExistingContractCompetition = Utils.getNoNil(
        getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#allowExistingContractCompetition"),
        false
    )
    self.allowForcedFieldPreparation = Utils.getNoNil(
        getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#allowForcedFieldPreparation"),
        false
    )
    self.transparentSpawnModeEnabled = Utils.getNoNil(
        getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#transparentSpawnModeEnabled"),
        false
    )
    self.fieldEdgeStartModeEnabled = Utils.getNoNil(
        getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#fieldEdgeStartModeEnabled"),
        false
    )
    self.headlandsFirstModeEnabled = Utils.getNoNil(
        getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#headlandsFirstModeEnabled"),
        true
    )
    local legacyDebugLogsEnabled = Utils.getNoNil(
        getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#debugLogsEnabled"),
        false
    )
    local infoFlag = getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#debugLogsInfoEnabled")
    local attachFlag = getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#debugLogsAttachEnabled")
    local helperFlag = getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#debugLogsHelperEnabled")
    local missionFlag = getXMLBool(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#debugLogsMissionEnabled")

    if infoFlag == nil and attachFlag == nil and helperFlag == nil and missionFlag == nil then
        self:setDebugLogsEnabled(legacyDebugLogsEnabled)
    else
        self:setDebugLogChannelEnabled("info", Utils.getNoNil(infoFlag, legacyDebugLogsEnabled))
        self:setDebugLogChannelEnabled("attach", Utils.getNoNil(attachFlag, legacyDebugLogsEnabled))
        self:setDebugLogChannelEnabled("helper", Utils.getNoNil(helperFlag, legacyDebugLogsEnabled))
        self:setDebugLogChannelEnabled("mission", Utils.getNoNil(missionFlag, false))
    end
    self.neighborFarmId = getXMLInt(xmlFile, self.SETTINGS_XML_ROOT .. ".farm#id")
    self.savedAssignmentKeys = {}
    self.savedAssignmentFieldIds = {}
    self.savedAssignmentsMissingLog = {}

    local index = 0
    while true do
        local key = string.format("%s.assignments.assignment(%d)#key", self.SETTINGS_XML_ROOT, index)
        local assignmentKey = getXMLString(xmlFile, key)
        if assignmentKey == nil then
            break
        end

        self.savedAssignmentKeys[tostring(assignmentKey)] = true
        local fieldId = getXMLInt(xmlFile,
            string.format("%s.assignments.assignment(%d)#fieldId", self.SETTINGS_XML_ROOT, index))
        if fieldId ~= nil then
            self.savedAssignmentFieldIds[tostring(assignmentKey)] = fieldId
        end
        index = index + 1
    end

    delete(xmlFile)

    local savedCount = 0
    for _, _ in pairs(self.savedAssignmentKeys) do
        savedCount = savedCount + 1
    end
    nfwLogInfo(
        "[%s] Savegame-Einstellungen geladen: maxNeighbors=%d allowExistingContractCompetition=%s allowForcedFieldPreparation=%s transparentSpawnModeEnabled=%s fieldEdgeStartModeEnabled=%s headlandsFirstModeEnabled=%s debugLogsEnabled=%s debugInfo=%s debugAttach=%s debugHelper=%s debugMission=%s neighborFarmId=%s savedAssignments=%d path=%s",
        self.MOD_NAME,
        self.maxNeighbors,
        tostring(self.allowExistingContractCompetition),
        tostring(self.allowForcedFieldPreparation),
        tostring(self.transparentSpawnModeEnabled),
        tostring(self.fieldEdgeStartModeEnabled),
        tostring(self.headlandsFirstModeEnabled),
        tostring(self.debugLogsEnabled),
        tostring(self.debugLogsInfoEnabled),
        tostring(self.debugLogsAttachEnabled),
        tostring(self.debugLogsHelperEnabled),
        tostring(self.debugLogsMissionEnabled),
        tostring(self.neighborFarmId),
        savedCount,
        tostring(path)
    )
end

function NeighborFieldWorkers:collectPersistedAssignmentKeys()
    local keys = {}

    for key, assignment in pairs(self.activeAssignments) do
        if key ~= nil and assignment ~= nil and assignment.mission ~= nil then
            local status = assignment.mission.status
            if status ~= MissionStatus.FINISHED and status ~= MissionStatus.DISMISSED then
                keys[tostring(key)] = true
            end
        end
    end

    if g_missionManager ~= nil and g_missionManager.getMissions ~= nil then
        for _, mission in ipairs(g_missionManager:getMissions()) do
            local missionKey = self:getMissionKey(mission)
            if missionKey ~= nil and self:isAllowedMissionType(mission) then
                local isActive = mission.status == MissionStatus.PREPARING or mission.status == MissionStatus.RUNNING
                local hasVehicles = mission.spawnedVehicles == true
                    or (mission.vehicles ~= nil and #mission.vehicles > 0)

                if (isActive or hasVehicles) and self:isMissionOwnedByNeighborFarm(mission) then
                    keys[tostring(missionKey)] = true
                end
            end
        end
    end

    return keys
end

function NeighborFieldWorkers:getPersistedFieldIdForAssignmentKey(assignmentKey)
    if assignmentKey == nil then
        return nil
    end

    local keyText = tostring(assignmentKey)
    local assignment = self.activeAssignments[assignmentKey]
    if assignment == nil then
        assignment = self.activeAssignments[keyText]
    end
    if assignment ~= nil and assignment.mission ~= nil then
        local fieldId = self:getMissionFieldId(assignment.mission)
        if fieldId ~= nil then
            return fieldId
        end
    end

    if g_missionManager ~= nil and g_missionManager.getMissions ~= nil then
        for _, mission in ipairs(g_missionManager:getMissions()) do
            local missionKey = self:getMissionKey(mission)
            if missionKey ~= nil and tostring(missionKey) == keyText then
                local fieldId = self:getMissionFieldId(mission)
                if fieldId ~= nil then
                    return fieldId
                end
            end
        end
    end

    return self.savedAssignmentFieldIds[keyText]
end

function NeighborFieldWorkers:saveSettingsToSavegame()
    local path = self:getSavegameSettingsPath()
    if path == nil then
        return
    end

    local xmlFile = createXMLFile("neighborFieldWorkers_settings", path, self.SETTINGS_XML_ROOT)
    if xmlFile == nil then
        return
    end

    setXMLInt(xmlFile, self.SETTINGS_XML_ROOT .. "#version", self.SETTINGS_VERSION)
    setXMLInt(xmlFile, self.SETTINGS_XML_ROOT .. ".settings#maxNeighbors", self.maxNeighbors)
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#allowExistingContractCompetition",
        self.allowExistingContractCompetition == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#allowForcedFieldPreparation",
        self.allowForcedFieldPreparation == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#transparentSpawnModeEnabled",
        self.transparentSpawnModeEnabled == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#fieldEdgeStartModeEnabled",
        self.fieldEdgeStartModeEnabled == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#headlandsFirstModeEnabled",
        self.headlandsFirstModeEnabled == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#debugLogsEnabled",
        self.debugLogsEnabled == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#debugLogsInfoEnabled",
        self.debugLogsInfoEnabled == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#debugLogsAttachEnabled",
        self.debugLogsAttachEnabled == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#debugLogsHelperEnabled",
        self.debugLogsHelperEnabled == true
    )
    setXMLBool(
        xmlFile,
        self.SETTINGS_XML_ROOT .. ".settings#debugLogsMissionEnabled",
        self.debugLogsMissionEnabled == true
    )
    if self.neighborFarmId ~= nil then
        setXMLInt(xmlFile, self.SETTINGS_XML_ROOT .. ".farm#id", self.neighborFarmId)
    end

    local persistedKeys = self:collectPersistedAssignmentKeys()
    self.savedAssignmentKeys = persistedKeys
    local persistedFieldIds = {}

    local index = 0
    for assignmentKey, _ in pairs(persistedKeys) do
        local key = string.format("%s.assignments.assignment(%d)#key", self.SETTINGS_XML_ROOT, index)
        setXMLString(xmlFile, key, tostring(assignmentKey))
        local fieldId = self:getPersistedFieldIdForAssignmentKey(assignmentKey)
        if fieldId ~= nil then
            setXMLInt(xmlFile, string.format("%s.assignments.assignment(%d)#fieldId", self.SETTINGS_XML_ROOT, index),
                fieldId)
            persistedFieldIds[tostring(assignmentKey)] = fieldId
        end
        index = index + 1
    end
    self.savedAssignmentFieldIds = persistedFieldIds

    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function NeighborFieldWorkers:loadMap()
    self.scanTimerMs = self.scanIntervalMs
    self.assignmentUpdateTimerMs = 0
    self.nextScanLogAtMs = 0
    self.nextNeighborFarmRetryAtMs = 0
    self.activeAssignments = {}
    self.settingsLoadedFromSavegame = false
    self.inGameMenuPageInstalled = false
    self.savedAssignmentKeys = {}
    self.savedAssignmentFieldIds = {}
    self.savedAssignmentsMissingLog = {}
    self.initialReconcileLogged = false
    self.shutdownHandled = false
    self.missionMoneyHookInstalled = false
    self.originalMissionAddMoney = nil
    self.originalMissionAddMoneyChange = nil
    self.aiJobStopHookInstalled = false
    self.originalAIJobStop = nil
    self.combineDriveHookInstalled = false
    self.fieldCourseDetectionHookInstalled = false
    self.fieldCourseDriveHookInstalled = false
    self.pendingFieldDetectionByVehicle = {}
    self.nextPendingFieldDetectionCleanupAtMs = 0
    self.allowNeighborDebit = false
    self.nextEconomyMaintenanceAtMs = 0
    self.helperBaseCapacity = nil
    self.dynamicNeighborHelpersAdded = 0
    self.dynamicNeighborHelperIndices = {}
    self.nextHelperPoolLogAtMs = 0
    self.harvestVehicleRoleCache = {}
    self.harvestVehicleRoleUncertainCache = {}
    self.stoneVehicleRoleCache = {}
    self.stoneVehicleRoleUncertainCache = {}
    self.vehicleInfoMetaCache = {}
    self.nextHarvestFilterLogAtMs = 0
    self.nextStoneFilterLogAtMs = 0
    self.helperNamePools = {}
    self.neighborHelperNamesByIndex = {}
    self.weedToolSupportedStatesCache = {}
    self.transparentSpawnModeEnabled = true
    self.fieldEdgeStartModeEnabled = true
    self.headlandsFirstModeEnabled = true
    self.debugLogsEnabled = false
    self.debugLogsInfoEnabled = false
    self.debugLogsAttachEnabled = false
    self.debugLogsHelperEnabled = false
    self.debugLogsMissionEnabled = false
    self:setDebugLogsEnabled(false)
    self.debugConsoleCommandsRegistered = false
    self.readyPrepBlockedCycles = 0
    self.settingsValueElement = nil
    self.settingsCompetitionElement = nil
    self.settingsForcePrepareElement = nil
    self.settingsSectionHeaderAdded = false
    self.settingsWarnedMissingRefs = false

    self:tryInstallSettingsHooks()
    self:tryInstallMissionHooks()
    self:tryInstallInGameMenuHooks()
    self:tryInstallInGameMenuPage()
    self:tryInstallMissionLimitHook()
    self:tryInstallMissionFieldSpawnHook()
    self:tryInstallSingleplayerMergeHook()
    self:tryInstallVehicleResetHook()
    self:tryInstallAIJobStopHook()
    self:tryInstallCombineDriveHook()
    self:tryInstallFieldCourseDetectionHook()
    self:tryInstallFieldCourseDriveHook()
    self:enforceNoMergedFarms()
    self:registerDebugConsoleCommands()

    nfwLogInfo(
        "[%s] Initialisiert. Max neighbors=%d allowExistingContractCompetition=%s allowForcedFieldPreparation=%s transparentSpawnModeEnabled=%s fieldEdgeStartModeEnabled=%s headlandsFirstModeEnabled=%s",
        self.MOD_NAME,
        self.maxNeighbors,
        tostring(self.allowExistingContractCompetition),
        tostring(self.allowForcedFieldPreparation),
        tostring(self.transparentSpawnModeEnabled),
        tostring(self.fieldEdgeStartModeEnabled),
        tostring(self.headlandsFirstModeEnabled)
    )
end

function NeighborFieldWorkers:deleteMap()
    self:stopNeighborAIJobsForShutdown()
    self:unregisterDebugConsoleCommands()

    self.settingsValueElement = nil
    self.settingsCompetitionElement = nil
    self.settingsForcePrepareElement = nil
    self.settingsSectionHeaderAdded = false
    self.settingsWarnedMissingRefs = false
    self.inGameMenuPageInstalled = false

    self.activeAssignments = {}
    self.savedAssignmentKeys = {}
    self.savedAssignmentFieldIds = {}
    self.savedAssignmentsMissingLog = {}
    self.initialReconcileLogged = false
    self.shutdownHandled = false
    self.missionMoneyHookInstalled = false
    self.originalMissionAddMoney = nil
    self.originalMissionAddMoneyChange = nil
    self.aiJobStopHookInstalled = false
    self.originalAIJobStop = nil
    self.combineDriveHookInstalled = false
    self.fieldCourseDetectionHookInstalled = false
    self.fieldCourseDriveHookInstalled = false
    self.pendingFieldDetectionByVehicle = {}
    self.nextPendingFieldDetectionCleanupAtMs = 0
    self.allowNeighborDebit = false
    self.nextEconomyMaintenanceAtMs = 0
    self.helperBaseCapacity = nil
    self.dynamicNeighborHelpersAdded = 0
    self.dynamicNeighborHelperIndices = {}
    self.nextHelperPoolLogAtMs = 0
    self.harvestVehicleRoleCache = {}
    self.harvestVehicleRoleUncertainCache = {}
    self.stoneVehicleRoleCache = {}
    self.stoneVehicleRoleUncertainCache = {}
    self.vehicleInfoMetaCache = {}
    self.nextHarvestFilterLogAtMs = 0
    self.nextStoneFilterLogAtMs = 0
    self.helperNamePools = {}
    self.neighborHelperNamesByIndex = {}
    self.weedToolSupportedStatesCache = {}
    self.debugConsoleCommandsRegistered = false
    self.readyPrepBlockedCycles = 0
end

function NeighborFieldWorkers:isMissionExiting()
    return g_currentMission == nil or g_currentMission.isExitingGame == true
end

function NeighborFieldWorkers:stopNeighborAIJobsForShutdown()
    if self.shutdownHandled then
        return
    end
    self.shutdownHandled = true

    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end

    local stopMessage = nil
    if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
        stopMessage = AIMessageSuccessStoppedByUser.new()
    end

    local stoppedVehicles = 0
    local activeAssignments = 0

    for _, assignment in pairs(self.activeAssignments) do
        if assignment ~= nil then
            activeAssignments = activeAssignments + 1

            local seenVehicles = {}
            local vehicles = {}

            if assignment.vehicle ~= nil then
                table.insert(vehicles, assignment.vehicle)
                seenVehicles[assignment.vehicle] = true
            end

            local mission = assignment.mission
            if mission ~= nil and mission.vehicles ~= nil then
                for _, missionVehicle in ipairs(mission.vehicles) do
                    if missionVehicle ~= nil and not seenVehicles[missionVehicle] then
                        table.insert(vehicles, missionVehicle)
                        seenVehicles[missionVehicle] = true
                    end
                end
            end

            for _, vehicle in ipairs(vehicles) do
                if vehicle ~= nil and not vehicle.isDeleted and vehicle.stopCurrentAIJob ~= nil and vehicle.getIsAIActive ~= nil then
                    local okActive, isActive = pcall(vehicle.getIsAIActive, vehicle)
                    if okActive and isActive then
                        local okStop = pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
                        if okStop then
                            stoppedVehicles = stoppedVehicles + 1
                        end
                    end
                end
            end

            assignment.aiStarted = false
            assignment.aiMode = nil
            assignment.giantsJob = nil
            assignment.aiStartTimeMs = nil
            assignment.aiInactiveSinceMs = nil
            assignment.aiFarSinceMs = nil
            assignment.noMovementSinceMs = nil
            assignment.lastMovementCheckX = nil
            assignment.lastMovementCheckZ = nil
            assignment.nextStartAfterAttachMs = 0
        end
    end

    if activeAssignments > 0 or stoppedVehicles > 0 then
        nfwLogInfo(
            "[%s] Shutdown-Schutz aktiv: assignments=%d stoppedVehicles=%d",
            self.MOD_NAME,
            activeAssignments,
            stoppedVehicles
        )
    end
end

function NeighborFieldWorkers:update(dt)
    self:tryInstallSettingsHooks()
    self:tryInstallMissionHooks()
    self:tryInstallInGameMenuHooks()
    self:tryInstallInGameMenuPage()
    self:tryInstallMissionLimitHook()
    self:tryInstallMissionFieldSpawnHook()
    self:tryInstallSingleplayerMergeHook()
    self:tryInstallVehicleResetHook()
    self:tryInstallAIJobStopHook()
    self:tryInstallCombineDriveHook()
    self:tryInstallFieldCourseDetectionHook()
    self:tryInstallFieldCourseDriveHook()
    self:enforceNoMergedFarms()
    self:tryInstallMissionMoneyHooks()

    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end

    if self:isMissionExiting() then
        self:stopNeighborAIJobsForShutdown()
        return
    end

    if not self.settingsLoadedFromSavegame and g_currentMission.missionInfo ~= nil then
        self.savegameDirectory = g_currentMission.missionInfo.savegameDirectory
        self:loadSettingsFromSavegame()
        self.settingsLoadedFromSavegame = true
    end

    local hasTrackedAssignments = next(self.activeAssignments) ~= nil
    local shouldMaintainAssignments = self.maxNeighbors > 0
        or hasTrackedAssignments
        or self.neighborFarmId ~= nil

    self.assignmentUpdateTimerMs = self.assignmentUpdateTimerMs - dt
    if self.assignmentUpdateTimerMs <= 0 then
        self.assignmentUpdateTimerMs = self.assignmentUpdateIntervalMs
        self:reconcileExistingNeighborMissions()

        hasTrackedAssignments = next(self.activeAssignments) ~= nil
        shouldMaintainAssignments = self.maxNeighbors > 0
            or hasTrackedAssignments
            or self.neighborFarmId ~= nil

        if shouldMaintainAssignments then
            if not self:ensureNeighborFarm() then
                return
            end

            self:ensureDynamicHelperPoolCapacity()
            self:updateActiveAssignments()
        end
    end

    local now = g_time or 0
    self:cleanupPendingFieldDetectionOverrides(now)

    if now >= self.nextEconomyMaintenanceAtMs then
        self.nextEconomyMaintenanceAtMs = now + 5000
        if self:getActiveAssignmentCount() <= 0 then
            self:setNeighborFarmBalance(1, "IDLE_ENFORCE")
        end
    end

    self.scanTimerMs = self.scanTimerMs - dt
    if self.scanTimerMs <= 0 then
        self.scanTimerMs = self.scanIntervalMs

        if self.maxNeighbors > 0 or hasTrackedAssignments then
            if not self:ensureNeighborFarm() then
                return
            end

            self:logMissionScanSummary()
            if self.maxNeighbors > 0 then
                self:tryStartNewNeighborMission()
            end
        end
    end
end

function NeighborFieldWorkers:tryInstallMissionHooks()
    if self.missionHooksInstalled then
        return
    end

    if type(Mission00) ~= "table"
        or type(Mission00.loadMission00Finished) ~= "function"
        or type(FSCareerMissionInfo) ~= "table"
        or type(FSCareerMissionInfo.saveToXMLFile) ~= "function" then
        return
    end

    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(mission, node)
        self:onMission00Loaded(mission, node)
    end)

    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(missionInfo)
        self:onSavegameWrite(missionInfo)
    end)

    self.missionHooksInstalled = true
end

function NeighborFieldWorkers:tryInstallInGameMenuHooks()
    if self.inGameMenuHooksInstalled then
        return
    end

    if type(InGameMenu) ~= "table" or type(InGameMenu.onLoadMapFinished) ~= "function" then
        return
    end

    InGameMenu.onLoadMapFinished = Utils.appendedFunction(InGameMenu.onLoadMapFinished, function(inGameMenu)
        self:tryInstallInGameMenuPage(inGameMenu)
    end)

    self.inGameMenuHooksInstalled = true
end

function NeighborFieldWorkers:moveInGameMenuPageAfter(inGameMenu, page, targetPage)
    if inGameMenu == nil or page == nil then
        return
    end

    local targetPosition = #inGameMenu.pagingElement.elements + 1
    if targetPage ~= nil then
        for i, element in ipairs(inGameMenu.pagingElement.elements) do
            if element == targetPage then
                targetPosition = i + 1
                break
            end
        end
    end

    for i, element in ipairs(inGameMenu.pagingElement.elements) do
        if element == page then
            if i ~= targetPosition then
                table.remove(inGameMenu.pagingElement.elements, i)
                table.insert(inGameMenu.pagingElement.elements, targetPosition, element)
            end
            break
        end
    end

    for i, mapping in ipairs(inGameMenu.pagingElement.pages) do
        if mapping.element == page then
            if i ~= targetPosition then
                table.remove(inGameMenu.pagingElement.pages, i)
                table.insert(inGameMenu.pagingElement.pages, targetPosition, mapping)
            end
            break
        end
    end

    for i, frame in ipairs(inGameMenu.pageFrames) do
        if frame == page then
            if i ~= targetPosition then
                table.remove(inGameMenu.pageFrames, i)
                table.insert(inGameMenu.pageFrames, targetPosition, frame)
            end
            break
        end
    end

    inGameMenu.pagingElement:updatePageMapping()
    inGameMenu:rebuildTabList()
end

function NeighborFieldWorkers:tryInstallInGameMenuPage(optionalInGameMenu)
    if self.inGameMenuPageInstalled then
        return
    end

    local inGameMenu = optionalInGameMenu
    if inGameMenu == nil and g_inGameMenu ~= nil then
        inGameMenu = g_inGameMenu
    end
    if inGameMenu == nil and g_gui ~= nil and g_gui.screenControllers ~= nil and type(InGameMenu) == "table" then
        inGameMenu = g_gui.screenControllers[InGameMenu]
    end
    if inGameMenu == nil then
        return
    end

    if inGameMenu.pageNeighborFieldWorkers ~= nil then
        self.inGameMenuPageInstalled = true
        return
    end

    if type(InGameMenuNeighborJobsFrame) ~= "table" or type(InGameMenuNeighborJobsFrame.register) ~= "function" then
        return
    end

    InGameMenuNeighborJobsFrame.register()

    local xmlFile = loadXMLFile("IngameMenuFrameRefXML", self.MOD_DIR .. "InGameMenuNeighborJobsFrameRef.xml")
    if xmlFile == 0 then
        nfwLogInfo("[%s] InGameMenu Seite konnte nicht geladen werden (FrameRef XML fehlt)", self.MOD_NAME)
        return
    end

    if inGameMenu.controlIDs ~= nil then
        inGameMenu.controlIDs.pageNeighborFieldWorkers = nil
    end

    g_gui:loadGuiRec(xmlFile, "FrameReferences", inGameMenu.pagingElement, inGameMenu)
    inGameMenu:exposeControlsAsFields("pageNeighborFieldWorkers")
    inGameMenu.pagingElement:updatePageMapping()
    delete(xmlFile)

    local frame = g_gui:resolveFrameReference(inGameMenu.pageNeighborFieldWorkers)
    if frame == nil then
        nfwLogInfo("[%s] InGameMenu Seite konnte nicht registriert werden (FrameReference nil)", self.MOD_NAME)
        return
    end

    if frame.initialize ~= nil then
        inGameMenu:registerPage(frame, nil, function()
            return true
        end)
        local iconFileName = Utils.getFilename("images/menuIcon.dds", self.MOD_DIR)
        inGameMenu:addPageTab(frame, iconFileName, GuiUtils.getUVs({ 0, 0, 1024, 1024 }))

        frame:onGuiSetupFinished()
        frame:initialize()
    else
        nfwLogInfo("[%s] InGameMenu Seite konnte nicht initialisiert werden (initialize fehlt)", self.MOD_NAME)
        return
    end

    self:moveInGameMenuPageAfter(inGameMenu, frame, inGameMenu.pageContracts)

    self.inGameMenuPageInstalled = true
    nfwLogInfo("[%s] InGameMenu Seite registriert: pageNeighborFieldWorkers", self.MOD_NAME)
end

function NeighborFieldWorkers:tryInstallVehicleResetHook()
    if self.vehicleResetHookInstalled then
        return
    end

    if g_messageCenter == nil or MessageType == nil or MessageType.VEHICLE_RESET == nil then
        return
    end

    g_messageCenter:subscribe(MessageType.VEHICLE_RESET, self.onVehicleResetMessage, self)
    self.vehicleResetHookInstalled = true
end

function NeighborFieldWorkers:onVehicleResetMessage(oldVehicle, newVehicle)
    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end

    if oldVehicle == nil and newVehicle == nil then
        return
    end

    for _, assignment in pairs(self.activeAssignments) do
        if assignment ~= nil and assignment.mission ~= nil and assignment.mission.vehicles ~= nil then
            local affected = false
            if assignment.vehicle ~= nil and assignment.vehicle == oldVehicle then
                assignment.vehicle = newVehicle
                affected = true
            end

            for _, vehicle in ipairs(assignment.mission.vehicles) do
                if vehicle == oldVehicle or vehicle == newVehicle then
                    affected = true
                    break
                end
            end

            if affected then
                local ox, _, oz = 0, 0, 0
                if oldVehicle ~= nil and oldVehicle.rootNode ~= nil then
                    ox, _, oz = getWorldTranslation(oldVehicle.rootNode)
                end
                local nx, _, nz = 0, 0, 0
                if newVehicle ~= nil and newVehicle.rootNode ~= nil then
                    nx, _, nz = getWorldTranslation(newVehicle.rootNode)
                end

                nfwLogInfo(
                    "[%s] VEHICLE_RESET erkannt: mission=%s oldPos=(%.1f/%.1f) newPos=(%.1f/%.1f) aiStarted=%s",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    ox,
                    oz,
                    nx,
                    nz,
                    tostring(assignment.aiStarted)
                )

                if assignment.aiStarted then
                    assignment.aiStarted = false
                    assignment.aiMode = nil
                    assignment.aiStartTimeMs = nil
                    assignment.aiInactiveSinceMs = nil
                    assignment.aiFarSinceMs = nil
                    assignment.noMovementSinceMs = nil
                    assignment.lastMovementCheckX = nil
                    assignment.lastMovementCheckZ = nil
                    assignment.stuckCheckAnchorX = nil
                    assignment.stuckCheckAnchorZ = nil
                    assignment.stuckCheckAnchorAtMs = 0
                    assignment.attachAlignMode = 1
                    assignment.attachFailedPasses = 0
                    self:resetAttachWorkflowState(assignment)
                    assignment.forceDirectStart = true
                    assignment.forceRecoveryReposition = true
                    assignment.recoveredFromSave = false
                    assignment.nextStartAfterAttachMs = 0
                    assignment.nextStartDelayLogAtMs = 0
                    assignment.nextAttachDebugLogAtMs = 0
                    assignment.nextResourceTopupAtMs = 0
                    assignment.nextNoHelperLogAtMs = 0
                    assignment.nextFrontLiftEnforceAtMs = 0
                    assignment.lastObservedAiImplementCount = nil
                    assignment.aiImplementCountStableSinceMs = 0
                    self:tryStartPendingAssignment(assignment)
                end
            end
        end
    end
end

function NeighborFieldWorkers:tryInstallMissionLimitHook()
    if self.missionLimitHookInstalled then
        return
    end

    if type(MissionManager) ~= "table" or type(MissionManager.hasFarmReachedMissionLimit) ~= "function" then
        return
    end

    MissionManager.hasFarmReachedMissionLimit = Utils.overwrittenFunction(
        MissionManager.hasFarmReachedMissionLimit,
        function(missionManager, superFunc, farmId)
            if NeighborFieldWorkers ~= nil and NeighborFieldWorkers:isNeighborFarm(farmId) then
                return false
            end

            return superFunc(missionManager, farmId)
        end
    )

    self.missionLimitHookInstalled = true
end

function NeighborFieldWorkers:tryInstallMissionFieldSpawnHook()
    if self.missionFieldSpawnHookInstalled then
        return
    end

    if type(AbstractMission) ~= "table"
        or type(AbstractMission.spawnVehicle) ~= "function"
        or type(AbstractMission.isSpawnSpaceAvailable) ~= "function" then
        return
    end

    AbstractMission.isSpawnSpaceAvailable = Utils.overwrittenFunction(
        AbstractMission.isSpawnSpaceAvailable,
        function(mission, superFunc)
            if NeighborFieldWorkers ~= nil and NeighborFieldWorkers:shouldMissionSpawnVehiclesAtField(mission) then
                return true
            end

            return superFunc(mission)
        end
    )

    AbstractMission.spawnVehicle = Utils.overwrittenFunction(
        AbstractMission.spawnVehicle,
        function(mission, superFunc, info)
            if NeighborFieldWorkers ~= nil and NeighborFieldWorkers:shouldMissionSpawnVehiclesAtField(mission) then
                local ok, handled = pcall(NeighborFieldWorkers.spawnMissionVehicleAtField, NeighborFieldWorkers, mission,
                    info)
                if ok and handled then
                    return
                end

                nfwLogInfo(
                    "[%s] Feld-Spawn Hook Fallback auf Standard-Spawn: mission=%s",
                    NeighborFieldWorkers.MOD_NAME,
                    tostring(NeighborFieldWorkers:getMissionKey(mission))
                )
            end

            return superFunc(mission, info)
        end
    )

    if type(AbstractMission.onSpawnedVehicle) == "function" then
        AbstractMission.onSpawnedVehicle = Utils.overwrittenFunction(
            AbstractMission.onSpawnedVehicle,
            function(mission, superFunc, vehicles, vehicleLoadState, loadingInfo)
                superFunc(mission, vehicles, vehicleLoadState, loadingInfo)

                if NeighborFieldWorkers == nil then
                    return
                end
                if type(VehicleLoadingState) == "table" and vehicleLoadState ~= VehicleLoadingState.OK then
                    return
                end
                if not NeighborFieldWorkers:shouldUseTransparentSpawnModeForMission(mission) then
                    return
                end

                NeighborFieldWorkers:hideMissionVehiclesUntilHelperStart(mission, vehicles)
            end
        )
    end

    self.missionFieldSpawnHookInstalled = true
end

function NeighborFieldWorkers:logSingleplayerMergeSuppressed(methodLabel)
    local now = g_time or 0
    if self.lastMergeSuppressMethod ~= methodLabel or now >= self.lastMergeSuppressLogMs + 10000 then
        self.lastMergeSuppressMethod = methodLabel
        self.lastMergeSuppressLogMs = now
        nfwLogInfo("[%s] Singleplayer-Farm-Merge unterdrueckt: method=%s", self.MOD_NAME, tostring(methodLabel))
    end
end

function NeighborFieldWorkers:getNoMergeOverride(methodLabel)
    if self.mergeOverrideFunctions[methodLabel] == nil then
        self.mergeOverrideFunctions[methodLabel] = function(farmManager)
            if farmManager ~= nil then
                farmManager.mergedFarms = nil
            end

            if NeighborFieldWorkers ~= nil then
                NeighborFieldWorkers.singleplayerMergeSuppressed = true
                NeighborFieldWorkers:logSingleplayerMergeSuppressed(methodLabel)
            end
        end
    end

    return self.mergeOverrideFunctions[methodLabel]
end

function NeighborFieldWorkers:tryOverrideMergeMethod(targetTable, methodName, sourceLabel)
    if type(targetTable) ~= "table" then
        return false
    end

    local existing = targetTable[methodName]
    if type(existing) ~= "function" then
        return false
    end

    local methodLabel = string.format("%s.%s", tostring(sourceLabel), tostring(methodName))
    local override = self:getNoMergeOverride(methodLabel)
    if existing ~= override then
        targetTable[methodName] = override
        self.singleplayerMergeSuppressed = true
        nfwLogInfo("[%s] Singleplayer-Merge Hook gesetzt: %s", self.MOD_NAME, methodLabel)
        return true
    end

    return false
end

function NeighborFieldWorkers:applySingleplayerMergeOverrides()
    local changed = false
    local mergeMethodNames = {
        "mergeFarmlandsForSingleplayer",
        "mergeFarmsForSingleplayer",
        "mergeFarmsSingleplayer",
        "mergeSingleplayerFarms"
    }

    for _, methodName in ipairs(mergeMethodNames) do
        if self:tryOverrideMergeMethod(FarmManager, methodName, "FarmManager") then
            changed = true
        end

        if g_farmManager ~= nil then
            if self:tryOverrideMergeMethod(g_farmManager, methodName, "g_farmManager") then
                changed = true
            end

            local mt = getmetatable(g_farmManager)
            if mt ~= nil and type(mt.__index) == "table" then
                if self:tryOverrideMergeMethod(mt.__index, methodName, "g_farmManager.__index") then
                    changed = true
                end
            end
        end
    end

    return changed
end

function NeighborFieldWorkers:tryInstallSingleplayerMergeHook()
    self:applySingleplayerMergeOverrides()

    if self.singleplayerMergeHookInstalled then
        return
    end

    if type(FarmlandManager) ~= "table" or type(FarmlandManager.loadFromXMLFile) ~= "function" then
        return
    end

    FarmlandManager.loadFromXMLFile = Utils.prependedFunction(
        FarmlandManager.loadFromXMLFile,
        function(_farmlandManager, _xmlFilename)
            self:applySingleplayerMergeOverrides()
        end
    )

    self.singleplayerMergeHookInstalled = true
end

function NeighborFieldWorkers:enforceNoMergedFarms()
    if g_farmManager ~= nil then
        g_farmManager.mergedFarms = nil
    end
    self:applySingleplayerMergeOverrides()
end

function NeighborFieldWorkers:onMission00Loaded(mission, _)
    if mission == nil or mission.missionInfo == nil then
        return
    end

    self.savegameDirectory = mission.missionInfo.savegameDirectory
    self:loadSettingsFromSavegame()
    self.settingsLoadedFromSavegame = true
    self:updateSettingsElementState()

    if mission:getIsServer() then
        self:enforceNoMergedFarms()
        self:ensureNeighborFarm()
    end
end

function NeighborFieldWorkers:normalizeSingleplayerCareerMoney()
    if self.savegameDirectory == nil or self.savegameDirectory == "" then
        return
    end

    if g_currentMission == nil
        or g_currentMission.missionDynamicInfo == nil
        or g_currentMission.missionDynamicInfo.isMultiplayer then
        return
    end

    if g_currentMission.getFarmId == nil
        or g_farmManager == nil
        or g_farmManager.getFarmById == nil then
        return
    end

    local playerFarmId = g_currentMission:getFarmId()
    local playerFarm = g_farmManager:getFarmById(playerFarmId)
    if playerFarm == nil then
        return
    end

    local playerMoney = playerFarm.money
    if type(playerMoney) ~= "number" and playerFarm.getBalance ~= nil then
        local okBalance, balance = pcall(playerFarm.getBalance, playerFarm)
        if okBalance and type(balance) == "number" then
            playerMoney = balance
        end
    end

    if type(playerMoney) ~= "number" then
        return
    end

    local path = self.savegameDirectory .. "/careerSavegame.xml"
    if not fileExists(path) then
        return
    end

    local xmlFile = loadXMLFile("neighborFieldWorkers_careerSavegame", path)
    if xmlFile == nil or xmlFile == 0 then
        return
    end

    local normalizedMoney = math.floor(playerMoney + 0.5)
    setXMLInt(xmlFile, "careerSavegame.statistics#money", normalizedMoney)
    saveXMLFile(xmlFile)
    delete(xmlFile)

    nfwLogInfo(
        "[%s] Karrieregeld auf Spielerfarm normalisiert: farmId=%s money=%d",
        self.MOD_NAME,
        tostring(playerFarmId),
        normalizedMoney
    )
end

function NeighborFieldWorkers:onSavegameWrite(missionInfo)
    if missionInfo == nil then
        return
    end

    self.savegameDirectory = missionInfo.savegameDirectory
    self:saveSettingsToSavegame()

    local ok, err = pcall(function()
        self:normalizeSingleplayerCareerMoney()
    end)
    if not ok then
        nfwLogInfo("[%s] Karrieregeld-Normalisierung fehlgeschlagen: %s", self.MOD_NAME, tostring(err))
    end
end

function NeighborFieldWorkers:tryInstallSettingsHooks()
    if self.settingsHooksInstalled then
        return
    end

    if type(InGameMenuSettingsFrame) ~= "table" or type(InGameMenuSettingsFrame.onFrameOpen) ~= "function" then
        return
    end

    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen,
        function(settingsFrame, element)
            self:onSettingsFrameOpen(settingsFrame, element)
        end)

    self.settingsHooksInstalled = true
end

function NeighborFieldWorkers:onSettingsFrameOpen(settingsFrame, _)
    self:ensureSettingsGuiElement(settingsFrame)
    self:updateSettingsElementState()
end

function NeighborFieldWorkers:ensureSettingsGuiElement(settingsFrame)
    if settingsFrame == nil or settingsFrame.gameSettingsLayout == nil then
        return
    end

    local hasMaxNeighborsOption = self.settingsValueElement ~= nil and self.settingsValueElement.parent ~= nil
    local hasCompetitionOption = self.settingsCompetitionElement ~= nil and self.settingsCompetitionElement.parent ~= nil
    local hasForcePrepareOption = self.settingsForcePrepareElement ~= nil and self.settingsForcePrepareElement.parent ~= nil
    if hasMaxNeighborsOption and hasCompetitionOption and hasForcePrepareOption then
        return
    end

    local optionRef = settingsFrame.economicDifficulty
    if optionRef == nil or optionRef.parent == nil then
        if not self.settingsWarnedMissingRefs then
            self.settingsWarnedMissingRefs = true
        end
        return
    end

    local layout = settingsFrame.gameSettingsLayout
    local containerRef = optionRef.parent
    local titleRef = containerRef.elements ~= nil and containerRef.elements[2] or nil
    if titleRef == nil then
        return
    end

    if not self.settingsSectionHeaderAdded then
        for _, element in ipairs(layout.elements) do
            if element.name == "sectionHeader" then
                local header = element:clone()
                header.id = "nfwSectionHeader"
                header:setText(self:getText("nfw_settings_section"))
                layout:addElement(header)
                self.settingsSectionHeaderAdded = true
                break
            end
        end
    end

    local addedElement = false

    if not hasMaxNeighborsOption then
        local option = optionRef:clone()
        option.id = "nfwMaxNeighborsOption"
        option.onClickCallback = function(state, element, ...)
            self:onSettingChangedMaxNeighbors(state, element, ...)
        end
        option.buttonLRChange = function(state, element, ...)
            self:onSettingChangedMaxNeighbors(state, element, ...)
        end
        option.texts = {}
        for value = self.maxNeighborsMin, self.maxNeighborsMax do
            table.insert(option.texts, tostring(value))
        end

        local tooltipElement = option.elements ~= nil and option.elements[1] or nil
        if tooltipElement ~= nil then
            local tooltipText = self:getText("nfw_settings_maxNeighbors_tooltip")
            if tooltipElement.setText ~= nil then
                tooltipElement:setText(tooltipText)
            else
                tooltipElement.text = tooltipText
                tooltipElement.sourceText = tooltipText
            end
        end

        local title = titleRef:clone()
        title.id = "nfwMaxNeighborsTitle"
        title:setText(self:getText("nfw_settings_maxNeighbors"))

        local container = containerRef:clone()
        container.id = "nfwMaxNeighborsContainer"
        if container.elements ~= nil then
            for key, _ in pairs(container.elements) do
                container.elements[key] = nil
            end
        end
        container:addElement(title)
        container:addElement(option)

        layout:addElement(container)
        self.settingsValueElement = option
        addedElement = true
    end

    if not hasCompetitionOption then
        local option = optionRef:clone()
        option.id = "nfwContractCompetitionOption"
        option.onClickCallback = function(state, element, ...)
            self:onSettingChangedContractCompetition(state, element, ...)
        end
        option.buttonLRChange = function(state, element, ...)
            self:onSettingChangedContractCompetition(state, element, ...)
        end
        option.texts = {
            self:getText("nfw_settings_toggle_off"),
            self:getText("nfw_settings_toggle_on")
        }

        local tooltipElement = option.elements ~= nil and option.elements[1] or nil
        if tooltipElement ~= nil then
            local tooltipText = self:getText("nfw_settings_contractCompetition_tooltip")
            if tooltipElement.setText ~= nil then
                tooltipElement:setText(tooltipText)
            else
                tooltipElement.text = tooltipText
                tooltipElement.sourceText = tooltipText
            end
        end

        local title = titleRef:clone()
        title.id = "nfwContractCompetitionTitle"
        title:setText(self:getText("nfw_settings_contractCompetition"))

        local container = containerRef:clone()
        container.id = "nfwContractCompetitionContainer"
        if container.elements ~= nil then
            for key, _ in pairs(container.elements) do
                container.elements[key] = nil
            end
        end
        container:addElement(title)
        container:addElement(option)

        layout:addElement(container)
        self.settingsCompetitionElement = option
        addedElement = true
    end

    if not hasForcePrepareOption then
        local option = optionRef:clone()
        option.id = "nfwForceFieldPreparationOption"
        option.onClickCallback = function(state, element, ...)
            self:onSettingChangedForceFieldPreparation(state, element, ...)
        end
        option.buttonLRChange = function(state, element, ...)
            self:onSettingChangedForceFieldPreparation(state, element, ...)
        end
        option.texts = {
            self:getText("nfw_settings_toggle_off"),
            self:getText("nfw_settings_toggle_on")
        }

        local tooltipElement = option.elements ~= nil and option.elements[1] or nil
        if tooltipElement ~= nil then
            local tooltipText = self:getText("nfw_settings_forceFieldPreparation_tooltip")
            if tooltipElement.setText ~= nil then
                tooltipElement:setText(tooltipText)
            else
                tooltipElement.text = tooltipText
                tooltipElement.sourceText = tooltipText
            end
        end

        local title = titleRef:clone()
        title.id = "nfwForceFieldPreparationTitle"
        title:setText(self:getText("nfw_settings_forceFieldPreparation"))

        local container = containerRef:clone()
        container.id = "nfwForceFieldPreparationContainer"
        if container.elements ~= nil then
            for key, _ in pairs(container.elements) do
                container.elements[key] = nil
            end
        end
        container:addElement(title)
        container:addElement(option)

        layout:addElement(container)
        self.settingsForcePrepareElement = option
        addedElement = true
    end

    if addedElement then
        layout:invalidateLayout()
    end
end

function NeighborFieldWorkers:updateSettingsElementState()
    local hasAnySettingElement = false
    if self.settingsValueElement ~= nil and self.settingsValueElement.parent ~= nil then
        hasAnySettingElement = true
    end
    if self.settingsCompetitionElement ~= nil and self.settingsCompetitionElement.parent ~= nil then
        hasAnySettingElement = true
    end
    if self.settingsForcePrepareElement ~= nil and self.settingsForcePrepareElement.parent ~= nil then
        hasAnySettingElement = true
    end

    if not hasAnySettingElement then
        return
    end

    self.settingsStateUpdateInProgress = true
    if self.settingsValueElement ~= nil and self.settingsValueElement.parent ~= nil then
        self.settingsValueElement:setState(self.maxNeighbors + 1)
    end
    if self.settingsCompetitionElement ~= nil and self.settingsCompetitionElement.parent ~= nil then
        self.settingsCompetitionElement:setState(self.allowExistingContractCompetition == true and 2 or 1)
    end
    if self.settingsForcePrepareElement ~= nil and self.settingsForcePrepareElement.parent ~= nil then
        self.settingsForcePrepareElement:setState(self.allowForcedFieldPreparation == true and 2 or 1)
    end
    self.settingsStateUpdateInProgress = false
end

function NeighborFieldWorkers:getSettingStateFromCallback(...)
    local callbackArgs = { ... }
    local callbackElement = nil
    for _, arg in ipairs(callbackArgs) do
        if type(arg) == "table" and type(arg.getState) == "function" then
            callbackElement = arg
            break
        end
    end

    if callbackElement ~= nil then
        return callbackElement:getState()
    end

    for _, arg in ipairs(callbackArgs) do
        if type(arg) == "number" then
            return arg
        end
    end

    return nil
end

function NeighborFieldWorkers:onSettingChangedMaxNeighbors(state, element, ...)
    if self.settingsStateUpdateInProgress then
        return
    end

    local value = self:getSettingStateFromCallback(state, element, ...)

    if value == nil then
        return
    end

    local newValue = nfwClamp((value or 1) - 1, self.maxNeighborsMin, self.maxNeighborsMax)
    if self.maxNeighbors == newValue then
        return
    end

    self.maxNeighbors = newValue
    self:saveSettingsToSavegame()

    nfwLogInfo("[%s] Max neighbors changed to %d", self.MOD_NAME, self.maxNeighbors)
end

function NeighborFieldWorkers:onSettingChangedContractCompetition(state, element, ...)
    if self.settingsStateUpdateInProgress then
        return
    end

    local value = self:getSettingStateFromCallback(state, element, ...)
    if value == nil then
        return
    end

    local enabled = (value or 1) >= 2
    if self.allowExistingContractCompetition == enabled then
        return
    end

    self.allowExistingContractCompetition = enabled
    self:saveSettingsToSavegame()

    nfwLogInfo(
        "[%s] Contract competition changed to %s (ON=neighbors can take existing contracts)",
        self.MOD_NAME,
        tostring(self.allowExistingContractCompetition)
    )
end

function NeighborFieldWorkers:findFarmIdByName(targetName)
    if g_farmManager == nil or type(g_farmManager.getFarms) ~= "function" then
        return nil
    end

    local normalizedTarget = nfwNormalizeName(targetName)
    for farmId, farm in pairs(g_farmManager:getFarms()) do
        local name = farm ~= nil and farm.name or nil
        if name == nil and farm ~= nil and type(farm.getName) == "function" then
            name = farm:getName()
        end

        local normalizedName = nfwNormalizeName(name)
        if normalizedTarget ~= nil and normalizedName == normalizedTarget then
            return farmId
        end

        if self:isNeighborFarmNameCandidate(name) then
            return farmId
        end
    end

    return nil
end

function NeighborFieldWorkers:isNeighborFarm(farmId)
    return self.neighborFarmId ~= nil and farmId ~= nil and farmId == self.neighborFarmId
end

function NeighborFieldWorkers:isMissionInProgress(mission)
    if mission == nil then
        return false
    end

    return mission.status == MissionStatus.PREPARING or mission.status == MissionStatus.RUNNING
end

function NeighborFieldWorkers:canMissionBeRecoveredAsActive(mission, wasSaved)
    if mission == nil then
        return false
    end

    if mission.status == MissionStatus.PREPARING or mission.status == MissionStatus.RUNNING then
        return true
    end

    local hasSpawnedMissionVehicles = mission.spawnedVehicles == true
        or (mission.vehicles ~= nil and #mission.vehicles > 0)
    local hasActiveId = mission.activeId ~= nil

    return wasSaved == true and (hasSpawnedMissionVehicles or hasActiveId or mission.status == MissionStatus.CREATED)
end

function NeighborFieldWorkers:getFarmNameById(farmId)
    if farmId == nil or g_farmManager == nil or type(g_farmManager.getFarmById) ~= "function" then
        return nil
    end

    local farm = g_farmManager:getFarmById(farmId)
    if farm == nil then
        return nil
    end

    local name = farm.name
    if name == nil and type(farm.getName) == "function" then
        name = farm:getName()
    end

    return name
end

function NeighborFieldWorkers:inferNeighborFarmIdFromActiveMissions()
    if g_missionManager == nil or g_missionManager.getMissions == nil then
        return nil
    end

    local playerFarmId = nil
    if g_currentMission ~= nil and g_currentMission.getFarmId ~= nil then
        playerFarmId = g_currentMission:getFarmId()
    end

    local farmCounts = {}
    local explicitNamedFarmId = nil

    for _, mission in ipairs(g_missionManager:getMissions()) do
        if mission ~= nil
            and mission.farmId ~= nil
            and self:isMissionInProgress(mission)
            and self:isAllowedMissionType(mission) then
            local farmId = mission.farmId
            farmCounts[farmId] = Utils.getNoNil(farmCounts[farmId], 0) + 1

            local farmName = self:getFarmNameById(farmId)
            if self:isNeighborFarmNameCandidate(farmName) then
                explicitNamedFarmId = farmId
                break
            end
        end
    end

    local inferredFarmId = explicitNamedFarmId

    if inferredFarmId == nil and self.neighborFarmId ~= nil and farmCounts[self.neighborFarmId] ~= nil then
        inferredFarmId = self.neighborFarmId
    end

    if inferredFarmId == nil then
        local bestFarmId = nil
        local bestCount = 0
        local hasTie = false

        for farmId, count in pairs(farmCounts) do
            if farmId ~= playerFarmId then
                if count > bestCount then
                    bestFarmId = farmId
                    bestCount = count
                    hasTie = false
                elseif count == bestCount and bestFarmId ~= nil then
                    hasTie = true
                end
            end
        end

        if bestFarmId ~= nil and not hasTie then
            inferredFarmId = bestFarmId
        end
    end

    if inferredFarmId ~= nil and inferredFarmId ~= self.neighborFarmId then
        self.neighborFarmId = inferredFarmId
        nfwLogInfo(
            "[%s] Nachbar-Farm aus laufenden Missionen erkannt: farmId=%s name=%s",
            self.MOD_NAME,
            tostring(self.neighborFarmId),
            tostring(self:getFarmNameById(self.neighborFarmId))
        )
    end

    return self.neighborFarmId
end

function NeighborFieldWorkers:isMissionOwnedByNeighborFarm(mission)
    if mission == nil or mission.farmId == nil then
        return false
    end

    if self:isNeighborFarm(mission.farmId) then
        return true
    end

    local farmName = self:getFarmNameById(mission.farmId)
    if self:isNeighborFarmNameCandidate(farmName) then
        self.neighborFarmId = mission.farmId
        return true
    end

    return false
end

function NeighborFieldWorkers:ensureNeighborFarm()
    if g_farmManager ~= nil and self.neighborFarmId ~= nil and g_farmManager:getFarmById(self.neighborFarmId) ~= nil then
        return true
    end

    local now = g_time or 0

    if now < self.nextNeighborFarmRetryAtMs then
        return false
    end

    self.nextNeighborFarmRetryAtMs = now + self.neighborFarmRetryIntervalMs

    if g_farmManager == nil then
        nfwLogInfo("[%s] Kein g_farmManager verfuegbar", self.MOD_NAME)
        return false
    end

    local inferredFarmId = self:inferNeighborFarmIdFromActiveMissions()
    if inferredFarmId ~= nil and g_farmManager:getFarmById(inferredFarmId) ~= nil then
        return true
    end

    local localizedFarmName = self:getLocalizedNeighborFarmName()
    local existingFarmId = self:findFarmIdByName(localizedFarmName)
    if existingFarmId ~= nil then
        self.neighborFarmId = existingFarmId
        return true
    end

    if type(g_farmManager.createFarm) ~= "function" then
        nfwLogInfo("[%s] Farm-Erstellung nicht moeglich (g_farmManager.createFarm fehlt)", self.MOD_NAME)
        return false
    end

    local playerUserId = nil
    if g_currentMission ~= nil then
        playerUserId = g_currentMission.playerUserId
    end

    local created = nil
    local triedVariants = {}

    local function tryCreateFarm(password, userId)
        local ok, result = pcall(g_farmManager.createFarm, g_farmManager, localizedFarmName, self.NEIGHBOR_FARM_COLOR,
            password, userId)
        table.insert(triedVariants,
            string.format("pwd=%s userId=%s ok=%s", tostring(password), tostring(userId), tostring(ok)))
        if ok and result ~= nil then
            return result
        end
        return nil
    end

    created = tryCreateFarm(nil, nil)
    if created == nil then created = tryCreateFarm("", nil) end
    if created == nil then created = tryCreateFarm(nil, playerUserId) end
    if created == nil then created = tryCreateFarm("", playerUserId) end
    if type(created) == "number" then
        self.neighborFarmId = created
    elseif type(created) == "table" then
        self.neighborFarmId = created.farmId or created.id
        if self.neighborFarmId == nil and type(created.getId) == "function" then
            self.neighborFarmId = created:getId()
        end
    end

    if self.neighborFarmId == nil then
        self.neighborFarmId = self:findFarmIdByName(localizedFarmName)
    end

    if self.neighborFarmId ~= nil then
        nfwLogInfo("[%s] Using neighbor farm '%s' with id=%s", self.MOD_NAME, localizedFarmName,
            tostring(self.neighborFarmId))
    else
        nfwLogInfo(
            "[%s] Konnte Nachbarfarm nicht erstellen/finden (createFarm result=%s, tries=%s)",
            self.MOD_NAME,
            tostring(created),
            table.concat(triedVariants, " | ")
        )
    end

    return self.neighborFarmId ~= nil
end

function NeighborFieldWorkers:getMissionKey(mission)
    if mission == nil then
        return nil
    end

    if mission.getUniqueId ~= nil then
        local uniqueId = mission:getUniqueId()
        if uniqueId ~= nil then
            return uniqueId
        end
    end

    return tostring(mission)
end

function NeighborFieldWorkers:getMissionTypeName(mission)
    if mission == nil then
        return "unknown"
    end

    if mission.type ~= nil and mission.type.name ~= nil then
        return tostring(mission.type.name)
    end

    if mission.getMissionTypeName ~= nil then
        local ok, name = pcall(mission.getMissionTypeName, mission)
        if ok and name ~= nil then
            return tostring(name)
        end
    end

    return tostring(mission.className or "unknown")
end

function NeighborFieldWorkers:getMissionTypeNameLower(mission)
    return string.lower(self:getMissionTypeName(mission))
end

function NeighborFieldWorkers:isHarvestMission(mission)
    return string.find(self:getMissionTypeNameLower(mission), "harvest", 1, true) ~= nil
end

function NeighborFieldWorkers:isStoneMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "stonepick", 1, true) ~= nil
        or string.find(nameLower, "stone", 1, true) ~= nil
end

function NeighborFieldWorkers:isCultivateMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "cultivat", 1, true) ~= nil
end

function NeighborFieldWorkers:isPlowMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "plow", 1, true) ~= nil
        or string.find(nameLower, "pflug", 1, true) ~= nil
end

function NeighborFieldWorkers:isSowMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "sow", 1, true) ~= nil
        or string.find(nameLower, "seed", 1, true) ~= nil
end

function NeighborFieldWorkers:isMowMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "mow", 1, true) ~= nil
end

function NeighborFieldWorkers:isHoeMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "hoe", 1, true) ~= nil
end

function NeighborFieldWorkers:isWeedMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "weed", 1, true) ~= nil
end

function NeighborFieldWorkers:isSprayMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "herbicid", 1, true) ~= nil
        or string.find(nameLower, "spray", 1, true) ~= nil
end

function NeighborFieldWorkers:isFertilizeMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "fertiliz", 1, true) ~= nil
end

function NeighborFieldWorkers:isTurnMission(mission)
    local nameLower = self:getMissionTypeNameLower(mission)
    return string.find(nameLower, "ted", 1, true) ~= nil
        or string.find(nameLower, "windrow", 1, true) ~= nil
        or string.find(nameLower, "turn", 1, true) ~= nil
        or string.find(nameLower, "wend", 1, true) ~= nil
end

function NeighborFieldWorkers:isBalerVehicleInfo(info)
    if info == nil then
        return false
    end

    local meta = self:getVehicleInfoMetaByInfo(info)
    if meta ~= nil and meta.isBalerTool == true then
        return true
    end

    local fileLower = string.lower(tostring(info.filename or ""))
    if nfwContainsAny(fileLower, { "baler", "bale", "ballen", "press" }) then
        return true
    end

    return false
end

function NeighborFieldWorkers:isBalerVehicleObject(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return false
    end

    if vehicle.spec_baler ~= nil then
        return true
    end

    local configLower = string.lower(tostring(vehicle.configFileName or ""))
    if nfwContainsAny(configLower, { "baler", "bale", "ballen", "press" }) then
        return true
    end

    if vehicle.getName ~= nil then
        local okName, displayName = pcall(vehicle.getName, vehicle)
        if okName and displayName ~= nil then
            local nameLower = string.lower(tostring(displayName))
            if nfwContainsAny(nameLower, { "baler", "bale", "ballen", "press" }) then
                return true
            end
        end
    end

    return false
end

function NeighborFieldWorkers:isMowAndBaleMission(mission)
    if mission == nil or not self:isMowMission(mission) then
        return false
    end

    local typeLower = self:getMissionTypeNameLower(mission)
    if nfwContainsAny(typeLower, { "bale", "baler", "ballen", "press" }) then
        return true
    end

    if mission.vehiclesToLoad ~= nil then
        for _, info in ipairs(mission.vehiclesToLoad) do
            if self:isBalerVehicleInfo(info) then
                return true
            end
        end
    end

    if mission.vehicles ~= nil then
        for _, vehicle in ipairs(mission.vehicles) do
            if self:isBalerVehicleObject(vehicle) then
                return true
            end
        end
    end

    return false
end

function NeighborFieldWorkers:getDebugFruitTypeName(fruitTypeIndex)
    if type(fruitTypeIndex) ~= "number"
        or g_fruitTypeManager == nil
        or g_fruitTypeManager.getFruitTypeByIndex == nil then
        return tostring(fruitTypeIndex)
    end

    local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    if fruitType ~= nil and fruitType.name ~= nil then
        return tostring(fruitType.name)
    end

    return tostring(fruitTypeIndex)
end

function NeighborFieldWorkers:getDebugFillTypeName(fillTypeIndex)
    if type(fillTypeIndex) ~= "number"
        or g_fillTypeManager == nil
        or g_fillTypeManager.getFillTypeNameByIndex == nil then
        return tostring(fillTypeIndex)
    end

    local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
    if fillTypeName ~= nil then
        return tostring(fillTypeName)
    end

    return tostring(fillTypeIndex)
end

function NeighborFieldWorkers:normalizeFruitTypeIndex(value)
    if type(value) == "table" then
        value = value.index or value.fruitType or value.fruitTypeIndex
    end

    if type(value) == "string" then
        if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypeByName ~= nil then
            local fruitType = g_fruitTypeManager:getFruitTypeByName(value)
            if fruitType ~= nil and type(fruitType.index) == "number" then
                return fruitType.index
            end
        end

        value = tonumber(value)
    end

    if type(value) == "number" then
        local fruitTypeIndex = math.floor(value + 0.5)
        if fruitTypeIndex > 0 and (FruitType == nil or FruitType.UNKNOWN == nil or fruitTypeIndex ~= FruitType.UNKNOWN) then
            return fruitTypeIndex
        end
    end

    return nil
end

function NeighborFieldWorkers:normalizeFillTypeIndex(value)
    if type(value) == "table" then
        value = value.index or value.fillType or value.fillTypeIndex
    end

    if type(value) == "string" then
        local lookup = string.upper(value)
        if type(FillType) == "table" and FillType[lookup] ~= nil then
            return FillType[lookup]
        end

        if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByName ~= nil then
            local fillType = g_fillTypeManager:getFillTypeByName(value)
            if fillType ~= nil and type(fillType.index) == "number" then
                return fillType.index
            end
        end

        value = tonumber(value)
    end

    if type(value) == "number" then
        local fillTypeIndex = math.floor(value + 0.5)
        if fillTypeIndex > 0 and (FillType == nil or FillType.UNKNOWN == nil or fillTypeIndex ~= FillType.UNKNOWN) then
            return fillTypeIndex
        end
    end

    return nil
end

function NeighborFieldWorkers:getMissionSowFruitType(mission)
    if mission == nil or not self:isSowMission(mission) then
        return nil
    end

    local fruitTypeFields = {
        "fruitType",
        "fruitTypeIndex",
        "seedFruitType",
        "seedFruitTypeIndex",
        "targetFruitType",
        "targetFruitTypeIndex"
    }

    for _, fieldName in ipairs(fruitTypeFields) do
        local fruitType = self:normalizeFruitTypeIndex(mission[fieldName])
        if fruitType ~= nil then
            return fruitType
        end
    end

    local fruitTypeFunctions = {
        "getFruitType",
        "getFruitTypeIndex",
        "getSeedFruitType",
        "getSeedFruitTypeIndex",
        "getTargetFruitType",
        "getTargetFruitTypeIndex"
    }

    for _, functionName in ipairs(fruitTypeFunctions) do
        if type(mission[functionName]) == "function" then
            local ok, value = pcall(mission[functionName], mission)
            if ok then
                local fruitType = self:normalizeFruitTypeIndex(value)
                if fruitType ~= nil then
                    return fruitType
                end
            end
        end
    end

    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypeIndexByFillTypeIndex ~= nil then
        local fillTypeFields = {
            "fillType",
            "fillTypeIndex",
            "seedFillType",
            "seedFillTypeIndex",
            "requiredFillType",
            "requiredFillTypeIndex"
        }

        for _, fieldName in ipairs(fillTypeFields) do
            local fillTypeIndex = self:normalizeFillTypeIndex(mission[fieldName])
            if fillTypeIndex ~= nil then
                local fruitType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(fillTypeIndex)
                fruitType = self:normalizeFruitTypeIndex(fruitType)
                if fruitType ~= nil then
                    return fruitType
                end
            end
        end

        local fillTypeFunctions = {
            "getFillType",
            "getFillTypeIndex",
            "getSeedFillType",
            "getSeedFillTypeIndex",
            "getRequiredFillType",
            "getRequiredFillTypeIndex"
        }

        for _, functionName in ipairs(fillTypeFunctions) do
            if type(mission[functionName]) == "function" then
                local ok, value = pcall(mission[functionName], mission)
                if ok then
                    local fillTypeIndex = self:normalizeFillTypeIndex(value)
                    if fillTypeIndex ~= nil then
                        local fruitType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(fillTypeIndex)
                        fruitType = self:normalizeFruitTypeIndex(fruitType)
                        if fruitType ~= nil then
                            return fruitType
                        end
                    end
                end
            end
        end
    end

    return nil
end

function NeighborFieldWorkers:getMissionSowFillType(mission, missionFruitType)
    if mission == nil or not self:isSowMission(mission) then
        return nil
    end

    local fruitType = missionFruitType
    if fruitType == nil then
        fruitType = self:getMissionSowFruitType(mission)
    end

    if fruitType ~= nil
        and g_fruitTypeManager ~= nil
        and g_fruitTypeManager.getFillTypeIndexByFruitTypeIndex ~= nil then
        local fillType = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitType)
        fillType = self:normalizeFillTypeIndex(fillType)
        if fillType ~= nil then
            return fillType
        end
    end

    local fillTypeFields = {
        "fillType",
        "fillTypeIndex",
        "seedFillType",
        "seedFillTypeIndex",
        "requiredFillType",
        "requiredFillTypeIndex"
    }

    for _, fieldName in ipairs(fillTypeFields) do
        local fillType = self:normalizeFillTypeIndex(mission[fieldName])
        if fillType ~= nil then
            return fillType
        end
    end

    local fillTypeFunctions = {
        "getFillType",
        "getFillTypeIndex",
        "getSeedFillType",
        "getSeedFillTypeIndex",
        "getRequiredFillType",
        "getRequiredFillTypeIndex"
    }

    for _, functionName in ipairs(fillTypeFunctions) do
        if type(mission[functionName]) == "function" then
            local ok, value = pcall(mission[functionName], mission)
            if ok then
                local fillType = self:normalizeFillTypeIndex(value)
                if fillType ~= nil then
                    return fillType
                end
            end
        end
    end

    return nil
end

function NeighborFieldWorkers:getMissionRequiredFillType(mission)
    if mission == nil then
        return nil
    end

    local fillTypeFields = {
        "fillType",
        "fillTypeIndex",
        "requiredFillType",
        "requiredFillTypeIndex",
        "sprayFillType",
        "sprayFillTypeIndex",
        "fertilizerFillType",
        "fertilizerFillTypeIndex",
        "herbicideFillType",
        "herbicideFillTypeIndex"
    }

    for _, fieldName in ipairs(fillTypeFields) do
        local fillType = self:normalizeFillTypeIndex(mission[fieldName])
        if fillType ~= nil then
            return fillType
        end
    end

    local fillTypeFunctions = {
        "getFillType",
        "getFillTypeIndex",
        "getRequiredFillType",
        "getRequiredFillTypeIndex",
        "getSprayFillType",
        "getSprayFillTypeIndex",
        "getFertilizerFillType",
        "getFertilizerFillTypeIndex",
        "getHerbicideFillType",
        "getHerbicideFillTypeIndex"
    }

    for _, functionName in ipairs(fillTypeFunctions) do
        if type(mission[functionName]) == "function" then
            local ok, value = pcall(mission[functionName], mission)
            if ok then
                local fillType = self:normalizeFillTypeIndex(value)
                if fillType ~= nil then
                    return fillType
                end
            end
        end
    end

    return nil
end

function NeighborFieldWorkers:prepareMissionSowSeedSelection(assignment, missionSowFruitType)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or not self:isSowMission(mission) then
        return
    end

    local targetFruitType = missionSowFruitType
    if targetFruitType == nil then
        targetFruitType = self:getMissionSowFruitType(mission)
    end

    if assignment ~= nil and assignment.lastSowTargetFruitType ~= targetFruitType then
        assignment.lastSowTargetFruitType = targetFruitType
        assignment.nextSowSelectionLogAtMs = 0
    end

    if targetFruitType == nil then
        local now = g_time or 0
        if now >= Utils.getNoNil(assignment.nextSowSelectionLogAtMs, 0) then
            assignment.nextSowSelectionLogAtMs = now + 10000
            nfwLogInfo(
                "[%s] Saat-Mission Zielkultur noch unbekannt: mission=%s type=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(self:getMissionTypeName(mission))
            )
        end
        return
    end

    local changedEntries = {}
    local compatibleVehicles = 0
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_sowingMachine ~= nil then
            local spec = vehicle.spec_sowingMachine
            local targetSeedIndex = nil
            if spec.seeds ~= nil then
                for seedIndex, fruitType in ipairs(spec.seeds) do
                    if fruitType == targetFruitType then
                        targetSeedIndex = seedIndex
                        break
                    end
                end
            end

            if targetSeedIndex ~= nil then
                compatibleVehicles = compatibleVehicles + 1
                local currentFruitType = (spec.seeds ~= nil and spec.currentSeed ~= nil) and spec.seeds
                    [spec.currentSeed] or nil
                if currentFruitType ~= targetFruitType then
                    if vehicle.setSeedFruitType ~= nil then
                        pcall(vehicle.setSeedFruitType, vehicle, targetFruitType, true)
                    elseif vehicle.setSeedIndex ~= nil then
                        pcall(vehicle.setSeedIndex, vehicle, targetSeedIndex, true)
                    end

                    local newFruitType = (spec.seeds ~= nil and spec.currentSeed ~= nil) and spec.seeds
                        [spec.currentSeed] or nil
                    if newFruitType == targetFruitType then
                        local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                        table.insert(
                            changedEntries,
                            string.format("%s=%s", tostring(vehicleName), self:getDebugFruitTypeName(targetFruitType))
                        )
                    end
                end
            end
        end
    end

    if #changedEntries > 0 then
        nfwLogInfo(
            "[%s] Saatgut-Typ auf Missionsziel gesetzt: mission=%s fruitType=%s entries=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            self:getDebugFruitTypeName(targetFruitType),
            table.concat(changedEntries, ", ")
        )
    elseif compatibleVehicles == 0 then
        local now = g_time or 0
        if now >= Utils.getNoNil(assignment.nextSowSelectionLogAtMs, 0) then
            assignment.nextSowSelectionLogAtMs = now + 10000
            nfwLogInfo(
                "[%s] Saat-Mission: kein kompatibles Sae-Geraet fuer Zielkultur gefunden: mission=%s fruitType=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                self:getDebugFruitTypeName(targetFruitType)
            )
        end
    end
end

function NeighborFieldWorkers:enforceSowImplementOperationalState(assignment, vehicle, forceLog)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or not self:isSowMission(mission) or vehicle == nil or vehicle.isDeleted then
        return
    end

    local now = g_time or 0
    if not forceLog and now < Utils.getNoNil(assignment.nextSowImplementEnforceAtMs, 0) then
        return
    end
    assignment.nextSowImplementEnforceAtMs = now + 1500

    local stateEntries = {}
    local visited = {}
    local containsSowCache = {}

    local function objectContainsSowingTool(obj, depth)
        if obj == nil or depth > 10 then
            return false
        end
        if containsSowCache[obj] ~= nil then
            return containsSowCache[obj]
        end

        if obj.spec_sowingMachine ~= nil or obj.spec_planter ~= nil then
            containsSowCache[obj] = true
            return true
        end

        local hasSow = false
        if obj.getAttachedImplements ~= nil then
            local attached = obj:getAttachedImplements()
            if attached ~= nil then
                for _, impl in ipairs(attached) do
                    if impl ~= nil and impl.object ~= nil and objectContainsSowingTool(impl.object, depth + 1) then
                        hasSow = true
                        break
                    end
                end
            end
        end

        containsSowCache[obj] = hasSow
        return hasSow
    end

    local function visitObject(obj, depth, parentObj, parentJointDescIndex)
        if obj == nil or visited[obj] or depth > 8 then
            return
        end
        visited[obj] = true

        local objName = tostring(obj.getName ~= nil and obj:getName() or obj)
        local actions = {}
        local isSowTool = obj.spec_sowingMachine ~= nil or obj.spec_planter ~= nil
        local isSowSupportCarrier = (not isSowTool)
            and obj.spec_motorized == nil
            and objectContainsSowingTool(obj, 0)

        if parentObj ~= nil
            and parentJointDescIndex ~= nil
            and parentObj.getJointMoveDown ~= nil
            and parentObj.setJointMoveDown ~= nil
            and objectContainsSowingTool(obj, 0) then
            local okMoveDown, moveDown = pcall(parentObj.getJointMoveDown, parentObj, parentJointDescIndex)
            if okMoveDown and moveDown ~= true then
                pcall(parentObj.setJointMoveDown, parentObj, parentJointDescIndex, true, false)
                local parentName = tostring(parentObj.getName ~= nil and parentObj:getName() or parentObj)
                table.insert(
                    actions,
                    string.format("lowerJoint=%s->%s", nfwToSingleLineText(parentName, 24), nfwToSingleLineText(objName, 24))
                )
            end
        end

        if isSowSupportCarrier then
            if obj.getCanBeTurnedOn ~= nil
                and obj.getIsTurnedOn ~= nil
                and obj.setIsTurnedOn ~= nil then
                local okCanTurn, canTurn = pcall(obj.getCanBeTurnedOn, obj)
                local okTurnedOn, isTurnedOn = pcall(obj.getIsTurnedOn, obj)
                if okCanTurn and canTurn and okTurnedOn and not isTurnedOn then
                    pcall(obj.setIsTurnedOn, obj, true, true)
                    table.insert(actions, "supportTurnOn=true")
                end
            end

            if obj.aiImplementStartLine ~= nil then
                pcall(obj.aiImplementStartLine, obj)
                table.insert(actions, "supportStartLine")
            end

            local supportOn = obj.getIsTurnedOn ~= nil and obj:getIsTurnedOn() or nil
            local supportCanStart = obj.getCanStartFieldWork ~= nil and obj:getCanStartFieldWork() or nil
            table.insert(
                stateEntries,
                string.format(
                    "%s{support=true canStart=%s on=%s act=%s}",
                    nfwToSingleLineText(objName, 40),
                    tostring(supportCanStart),
                    tostring(supportOn),
                    #actions > 0 and table.concat(actions, ",") or "none"
                )
            )
        end

        if isSowTool then
            if obj.getCanBeTurnedOn ~= nil
                and obj.getIsTurnedOn ~= nil
                and obj.setIsTurnedOn ~= nil then
                local okCanTurn, canTurn = pcall(obj.getCanBeTurnedOn, obj)
                local okTurnedOn, isTurnedOn = pcall(obj.getIsTurnedOn, obj)
                if okCanTurn and canTurn and okTurnedOn and not isTurnedOn then
                    pcall(obj.setIsTurnedOn, obj, true, true)
                    table.insert(actions, "turnOn=true")
                end
            end

            if obj.spec_foldable ~= nil
                and obj.spec_foldable.hasFoldingParts
                and obj.spec_foldable.allowUnfoldingByAI == true
                and obj.getFoldAnimTime ~= nil
                and obj.setFoldDirection ~= nil then
                local okFold, foldTime = pcall(obj.getFoldAnimTime, obj)
                if okFold and type(foldTime) == "number" then
                    local moveDirection = tonumber(obj.spec_foldable.moveDirection) or 0
                    local turnOnDir = tonumber(obj.spec_foldable.turnOnFoldDirection) or 0
                    local unfoldedState = obj.getIsUnfolded ~= nil and obj:getIsUnfolded() or nil
                    if unfoldedState ~= true then
                        local foldDirection = nil
                        if math.abs(moveDirection) > 0.001 then
                            foldDirection = nil
                        elseif turnOnDir > 0 then
                            foldDirection = 1
                        elseif turnOnDir < 0 then
                            foldDirection = -1
                        else
                            foldDirection = foldTime > 0.5 and -1 or 1
                        end
                        if foldDirection ~= nil then
                            pcall(obj.setFoldDirection, obj, foldDirection, true)
                            table.insert(actions, string.format("foldDir=%d", foldDirection))
                        end
                    end
                end
            end

            if obj.aiImplementStartLine ~= nil then
                pcall(obj.aiImplementStartLine, obj)
                table.insert(actions, "startLine")
            end

            local canStart = obj.getCanStartFieldWork ~= nil and obj:getCanStartFieldWork() or nil
            local turnedOn = obj.getIsTurnedOn ~= nil and obj:getIsTurnedOn() or nil
            local unfolded = obj.getIsUnfolded ~= nil and obj:getIsUnfolded() or nil
            local lowered = obj.getIsLowered ~= nil and obj:getIsLowered(false) or nil
            local canContinue = "n/a"
            local stopAI = "n/a"
            local stopReason = "n/a"
            if obj.getCanAIImplementContinueWork ~= nil then
                local okCont, c, s, r = pcall(obj.getCanAIImplementContinueWork, obj, false)
                if okCont then
                    canContinue = tostring(c)
                    stopAI = tostring(s)
                    stopReason = self:getAIMessageNameByInstance(r)
                else
                    canContinue = "err"
                    stopAI = "err"
                    stopReason = nfwToSingleLineText(c, 120)
                end
            end
            table.insert(
                stateEntries,
                string.format(
                    "%s{start=%s on=%s unfolded=%s lowered=%s cont=%s stop=%s reason=%s act=%s}",
                    nfwToSingleLineText(objName, 40),
                    tostring(canStart),
                    tostring(turnedOn),
                    tostring(unfolded),
                    tostring(lowered),
                    tostring(canContinue),
                    tostring(stopAI),
                    tostring(stopReason),
                    #actions > 0 and table.concat(actions, ",") or "none"
                )
            )
        end

        if obj.getAttachedImplements ~= nil then
            local attached = obj:getAttachedImplements()
            if attached ~= nil then
                for _, impl in ipairs(attached) do
                    if impl ~= nil and impl.object ~= nil then
                        visitObject(impl.object, depth + 1, obj, impl.jointDescIndex)
                    end
                end
            end
        end
    end

    visitObject(vehicle, 0, nil, nil)

    if forceLog or now >= Utils.getNoNil(assignment.nextSowImplementStateLogAtMs, 0) then
        assignment.nextSowImplementStateLogAtMs = now + 5000
        if #stateEntries > 0 then
            nfwLogHelperDiag(
                "[%s] HelperDiag SOW_IMPL_STATE_PASSIVE: mission=%s states=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                nfwToSingleLineText(table.concat(stateEntries, " || "), 1400)
            )
        end
    end
end

function NeighborFieldWorkers:shouldDeferSowOperationalStateBeforeStart(assignment, mission)
    if assignment == nil or mission == nil or not self:isSowMission(mission) then
        return false
    end

    if self.fieldEdgeStartModeEnabled ~= true then
        return false
    end

    if assignment.disableEdgeStartForMission == true then
        return false
    end

    return true
end

function NeighborFieldWorkers:shouldDeferSowOperationalStateDuringEdgeApproach(assignment, mission, vehicle)
    if assignment == nil or mission == nil or not self:isSowMission(mission) then
        return false
    end

    if assignment.lastStartUsedEdge ~= true or assignment.disableEdgeStartForMission == true then
        return false
    end

    if vehicle == nil or vehicle.isDeleted then
        return false
    end

    if vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() ~= true then
        return false
    end

    local taskIndex = assignment.giantsJob ~= nil and tonumber(assignment.giantsJob.currentTaskIndex) or nil
    return taskIndex == 1
end

function NeighborFieldWorkers:getVehicleInfoMetaByInfo(info)
    local defaultMeta = {
        power = 0,
        isMotorized = false,
        isTrailer = false,
        isAttachable = false,
        isWeight = false,
        isPlowTool = false,
        isCultivateTool = false,
        isMowerTool = false,
        isHoeTool = false,
        isWeederTool = false,
        isSprayerTool = false,
        isSowingTool = false,
        isTurnTool = false,
        isBalerTool = false,
        isFrontTank = false,
        isTractor = false,
        needsLiveProbe = false
    }
    if info == nil or info.filename == nil then
        return defaultMeta
    end

    local filename = tostring(info.filename)
    local cacheKey = string.lower(filename)
    local cached = self.vehicleInfoMetaCache[cacheKey]
    if cached ~= nil then
        return cached
    end

    local meta = {
        power = 0,
        isMotorized = false,
        isTrailer = false,
        isAttachable = false,
        isWeight = false,
        isPlowTool = false,
        isCultivateTool = false,
        isMowerTool = false,
        isHoeTool = false,
        isWeederTool = false,
        isSprayerTool = false,
        isSowingTool = false,
        isTurnTool = false,
        isBalerTool = false,
        isFrontTank = false,
        isTractor = false,
        needsLiveProbe = false
    }

    local item = nil
    if g_storeManager ~= nil and g_storeManager.getItemByXMLFilename ~= nil then
        item = g_storeManager:getItemByXMLFilename(filename)
    end

    if item ~= nil then
        if item.specs ~= nil and type(item.specs.power) == "number" then
            meta.power = math.max(meta.power, item.specs.power)
            if item.specs.power > 0 then
                meta.isMotorized = true
            end
        end

        if item.categoryNames ~= nil then
            for _, categoryName in ipairs(item.categoryNames) do
                local categoryLower = string.lower(tostring(categoryName))
                if string.find(categoryLower, "tractor", 1, true) ~= nil
                    or string.find(categoryLower, "vehicle", 1, true) ~= nil
                    or string.find(categoryLower, "truck", 1, true) ~= nil
                    or string.find(categoryLower, "harvester", 1, true) ~= nil
                    or string.find(categoryLower, "combine", 1, true) ~= nil then
                    meta.isMotorized = true
                end
                if string.find(categoryLower, "trailer", 1, true) ~= nil
                    or string.find(categoryLower, "wagen", 1, true) ~= nil
                    or string.find(categoryLower, "dolly", 1, true) ~= nil then
                    meta.isTrailer = true
                end
                if string.find(categoryLower, "attach", 1, true) ~= nil then
                    meta.isAttachable = true
                end
                if string.find(categoryLower, "weight", 1, true) ~= nil
                    or string.find(categoryLower, "gewicht", 1, true) ~= nil then
                    meta.isWeight = true
                end
                if string.find(categoryLower, "plow", 1, true) ~= nil
                    or string.find(categoryLower, "pflug", 1, true) ~= nil then
                    meta.isPlowTool = true
                end
                if string.find(categoryLower, "cultivat", 1, true) ~= nil
                    or string.find(categoryLower, "grubber", 1, true) ~= nil
                    or string.find(categoryLower, "powerharrow", 1, true) ~= nil
                    or string.find(categoryLower, "harrow", 1, true) ~= nil then
                    meta.isCultivateTool = true
                end
                if string.find(categoryLower, "mow", 1, true) ~= nil
                    or string.find(categoryLower, "mower", 1, true) ~= nil
                    or string.find(categoryLower, "maeh", 1, true) ~= nil then
                    meta.isMowerTool = true
                end
                if string.find(categoryLower, "hoe", 1, true) ~= nil
                    or string.find(categoryLower, "hack", 1, true) ~= nil then
                    meta.isHoeTool = true
                end
                if string.find(categoryLower, "weed", 1, true) ~= nil
                    or string.find(categoryLower, "weeder", 1, true) ~= nil
                    or string.find(categoryLower, "unkraut", 1, true) ~= nil then
                    meta.isWeederTool = true
                end
                if string.find(categoryLower, "spray", 1, true) ~= nil
                    or string.find(categoryLower, "sprayer", 1, true) ~= nil
                    or string.find(categoryLower, "herbicid", 1, true) ~= nil
                    or string.find(categoryLower, "sprit", 1, true) ~= nil then
                    meta.isSprayerTool = true
                end
                if string.find(categoryLower, "sow", 1, true) ~= nil
                    or string.find(categoryLower, "seed", 1, true) ~= nil
                    or string.find(categoryLower, "seeder", 1, true) ~= nil
                    or string.find(categoryLower, "planter", 1, true) ~= nil
                    or string.find(categoryLower, "sae", 1, true) ~= nil then
                    meta.isSowingTool = true
                end
                if string.find(categoryLower, "ted", 1, true) ~= nil
                    or string.find(categoryLower, "windrow", 1, true) ~= nil
                    or string.find(categoryLower, "turn", 1, true) ~= nil
                    or string.find(categoryLower, "wend", 1, true) ~= nil then
                    meta.isTurnTool = true
                end
                if string.find(categoryLower, "baler", 1, true) ~= nil
                    or string.find(categoryLower, "bale", 1, true) ~= nil
                    or string.find(categoryLower, "ballen", 1, true) ~= nil
                    or string.find(categoryLower, "press", 1, true) ~= nil then
                    meta.isBalerTool = true
                end
                if string.find(categoryLower, "tank", 1, true) ~= nil then
                    meta.isFrontTank = true
                end
                if string.find(categoryLower, "tractor", 1, true) ~= nil then
                    meta.isTractor = true
                end
            end
        end
    end

    local filenameLower = string.lower(filename)
    if string.find(filenameLower, "trailer", 1, true) ~= nil
        or string.find(filenameLower, "wagen", 1, true) ~= nil
        or string.find(filenameLower, "dolly", 1, true) ~= nil then
        meta.isTrailer = true
    end
    if string.find(filenameLower, "tractor", 1, true) ~= nil
        or string.find(filenameLower, "truck", 1, true) ~= nil
        or string.find(filenameLower, "combine", 1, true) ~= nil
        or string.find(filenameLower, "harvester", 1, true) ~= nil
        or string.find(filenameLower, "selfpropelled", 1, true) ~= nil then
        meta.isMotorized = true
    end
    if string.find(filenameLower, "weight", 1, true) ~= nil
        or string.find(filenameLower, "gewicht", 1, true) ~= nil then
        meta.isWeight = true
    end
    if string.find(filenameLower, "plow", 1, true) ~= nil
        or string.find(filenameLower, "pflug", 1, true) ~= nil then
        meta.isPlowTool = true
    end
    if string.find(filenameLower, "cultivat", 1, true) ~= nil
        or string.find(filenameLower, "grubber", 1, true) ~= nil
        or string.find(filenameLower, "harrow", 1, true) ~= nil then
        meta.isCultivateTool = true
    end
    if string.find(filenameLower, "mow", 1, true) ~= nil
        or string.find(filenameLower, "mower", 1, true) ~= nil
        or string.find(filenameLower, "maeh", 1, true) ~= nil then
        meta.isMowerTool = true
    end
    if string.find(filenameLower, "hoe", 1, true) ~= nil
        or string.find(filenameLower, "hack", 1, true) ~= nil then
        meta.isHoeTool = true
    end
    if string.find(filenameLower, "weed", 1, true) ~= nil
        or string.find(filenameLower, "weeder", 1, true) ~= nil
        or string.find(filenameLower, "unkraut", 1, true) ~= nil then
        meta.isWeederTool = true
    end
    if string.find(filenameLower, "spray", 1, true) ~= nil
        or string.find(filenameLower, "sprayer", 1, true) ~= nil
        or string.find(filenameLower, "herbicid", 1, true) ~= nil
        or string.find(filenameLower, "sprit", 1, true) ~= nil then
        meta.isSprayerTool = true
    end
    if string.find(filenameLower, "sow", 1, true) ~= nil
        or string.find(filenameLower, "seed", 1, true) ~= nil
        or string.find(filenameLower, "seeder", 1, true) ~= nil
        or string.find(filenameLower, "planter", 1, true) ~= nil
        or string.find(filenameLower, "sae", 1, true) ~= nil then
        meta.isSowingTool = true
    end
    if string.find(filenameLower, "ted", 1, true) ~= nil
        or string.find(filenameLower, "windrow", 1, true) ~= nil
        or string.find(filenameLower, "turn", 1, true) ~= nil
        or string.find(filenameLower, "wend", 1, true) ~= nil then
        meta.isTurnTool = true
    end
    if string.find(filenameLower, "baler", 1, true) ~= nil
        or string.find(filenameLower, "bale", 1, true) ~= nil
        or string.find(filenameLower, "ballen", 1, true) ~= nil
        or string.find(filenameLower, "press", 1, true) ~= nil then
        meta.isBalerTool = true
    end
    if string.find(filenameLower, "fronttank", 1, true) ~= nil
        or (string.find(filenameLower, "front", 1, true) ~= nil and string.find(filenameLower, "tank", 1, true) ~= nil) then
        meta.isFrontTank = true
    end

    local hasDetectedType = meta.isMotorized
        or meta.isTrailer
        or meta.isAttachable
        or meta.isWeight
        or meta.isFrontTank
        or meta.isTractor
    local hasDetectedTool = meta.isPlowTool
        or meta.isCultivateTool
        or meta.isMowerTool
        or meta.isHoeTool
        or meta.isWeederTool
        or meta.isSprayerTool
        or meta.isSowingTool
        or meta.isTurnTool
        or meta.isBalerTool
    local needsXmlProbe = not hasDetectedType and not hasDetectedTool
    meta.needsLiveProbe = needsXmlProbe

    if meta.isMotorized and not meta.isTrailer and not meta.isWeight then
        meta.isTractor = true
    end

    self.vehicleInfoMetaCache[cacheKey] = meta
    return meta
end

function NeighborFieldWorkers:getVehicleInfoPowerScore(info)
    local meta = self:getVehicleInfoMetaByInfo(info)
    return Utils.getNoNil(meta.power, 0)
end

function NeighborFieldWorkers:updateVehicleInfoMetaFromVehicle(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return
    end

    local filename = tostring(vehicle.configFileName or "")
    if filename == "" then
        return
    end

    local cacheKey = string.lower(filename)
    local meta = self.vehicleInfoMetaCache[cacheKey]
    if meta == nil then
        meta = {
            power = 0,
            isMotorized = false,
            isTrailer = false,
            isAttachable = false,
            isWeight = false,
            isPlowTool = false,
            isCultivateTool = false,
            isMowerTool = false,
            isHoeTool = false,
            isWeederTool = false,
            isSprayerTool = false,
            isSowingTool = false,
            isTurnTool = false,
            isBalerTool = false,
            isFrontTank = false,
            isTractor = false,
            needsLiveProbe = false
        }
    end

    local powerScore = self:getVehiclePowerScore(vehicle)
    if type(powerScore) == "number" and powerScore > 0 then
        meta.power = math.max(meta.power, powerScore)
    end

    meta.isMotorized = meta.isMotorized or vehicle.spec_motorized ~= nil
    meta.isTrailer = meta.isTrailer or vehicle.spec_trailer ~= nil or vehicle.spec_cutterTrailer ~= nil
    meta.isAttachable = meta.isAttachable or vehicle.spec_attachable ~= nil
    meta.isWeight = meta.isWeight or vehicle.spec_weight ~= nil
    meta.isPlowTool = meta.isPlowTool or vehicle.spec_plow ~= nil
    meta.isCultivateTool = meta.isCultivateTool or vehicle.spec_cultivator ~= nil or vehicle.spec_powerHarrow ~= nil or
        vehicle.spec_discHarrow ~= nil
    meta.isMowerTool = meta.isMowerTool or vehicle.spec_mower ~= nil
    meta.isHoeTool = meta.isHoeTool or vehicle.spec_hoe ~= nil
    meta.isWeederTool = meta.isWeederTool or vehicle.spec_weeder ~= nil
    meta.isSprayerTool = meta.isSprayerTool or vehicle.spec_sprayer ~= nil
    meta.isSowingTool = meta.isSowingTool or vehicle.spec_sowingMachine ~= nil or vehicle.spec_planter ~= nil
    meta.isTurnTool = meta.isTurnTool or vehicle.spec_tedder ~= nil or vehicle.spec_windrower ~= nil
    meta.isBalerTool = meta.isBalerTool or vehicle.spec_baler ~= nil
    meta.isFrontTank = meta.isFrontTank or vehicle.spec_frontTank ~= nil

    if meta.isMotorized and not meta.isTrailer and not meta.isWeight then
        meta.isTractor = true
    end

    meta.needsLiveProbe = false
    self.vehicleInfoMetaCache[cacheKey] = meta
end

function NeighborFieldWorkers:learnVehicleInfoMetaFromMissionVehicles(mission)
    if mission == nil or mission.vehicles == nil then
        return
    end

    for _, vehicle in ipairs(mission.vehicles) do
        self:updateVehicleInfoMetaFromVehicle(vehicle)
    end
end

function NeighborFieldWorkers:getVehicleInfoLength(info)
    if info == nil or info.filename == nil then
        return nil
    end

    local filename = tostring(info.filename)
    local cacheKey = string.format(
        "%s|%s",
        nfwNormalizeXmlPath(filename),
        nfwBuildConfigurationsCacheKey(info.configurations)
    )
    local cached = self.vehicleInfoSizeCache[cacheKey]
    if cached ~= nil then
        if cached > 0 then
            return cached
        end
        return nil
    end

    local length = nil
    if type(info.length) == "number" and info.length > 0 then
        length = info.length
    end
    local storeItem = nil
    if length == nil and g_storeManager ~= nil and g_storeManager.getItemByXMLFilename ~= nil then
        storeItem = g_storeManager:getItemByXMLFilename(filename)
        if storeItem ~= nil then
            if storeItem.specs ~= nil and type(storeItem.specs.length) == "number" and storeItem.specs.length > 0 then
                length = storeItem.specs.length
            elseif type(storeItem.length) == "number" and storeItem.length > 0 then
                length = storeItem.length
            end
        end
    end

    self.vehicleInfoSizeCache[cacheKey] = length ~= nil and length or -1
    return length
end

function NeighborFieldWorkers:getVehicleLength(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return nil
    end

    if vehicle.size ~= nil and type(vehicle.size.length) == "number" and vehicle.size.length > 0 then
        return vehicle.size.length
    end

    if vehicle.spec_aiDrivable ~= nil
        and vehicle.spec_aiDrivable.agentInfo ~= nil
        and type(vehicle.spec_aiDrivable.agentInfo.length) == "number"
        and vehicle.spec_aiDrivable.agentInfo.length > 0 then
        return vehicle.spec_aiDrivable.agentInfo.length
    end

    if vehicle.configFileName ~= nil and vehicle.configFileName ~= "" then
        return self:getVehicleInfoLength({ filename = vehicle.configFileName })
    end

    return nil
end

function NeighborFieldWorkers:calculateAttachmentPlacementDistance(leadLength, implementLength, isFrontPlacement)
    local leadHalf = nil
    if type(leadLength) == "number" and leadLength > 0 then
        leadHalf = leadLength * 0.5
    end

    local implementHalf = nil
    if type(implementLength) == "number" and implementLength > 0 then
        implementHalf = implementLength * 0.5
    end

    if leadHalf ~= nil and implementHalf ~= nil then
        return math.max(1.5, leadHalf + NFW_IMPLEMENT_SPACING_BUFFER + implementHalf)
    end

    local defaultDist = isFrontPlacement and NFW_FRONT_IMPLEMENT_BASE_DIST or NFW_REAR_IMPLEMENT_BASE_DIST
    return defaultDist
end

function NeighborFieldWorkers:getImplementPlacementDistanceForInfo(mission, info, isFrontPlacement)
    local leadLength = mission ~= nil and mission.nfwPrimaryVehicleLength or nil
    local implementLength = self:getVehicleInfoLength(info)
    if mission ~= nil and (type(leadLength) ~= "number" or leadLength <= 0 or type(implementLength) ~= "number" or implementLength <= 0) then
        mission.nfwLengthFallbackUsed = true
    end
    return self:calculateAttachmentPlacementDistance(leadLength, implementLength, isFrontPlacement)
end

function NeighborFieldWorkers:getImplementPlacementDistanceForVehicle(leadVehicle, implementVehicle, isFrontPlacement)
    local leadLength = self:getVehicleLength(leadVehicle)
    local implementLength = self:getVehicleLength(implementVehicle)
    return self:calculateAttachmentPlacementDistance(leadLength, implementLength, isFrontPlacement)
end

function NeighborFieldWorkers:isPrimaryMissionVehicleInfo(mission, info, infoMeta)
    if info == nil then
        return false
    end

    local meta = infoMeta or self:getVehicleInfoMetaByInfo(info)
    if meta.isTrailer then
        return false
    end

    if meta.isMotorized or meta.isTractor then
        return true
    end

    if self:isHarvestMission(mission) then
        if self:getHarvestVehicleRoleByInfo(info) == "combine" then
            if mission ~= nil and mission.nfwHarvestTowCombineFileSet ~= nil then
                local infoFileKey = nfwNormalizeXmlPath(info.filename or "")
                local infoFileBase = nfwGetXmlBasename(info.filename or "")
                if mission.nfwHarvestTowCombineFileSet[infoFileKey] == true
                    or (infoFileBase ~= nil and mission.nfwHarvestTowCombineFileSet[infoFileBase] == true) then
                    return false
                end
            end
            return true
        end
        return false
    end

    return false
end

function NeighborFieldWorkers:getVehiclePowerScore(vehicle)
    if vehicle == nil or vehicle.isDeleted or vehicle.spec_motorized == nil then
        return 0
    end

    if vehicle.getMotor ~= nil then
        local okMotor, motor = pcall(vehicle.getMotor, vehicle)
        if okMotor and motor ~= nil then
            if type(motor.peakMotorPower) == "number" then
                return motor.peakMotorPower
            end
            if motor.getPeakTorque ~= nil then
                local okTorque, peakTorque = pcall(motor.getPeakTorque, motor)
                if okTorque and type(peakTorque) == "number" then
                    return peakTorque
                end
            end
        end
    end

    return 0
end

function NeighborFieldWorkers:isVehicleUpsideDown(vehicle)
    if vehicle == nil or vehicle.isDeleted or vehicle.rootNode == nil then
        return false
    end

    local _, upY, _ = localDirectionToWorld(vehicle.rootNode, 0, 1, 0)
    return upY < -0.15
end

function NeighborFieldWorkers:respawnAssignmentVehiclesAtStartPosition(assignment, reason)
    if assignment == nil or assignment.mission == nil then
        return false
    end

    self:releaseAttachmentLeadVehicleLock(assignment)
    assignment.forceRecoveryReposition = true
    assignment.forceDirectStart = true
    assignment.recoveredFromSave = false
    assignment.lastRelocateTryTime = 0
    assignment.lastAttachTryTime = g_time or 0
    assignment.attachAlignMode = 1
    assignment.attachFailedPasses = 0
    self:resetAttachWorkflowState(assignment)

    local moved = self:relocateMissionVehiclesToField(assignment, true)
    self:prepareMissionVehicleConsumables(assignment)
    local nextStartAfterAttachMs = tonumber(assignment.nextStartAfterAttachMs) or 0
    assignment.nextStartAfterAttachMs = math.max(nextStartAfterAttachMs, (g_time or 0) + 2000)

    nfwLogInfo(
        "[%s] Missionsfahrzeuge auf Startposition zurueckgesetzt (entkoppelt): mission=%s reason=%s moved=%s",
        self.MOD_NAME,
        tostring(assignment.key),
        tostring(reason or "unknown"),
        tostring(moved)
    )

    return moved
end

function NeighborFieldWorkers:isLikelyFrontAttachmentInfo(info)
    if info == nil then
        return false
    end

    if nfwIsPickUp900Text(info.filename) then
        return true
    end

    if nfwIsMcdonR216XmlPath(info.filename) then
        return true
    end

    local meta = self:getVehicleInfoMetaByInfo(info)
    if meta.isFrontTank then
        return true
    end
    if meta.isTrailer then
        return false
    end

    if meta.isWeight or meta.isFrontTank then
        return true
    end

    if nfwIsGmd8730XmlPath(info.filename) then
        return false
    end
    if nfwIsGmd3123FXmlPath(info.filename) then
        return true
    end

    local filenameLower = string.lower(tostring(info.filename or ""))
    if nfwContainsAny(filenameLower, { "gusscom", "fronttank", "ft1001", "kdf341", "kdf" }) then
        return true
    end

    local isLikelyRearFieldTool = meta.isPlowTool
        or meta.isCultivateTool
        or meta.isMowerTool
        or meta.isHoeTool
        or meta.isWeederTool
        or meta.isSprayerTool
        or meta.isSowingTool
        or meta.isTurnTool
        or meta.isBalerTool
    if isLikelyRearFieldTool then
        return false
    end

    if nfwContainsAny(filenameLower, { "front", "vorn", "frontal", "fronte" }) then
        return true
    end

    if g_storeManager ~= nil and g_storeManager.getItemByXMLFilename ~= nil and info.filename ~= nil then
        local item = g_storeManager:getItemByXMLFilename(tostring(info.filename))
        if item ~= nil then
            local displayName = string.lower(tostring(item.name or ""))
            if nfwIsPickUp900Text(displayName) then
                return true
            end
            if isLikelyRearFieldTool then
                return false
            end
            if nfwContainsAny(displayName, { "front", "vorn", "frontal", "fronte", "gusscom", "fronttank", "kdf341", "kdf" }) then
                return true
            end
        end
    end

    return false
end

function NeighborFieldWorkers:isLikelyFrontTankInfo(info, meta)
    if meta ~= nil and meta.isFrontTank then
        return true
    end

    local filenameLower = string.lower(tostring(info ~= nil and info.filename or ""))
    if nfwContainsAny(filenameLower, { "fronttank", "front_tank", "front tank" }) then
        return true
    end

    -- Some front support tanks are trailer-like in metadata and do not contain explicit "fronttank" tokens.
    -- For these cases, prefer front assignment when it looks like a tank but not like a rear fieldwork tool.
    if string.find(filenameLower, "tank", 1, true) ~= nil then
        local looksLikeRearTool = meta ~= nil
            and (meta.isPlowTool or meta.isCultivateTool or meta.isMowerTool or meta.isHoeTool
                or meta.isWeederTool or meta.isSowingTool or meta.isTurnTool or meta.isBalerTool)
        if not looksLikeRearTool then
            return true
        end
    end

    if string.find(filenameLower, "tank", 1, true) ~= nil and self:isLikelyFrontAttachmentInfo(info) then
        return true
    end

    return false
end

function NeighborFieldWorkers:appendUniqueMissionInfo(filtered, lookup, kept, info)
    if info == nil then
        return
    end

    local key = tostring(info)
    if lookup[key] then
        return
    end

    lookup[key] = true
    table.insert(filtered, info)
    table.insert(kept, tostring(info.filename or "unknown"))
end

function NeighborFieldWorkers:isSimpleToolInfo(meta)
    return meta ~= nil
        and not meta.isMotorized
        and not meta.isTrailer
        and not meta.isWeight
end

function NeighborFieldWorkers:filterMowMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwMowVehiclesFiltered == true then
        return
    end
    if not self:isMowMission(mission) then
        return
    end

    local bestTractorInfo = nil
    local bestTractorPower = -1
    local bestMotorizedMowerCarrierInfo = nil
    local bestMotorizedMowerCarrierPower = -1
    local bestWeightInfo = nil
    local bestWeightScore = -1
    local frontMowers = {}
    local rearMowers = {}
    local mowerCandidates = {}
    local fallbackTools = {}
    local forcedFrontMowerInfo = nil
    local forcedRearMowerInfo = nil

    for _, info in ipairs(mission.vehiclesToLoad) do
        local meta = self:getVehicleInfoMetaByInfo(info)
        local filenameLower = string.lower(tostring(info.filename or ""))
        local isMacDonR216Header = nfwIsMcdonR216XmlPath(info.filename)
        local isKnownSelfPropelledMowerByName = nfwContainsAny(filenameLower, { "m1240", "selfpropelled" })
        if isMacDonR216Header then
            -- Special-case: MacDon r216SP is a front header/cutter for MacDon carriers.
            -- Depending on store metadata it can be misclassified (e.g. trailer-like) and be filtered out.
            -- Always keep it as mower tool and force front attachment.
            local score = self:getVehicleInfoPowerScore(info)
            local entry = { info = info, score = score }
            table.insert(fallbackTools, entry)
            table.insert(mowerCandidates, entry)
            table.insert(frontMowers, entry)
            forcedFrontMowerInfo = info
        elseif meta.isTractor then
            local power = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or power > bestTractorPower then
                bestTractorInfo = info
                bestTractorPower = power
            end
        elseif (((meta.isMotorized and not meta.isTrailer) or isKnownSelfPropelledMowerByName) and not isMacDonR216Header) then
            local isMotorizedMowerCarrier = meta.isMowerTool
                or isKnownSelfPropelledMowerByName
            if isMotorizedMowerCarrier then
                local power = self:getVehicleInfoPowerScore(info)
                if bestMotorizedMowerCarrierInfo == nil or power > bestMotorizedMowerCarrierPower then
                    bestMotorizedMowerCarrierInfo = info
                    bestMotorizedMowerCarrierPower = power
                end
            end
        elseif meta.isWeight and not meta.isMotorized and not meta.isTrailer then
            local score = self:getVehicleInfoPowerScore(info)
            if bestWeightInfo == nil or score > bestWeightScore then
                bestWeightInfo = info
                bestWeightScore = score
            end
        elseif self:isSimpleToolInfo(meta) then
            local score = self:getVehicleInfoPowerScore(info)
            local entry = { info = info, score = score }
            table.insert(fallbackTools, entry)

            if meta.isMowerTool then
                table.insert(mowerCandidates, entry)
                if nfwIsMcdonR216XmlPath(info.filename) then
                    forcedFrontMowerInfo = info
                end
                if nfwIsGmd3123FXmlPath(info.filename) then
                    forcedFrontMowerInfo = info
                end
                if nfwIsGmd8730XmlPath(info.filename) then
                    forcedRearMowerInfo = info
                end
                if self:isLikelyFrontAttachmentInfo(info) then
                    table.insert(frontMowers, entry)
                else
                    table.insert(rearMowers, entry)
                end
            end
        end
    end

    nfwSortCandidatesByScore(frontMowers)
    nfwSortCandidatesByScore(rearMowers)
    nfwSortCandidatesByScore(mowerCandidates)
    nfwSortCandidatesByScore(fallbackTools)

    local filtered = {}
    local kept = {}
    local lookup = {}
    local selectedWorkVehicleInfo = bestMotorizedMowerCarrierInfo
    if selectedWorkVehicleInfo == nil then
        selectedWorkVehicleInfo = bestTractorInfo
    end
    self:appendUniqueMissionInfo(filtered, lookup, kept, selectedWorkVehicleInfo)

    local selectedFrontMowerInfo = nil
    local selectedRearMowerInfo = nil
    if #frontMowers > 0 then
        selectedFrontMowerInfo = frontMowers[1].info
    end
    if #rearMowers > 0 then
        selectedRearMowerInfo = rearMowers[1].info
    end

    -- Mowing special-case:
    -- If two mower tools are present, force one front + one rear selection.
    if #mowerCandidates >= 2 then
        if selectedRearMowerInfo == nil then
            for _, entry in ipairs(mowerCandidates) do
                if entry.info ~= selectedFrontMowerInfo then
                    selectedRearMowerInfo = entry.info
                    break
                end
            end
        end
        if selectedFrontMowerInfo == nil then
            for _, entry in ipairs(mowerCandidates) do
                if entry.info ~= selectedRearMowerInfo then
                    selectedFrontMowerInfo = entry.info
                    break
                end
            end
        end
    end

    if forcedFrontMowerInfo ~= nil then
        selectedFrontMowerInfo = forcedFrontMowerInfo
    end
    if forcedRearMowerInfo ~= nil then
        selectedRearMowerInfo = forcedRearMowerInfo
    end

    local selectedToolCount = 0
    if selectedFrontMowerInfo ~= nil then
        self:appendUniqueMissionInfo(filtered, lookup, kept, selectedFrontMowerInfo)
        selectedToolCount = selectedToolCount + 1
    end
    if selectedRearMowerInfo ~= nil and selectedToolCount < 2 then
        self:appendUniqueMissionInfo(filtered, lookup, kept, selectedRearMowerInfo)
        selectedToolCount = selectedToolCount + 1
    end

    if selectedToolCount < 2 then
        for _, entry in ipairs(fallbackTools) do
            local beforeCount = #filtered
            self:appendUniqueMissionInfo(filtered, lookup, kept, entry.info)
            if #filtered > beforeCount then
                selectedToolCount = selectedToolCount + 1
                if selectedToolCount >= 2 then
                    break
                end
            end
        end
    end

    -- Keep one non-motorized front weight for mowing missions if the mission provides one.
    -- Positioning and front-attach behavior is handled later by side classification.
    if bestWeightInfo ~= nil then
        self:appendUniqueMissionInfo(filtered, lookup, kept, bestWeightInfo)
    end

    -- Self-propelled mowers with one cutter/header must attach front.
    -- If no explicit front/rear mower was detected, force the first kept tool to front.
    if selectedWorkVehicleInfo ~= nil
        and selectedWorkVehicleInfo == bestMotorizedMowerCarrierInfo
        and selectedFrontMowerInfo == nil
        and selectedRearMowerInfo == nil then
        for _, info in ipairs(filtered) do
            if info ~= nil and info ~= selectedWorkVehicleInfo then
                selectedFrontMowerInfo = info
                break
            end
        end
    end

    local removed = {}
    for _, info in ipairs(mission.vehiclesToLoad) do
        if not lookup[tostring(info)] then
            table.insert(removed, tostring(info ~= nil and info.filename or "unknown"))
        end
    end

    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwMowVehiclesFiltered = true
        mission.nfwMowExpectedVehicleCount = #filtered
        mission.nfwForcedFrontImplementFilenameSet = nil
        mission.nfwForcedRearImplementFilenameSet = nil
        if selectedFrontMowerInfo ~= nil and selectedFrontMowerInfo.filename ~= nil then
            local xmlKey = nfwNormalizeXmlPath(selectedFrontMowerInfo.filename)
            local xmlBase = nfwGetXmlBasename(selectedFrontMowerInfo.filename)
            mission.nfwForcedFrontImplementFilenameSet = {
                [xmlKey] = true
            }
            if xmlBase ~= nil and xmlBase ~= "" then
                mission.nfwForcedFrontImplementFilenameSet[xmlBase] = true
            end
        end
        if selectedRearMowerInfo ~= nil and selectedRearMowerInfo.filename ~= nil then
            local xmlKey = nfwNormalizeXmlPath(selectedRearMowerInfo.filename)
            local xmlBase = nfwGetXmlBasename(selectedRearMowerInfo.filename)
            mission.nfwForcedRearImplementFilenameSet = {
                [xmlKey] = true
            }
            if xmlBase ~= nil and xmlBase ~= "" then
                mission.nfwForcedRearImplementFilenameSet[xmlBase] = true
            end
        end
    else
        mission.nfwMowExpectedVehicleCount = nil
        mission.nfwForcedFrontImplementFilenameSet = nil
        mission.nfwForcedRearImplementFilenameSet = nil
    end

    if #removed > 0 then
        nfwLogInfo(
            "[%s] M�h-Mission gefiltert: mission=%s kept=%d removed=%d keptVehicles=%s removedVehicles=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            #filtered,
            #removed,
            table.concat(kept, ", "),
            table.concat(removed, ", ")
        )
    end
end

function NeighborFieldWorkers:filterHoeMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwHoeVehiclesFiltered == true then
        return
    end
    if not self:isHoeMission(mission) then
        return
    end

    local bestTractorInfo = nil
    local bestTractorPower = -1
    local bestWeightInfo = nil
    local bestToolInfo = nil
    local bestToolPower = -1
    local fallbackToolInfo = nil

    for _, info in ipairs(mission.vehiclesToLoad) do
        local meta = self:getVehicleInfoMetaByInfo(info)
        if meta.isTractor then
            local power = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or power > bestTractorPower then
                bestTractorInfo = info
                bestTractorPower = power
            end
        elseif meta.isWeight and not meta.isMotorized and not meta.isTrailer then
            if bestWeightInfo == nil then
                bestWeightInfo = info
            end
        elseif self:isSimpleToolInfo(meta) then
            if not meta.isFrontTank and fallbackToolInfo == nil then
                fallbackToolInfo = info
            end
            if meta.isHoeTool then
                local power = self:getVehicleInfoPowerScore(info)
                if bestToolInfo == nil or power > bestToolPower then
                    bestToolInfo = info
                    bestToolPower = power
                end
            end
        end
    end

    if bestToolInfo == nil then
        bestToolInfo = fallbackToolInfo
    end

    local filtered = {}
    local kept = {}
    local lookup = {}
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestTractorInfo)
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestWeightInfo)
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestToolInfo)

    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwHoeVehiclesFiltered = true
        mission.nfwHoeExpectedVehicleCount = #filtered
    else
        mission.nfwHoeExpectedVehicleCount = nil
    end
end

function NeighborFieldWorkers:filterWeedMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwWeedVehiclesFiltered == true then
        return
    end
    if not self:isWeedMission(mission) then
        return
    end

    local bestTractorInfo = nil
    local bestTractorPower = -1
    local bestWeightInfo = nil
    local bestToolInfo = nil
    local bestToolPower = -1
    local fallbackToolInfo = nil

    for _, info in ipairs(mission.vehiclesToLoad) do
        local meta = self:getVehicleInfoMetaByInfo(info)
        if meta.isTractor then
            local power = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or power > bestTractorPower then
                bestTractorInfo = info
                bestTractorPower = power
            end
        elseif meta.isWeight and not meta.isMotorized and not meta.isTrailer then
            if bestWeightInfo == nil then
                bestWeightInfo = info
            end
        elseif self:isSimpleToolInfo(meta) then
            if not meta.isFrontTank and fallbackToolInfo == nil then
                fallbackToolInfo = info
            end
            if meta.isWeederTool then
                local power = self:getVehicleInfoPowerScore(info)
                if bestToolInfo == nil or power > bestToolPower then
                    bestToolInfo = info
                    bestToolPower = power
                end
            end
        end
    end

    if bestToolInfo == nil then
        bestToolInfo = fallbackToolInfo
    end

    local filtered = {}
    local kept = {}
    local lookup = {}
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestTractorInfo)
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestWeightInfo)
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestToolInfo)

    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwWeedVehiclesFiltered = true
        mission.nfwWeedExpectedVehicleCount = #filtered
    else
        mission.nfwWeedExpectedVehicleCount = nil
    end
end

function NeighborFieldWorkers:filterSprayMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwSprayVehiclesFiltered == true then
        return
    end
    if not self:isSprayMission(mission) and not self:isFertilizeMission(mission) then
        return
    end

    local bestTractorInfo = nil
    local bestTractorPower = -1
    local bestWeightInfo = nil
    local bestFrontTankInfo = nil
    local bestToolInfo = nil
    local bestToolPower = -1
    local fallbackToolInfo = nil

    for _, info in ipairs(mission.vehiclesToLoad) do
        local meta = self:getVehicleInfoMetaByInfo(info)
        if meta.isTractor then
            local power = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or power > bestTractorPower then
                bestTractorInfo = info
                bestTractorPower = power
            end
        elseif meta.isWeight and not meta.isMotorized and not meta.isTrailer then
            if bestWeightInfo == nil then
                bestWeightInfo = info
            end
        elseif not meta.isMotorized then
            if self:isLikelyFrontTankInfo(info, meta) then
                if bestFrontTankInfo == nil then
                    bestFrontTankInfo = info
                end
            else
                if fallbackToolInfo == nil then
                    fallbackToolInfo = info
                end
                if meta.isSprayerTool then
                    local power = self:getVehicleInfoPowerScore(info)
                    if bestToolInfo == nil or power > bestToolPower then
                        bestToolInfo = info
                        bestToolPower = power
                    end
                end
            end
        end
    end

    if bestToolInfo == nil then
        bestToolInfo = fallbackToolInfo
    end

    local filtered = {}
    local kept = {}
    local lookup = {}
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestTractorInfo)
    if bestFrontTankInfo ~= nil then
        self:appendUniqueMissionInfo(filtered, lookup, kept, bestFrontTankInfo)
    else
        self:appendUniqueMissionInfo(filtered, lookup, kept, bestWeightInfo)
    end
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestToolInfo)

    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwSprayVehiclesFiltered = true
        mission.nfwSprayExpectedVehicleCount = #filtered
        mission.nfwForcedFrontImplementFilenameSet = nil
        mission.nfwForcedRearImplementFilenameSet = nil

        local function setFilenameIntoSet(targetSet, filename)
            if targetSet == nil or filename == nil or filename == "" then
                return
            end
            local xmlKey = nfwNormalizeXmlPath(filename)
            local xmlBase = nfwGetXmlBasename(filename)
            if xmlKey ~= nil and xmlKey ~= "" then
                targetSet[xmlKey] = true
            end
            if xmlBase ~= nil and xmlBase ~= "" then
                targetSet[xmlBase] = true
            end
        end

        if bestFrontTankInfo ~= nil and bestFrontTankInfo.filename ~= nil then
            mission.nfwForcedFrontImplementFilenameSet = {}
            setFilenameIntoSet(mission.nfwForcedFrontImplementFilenameSet, bestFrontTankInfo.filename)
        elseif bestWeightInfo ~= nil and bestWeightInfo.filename ~= nil then
            mission.nfwForcedFrontImplementFilenameSet = {}
            setFilenameIntoSet(mission.nfwForcedFrontImplementFilenameSet, bestWeightInfo.filename)
        end

        if bestToolInfo ~= nil and bestToolInfo.filename ~= nil then
            mission.nfwForcedRearImplementFilenameSet = {}
            setFilenameIntoSet(mission.nfwForcedRearImplementFilenameSet, bestToolInfo.filename)
        end
    else
        mission.nfwSprayExpectedVehicleCount = nil
        mission.nfwForcedFrontImplementFilenameSet = nil
        mission.nfwForcedRearImplementFilenameSet = nil
    end
end

function NeighborFieldWorkers:filterSowMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwSowVehiclesFiltered == true then
        return
    end
    if not self:isSowMission(mission) then
        return
    end

    local bestTractorInfo = nil
    local bestTractorPower = -1
    local bestWeightInfo = nil
    local bestToolInfo = nil
    local bestToolPower = -1
    local fallbackToolInfo = nil
    local hasLiveMetaFallback = false

    for _, info in ipairs(mission.vehiclesToLoad) do
        local meta = self:getVehicleInfoMetaByInfo(info)
        if meta.needsLiveProbe == true then
            hasLiveMetaFallback = true
        end
        if meta.isTractor then
            local power = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or power > bestTractorPower then
                bestTractorInfo = info
                bestTractorPower = power
            end
        elseif meta.isWeight and not meta.isMotorized and not meta.isTrailer then
            if bestWeightInfo == nil then
                bestWeightInfo = info
            end
        elseif self:isSimpleToolInfo(meta) then
            if not meta.isFrontTank and fallbackToolInfo == nil then
                fallbackToolInfo = info
            end
            if meta.isSowingTool then
                local power = self:getVehicleInfoPowerScore(info)
                if bestToolInfo == nil or power > bestToolPower then
                    bestToolInfo = info
                    bestToolPower = power
                end
            end
        end
    end

    if hasLiveMetaFallback then
        mission.nfwSowMetaFallbackUsed = true
        mission.nfwSowVehiclesFiltered = nil
        mission.nfwSowExpectedVehicleCount = nil
        return
    end

    mission.nfwSowMetaFallbackUsed = nil
    if bestToolInfo == nil then
        bestToolInfo = fallbackToolInfo
    end

    local filtered = {}
    local kept = {}
    local lookup = {}
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestTractorInfo)
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestWeightInfo)
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestToolInfo)

    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwSowVehiclesFiltered = true
        mission.nfwSowExpectedVehicleCount = #filtered
    else
        mission.nfwSowExpectedVehicleCount = nil
    end
end

function NeighborFieldWorkers:filterTurnMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwTurnVehiclesFiltered == true then
        return
    end
    if not self:isTurnMission(mission) then
        return
    end

    local bestTractorInfo = nil
    local bestTractorPower = -1
    local bestToolInfo = nil
    local bestToolPower = -1
    local fallbackToolInfo = nil

    for _, info in ipairs(mission.vehiclesToLoad) do
        local meta = self:getVehicleInfoMetaByInfo(info)
        if meta.isTractor then
            local power = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or power > bestTractorPower then
                bestTractorInfo = info
                bestTractorPower = power
            end
        elseif self:isSimpleToolInfo(meta) then
            if not meta.isFrontTank and fallbackToolInfo == nil then
                fallbackToolInfo = info
            end
            if meta.isTurnTool then
                local power = self:getVehicleInfoPowerScore(info)
                if bestToolInfo == nil or power > bestToolPower then
                    bestToolInfo = info
                    bestToolPower = power
                end
            end
        end
    end

    if bestToolInfo == nil then
        bestToolInfo = fallbackToolInfo
    end

    local filtered = {}
    local kept = {}
    local lookup = {}
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestTractorInfo)
    self:appendUniqueMissionInfo(filtered, lookup, kept, bestToolInfo)

    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwTurnVehiclesFiltered = true
        mission.nfwTurnExpectedVehicleCount = #filtered
    else
        mission.nfwTurnExpectedVehicleCount = nil
    end
end

function NeighborFieldWorkers:getHarvestVehicleRoleByInfo(info)
    if info == nil or info.filename == nil then
        return "other"
    end

    local filename = tostring(info.filename)
    local cacheKey = string.lower(filename)
    local cached = self.harvestVehicleRoleCache[cacheKey]
    if cached ~= nil then
        return cached
    end

    local isCombine = false
    local isCutter = false
    local isTrailer = false
    local item = nil
    if g_storeManager ~= nil and g_storeManager.getItemByXMLFilename ~= nil then
        item = g_storeManager:getItemByXMLFilename(filename)
    end

    if item ~= nil and item.categoryNames ~= nil then
        for _, categoryName in ipairs(item.categoryNames) do
            local categoryLower = string.lower(tostring(categoryName))
            if string.find(categoryLower, "trailer", 1, true) ~= nil
                or string.find(categoryLower, "wagen", 1, true) ~= nil
                or string.find(categoryLower, "dolly", 1, true) ~= nil then
                isTrailer = true
            end
            if string.find(categoryLower, "combine", 1, true) ~= nil
                or string.find(categoryLower, "harvester", 1, true) ~= nil then
                isCombine = true
            end
            if string.find(categoryLower, "cutter", 1, true) ~= nil
                or string.find(categoryLower, "header", 1, true) ~= nil then
                isCutter = true
            end
        end
    end

    local filenameLower = string.lower(filename)
    if string.find(filenameLower, "trailer", 1, true) ~= nil
        or string.find(filenameLower, "transport", 1, true) ~= nil
        or string.find(filenameLower, "carriage", 1, true) ~= nil then
        isTrailer = true
    end
    if not isCombine and not isCutter then
        if string.find(filenameLower, "combine", 1, true) ~= nil
            or string.find(filenameLower, "harvester", 1, true) ~= nil then
            isCombine = true
        elseif string.find(filenameLower, "cutter", 1, true) ~= nil
            or string.find(filenameLower, "header", 1, true) ~= nil then
            isCutter = true
        end
    end

    local meta = self:getVehicleInfoMetaByInfo(info)
    local likelyTowBehindCombine = self:isLikelyTowBehindHarvestCombineInfo(info, meta)

    local role = "other"
    if isCombine and isCutter and not likelyTowBehindCombine and not meta.isMotorized then
        -- Some headers expose combine-like specs but are still front cutting tools.
        role = "cutter"
    elseif isCombine then
        role = "combine"
    elseif isCutter then
        -- Some cutter mods also expose trailer-like specs/categories.
        -- For harvest missions we still need to treat them as cutter attachments.
        role = "cutter"
    end

    local uncertain = false
    if role == "other" then
        local clearlyNonHarvestPrimary = isTrailer
            or meta.isTractor
            or meta.isWeight
            or meta.isFrontTank
            or meta.isPlowTool
            or meta.isCultivateTool
            or meta.isHoeTool
            or meta.isWeederTool
            or meta.isSprayerTool
            or meta.isSowingTool
            or meta.isTurnTool
            or meta.isBalerTool
        uncertain = not clearlyNonHarvestPrimary
    end

    self.harvestVehicleRoleCache[cacheKey] = role
    self.harvestVehicleRoleUncertainCache[cacheKey] = uncertain
    return role
end

function NeighborFieldWorkers:isHarvestVehicleRoleUncertainByInfo(info)
    if info == nil or info.filename == nil then
        return false
    end

    local cacheKey = string.lower(tostring(info.filename))
    local cached = self.harvestVehicleRoleUncertainCache[cacheKey]
    if cached ~= nil then
        return cached == true
    end

    self:getHarvestVehicleRoleByInfo(info)
    return self.harvestVehicleRoleUncertainCache[cacheKey] == true
end

function NeighborFieldWorkers:isLikelyTowBehindHarvestCombineInfo(info, meta)
    if info == nil then
        return false
    end

    local checkMeta = meta or self:getVehicleInfoMetaByInfo(info)

    local filenameLower = string.lower(tostring(info.filename or ""))
    -- Explicit tow-behind harvester families (e.g. Dewulf GBC/Xylon, ROPA Keiler) should always keep a tractor.
    if nfwContainsAny(filenameLower, { "gbc", "xylon", "keiler" }) then
        return true
    end
    if nfwContainsAny(filenameLower, { "trailer", "carriage", "transport", "tow", "towed", "anhaenger", "anhanger", "gezogen", "pull" }) then
        return true
    end

    if g_storeManager ~= nil and g_storeManager.getItemByXMLFilename ~= nil and info.filename ~= nil then
        local item = g_storeManager:getItemByXMLFilename(tostring(info.filename))
        if item ~= nil then
            local displayNameLower = string.lower(tostring(item.name or ""))
            if nfwContainsAny(displayNameLower, { "gbc", "xylon", "keiler" }) then
                return true
            end
            if nfwContainsAny(displayNameLower, { "trailer", "carriage", "tow", "trailed", "anhaenger", "anhanger", "gezogen", "pull" }) then
                return true
            end
        end
    end

    if checkMeta.isMotorized then
        return false
    end
    if checkMeta.isTrailer or checkMeta.isAttachable then
        return true
    end

    return false
end

function NeighborFieldWorkers:onSettingChangedForceFieldPreparation(state, element, ...)
    if self.settingsStateUpdateInProgress then
        return
    end

    local value = self:getSettingStateFromCallback(state, element, ...)
    if value == nil then
        return
    end

    local enabled = (value or 1) >= 2
    if self.allowForcedFieldPreparation == enabled then
        return
    end

    self.allowForcedFieldPreparation = enabled
    self:saveSettingsToSavegame()

    nfwLogInfo(
        "[%s] Field preparation force mode changed to %s (ON=PASS2 PREP allowed, OFF=PASS2 PREP disabled)",
        self.MOD_NAME,
        tostring(self.allowForcedFieldPreparation)
    )
end

function NeighborFieldWorkers:isLikelyTowBehindHarvestCombineVehicle(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return false
    end

    if vehicle.spec_motorized ~= nil then
        return false
    end

    local hasCombineSpec = vehicle.spec_combine ~= nil
        or vehicle.spec_attachableCombine ~= nil
        or vehicle.spec_attachableCombineWithoutCutter ~= nil
    if not hasCombineSpec then
        return false
    end

    if vehicle.spec_trailer ~= nil then
        return true
    end

    local configLower = string.lower(tostring(vehicle.configFileName or ""))
    if nfwContainsAny(configLower, { "trailer", "carriage", "transport", "tow", "towed", "anhaenger", "anhanger", "gezogen", "pull", "dewulf", "gbc", "xylon", "keiler" }) then
        return true
    end

    if vehicle.getName ~= nil then
        local okName, displayName = pcall(vehicle.getName, vehicle)
        if okName and displayName ~= nil then
            local nameLower = string.lower(tostring(displayName))
            if nfwContainsAny(nameLower, { "trailer", "carriage", "tow", "trailed", "anhaenger", "anhanger", "gezogen", "pull", "dewulf", "gbc", "xylon", "keiler" }) then
                return true
            end
        end
    end

    return false
end

function NeighborFieldWorkers:isMarkedHarvestTowCombineFilename(mission, filename)
    if mission == nil or mission.nfwHarvestTowCombineFileSet == nil or filename == nil or filename == "" then
        return false
    end

    local fileKey = nfwNormalizeXmlPath(filename)
    local fileBase = nfwGetXmlBasename(filename)
    if mission.nfwHarvestTowCombineFileSet[fileKey] == true then
        return true
    end
    if fileBase ~= nil and mission.nfwHarvestTowCombineFileSet[fileBase] == true then
        return true
    end

    return false
end

function NeighborFieldWorkers:filterHarvestMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwHarvestVehiclesFiltered == true then
        return
    end
    if not self:isHarvestMission(mission) then
        return
    end

    local bestCombineInfo = nil
    local bestCombineScore = -math.huge
    local bestCombineNeedsTractor = false
    local bestCutterInfo = nil
    local bestTractorInfo = nil
    local bestTractorScore = -math.huge
    local hasAnyCutterInfo = false
    local hasUncertainRoleInfo = false
    local combineCandidates = {}

    for _, info in ipairs(mission.vehiclesToLoad) do
        local role = self:getHarvestVehicleRoleByInfo(info)
        local meta = self:getVehicleInfoMetaByInfo(info)
        if role == "combine" then
            table.insert(combineCandidates, { info = info, meta = meta })
        elseif role == "cutter" then
            hasAnyCutterInfo = true
            if bestCutterInfo == nil then
                bestCutterInfo = info
            end
        elseif meta.isTractor
            or (role == "other" and meta.isMotorized and not meta.isTrailer and not meta.isWeight) then
            local score = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or score > bestTractorScore then
                bestTractorInfo = info
                bestTractorScore = score
            end
        elseif role == "other" and self:isHarvestVehicleRoleUncertainByInfo(info) then
            hasUncertainRoleInfo = true
        end
    end

    for _, candidate in ipairs(combineCandidates) do
        local info = candidate.info
        local meta = candidate.meta
        local needsTractor = self:isLikelyTowBehindHarvestCombineInfo(info, meta)
        if not needsTractor and not meta.isMotorized and not hasAnyCutterInfo and bestTractorInfo ~= nil then
            -- Ambiguous harvest loadout: combine + tractor, but no separate header.
            -- This is usually a trailer-harvester mission and must keep a tractor.
            needsTractor = true
        end

        local score = self:getVehicleInfoPowerScore(info)
        if not needsTractor then
            score = score + 1000000
        end

        if bestCombineInfo == nil or score > bestCombineScore then
            bestCombineInfo = info
            bestCombineScore = score
            bestCombineNeedsTractor = needsTractor
        end
    end

    if bestCombineInfo == nil then
        -- Safety fallback: role detection is unresolved without live vehicle specs.
        -- Keep full loadout and prune after spawn using live data.
        mission.nfwHarvestRoleFallbackUsed = true
        mission.nfwHarvestVehiclesFiltered = nil
        mission.nfwHarvestTowCombineFileSet = nil
        mission.nfwHarvestExpectedVehicleCount = nil
        return
    end

    if hasUncertainRoleInfo then
        -- Defer filtering to post-spawn prune when any role remained uncertain.
        mission.nfwHarvestRoleFallbackUsed = true
        mission.nfwHarvestVehiclesFiltered = nil
        mission.nfwHarvestTowCombineFileSet = nil
        mission.nfwHarvestExpectedVehicleCount = nil
        return
    end

    mission.nfwHarvestRoleFallbackUsed = nil
    mission.nfwHarvestTowCombineFileSet = nil
    if bestCombineNeedsTractor then
        local filename = tostring(bestCombineInfo.filename or "")
        local fileSet = {}
        local fileKey = nfwNormalizeXmlPath(filename)
        local fileBase = nfwGetXmlBasename(filename)
        if fileKey ~= nil and fileKey ~= "" then
            fileSet[fileKey] = true
        end
        if fileBase ~= nil and fileBase ~= "" then
            fileSet[fileBase] = true
        end
        mission.nfwHarvestTowCombineFileSet = fileSet
    end

    local filtered = {}
    local kept = {}
    local keepLookup = {}
    local function nfwKeepInfo(info)
        if info ~= nil then
            local key = tostring(info)
            if not keepLookup[key] then
                keepLookup[key] = true
                table.insert(filtered, info)
                table.insert(kept, tostring(info.filename or "unknown"))
            end
        end
    end

    if bestCombineNeedsTractor and bestTractorInfo ~= nil then
        nfwKeepInfo(bestTractorInfo)
    end
    nfwKeepInfo(bestCombineInfo)
    nfwKeepInfo(bestCutterInfo)

    local removed = {}
    for _, info in ipairs(mission.vehiclesToLoad) do
        if not keepLookup[tostring(info)] then
            table.insert(removed, tostring(info ~= nil and info.filename or "unknown"))
        end
    end

    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwHarvestVehiclesFiltered = true
        mission.nfwHarvestExpectedVehicleCount = #filtered
    else
        mission.nfwHarvestExpectedVehicleCount = nil
    end

    nfwLogHelperDiag(
        "[%s] HelperDiag HARVEST_FILTER_RESULT: mission=%s kept=%d removed=%d needsTractor=%s keep=%s removedList=%s",
        self.MOD_NAME,
        tostring(self:getMissionKey(mission)),
        #filtered,
        #removed,
        tostring(bestCombineNeedsTractor),
        nfwToSingleLineText(table.concat(kept, ", "), 700),
        nfwToSingleLineText(table.concat(removed, ", "), 700)
    )

    if #removed > 0 then
        local now = g_time or 0
        if now >= Utils.getNoNil(self.nextHarvestFilterLogAtMs, 0) then
            self.nextHarvestFilterLogAtMs = now + 5000
            nfwLogInfo(
                "[%s] Erntefahrzeuge gefiltert: mission=%s kept=%d removed=%d removedVehicles=%s",
                self.MOD_NAME,
                tostring(self:getMissionKey(mission)),
                #filtered,
                #removed,
                table.concat(removed, ", ")
            )
            if #kept > 0 then
                nfwLogInfo("[%s] Erntefahrzeuge behalten: mission=%s vehicles=%s", self.MOD_NAME,
                    tostring(self:getMissionKey(mission)), table.concat(kept, ", "))
            end
        end
    end
end

function NeighborFieldWorkers:getStoneVehicleRoleByInfo(info)
    if info == nil or info.filename == nil then
        return "other"
    end

    local filename = tostring(info.filename)
    local cacheKey = string.lower(filename)
    local cached = self.stoneVehicleRoleCache[cacheKey]
    if cached ~= nil then
        return cached
    end

    local isStonePicker = false
    local isMotorized = false
    local isTrailer = false
    local item = nil
    if g_storeManager ~= nil and g_storeManager.getItemByXMLFilename ~= nil then
        item = g_storeManager:getItemByXMLFilename(filename)
    end

    if item ~= nil and item.categoryNames ~= nil then
        for _, categoryName in ipairs(item.categoryNames) do
            local categoryLower = string.lower(tostring(categoryName))
            if string.find(categoryLower, "trailer", 1, true) ~= nil
                or string.find(categoryLower, "wagen", 1, true) ~= nil
                or string.find(categoryLower, "dolly", 1, true) ~= nil then
                isTrailer = true
            end
            if string.find(categoryLower, "tractor", 1, true) ~= nil
                or string.find(categoryLower, "vehicle", 1, true) ~= nil
                or string.find(categoryLower, "truck", 1, true) ~= nil then
                isMotorized = true
            end
            if string.find(categoryLower, "stone", 1, true) ~= nil
                and (string.find(categoryLower, "picker", 1, true) ~= nil
                    or string.find(categoryLower, "collector", 1, true) ~= nil
                    or string.find(categoryLower, "sammler", 1, true) ~= nil) then
                isStonePicker = true
            end
        end
    end

    local filenameLower = string.lower(filename)
    if string.find(filenameLower, "trailer", 1, true) ~= nil
        or string.find(filenameLower, "transport", 1, true) ~= nil
        or string.find(filenameLower, "carriage", 1, true) ~= nil then
        isTrailer = true
    end
    if string.find(filenameLower, "stone", 1, true) ~= nil
        and (string.find(filenameLower, "picker", 1, true) ~= nil
            or string.find(filenameLower, "collector", 1, true) ~= nil
            or string.find(filenameLower, "sammler", 1, true) ~= nil) then
        isStonePicker = true
    end

    local role = "other"
    if isTrailer then
        role = "other"
    elseif isStonePicker then
        role = "stonePicker"
    elseif isMotorized then
        role = "tractor"
    end

    local uncertain = false
    if role == "other" then
        local meta = self:getVehicleInfoMetaByInfo(info)
        local clearlyOther = isTrailer
            or meta.isTractor
            or meta.isWeight
            or meta.isFrontTank
            or meta.isPlowTool
            or meta.isCultivateTool
            or meta.isMowerTool
            or meta.isHoeTool
            or meta.isWeederTool
            or meta.isSprayerTool
            or meta.isSowingTool
            or meta.isTurnTool
            or meta.isBalerTool
        uncertain = not clearlyOther
    end

    self.stoneVehicleRoleCache[cacheKey] = role
    self.stoneVehicleRoleUncertainCache[cacheKey] = uncertain
    return role
end

function NeighborFieldWorkers:isStoneVehicleRoleUncertainByInfo(info)
    if info == nil or info.filename == nil then
        return false
    end

    local cacheKey = string.lower(tostring(info.filename))
    local cached = self.stoneVehicleRoleUncertainCache[cacheKey]
    if cached ~= nil then
        return cached == true
    end

    self:getStoneVehicleRoleByInfo(info)
    return self.stoneVehicleRoleUncertainCache[cacheKey] == true
end

function NeighborFieldWorkers:filterStoneMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwStoneVehiclesFiltered == true then
        return
    end
    if not self:isStoneMission(mission) then
        return
    end

    local filtered = {}
    local removed = {}
    local kept = {}
    local tractorCount = 0
    local pickerCount = 0
    local hasUncertainRoleInfo = false
    for _, info in ipairs(mission.vehiclesToLoad) do
        local role = self:getStoneVehicleRoleByInfo(info)
        local keep = false
        if role == "tractor" and tractorCount < 1 then
            keep = true
            tractorCount = tractorCount + 1
        elseif role == "stonePicker" and pickerCount < 1 then
            keep = true
            pickerCount = pickerCount + 1
        elseif role == "other" and self:isStoneVehicleRoleUncertainByInfo(info) then
            hasUncertainRoleInfo = true
        end

        if keep then
            table.insert(filtered, info)
            table.insert(kept, tostring(info ~= nil and info.filename or "unknown"))
        else
            table.insert(removed, tostring(info ~= nil and info.filename or "unknown"))
        end
    end

    if hasUncertainRoleInfo and (tractorCount < 1 or pickerCount < 1) then
        mission.nfwStoneRoleFallbackUsed = true
        mission.nfwStoneVehiclesFiltered = nil
        mission.nfwStoneExpectedVehicleCount = nil
        return
    end

    mission.nfwStoneRoleFallbackUsed = nil
    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwStoneVehiclesFiltered = true
        mission.nfwStoneExpectedVehicleCount = #filtered
    else
        mission.nfwStoneExpectedVehicleCount = nil
    end

    if #removed > 0 then
        local now = g_time or 0
        if now >= Utils.getNoNil(self.nextStoneFilterLogAtMs, 0) then
            self.nextStoneFilterLogAtMs = now + 5000
            nfwLogInfo(
                "[%s] Steinfahrzeuge gefiltert: mission=%s kept=%d removed=%d removedVehicles=%s",
                self.MOD_NAME,
                tostring(self:getMissionKey(mission)),
                #filtered,
                #removed,
                table.concat(removed, ", ")
            )
            if #kept > 0 then
                nfwLogInfo("[%s] Steinfahrzeuge behalten: mission=%s vehicles=%s", self.MOD_NAME,
                    tostring(self:getMissionKey(mission)), table.concat(kept, ", "))
            end
        end
    end
end

function NeighborFieldWorkers:filterCultivateMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwCultivateVehiclesFiltered == true then
        return
    end
    if not self:isCultivateMission(mission) then
        return
    end

    local bestTractorInfo = nil
    local bestTractorPower = -1
    local bestToolInfo = nil
    local bestToolPower = -1
    local fallbackToolInfo = nil
    local hasLiveMetaFallback = false

    for _, info in ipairs(mission.vehiclesToLoad) do
        local meta = self:getVehicleInfoMetaByInfo(info)
        if meta.needsLiveProbe == true then
            hasLiveMetaFallback = true
        end
        if meta.isTractor then
            local power = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or power > bestTractorPower then
                bestTractorInfo = info
                bestTractorPower = power
            end
        elseif not meta.isMotorized and not meta.isWeight and not meta.isTrailer then
            if fallbackToolInfo == nil then
                fallbackToolInfo = info
            end
            if meta.isCultivateTool then
                local power = self:getVehicleInfoPowerScore(info)
                if bestToolInfo == nil or power > bestToolPower then
                    bestToolInfo = info
                    bestToolPower = power
                end
            end
        end
    end

    if hasLiveMetaFallback then
        mission.nfwCultivateMetaFallbackUsed = true
        mission.nfwCultivateVehiclesFiltered = nil
        mission.nfwCultivateExpectedVehicleCount = nil
        return
    end

    mission.nfwCultivateMetaFallbackUsed = nil
    if bestToolInfo == nil then
        bestToolInfo = fallbackToolInfo
    end

    local filtered = {}
    local kept = {}
    local removed = {}
    if bestTractorInfo ~= nil then
        table.insert(filtered, bestTractorInfo)
        table.insert(kept, tostring(bestTractorInfo.filename))
    end
    if bestToolInfo ~= nil then
        table.insert(filtered, bestToolInfo)
        table.insert(kept, tostring(bestToolInfo.filename))
    end

    if #filtered > 0 then
        local keepLookup = {}
        for _, info in ipairs(filtered) do
            if info ~= nil then
                keepLookup[tostring(info)] = true
            end
        end
        for _, info in ipairs(mission.vehiclesToLoad) do
            if not keepLookup[tostring(info)] then
                table.insert(removed, tostring(info ~= nil and info.filename or "unknown"))
            end
        end

        mission.vehiclesToLoad = filtered
        mission.nfwCultivateVehiclesFiltered = true
        mission.nfwCultivateExpectedVehicleCount = #filtered

        if #removed > 0 then
            nfwLogInfo(
                "[%s] Kultivator-Fahrzeuge gefiltert: mission=%s kept=%d removed=%d keptVehicles=%s removedVehicles=%s",
                self.MOD_NAME,
                tostring(self:getMissionKey(mission)),
                #filtered,
                #removed,
                table.concat(kept, ", "),
                table.concat(removed, ", ")
            )
        end
    end
end

function NeighborFieldWorkers:filterPlowMissionVehiclesToLoad(mission)
    if mission == nil or mission.vehiclesToLoad == nil or mission.nfwPlowVehiclesFiltered == true then
        return
    end
    if not self:isPlowMission(mission) then
        return
    end

    local bestTractorInfo = nil
    local bestTractorPower = -1
    local bestPlowInfo = nil
    local bestPlowPower = -1
    local bestWeightInfo = nil
    local fallbackPlowInfo = nil
    local hasLiveMetaFallback = false

    for _, info in ipairs(mission.vehiclesToLoad) do
        local meta = self:getVehicleInfoMetaByInfo(info)
        if meta.needsLiveProbe == true then
            hasLiveMetaFallback = true
        end
        if meta.isTractor then
            local power = self:getVehicleInfoPowerScore(info)
            if bestTractorInfo == nil or power > bestTractorPower then
                bestTractorInfo = info
                bestTractorPower = power
            end
        elseif meta.isWeight and not meta.isMotorized and not meta.isTrailer then
            if bestWeightInfo == nil then
                bestWeightInfo = info
            end
        elseif not meta.isMotorized and not meta.isTrailer and not meta.isWeight then
            if fallbackPlowInfo == nil then
                fallbackPlowInfo = info
            end

            if meta.isPlowTool then
                local power = self:getVehicleInfoPowerScore(info)
                if bestPlowInfo == nil or power > bestPlowPower then
                    bestPlowInfo = info
                    bestPlowPower = power
                end
            end
        end
    end

    if hasLiveMetaFallback then
        mission.nfwPlowMetaFallbackUsed = true
        mission.nfwPlowVehiclesFiltered = nil
        mission.nfwPlowExpectedVehicleCount = nil
        return
    end

    mission.nfwPlowMetaFallbackUsed = nil
    if bestPlowInfo == nil then
        bestPlowInfo = fallbackPlowInfo
    end

    local filtered = {}
    local kept = {}
    local removed = {}
    if bestTractorInfo ~= nil then
        table.insert(filtered, bestTractorInfo)
        table.insert(kept, tostring(bestTractorInfo.filename))
    end
    if bestWeightInfo ~= nil then
        table.insert(filtered, bestWeightInfo)
        table.insert(kept, tostring(bestWeightInfo.filename))
    end
    if bestPlowInfo ~= nil then
        table.insert(filtered, bestPlowInfo)
        table.insert(kept, tostring(bestPlowInfo.filename))
    end

    local keepLookup = {}
    for _, info in ipairs(filtered) do
        keepLookup[tostring(info)] = true
    end

    for _, info in ipairs(mission.vehiclesToLoad) do
        if not keepLookup[tostring(info)] then
            table.insert(removed, tostring(info ~= nil and info.filename or "unknown"))
        end
    end

    if #filtered > 0 then
        mission.vehiclesToLoad = filtered
        mission.nfwPlowVehiclesFiltered = true
        mission.nfwPlowExpectedVehicleCount = #filtered
    else
        mission.nfwPlowExpectedVehicleCount = nil
    end

    if #removed > 0 then
        nfwLogInfo(
            "[%s] Pflug-Mission gefiltert: mission=%s kept=%d removed=%d vehicles=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            #filtered,
            #removed,
            table.concat(removed, ", ")
        )
        if #kept > 0 then
            nfwLogInfo("[%s] Pflug-Mission behalten: mission=%s vehicles=%s", self.MOD_NAME,
                tostring(self:getMissionKey(mission)), table.concat(kept, ", "))
        end
    end
end

function NeighborFieldWorkers:getCombineFillStatus(vehicle)
    if vehicle == nil
        or vehicle.spec_combine == nil
        or vehicle.getFillUnitCapacity == nil
        or vehicle.getFillUnitFillLevel == nil then
        return nil, nil, nil
    end

    local fillUnitIndex = vehicle.spec_combine.fillUnitIndex
    if fillUnitIndex == nil then
        return nil, nil, nil
    end

    local fillLevel = vehicle:getFillUnitFillLevel(fillUnitIndex)
    local capacity = vehicle:getFillUnitCapacity(fillUnitIndex)
    if type(fillLevel) ~= "number"
        or type(capacity) ~= "number"
        or capacity <= 0
        or capacity == math.huge then
        return nil, nil, nil
    end

    local pct = nfwClamp(fillLevel / math.max(capacity, 0.0001), 0, 1)
    return math.floor(pct * 100 + 0.5), fillLevel, capacity
end

function NeighborFieldWorkers:tryInstallAIJobStopHook()
    if self.aiJobStopHookInstalled then
        return
    end

    if type(AIJob) ~= "table" or type(AIJob.stop) ~= "function" then
        return
    end

    if AIJob.nfwNeighborStopHookInstalled == true then
        self.aiJobStopHookInstalled = true
        if self.originalAIJobStop == nil and AIJob.nfwNeighborStopOriginal ~= nil then
            self.originalAIJobStop = AIJob.nfwNeighborStopOriginal
        end
        return
    end

    local originalStop = AIJob.stop
    self.originalAIJobStop = originalStop
    AIJob.nfwNeighborStopOriginal = originalStop

    AIJob.stop = function(job, aiMessage, ...)
        local stopTrace = nil
        if type(debug) == "table" and type(debug.traceback) == "function" then
            stopTrace = debug.traceback("", 2)
        end

        if NeighborFieldWorkers ~= nil and NeighborFieldWorkers.onAIJobStopped ~= nil then
            local okHook, err = pcall(NeighborFieldWorkers.onAIJobStopped, NeighborFieldWorkers, job, aiMessage,
                stopTrace)
            if not okHook then
                nfwLogHelperDiag(
                    "[%s] HelperDiag JOB_STOP_HOOK_ERROR: %s",
                    NeighborFieldWorkers.MOD_NAME,
                    tostring(err)
                )
            end
        end

        return originalStop(job, aiMessage, ...)
    end

    AIJob.nfwNeighborStopHookInstalled = true
    self.aiJobStopHookInstalled = true
    nfwLogInfo("[%s] AIJob.stop Hook aktiv", self.MOD_NAME)
end

function NeighborFieldWorkers:findActiveHarvestAssignmentByRootVehicle(rootVehicle)
    if rootVehicle == nil then
        return nil
    end

    for _, assignment in pairs(self.activeAssignments) do
        if assignment ~= nil
            and assignment.aiStarted
            and assignment.mission ~= nil
            and self:isHarvestMission(assignment.mission)
            and assignment.vehicle ~= nil
            and not assignment.vehicle.isDeleted then
            local assignmentRoot = assignment.vehicle.rootVehicle or assignment.vehicle
            if assignmentRoot == rootVehicle then
                return assignment
            end
        end
    end

    return nil
end

function NeighborFieldWorkers:shouldBypassNoTrailerHarvestStop(strategy)
    if strategy == nil or strategy.vehicle == nil then
        return false, nil, "strategyOrVehicle=nil"
    end

    local rootVehicle = strategy.vehicle.rootVehicle or strategy.vehicle
    if rootVehicle == nil or rootVehicle.isDeleted then
        return false, nil, "rootVehicle=nilOrDeleted"
    end

    if self.neighborFarmId ~= nil and rootVehicle.getOwnerFarmId ~= nil then
        local okFarm, ownerFarmId = pcall(rootVehicle.getOwnerFarmId, rootVehicle)
        if okFarm and ownerFarmId ~= self.neighborFarmId then
            return false, nil, "notNeighborFarm"
        end
    end

    local assignment = self:findActiveHarvestAssignmentByRootVehicle(rootVehicle)
    if assignment == nil then
        return false, nil, "noActiveHarvestAssignment"
    end

    if type(strategy.combines) ~= "table" then
        return false, assignment, "combines=nil"
    end

    local hasInfiniteDischargeCapacity = false
    local hasNoTrailerNearby = false
    for _, combine in pairs(strategy.combines) do
        if combine ~= nil
            and not combine.isDeleted
            and combine.getCurrentDischargeNode ~= nil
            and combine.getFillUnitCapacity ~= nil then
            local dischargeNode = combine:getCurrentDischargeNode()
            if dischargeNode ~= nil and dischargeNode.fillUnitIndex ~= nil then
                local capacityFn = combine.nfwOriginalGetFillUnitCapacity or combine.getFillUnitCapacity
                local okCap, cap = pcall(capacityFn, combine, dischargeNode.fillUnitIndex)
                if okCap and cap == math.huge then
                    hasInfiniteDischargeCapacity = true
                    local trailerNearby = false
                    if combine.spec_pipe ~= nil and combine.spec_pipe.nearestObjectInTriggers ~= nil and NetworkUtil ~= nil and NetworkUtil.getObject ~= nil then
                        trailerNearby = NetworkUtil.getObject(combine.spec_pipe.nearestObjectInTriggers.objectId) ~= nil
                    end
                    if not trailerNearby then
                        hasNoTrailerNearby = true
                    end

                    if combine.spec_pipe ~= nil and combine.spec_pipe.turnOnAllowedStates ~= nil then
                        combine.spec_pipe.turnOnAllowedStates = {}
                    end
                    if combine.spec_combine ~= nil then
                        combine.spec_combine.turnOffWhenFull = false
                    end
                end
            end
        end
    end

    if not hasInfiniteDischargeCapacity then
        return false, assignment, "noInfiniteDischargeCapacity"
    end

    if not hasNoTrailerNearby then
        return false, assignment, "trailerNearby"
    end

    if rootVehicle.getCanStartFieldWork ~= nil then
        local okStart, canStartNow = pcall(rootVehicle.getCanStartFieldWork, rootVehicle)
        if okStart and canStartNow == true then
            return false, assignment, "canStartFieldWork=true"
        end
    end

    if rootVehicle.getCanAIFieldWorkerContinueWork ~= nil then
        local okContinue, canContinue, stopAI = pcall(rootVehicle.getCanAIFieldWorkerContinueWork, rootVehicle, false)
        if okContinue and (canContinue ~= true or stopAI == true) then
            return false, assignment,
                string.format("continueBlocked(can=%s stop=%s)", tostring(canContinue), tostring(stopAI))
        end
    end

    return true, assignment, "noTrailerHardStopCandidate"
end

function NeighborFieldWorkers:tryInstallCombineDriveHook()
    if self.combineDriveHookInstalled then
        return
    end

    if type(AIDriveStrategyCombine) ~= "table" or type(AIDriveStrategyCombine.getDriveData) ~= "function" then
        return
    end

    if AIDriveStrategyCombine.nfwNeighborGetDriveDataHookInstalled == true then
        self.combineDriveHookInstalled = true
        return
    end

    AIDriveStrategyCombine.getDriveData = Utils.overwrittenFunction(
        AIDriveStrategyCombine.getDriveData,
        function(strategy, superFunc, dt, vX, vY, vZ)
            local x, z, moveForwards, maxSpeed, distance = superFunc(strategy, dt, vX, vY, vZ)

            if NeighborFieldWorkers ~= nil then
                local shouldBypass, assignment, bypassReason = NeighborFieldWorkers:shouldBypassNoTrailerHarvestStop(
                    strategy)
                local looksLikeHardStop = x == 0 and z == 1 and moveForwards == true and maxSpeed == 0 and
                    distance == math.huge
                local now = g_time or 0

                if assignment ~= nil and now >= Utils.getNoNil(assignment.nextCombineDriveDiagAtMs, 0) then
                    assignment.nextCombineDriveDiagAtMs = now + 2500
                    local rootVehicle = strategy ~= nil and strategy.vehicle ~= nil and
                        (strategy.vehicle.rootVehicle or strategy.vehicle) or nil
                    local vehicleName = rootVehicle ~= nil and rootVehicle.getName ~= nil and rootVehicle:getName() or
                        "unknown"
                    nfwLogHelperDiag(
                        "[%s] HelperDiag COMBINE_DRIVE: mission=%s vehicle=%s bypass=%s reason=%s hardStop=%s out={x=%s z=%s fw=%s max=%.2f dist=%s} runtime={%s}",
                        NeighborFieldWorkers.MOD_NAME,
                        tostring(assignment.key),
                        tostring(vehicleName),
                        tostring(shouldBypass),
                        tostring(bypassReason),
                        tostring(looksLikeHardStop),
                        tostring(x),
                        tostring(z),
                        tostring(moveForwards),
                        tonumber(maxSpeed) or -1,
                        tostring(distance),
                        nfwToSingleLineText(NeighborFieldWorkers:getHarvestVehicleRuntimeDebug(rootVehicle), 320)
                    )
                end

                if shouldBypass and looksLikeHardStop then
                    if assignment ~= nil and now >= Utils.getNoNil(assignment.nextCombineDriveBypassLogAtMs, 0) then
                        assignment.nextCombineDriveBypassLogAtMs = now + 2500
                        nfwLogHelperDiag(
                            "[%s] HelperDiag HARVEST_NO_TRAILER_BYPASS_APPLIED: mission=%s reason=%s",
                            NeighborFieldWorkers.MOD_NAME,
                            tostring(assignment.key),
                            tostring(bypassReason)
                        )
                    end
                    return nil, nil, nil, math.huge, nil
                end
            end

            return x, z, moveForwards, maxSpeed, distance
        end
    )

    AIDriveStrategyCombine.nfwNeighborGetDriveDataHookInstalled = true
    self.combineDriveHookInstalled = true
    nfwLogInfo("[%s] AIDriveStrategyCombine.getDriveData Hook aktiv", self.MOD_NAME)
end

function NeighborFieldWorkers:tryInstallFieldCourseDetectionHook()
    if self.fieldCourseDetectionHookInstalled then
        return
    end

    if type(AIDriveStrategyFieldCourse) ~= "table" or type(AIDriveStrategyFieldCourse.setAIVehicle) ~= "function" then
        return
    end

    if AIDriveStrategyFieldCourse.nfwNeighborDetectionHookInstalled == true then
        self.fieldCourseDetectionHookInstalled = true
        return
    end

    AIDriveStrategyFieldCourse.setAIVehicle = Utils.overwrittenFunction(
        AIDriveStrategyFieldCourse.setAIVehicle,
        function(strategy, superFunc, vehicle)
            local previousDetectionPosition = AIDriveStrategyFieldCourse.fieldDetectionPosition
            local pending = nil
            if NeighborFieldWorkers ~= nil and NeighborFieldWorkers.pendingFieldDetectionByVehicle ~= nil and vehicle ~= nil then
                pending = NeighborFieldWorkers.pendingFieldDetectionByVehicle[vehicle]
            end

            if pending ~= nil and pending.x ~= nil and pending.z ~= nil then
                AIDriveStrategyFieldCourse.fieldDetectionPosition = { pending.x, pending.z }
                pending.appliedAtMs = g_time or 0
                nfwLogHelperDiag(
                    "[%s] HelperDiag DETECT_OVERRIDE_APPLY: mission=%s vehicle=%s detect=(%.1f/%.1f)",
                    NeighborFieldWorkers.MOD_NAME,
                    tostring(Utils.getNoNil(pending.missionKey, "n/a")),
                    tostring(vehicle ~= nil and vehicle.getName ~= nil and vehicle:getName() or "unknown"),
                    pending.x,
                    pending.z
                )
            end

            local ok, resultOrErr = pcall(superFunc, strategy, vehicle)

            if pending ~= nil and NeighborFieldWorkers ~= nil and NeighborFieldWorkers.pendingFieldDetectionByVehicle ~= nil and vehicle ~= nil then
                NeighborFieldWorkers.pendingFieldDetectionByVehicle[vehicle] = nil
            end
            AIDriveStrategyFieldCourse.fieldDetectionPosition = previousDetectionPosition

            if not ok then
                error(resultOrErr)
            end

            return resultOrErr
        end
    )

    AIDriveStrategyFieldCourse.nfwNeighborDetectionHookInstalled = true
    self.fieldCourseDetectionHookInstalled = true
    nfwLogInfo("[%s] AIDriveStrategyFieldCourse.setAIVehicle Hook aktiv", self.MOD_NAME)
end

function NeighborFieldWorkers:tryInstallFieldCourseDriveHook()
    if self.fieldCourseDriveHookInstalled then
        return
    end

    if type(AIDriveStrategyFieldCourse) ~= "table" or type(AIDriveStrategyFieldCourse.getDriveData) ~= "function" then
        return
    end

    if AIDriveStrategyFieldCourse.nfwNeighborDriveDataHookInstalled == true then
        self.fieldCourseDriveHookInstalled = true
        return
    end

    AIDriveStrategyFieldCourse.getDriveData = Utils.overwrittenFunction(
        AIDriveStrategyFieldCourse.getDriveData,
        function(strategy, superFunc, dt, vX, vY, vZ)
            local tX, tZ, moveForwards, maxSpeed, distanceToStop = superFunc(strategy, dt, vX, vY, vZ)

            if NeighborFieldWorkers ~= nil then
                local vehicle = strategy ~= nil and strategy.vehicle or nil
                local rootVehicle = vehicle ~= nil and (vehicle.rootVehicle or vehicle) or nil
                local assignment = rootVehicle ~= nil and
                    NeighborFieldWorkers:findActiveHarvestAssignmentByRootVehicle(rootVehicle) or nil
                if assignment ~= nil then
                    local now = g_time or 0
                    if now >= Utils.getNoNil(assignment.nextFieldCourseDriveDiagAtMs, 0) then
                        assignment.nextFieldCourseDriveDiagAtMs = now + 2500

                        local canStartNow = nil
                        if rootVehicle ~= nil and rootVehicle.getCanStartFieldWork ~= nil then
                            local okStart, startValue = pcall(rootVehicle.getCanStartFieldWork, rootVehicle)
                            canStartNow = okStart and startValue or ("err:" .. nfwToSingleLineText(startValue, 120))
                        end

                        local continueFalse = "n/a"
                        local continueTrue = "n/a"
                        if rootVehicle ~= nil and rootVehicle.getCanAIFieldWorkerContinueWork ~= nil then
                            local okF, cF, sF, rF = pcall(rootVehicle.getCanAIFieldWorkerContinueWork, rootVehicle, false)
                            local okT, cT, sT, rT = pcall(rootVehicle.getCanAIFieldWorkerContinueWork, rootVehicle, true)
                            continueFalse = okF and
                                string.format("can=%s stop=%s reason=%s", tostring(cF), tostring(sF),
                                    NeighborFieldWorkers:getAIMessageNameByInstance(rF))
                                or ("err=" .. nfwToSingleLineText(cF, 120))
                            continueTrue = okT and
                                string.format("can=%s stop=%s reason=%s", tostring(cT), tostring(sT),
                                    NeighborFieldWorkers:getAIMessageNameByInstance(rT))
                                or ("err=" .. nfwToSingleLineText(cT, 120))
                        end

                        local runtime = NeighborFieldWorkers:getHarvestVehicleRuntimeDebug(rootVehicle)
                        nfwLogHelperDiag(
                            "[%s] HelperDiag FIELDCOURSE_DRIVE: mission=%s vehicle=%s out={x=%s z=%s fw=%s max=%s dist=%s} state={detect=%s notOwned=%s blocked=%s staticCollision=%s staticTimer=%s collisionDist=%s lastContinue=%s lastBlockedAt=%s hasCourse=%s} canStart=%s continueFalse={%s} continueTrue={%s} runtime={%s}",
                            NeighborFieldWorkers.MOD_NAME,
                            tostring(assignment.key),
                            tostring(rootVehicle ~= nil and rootVehicle.getName ~= nil and rootVehicle:getName() or
                                "unknown"),
                            tostring(tX),
                            tostring(tZ),
                            tostring(moveForwards),
                            tostring(maxSpeed),
                            tostring(distanceToStop),
                            tostring(strategy ~= nil and strategy.fieldDetectionInProgress or nil),
                            tostring(strategy ~= nil and strategy.fieldNotOwned or nil),
                            tostring(strategy ~= nil and strategy.isBlocked or nil),
                            tostring(strategy ~= nil and strategy.hasStaticCollision or nil),
                            tostring(strategy ~= nil and strategy.hasStaticCollisionTimer or nil),
                            tostring(strategy ~= nil and strategy.collisionDistance or nil),
                            tostring(strategy ~= nil and strategy.lastContinueWorkState or nil),
                            tostring(strategy ~= nil and strategy.lastContinueWorkBlockedTime or nil),
                            tostring(strategy ~= nil and strategy.aiFieldCourse ~= nil),
                            tostring(canStartNow),
                            continueFalse,
                            continueTrue,
                            nfwToSingleLineText(runtime, 320)
                        )
                    end
                end
            end

            return tX, tZ, moveForwards, maxSpeed, distanceToStop
        end
    )

    AIDriveStrategyFieldCourse.nfwNeighborDriveDataHookInstalled = true
    self.fieldCourseDriveHookInstalled = true
    nfwLogInfo("[%s] AIDriveStrategyFieldCourse.getDriveData Hook aktiv", self.MOD_NAME)
end

function NeighborFieldWorkers:registerPendingFieldDetectionOverride(assignment, vehicle, detectionX, detectionZ)
    if vehicle == nil or vehicle.isDeleted or detectionX == nil or detectionZ == nil then
        return
    end

    if self.pendingFieldDetectionByVehicle == nil then
        self.pendingFieldDetectionByVehicle = {}
    end

    local now = g_time or 0
    local missionKey = assignment ~= nil and tostring(assignment.key) or "n/a"
    self.pendingFieldDetectionByVehicle[vehicle] = {
        missionKey = missionKey,
        x = detectionX,
        z = detectionZ,
        createdAtMs = now,
        expiresAtMs = now + 30000
    }

    nfwLogHelperDiag(
        "[%s] HelperDiag DETECT_OVERRIDE_ARM: mission=%s vehicle=%s detect=(%.1f/%.1f)",
        self.MOD_NAME,
        missionKey,
        tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
        detectionX,
        detectionZ
    )
end

function NeighborFieldWorkers:cleanupPendingFieldDetectionOverrides(now)
    if self.pendingFieldDetectionByVehicle == nil then
        return
    end

    if now < Utils.getNoNil(self.nextPendingFieldDetectionCleanupAtMs, 0) then
        return
    end
    self.nextPendingFieldDetectionCleanupAtMs = now + 5000

    local removed = 0
    for vehicle, pending in pairs(self.pendingFieldDetectionByVehicle) do
        local expiresAtMs = Utils.getNoNil(pending ~= nil and pending.expiresAtMs or nil, 0)
        if vehicle == nil or vehicle.isDeleted or (expiresAtMs > 0 and now > expiresAtMs) then
            self.pendingFieldDetectionByVehicle[vehicle] = nil
            removed = removed + 1
        end
    end

    if removed > 0 then
        nfwLogHelperDiag(
            "[%s] HelperDiag DETECT_OVERRIDE_CLEANUP: removed=%d",
            self.MOD_NAME,
            removed
        )
    end
end

function NeighborFieldWorkers:onAIJobStopped(job, aiMessage, stopTrace)
    if job == nil then
        return
    end

    local assignment = nil
    for _, entry in pairs(self.activeAssignments) do
        if entry ~= nil and entry.giantsJob == job then
            assignment = entry
            break
        end
    end

    local startedFarmId = job.startedFarmId
    local isNeighborJob = self.neighborFarmId ~= nil and startedFarmId == self.neighborFarmId
    if assignment == nil and not isNeighborJob then
        return
    end

    local messageName = "nil"
    local messageType = "nil"
    local messageText = "nil"
    local messageI18N = "nil"
    if aiMessage ~= nil then
        messageName = self:getAIMessageNameByInstance(aiMessage)

        if aiMessage.getType ~= nil then
            local okType, aiType = pcall(aiMessage.getType, aiMessage)
            if okType and aiType ~= nil then
                messageType = tostring(aiType)
            end
        end
        if aiMessage.getMessage ~= nil then
            local okText, text = pcall(aiMessage.getMessage, aiMessage, job)
            if okText and text ~= nil then
                messageText = tostring(text)
            end
        end
        if aiMessage.getI18NText ~= nil then
            local okI18n, i18n = pcall(aiMessage.getI18NText, aiMessage)
            if okI18n and i18n ~= nil then
                messageI18N = tostring(i18n)
            end
        end
    end

    local jobDesc = "n/a"
    if job.getDescription ~= nil then
        local okDesc, desc = pcall(job.getDescription, job)
        if okDesc and desc ~= nil then
            jobDesc = tostring(desc)
        end
    end

    local helperName = "n/a"
    if g_helperManager ~= nil and g_helperManager.getHelperByIndex ~= nil and job.helperIndex ~= nil then
        local helper = g_helperManager:getHelperByIndex(job.helperIndex)
        if helper ~= nil then
            helperName = tostring(Utils.getNoNil(helper.title, helper.name or "n/a"))
        end
    end

    local missionKey = assignment ~= nil and tostring(assignment.key) or "n/a"
    local vehicleName = "n/a"
    local missionType = "n/a"
    if assignment ~= nil then
        if assignment.vehicle ~= nil and assignment.vehicle.getName ~= nil then
            vehicleName = tostring(assignment.vehicle:getName())
        end
        if assignment.mission ~= nil then
            missionType = tostring(self:getMissionTypeName(assignment.mission))
        end
    end

    local taskIndexNumber = tonumber(job.currentTaskIndex) or 0
    local reasonCompact = string.format("%s|%s|%s", messageName, messageType,
        messageI18N ~= "nil" and messageI18N or messageText)
    if assignment ~= nil then
        assignment.helperDiagLastStopReason = reasonCompact
        assignment.helperDiagLastStopAtMs = g_time or 0
        if messageName == "ERROR_NO_FIELD_FOUND" then
            assignment.noFieldRetryIndex = Utils.getNoNil(assignment.noFieldRetryIndex, 0) + 1
            assignment.forceDirectStart = true
            assignment.forceRecoveryReposition = false
            assignment.suppressRelocateDuringSprayerAttach = false
        elseif messageName == "ERROR_NOT_REACHABLE" then
            assignment.noFieldRetryIndex = math.max(1, Utils.getNoNil(assignment.noFieldRetryIndex, 1))
            assignment.forceDirectStart = self.fieldEdgeStartModeEnabled ~= true
            assignment.forceRecoveryReposition = false
            assignment.suppressRelocateDuringSprayerAttach = false
            if self.fieldEdgeStartModeEnabled == true then
                assignment.disableEdgeStartForMission = true
                nfwLogHelperDiag(
                    "[%s] HelperDiag EDGE_FALLBACK_ARMED: mission=%s vehicle=%s reason=ERROR_NOT_REACHABLE action=disableEdgeStartForMission",
                    self.MOD_NAME,
                    missionKey,
                    vehicleName
                )
            end
        elseif messageName == "ERROR_UNKNOWN"
            and taskIndexNumber == 1
            and self.fieldEdgeStartModeEnabled == true
            and assignment.disableEdgeStartForMission ~= true then
            assignment.forceDirectStart = true
            assignment.forceRecoveryReposition = false
            assignment.suppressRelocateDuringSprayerAttach = false
            assignment.disableEdgeStartForMission = true
            nfwLogHelperDiag(
                "[%s] HelperDiag EDGE_FALLBACK_ARMED: mission=%s vehicle=%s reason=ERROR_UNKNOWN_TASK1 action=disableEdgeStartForMission+forceDirectStart",
                self.MOD_NAME,
                missionKey,
                vehicleName
            )
        elseif messageName == "ERROR_COULD_NOT_PREPARE"
            and taskIndexNumber == 1 then
            assignment.forceDirectStart = true
            assignment.forceRecoveryReposition = false
            assignment.suppressRelocateDuringSprayerAttach = false
            if self.fieldEdgeStartModeEnabled == true then
                assignment.disableEdgeStartForMission = true
                nfwLogHelperDiag(
                    "[%s] HelperDiag EDGE_FALLBACK_ARMED: mission=%s vehicle=%s reason=ERROR_COULD_NOT_PREPARE_TASK1 action=disableEdgeStartForMission+forceDirectStart",
                    self.MOD_NAME,
                    missionKey,
                    vehicleName
                )
            end
        else
            assignment.noFieldRetryIndex = 0
        end
    end

    nfwLogHelperDiag(
        "[%s] HelperDiag JOB_STOP: mission=%s type=%s vehicle=%s farmId=%s helper=%s jobDesc=%s msgName=%s msgType=%s msgI18N=%s msgText=%s taskIndex=%s",
        self.MOD_NAME,
        missionKey,
        missionType,
        vehicleName,
        tostring(startedFarmId),
        helperName,
        jobDesc,
        messageName,
        messageType,
        messageI18N,
        messageText,
        tostring(job.currentTaskIndex)
    )

    local isSowUnknownStop = assignment ~= nil
        and messageName == "ERROR_UNKNOWN"
        and self:isSowMission(assignment.mission)
    if (messageName == "ERROR_NO_FIELD_FOUND" or messageName == "ERROR_FIELD_NOT_READY" or isSowUnknownStop)
        and type(stopTrace) == "string"
        and stopTrace ~= "" then
        local compactTrace = string.gsub(stopTrace, "[\r\n]+", " | ")
        if string.len(compactTrace) > 1400 then
            compactTrace = string.sub(compactTrace, 1, 1400) .. "..."
        end
        nfwLogHelperDiag(
            "[%s] HelperDiag JOB_STOP_TRACE: mission=%s vehicle=%s trace=%s",
            self.MOD_NAME,
            missionKey,
            vehicleName,
            compactTrace
        )
    end

    local autoCompletionQueued = false
    if assignment ~= nil then
        self:logStopRootCauseDiagnostics(assignment, job, messageName, stopTrace)

        if self:isHarvestMission(assignment.mission)
            and (messageName == "ERROR_UNKNOWN"
                or messageName == "ERROR_NO_FIELD_FOUND"
                or messageName == "ERROR_FIELD_NOT_READY") then
            local diagVehicle = assignment.vehicle
            if diagVehicle == nil or diagVehicle.isDeleted or diagVehicle.rootNode == nil then
                diagVehicle = self:findMissionWorkVehicle(assignment)
            end
            if diagVehicle ~= nil and diagVehicle.rootNode ~= nil then
                local diagSpeed = diagVehicle.getLastSpeed ~= nil and diagVehicle:getLastSpeed() or 0
                self:logHarvestBlockedDeepDiagnostics(assignment, diagVehicle, assignment.mission, g_time or 0, diagSpeed)
            end
        end

        local shouldAutoComplete, autoReason = self:shouldAutoCompleteAssignmentAfterStop(assignment, messageName)
        if shouldAutoComplete then
            autoCompletionQueued = self:queueAssignmentAutoCompletion(assignment, autoReason)
            nfwLogHelperDiag(
                "[%s] HelperDiag JOB_STOP_AUTOCOMPLETE: mission=%s vehicle=%s msgName=%s reason=%s",
                self.MOD_NAME,
                missionKey,
                vehicleName,
                tostring(messageName),
                tostring(autoReason)
            )
        end
    end

    if assignment ~= nil and messageName == "ERROR_NO_FIELD_FOUND" and not autoCompletionQueued then
        nfwLogHelperDiag(
            "[%s] HelperDiag JOB_STOP_FALLBACK: mission=%s vehicle=%s action=forceDirectStart+reposition noFieldRetryIndex=%s",
            self.MOD_NAME,
            missionKey,
            vehicleName,
            tostring(Utils.getNoNil(assignment.noFieldRetryIndex, 0))
        )
    end
end

function NeighborFieldWorkers:shouldSuppressNeighborMoneyCost(amount, farmId, moneyType)
    if not self:isNeighborFarm(farmId) then
        return false
    end

    if self.allowNeighborDebit then
        return false
    end

    if type(amount) ~= "number" or amount >= 0 then
        return false
    end

    local blocked = {
        AI = true,
        PURCHASE_FUEL = true,
        PURCHASE_FERTILIZER = true,
        PURCHASE_CONSUMABLES = true,
        PURCHASE_SEEDS = true,
        VEHICLE_RUNNING_COSTS = true,
        LEASING_COSTS = true,
        PROPERTY_MAINTENANCE = true
    }

    if type(MoneyType) == "table" and moneyType ~= nil then
        for key, _ in pairs(blocked) do
            if MoneyType[key] ~= nil and moneyType == MoneyType[key] then
                return true
            end
        end
    end

    return true
end

function NeighborFieldWorkers:tryInstallMissionMoneyHooks()
    if self.missionMoneyHookInstalled then
        return
    end

    if g_currentMission == nil then
        return
    end

    if type(g_currentMission.addMoney) ~= "function" then
        return
    end

    self.originalMissionAddMoney = g_currentMission.addMoney
    g_currentMission.addMoney = function(mission, amount, farmId, moneyType, ...)
        if NeighborFieldWorkers ~= nil and NeighborFieldWorkers:shouldSuppressNeighborMoneyCost(amount, farmId, moneyType) then
            return NeighborFieldWorkers.originalMissionAddMoney(mission, 0, farmId, moneyType, ...)
        end

        return NeighborFieldWorkers.originalMissionAddMoney(mission, amount, farmId, moneyType, ...)
    end

    if type(g_currentMission.addMoneyChange) == "function" then
        self.originalMissionAddMoneyChange = g_currentMission.addMoneyChange
        g_currentMission.addMoneyChange = function(mission, amount, farmId, moneyType, ...)
            if NeighborFieldWorkers ~= nil and NeighborFieldWorkers:shouldSuppressNeighborMoneyCost(amount, farmId, moneyType) then
                return NeighborFieldWorkers.originalMissionAddMoneyChange(mission, 0, farmId, moneyType, ...)
            end

            return NeighborFieldWorkers.originalMissionAddMoneyChange(mission, amount, farmId, moneyType, ...)
        end
    end

    self.missionMoneyHookInstalled = true
    nfwLogInfo("[%s] Money-Hook aktiv: Nachbar-Kosten werden unterdrueckt", self.MOD_NAME)
end

function NeighborFieldWorkers:setNeighborFarmBalance(targetBalance, reason)
    if g_farmManager == nil or g_currentMission == nil or self.neighborFarmId == nil then
        return false
    end

    local farm = g_farmManager:getFarmById(self.neighborFarmId)
    if farm == nil then
        return false
    end

    local currentBalance = farm.money
    if type(currentBalance) ~= "number" and farm.getBalance ~= nil then
        local okBalance, balance = pcall(farm.getBalance, farm)
        if okBalance and type(balance) == "number" then
            currentBalance = balance
        end
    end
    if type(currentBalance) ~= "number" then
        return false
    end

    targetBalance = math.floor(Utils.getNoNil(targetBalance, 1) + 0.5)
    currentBalance = math.floor(currentBalance + 0.5)
    if currentBalance == targetBalance then
        return false
    end

    if type(farm.money) == "number" then
        farm.money = targetBalance
    else
        local delta = targetBalance - currentBalance
        self.allowNeighborDebit = true
        local moneyType = nil
        if type(MoneyType) == "table" then
            moneyType = MoneyType.PROPERTY_INCOME or MoneyType.MISSIONS or MoneyType.AI
        end
        pcall(g_currentMission.addMoney, g_currentMission, delta, self.neighborFarmId, moneyType, false, false)
        self.allowNeighborDebit = false
    end

    nfwLogInfo(
        "[%s] Nachbar-Farm Guthaben gesetzt: farmId=%s old=%d new=%d reason=%s",
        self.MOD_NAME,
        tostring(self.neighborFarmId),
        currentBalance,
        targetBalance,
        tostring(reason or "n/a")
    )
    return true
end

function NeighborFieldWorkers:ensureDynamicHelperPoolCapacity()
    if g_helperManager == nil
        or g_helperManager.getNumOfHelpers == nil
        or g_helperManager.addHelper == nil then
        return
    end

    local currentTotal = g_helperManager:getNumOfHelpers()
    self:refreshModHelperTitles()
    local observedBase = math.max(0, currentTotal - Utils.getNoNil(self.dynamicNeighborHelpersAdded, 0))
    if self.helperBaseCapacity == nil or observedBase > self.helperBaseCapacity then
        self.helperBaseCapacity = observedBase
    end

    local neighborDemand = self:getActiveAssignmentCount()
    if neighborDemand <= 0 then
        return
    end

    local desiredTotal = Utils.getNoNil(self.helperBaseCapacity, currentTotal) + neighborDemand
    if currentTotal >= desiredTotal then
        return
    end

    local toAdd = desiredTotal - currentTotal
    local templateStyle = nil
    if g_helperManager.getHelperByIndex ~= nil and currentTotal > 0 then
        local helperTemplate = g_helperManager:getHelperByIndex(1)
        if helperTemplate ~= nil then
            templateStyle = helperTemplate.playerStyle
        end
    end

    local added = 0
    for i = 1, toAdd do
        local helperIndex = currentTotal + added + 1
        local helperDisplayName = self:getOrCreateNeighborHelperNameForIndex(helperIndex)
        local helperId = nfwBuildUniqueHelperIdFromDisplayName(helperDisplayName, helperIndex)

        local helper = g_helperManager:addHelper(helperId, helperDisplayName, self.NEIGHBOR_FARM_COLOR, templateStyle,
            self.MOD_DIR, false)
        if helper ~= nil then
            local effectiveIndex = helper.index ~= nil and helper.index or helperIndex
            local effectiveDisplayName = self:getOrCreateNeighborHelperNameForIndex(effectiveIndex)
            helper.title = effectiveDisplayName
            helper.name = effectiveDisplayName
            self.neighborHelperNamesByIndex[tostring(effectiveIndex)] = effectiveDisplayName
            self.dynamicNeighborHelperIndices[effectiveIndex] = true
            added = added + 1
        end
    end

    if added > 0 then
        self.dynamicNeighborHelpersAdded = Utils.getNoNil(self.dynamicNeighborHelpersAdded, 0) + added
        local now = g_time or 0
        if now >= Utils.getNoNil(self.nextHelperPoolLogAtMs, 0) then
            self.nextHelperPoolLogAtMs = now + 5000
            nfwLogInfo(
                "[%s] Helper-Pool erweitert: added=%d base=%d total=%d neighborDemand=%d",
                self.MOD_NAME,
                added,
                Utils.getNoNil(self.helperBaseCapacity, 0),
                g_helperManager:getNumOfHelpers(),
                neighborDemand
            )
        end
    end
end

function NeighborFieldWorkers:getMissionPreferredConsumableFillType(mission, supportedFillTypes)
    if mission == nil or supportedFillTypes == nil then
        return nil
    end

    local typeName = self:getMissionTypeNameLower(mission)
    local missionRequiredFillType = self:getMissionRequiredFillType(mission)

    if missionRequiredFillType ~= nil and supportedFillTypes[missionRequiredFillType] then
        return missionRequiredFillType
    end

    if self:isSowMission(mission) then
        local missionSowFruitType = self:getMissionSowFruitType(mission)
        local missionSowFillType = self:getMissionSowFillType(mission, missionSowFruitType)
        if missionSowFillType ~= nil and supportedFillTypes[missionSowFillType] then
            return missionSowFillType
        end
        if FillType.SEEDS ~= nil and supportedFillTypes[FillType.SEEDS] then
            return FillType.SEEDS
        end
    end

    if string.find(typeName, "herbicid", 1, true) ~= nil or string.find(typeName, "spray", 1, true) ~= nil then
        if supportedFillTypes[FillType.HERBICIDE] then
            return FillType.HERBICIDE
        end
        if supportedFillTypes[FillType.LIQUIDFERTILIZER] then
            return FillType.LIQUIDFERTILIZER
        end
        if supportedFillTypes[FillType.FERTILIZER] then
            return FillType.FERTILIZER
        end
    end

    if string.find(typeName, "fertiliz", 1, true) ~= nil then
        if supportedFillTypes[FillType.FERTILIZER] then
            return FillType.FERTILIZER
        end
        if supportedFillTypes[FillType.LIQUIDFERTILIZER] then
            return FillType.LIQUIDFERTILIZER
        end
        if supportedFillTypes[FillType.DIGESTATE] then
            return FillType.DIGESTATE
        end
        if supportedFillTypes[FillType.LIQUIDMANURE] then
            return FillType.LIQUIDMANURE
        end
        if supportedFillTypes[FillType.MANURE] then
            return FillType.MANURE
        end
    end

    return nil
end

function NeighborFieldWorkers:getSowingVehiclePreferredFillType(vehicle, supportedFillTypes, missionSowFillType)
    if vehicle == nil or supportedFillTypes == nil then
        return nil
    end
    if vehicle.spec_sowingMachine == nil and vehicle.spec_planter == nil then
        return nil
    end

    -- For grass and most regular sowing contracts we must prioritize real seed fill.
    -- Some mod maps expose fruit fill types as "supported", which can block actual sowing.
    if FillType ~= nil and FillType.SEEDS ~= nil and supportedFillTypes[FillType.SEEDS] then
        return FillType.SEEDS
    end

    if missionSowFillType ~= nil and supportedFillTypes[missionSowFillType] then
        return missionSowFillType
    end

    return nil
end

function NeighborFieldWorkers:fillVehicleUnitFree(vehicle, fillUnitIndex, fillType, farmId)
    if vehicle == nil
        or vehicle.getFillUnitCapacity == nil
        or vehicle.getFillUnitFillLevel == nil
        or vehicle.addFillUnitFillLevel == nil then
        return false
    end

    local capacity = vehicle:getFillUnitCapacity(fillUnitIndex)
    local level = vehicle:getFillUnitFillLevel(fillUnitIndex)
    if type(capacity) ~= "number" or type(level) ~= "number" or capacity <= 0 then
        return false
    end

    local delta = capacity - level
    if delta <= 0.01 then
        return false
    end

    pcall(vehicle.addFillUnitFillLevel, vehicle, farmId, fillUnitIndex, delta, fillType, ToolType.UNDEFINED, nil)
    return true
end

function NeighborFieldWorkers:getMissionResourceTopupIntervalMs(mission)
    if self:isHarvestMission(mission) or self:isStoneMission(mission) then
        return 1000
    end

    return 5000
end

function NeighborFieldWorkers:getHarvestVoidFillUnitIndices(vehicle)
    local indices = {}
    local seen = {}

    local function addIndex(idx)
        if type(idx) ~= "number" then
            return
        end
        idx = math.floor(idx)
        if idx < 0 or seen[idx] then
            return
        end
        seen[idx] = true
        table.insert(indices, idx)
    end

    if vehicle == nil or vehicle.spec_combine == nil then
        return indices
    end

    local spec = vehicle.spec_combine
    addIndex(spec.fillUnitIndex)
    addIndex(spec.bufferFillUnitIndex)

    if vehicle.getCurrentDischargeNode ~= nil then
        local dischargeNode = vehicle:getCurrentDischargeNode()
        if dischargeNode ~= nil then
            addIndex(dischargeNode.fillUnitIndex)
        end
    end

    if vehicle.getFillUnits ~= nil then
        local fillUnits = vehicle:getFillUnits()
        if type(fillUnits) == "table" then
            for fillUnitIndex, _ in pairs(fillUnits) do
                addIndex(fillUnitIndex)
            end
        end
    end

    return indices
end

function NeighborFieldWorkers:isHarvestOutputFillUnit(vehicle, fillUnitIndex)
    if vehicle == nil
        or vehicle.spec_combine == nil
        or type(fillUnitIndex) ~= "number" then
        return false
    end

    local targetIndex = math.floor(fillUnitIndex)
    local spec = vehicle.spec_combine
    if spec.fillUnitIndex == targetIndex or spec.bufferFillUnitIndex == targetIndex then
        return true
    end

    if vehicle.nfwVoidDischargeFillUnitIndex == targetIndex then
        return true
    end

    if vehicle.getCurrentDischargeNode ~= nil then
        local dischargeNode = vehicle:getCurrentDischargeNode()
        if dischargeNode ~= nil and dischargeNode.fillUnitIndex == targetIndex then
            return true
        end
    end

    return false
end

function NeighborFieldWorkers:ensureFiniteHarvestVoidCapacity(vehicle)
    if vehicle == nil
        or vehicle.isDeleted
        or vehicle.spec_combine == nil
        or vehicle.getFillUnitCapacity == nil then
        return 0, 0
    end

    if type(vehicle.nfwVoidCapacityOverrideIndices) ~= "table" then
        vehicle.nfwVoidCapacityOverrideIndices = {}
    end

    if vehicle.nfwVoidCapacityOverrideInstalled ~= true and vehicle.getFillUnitCapacity ~= nil then
        vehicle.nfwOriginalGetFillUnitCapacity = vehicle.getFillUnitCapacity
        vehicle.getFillUnitCapacity = function(v, idx, ...)
            local original = v.nfwOriginalGetFillUnitCapacity
            local cap = original ~= nil and original(v, idx, ...) or 0
            if v.nfwVoidCapacityOverrideIndices ~= nil
                and v.nfwVoidCapacityOverrideIndices[idx] == true
                and cap == math.huge then
                return 1000000
            end
            return cap
        end
        vehicle.nfwVoidCapacityOverrideInstalled = true
    end

    local getCapacity = vehicle.nfwOriginalGetFillUnitCapacity or vehicle.getFillUnitCapacity
    local indices = self:getHarvestVoidFillUnitIndices(vehicle)
    local added = 0
    local total = 0

    for _, idx in ipairs(indices) do
        local cap = getCapacity(vehicle, idx)
        if cap == math.huge then
            total = total + 1
            if vehicle.nfwVoidCapacityOverrideIndices[idx] ~= true then
                vehicle.nfwVoidCapacityOverrideIndices[idx] = true
                added = added + 1
            end
        end
    end

    return added, total
end

function NeighborFieldWorkers:installHarvestVehicleDiagnosticHooks(vehicle)
    if vehicle == nil or vehicle.isDeleted or vehicle.spec_combine == nil then
        return
    end
    if vehicle.nfwHarvestDiagHooksInstalled == true then
        return
    end

    if vehicle.getCanStartFieldWork ~= nil then
        vehicle.nfwOriginalGetCanStartFieldWork = vehicle.getCanStartFieldWork
        vehicle.getCanStartFieldWork = function(v, ...)
            local result = v.nfwOriginalGetCanStartFieldWork(v, ...)
            v.nfwDiagLastCanStartAtMs = g_time or 0
            v.nfwDiagLastCanStartResult = result
            v.nfwDiagCanStartCallCount = Utils.getNoNil(v.nfwDiagCanStartCallCount, 0) + 1
            if result ~= true then
                v.nfwDiagCanStartFalseCount = Utils.getNoNil(v.nfwDiagCanStartFalseCount, 0) + 1
            end
            return result
        end
    end

    if vehicle.getCanAIFieldWorkerContinueWork ~= nil then
        vehicle.nfwOriginalGetCanAIFieldWorkerContinueWork = vehicle.getCanAIFieldWorkerContinueWork
        vehicle.getCanAIFieldWorkerContinueWork = function(v, isTurning, ...)
            local canContinue, stopAI, stopReason = v.nfwOriginalGetCanAIFieldWorkerContinueWork(v, isTurning, ...)
            v.nfwDiagLastContinueAtMs = g_time or 0
            v.nfwDiagLastContinueTurning = isTurning
            v.nfwDiagLastContinueResult = canContinue
            v.nfwDiagLastContinueStopAI = stopAI
            v.nfwDiagLastContinueStopReason = stopReason
            v.nfwDiagContinueCallCount = Utils.getNoNil(v.nfwDiagContinueCallCount, 0) + 1
            if canContinue ~= true then
                v.nfwDiagContinueFalseCount = Utils.getNoNil(v.nfwDiagContinueFalseCount, 0) + 1
            end
            return canContinue, stopAI, stopReason
        end
    end

    vehicle.nfwHarvestDiagHooksInstalled = true
end

function NeighborFieldWorkers:restoreNoTrailerHarvestVehicleOverrides(mission)
    if mission == nil or mission.vehicles == nil then
        return
    end

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            if vehicle.nfwVoidCapacityOverrideInstalled == true and vehicle.nfwOriginalGetFillUnitCapacity ~= nil then
                vehicle.getFillUnitCapacity = vehicle.nfwOriginalGetFillUnitCapacity
            end
            if vehicle.nfwVoidFillLevelOverrideInstalled == true and vehicle.nfwOriginalGetFillUnitFillLevel ~= nil then
                vehicle.getFillUnitFillLevel = vehicle.nfwOriginalGetFillUnitFillLevel
            end
            if vehicle.nfwHarvestDiagHooksInstalled == true then
                if vehicle.nfwOriginalGetCanStartFieldWork ~= nil then
                    vehicle.getCanStartFieldWork = vehicle.nfwOriginalGetCanStartFieldWork
                end
                if vehicle.nfwOriginalGetCanAIFieldWorkerContinueWork ~= nil then
                    vehicle.getCanAIFieldWorkerContinueWork = vehicle.nfwOriginalGetCanAIFieldWorkerContinueWork
                end
            end
            vehicle.nfwVoidCapacityOverrideInstalled = nil
            vehicle.nfwVoidFillLevelOverrideInstalled = nil
            vehicle.nfwOriginalGetFillUnitCapacity = nil
            vehicle.nfwOriginalGetFillUnitFillLevel = nil
            vehicle.nfwHarvestDiagHooksInstalled = nil
            vehicle.nfwOriginalGetCanStartFieldWork = nil
            vehicle.nfwOriginalGetCanAIFieldWorkerContinueWork = nil
            vehicle.nfwDiagLastCanStartAtMs = nil
            vehicle.nfwDiagLastCanStartResult = nil
            vehicle.nfwDiagCanStartCallCount = nil
            vehicle.nfwDiagCanStartFalseCount = nil
            vehicle.nfwDiagLastContinueAtMs = nil
            vehicle.nfwDiagLastContinueTurning = nil
            vehicle.nfwDiagLastContinueResult = nil
            vehicle.nfwDiagLastContinueStopAI = nil
            vehicle.nfwDiagLastContinueStopReason = nil
            vehicle.nfwDiagContinueCallCount = nil
            vehicle.nfwDiagContinueFalseCount = nil
            vehicle.nfwVoidCapacityOverrideIndices = nil
            vehicle.nfwVoidDischargeFillUnitIndex = nil
            vehicle.nfwVoidModeLogged = nil
        end
    end
end

function NeighborFieldWorkers:applyHarvestNoTrailerWorkaround(assignment)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or not self:isHarvestMission(mission) then
        return
    end

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.spec_combine ~= nil
            and vehicle.spec_pipe ~= nil
            and vehicle.getFillUnitCapacity ~= nil then
            self:installHarvestVehicleDiagnosticHooks(vehicle)
            local dischargeNode = vehicle.getCurrentDischargeNode ~= nil and vehicle:getCurrentDischargeNode() or nil
            local fillUnitIndex = dischargeNode ~= nil and dischargeNode.fillUnitIndex or nil
            if fillUnitIndex == nil then
                local spec = vehicle.spec_combine
                fillUnitIndex = spec ~= nil and (spec.bufferFillUnitIndex or spec.fillUnitIndex) or nil
            end

            if fillUnitIndex ~= nil then
                local getCapacityFn = vehicle.nfwOriginalGetFillUnitCapacity or vehicle.getFillUnitCapacity
                local capacity = getCapacityFn(vehicle, fillUnitIndex)
                if capacity == math.huge then
                    if vehicle.nfwVoidCapacityOverrideInstalled ~= true then
                        vehicle.nfwOriginalGetFillUnitCapacity = vehicle.getFillUnitCapacity
                        vehicle.getFillUnitCapacity = function(v, idx, ...)
                            local original = v.nfwOriginalGetFillUnitCapacity
                            local cap = original ~= nil and original(v, idx, ...) or 0
                            if idx == v.nfwVoidDischargeFillUnitIndex and cap == math.huge then
                                return 1000000
                            end
                            return cap
                        end
                        vehicle.nfwVoidCapacityOverrideInstalled = true
                    end
                    vehicle.nfwVoidDischargeFillUnitIndex = fillUnitIndex

                    if vehicle.spec_pipe.turnOnAllowedStates ~= nil then
                        vehicle.spec_pipe.turnOnAllowedStates = {}
                    end
                    if vehicle.spec_combine ~= nil then
                        vehicle.spec_combine.turnOffWhenFull = false
                    end

                    if vehicle.nfwVoidModeLogged ~= true then
                        vehicle.nfwVoidModeLogged = true
                        local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                        nfwLogInfo(
                            "[%s] Ernte-Workaround aktiv: mission=%s vehicle=%s fillUnit=%s mode=NO_TRAILER_REQUIRED",
                            self.MOD_NAME,
                            tostring(assignment.key),
                            tostring(vehicleName),
                            tostring(fillUnitIndex)
                        )
                    end
                end
            end
        end
    end
end

function NeighborFieldWorkers:forceHarvestVehicleContinueWork(assignment, triggerReason)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or not self:isHarvestMission(mission) then
        return false
    end

    local changed = false
    local drainedLiters = 0
    local touchedVehicles = 0
    local vehicleDetails = {}

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_combine ~= nil then
            touchedVehicles = touchedVehicles + 1
            local spec = vehicle.spec_combine
            local beforeRuntime = self:getHarvestVehicleRuntimeDebug(vehicle)

            local _, totalVoidIndices = self:ensureFiniteHarvestVoidCapacity(vehicle)
            local hasVoidHarvestFlow = totalVoidIndices > 0
            if totalVoidIndices > 0 then
                changed = true
            end

            if spec.turnOffWhenFull ~= false then
                spec.turnOffWhenFull = false
                changed = true
            end

            if vehicle.spec_pipe ~= nil and vehicle.spec_pipe.turnOnAllowedStates ~= nil then
                if next(vehicle.spec_pipe.turnOnAllowedStates) ~= nil then
                    vehicle.spec_pipe.turnOnAllowedStates = {}
                    changed = true
                end
            end

            if vehicle.getFillUnitFillLevel ~= nil
                and vehicle.getFillUnitCapacity ~= nil
                and vehicle.addFillUnitFillLevel ~= nil then
                local fillUnitsToCheck = {}
                if spec.fillUnitIndex ~= nil then
                    table.insert(fillUnitsToCheck, spec.fillUnitIndex)
                end
                if spec.bufferFillUnitIndex ~= nil and spec.bufferFillUnitIndex ~= spec.fillUnitIndex then
                    table.insert(fillUnitsToCheck, spec.bufferFillUnitIndex)
                end

                local dischargeNode = vehicle.getCurrentDischargeNode ~= nil and vehicle:getCurrentDischargeNode() or nil
                if dischargeNode ~= nil and dischargeNode.fillUnitIndex ~= nil then
                    local exists = false
                    for _, idx in ipairs(fillUnitsToCheck) do
                        if idx == dischargeNode.fillUnitIndex then
                            exists = true
                            break
                        end
                    end
                    if not exists then
                        table.insert(fillUnitsToCheck, dischargeNode.fillUnitIndex)
                    end
                end

                for _, fillUnitIndex in ipairs(fillUnitsToCheck) do
                    local level = vehicle:getFillUnitFillLevel(fillUnitIndex)
                    local capacity = vehicle:getFillUnitCapacity(fillUnitIndex)
                    local isVoidOverrideIndex = vehicle.nfwVoidCapacityOverrideIndices ~= nil
                        and vehicle.nfwVoidCapacityOverrideIndices[fillUnitIndex] == true
                    if type(level) == "number" and level > 0.01 then
                        local shouldDrain = false
                        if isVoidOverrideIndex then
                            -- No-trailer harvesters still need periodic drain, otherwise canStartFieldWork can remain false at 100%.
                            if type(capacity) == "number" and capacity > 0 then
                                local threshold = capacity * self.harvestTankResetThresholdPct
                                shouldDrain = level >= threshold
                            else
                                shouldDrain = true
                            end
                        elseif not (type(capacity) == "number" and capacity == math.huge) then
                            shouldDrain = true
                        end

                        if shouldDrain then
                            local fillType = vehicle.getFillUnitFillType ~= nil and
                                vehicle:getFillUnitFillType(fillUnitIndex) or FillType.UNKNOWN
                            local delta = -level
                            pcall(
                                vehicle.addFillUnitFillLevel,
                                vehicle,
                                self.neighborFarmId or 0,
                                fillUnitIndex,
                                delta,
                                fillType,
                                ToolType.UNDEFINED,
                                nil
                            )
                            drainedLiters = drainedLiters + math.max(level, 0)
                            changed = true
                        end
                    end
                end
            end

            if vehicle.getCanBeTurnedOn ~= nil and vehicle:getCanBeTurnedOn() and vehicle.getIsTurnedOn ~= nil and not vehicle:getIsTurnedOn() then
                if vehicle.setIsTurnedOn ~= nil then
                    pcall(vehicle.setIsTurnedOn, vehicle, true)
                    changed = true
                end
            end

            if hasVoidHarvestFlow and vehicle.spec_pipe ~= nil and vehicle.setPipeState ~= nil then
                local pipeSpec = vehicle.spec_pipe
                local trailer = nil
                if pipeSpec.nearestObjectInTriggers ~= nil and NetworkUtil ~= nil and NetworkUtil.getObject ~= nil then
                    trailer = NetworkUtil.getObject(pipeSpec.nearestObjectInTriggers.objectId)
                end
                local targetPipeState = pipeSpec.targetState
                local currentPipeState = pipeSpec.currentState
                if trailer == nil and (targetPipeState ~= 1 or currentPipeState ~= 1) then
                    pcall(vehicle.setPipeState, vehicle, 1)
                    changed = true
                end
            end

            if vehicle.aiImplementStartLine ~= nil then
                pcall(vehicle.aiImplementStartLine, vehicle)
            end

            if vehicle.getAttachedAIImplements ~= nil then
                local okImpl, aiImplements = pcall(vehicle.getAttachedAIImplements, vehicle)
                if okImpl and type(aiImplements) == "table" then
                    for _, aiImpl in ipairs(aiImplements) do
                        local implObj = aiImpl ~= nil and aiImpl.object or nil
                        if implObj ~= nil and implObj.aiImplementStartLine ~= nil then
                            pcall(implObj.aiImplementStartLine, implObj)
                        end
                    end
                end
            end

            local afterRuntime = self:getHarvestVehicleRuntimeDebug(vehicle)
            local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
            table.insert(
                vehicleDetails,
                string.format(
                    "%s{before=%s after=%s}",
                    tostring(vehicleName),
                    nfwToSingleLineText(beforeRuntime, 260),
                    nfwToSingleLineText(afterRuntime, 260)
                )
            )
        end
    end

    if changed and assignment ~= nil then
        local now = g_time or 0
        if now >= Utils.getNoNil(assignment.nextHarvestUnblockLogAtMs, 0) then
            assignment.nextHarvestUnblockLogAtMs = now + 3000
            nfwLogHelperDiag(
                "[%s] HelperDiag HARVEST_UNBLOCK_APPLIED: mission=%s reason=%s touched=%d drained=%.1f details=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(triggerReason or "UNKNOWN"),
                touchedVehicles,
                drainedLiters,
                nfwToSingleLineText(table.concat(vehicleDetails, " || "), 1400)
            )
        end
    end

    return changed
end

function NeighborFieldWorkers:prepareMissionVehicleConsumables(assignment)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or self.neighborFarmId == nil then
        return
    end

    local changedEntries = {}
    local farmId = self.neighborFarmId
    local missionSowFruitType = self:getMissionSowFruitType(mission)
    local missionSowFillType = self:getMissionSowFillType(mission, missionSowFruitType)

    self:prepareMissionSowSeedSelection(assignment, missionSowFruitType)

    if missionSowFruitType ~= nil and assignment ~= nil then
        local key = tostring(missionSowFruitType) .. ":" .. tostring(missionSowFillType)
        if assignment.lastSowMissionLogKey ~= key then
            assignment.lastSowMissionLogKey = key
            nfwLogInfo(
                "[%s] Saat-Missionsziel erkannt: mission=%s fruitType=%s fillType=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                self:getDebugFruitTypeName(missionSowFruitType),
                self:getDebugFillTypeName(missionSowFillType)
            )
        end
    end

    for _, vehicle in ipairs(mission.vehicles) do
        if self:isHarvestMission(mission)
            and vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.spec_combine ~= nil
            and vehicle.getFillUnitFillLevel ~= nil
            and vehicle.getFillUnitCapacity ~= nil
            and vehicle.addFillUnitFillLevel ~= nil then
            local spec = vehicle.spec_combine
            local checkFillUnits = {}
            if spec.fillUnitIndex ~= nil then
                table.insert(checkFillUnits, spec.fillUnitIndex)
            end
            if spec.bufferFillUnitIndex ~= nil and spec.bufferFillUnitIndex ~= spec.fillUnitIndex then
                table.insert(checkFillUnits, spec.bufferFillUnitIndex)
            end

            for _, fillUnitIndex in ipairs(checkFillUnits) do
                local capacity = vehicle:getFillUnitCapacity(fillUnitIndex)
                local level = vehicle:getFillUnitFillLevel(fillUnitIndex)
                local isVoidOverrideIndex = vehicle.nfwVoidCapacityOverrideIndices ~= nil
                    and vehicle.nfwVoidCapacityOverrideIndices[fillUnitIndex] == true
                if type(capacity) == "number"
                    and type(level) == "number"
                    and capacity > 0
                    and level > 0.01 then
                    local isInfiniteCapacity = capacity == math.huge
                    local isBufferCombine = spec.isBufferCombine == true
                    local pct = isInfiniteCapacity and 1 or (level / capacity)
                    local shouldReset = false
                    local resetTag = "HARVEST_RESET"

                    if isVoidOverrideIndex then
                        -- No-trailer harvesters use a virtual finite capacity mapping.
                        -- Reset at threshold so the helper never blocks on a full virtual tank.
                        shouldReset = pct >= self.harvestTankResetThresholdPct
                        resetTag = "HARVEST_VOID_RESET"
                    elseif isInfiniteCapacity then
                        shouldReset = true
                        resetTag = "HARVEST_VOID_INF"
                    elseif isBufferCombine then
                        -- Direct-discharge combines should not accumulate buffer fill.
                        shouldReset = true
                        resetTag = "HARVEST_VOID_BUF"
                    elseif pct >= self.harvestTankResetThresholdPct then
                        shouldReset = true
                        resetTag = "HARVEST_RESET"
                    end

                    if shouldReset then
                        local fillType = vehicle.getFillUnitFillType ~= nil and
                            vehicle:getFillUnitFillType(fillUnitIndex) or FillType.UNKNOWN
                        local delta = isInfiniteCapacity and -math.huge or -level
                        pcall(
                            vehicle.addFillUnitFillLevel,
                            vehicle,
                            farmId,
                            fillUnitIndex,
                            delta,
                            fillType,
                            ToolType.UNDEFINED,
                            nil
                        )
                        local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                        table.insert(
                            changedEntries,
                            string.format(
                                "%s[%d]=%s@%d%%",
                                tostring(vehicleName),
                                fillUnitIndex,
                                resetTag,
                                math.floor(pct * 100 + 0.5)
                            )
                        )
                    end
                end
            end
        end

        if self:isStoneMission(mission)
            and vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.getFillUnits ~= nil
            and vehicle.getFillUnitFillLevel ~= nil
            and vehicle.getFillUnitCapacity ~= nil
            and vehicle.addFillUnitFillLevel ~= nil then
            local fillUnits = vehicle:getFillUnits()
            if fillUnits ~= nil then
                for fillUnitIndex, _ in ipairs(fillUnits) do
                    local supported = vehicle.getFillUnitSupportedFillTypes ~= nil
                        and vehicle:getFillUnitSupportedFillTypes(fillUnitIndex)
                        or nil
                    local currentFillType = vehicle.getFillUnitFillType ~= nil
                        and vehicle:getFillUnitFillType(fillUnitIndex)
                        or FillType.UNKNOWN
                    local isStoneFillUnit = false
                    if FillType ~= nil and FillType.STONE ~= nil then
                        isStoneFillUnit = (supported ~= nil and supported[FillType.STONE] == true)
                            or currentFillType == FillType.STONE
                    end

                    if isStoneFillUnit then
                        local capacity = vehicle:getFillUnitCapacity(fillUnitIndex)
                        local level = vehicle:getFillUnitFillLevel(fillUnitIndex)
                        if type(capacity) == "number"
                            and type(level) == "number"
                            and capacity > 0
                            and capacity ~= math.huge
                            and level > 0.01 then
                            local pct = level / capacity
                            if pct >= self.stoneTankResetThresholdPct then
                                pcall(
                                    vehicle.addFillUnitFillLevel,
                                    vehicle,
                                    farmId,
                                    fillUnitIndex,
                                    -level,
                                    currentFillType,
                                    ToolType.UNDEFINED,
                                    nil
                                )
                                local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                                table.insert(
                                    changedEntries,
                                    string.format(
                                        "%s[%d]=STONE_RESET@%d%%",
                                        tostring(vehicleName),
                                        fillUnitIndex,
                                        math.floor(pct * 100 + 0.5)
                                    )
                                )
                            end
                        end
                    end
                end
            end
        end

        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.getFillUnits ~= nil
            and vehicle.getFillUnitSupportedFillTypes ~= nil then
            local fillUnits = vehicle:getFillUnits()
            if fillUnits ~= nil then
                for fillUnitIndex, _ in ipairs(fillUnits) do
                    local supported = vehicle:getFillUnitSupportedFillTypes(fillUnitIndex)
                    if supported ~= nil then
                        local preferred = self:getMissionPreferredConsumableFillType(mission, supported)
                        if self:isSowMission(mission) then
                            local sowPreferred = self:getSowingVehiclePreferredFillType(vehicle, supported,
                                missionSowFillType)
                            if sowPreferred ~= nil then
                                preferred = sowPreferred
                            end
                        end
                        local isHarvestOutputUnit = self:isHarvestMission(mission) and
                            self:isHarvestOutputFillUnit(vehicle, fillUnitIndex)
                        if preferred ~= nil and not isHarvestOutputUnit then
                            local currentFillType = vehicle.getFillUnitFillType ~= nil and
                                vehicle:getFillUnitFillType(fillUnitIndex) or FillType.UNKNOWN
                            local currentLevel = vehicle.getFillUnitFillLevel ~= nil and
                                vehicle:getFillUnitFillLevel(fillUnitIndex) or 0
                            if currentFillType ~= preferred and vehicle.setFillUnitFillType ~= nil then
                                if currentLevel > 0 and currentFillType ~= nil and currentFillType ~= FillType.UNKNOWN then
                                    pcall(vehicle.addFillUnitFillLevel, vehicle, farmId, fillUnitIndex, -math.huge,
                                        currentFillType, ToolType.UNDEFINED, nil)
                                end
                                pcall(vehicle.setFillUnitFillType, vehicle, fillUnitIndex, preferred)
                            end

                            if self:fillVehicleUnitFree(vehicle, fillUnitIndex, preferred, farmId) then
                                local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                                table.insert(changedEntries,
                                    string.format("%s[%d]=%s", tostring(vehicleName), fillUnitIndex, tostring(preferred)))
                            end
                        end

                        local fuelTypes = {}
                        if FillType.DIESEL ~= nil then table.insert(fuelTypes, FillType.DIESEL) end
                        if FillType.DEF ~= nil then table.insert(fuelTypes, FillType.DEF) end
                        if FillType.ELECTRICCHARGE ~= nil then table.insert(fuelTypes, FillType.ELECTRICCHARGE) end
                        if FillType.METHANE ~= nil then table.insert(fuelTypes, FillType.METHANE) end
                        for _, fuelType in ipairs(fuelTypes) do
                            if supported[fuelType] then
                                local currentFillType = vehicle.getFillUnitFillType ~= nil and
                                    vehicle:getFillUnitFillType(fillUnitIndex) or FillType.UNKNOWN
                                if currentFillType ~= fuelType and vehicle.setFillUnitFillType ~= nil and vehicle.getFillUnitFillLevel ~= nil then
                                    local level = vehicle:getFillUnitFillLevel(fillUnitIndex)
                                    if level <= 0.01 then
                                        pcall(vehicle.setFillUnitFillType, vehicle, fillUnitIndex, fuelType)
                                    end
                                end

                                if self:fillVehicleUnitFree(vehicle, fillUnitIndex, fuelType, farmId) then
                                    local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                                    table.insert(changedEntries,
                                        string.format("%s[%d]=%s", tostring(vehicleName), fillUnitIndex,
                                            tostring(fuelType)))
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if #changedEntries > 0 then
        nfwLogInfo(
            "[%s] Verbrauchsmittel/Fuel aufgefuellt: mission=%s entries=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            table.concat(changedEntries, ", ")
        )
    end
end

function NeighborFieldWorkers:getMissionDisplayType(mission)
    local typeName = self:getMissionTypeNameLower(mission)

    local function missionTypeText(key, fallbackEn)
        local text = self:getText(key)
        if text == nil or text == key or text == "" then
            return fallbackEn
        end
        return text
    end

    if string.find(typeName, "plow", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_plow", "Plowing")
    end
    if string.find(typeName, "cultivat", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_cultivate", "Cultivating")
    end
    if string.find(typeName, "mow", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_mow", "Mowing")
    end
    if string.find(typeName, "hoe", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_hoe", "Hoeing")
    end
    if string.find(typeName, "weed", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_weed", "Weeding")
    end
    if string.find(typeName, "fertiliz", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_fertilize", "Fertilizing")
    end
    if string.find(typeName, "herbicid", 1, true) ~= nil or string.find(typeName, "spray", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_spray", "Spraying")
    end
    if string.find(typeName, "sow", 1, true) ~= nil or string.find(typeName, "seed", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_sow", "Sowing")
    end
    if string.find(typeName, "harvest", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_harvest", "Harvesting")
    end
    if string.find(typeName, "stonepick", 1, true) ~= nil or string.find(typeName, "stone", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_stone", "Stone Picking")
    end
    if string.find(typeName, "ted", 1, true) ~= nil
        or string.find(typeName, "windrow", 1, true) ~= nil
        or string.find(typeName, "turn", 1, true) ~= nil
        or string.find(typeName, "wend", 1, true) ~= nil then
        return missionTypeText("nfw_missionType_turn", "Turning")
    end

    return self:getMissionTypeName(mission)
end

function NeighborFieldWorkers:getMissionCompletionPercent(mission)
    if mission ~= nil and mission.getCompletion ~= nil then
        local ok, completion = pcall(mission.getCompletion, mission)
        if ok and type(completion) == "number" then
            completion = nfwClamp(completion, 0, 1)
            return math.floor(completion * 100 + 0.5)
        end
    end

    return 0
end

function NeighborFieldWorkers:refreshCompletionStallTracking(assignment, completionPercent, now)
    if assignment == nil then
        return false
    end

    local effectiveNow = now or (g_time or 0)
    local percent = completionPercent
    if type(percent) ~= "number" then
        percent = self:getMissionCompletionPercent(assignment.mission)
    end

    local hasChanged = assignment.lastCompletionPercent == nil or percent ~= assignment.lastCompletionPercent
    if hasChanged then
        assignment.lastCompletionPercent = percent
        assignment.completionUnchangedSinceMs = effectiveNow
        assignment.nextCompletionStallLogAtMs = effectiveNow + 30000
    else
        if Utils.getNoNil(assignment.completionUnchangedSinceMs, 0) <= 0 then
            assignment.completionUnchangedSinceMs = effectiveNow
        end
        if Utils.getNoNil(assignment.nextCompletionStallLogAtMs, 0) <= 0 then
            assignment.nextCompletionStallLogAtMs = effectiveNow + 30000
        end
    end

    return hasChanged
end

function NeighborFieldWorkers:applyNeighborMissionEconomyRules(mission)
    if mission == nil then
        return
    end

    if mission.reward ~= nil then
        mission.reward = 0
    end
    if mission.reimbursement ~= nil then
        mission.reimbursement = 0
    end
end

function NeighborFieldWorkers:getMenuRows()
    local rows = {}
    local assignments = {}
    local function menuText(key, fallback)
        local text = self:getText(key)
        if text == nil or text == key or text == "" then
            return fallback
        end
        return text
    end

    self:reconcileExistingNeighborMissions()

    for _, assignment in pairs(self.activeAssignments) do
        if assignment ~= nil and assignment.mission ~= nil then
            local status = assignment.mission.status
            local includeInMenu = status == MissionStatus.PREPARING
                or status == MissionStatus.RUNNING
                or assignment.recoveredFromSave == true
            if includeInMenu then
                table.insert(assignments, assignment)
            end
        end
    end

    table.sort(assignments, function(a, b)
        local aField = self:getMissionFieldId(a.mission) or 999999
        local bField = self:getMissionFieldId(b.mission) or 999999
        if aField == bField then
            return tostring(a.key) < tostring(b.key)
        end
        return aField < bField
    end)

    for _, assignment in ipairs(assignments) do
        local mission = assignment.mission
        local missionType = self:getMissionDisplayType(mission)
        local fieldId = self:getMissionFieldId(mission)
        local fieldWorldX, fieldWorldZ = self:getMissionFieldPosition(mission)
        local completion = self:getMissionCompletionPercent(mission)
        local statusText = menuText("nfw_menu_status_running", "Running")
        if mission.status == MissionStatus.PREPARING then
            statusText = menuText("nfw_menu_status_preparing", "Preparing")
        elseif mission.status == MissionStatus.CREATED and assignment.recoveredFromSave then
            statusText = menuText("nfw_menu_status_restored", "Restored")
        end

        if mission.status == MissionStatus.RUNNING then
            self:assignLocalizedHelperNameToAssignment(assignment, assignment.vehicle)
        end
        local helperName = self:getAssignmentHelperDisplayName(assignment)
        local statusLabel = menuText("nfw_menu_status_label", "Status")
        local detailText = string.format("%s: %s", statusLabel, statusText)
        local helperText = ""
        if helperName ~= nil and helperName ~= "" then
            helperText = tostring(helperName)
        end

        table.insert(rows, {
            isHeader = true,
            rowType = "assignment",
            assignmentKey = assignment.key,
            title = string.format(
                "%s %s %s",
                missionType,
                menuText("nfw_menu_onField", "on field"),
                tostring(fieldId or "?")
            ),
            detail = detailText,
            progress = string.format("%d%%", completion),
            missionType = missionType,
            fieldId = fieldId,
            fieldWorldX = fieldWorldX,
            fieldWorldZ = fieldWorldZ,
            status = statusText,
            helperName = helperName,
            helperText = helperText
        })

        if mission.vehicles ~= nil then
            for _, vehicle in ipairs(mission.vehicles) do
                if vehicle ~= nil and not vehicle.isDeleted then
                    local includeVehicleRow = true
                    if vehicle.spec_motorized == nil
                        and vehicle.getAttacherVehicle ~= nil
                        and vehicle.rootNode ~= nil
                        and fieldWorldX ~= nil
                        and fieldWorldZ ~= nil then
                        local attacherVehicle = vehicle:getAttacherVehicle()
                        if attacherVehicle == nil then
                            local vx, _, vz = getWorldTranslation(vehicle.rootNode)
                            local distSq = MathUtil.vector2LengthSq(vx - fieldWorldX, vz - fieldWorldZ)
                            -- Hide remote detached support tools that are still parked at the shop.
                            if distSq > (60 * 60) then
                                includeVehicleRow = false
                            end
                        end
                    end

                    if includeVehicleRow then
                        local vehicleName = vehicle.getName ~= nil and vehicle:getName() or
                            menuText("nfw_menu_unknownEquipment", "Unknown equipment")
                        local vehicleType = vehicle.spec_motorized ~= nil and
                            menuText("nfw_menu_vehicleType_vehicle", "Vehicle") or
                            menuText("nfw_menu_vehicleType_implement", "Implement")
                        local vehicleDetail = ""
                        local vehicleImageFilename = nil
                        if vehicle.getImageFilename ~= nil then
                            local okImage, imageFilename = pcall(vehicle.getImageFilename, vehicle)
                            if okImage and imageFilename ~= nil and imageFilename ~= "" then
                                vehicleImageFilename = imageFilename
                            end
                        end
                        if vehicle.spec_combine ~= nil then
                            local fillPct, fillLevel, fillCapacity = self:getCombineFillStatus(vehicle)
                            if fillPct ~= nil then
                                vehicleDetail = string.format(
                                    "%s: %d%% (%d/%d l)",
                                    menuText("nfw_menu_tank", "Tank"),
                                    fillPct,
                                    math.floor(fillLevel + 0.5),
                                    math.floor(fillCapacity + 0.5)
                                )
                            end
                        end
                        table.insert(rows, {
                            isHeader = false,
                            rowType = "vehicle",
                            assignmentKey = assignment.key,
                            title = string.format("   %s: %s", vehicleType, tostring(vehicleName)),
                            detail = vehicleDetail,
                            progress = "",
                            missionType = missionType,
                            fieldId = fieldId,
                            fieldWorldX = fieldWorldX,
                            fieldWorldZ = fieldWorldZ,
                            status = statusText,
                            helperName = helperName,
                            helperText = "",
                            vehicleType = vehicleType,
                            vehicleName = vehicleName,
                            vehicleImageFilename = vehicleImageFilename
                        })
                    end
                end
            end
        end
    end

    return rows
end

function NeighborFieldWorkers:completeAssignmentFromMenu(assignmentKey)
    if assignmentKey == nil then
        return false, "ASSIGNMENT_KEY_NIL"
    end

    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return false, "NOT_SERVER"
    end

    local assignment = self.activeAssignments[assignmentKey]
    if assignment == nil or assignment.mission == nil then
        return false, "ASSIGNMENT_NOT_FOUND"
    end

    local mission = assignment.mission
    local fieldId = self:getMissionFieldId(mission)

    local vehicle = assignment.vehicle
    if vehicle ~= nil and vehicle.stopCurrentAIJob ~= nil and vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() then
        local stopMessage = nil
        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
            stopMessage = AIMessageSuccessStoppedByUser.new()
        end
        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
    end

    if mission.status ~= MissionStatus.FINISHED and mission.status ~= MissionStatus.DISMISSED and mission.finish ~= nil then
        pcall(mission.finish, mission, MissionFinishState.SUCCESS)
    end

    if mission.status == MissionStatus.FINISHED then
        self:finalizeAssignment(assignment)
    elseif mission.status ~= MissionStatus.DISMISSED then
        pcall(g_missionManager.cancelMission, g_missionManager, mission)
        pcall(g_missionManager.dismissMission, g_missionManager, mission)
        self:removeAssignment(assignment)
    else
        self:removeAssignment(assignment)
    end

    self.scanTimerMs = 0
    nfwLogInfo(
        "[%s] Auftrag aus Menue beendet: mission=%s type=%s field=%s",
        self.MOD_NAME,
        tostring(assignmentKey),
        self:getMissionTypeName(mission),
        tostring(fieldId)
    )
    self:setNeighborFarmBalance(1, "MENU_COMPLETE")

    return true, nil
end

function NeighborFieldWorkers:forceStartNeighborMissionFromMenu()
    if g_currentMission == nil or not g_currentMission:getIsServer() then
        nfwLogInfo("[%s] Menue Aktion abgebrochen: neuer Auftrag nur auf Server moeglich", self.MOD_NAME)
        return false, "NOT_SERVER"
    end

    if not self:ensureNeighborFarm() then
        return false, "NO_NEIGHBOR_FARM"
    end

    local mission, missionSource = self:selectMissionForNeighborStart("MENU")
    if mission == nil then
        nfwLogInfo(
            "[%s] Menue Aktion: Kein passender Auftrag verfuegbar (mode=%s)",
            self.MOD_NAME,
            tostring(self.allowExistingContractCompetition == true and "EXISTING_COMPETITION" or "GENERATE_NEW")
        )
        return false, "NO_MISSION"
    end

    local fieldInUse, fieldId, inUseReason = self:isMissionFieldInUseByNeighbor(mission, self:getMissionKey(mission))
    if fieldInUse then
        nfwLogInfo(
            "[%s] Menue Aktion abgebrochen (Feld bereits belegt): mission=%s field=%s source=%s reason=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            tostring(fieldId),
            tostring(missionSource),
            tostring(inUseReason)
        )
        return false, "FIELD_ALREADY_IN_USE"
    end

    self:forcePrepareSowMissionFieldIfNeeded(mission, missionSource, "MENU_START", false)

    self:configureMissionFieldSpawnState(mission)
    self:applyNeighborMissionEconomyRules(mission)

    nfwLogMissionDebug(
        "[%s] MissionStart[MENU][REQUEST]: mission=%s type=%s field=%s source=%s %s",
        self.MOD_NAME,
        tostring(self:getMissionKey(mission)),
        tostring(self:getMissionTypeName(mission)),
        tostring(self:getMissionFieldId(mission)),
        tostring(missionSource),
        self:getMissionStartDebugStateText(mission)
    )

    local startState = g_missionManager:startMission(mission, self.neighborFarmId, true)
    nfwLogMissionDebug(
        "[%s] MissionStart[MENU][RESULT]: mission=%s startState=%s %s",
        self.MOD_NAME,
        tostring(self:getMissionKey(mission)),
        tostring(self:missionStartStateToText(startState)),
        self:getMissionStartDebugStateText(mission)
    )
    if startState ~= MissionStartState.OK then
        self:clearMissionFieldSpawnState(mission)
        nfwLogInfo(
            "[%s] Menue Aktion Start fehlgeschlagen: mission=%s reason=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            self:missionStartStateToText(startState)
        )
        return false, self:missionStartStateToText(startState)
    end

    local assignment = self:createAssignmentForMission(mission)
    if assignment ~= nil then
        nfwLogInfo(
            "[%s] Menue Aktion: Neuer Auftrag erzwungen gestartet: mission=%s type=%s field=%s source=%s maxNeighbors=%d",
            self.MOD_NAME,
            tostring(assignment.key),
            self:getMissionTypeName(mission),
            tostring(self:getMissionFieldId(mission)),
            tostring(missionSource),
            self.maxNeighbors
        )
    else
        nfwLogMissionDebug(
            "[%s] MissionStart[MENU][WARN]: startState=OK aber assignment=nil mission=%s %s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            self:getMissionStartDebugStateText(mission)
        )
    end

    self.scanTimerMs = 0
    return true, nil
end

function NeighborFieldWorkers:applyFieldStateForNeighborMission(field, state)
    if field == nil or state == nil or FieldUpdateTask == nil then
        return false
    end

    local task = FieldUpdateTask.new()
    if task == nil then
        return false
    end

    task:setField(field)
    if field.getDensityMapPolygon ~= nil then
        task:setArea(field:getDensityMapPolygon())
    end

    if state.fruitTypeIndex ~= nil then
        task:setFruit(state.fruitTypeIndex, state.growthState or 1)
    end

    if state.groundType ~= nil then
        task:setGroundType(state.groundType)
    end

    local currentFieldState = nil
    if field.getFieldState ~= nil then
        local okCurrent, readFieldState = pcall(field.getFieldState, field)
        if okCurrent and readFieldState ~= nil then
            currentFieldState = readFieldState
        end
    end

    local function resolveStateValue(stateKey, fallback)
        if state[stateKey] ~= nil then
            return state[stateKey]
        end
        if currentFieldState ~= nil and currentFieldState[stateKey] ~= nil then
            return currentFieldState[stateKey]
        end
        return fallback
    end

    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    local groundAngle = resolveStateValue("groundAngle", 0)
    task:setGroundAngle(-groundAngle)
    task:setWeedState((missionInfo ~= nil and missionInfo.weedsEnabled) and (resolveStateValue("weedState", 0) or 0) or 0)
    task:setStoneLevel((missionInfo ~= nil and missionInfo.stonesEnabled) and (resolveStateValue("stoneLevel", 0) or 0) or
        0)
    task:setSprayType(resolveStateValue("sprayType", (FieldSprayType ~= nil and FieldSprayType.NONE) or 0))
    task:setSprayLevel(resolveStateValue("sprayLevel", 0) or 0)
    task:setLimeLevel(resolveStateValue("limeLevel", 0) or 0)
    task:setPlowLevel(resolveStateValue("plowLevel", 0) or 0)
    task:setRollerLevel(resolveStateValue("rollerLevel", 0) or 0)
    task:setStubbleShredLevel(resolveStateValue("stubbleShredLevel", 0) or 0)

    if state.clearHeightTypes == true then
        task:clearHeight()
    end

    task:resetDisplacement()
    task:clearTireTracks()
    task:enqueue(true)

    -- Keep field cache in sync immediately for isAvailable/getCanStart checks.
    if field.getFieldState ~= nil then
        local fieldState = field:getFieldState()
        if fieldState ~= nil then
            fieldState.isValid = true
            if state.fruitTypeIndex ~= nil then fieldState.fruitTypeIndex = state.fruitTypeIndex end
            if state.growthState ~= nil then fieldState.growthState = state.growthState end
            if state.groundType ~= nil then fieldState.groundType = state.groundType end
            if state.weedState ~= nil then fieldState.weedState = state.weedState end
            if state.stoneLevel ~= nil then fieldState.stoneLevel = state.stoneLevel end
            if state.sprayType ~= nil then fieldState.sprayType = state.sprayType end
            if state.sprayLevel ~= nil then fieldState.sprayLevel = state.sprayLevel end
            if state.limeLevel ~= nil then fieldState.limeLevel = state.limeLevel end
            if state.plowLevel ~= nil then fieldState.plowLevel = state.plowLevel end
            if state.rollerLevel ~= nil then fieldState.rollerLevel = state.rollerLevel end
            if state.stubbleShredLevel ~= nil then fieldState.stubbleShredLevel = state.stubbleShredLevel end
        end
    end

    return true
end

function NeighborFieldWorkers:getFieldStateSafe(field)
    if field == nil or field.getFieldState == nil then
        return nil, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(field.getFieldState, field)
    if not okState or fieldState == nil then
        return nil, "FIELD_STATE_UNAVAILABLE"
    end

    return fieldState, "OK"
end

function NeighborFieldWorkers:getFieldStateFruitSignals(fieldState)
    local rawHasFruit = fieldState ~= nil and fieldState.hasFruit or nil
    local fruitTypeIndex = fieldState ~= nil and tonumber(fieldState.fruitTypeIndex) or nil
    local growthState = fieldState ~= nil and tonumber(fieldState.growthState) or 0

    local hasKnownFruitType = fruitTypeIndex ~= nil
    if hasKnownFruitType and FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN then
        hasKnownFruitType = false
    end

    local hasFruitByState = hasKnownFruitType and growthState > 0
    local hasEffectiveFruit = rawHasFruit == true or hasFruitByState

    return {
        rawHasFruit = rawHasFruit,
        fruitTypeIndex = fruitTypeIndex,
        growthState = growthState,
        hasKnownFruitType = hasKnownFruitType,
        hasFruitByState = hasFruitByState,
        hasEffectiveFruit = hasEffectiveFruit
    }
end

function NeighborFieldWorkers:describeFieldStateForMissionGen(fieldState)
    if fieldState == nil then
        return "state=nil"
    end

    local fruit = self:getFieldStateFruitSignals(fieldState)
    return string.format(
        "isValid=%s hasFruitRaw=%s hasFruitEffective=%s hasFruitByState=%s fruitType=%s growth=%s groundType=%s canBeWorked=%s canBeSown=%s canBeFertilized=%s weed=%s stone=%s sprayLevel=%s sprayType=%s plowLevel=%s roller=%s stubble=%s",
        tostring(fieldState.isValid),
        tostring(fruit.rawHasFruit),
        tostring(fruit.hasEffectiveFruit),
        tostring(fruit.hasFruitByState),
        tostring(fieldState.fruitTypeIndex),
        tostring(fieldState.growthState),
        tostring(fieldState.groundType),
        tostring(fieldState.canBeWorked),
        tostring(fieldState.canBeSown),
        tostring(fieldState.canBeFertilized),
        tostring(fieldState.weedState),
        tostring(fieldState.stoneLevel),
        tostring(fieldState.sprayLevel),
        tostring(fieldState.sprayType),
        tostring(fieldState.plowLevel),
        tostring(fieldState.rollerLevel),
        tostring(fieldState.stubbleShredLevel)
    )
end

function NeighborFieldWorkers:getFieldIdTextForMissionGen(field)
    if field == nil then
        return "n/a"
    end

    if field.getId ~= nil then
        local okId, fieldId = pcall(field.getId, field)
        if okId and fieldId ~= nil then
            return tostring(fieldId)
        end
    end

    if field.farmlandId ~= nil then
        return tostring(field.farmlandId)
    end

    return tostring(field)
end

function NeighborFieldWorkers:getFieldStateDiagTextForMissionGen(field)
    local fieldState, stateReason = self:getFieldStateSafe(field)
    if fieldState == nil then
        return string.format("state=%s", tostring(stateReason))
    end

    return self:describeFieldStateForMissionGen(fieldState)
end

function NeighborFieldWorkers:getMissionTypeExpectedStateHintForMissionGen(missionTypeName)
    local nameLower = string.lower(tostring(missionTypeName or ""))

    if string.find(nameLower, "sow", 1, true) ~= nil or string.find(nameLower, "seed", 1, true) ~= nil then
        return "Erwartet: Feld ohne aktive Frucht und saefaehig (canBeSown=true)."
    end

    if string.find(nameLower, "fertiliz", 1, true) ~= nil then
        return "Erwartet: wachsende/nicht tote/nicht erntereife Frucht, canBeFertilized=true und duengebar (sprayLevel < max)."
    end

    if string.find(nameLower, "herbicid", 1, true) ~= nil or string.find(nameLower, "spray", 1, true) ~= nil then
        return "Erwartet: lebende Frucht (nicht tot/erntereif) und vorhandenes Unkraut als Ziel."
    end

    if string.find(nameLower, "harvest", 1, true) ~= nil then
        return "Erwartet: nicht-grasartige Frucht, erntereif, nicht tot und in Saison."
    end

    if string.find(nameLower, "mow", 1, true) ~= nil then
        return "Erwartet: grasartige Frucht in maehbarer Wachstumsphase und in Saison."
    end

    if string.find(nameLower, "ted", 1, true) ~= nil
        or string.find(nameLower, "windrow", 1, true) ~= nil
        or string.find(nameLower, "turn", 1, true) ~= nil
        or string.find(nameLower, "wend", 1, true) ~= nil then
        return "Erwartet: grasartige Frucht im frisch gemaehten Zustand (Wenden/Schwaden moeglich)."
    end

    if string.find(nameLower, "stonepick", 1, true) ~= nil or string.find(nameLower, "stone", 1, true) ~= nil then
        return "Erwartet: keine aktive Frucht, Boden gepfluegt (PLOWED) und stoneLevel > 0."
    end

    if string.find(nameLower, "plow", 1, true) ~= nil or string.find(nameLower, "cultivat", 1, true) ~= nil then
        return "Erwartet: Feld leer/tot/frueh (growth<=1), nicht erntereif und nicht bereits final fuer Saat vorbereitet."
    end

    if string.find(nameLower, "hoe", 1, true) ~= nil then
        return "Erwartet: lebende/nicht erntereife Frucht und Unkraut in einer von der Hacke unterstuetzten Stufe."
    end

    if string.find(nameLower, "weed", 1, true) ~= nil then
        return "Erwartet: lebende/nicht erntereife Frucht und Unkraut in einer vom Striegel unterstuetzten Stufe."
    end

    return "Erwartet: Missionsspezifische GIANTS-Bedingungen fuer Feld und Missionstyp."
end

function NeighborFieldWorkers:getMissionFailureExpectationHintForMissionGen(failReason)
    local reasonText = string.upper(tostring(failReason or "UNKNOWN"))

    if string.find(reasonText, "NO_FRUIT", 1, true) ~= nil then
        return "Soll: aktive Frucht vorhanden (fruitType gueltig, growth > 0)."
    end
    if string.find(reasonText, "HAS_FRUIT", 1, true) ~= nil then
        return "Soll: keine aktive Frucht auf dem Feld."
    end
    if string.find(reasonText, "CANNOT_BE_SOWN", 1, true) ~= nil then
        return "Soll: canBeSown=true bzw. saefaehiger Boden."
    end
    if string.find(reasonText, "FULLY_FERTILIZED", 1, true) ~= nil then
        return "Soll: Duengestatus unter Maximum (sprayLevel < max)."
    end
    if string.find(reasonText, "CANNOT_BE_FERTILIZED", 1, true) ~= nil then
        return "Soll: canBeFertilized=true."
    end
    if string.find(reasonText, "CROP_NOT_VALID", 1, true) ~= nil then
        return "Soll: lebende, nicht tote, nicht erntereife Kultur."
    end
    if string.find(reasonText, "NO_WEEDS", 1, true) ~= nil
        or string.find(reasonText, "NO_WEED_TARGET", 1, true) ~= nil then
        return "Soll: Unkraut vorhanden (weedState > 0)."
    end
    if string.find(reasonText, "WEED_LEVEL_NOT_LOWEST", 1, true) ~= nil then
        return "Soll: Unkraut auf niedrigster Stufe (weedState == 1)."
    end
    if string.find(reasonText, "WEED_STATE_NOT_SUPPORTED_BY_WEEDER", 1, true) ~= nil then
        return "Soll: Unkraut muss in den vom Striegel bearbeitbaren Weed-States liegen."
    end
    if string.find(reasonText, "WEED_STATE_NOT_SUPPORTED_BY_HOE", 1, true) ~= nil then
        return "Soll: Unkraut muss in den von der Hacke bearbeitbaren Weed-States liegen."
    end
    if string.find(reasonText, "NOT_HARVEST_READY", 1, true) ~= nil then
        return "Soll: Wachstumsstufe im Erntefenster."
    end
    if string.find(reasonText, "NOT_MOW_READY", 1, true) ~= nil then
        return "Soll: Grasartige Frucht in maehbarer Stufe."
    end
    if string.find(reasonText, "NOT_FRESHLY_CUT", 1, true) ~= nil then
        return "Soll: frisch gemaehter Graszustand (Cut/GrassCut)."
    end
    if string.find(reasonText, "GROUND_NOT_PREPARED", 1, true) ~= nil then
        return "Soll: vorbereiteter Boden (plowed/cultivated/seedbed/rolled) oder canBeSown=true."
    end
    if string.find(reasonText, "NO_STONES", 1, true) ~= nil then
        return "Soll: stoneLevel > 0."
    end
    if string.find(reasonText, "HAS_ACTIVE_CROP", 1, true) ~= nil then
        return "Soll: keine aktive Kultur fuer diese Mission."
    end
    if string.find(reasonText, "UNKNOWN_FRUIT_TYPE", 1, true) ~= nil then
        return "Soll: gueltiger fruitType (nicht UNKNOWN)."
    end
    if string.find(reasonText, "WITHERED", 1, true) ~= nil then
        return "Soll: Frucht darf nicht tot/verwelkt sein."
    end
    if string.find(reasonText, "OUT_OF_SEASON", 1, true) ~= nil then
        return "Soll: Kultur muss in aktueller Periode fuer den Missionstyp zulaessig sein."
    end
    if string.find(reasonText, "NOT_AVAILABLE_FOR_FIELD", 1, true) ~= nil then
        return "Soll: isAvailableForField(...) muss true liefern."
    end
    if string.find(reasonText, "TRY_GENERATE_NIL", 1, true) ~= nil then
        return "Soll: GIANTS tryGenerateMission darf nicht nil liefern (interne Generatorpruefung fehlgeschlagen)."
    end
    if string.find(reasonText, "PREP_APPLY_FAILED", 1, true) ~= nil then
        return "Soll: Feldzustand muss erfolgreich geschrieben werden koennen."
    end
    if string.find(reasonText, "PREP_STATE_UNAVAILABLE", 1, true) ~= nil then
        return "Soll: es muss ein gueltiger PREP-Zielzustand fuer Feld/Missionstyp berechenbar sein."
    end

    return "Soll: Missions- und Feldbedingungen gemaess Missionstyp erfuellt."
end

function NeighborFieldWorkers:logMissionGenerationFieldFailure(phase, missionTypeName, field, failReason, beforeStateDiag,
                                                               afterStateDiag, extraDetail)
    if not NFW_MISSION_DEBUG_LOG_ENABLED then
        return
    end

    nfwLogMissionDebug(
        "[%s] MissionGen[MISSION_DEBUG][%s]: type=%s field=%s fail=%s stateBefore={%s} stateAfter={%s} expectedType={%s} expectedFail={%s} detail=%s",
        self.MOD_NAME,
        tostring(phase or "UNKNOWN"),
        tostring(missionTypeName),
        tostring(self:getFieldIdTextForMissionGen(field)),
        tostring(failReason),
        tostring(beforeStateDiag or "n/a"),
        tostring(afterStateDiag or "n/a"),
        tostring(self:getMissionTypeExpectedStateHintForMissionGen(missionTypeName)),
        tostring(self:getMissionFailureExpectationHintForMissionGen(failReason)),
        tostring(extraDetail or "n/a")
    )
end

function NeighborFieldWorkers:getMissionFieldMismatchHintForMissionGen(missionTypeName, field)
    local okReady, readyReason = self:isMissionTypeFieldReadyWithoutPreparation(missionTypeName, field)
    if okReady == true then
        return string.format("NFW_READY_MATCH(%s)", tostring(readyReason))
    end
    return string.format("NFW_READY_MISMATCH(%s)", tostring(readyReason))
end

function NeighborFieldWorkers:getMissionGlobalDiagTextForMissionGen()
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    local environment = g_currentMission ~= nil and g_currentMission.environment or nil

    if missionInfo == nil then
        return "missionInfo=nil"
    end

    return string.format(
        "missionInfo={plowRequired=%s,weeds=%s,stones=%s,lime=%s,growthMode=%s,period=%s}",
        tostring(missionInfo.plowingRequiredEnabled),
        tostring(missionInfo.weedsEnabled),
        tostring(missionInfo.stonesEnabled),
        tostring(missionInfo.limeRequired),
        tostring(missionInfo.growthMode),
        tostring(environment ~= nil and environment.currentPeriod or nil)
    )
end

function NeighborFieldWorkers:getMissionAvailabilityBlockersForMissionGen(missionTypeName, field)
    local blockers = {}
    local nameLower = string.lower(tostring(missionTypeName or ""))
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil

    local function addBlocker(text)
        if text ~= nil and text ~= "" then
            table.insert(blockers, tostring(text))
        end
    end

    local fieldState, stateReason = self:getFieldStateSafe(field)
    if fieldState == nil then
        addBlocker(string.format("FIELD_STATE_UNAVAILABLE(%s)", tostring(stateReason)))
        return table.concat(blockers, ";")
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    local sprayLevel = tonumber(fieldState.sprayLevel)
    local sprayMax = (g_fieldManager ~= nil and g_fieldManager.sprayLevelMaxValue) or nil
    local weedState = tonumber(fieldState.weedState) or 0

    if string.find(nameLower, "plow", 1, true) ~= nil then
        if missionInfo ~= nil and missionInfo.plowingRequiredEnabled ~= true then
            addBlocker("PLOW_SETTING_DISABLED(plowingRequiredEnabled=false)")
        end
        local okSoil, reasonSoil = self:isFieldStateDeadEmptyOrEarlyForSoilWork(fieldState)
        if not okSoil then
            addBlocker(string.format("SOIL_STATE_FAIL(%s)", tostring(reasonSoil)))
        end
    end

    if string.find(nameLower, "cultivat", 1, true) ~= nil then
        local okSoil, reasonSoil = self:isFieldStateDeadEmptyOrEarlyForSoilWork(fieldState)
        if not okSoil then
            addBlocker(string.format("SOIL_STATE_FAIL(%s)", tostring(reasonSoil)))
        end
    end

    if string.find(nameLower, "fertiliz", 1, true) ~= nil then
        if sprayLevel ~= nil and type(sprayMax) == "number" and sprayMax > 0 and sprayLevel >= sprayMax then
            addBlocker(string.format("FERTILIZE_FULL(sprayLevel=%s,max=%s)", tostring(sprayLevel), tostring(sprayMax)))
        end
        if type(fieldState.canBeFertilized) == "boolean" and fieldState.canBeFertilized == false then
            addBlocker("CAN_BE_FERTILIZED_FALSE")
        end
        local cropOk, cropReason = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)
        if not cropOk then
            addBlocker(string.format("CROP_INVALID(%s)", tostring(cropReason)))
        end
        if fruitSignals.rawHasFruit ~= true then
            addBlocker(string.format("HAS_FRUIT_RAW_NOT_TRUE(raw=%s)", tostring(fruitSignals.rawHasFruit)))
        end
    end

    if string.find(nameLower, "herbicid", 1, true) ~= nil or string.find(nameLower, "spray", 1, true) ~= nil then
        if missionInfo ~= nil and missionInfo.weedsEnabled == false then
            addBlocker("WEEDS_DISABLED_IN_SETTINGS")
        end
        local cropOk, cropReason = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)
        if not cropOk then
            addBlocker(string.format("CROP_INVALID(%s)", tostring(cropReason)))
        end
        if weedState <= 0 then
            addBlocker(string.format("NO_WEEDS(weedState=%s)", tostring(weedState)))
        end
        if fruitSignals.rawHasFruit ~= true then
            addBlocker(string.format("HAS_FRUIT_RAW_NOT_TRUE(raw=%s)", tostring(fruitSignals.rawHasFruit)))
        end
    end

    if string.find(nameLower, "hoe", 1, true) ~= nil then
        if missionInfo ~= nil and missionInfo.weedsEnabled == false then
            addBlocker("WEEDS_DISABLED_IN_SETTINGS")
        end
        local cropOk, cropReason = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)
        if not cropOk then
            addBlocker(string.format("CROP_INVALID(%s)", tostring(cropReason)))
        end
        if weedState <= 0 then
            addBlocker(string.format("NO_WEEDS_FOR_HOE(weedState=%s)", tostring(weedState)))
        else
            local supported, supportReason = self:isWeedStateSupportedByTool(weedState, true)
            if not supported then
                addBlocker(tostring(supportReason))
            end
        end
    end

    if string.find(nameLower, "weed", 1, true) ~= nil then
        if missionInfo ~= nil and missionInfo.weedsEnabled == false then
            addBlocker("WEEDS_DISABLED_IN_SETTINGS")
        end
        local cropOk, cropReason = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)
        if not cropOk then
            addBlocker(string.format("CROP_INVALID(%s)", tostring(cropReason)))
        end
        if weedState <= 0 then
            addBlocker(string.format("NO_WEEDS_FOR_WEED(weedState=%s)", tostring(weedState)))
        else
            local supported, supportReason = self:isWeedStateSupportedByTool(weedState, false)
            if not supported then
                addBlocker(tostring(supportReason))
            end
        end
    end

    if string.find(nameLower, "sow", 1, true) ~= nil or string.find(nameLower, "seed", 1, true) ~= nil then
        if fruitSignals.hasEffectiveFruit == true then
            addBlocker("HAS_ACTIVE_CROP_FOR_SOW")
        end
        if fieldState.canBeWorked ~= true then
            addBlocker(string.format("CAN_BE_WORKED_FALSE(canBeWorked=%s)", tostring(fieldState.canBeWorked)))
        end
        if fieldState.canBeSown ~= true then
            addBlocker(string.format("CAN_BE_SOWN_FALSE(canBeSown=%s)", tostring(fieldState.canBeSown)))
        end
    end

    if string.find(nameLower, "stonepick", 1, true) ~= nil or string.find(nameLower, "stone", 1, true) ~= nil then
        if missionInfo ~= nil and missionInfo.stonesEnabled == false then
            addBlocker("STONES_DISABLED_IN_SETTINGS")
        end
        local stoneOk, stoneReason = self:isStoneFieldStateSuitableWithoutPreparation(fieldState)
        if not stoneOk then
            addBlocker(string.format("STONE_STATE_FAIL(%s)", tostring(stoneReason)))
        end
    end

    if string.find(nameLower, "harvest", 1, true) ~= nil then
        local harvestOk, harvestReason = self:isHarvestFieldStateSuitableWithoutPreparation(fieldState)
        if not harvestOk then
            addBlocker(string.format("HARVEST_STATE_FAIL(%s)", tostring(harvestReason)))
        end
    end

    if string.find(nameLower, "mow", 1, true) ~= nil then
        local mowOk, mowReason = self:isMowFieldStateSuitableWithoutPreparation(fieldState)
        if not mowOk then
            addBlocker(string.format("MOW_STATE_FAIL(%s)", tostring(mowReason)))
        end
    end

    if string.find(nameLower, "ted", 1, true) ~= nil
        or string.find(nameLower, "windrow", 1, true) ~= nil
        or string.find(nameLower, "turn", 1, true) ~= nil then
        local turnOk, turnReason = self:isTurnFieldStateSuitableWithoutPreparation(fieldState)
        if not turnOk then
            addBlocker(string.format("TURN_STATE_FAIL(%s)", tostring(turnReason)))
        end
    end

    if #blockers == 0 then
        addBlocker("NO_NFW_BLOCKER_IDENTIFIED")
    end

    return table.concat(blockers, ";")
end

function NeighborFieldWorkers:buildMissionAvailabilityDetailForMissionGen(missionTypeName, field, classObject, availabilityReason)
    local className = tostring(classObject ~= nil and classObject.NAME or "n/a")
    return string.format(
        "availability=%s class=%s %s blockers={%s}",
        tostring(availabilityReason),
        className,
        self:getMissionGlobalDiagTextForMissionGen(),
        self:getMissionAvailabilityBlockersForMissionGen(missionTypeName, field)
    )
end

function NeighborFieldWorkers:forcePrepareSowMissionFieldIfNeeded(mission, missionSource, triggerSource, forceNow)
    if mission == nil or not self:isSowMission(mission) or mission.field == nil then
        return false
    end

    if mission.nfwSowFieldPreparedForNFW == true and forceNow ~= true then
        return false
    end

    local triggerText = tostring(triggerSource or "n/a")

    local shouldPrepare = forceNow == true
    local sourceText = tostring(missionSource or "n/a")
    if not shouldPrepare then
        local isGeneratedPreparedSource = string.find(sourceText, "GENERATED_PREPARED_", 1, true) == 1
        local isLegacyGeneratedSource = string.find(sourceText, "GENERATED_", 1, true) == 1
            and string.find(sourceText, "GENERATED_READY_", 1, true) ~= 1
        if isGeneratedPreparedSource or isLegacyGeneratedSource then
            shouldPrepare = true
        end
    end
    if not shouldPrepare and forceNow == true then
        shouldPrepare = true
    end
    if not shouldPrepare then
        return false
    end

    if forceNow == true and triggerText == "STALLED_PROGRESS" and mission.nfwSowRecoveryPrepDone == true then
        nfwLogHelperDiag(
            "[%s] HelperDiag SOW_PREP_SKIPPED: mission=%s reason=RECOVERY_PREP_ALREADY_DONE trigger=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            triggerText
        )
        return false
    end

    local now = g_time or 0
    if forceNow == true and tostring(triggerSource or "") == "PENDING_START" then
        local nextAllowedAt = Utils.getNoNil(mission.nfwNextPendingForcePrepAtMs, 0)
        if now < nextAllowedAt then
            return false
        end
        mission.nfwNextPendingForcePrepAtMs = now + 15000
    end

    local missionTypeName = self:getMissionTypeNameLower(mission)
    if missionTypeName == nil or missionTypeName == "" then
        missionTypeName = "sow"
    end

    local state = self:getForcedPrepareStateForMissionTypeAndFieldInternal(missionTypeName, mission.field)
    if state == nil then
        state = {
            fruitTypeIndex = (FruitType ~= nil and FruitType.UNKNOWN) or nil,
            growthState = 1,
            groundType = self:getSowForcedPrepareGroundTypeForMissionGen(),
            sprayType = (FieldSprayType ~= nil and FieldSprayType.NONE) or 0,
            sprayLevel = 0,
            weedState = 0
        }
    end

    local fieldId = mission.field.getId ~= nil and mission.field:getId() or "n/a"
    local ok = self:applyFieldStateForNeighborMission(mission.field, state)
    local missionPrepareOk = false
    if mission.prepareField ~= nil then
        local okPrepare = pcall(mission.prepareField, mission)
        missionPrepareOk = okPrepare == true
    end

    if ok or missionPrepareOk then
        mission.nfwSowFieldPreparedForNFW = true
        if forceNow == true and triggerText == "STALLED_PROGRESS" then
            mission.nfwSowRecoveryPrepDone = true
        end
        nfwLogInfo(
            "[%s] SOW_PREP: Feld vorbereitet fuer Saemission: mission=%s field=%s source=%s trigger=%s force=%s mode={nfw=%s,missionPrepare=%s}",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            tostring(fieldId),
            sourceText,
            triggerText,
            tostring(forceNow == true),
            tostring(ok),
            tostring(missionPrepareOk)
        )
        return true
    end

    nfwLogInfo(
        "[%s] SOW_PREP: Feldvorbereitung fehlgeschlagen: mission=%s field=%s source=%s trigger=%s",
        self.MOD_NAME,
        tostring(self:getMissionKey(mission)),
        tostring(fieldId),
        sourceText,
        triggerText
    )
    return false
end

function NeighborFieldWorkers:isSowMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or not self:isSowMission(mission) or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    return self:isSowFieldStateSuitableWithoutPreparation(fieldState)
end

function NeighborFieldWorkers:isSowFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local canBeSown = fieldState.canBeSown == true
    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    local hasFruit = fruitSignals.hasEffectiveFruit == true
    local canBeWorked = fieldState.canBeWorked == true

    if hasFruit then
        return false, string.format(
            "HAS_FRUIT(hasFruitRaw=%s,hasFruitEffective=%s,canBeSown=%s,canBeWorked=%s,growth=%s,fruitType=%s)",
            tostring(fruitSignals.rawHasFruit),
            tostring(fruitSignals.hasEffectiveFruit),
            tostring(canBeSown),
            tostring(canBeWorked),
            tostring(fieldState.growthState),
            tostring(fieldState.fruitTypeIndex)
        )
    end

    -- NOTE:
    -- canBeSown ist ein von GIANTS berechneter Laufzeit-Status und kann bei
    -- bestehenden Konkurrenzmissionen inkonsistent sein. Daher hier bewusst
    -- nicht mehr als harte Abbruchbedingung verwenden.
    -- if not canBeSown then
    --     return false, string.format(
    --         "CANNOT_BE_SOWN(hasFruitRaw=%s,hasFruitEffective=%s,canBeWorked=%s,growth=%s,fruitType=%s)",
    --         tostring(fruitSignals.rawHasFruit),
    --         tostring(fruitSignals.hasEffectiveFruit),
    --         tostring(canBeWorked),
    --         tostring(fieldState.growthState),
    --         tostring(fieldState.fruitTypeIndex)
    --     )
    -- end

    return true, "OK"
end

function NeighborFieldWorkers:isWeedControlFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local weedState = tonumber(fieldState.weedState) or 0
    if weedState > 0 then
        return true, string.format("OK(weedState=%s)", tostring(weedState))
    end

    return false, string.format(
        "NO_WEEDS(weedState=%s,growth=%s,fruitType=%s)",
        tostring(fieldState.weedState),
        tostring(fieldState.growthState),
        tostring(fieldState.fruitTypeIndex)
    )
end

function NeighborFieldWorkers:getSupportedWeedStatesForTool(isHoeWeeder)
    if self.weedToolSupportedStatesCache == nil then
        self.weedToolSupportedStatesCache = {}
    end

    local cacheKey = isHoeWeeder == true and "hoe" or "weeder"
    local cached = self.weedToolSupportedStatesCache[cacheKey]
    if cached ~= nil then
        return cached
    end

    local supported = {}
    local source = "fallback"

    local weedSystem = g_currentMission ~= nil and g_currentMission.weedSystem or nil
    if weedSystem ~= nil and weedSystem.getWeederReplacements ~= nil then
        local ok, replacementData = pcall(weedSystem.getWeederReplacements, weedSystem, isHoeWeeder == true)
        if ok and type(replacementData) == "table"
            and type(replacementData.weed) == "table"
            and type(replacementData.weed.replacements) == "table" then
            for sourceState, _ in pairs(replacementData.weed.replacements) do
                local numericState = tonumber(sourceState)
                if numericState ~= nil then
                    supported[numericState] = true
                end
            end
            if next(supported) ~= nil then
                source = "giantsWeedSystem"
            end
        end
    end

    if next(supported) == nil then
        if isHoeWeeder == true then
            supported[1] = true
            supported[2] = true
            supported[3] = true
            supported[4] = true
            supported[6] = true
            source = "fallbackHoe(1,2,3,4,6)"
        else
            supported[1] = true
            supported[2] = true
            supported[3] = true
            supported[4] = true
            source = "fallbackWeeder(1,2,3,4)"
        end
    end

    local states = {}
    for state, _ in pairs(supported) do
        table.insert(states, state)
    end
    table.sort(states)

    local data = {
        supported = supported,
        states = states,
        statesText = table.concat(states, ","),
        source = source
    }

    self.weedToolSupportedStatesCache[cacheKey] = data
    return data
end

function NeighborFieldWorkers:isWeedStateSupportedByTool(weedState, isHoeWeeder)
    local numericState = tonumber(weedState) or 0
    if numericState <= 0 then
        return false, string.format("NO_WEED_STATE(weedState=%s)", tostring(weedState))
    end

    local supportData = self:getSupportedWeedStatesForTool(isHoeWeeder == true)
    if supportData ~= nil and supportData.supported ~= nil and supportData.supported[numericState] == true then
        return true, string.format(
            "SUPPORTED(tool=%s,weedState=%s,supported={%s},source=%s)",
            isHoeWeeder == true and "hoe" or "weeder",
            tostring(numericState),
            tostring(supportData.statesText),
            tostring(supportData.source)
        )
    end

    return false, string.format(
        "WEED_STATE_NOT_SUPPORTED_BY_%s(weedState=%s,supported={%s},source=%s)",
        isHoeWeeder == true and "HOE" or "WEEDER",
        tostring(numericState),
        tostring(supportData ~= nil and supportData.statesText or "n/a"),
        tostring(supportData ~= nil and supportData.source or "n/a")
    )
end

function NeighborFieldWorkers:isHoeFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local cropOk, cropReason = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)
    if not cropOk then
        return false, string.format("CROP_NOT_VALID_FOR_HOE(%s)", tostring(cropReason))
    end

    local weedState = tonumber(fieldState.weedState) or 0
    if weedState <= 0 then
        return false, string.format(
            "NO_WEEDS_FOR_HOE(weedState=%s,growth=%s,fruitType=%s)",
            tostring(fieldState.weedState),
            tostring(fieldState.growthState),
            tostring(fieldState.fruitTypeIndex)
        )
    end

    local supported, supportReason = self:isWeedStateSupportedByTool(weedState, true)
    if not supported then
        return false, tostring(supportReason)
    end

    return true, string.format("OK_HOE(weedState=%s,%s)", tostring(weedState), tostring(supportReason))
end

function NeighborFieldWorkers:isWeedMissionFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local cropOk, cropReason = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)
    if not cropOk then
        return false, string.format("CROP_NOT_VALID_FOR_WEED(%s)", tostring(cropReason))
    end

    local weedState = tonumber(fieldState.weedState) or 0
    if weedState <= 0 then
        return false, string.format(
            "NO_WEEDS_FOR_WEED(weedState=%s,growth=%s,fruitType=%s)",
            tostring(fieldState.weedState),
            tostring(fieldState.growthState),
            tostring(fieldState.fruitTypeIndex)
        )
    end

    local supported, supportReason = self:isWeedStateSupportedByTool(weedState, false)
    if not supported then
        return false, tostring(supportReason)
    end

    return true, string.format("OK_WEED(weedState=%s,%s)", tostring(weedState), tostring(supportReason))
end

function NeighborFieldWorkers:isHoeMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    return self:isHoeFieldStateSuitableWithoutPreparation(fieldState)
end

function NeighborFieldWorkers:isWeedMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    return self:isWeedMissionFieldStateSuitableWithoutPreparation(fieldState)
end

function NeighborFieldWorkers:isFertilizeMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    return self:isFertilizeFieldStateSuitableWithoutPreparation(fieldState)
end

function NeighborFieldWorkers:isFertilizeFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local sprayLevel = tonumber(fieldState.sprayLevel)
    local sprayMax = (g_fieldManager ~= nil and g_fieldManager.sprayLevelMaxValue) or nil
    if sprayLevel ~= nil and type(sprayMax) == "number" and sprayMax > 0 then
        if sprayLevel >= sprayMax then
            return false, string.format(
                "FULLY_FERTILIZED(sprayLevel=%s,max=%s)",
                tostring(sprayLevel),
                tostring(sprayMax)
            )
        end
    end

    -- NOTE:
    -- canBeFertilized ist ein von GIANTS berechneter Laufzeit-Status und kann
    -- bei bestehenden Konkurrenzmissionen inkonsistent sein. Daher hier bewusst
    -- nicht mehr als harte Abbruchbedingung verwenden.
    -- if type(fieldState.canBeFertilized) == "boolean" and not fieldState.canBeFertilized then
    --     return false, string.format(
    --         "CANNOT_BE_FERTILIZED(sprayLevel=%s,max=%s,canBeWorked=%s,growth=%s,fruitType=%s)",
    --         tostring(sprayLevel),
    --         tostring(sprayMax),
    --         tostring(fieldState.canBeWorked),
    --         tostring(fieldState.growthState),
    --         tostring(fieldState.fruitTypeIndex)
    --     )
    -- end

    local cropOk, cropReason = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)
    if not cropOk then
        return false, string.format("CROP_NOT_VALID_FOR_FERTILIZE(%s)", tostring(cropReason))
    end

    return true, "OK"
end

function NeighborFieldWorkers:isSprayMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    return self:isSprayFieldStateSuitableWithoutPreparation(fieldState)
end

function NeighborFieldWorkers:isSprayFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    local hasFruit = fruitSignals.hasEffectiveFruit == true
    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    local growthState = tonumber(fieldState.growthState) or 0

    if not hasFruit then
        return false, string.format(
            "NO_FRUIT(hasFruitRaw=%s,hasFruitEffective=%s,fruitType=%s,growth=%s)",
            tostring(fruitSignals.rawHasFruit),
            tostring(fruitSignals.hasEffectiveFruit),
            tostring(fieldState.fruitTypeIndex),
            tostring(fieldState.growthState)
        )
    end

    if fruitTypeIndex == nil or (FruitType ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return false, string.format("UNKNOWN_FRUIT_TYPE(fruitType=%s)", tostring(fieldState.fruitTypeIndex))
    end

    if growthState <= 0 then
        return false, string.format("NO_GROWTH(growth=%s)", tostring(fieldState.growthState))
    end

    local fruitTypeDesc = nil
    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypeByIndex ~= nil then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    end

    if fruitTypeDesc == nil then
        return false, string.format("FRUIT_DESC_MISSING(fruitType=%s)", tostring(fruitTypeIndex))
    end

    if self:isFruitGrowthWithered(fruitTypeDesc, growthState) then
        return false, string.format("WITHERED(growth=%s,fruitType=%s)", tostring(growthState), tostring(fruitTypeIndex))
    end

    local weedOk, weedReason = self:isWeedControlFieldStateSuitableWithoutPreparation(fieldState)
    if not weedOk then
        return false, string.format("NO_WEED_TARGET(%s)", tostring(weedReason))
    end

    return true, "OK"
end

function NeighborFieldWorkers:getFruitTypeByIndexSafe(fruitTypeIndex)
    if fruitTypeIndex == nil or g_fruitTypeManager == nil or g_fruitTypeManager.getFruitTypeByIndex == nil then
        return nil
    end

    return g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
end

function NeighborFieldWorkers:isFruitTypeGrassLikeForMowMission(fruitTypeDesc)
    if fruitTypeDesc == nil then
        return false
    end

    local fruitIndex = tonumber(fruitTypeDesc.index)
    if FruitType ~= nil and fruitIndex ~= nil and FruitType.GRASS ~= nil and fruitIndex == FruitType.GRASS then
        return true
    end

    local nameUpper = string.upper(tostring(fruitTypeDesc.name or ""))
    if string.find(nameUpper, "GRASS", 1, true) ~= nil
        or string.find(nameUpper, "CLOVER", 1, true) ~= nil
        or string.find(nameUpper, "KLEE", 1, true) ~= nil
        or string.find(nameUpper, "LUCERNE", 1, true) ~= nil
        or string.find(nameUpper, "LUZERNE", 1, true) ~= nil
        or string.find(nameUpper, "ALFALFA", 1, true) ~= nil then
        return true
    end

    return false
end

function NeighborFieldWorkers:isFruitGrowthWithered(fruitTypeDesc, growthState)
    if fruitTypeDesc == nil then
        return false
    end

    local isWithered = false
    if fruitTypeDesc.getIsWithered ~= nil then
        local okWithered, withered = pcall(fruitTypeDesc.getIsWithered, fruitTypeDesc, growthState)
        if okWithered and withered == true then
            isWithered = true
        end
    end

    if not isWithered and type(fruitTypeDesc.witheredState) == "number" and growthState == fruitTypeDesc.witheredState then
        isWithered = true
    end

    return isWithered
end

function NeighborFieldWorkers:isHarvestFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    if fruitSignals.hasEffectiveFruit ~= true then
        return false, string.format(
            "NO_FRUIT(hasFruitRaw=%s,hasFruitEffective=%s,fruitType=%s,growth=%s)",
            tostring(fruitSignals.rawHasFruit),
            tostring(fruitSignals.hasEffectiveFruit),
            tostring(fieldState.fruitTypeIndex),
            tostring(fieldState.growthState)
        )
    end

    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    if fruitTypeIndex == nil or (FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return false, string.format("UNKNOWN_FRUIT_TYPE(fruitType=%s)", tostring(fieldState.fruitTypeIndex))
    end

    local growthState = tonumber(fieldState.growthState) or 0
    if growthState <= 0 then
        return false, string.format("NO_GROWTH(growth=%s)", tostring(fieldState.growthState))
    end

    local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
    if fruitTypeDesc == nil then
        return false, string.format("FRUIT_DESC_MISSING(fruitType=%s)", tostring(fruitTypeIndex))
    end

    if self:isFruitTypeGrassLikeForMowMission(fruitTypeDesc) then
        return false,
            string.format("GRASS_LIKE_USE_MOW(fruitType=%s,name=%s)", tostring(fruitTypeIndex),
                tostring(fruitTypeDesc.name))
    end

    if self:isFruitGrowthWithered(fruitTypeDesc, growthState) then
        return false, string.format("WITHERED(growth=%s,fruitType=%s)", tostring(growthState), tostring(fruitTypeIndex))
    end

    local growthMode = g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and
        g_currentMission.missionInfo.growthMode or nil
    local currentPeriod = g_currentMission ~= nil and g_currentMission.environment ~= nil and
        g_currentMission.environment.currentPeriod or nil
    if not self:isFruitHarvestableInCurrentPeriodForMissionGen(fruitTypeDesc, growthMode, currentPeriod) then
        return false,
            string.format("OUT_OF_SEASON(fruitType=%s,period=%s)", tostring(fruitTypeIndex), tostring(currentPeriod))
    end

    local minHarvest = tonumber(fruitTypeDesc.minHarvestingGrowthState) or 0
    local maxHarvest = tonumber(fruitTypeDesc.maxHarvestingGrowthState) or 0
    if minHarvest > 0 and maxHarvest > 0 and growthState >= minHarvest and growthState <= maxHarvest then
        return true,
            string.format("OK(growth=%s,min=%s,max=%s,fruitType=%s)", tostring(growthState), tostring(minHarvest),
                tostring(maxHarvest), tostring(fruitTypeIndex))
    end

    return false, string.format(
        "NOT_HARVEST_READY(growth=%s,min=%s,max=%s,fruitType=%s)",
        tostring(growthState),
        tostring(minHarvest),
        tostring(maxHarvest),
        tostring(fruitTypeIndex)
    )
end

function NeighborFieldWorkers:isMowFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    if fruitSignals.hasEffectiveFruit ~= true then
        return false, string.format(
            "NO_FRUIT(hasFruitRaw=%s,hasFruitEffective=%s,fruitType=%s,growth=%s)",
            tostring(fruitSignals.rawHasFruit),
            tostring(fruitSignals.hasEffectiveFruit),
            tostring(fieldState.fruitTypeIndex),
            tostring(fieldState.growthState)
        )
    end

    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    if fruitTypeIndex == nil or (FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return false, string.format("UNKNOWN_FRUIT_TYPE(fruitType=%s)", tostring(fieldState.fruitTypeIndex))
    end

    local growthState = tonumber(fieldState.growthState) or 0
    if growthState <= 0 then
        return false, string.format("NO_GROWTH(growth=%s)", tostring(fieldState.growthState))
    end

    local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
    if fruitTypeDesc == nil then
        return false, string.format("FRUIT_DESC_MISSING(fruitType=%s)", tostring(fruitTypeIndex))
    end

    if not self:isFruitTypeGrassLikeForMowMission(fruitTypeDesc) then
        return false,
            string.format("NOT_GRASS_LIKE(fruitType=%s,name=%s)", tostring(fruitTypeIndex), tostring(fruitTypeDesc.name))
    end

    if self:isFruitGrowthWithered(fruitTypeDesc, growthState) then
        return false, string.format("WITHERED(growth=%s,fruitType=%s)", tostring(growthState), tostring(fruitTypeIndex))
    end

    local growthMode = g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and
        g_currentMission.missionInfo.growthMode or nil
    local currentPeriod = g_currentMission ~= nil and g_currentMission.environment ~= nil and
        g_currentMission.environment.currentPeriod or nil
    if not self:isFruitHarvestableInCurrentPeriodForMissionGen(fruitTypeDesc, growthMode, currentPeriod) then
        return false,
            string.format("OUT_OF_SEASON(fruitType=%s,period=%s)", tostring(fruitTypeIndex), tostring(currentPeriod))
    end

    local minHarvest = tonumber(fruitTypeDesc.minHarvestingGrowthState) or 0
    local maxHarvest = tonumber(fruitTypeDesc.maxHarvestingGrowthState) or 0
    if maxHarvest > 0 then
        local readyFrom = math.max(1, maxHarvest - 1)
        if growthState >= readyFrom and growthState <= maxHarvest then
            return true, string.format(
                "OK(growth=%s,readyFrom=%s,max=%s,fruitType=%s)",
                tostring(growthState),
                tostring(readyFrom),
                tostring(maxHarvest),
                tostring(fruitTypeIndex)
            )
        end
    end

    if minHarvest > 0 and maxHarvest > 0 and growthState >= minHarvest and growthState <= maxHarvest then
        return true,
            string.format("OK_STRICT(growth=%s,min=%s,max=%s,fruitType=%s)", tostring(growthState), tostring(minHarvest),
                tostring(maxHarvest), tostring(fruitTypeIndex))
    end

    return false, string.format(
        "NOT_MOW_READY(growth=%s,min=%s,max=%s,fruitType=%s)",
        tostring(growthState),
        tostring(minHarvest),
        tostring(maxHarvest),
        tostring(fruitTypeIndex)
    )
end

function NeighborFieldWorkers:isHarvestMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    return self:isHarvestFieldStateSuitableWithoutPreparation(fieldState)
end

function NeighborFieldWorkers:isMowMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    return self:isMowFieldStateSuitableWithoutPreparation(fieldState)
end

function NeighborFieldWorkers:isTurnMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    return self:isTurnFieldStateSuitableWithoutPreparation(fieldState)
end

function NeighborFieldWorkers:isTurnFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    if fruitSignals.hasEffectiveFruit ~= true then
        return false, string.format(
            "NO_FRUIT(hasFruitRaw=%s,hasFruitEffective=%s,fruitType=%s,growth=%s)",
            tostring(fruitSignals.rawHasFruit),
            tostring(fruitSignals.hasEffectiveFruit),
            tostring(fieldState.fruitTypeIndex),
            tostring(fieldState.growthState)
        )
    end

    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    if fruitTypeIndex == nil or (FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return false, string.format("UNKNOWN_FRUIT_TYPE(fruitType=%s)", tostring(fieldState.fruitTypeIndex))
    end

    local growthState = tonumber(fieldState.growthState) or 0
    if growthState <= 0 then
        return false, string.format("NO_GROWTH(growth=%s)", tostring(fieldState.growthState))
    end

    local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
    if fruitTypeDesc == nil then
        return false, string.format("FRUIT_DESC_MISSING(fruitType=%s)", tostring(fruitTypeIndex))
    end

    if not self:isFruitTypeGrassLikeForMowMission(fruitTypeDesc) then
        return false,
            string.format("NOT_GRASS_LIKE_FOR_TURN(fruitType=%s,name=%s)", tostring(fruitTypeIndex),
                tostring(fruitTypeDesc.name))
    end

    if self:isFruitGrowthWithered(fruitTypeDesc, growthState) then
        return false, string.format("WITHERED(growth=%s,fruitType=%s)", tostring(growthState), tostring(fruitTypeIndex))
    end

    local isCutState = false
    if fruitTypeDesc.getIsCut ~= nil then
        local okCut, cut = pcall(fruitTypeDesc.getIsCut, fruitTypeDesc, growthState)
        if okCut and cut == true then
            isCutState = true
        end
    end

    if not isCutState and type(fruitTypeDesc.cutStates) == "table" and fruitTypeDesc.cutStates[growthState] == true then
        isCutState = true
    end

    if not isCutState and type(fruitTypeDesc.cutState) == "number" and fruitTypeDesc.cutState > 0 and growthState == fruitTypeDesc.cutState then
        isCutState = true
    end

    local isGrassCutGround = false
    if FieldGroundType ~= nil and FieldGroundType.GRASS_CUT ~= nil and fieldState.groundType == FieldGroundType.GRASS_CUT then
        isGrassCutGround = true
    end

    if not isCutState and not isGrassCutGround then
        return false, string.format(
            "NOT_FRESHLY_CUT(growth=%s,cutState=%s,groundType=%s)",
            tostring(growthState),
            tostring(fruitTypeDesc.cutState),
            tostring(fieldState.groundType)
        )
    end

    return true, string.format(
        "OK_TURN(growth=%s,cut=%s,groundType=%s)",
        tostring(growthState),
        tostring(isCutState),
        tostring(fieldState.groundType)
    )
end

function NeighborFieldWorkers:isFieldStateCropAliveAndNotHarvestReady(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    local hasFruit = fruitSignals.hasEffectiveFruit == true
    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    local growthState = tonumber(fieldState.growthState) or 0

    if not hasFruit then
        return false, string.format(
            "NO_FRUIT(hasFruitRaw=%s,hasFruitEffective=%s,fruitType=%s,growth=%s)",
            tostring(fruitSignals.rawHasFruit),
            tostring(fruitSignals.hasEffectiveFruit),
            tostring(fieldState.fruitTypeIndex),
            tostring(fieldState.growthState)
        )
    end

    if fruitTypeIndex == nil or (FruitType ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return false, string.format("UNKNOWN_FRUIT_TYPE(fruitType=%s)", tostring(fieldState.fruitTypeIndex))
    end

    if growthState <= 0 then
        return false, string.format("NO_GROWTH(growth=%s)", tostring(fieldState.growthState))
    end

    local fruitTypeDesc = nil
    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypeByIndex ~= nil then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    end

    if fruitTypeDesc ~= nil then
        local isWithered = false
        if fruitTypeDesc.getIsWithered ~= nil then
            local okWithered, withered = pcall(fruitTypeDesc.getIsWithered, fruitTypeDesc, growthState)
            if okWithered and withered == true then
                isWithered = true
            end
        end
        if not isWithered and type(fruitTypeDesc.witheredState) == "number" and growthState == fruitTypeDesc.witheredState then
            isWithered = true
        end
        if isWithered then
            return false,
                string.format("WITHERED(growth=%s,fruitType=%s)", tostring(growthState), tostring(fruitTypeIndex))
        end

        local minHarvest = tonumber(fruitTypeDesc.minHarvestingGrowthState) or 0
        local maxHarvest = tonumber(fruitTypeDesc.maxHarvestingGrowthState) or 0
        if minHarvest > 0 and maxHarvest > 0 and growthState >= minHarvest and growthState <= maxHarvest then
            return false, string.format(
                "HARVEST_READY(growth=%s,min=%s,max=%s,fruitType=%s)",
                tostring(growthState),
                tostring(minHarvest),
                tostring(maxHarvest),
                tostring(fruitTypeIndex)
            )
        end
    end

    return true, string.format("OK(growth=%s,fruitType=%s)", tostring(growthState), tostring(fruitTypeIndex))
end

function NeighborFieldWorkers:isFieldStateDeadEmptyOrEarlyForSoilWork(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    if fruitTypeIndex == nil then
        fruitTypeIndex = FruitType.UNKNOWN
    end
    local growthState = tonumber(fieldState.growthState) or 0
    local hasFruitFlag = fieldState.hasFruit

    if fruitSignals.hasEffectiveFruit ~= true or fruitTypeIndex == FruitType.UNKNOWN or growthState <= 0 then
        return true, string.format(
            "NO_FRUIT(fruitType=%s,growth=%s,hasFruitRaw=%s,hasFruitEffective=%s)",
            tostring(fruitTypeIndex),
            tostring(growthState),
            tostring(hasFruitFlag),
            tostring(fruitSignals.hasEffectiveFruit)
        )
    end

    if growthState <= 1 then
        return true, string.format(
            "GROWTH_LE_1(fruitType=%s,growth=%s)",
            tostring(fruitTypeIndex),
            tostring(growthState)
        )
    end

    local isWithered = false
    local fruitTypeDesc = nil
    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypeByIndex ~= nil then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    end
    if fruitTypeDesc ~= nil then
        if fruitTypeDesc.getIsWithered ~= nil then
            local okWithered, withered = pcall(fruitTypeDesc.getIsWithered, fruitTypeDesc, growthState)
            if okWithered and withered == true then
                isWithered = true
            end
        end
        if not isWithered and type(fruitTypeDesc.witheredState) == "number" and growthState == fruitTypeDesc.witheredState then
            isWithered = true
        end
    end

    if isWithered then
        return true, string.format(
            "WITHERED(fruitType=%s,growth=%s)",
            tostring(fruitTypeIndex),
            tostring(growthState)
        )
    end

    if fruitTypeDesc ~= nil then
        local maxHarvest = tonumber(fruitTypeDesc.maxHarvestingGrowthState) or 0
        if maxHarvest > 0 and growthState > maxHarvest then
            return true, string.format(
                "POST_HARVEST_WINDOW(fruitType=%s,growth=%s,maxHarvest=%s)",
                tostring(fruitTypeIndex),
                tostring(growthState),
                tostring(maxHarvest)
            )
        end
    end

    return false, string.format(
        "NOT_ALLOWED(fruitType=%s,growth=%s,hasFruitRaw=%s,hasFruitEffective=%s)",
        tostring(fruitTypeIndex),
        tostring(growthState),
        tostring(hasFruitFlag),
        tostring(fruitSignals.hasEffectiveFruit)
    )
end

function NeighborFieldWorkers:isStoneFieldStateSuitableWithoutPreparation(fieldState)
    if fieldState == nil then
        return false, "FIELD_STATE_NIL"
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    local hasFruit = fruitSignals.hasEffectiveFruit == true
    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    local growthState = tonumber(fieldState.growthState) or 0

    if hasFruit and growthState > 0 and (fruitTypeIndex == nil or FruitType == nil or fruitTypeIndex ~= FruitType.UNKNOWN) then
        return false, string.format(
            "HAS_ACTIVE_CROP(fruitType=%s,growth=%s,hasFruitRaw=%s,hasFruitEffective=%s)",
            tostring(fieldState.fruitTypeIndex),
            tostring(fieldState.growthState),
            tostring(fieldState.hasFruit),
            tostring(fruitSignals.hasEffectiveFruit)
        )
    end

    local groundType = fieldState.groundType
    local isPlowedGround = false

    if FieldGroundType ~= nil and FieldGroundType.PLOWED ~= nil and groundType == FieldGroundType.PLOWED then
        isPlowedGround = true
    end

    if not isPlowedGround then
        return false, string.format(
            "GROUND_NOT_PLOWED(groundType=%s)",
            tostring(groundType)
        )
    end

    local stoneLevel = tonumber(fieldState.stoneLevel) or 0
    if stoneLevel <= 0 then
        return false, string.format(
            "NO_STONES(stoneLevel=%s,groundType=%s)",
            tostring(fieldState.stoneLevel),
            tostring(groundType)
        )
    end

    return true, string.format(
        "OK(stoneLevel=%s,groundType=%s)",
        tostring(stoneLevel),
        tostring(groundType)
    )
end

function NeighborFieldWorkers:isSoilWorkMissionFieldSuitableWithoutPreparation(mission)
    if mission == nil or mission.field == nil then
        return false, "MISSION_OR_FIELD_NIL"
    end

    local isSoilWorkMission = self:isPlowMission(mission) or self:isCultivateMission(mission) or
        self:isStoneMission(mission)
    if not isSoilWorkMission then
        return true, "NOT_SOIL_WORK_MISSION"
    end

    if mission.field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    if self:isStoneMission(mission) then
        return self:isStoneFieldStateSuitableWithoutPreparation(fieldState)
    end

    return self:isFieldStateDeadEmptyOrEarlyForSoilWork(fieldState)
end

function NeighborFieldWorkers:getNeighborMissionReadySuitability(mission)
    if mission == nil then
        return false, "MISSION_NIL", "MISSION"
    end

    if self:isSowMission(mission) then
        local ok, reason = self:isSowMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "sowMission"
    end

    if self:isFertilizeMission(mission) then
        local ok, reason = self:isFertilizeMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "fertilizeMission"
    end

    if self:isSprayMission(mission) then
        local ok, reason = self:isSprayMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "sprayMission"
    end

    if self:isHarvestMission(mission) then
        local ok, reason = self:isHarvestMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "harvestMission"
    end

    if self:isMowMission(mission) then
        local ok, reason = self:isMowMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "mowMission"
    end

    if self:isTurnMission(mission) then
        local ok, reason = self:isTurnMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "turnMission"
    end

    if self:isPlowMission(mission) or self:isCultivateMission(mission) or self:isStoneMission(mission) then
        local ok, reason = self:isSoilWorkMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "soilWorkMission"
    end

    if self:isHoeMission(mission) then
        local ok, reason = self:isHoeMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "hoeMission"
    end

    if self:isWeedMission(mission) then
        local ok, reason = self:isWeedMissionFieldSuitableWithoutPreparation(mission)
        return ok, reason, "weedMission"
    end

    return true, "NO_EXTRA_CHECK", nil
end

function NeighborFieldWorkers:validateGeneratedMissionForReadyUse(mission, triggerSource, passLabel)
    if mission == nil then
        return nil
    end

    local missionKey = self:getMissionKey(mission)
    local fieldInUse, fieldId, inUseReason = self:isMissionFieldInUseByNeighbor(mission, missionKey)
    if fieldInUse then
        nfwLogInfo(
            "[%s] MissionGen[%s]: %s verworfen (Feld bereits belegt): mission=%s field=%s reason=%s",
            self.MOD_NAME,
            tostring(triggerSource),
            tostring(passLabel or "PASS"),
            tostring(missionKey),
            tostring(fieldId),
            tostring(inUseReason)
        )

        if g_missionManager ~= nil then
            pcall(g_missionManager.cancelMission, g_missionManager, mission)
            pcall(g_missionManager.dismissMission, g_missionManager, mission)
        end

        return nil
    end

    local isSuitable, reason, checkName = self:getNeighborMissionReadySuitability(mission)

    if checkName == nil or isSuitable then
        return mission
    end

    nfwLogInfo(
        "[%s] MissionGen[%s]: %s %s verworfen (Feld ungueltig): mission=%s field=%s reason=%s",
        self.MOD_NAME,
        tostring(triggerSource),
        tostring(passLabel or "PASS"),
        tostring(checkName),
        tostring(self:getMissionKey(mission)),
        tostring(self:getMissionFieldId(mission)),
        tostring(reason)
    )

    if g_missionManager ~= nil then
        pcall(g_missionManager.cancelMission, g_missionManager, mission)
        pcall(g_missionManager.dismissMission, g_missionManager, mission)
    end

    return nil
end

function NeighborFieldWorkers:isAllowedMissionTypeName(missionTypeName)
    local nameLower = string.lower(tostring(missionTypeName or ""))
    if string.find(nameLower, "plow", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "cultivat", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "mow", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "hoe", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "weed", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "fertiliz", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "herbicid", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "spray", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "sow", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "seed", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "harvest", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "stonepick", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "stone", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "ted", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "windrow", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "turn", 1, true) ~= nil then
        return true
    end
    if string.find(nameLower, "wend", 1, true) ~= nil then
        return true
    end

    return false
end

function NeighborFieldWorkers:isAllowedMissionType(mission)
    return self:isAllowedMissionTypeName(self:getMissionTypeName(mission))
end

function NeighborFieldWorkers:shouldAllowForcedPrepareForMissionTypeName(missionTypeName)
    return true
end

function NeighborFieldWorkers:canMissionBeStartedWithVehicles(mission)
    if mission == nil then
        return false, "MISSION_NIL"
    end

    if self:isMowAndBaleMission(mission) then
        return false, "MOW_BALE_NOT_SUPPORTED"
    end

    if mission.hasLeasableVehicles ~= nil then
        local ok, hasLeasable = pcall(mission.hasLeasableVehicles, mission)
        if ok and not hasLeasable then
            return false, "NO_LEASABLE_VEHICLES"
        end
    end

    return true, nil
end

function NeighborFieldWorkers:getMissionFieldId(mission)
    if mission ~= nil and mission.getFarmlandId ~= nil then
        local ok, fieldId = pcall(mission.getFarmlandId, mission)
        if ok then
            return fieldId
        end
    end

    return nil
end

function NeighborFieldWorkers:getActiveNeighborFieldReservations()
    local reservations = {}

    local function tryReserve(fieldId, source, key)
        if fieldId == nil then
            return
        end

        local fieldKey = tostring(fieldId)
        if fieldKey == "" or reservations[fieldKey] ~= nil then
            return
        end

        reservations[fieldKey] = {
            source = source,
            key = key ~= nil and tostring(key) or nil
        }
    end

    for assignmentKey, assignment in pairs(self.activeAssignments) do
        if assignment ~= nil and assignment.mission ~= nil then
            local status = assignment.mission.status
            if status ~= MissionStatus.FINISHED and status ~= MissionStatus.DISMISSED then
                tryReserve(self:getMissionFieldId(assignment.mission), "ACTIVE_ASSIGNMENT", assignmentKey)
            end
        end
    end

    if g_missionManager ~= nil and g_missionManager.getMissions ~= nil then
        for _, mission in ipairs(g_missionManager:getMissions()) do
            if mission ~= nil then
                local status = mission.status
                if status ~= MissionStatus.FINISHED
                    and status ~= MissionStatus.DISMISSED
                    and mission.farmId ~= nil
                    and self:isNeighborFarm(mission.farmId) then
                    tryReserve(self:getMissionFieldId(mission), "MISSION_MANAGER_NEIGHBOR", self:getMissionKey(mission))
                end
            end
        end
    end

    for savedKey, savedFieldId in pairs(self.savedAssignmentFieldIds) do
        if savedFieldId ~= nil and self.activeAssignments[savedKey] == nil then
            tryReserve(savedFieldId, "SAVE_PENDING_KEY", savedKey)
        end
    end

    return reservations
end

function NeighborFieldWorkers:isMissionFieldInUseByNeighbor(mission, ignoreMissionKey)
    if mission == nil then
        return false, nil, "MISSION_NIL"
    end

    local fieldId = self:getMissionFieldId(mission)
    if fieldId == nil then
        return false, nil, "NO_FIELD_ID"
    end

    local reservations = self:getActiveNeighborFieldReservations()
    local reservation = reservations[tostring(fieldId)]
    if reservation == nil then
        return false, fieldId, "FREE"
    end

    local ignoredKey = ignoreMissionKey ~= nil and tostring(ignoreMissionKey) or nil
    if ignoredKey ~= nil and reservation.key ~= nil and reservation.key == ignoredKey then
        return false, fieldId, "OWN_KEY"
    end

    local reason = tostring(reservation.source or "UNKNOWN")
    if reservation.key ~= nil then
        reason = string.format("%s:%s", reason, tostring(reservation.key))
    end

    return true, fieldId, reason
end

function NeighborFieldWorkers:getMissionLocationText(mission)
    if mission ~= nil and mission.getLocation ~= nil then
        local ok, location = pcall(mission.getLocation, mission)
        if ok and location ~= nil then
            return tostring(location)
        end
    end

    return "n/a"
end

function NeighborFieldWorkers:getMissionFieldPosition(mission)
    if mission ~= nil and mission.field ~= nil and mission.field.getCenterOfFieldWorldPosition ~= nil then
        local okCenter, x, z = pcall(mission.field.getCenterOfFieldWorldPosition, mission.field)
        if okCenter and type(x) == "number" and type(z) == "number" then
            return x, z
        end
    end

    if mission ~= nil and mission.getWorldPosition ~= nil then
        local ok, x, z = pcall(mission.getWorldPosition, mission)
        if ok and type(x) == "number" and type(z) == "number" then
            return x, z
        end
    end

    if mission ~= nil and mission.field ~= nil and mission.field.getIndicatorPosition ~= nil then
        local ok, x, _, z = pcall(mission.field.getIndicatorPosition, mission.field)
        if ok and type(x) == "number" and type(z) == "number" then
            return x, z
        end
    end

    return nil, nil
end

function NeighborFieldWorkers:isPositionWithinMissionField(mission, x, z)
    if mission == nil or type(x) ~= "number" or type(z) ~= "number" then
        return false
    end
    if g_missionManager == nil or g_missionManager.getMissionAtWorldPosition == nil then
        return false
    end

    local ok, missionAtPos = pcall(g_missionManager.getMissionAtWorldPosition, g_missionManager, x, z)
    if not ok or missionAtPos == nil then
        return false
    end

    return self:getMissionKey(missionAtPos) == self:getMissionKey(mission)
end

function NeighborFieldWorkers:getMissionFieldPolygonWorldPoints(mission)
    local points = {}
    if mission == nil or mission.field == nil then
        return points
    end

    local polyNodes = mission.field.polygonPoints
    if type(polyNodes) ~= "table" then
        return points
    end

    for _, node in ipairs(polyNodes) do
        if node ~= nil then
            local x, _, z = getWorldTranslation(node)
            if type(x) == "number" and type(z) == "number" then
                table.insert(points, { x = x, z = z })
            end
        end
    end

    return points
end

function NeighborFieldWorkers:getClosestPointOnSegment2D(px, pz, ax, az, bx, bz)
    local abx = bx - ax
    local abz = bz - az
    local abLenSq = abx * abx + abz * abz
    if abLenSq <= 0.000001 then
        local dx = px - ax
        local dz = pz - az
        return ax, az, dx * dx + dz * dz
    end

    local apx = px - ax
    local apz = pz - az
    local t = (apx * abx + apz * abz) / abLenSq
    t = math.max(0, math.min(1, t))
    local qx = ax + abx * t
    local qz = az + abz * t
    local dx = px - qx
    local dz = pz - qz
    return qx, qz, dx * dx + dz * dz
end

function NeighborFieldWorkers:getAIDriveReferenceNode(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return nil
    end

    if vehicle.getAIRootNode ~= nil then
        local okRoot, rootNode = pcall(vehicle.getAIRootNode, vehicle)
        if okRoot and rootNode ~= nil then
            return rootNode
        end
    end

    return vehicle.rootNode
end

function NeighborFieldWorkers:getAIAgentFrontDistanceFromReference(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return nil
    end

    local frontDistance = nil
    if vehicle.getAIAgentSize ~= nil then
        local okSize, _, length, lengthOffset = pcall(vehicle.getAIAgentSize, vehicle)
        if okSize and type(length) == "number" and type(lengthOffset) == "number" then
            frontDistance = math.max(0, length * 0.5 + lengthOffset)
        end
    end

    if frontDistance == nil and vehicle.getAIRootNodeMaxZOffset ~= nil then
        local okMax, maxZ = pcall(vehicle.getAIRootNodeMaxZOffset, vehicle)
        if okMax and type(maxZ) == "number" then
            frontDistance = math.max(0, maxZ)
        end
    end

    return frontDistance
end

function NeighborFieldWorkers:getRaySegmentIntersection2D(rx, rz, dirX, dirZ, ax, az, bx, bz)
    local segX = bx - ax
    local segZ = bz - az
    local denom = dirX * segZ - dirZ * segX
    if math.abs(denom) <= 0.000001 then
        return nil, nil, nil
    end

    local relX = ax - rx
    local relZ = az - rz
    local t = (relX * segZ - relZ * segX) / denom
    local u = (relX * dirZ - relZ * dirX) / denom
    if t >= 0 and u >= 0 and u <= 1 then
        return rx + dirX * t, rz + dirZ * t, t
    end

    return nil, nil, nil
end

function NeighborFieldWorkers:getMissionFieldEdgeStartPosition(mission, referenceX, referenceZ, inwardOffset, forwardDirX, forwardDirZ)
    local points = self:getMissionFieldPolygonWorldPoints(mission)
    if #points < 3 then
        return nil, nil, "NO_POLYGON"
    end

    local rx = tonumber(referenceX)
    local rz = tonumber(referenceZ)
    if type(rx) ~= "number" or type(rz) ~= "number" then
        rx, rz = self:getMissionFieldPosition(mission)
    end
    if type(rx) ~= "number" or type(rz) ~= "number" then
        return nil, nil, "NO_REFERENCE"
    end

    local bestX, bestZ = nil, nil
    local bestDistSq = math.huge
    local startMode = "NEAREST_EDGE"

    local dirX = tonumber(forwardDirX)
    local dirZ = tonumber(forwardDirZ)
    if type(dirX) == "number" and type(dirZ) == "number" then
        local len = MathUtil.vector2Length(dirX, dirZ)
        if len > 0.001 then
            dirX = dirX / len
            dirZ = dirZ / len

            local bestT = math.huge
            for i = 1, #points do
                local a = points[i]
                local b = points[(i % #points) + 1]
                local hitX, hitZ, t = self:getRaySegmentIntersection2D(rx, rz, dirX, dirZ, a.x, a.z, b.x, b.z)
                if type(t) == "number" and t >= 0.05 and t < bestT then
                    bestT = t
                    bestX = hitX
                    bestZ = hitZ
                end
            end

            if type(bestX) == "number" and type(bestZ) == "number" then
                startMode = "FORWARD_RAY"
            end
        end
    end

    if type(bestX) ~= "number" or type(bestZ) ~= "number" then
        for i = 1, #points do
            local a = points[i]
            local b = points[(i % #points) + 1]
            local qx, qz, distSq = self:getClosestPointOnSegment2D(rx, rz, a.x, a.z, b.x, b.z)
            if distSq < bestDistSq then
                bestDistSq = distSq
                bestX, bestZ = qx, qz
            end
        end
    end

    if type(bestX) ~= "number" or type(bestZ) ~= "number" then
        return nil, nil, "NO_EDGE_POINT"
    end

    local cx, cz = self:getMissionFieldPosition(mission)
    local offset = tonumber(inwardOffset) or 2.5
    if offset > 0 then
        local usedForwardInset = false
        if startMode == "FORWARD_RAY" and type(dirX) == "number" and type(dirZ) == "number" then
            local insideBackX = bestX - dirX * offset
            local insideBackZ = bestZ - dirZ * offset
            if self:isPositionWithinMissionField(mission, insideBackX, insideBackZ) then
                bestX = insideBackX
                bestZ = insideBackZ
                usedForwardInset = true
            else
                local insideForwardX = bestX + dirX * offset
                local insideForwardZ = bestZ + dirZ * offset
                if self:isPositionWithinMissionField(mission, insideForwardX, insideForwardZ) then
                    bestX = insideForwardX
                    bestZ = insideForwardZ
                    usedForwardInset = true
                end
            end
        end

        if not usedForwardInset and type(cx) == "number" and type(cz) == "number" then
            local toCenterX = cx - bestX
            local toCenterZ = cz - bestZ
            local len = MathUtil.vector2Length(toCenterX, toCenterZ)
            if len > 0.001 then
                bestX = bestX + (toCenterX / len) * offset
                bestZ = bestZ + (toCenterZ / len) * offset
            end
        end
    end

    if type(cx) == "number" and type(cz) == "number" and not self:isPositionWithinMissionField(mission, bestX, bestZ) then
        local dirX = cx - bestX
        local dirZ = cz - bestZ
        local len = MathUtil.vector2Length(dirX, dirZ)
        if len > 0.001 then
            local stepX = dirX / len
            local stepZ = dirZ / len
            local fallbackX = bestX
            local fallbackZ = bestZ
            for i = 1, 12 do
                fallbackX = fallbackX + stepX
                fallbackZ = fallbackZ + stepZ
                if self:isPositionWithinMissionField(mission, fallbackX, fallbackZ) then
                    bestX = fallbackX
                    bestZ = fallbackZ
                    break
                end
            end
        end
    end

    return bestX, bestZ, "OK_" .. tostring(startMode)
end

function NeighborFieldWorkers:getMissionSpawnDirection(mission)
    if mission ~= nil and mission.field ~= nil and mission.field.rootNode ~= nil then
        local dirX, _, dirZ = localDirectionToWorld(mission.field.rootNode, 0, 0, 1)
        local len = MathUtil.vector2Length(dirX, dirZ)
        if len > 0.001 then
            return dirX / len, dirZ / len
        end
    end

    return 0, 1
end

function NeighborFieldWorkers:getFieldDataDebugAtWorldPos(x, z)
    if type(x) ~= "number" or type(z) ~= "number" then
        return "n/a"
    end

    local parts = {
        string.format("x=%.1f z=%.1f", x, z)
    }

    if type(FSDensityMapUtil) == "table" then
        if type(FSDensityMapUtil.getFieldTypeAtWorldPos) == "function" then
            local okFieldType, fieldType = pcall(FSDensityMapUtil.getFieldTypeAtWorldPos, x, z)
            if okFieldType then
                table.insert(parts, string.format("fieldType=%s", tostring(fieldType)))
            else
                table.insert(parts, string.format("fieldTypeErr=%s", nfwToSingleLineText(fieldType, 120)))
            end
        end

        if type(FSDensityMapUtil.getFieldDataAtWorldPosition) == "function" then
            local y = 0
            if g_terrainNode ~= nil then
                y = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)
            end
            local okFieldData, a, b, c, d, e, f = pcall(FSDensityMapUtil.getFieldDataAtWorldPosition, x, y, z)
            if okFieldData then
                table.insert(parts,
                    string.format("fieldData=%s|%s|%s|%s|%s|%s", tostring(a), tostring(b), tostring(c), tostring(d),
                        tostring(e), tostring(f)))
            else
                table.insert(parts, string.format("fieldDataErr=%s", nfwToSingleLineText(a, 120)))
            end
        end
    end

    if g_farmlandManager ~= nil and type(g_farmlandManager.getFarmlandIdAtWorldPosition) == "function" then
        local okFarmland, farmlandId = pcall(g_farmlandManager.getFarmlandIdAtWorldPosition, g_farmlandManager, x, z)
        if okFarmland then
            table.insert(parts, string.format("farmland=%s", tostring(farmlandId)))
        else
            table.insert(parts, string.format("farmlandErr=%s", nfwToSingleLineText(farmlandId, 120)))
        end
    end

    if g_missionManager ~= nil and type(g_missionManager.getMissionAtWorldPosition) == "function" then
        local okMissionAtPos, foundMission = pcall(g_missionManager.getMissionAtWorldPosition, g_missionManager, x, z)
        if okMissionAtPos and foundMission ~= nil then
            table.insert(parts, string.format("missionAtPos=%s", tostring(self:getMissionKey(foundMission))))
        elseif not okMissionAtPos then
            table.insert(parts, string.format("missionAtPosErr=%s", nfwToSingleLineText(foundMission, 120)))
        end
    end

    return table.concat(parts, " ")
end

function NeighborFieldWorkers:getAIMessageNameByInstance(aiMessage)
    if aiMessage == nil then
        return "nil"
    end

    if g_currentMission ~= nil and g_currentMission.aiMessageManager ~= nil then
        local manager = g_currentMission.aiMessageManager
        if manager.getMessageIndex ~= nil and manager.messages ~= nil then
            local okIdx, idx = pcall(manager.getMessageIndex, manager, aiMessage)
            if okIdx and type(idx) == "number" and manager.messages[idx] ~= nil and manager.messages[idx].name ~= nil then
                return tostring(manager.messages[idx].name)
            end
        end
    end

    if aiMessage.getType ~= nil then
        local okType, aiType = pcall(aiMessage.getType, aiMessage)
        if okType and aiType ~= nil then
            return string.format("TYPE_%s", tostring(aiType))
        end
    end

    return tostring(aiMessage)
end

function NeighborFieldWorkers:getStopTraceSourceHint(stopTrace)
    if type(stopTrace) ~= "string" or stopTrace == "" then
        return "trace=none"
    end

    local traceLower = string.lower(stopTrace)
    local knownHints = {
        { "aidrivestrategyfieldcourse.lua:204", "fieldCourse:noValidSegment(ERROR_FIELD_NOT_READY)" },
        { "aidrivestrategyfieldcourse.lua:211", "fieldCourse:noFieldBoundary(ERROR_NO_FIELD_FOUND)" },
        { "aidrivestrategyfieldcourse.lua:399", "fieldCourse:startDetectionFailed(ERROR_NO_FIELD_FOUND)" },
        { "fertilizingsowingmachine.lua:78",    "fertSow:waterRequired(ERROR_NO_FIELD_FOUND)" },
        { "fertilizingsowingmachine.lua:87",    "fertSow:waterProhibited(ERROR_NO_FIELD_FOUND)" },
        { "fertilizingsowingmachine.lua:160",   "fertSow:fieldTypeMismatch(ERROR_NO_FIELD_FOUND)" },
        { "sowingmachine.lua:482",              "sowing:waterRequired(ERROR_NO_FIELD_FOUND)" },
        { "sowingmachine.lua:491",              "sowing:waterProhibited(ERROR_NO_FIELD_FOUND)" },
        { "sowingmachine.lua:536",              "sowing:fieldTypeMismatch(ERROR_NO_FIELD_FOUND)" }
    }

    for _, hint in ipairs(knownHints) do
        if string.find(traceLower, hint[1], 1, true) ~= nil then
            return hint[2]
        end
    end

    local firstLuaFrame = string.match(stopTrace, "([%w%._%-%/%\\]+%.lua:%d+)")
    if firstLuaFrame ~= nil then
        return string.format("traceTop=%s", firstLuaFrame)
    end

    return "trace=unmapped"
end

function NeighborFieldWorkers:getVehicleContinueWorkDebug(vehicle)
    if vehicle == nil then
        return "vehicle=nil"
    end

    if vehicle.getCanAIFieldWorkerContinueWork == nil then
        return "vehicle.getCanAIFieldWorkerContinueWork=nil"
    end

    local okCheck, canContinue, stopAI, stopReason = pcall(vehicle.getCanAIFieldWorkerContinueWork, vehicle, false)
    if not okCheck then
        return string.format("continueCheckErr=%s", nfwToSingleLineText(canContinue, 180))
    end

    local stopReasonName = self:getAIMessageNameByInstance(stopReason)
    return string.format(
        "canContinue=%s stopAI=%s stopReason=%s",
        tostring(canContinue),
        tostring(stopAI),
        tostring(stopReasonName)
    )
end

function NeighborFieldWorkers:getVehicleHarvestHookDebug(vehicle, now)
    if vehicle == nil then
        return "hooks=vehicle=nil"
    end

    local canStartAge = "n/a"
    if type(vehicle.nfwDiagLastCanStartAtMs) == "number" and vehicle.nfwDiagLastCanStartAtMs > 0 then
        canStartAge = tostring(math.max(0, now - vehicle.nfwDiagLastCanStartAtMs))
    end

    local continueAge = "n/a"
    if type(vehicle.nfwDiagLastContinueAtMs) == "number" and vehicle.nfwDiagLastContinueAtMs > 0 then
        continueAge = tostring(math.max(0, now - vehicle.nfwDiagLastContinueAtMs))
    end

    local stopReasonName = self:getAIMessageNameByInstance(vehicle.nfwDiagLastContinueStopReason)
    return string.format(
        "hooked=%s canStart={last=%s ageMs=%s calls=%s false=%s} continue={last=%s turning=%s stopAI=%s stopReason=%s ageMs=%s calls=%s false=%s}",
        tostring(vehicle.nfwHarvestDiagHooksInstalled == true),
        tostring(vehicle.nfwDiagLastCanStartResult),
        tostring(canStartAge),
        tostring(Utils.getNoNil(vehicle.nfwDiagCanStartCallCount, 0)),
        tostring(Utils.getNoNil(vehicle.nfwDiagCanStartFalseCount, 0)),
        tostring(vehicle.nfwDiagLastContinueResult),
        tostring(vehicle.nfwDiagLastContinueTurning),
        tostring(vehicle.nfwDiagLastContinueStopAI),
        tostring(stopReasonName),
        tostring(continueAge),
        tostring(Utils.getNoNil(vehicle.nfwDiagContinueCallCount, 0)),
        tostring(Utils.getNoNil(vehicle.nfwDiagContinueFalseCount, 0))
    )
end

function NeighborFieldWorkers:getAIDriveStrategiesDebug(vehicle)
    if vehicle == nil or vehicle.spec_aiFieldWorker == nil or type(vehicle.spec_aiFieldWorker.driveStrategies) ~= "table" then
        return "strategies=n/a"
    end

    local parts = {}
    for i, strategy in ipairs(vehicle.spec_aiFieldWorker.driveStrategies) do
        local className = type(ClassUtil) == "table"
            and type(ClassUtil.getClassNameByObject) == "function"
            and ClassUtil.getClassNameByObject(strategy)
            or nil
        table.insert(
            parts,
            string.format(
                "%d:%s{blocked=%s lastCont=%s detect=%s hasCourse=%s}",
                i,
                tostring(className or strategy),
                tostring(strategy ~= nil and strategy.isBlocked or nil),
                tostring(strategy ~= nil and strategy.lastContinueWorkState or nil),
                tostring(strategy ~= nil and strategy.fieldDetectionInProgress or nil),
                tostring(strategy ~= nil and strategy.aiFieldCourse ~= nil)
            )
        )
    end

    return table.concat(parts, " || ")
end

function NeighborFieldWorkers:getHarvestPipeAndDischargeDebug(vehicle)
    if vehicle == nil then
        return "pipe=vehicle=nil"
    end

    local dischargeNode = vehicle.getCurrentDischargeNode ~= nil and vehicle:getCurrentDischargeNode() or nil
    local dischargeFillUnit = dischargeNode ~= nil and dischargeNode.fillUnitIndex or nil
    local canDischargeToObject = "n/a"
    if dischargeNode ~= nil and vehicle.getCanDischargeToObject ~= nil then
        local okCan, value = pcall(vehicle.getCanDischargeToObject, vehicle, dischargeNode)
        canDischargeToObject = okCan and tostring(value) or ("err:" .. nfwToSingleLineText(value, 120))
    end

    local targetObjectName = "n/a"
    if dischargeNode ~= nil and vehicle.getDischargeTargetObject ~= nil then
        local okTarget, targetObject = pcall(vehicle.getDischargeTargetObject, vehicle, dischargeNode)
        if okTarget and targetObject ~= nil then
            targetObjectName = tostring(targetObject.getName ~= nil and targetObject:getName() or targetObject)
        elseif not okTarget then
            targetObjectName = "err:" .. nfwToSingleLineText(targetObject, 120)
        end
    end

    local pipeDebug = "pipe=n/a"
    if vehicle.spec_pipe ~= nil then
        local pipeSpec = vehicle.spec_pipe
        local trailer = nil
        if pipeSpec.nearestObjectInTriggers ~= nil and NetworkUtil ~= nil and NetworkUtil.getObject ~= nil then
            trailer = NetworkUtil.getObject(pipeSpec.nearestObjectInTriggers.objectId)
        end

        local states = {}
        if type(pipeSpec.turnOnAllowedStates) == "table" then
            for state, enabled in pairs(pipeSpec.turnOnAllowedStates) do
                table.insert(states, string.format("%s=%s", tostring(state), tostring(enabled)))
            end
            table.sort(states)
        end

        pipeDebug = string.format(
            "pipe={state=%s target=%s nearest=%s ignoreFill=%s unloadToTrailer=%s allowedStates=[%s]}",
            tostring(pipeSpec.currentState),
            tostring(pipeSpec.targetState),
            tostring(trailer ~= nil and (trailer.getName ~= nil and trailer:getName() or trailer) or "nil"),
            tostring(pipeSpec.nearestObjectInTriggerIgnoreFillLevel),
            tostring(pipeSpec.unloadingToTrailer),
            table.concat(states, ",")
        )
    end

    return string.format(
        "%s discharge={fillUnit=%s canToObject=%s target=%s}",
        pipeDebug,
        tostring(dischargeFillUnit),
        tostring(canDischargeToObject),
        tostring(targetObjectName)
    )
end

function NeighborFieldWorkers:logHarvestBlockedDeepDiagnostics(assignment, vehicle, mission, now, speed)
    if assignment == nil or vehicle == nil or mission == nil or vehicle.rootNode == nil then
        return
    end

    local missionKey = tostring(assignment.key)
    local vehicleName = tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown")
    local canStartNow = vehicle.getCanStartFieldWork ~= nil and vehicle:getCanStartFieldWork() or nil

    local continueFalse = "n/a"
    local continueTrue = "n/a"
    if vehicle.getCanAIFieldWorkerContinueWork ~= nil then
        local okF, cF, sF, rF = pcall(vehicle.getCanAIFieldWorkerContinueWork, vehicle, false)
        local okT, cT, sT, rT = pcall(vehicle.getCanAIFieldWorkerContinueWork, vehicle, true)
        continueFalse = okF and
            string.format("can=%s stop=%s reason=%s", tostring(cF), tostring(sF), self:getAIMessageNameByInstance(rF))
            or ("err=" .. nfwToSingleLineText(cF, 120))
        continueTrue = okT and
            string.format("can=%s stop=%s reason=%s", tostring(cT), tostring(sT), self:getAIMessageNameByInstance(rT))
            or ("err=" .. nfwToSingleLineText(cT, 120))
    end

    local x, _, z = getWorldTranslation(vehicle.rootNode)
    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    local fieldDistance = "n/a"
    if type(fieldX) == "number" and type(fieldZ) == "number" then
        fieldDistance = string.format("%.1f", MathUtil.vector2Length(x - fieldX, z - fieldZ))
    end

    nfwLogHelperDiag(
        "[%s] HelperDiag HARVEST_BLOCKED_DEEP: mission=%s vehicle=%s speed=%.2f canStartNow=%s continueFalse={%s} continueTrue={%s} runtime={%s} hooks={%s} pipe={%s} fieldDist=%s strategies={%s}",
        self.MOD_NAME,
        missionKey,
        vehicleName,
        speed,
        tostring(canStartNow),
        continueFalse,
        continueTrue,
        self:getHarvestVehicleRuntimeDebug(vehicle),
        self:getVehicleHarvestHookDebug(vehicle, now),
        self:getHarvestPipeAndDischargeDebug(vehicle),
        fieldDistance,
        nfwToSingleLineText(self:getAIDriveStrategiesDebug(vehicle), 900)
    )

    local aiImplements = nil
    if vehicle.getAttachedAIImplements ~= nil then
        local okImpl, impls = pcall(vehicle.getAttachedAIImplements, vehicle)
        if okImpl and type(impls) == "table" then
            aiImplements = impls
        end
    end

    if aiImplements == nil then
        nfwLogHelperDiag(
            "[%s] HelperDiag HARVEST_BLOCKED_DEEP_IMPL: mission=%s vehicle=%s aiImplements=nil",
            self.MOD_NAME,
            missionKey,
            vehicleName
        )
        return
    end

    for index, aiImplement in ipairs(aiImplements) do
        local implObject = aiImplement ~= nil and aiImplement.object or nil
        if implObject ~= nil then
            local implName = tostring(implObject.getName ~= nil and implObject:getName() or ("impl_" .. tostring(index)))
            local canStart = implObject.getCanStartFieldWork ~= nil and implObject:getCanStartFieldWork() or nil
            local contFalse = "n/a"
            local contTrue = "n/a"
            if implObject.getCanAIImplementContinueWork ~= nil then
                local okF, cF, sF, rF = pcall(implObject.getCanAIImplementContinueWork, implObject, false)
                local okT, cT, sT, rT = pcall(implObject.getCanAIImplementContinueWork, implObject, true)
                contFalse = okF and
                    string.format("can=%s stop=%s reason=%s", tostring(cF), tostring(sF),
                        self:getAIMessageNameByInstance(rF))
                    or ("err=" .. nfwToSingleLineText(cF, 120))
                contTrue = okT and
                    string.format("can=%s stop=%s reason=%s", tostring(cT), tostring(sT),
                        self:getAIMessageNameByInstance(rT))
                    or ("err=" .. nfwToSingleLineText(cT, 120))
            end

            nfwLogHelperDiag(
                "[%s] HelperDiag HARVEST_BLOCKED_DEEP_IMPL: mission=%s idx=%d impl=%s canStart=%s contFalse={%s} contTrue={%s} probeVehicle={%s} probeField={%s}",
                self.MOD_NAME,
                missionKey,
                index,
                implName,
                tostring(canStart),
                contFalse,
                contTrue,
                self:getImplementAIAreaProbe(implObject, x, z, 8),
                self:getImplementAIAreaProbe(implObject, fieldX, fieldZ, 10)
            )
        end
    end
end

function NeighborFieldWorkers:getImplementAIAreaMetrics(implementObject, centerX, centerZ, halfSize)
    if implementObject == nil or type(centerX) ~= "number" or type(centerZ) ~= "number" then
        return {
            ok = false,
            error = "n/a"
        }
    end
    if type(AIVehicleUtil) ~= "table" or type(AIVehicleUtil.getAIAreaOfVehicle) ~= "function" then
        return {
            ok = false,
            error = "AIVehicleUtil=nil"
        }
    end

    local size = halfSize or 8
    local startX = centerX - size
    local startZ = centerZ - size
    local widthX = centerX + size
    local widthZ = centerZ - size
    local heightX = centerX - size
    local heightZ = centerZ + size

    local okArea, area, totalArea = pcall(
        AIVehicleUtil.getAIAreaOfVehicle,
        implementObject,
        startX,
        startZ,
        widthX,
        widthZ,
        heightX,
        heightZ
    )

    if not okArea then
        return {
            ok = false,
            error = nfwToSingleLineText(area, 180)
        }
    end

    local areaValue = type(area) == "number" and area or 0
    local totalValue = type(totalArea) == "number" and totalArea or 0
    local ratio = totalValue > 0 and (areaValue / totalValue) or 0
    return {
        ok = true,
        area = areaValue,
        total = totalValue,
        ratio = ratio
    }
end

function NeighborFieldWorkers:getImplementAIAreaProbe(implementObject, centerX, centerZ, halfSize)
    local metrics = self:getImplementAIAreaMetrics(implementObject, centerX, centerZ, halfSize)
    if metrics == nil or metrics.ok ~= true then
        return string.format("err=%s", nfwToSingleLineText(metrics ~= nil and metrics.error or "n/a", 180))
    end

    return string.format("area=%.2f total=%.2f ratio=%.4f", metrics.area, metrics.total, metrics.ratio)
end

function NeighborFieldWorkers:getImplementRequirementDebug(implementObject)
    if implementObject == nil then
        return "impl=nil"
    end

    local reqFruit = {}
    if implementObject.getAIFruitRequirements ~= nil then
        local okReq, values = pcall(implementObject.getAIFruitRequirements, implementObject)
        if okReq and type(values) == "table" then
            reqFruit = values
        end
    end

    local banFruit = {}
    if implementObject.getAIFruitProhibitions ~= nil then
        local okBan, values = pcall(implementObject.getAIFruitProhibitions, implementObject)
        if okBan and type(values) == "table" then
            banFruit = values
        end
    end

    local reqGround = {}
    if implementObject.getAITerrainDetailRequiredRange ~= nil then
        local okReq, values = pcall(implementObject.getAITerrainDetailRequiredRange, implementObject)
        if okReq and type(values) == "table" then
            reqGround = values
        end
    end

    local banGround = {}
    if implementObject.getAITerrainDetailProhibitedRange ~= nil then
        local okBan, values = pcall(implementObject.getAITerrainDetailProhibitedRange, implementObject)
        if okBan and type(values) == "table" then
            banGround = values
        end
    end

    return string.format(
        "fruitReq=%d(%s) fruitBan=%d(%s) groundReq=%d(%s) groundBan=%d(%s)",
        #reqFruit,
        nfwFormatAiRangeList(reqFruit, 2),
        #banFruit,
        nfwFormatAiRangeList(banFruit, 2),
        #reqGround,
        nfwFormatAiRangeList(reqGround, 2),
        #banGround,
        nfwFormatAiRangeList(banGround, 2)
    )
end

function NeighborFieldWorkers:logStopRootCauseDiagnostics(assignment, job, messageName, stopTrace)
    if assignment == nil or assignment.mission == nil or assignment.vehicle == nil then
        return
    end
    local isSowUnknown = messageName == "ERROR_UNKNOWN" and self:isSowMission(assignment.mission)
    if messageName ~= "ERROR_NO_FIELD_FOUND" and messageName ~= "ERROR_FIELD_NOT_READY" and not isSowUnknown then
        return
    end

    local now = g_time or 0
    local nextAllowed = Utils.getNoNil(assignment.nextStopRootCauseDiagAtMs, 0)
    if now < nextAllowed then
        return
    end
    assignment.nextStopRootCauseDiagAtMs = now + 2000

    local vehicle = assignment.vehicle
    if vehicle.rootNode == nil then
        return
    end
    local mission = assignment.mission
    local missionKey = tostring(assignment.key)
    local vehicleName = tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown")

    local vx, _, vz = getWorldTranslation(vehicle.rootNode)
    local fx, fz = self:getMissionFieldPosition(mission)
    if type(fx) ~= "number" or type(fz) ~= "number" then
        fx = vx
        fz = vz
    end

    local traceHint = self:getStopTraceSourceHint(stopTrace)
    local continueDiag = self:getVehicleContinueWorkDebug(vehicle)
    local taskIndex = job ~= nil and tonumber(job.currentTaskIndex) or nil
    local strategies = self:getAIDriveStrategiesDebug(vehicle)

    nfwLogHelperDiag(
        "[%s] HelperDiag STOP_ROOT_CAUSE: mission=%s msg=%s task=%s traceHint=%s continue={%s} strategies={%s} vehiclePos={%s} fieldPos={%s}",
        self.MOD_NAME,
        missionKey,
        tostring(messageName),
        tostring(taskIndex),
        tostring(traceHint),
        continueDiag,
        nfwToSingleLineText(strategies, 360),
        self:getFieldDataDebugAtWorldPos(vx, vz),
        self:getFieldDataDebugAtWorldPos(fx, fz)
    )

    local aiImplements = nil
    if vehicle.getAttachedAIImplements ~= nil then
        local okImplements, implements = pcall(vehicle.getAttachedAIImplements, vehicle)
        if okImplements and type(implements) == "table" then
            aiImplements = implements
        end
    end

    if aiImplements == nil then
        nfwLogHelperDiag(
            "[%s] HelperDiag STOP_IMPL_DIAG: mission=%s vehicle=%s aiImplements=nil",
            self.MOD_NAME,
            missionKey,
            vehicleName
        )
        return
    end

    for index, aiImplement in ipairs(aiImplements) do
        local obj = aiImplement ~= nil and aiImplement.object or nil
        if obj ~= nil then
            local objName = tostring(obj.getName ~= nil and obj:getName() or ("impl_" .. tostring(index)))
            local canContinue = "n/a"
            local stopAI = "n/a"
            local stopReasonName = "nil"
            if obj.getCanAIImplementContinueWork ~= nil then
                local okCheck, c, s, r = pcall(obj.getCanAIImplementContinueWork, obj, false)
                if okCheck then
                    canContinue = tostring(c)
                    stopAI = tostring(s)
                    stopReasonName = self:getAIMessageNameByInstance(r)
                else
                    canContinue = "err"
                    stopAI = "err"
                    stopReasonName = nfwToSingleLineText(c, 140)
                end
            end

            local markersText = "markers=n/a"
            if obj.getAIMarkers ~= nil then
                local okMarkers, leftMarker, rightMarker, backMarker = pcall(obj.getAIMarkers, obj)
                if okMarkers then
                    markersText = string.format(
                        "markers={left=%s right=%s back=%s}",
                        tostring(leftMarker ~= nil),
                        tostring(rightMarker ~= nil),
                        tostring(backMarker ~= nil)
                    )
                else
                    markersText = string.format("markersErr=%s", nfwToSingleLineText(leftMarker, 120))
                end
            end

            local vehicleProbe = self:getImplementAIAreaProbe(obj, vx, vz, 8)
            local fieldProbe = self:getImplementAIAreaProbe(obj, fx, fz, 10)
            local reqDiag = self:getImplementRequirementDebug(obj)

            nfwLogHelperDiag(
                "[%s] HelperDiag STOP_IMPL_DIAG: mission=%s idx=%d impl=%s canContinue=%s stopAI=%s stopReason=%s %s probeVehicle={%s} probeField={%s} req={%s}",
                self.MOD_NAME,
                missionKey,
                index,
                objName,
                canContinue,
                stopAI,
                stopReasonName,
                markersText,
                vehicleProbe,
                fieldProbe,
                reqDiag
            )
        end
    end
end

function NeighborFieldWorkers:shouldAutoCompleteAssignmentAfterStop(assignment, messageName)
    if assignment == nil or assignment.mission == nil or assignment.vehicle == nil then
        return false, nil
    end

    if messageName == "SUCCESS_FINISHED_JOB" then
        if self:isSowMission(assignment.mission) then
            local completionPercent = self:getMissionCompletionPercent(assignment.mission)
            if completionPercent < 98 then
                nfwLogHelperDiag(
                    "[%s] HelperDiag JOB_STOP_AUTOCOMPLETE_SKIPPED: mission=%s msgName=%s reason=SOW_LOW_PROGRESS progress=%d%%",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    tostring(messageName),
                    completionPercent
                )
                return false, nil
            end
        end
        return true, "SUCCESS_FINISHED_JOB"
    end

    if messageName == "ERROR_FIELD_NOT_READY" then
        if self:isSowMission(assignment.mission) then
            nfwLogHelperDiag(
                "[%s] HelperDiag JOB_STOP_AUTOCOMPLETE_SKIPPED: mission=%s msgName=%s reason=SOW_RECOVERY_INSTEAD",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(messageName)
            )
            return false, nil
        end
        return true, "FIELD_NOT_READY"
    end

    if messageName ~= "ERROR_NO_FIELD_FOUND" then
        return false, nil
    end

    if not self:isPreparationSensitiveMissionType(assignment.mission) then
        return false, nil
    end

    if self:isSowMission(assignment.mission) then
        nfwLogHelperDiag(
            "[%s] HelperDiag JOB_STOP_AUTOCOMPLETE_SKIPPED: mission=%s msgName=%s reason=SOW_RECOVERY_INSTEAD",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(messageName)
        )
        return false, nil
    end

    local fieldX, fieldZ = self:getMissionFieldPosition(assignment.mission)
    if type(fieldX) ~= "number" or type(fieldZ) ~= "number" then
        return false, nil
    end

    local vehicle = assignment.vehicle
    local aiImplements = nil
    if vehicle.getAttachedAIImplements ~= nil then
        local okImplements, implements = pcall(vehicle.getAttachedAIImplements, vehicle)
        if okImplements and type(implements) == "table" then
            aiImplements = implements
        end
    end
    if aiImplements == nil or #aiImplements == 0 then
        return false, nil
    end

    local hasStrongWorkAreaAtField = false
    for _, aiImplement in ipairs(aiImplements) do
        local obj = aiImplement ~= nil and aiImplement.object or nil
        if obj ~= nil then
            local metrics = self:getImplementAIAreaMetrics(obj, fieldX, fieldZ, 10)
            if metrics ~= nil and metrics.ok and metrics.total > 0 and metrics.ratio >= 0.20 then
                hasStrongWorkAreaAtField = true
                break
            end
        end
    end

    if hasStrongWorkAreaAtField then
        return true, "NO_FIELD_FOUND_PREP_MISMATCH"
    end

    return false, nil
end

function NeighborFieldWorkers:isPreparationSensitiveMissionType(mission)
    local missionTypeLower = string.lower(self:getMissionTypeName(mission))
    return string.find(missionTypeLower, "fertiliz", 1, true) ~= nil
        or string.find(missionTypeLower, "spray", 1, true) ~= nil
        or string.find(missionTypeLower, "herbicid", 1, true) ~= nil
        or string.find(missionTypeLower, "sow", 1, true) ~= nil
        or string.find(missionTypeLower, "seed", 1, true) ~= nil
end

function NeighborFieldWorkers:shouldAutoCompleteStartBlockedAssignment(assignment, vehicle, blockedForMs)
    if assignment == nil or assignment.mission == nil or vehicle == nil then
        return false, nil
    end
    if blockedForMs == nil or blockedForMs < 20000 then
        return false, nil
    end
    if not self:isPreparationSensitiveMissionType(assignment.mission) then
        return false, nil
    end

    local fieldX, fieldZ = self:getMissionFieldPosition(assignment.mission)
    if type(fieldX) ~= "number" or type(fieldZ) ~= "number" then
        return false, nil
    end

    local aiImplements = nil
    if vehicle.getAttachedAIImplements ~= nil then
        local okImplements, implements = pcall(vehicle.getAttachedAIImplements, vehicle)
        if okImplements and type(implements) == "table" then
            aiImplements = implements
        end
    end
    if aiImplements == nil or #aiImplements == 0 then
        return false, nil
    end

    for _, aiImplement in ipairs(aiImplements) do
        local obj = aiImplement ~= nil and aiImplement.object or nil
        if obj ~= nil then
            local metrics = self:getImplementAIAreaMetrics(obj, fieldX, fieldZ, 10)
            if metrics ~= nil and metrics.ok and metrics.total > 0 and metrics.ratio >= 0.20 then
                return true, "START_BLOCKED_PREP_MISMATCH"
            end
        end
    end

    return false, nil
end

function NeighborFieldWorkers:queueAssignmentAutoCompletion(assignment, reason)
    if assignment == nil or assignment.mission == nil then
        return false
    end

    assignment.autoCompleteRequested = true
    assignment.autoCompleteReason = tostring(reason or "AUTO")
    assignment.forceDirectStart = false
    assignment.forceRecoveryReposition = false
    assignment.forceRecoveryReason = nil
    assignment.suppressRelocateDuringSprayerAttach = false
    assignment.noFieldRetryIndex = 0

    nfwLogInfo(
        "[%s] Auftrag zum Auto-Abschluss markiert: mission=%s reason=%s",
        self.MOD_NAME,
        tostring(assignment.key),
        tostring(assignment.autoCompleteReason)
    )
    return true
end

function NeighborFieldWorkers:getVehicleAiCapabilityDebug(vehicle)
    if vehicle == nil then
        return "vehicle=nil"
    end

    local summaries = {}
    local seen = {}

    local function appendObject(obj, role)
        if obj == nil or seen[obj] then
            return
        end
        seen[obj] = true

        local name = tostring(obj.getName ~= nil and obj:getName() or role or "unknown")
        local flags = {}
        local canStart = obj.getCanStartFieldWork ~= nil and obj:getCanStartFieldWork() or nil
        table.insert(flags, string.format("canStart=%s", tostring(canStart)))

        if obj.spec_sprayer ~= nil then
            table.insert(flags, "sprayer")
            local sprayFillType = obj.spec_sprayer.workAreaParameters ~= nil and
                obj.spec_sprayer.workAreaParameters.sprayFillType or nil
            table.insert(flags, string.format("sprayFill=%s", tostring(sprayFillType)))
            table.insert(flags, string.format("sprayFillName=%s", self:getDebugFillTypeName(sprayFillType)))
        end
        if obj.spec_sowingMachine ~= nil then
            table.insert(flags, "sowing")
            local seedType = obj.spec_sowingMachine.workAreaParameters ~= nil and
                obj.spec_sowingMachine.workAreaParameters.seedsFruitType or nil
            local seedName = nil
            if seedType ~= nil and g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypeByIndex ~= nil then
                local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(seedType)
                if fruitDesc ~= nil and fruitDesc.name ~= nil then
                    seedName = fruitDesc.name
                end
            end
            table.insert(flags, string.format("seed=%s", seedName ~= nil and tostring(seedName) or tostring(seedType)))
        end
        if obj.spec_fertilizingSowingMachine ~= nil then
            table.insert(flags, "fertSow")
        end
        if obj.spec_fertilizingCultivator ~= nil then
            table.insert(flags, "fertCult")
        end
        if obj.spec_fertilizingCultivatorRoller ~= nil then
            table.insert(flags, "fertCultRoller")
        end
        if obj.spec_spreader ~= nil then
            table.insert(flags, "spreader")
        end
        if obj.spec_sprayer ~= nil and obj.spec_sprayer.isFertilizerSprayer then
            table.insert(flags, "fertSprayer")
        end

        table.insert(summaries, string.format("%s{%s}", nfwToSingleLineText(name, 64), table.concat(flags, ",")))
    end

    appendObject(vehicle, "vehicle")
    if vehicle.getAttachedImplements ~= nil then
        local attached = vehicle:getAttachedImplements()
        if attached ~= nil then
            for _, impl in ipairs(attached) do
                if impl ~= nil and impl.object ~= nil then
                    appendObject(impl.object, "implement")
                end
            end
        end
    end

    return table.concat(summaries, " || ")
end

function NeighborFieldWorkers:getEnvironmentPeriodDebug()
    local environment = g_currentMission ~= nil and g_currentMission.environment or nil
    if environment == nil then
        return "env=nil"
    end

    return string.format(
        "env{day=%s monoDay=%s period=%s season=%s}",
        tostring(environment.currentDay),
        tostring(environment.currentMonotonicDay),
        tostring(environment.currentPeriod),
        tostring(environment.currentSeason)
    )
end

function NeighborFieldWorkers:getSowMissionRuntimeDebug(assignment, vehicle, fieldX, fieldZ)
    local mission = assignment ~= nil and assignment.mission or nil
    local missionFruitType = self:getMissionSowFruitType(mission)
    local missionFillType = self:getMissionSowFillType(mission, missionFruitType)

    local parts = {}
    table.insert(
        parts,
        string.format(
            "target{fruit=%s fill=%s}",
            self:getDebugFruitTypeName(missionFruitType),
            self:getDebugFillTypeName(missionFillType)
        )
    )
    table.insert(parts, self:getEnvironmentPeriodDebug())
    table.insert(parts, string.format("continue={%s}", self:getVehicleContinueWorkDebug(vehicle)))
    local taskIndex = assignment ~= nil and assignment.giantsJob ~= nil and tonumber(assignment.giantsJob.currentTaskIndex) or nil
    table.insert(
        parts,
        string.format(
            "job{task=%s aiStarted=%s edgeUsed=%s edgeDisabled=%s direct=%s}",
            tostring(taskIndex),
            tostring(assignment ~= nil and assignment.aiStarted == true),
            tostring(assignment ~= nil and assignment.lastStartUsedEdge == true),
            tostring(assignment ~= nil and assignment.disableEdgeStartForMission == true),
            tostring(assignment ~= nil and assignment.forceDirectStart == true)
        )
    )
    table.insert(parts, string.format("strategies={%s}", nfwToSingleLineText(self:getAIDriveStrategiesDebug(vehicle), 380)))

    local aiImplementObjects = {}
    local aiImplementNames = {}
    if vehicle ~= nil and vehicle.getAttachedAIImplements ~= nil then
        local okAttached, attachedAIImplements = pcall(vehicle.getAttachedAIImplements, vehicle)
        if okAttached and type(attachedAIImplements) == "table" then
            for i, aiImplement in ipairs(attachedAIImplements) do
                local implObject = aiImplement ~= nil and aiImplement.object or nil
                if implObject ~= nil then
                    aiImplementObjects[implObject] = true
                    local implName = tostring(implObject.getName ~= nil and implObject:getName() or ("impl_" .. tostring(i)))
                    table.insert(aiImplementNames, nfwToSingleLineText(implName, 34))
                end
            end
        end
    end
    if #aiImplementNames > 0 then
        table.insert(parts, "aiList={" .. table.concat(aiImplementNames, ",") .. "}")
    else
        table.insert(parts, "aiList=none")
    end

    local bestFieldProbe = "n/a"
    local bestRatio = -1
    if type(fieldX) == "number" and type(fieldZ) == "number" and vehicle ~= nil and vehicle.getAttachedAIImplements ~= nil then
        local okImplements, aiImplements = pcall(vehicle.getAttachedAIImplements, vehicle)
        if okImplements and type(aiImplements) == "table" then
            for _, aiImplement in ipairs(aiImplements) do
                local implementObject = aiImplement ~= nil and aiImplement.object or nil
                if implementObject ~= nil then
                    local metrics = self:getImplementAIAreaMetrics(implementObject, fieldX, fieldZ, 10)
                    if metrics ~= nil and metrics.ok and metrics.ratio > bestRatio then
                        bestRatio = metrics.ratio
                        local implementName = tostring(implementObject.getName ~= nil and implementObject:getName() or
                            implementObject)
                        bestFieldProbe = string.format(
                            "%s{area=%.2f total=%.2f ratio=%.4f}",
                            nfwToSingleLineText(implementName, 40),
                            metrics.area,
                            metrics.total,
                            metrics.ratio
                        )
                    end
                end
            end
        end
    end
    table.insert(parts, "fieldProbe=" .. bestFieldProbe)

    local sowObjects = {}
    local seen = {}
    local traversedAttachObjects = {}
    local function appendSowObject(obj)
        if obj == nil or seen[obj] then
            return
        end
        seen[obj] = true
        if obj.spec_sowingMachine == nil then
            return
        end

        local spec = obj.spec_sowingMachine
        local currentSeedFruit = (spec.seeds ~= nil and spec.currentSeed ~= nil) and spec.seeds[spec.currentSeed] or nil
        local canStart = obj.getCanStartFieldWork ~= nil and obj:getCanStartFieldWork() or nil
        local turnedOn = obj.getIsTurnedOn ~= nil and obj:getIsTurnedOn() or nil
        local unfolded = obj.getIsUnfolded ~= nil and obj:getIsUnfolded() or nil
        local lowered = obj.getIsLowered ~= nil and obj:getIsLowered(false) or nil
        local params = spec.workAreaParameters
        local canPlant = params ~= nil and params.canFruitBePlanted or nil
        local isActive = params ~= nil and params.isActive or nil
        local changedArea = params ~= nil and params.lastChangedArea or nil
        local statsArea = params ~= nil and params.lastStatsArea or nil
        local rootX, _, rootZ = nil, nil, nil
        if obj.rootNode ~= nil then
            rootX, _, rootZ = getWorldTranslation(obj.rootNode)
        end
        local posText = "n/a"
        local posFieldText = "n/a"
        local selfProbe = "n/a"
        if type(rootX) == "number" and type(rootZ) == "number" then
            posText = string.format("%.1f/%.1f", rootX, rootZ)
            posFieldText = self:getFieldDataDebugAtWorldPos(rootX, rootZ)
            selfProbe = self:getImplementAIAreaProbe(obj, rootX, rootZ, 6)
        end
        local missionProbe = "n/a"
        if type(fieldX) == "number" and type(fieldZ) == "number" then
            missionProbe = self:getImplementAIAreaProbe(obj, fieldX, fieldZ, 10)
        end
        local attacherName = "none"
        if obj.getAttacherVehicle ~= nil then
            local okAttacher, attacherVehicle = pcall(obj.getAttacherVehicle, obj)
            if okAttacher and attacherVehicle ~= nil then
                attacherName = tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or attacherVehicle)
            end
        end
        local markerInfo = "n/a"
        if obj.getAIMarkers ~= nil then
            local okMarkers, leftMarker, rightMarker, backMarker = pcall(obj.getAIMarkers, obj)
            if okMarkers then
                markerInfo = string.format("L%s/R%s/B%s", tostring(leftMarker ~= nil), tostring(rightMarker ~= nil),
                    tostring(backMarker ~= nil))
            else
                markerInfo = "err"
            end
        end
        local reqDiag = self:getImplementRequirementDebug(obj)
        local aiMember = aiImplementObjects[obj] == true
        local canContinue = "n/a"
        local stopAI = "n/a"
        local stopReason = "n/a"
        if obj.getCanAIImplementContinueWork ~= nil then
            local okCont, c, s, r = pcall(obj.getCanAIImplementContinueWork, obj, false)
            if okCont then
                canContinue = tostring(c)
                stopAI = tostring(s)
                stopReason = self:getAIMessageNameByInstance(r)
            else
                canContinue = "err"
                stopAI = "err"
                stopReason = nfwToSingleLineText(c, 120)
            end
        end
        local fillParts = {}
        if obj.getFillUnits ~= nil
            and obj.getFillUnitSupportedFillTypes ~= nil
            and obj.getFillUnitFillLevel ~= nil
            and obj.getFillUnitCapacity ~= nil then
            local fillUnits = obj:getFillUnits()
            if type(fillUnits) == "table" then
                for fillUnitIndex, _ in ipairs(fillUnits) do
                    local supported = obj:getFillUnitSupportedFillTypes(fillUnitIndex)
                    local supportsMissionFill = missionFillType ~= nil and supported ~= nil and
                        supported[missionFillType] == true
                    local supportsSeeds = FillType ~= nil and FillType.SEEDS ~= nil and supported ~= nil and
                        supported[FillType.SEEDS] == true
                    if supportsMissionFill or supportsSeeds then
                        local level = obj:getFillUnitFillLevel(fillUnitIndex) or 0
                        local capacity = obj:getFillUnitCapacity(fillUnitIndex) or 0
                        local fillType = obj.getFillUnitFillType ~= nil and obj:getFillUnitFillType(fillUnitIndex) or
                            FillType.UNKNOWN
                        table.insert(
                            fillParts,
                            string.format(
                                "%d:%s %.1f/%.1f",
                                fillUnitIndex,
                                self:getDebugFillTypeName(fillType),
                                level,
                                capacity
                            )
                        )
                    end
                end
            end
        end

        local objectName = tostring(obj.getName ~= nil and obj:getName() or obj)
        table.insert(
            sowObjects,
            string.format(
                "%s{ai=%s attach=%s pos=%s posField={%s} probeSelf={%s} probeField={%s} markers=%s canStart=%s on=%s unfolded=%s lowered=%s cont=%s stop=%s reason=%s seed=%s canPlant=%s active=%s area=%.2f/%.2f warn={fruit=%s,season=%s,field=%s,rice=%s,waterReq=%s,waterProh=%s} req={%s} fills=[%s]}",
                nfwToSingleLineText(objectName, 40),
                tostring(aiMember),
                nfwToSingleLineText(attacherName, 40),
                tostring(posText),
                nfwToSingleLineText(posFieldText, 190),
                nfwToSingleLineText(selfProbe, 120),
                nfwToSingleLineText(missionProbe, 120),
                tostring(markerInfo),
                tostring(canStart),
                tostring(turnedOn),
                tostring(unfolded),
                tostring(lowered),
                tostring(canContinue),
                tostring(stopAI),
                tostring(stopReason),
                self:getDebugFruitTypeName(currentSeedFruit),
                tostring(canPlant),
                tostring(isActive),
                tonumber(changedArea) or 0,
                tonumber(statsArea) or 0,
                tostring(spec.showFruitCanNotBePlantedWarning == true),
                tostring(spec.showWrongPlantingTimeWarning == true),
                tostring(spec.showFieldTypeWarningRegularRequired == true),
                tostring(spec.showFieldTypeWarningRiceRequired == true),
                tostring(spec.showWaterPlantingRequiredWarning == true),
                tostring(spec.showWaterPlantingProhibitedWarning == true),
                nfwToSingleLineText(reqDiag, 200),
                table.concat(fillParts, ";")
            )
        )
    end

    local function appendAttachedSowersRecursive(rootObj, depth)
        if rootObj == nil or depth > 8 or traversedAttachObjects[rootObj] then
            return
        end
        traversedAttachObjects[rootObj] = true

        appendSowObject(rootObj)
        if rootObj.getAttachedImplements ~= nil then
            local attached = rootObj:getAttachedImplements()
            if attached ~= nil then
                for _, implement in ipairs(attached) do
                    if implement ~= nil and implement.object ~= nil then
                        appendAttachedSowersRecursive(implement.object, depth + 1)
                    end
                end
            end
        end
    end

    appendAttachedSowersRecursive(vehicle, 0)

    if #sowObjects > 0 then
        table.insert(parts, "sowers=" .. table.concat(sowObjects, " || "))
    else
        table.insert(parts, "sowers=none")
    end

    table.insert(parts, "caps=" .. nfwToSingleLineText(self:getVehicleAiCapabilityDebug(vehicle), 500))
    return table.concat(parts, " | ")
end

function NeighborFieldWorkers:getBestSowFieldProbeRatio(mission, vehicle, fieldX, fieldZ)
    if mission == nil
        or vehicle == nil
        or vehicle.isDeleted
        or type(fieldX) ~= "number"
        or type(fieldZ) ~= "number" then
        return nil
    end

    local bestRatio = nil
    local seen = {}
    local function evalObject(obj)
        if obj == nil or seen[obj] then
            return
        end
        seen[obj] = true
        if obj.spec_sowingMachine ~= nil or obj.spec_planter ~= nil then
            local metrics = self:getImplementAIAreaMetrics(obj, fieldX, fieldZ, 10)
            if metrics ~= nil and metrics.ok and type(metrics.ratio) == "number" then
                if bestRatio == nil or metrics.ratio > bestRatio then
                    bestRatio = metrics.ratio
                end
            end
        end
    end

    local function walk(obj, depth)
        if obj == nil or depth > 8 then
            return
        end
        evalObject(obj)
        if obj.getAttachedImplements ~= nil then
            local attached = obj:getAttachedImplements()
            if attached ~= nil then
                for _, impl in ipairs(attached) do
                    if impl ~= nil and impl.object ~= nil then
                        walk(impl.object, depth + 1)
                    end
                end
            end
        end
    end

    walk(vehicle, 0)
    return bestRatio
end

function NeighborFieldWorkers:getSowMissionBlockingReason(assignment, vehicle)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or not self:isSowMission(mission) or vehicle == nil or vehicle.isDeleted then
        return nil
    end

    local reasons = {}
    local visited = {}

    local function addReason(objName, reasonCode)
        table.insert(
            reasons,
            string.format("%s:%s", nfwToSingleLineText(tostring(objName or "sower"), 36), tostring(reasonCode))
        )
    end

    local function visitObject(obj, depth)
        if obj == nil or visited[obj] or depth > 8 then
            return
        end
        visited[obj] = true

        if obj.spec_sowingMachine ~= nil then
            local spec = obj.spec_sowingMachine
            local params = spec.workAreaParameters
            local objName = obj.getName ~= nil and obj:getName() or tostring(obj)

            if params ~= nil and params.canFruitBePlanted == false then
                addReason(objName, "CAN_PLANT_FALSE")
            end
            if spec.showWrongPlantingTimeWarning == true then
                addReason(objName, "WRONG_SEASON")
            end
            if spec.showFruitCanNotBePlantedWarning == true then
                addReason(objName, "FRUIT_NOT_AVAILABLE")
            end
            if spec.showFieldTypeWarningRegularRequired == true then
                addReason(objName, "FIELD_TYPE_REGULAR_REQUIRED")
            end
            if spec.showFieldTypeWarningRiceRequired == true then
                addReason(objName, "FIELD_TYPE_RICE_REQUIRED")
            end
            if spec.showWaterPlantingRequiredWarning == true then
                addReason(objName, "WATER_REQUIRED")
            end
            if spec.showWaterPlantingProhibitedWarning == true then
                addReason(objName, "WATER_PROHIBITED")
            end
            if spec.showWrongFruitForMissionWarning == true then
                addReason(objName, "WRONG_MISSION_FRUIT")
            end
        end

        if obj.getAttachedImplements ~= nil then
            local attached = obj:getAttachedImplements()
            if attached ~= nil then
                for _, impl in ipairs(attached) do
                    if impl ~= nil and impl.object ~= nil then
                        visitObject(impl.object, depth + 1)
                    end
                end
            end
        end
    end

    visitObject(vehicle, 0)
    if #reasons == 0 then
        return nil
    end

    return table.concat(reasons, " | ")
end

function NeighborFieldWorkers:getSowZeroAreaWatchdogSummary(assignment, vehicle)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or not self:isSowMission(mission) or vehicle == nil or vehicle.isDeleted then
        return nil
    end

    local sawActive = false
    local sawArea = false
    local entries = {}
    local visited = {}

    local function walk(obj, depth)
        if obj == nil or visited[obj] or depth > 8 then
            return
        end
        visited[obj] = true

        if obj.spec_sowingMachine ~= nil then
            local spec = obj.spec_sowingMachine
            local params = spec.workAreaParameters
            local active = params ~= nil and params.isActive == true
            local changedArea = params ~= nil and (tonumber(params.lastChangedArea) or 0) or 0
            local statsArea = params ~= nil and (tonumber(params.lastStatsArea) or 0) or 0
            local totalArea = changedArea + statsArea
            if active then
                sawActive = true
            end
            if totalArea > 0.0001 then
                sawArea = true
            end

            local name = tostring(obj.getName ~= nil and obj:getName() or obj)
            local aiMember = self:isImplementCurrentlyUsedByAI(vehicle, obj)
            local canContinue = "n/a"
            local stopAI = "n/a"
            local stopReason = "n/a"
            if obj.getCanAIImplementContinueWork ~= nil then
                local okCont, c, s, r = pcall(obj.getCanAIImplementContinueWork, obj, false)
                if okCont then
                    canContinue = tostring(c)
                    stopAI = tostring(s)
                    stopReason = self:getAIMessageNameByInstance(r)
                else
                    canContinue = "err"
                    stopAI = "err"
                    stopReason = nfwToSingleLineText(c, 100)
                end
            end

            table.insert(
                entries,
                string.format(
                    "%s{ai=%s active=%s area=%.2f canPlant=%s cont=%s stop=%s reason=%s warn={fruit=%s,season=%s,field=%s,rice=%s,waterReq=%s,waterProh=%s}}",
                    nfwToSingleLineText(name, 32),
                    tostring(aiMember),
                    tostring(active),
                    totalArea,
                    tostring(params ~= nil and params.canFruitBePlanted or nil),
                    tostring(canContinue),
                    tostring(stopAI),
                    tostring(stopReason),
                    tostring(spec.showFruitCanNotBePlantedWarning == true),
                    tostring(spec.showWrongPlantingTimeWarning == true),
                    tostring(spec.showFieldTypeWarningRegularRequired == true),
                    tostring(spec.showFieldTypeWarningRiceRequired == true),
                    tostring(spec.showWaterPlantingRequiredWarning == true),
                    tostring(spec.showWaterPlantingProhibitedWarning == true)
                )
            )
        end

        if obj.getAttachedImplements ~= nil then
            local attached = obj:getAttachedImplements()
            if attached ~= nil then
                for _, impl in ipairs(attached) do
                    if impl ~= nil and impl.object ~= nil then
                        walk(impl.object, depth + 1)
                    end
                end
            end
        end
    end

    walk(vehicle, 0)
    if sawActive and not sawArea and #entries > 0 then
        return table.concat(entries, " || ")
    end

    return nil
end

function NeighborFieldWorkers:getHarvestVehicleRuntimeDebug(vehicle)
    if vehicle == nil or vehicle.spec_combine == nil then
        return "harvestRuntime=n/a"
    end

    local spec = vehicle.spec_combine
    local dischargeNode = vehicle.getCurrentDischargeNode ~= nil and vehicle:getCurrentDischargeNode() or nil
    local fillUnitIndex = dischargeNode ~= nil and dischargeNode.fillUnitIndex or nil
    if fillUnitIndex == nil then
        fillUnitIndex = spec.bufferFillUnitIndex or spec.fillUnitIndex
    end

    local fillLevelText = "n/a"
    local capacityText = "n/a"
    local pctText = "n/a"
    local rawFillLevelText = "n/a"
    local rawCapacityText = "n/a"
    local rawPctText = "n/a"
    if fillUnitIndex ~= nil and vehicle.getFillUnitFillLevel ~= nil and vehicle.getFillUnitCapacity ~= nil then
        local okLevel, level = pcall(vehicle.getFillUnitFillLevel, vehicle, fillUnitIndex)
        local okCap, capacity = pcall(vehicle.getFillUnitCapacity, vehicle, fillUnitIndex)
        if okLevel and type(level) == "number" then
            fillLevelText = string.format("%.1f", level)
        end
        if okCap and type(capacity) == "number" then
            if capacity == math.huge then
                capacityText = "inf"
            else
                capacityText = string.format("%.1f", capacity)
                if okLevel and type(level) == "number" and capacity > 0 then
                    pctText = string.format("%.1f", (level / capacity) * 100)
                end
            end
        end

        local rawLevelFn = vehicle.nfwOriginalGetFillUnitFillLevel
        local rawCapFn = vehicle.nfwOriginalGetFillUnitCapacity
        if rawLevelFn ~= nil then
            local okRawLevel, rawLevel = pcall(rawLevelFn, vehicle, fillUnitIndex)
            if okRawLevel and type(rawLevel) == "number" then
                rawFillLevelText = string.format("%.1f", rawLevel)
            end
        end
        if rawCapFn ~= nil then
            local okRawCap, rawCap = pcall(rawCapFn, vehicle, fillUnitIndex)
            if okRawCap and type(rawCap) == "number" then
                if rawCap == math.huge then
                    rawCapacityText = "inf"
                else
                    rawCapacityText = string.format("%.1f", rawCap)
                end
            end
            if rawLevelFn ~= nil and okRawCap and type(rawCap) == "number" and rawCap > 0 and rawCap ~= math.huge then
                local okRawLevel, rawLevel = pcall(rawLevelFn, vehicle, fillUnitIndex)
                if okRawLevel and type(rawLevel) == "number" then
                    rawPctText = string.format("%.1f", (rawLevel / rawCap) * 100)
                end
            end
        end
    end

    local pipeStateText = "n/a"
    local pipeTargetText = "n/a"
    local trailerNearText = "n/a"
    if vehicle.spec_pipe ~= nil then
        local pipeSpec = vehicle.spec_pipe
        pipeStateText = tostring(pipeSpec.currentState)
        pipeTargetText = tostring(pipeSpec.targetState)
        local trailer = nil
        if pipeSpec.nearestObjectInTriggers ~= nil and NetworkUtil ~= nil and NetworkUtil.getObject ~= nil then
            trailer = NetworkUtil.getObject(pipeSpec.nearestObjectInTriggers.objectId)
        end
        trailerNearText = tostring(trailer ~= nil)
    end

    local turnedOnText = "n/a"
    if vehicle.getIsTurnedOn ~= nil then
        local okTurned, turnedOn = pcall(vehicle.getIsTurnedOn, vehicle)
        if okTurned then
            turnedOnText = tostring(turnedOn)
        end
    end

    return string.format(
        "fillUnit=%s fill=%s cap=%s pct=%s rawFill=%s rawCap=%s rawPct=%s pipe=%s target=%s trailerNear=%s turnedOn=%s turnOffWhenFull=%s",
        tostring(fillUnitIndex),
        fillLevelText,
        capacityText,
        pctText,
        rawFillLevelText,
        rawCapacityText,
        rawPctText,
        pipeStateText,
        pipeTargetText,
        trailerNearText,
        turnedOnText,
        tostring(spec.turnOffWhenFull)
    )
end

function NeighborFieldWorkers:getFieldCourseStartProbe(vehicle, farmId)
    local probe = {
        available = false,
        settingsAvailable = false,
        ok = false,
        hasClosest = false,
        isValid = false,
        closestX = nil,
        closestZ = nil,
        notOwned = nil,
        errorText = nil
    }

    if vehicle == nil or type(FieldCourse) ~= "table" or type(FieldCourse.findClosestField) ~= "function" then
        return probe
    end

    probe.available = true

    local fieldCourseSettings = nil
    if vehicle.getAIModeFieldCourseSettings ~= nil then
        local okSettings, settings = pcall(vehicle.getAIModeFieldCourseSettings, vehicle)
        if okSettings then
            fieldCourseSettings = settings
        end
    end
    if fieldCourseSettings == nil and type(FieldCourseSettings) == "table" and type(FieldCourseSettings.generate) == "function" then
        local okGen, generatedSettings = pcall(FieldCourseSettings.generate, vehicle)
        if okGen then
            fieldCourseSettings = generatedSettings
        end
    end
    probe.settingsAvailable = fieldCourseSettings ~= nil

    local okClosest, closestX, closestZ, notOwned = pcall(
        FieldCourse.findClosestField,
        nil,
        nil,
        nil,
        nil,
        farmId,
        vehicle,
        2,
        fieldCourseSettings
    )
    if okClosest then
        probe.ok = true
        probe.closestX = closestX
        probe.closestZ = closestZ
        probe.notOwned = notOwned
        probe.hasClosest = type(closestX) == "number" and type(closestZ) == "number"
        probe.isValid = probe.hasClosest and notOwned ~= true
    else
        probe.errorText = nfwToSingleLineText(closestX, 200)
    end

    return probe
end

function NeighborFieldWorkers:logHelperStartFieldDiagnostics(assignment, vehicle, targetX, targetZ, isDirectStart)
    if assignment == nil or assignment.mission == nil or vehicle == nil or vehicle.rootNode == nil then
        return
    end

    local mission = assignment.mission
    local missionKey = tostring(assignment.key)
    local missionType = self:getMissionTypeName(mission)
    local missionFieldId = self:getMissionFieldId(mission)
    local missionRequiredFillType = self:getMissionRequiredFillType(mission)
    local missionFieldX, missionFieldZ = self:getMissionFieldPosition(mission)
    local vehicleX, _, vehicleZ = getWorldTranslation(vehicle.rootNode)

    local vehiclePosInfo = self:getFieldDataDebugAtWorldPos(vehicleX, vehicleZ)
    local missionPosInfo = self:getFieldDataDebugAtWorldPos(missionFieldX, missionFieldZ)
    local targetPosInfo = self:getFieldDataDebugAtWorldPos(targetX, targetZ)

    local fieldCourseDiag = "unavailable"
    local fieldCourseProbe = self:getFieldCourseStartProbe(vehicle, mission.farmId)
    if fieldCourseProbe.available then
        if fieldCourseProbe.ok then
            fieldCourseDiag = string.format(
                "closest=(%s/%s) notOwned=%s farmId=%s settings=%s",
                type(fieldCourseProbe.closestX) == "number" and string.format("%.1f", fieldCourseProbe.closestX) or
                tostring(fieldCourseProbe.closestX),
                type(fieldCourseProbe.closestZ) == "number" and string.format("%.1f", fieldCourseProbe.closestZ) or
                tostring(fieldCourseProbe.closestZ),
                tostring(fieldCourseProbe.notOwned),
                tostring(mission.farmId),
                tostring(fieldCourseProbe.settingsAvailable)
            )
        else
            fieldCourseDiag = string.format("err=%s", tostring(fieldCourseProbe.errorText))
        end
    end

    nfwLogHelperDiag(
        "[%s] HelperDiag START_FIELD_CTX: mission=%s type=%s fieldId=%s reqFill=%s(%s) directStart=%s vehiclePos={%s} missionPos={%s} targetPos={%s} fieldCourse={%s}",
        self.MOD_NAME,
        missionKey,
        tostring(missionType),
        tostring(missionFieldId),
        tostring(missionRequiredFillType),
        self:getDebugFillTypeName(missionRequiredFillType),
        tostring(isDirectStart),
        vehiclePosInfo,
        missionPosInfo,
        targetPosInfo,
        fieldCourseDiag
    )

    nfwLogHelperDiag(
        "[%s] HelperDiag START_IMPL_CTX: mission=%s vehicle=%s impl=%s",
        self.MOD_NAME,
        missionKey,
        tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
        nfwToSingleLineText(self:getVehicleAiCapabilityDebug(vehicle), 1800)
    )

    nfwLogHelperDiag(
        "[%s] HelperDiag START_CONTINUE_CTX: mission=%s vehicle=%s %s",
        self.MOD_NAME,
        missionKey,
        tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
        self:getVehicleContinueWorkDebug(vehicle)
    )
end

function NeighborFieldWorkers:configureMissionFieldSpawnState(mission)
    if mission == nil then
        return false
    end

    self:filterHarvestMissionVehiclesToLoad(mission)
    self:filterStoneMissionVehiclesToLoad(mission)
    self:filterCultivateMissionVehiclesToLoad(mission)
    self:filterPlowMissionVehiclesToLoad(mission)
    self:filterMowMissionVehiclesToLoad(mission)
    self:filterHoeMissionVehiclesToLoad(mission)
    self:filterWeedMissionVehiclesToLoad(mission)
    self:filterSprayMissionVehiclesToLoad(mission)
    self:filterSowMissionVehiclesToLoad(mission)
    self:filterTurnMissionVehiclesToLoad(mission)

    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    if fieldX == nil or fieldZ == nil then
        return false
    end

    local dirX, dirZ = self:getMissionSpawnDirection(mission)

    mission.nfwSpawnAtField = true
    mission.nfwSpawnFieldX = fieldX
    mission.nfwSpawnFieldZ = fieldZ
    mission.nfwSpawnDirX = dirX
    mission.nfwSpawnDirZ = dirZ
    mission.nfwSpawnIndex = 0
    mission.nfwSpawnLogDone = false
    mission.nfwPrimarySpawnX = nil
    mission.nfwPrimarySpawnZ = nil
    mission.nfwPrimarySpawnDirX = nil
    mission.nfwPrimarySpawnDirZ = nil
    mission.nfwPrimarySpawnYRot = nil
    mission.nfwPrimaryVehicleLength = nil
    mission.nfwLengthFallbackUsed = nil
    mission.nfwLengthResolvedRelayoutDone = nil
    mission.nfwHarvestRoleFallbackUsed = nil
    mission.nfwStoneRoleFallbackUsed = nil
    mission.nfwCultivateMetaFallbackUsed = nil
    mission.nfwPlowMetaFallbackUsed = nil
    mission.nfwSowMetaFallbackUsed = nil
    mission.nfwSprayerSpawnIndex = 0
    mission.nfwRearImplementSpawnIndex = 0
    mission.nfwFrontImplementSpawnIndex = 0
    mission.nfwHideVehiclesUntilHelperStart = self.transparentSpawnModeEnabled == true
    mission.nfwHiddenVehicles = nil
    -- Keep nfwForcedFrontImplementFilenameSet from filterMowMissionVehiclesToLoad()
    -- so front/rear mower assignment survives into spawn + attach phases.

    return true
end

function NeighborFieldWorkers:clearMissionFieldSpawnState(mission)
    if mission == nil then
        return
    end

    mission.nfwSpawnAtField = nil
    mission.nfwSpawnFieldX = nil
    mission.nfwSpawnFieldZ = nil
    mission.nfwSpawnDirX = nil
    mission.nfwSpawnDirZ = nil
    mission.nfwSpawnIndex = nil
    mission.nfwSpawnLogDone = nil
    mission.nfwPrimarySpawnX = nil
    mission.nfwPrimarySpawnZ = nil
    mission.nfwPrimarySpawnDirX = nil
    mission.nfwPrimarySpawnDirZ = nil
    mission.nfwPrimarySpawnYRot = nil
    mission.nfwPrimaryVehicleLength = nil
    mission.nfwLengthFallbackUsed = nil
    mission.nfwLengthResolvedRelayoutDone = nil
    mission.nfwHarvestRoleFallbackUsed = nil
    mission.nfwStoneRoleFallbackUsed = nil
    mission.nfwCultivateMetaFallbackUsed = nil
    mission.nfwPlowMetaFallbackUsed = nil
    mission.nfwSowMetaFallbackUsed = nil
    mission.nfwSprayerSpawnIndex = nil
    mission.nfwRearImplementSpawnIndex = nil
    mission.nfwFrontImplementSpawnIndex = nil
    mission.nfwForcedFrontImplementFilenameSet = nil
    mission.nfwForcedRearImplementFilenameSet = nil
    mission.nfwHarvestVehiclesFiltered = nil
    mission.nfwHarvestExpectedVehicleCount = nil
    mission.nfwStoneVehiclesFiltered = nil
    mission.nfwStoneExpectedVehicleCount = nil
    mission.nfwCultivateVehiclesFiltered = nil
    mission.nfwCultivateExpectedVehicleCount = nil
    mission.nfwPlowVehiclesFiltered = nil
    mission.nfwPlowExpectedVehicleCount = nil
    mission.nfwMowVehiclesFiltered = nil
    mission.nfwMowExpectedVehicleCount = nil
    mission.nfwHoeVehiclesFiltered = nil
    mission.nfwHoeExpectedVehicleCount = nil
    mission.nfwWeedVehiclesFiltered = nil
    mission.nfwWeedExpectedVehicleCount = nil
    mission.nfwSprayVehiclesFiltered = nil
    mission.nfwSprayExpectedVehicleCount = nil
    mission.nfwSowVehiclesFiltered = nil
    mission.nfwSowExpectedVehicleCount = nil
    mission.nfwTurnVehiclesFiltered = nil
    mission.nfwTurnExpectedVehicleCount = nil
    mission.nfwSowFieldPreparedForNFW = nil
    mission.nfwSowRecoveryPrepDone = nil
    mission.nfwHideVehiclesUntilHelperStart = nil
    mission.nfwHiddenVehicles = nil
end

function NeighborFieldWorkers:shouldMissionSpawnVehiclesAtField(mission)
    return mission ~= nil and mission.nfwSpawnAtField == true
end

function NeighborFieldWorkers:shouldUseTransparentSpawnModeForMission(mission)
    return self.transparentSpawnModeEnabled == true
        and mission ~= nil
        and mission.nfwHideVehiclesUntilHelperStart == true
        and self:shouldMissionSpawnVehiclesAtField(mission)
end

function NeighborFieldWorkers:setMissionVehicleVisibleState(vehicle, visible)
    if vehicle == nil or vehicle.isDeleted or vehicle.rootNode == nil then
        return false
    end
    if setVisibility == nil then
        return false
    end

    local targetVisible = visible == true
    local anyApplied = false

    if vehicle.setVisibility ~= nil then
        local okVehicle = pcall(vehicle.setVisibility, vehicle, targetVisible)
        if okVehicle then
            anyApplied = true
        end
    end

    if type(vehicle.components) == "table" then
        for _, component in pairs(vehicle.components) do
            if component ~= nil and component.node ~= nil then
                local okComponent = pcall(setVisibility, component.node, targetVisible)
                if okComponent then
                    anyApplied = true
                end
            end
        end
    end

    local okRoot = pcall(setVisibility, vehicle.rootNode, targetVisible)
    if okRoot then
        anyApplied = true
    end

    return anyApplied
end

function NeighborFieldWorkers:hideMissionVehiclesUntilHelperStart(mission, vehicles)
    if not self:shouldUseTransparentSpawnModeForMission(mission) then
        return 0
    end
    if type(vehicles) ~= "table" or #vehicles == 0 then
        return 0
    end

    mission.nfwHiddenVehicles = mission.nfwHiddenVehicles or {}
    local hiddenCount = 0

    for _, vehicle in ipairs(vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            local alreadyTracked = false
            for _, existing in ipairs(mission.nfwHiddenVehicles) do
                if existing == vehicle then
                    alreadyTracked = true
                    break
                end
            end

            if not alreadyTracked then
                table.insert(mission.nfwHiddenVehicles, vehicle)
            end

            if self:setMissionVehicleVisibleState(vehicle, false) then
                hiddenCount = hiddenCount + 1
            end
        end
    end

    if hiddenCount > 0 then
        nfwLogAttachDebug(
            "[%s] TransparentSpawn hide: mission=%s hiddenNow=%d tracked=%d",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            hiddenCount,
            #mission.nfwHiddenVehicles
        )
    end

    return hiddenCount
end

function NeighborFieldWorkers:enforceHiddenMissionVehicleState(mission)
    if mission == nil or mission.nfwHiddenVehicles == nil then
        return 0
    end

    local refreshed = 0
    for _, vehicle in ipairs(mission.nfwHiddenVehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            if self:setMissionVehicleVisibleState(vehicle, false) then
                refreshed = refreshed + 1
            end
        end
    end

    return refreshed
end

function NeighborFieldWorkers:revealHiddenMissionVehicles(mission, reason)
    if mission == nil or mission.nfwHiddenVehicles == nil then
        return 0
    end

    local revealCount = 0
    for _, vehicle in ipairs(mission.nfwHiddenVehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            if self:setMissionVehicleVisibleState(vehicle, true) then
                revealCount = revealCount + 1
            end
        end
    end

    mission.nfwHiddenVehicles = nil
    mission.nfwHideVehiclesUntilHelperStart = nil

    if revealCount > 0 then
        nfwLogAttachDebug(
            "[%s] TransparentSpawn reveal: mission=%s count=%d reason=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            revealCount,
            tostring(reason or "n/a")
        )
    end

    return revealCount
end

function NeighborFieldWorkers:getMissionSpawnSlotByIndex(mission, idx)
    if mission == nil then
        return nil, nil, nil
    end

    local fieldX = mission.nfwSpawnFieldX
    local fieldZ = mission.nfwSpawnFieldZ
    local dirX = mission.nfwSpawnDirX
    local dirZ = mission.nfwSpawnDirZ
    if type(fieldX) ~= "number" or type(fieldZ) ~= "number" then
        return nil, nil, nil
    end
    if type(dirX) ~= "number" or type(dirZ) ~= "number" then
        dirX, dirZ = self:getMissionSpawnDirection(mission)
    end

    local slotIndex = math.max(1, math.floor(Utils.getNoNil(idx, 1)))
    local row = math.floor((slotIndex - 1) / 3)
    local col = (slotIndex - 1) % 3
    local sideOffset = (col - 1) * 4.5
    local backOffset = 8 + row * 7
    local perpX = -dirZ
    local perpZ = dirX

    local spawnX = fieldX - dirX * backOffset + perpX * sideOffset
    local spawnZ = fieldZ - dirZ * backOffset + perpZ * sideOffset
    local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
    return spawnX, spawnZ, yRot
end

function NeighborFieldWorkers:getMissionPrimarySpawnAnchor(mission)
    if mission == nil then
        return nil, nil, nil, nil
    end

    if type(mission.nfwPrimarySpawnX) == "number"
        and type(mission.nfwPrimarySpawnZ) == "number"
        and type(mission.nfwPrimarySpawnDirX) == "number"
        and type(mission.nfwPrimarySpawnDirZ) == "number" then
        return mission.nfwPrimarySpawnX, mission.nfwPrimarySpawnZ, mission.nfwPrimarySpawnDirX,
            mission.nfwPrimarySpawnDirZ
    end

    local primaryIdx = 1
    local primaryInfo = nil
    if mission.vehiclesToLoad ~= nil then
        for i, info in ipairs(mission.vehiclesToLoad) do
            local meta = self:getVehicleInfoMetaByInfo(info)
            if self:isPrimaryMissionVehicleInfo(mission, info, meta) then
                primaryIdx = i
                primaryInfo = info
                break
            end
        end
        if primaryInfo == nil then
            primaryInfo = mission.vehiclesToLoad[primaryIdx]
        end
    end

    local spawnX, spawnZ, yRot = self:getMissionSpawnSlotByIndex(mission, primaryIdx)
    if type(spawnX) ~= "number" or type(spawnZ) ~= "number" then
        return nil, nil, nil, nil
    end

    local dirX, dirZ = self:getMissionSpawnDirection(mission)
    mission.nfwPrimarySpawnX = spawnX
    mission.nfwPrimarySpawnZ = spawnZ
    mission.nfwPrimarySpawnDirX = dirX
    mission.nfwPrimarySpawnDirZ = dirZ
    mission.nfwPrimarySpawnYRot = yRot
    mission.nfwPrimaryVehicleLength = self:getVehicleInfoLength(primaryInfo)
    if type(mission.nfwPrimaryVehicleLength) ~= "number" or mission.nfwPrimaryVehicleLength <= 0 then
        mission.nfwLengthFallbackUsed = true
    end

    return spawnX, spawnZ, dirX, dirZ
end

function NeighborFieldWorkers:spawnMissionVehicleAtField(mission, info)
    if mission == nil or info == nil or VehicleLoadingData == nil then
        return false
    end

    local data = VehicleLoadingData.new()
    data:setFilename(info.filename)
    if not data.isValid then
        return false
    end

    if info.configurations ~= nil then
        data:setConfigurations(info.configurations)
    end

    data:setPropertyState(VehiclePropertyState.MISSION)
    data:setOwnerFarmId(mission.farmId)
    data:setIgnoreShopOffset(true)

    local fieldX = mission.nfwSpawnFieldX
    local fieldZ = mission.nfwSpawnFieldZ
    if type(fieldX) ~= "number" or type(fieldZ) ~= "number" then
        return false
    end

    local dirX = mission.nfwSpawnDirX
    local dirZ = mission.nfwSpawnDirZ
    if type(dirX) ~= "number" or type(dirZ) ~= "number" then
        dirX, dirZ = self:getMissionSpawnDirection(mission)
    end

    local idx = Utils.getNoNil(mission.nfwSpawnIndex, 0) + 1
    mission.nfwSpawnIndex = idx

    local spawnX, spawnZ, yRot = self:getMissionSpawnSlotByIndex(mission, idx)
    if type(spawnX) ~= "number" or type(spawnZ) ~= "number" then
        return false
    end
    local infoMeta = self:getVehicleInfoMetaByInfo(info)
    local infoFilenameLower = string.lower(tostring(info ~= nil and info.filename or ""))
    local isHarvestCutterInfo = false
    local isHarvestTowCombineInfo = false
    if self:isHarvestMission(mission) then
        local harvestRole = self:getHarvestVehicleRoleByInfo(info)
        isHarvestCutterInfo = harvestRole == "cutter"
        isHarvestTowCombineInfo = self:isMarkedHarvestTowCombineFilename(mission, info ~= nil and info.filename or nil)
            or self:isLikelyTowBehindHarvestCombineInfo(info, infoMeta)
    end

    local forcedFrontByMission = false
    if mission ~= nil and mission.nfwForcedFrontImplementFilenameSet ~= nil then
        local infoFileKey = nfwNormalizeXmlPath(info ~= nil and info.filename or "")
        local infoFileBase = nfwGetXmlBasename(info ~= nil and info.filename or "")
        forcedFrontByMission = mission.nfwForcedFrontImplementFilenameSet[infoFileKey] == true
            or (infoFileBase ~= nil and mission.nfwForcedFrontImplementFilenameSet[infoFileBase] == true)
    end
    local forcedRearByMission = false
    if mission ~= nil and mission.nfwForcedRearImplementFilenameSet ~= nil then
        local infoFileKey = nfwNormalizeXmlPath(info ~= nil and info.filename or "")
        local infoFileBase = nfwGetXmlBasename(info ~= nil and info.filename or "")
        forcedRearByMission = mission.nfwForcedRearImplementFilenameSet[infoFileKey] == true
            or (infoFileBase ~= nil and mission.nfwForcedRearImplementFilenameSet[infoFileBase] == true)
    end

    local isPrimaryVehicleInfo = self:isPrimaryMissionVehicleInfo(mission, info, infoMeta)
    local isFrontSupportInfo = infoMeta.isFrontTank
        or infoMeta.isWeight
        or forcedFrontByMission
        or isHarvestCutterInfo
        or self:isLikelyFrontAttachmentInfo(info)
    if isHarvestTowCombineInfo then
        -- Tow-behind harvesters (e.g. Dewulf trailer-harvesters) must attach at rear.
        isFrontSupportInfo = false
    end
    if forcedRearByMission then
        isFrontSupportInfo = false
    end
    local isImplementInfo = not isPrimaryVehicleInfo and
        (not infoMeta.isTrailer or isHarvestTowCombineInfo or isHarvestCutterInfo)
    local sideDecisionReason = "unknown"

    if isPrimaryVehicleInfo then
        sideDecisionReason = "primary"
        mission.nfwPrimarySpawnX = spawnX
        mission.nfwPrimarySpawnZ = spawnZ
        mission.nfwPrimarySpawnDirX = dirX
        mission.nfwPrimarySpawnDirZ = dirZ
        mission.nfwPrimarySpawnYRot = yRot
        mission.nfwPrimaryVehicleLength = self:getVehicleInfoLength(info)
        if type(mission.nfwPrimaryVehicleLength) ~= "number" or mission.nfwPrimaryVehicleLength <= 0 then
            mission.nfwLengthFallbackUsed = true
        end
    elseif isImplementInfo then
        if forcedRearByMission then
            sideDecisionReason = "forcedRearByMission"
        elseif forcedFrontByMission then
            sideDecisionReason = "forcedFrontByMission"
        elseif infoMeta.isWeight then
            sideDecisionReason = "weightFront"
        elseif infoMeta.isFrontTank then
            sideDecisionReason = "frontTank"
        elseif isHarvestTowCombineInfo then
            sideDecisionReason = "harvestTowRear"
        elseif isHarvestCutterInfo and not infoMeta.isTrailer then
            sideDecisionReason = "harvestCutterFront"
        elseif self:isLikelyFrontAttachmentInfo(info) then
            sideDecisionReason = "heuristicFront"
        else
            sideDecisionReason = "defaultRear"
        end

        local primarySpawnX = mission.nfwPrimarySpawnX
        local primarySpawnZ = mission.nfwPrimarySpawnZ
        local primaryDirX = mission.nfwPrimarySpawnDirX
        local primaryDirZ = mission.nfwPrimarySpawnDirZ
        local estimatedPrimary = false
        if type(primarySpawnX) ~= "number"
            or type(primarySpawnZ) ~= "number"
            or type(primaryDirX) ~= "number"
            or type(primaryDirZ) ~= "number" then
            primarySpawnX, primarySpawnZ, primaryDirX, primaryDirZ = self:getMissionPrimarySpawnAnchor(mission)
            estimatedPrimary = true
        end

        if type(primarySpawnX) == "number"
            and type(primarySpawnZ) == "number"
            and type(primaryDirX) == "number"
            and type(primaryDirZ) == "number" then
            local isFrontPlacement = isFrontSupportInfo
            if estimatedPrimary then
                nfwLogAttachDebug(
                    "[%s] SpawnTrace primaryEstimated: mission=%s idx=%d anchor=(%.2f/%.2f)",
                    self.MOD_NAME,
                    tostring(self:getMissionKey(mission)),
                    idx,
                    primarySpawnX,
                    primarySpawnZ
                )
            end

            local sideSpawnIdx = 1
            if isFrontPlacement then
                sideSpawnIdx = Utils.getNoNil(mission.nfwFrontImplementSpawnIndex, 0) + 1
                mission.nfwFrontImplementSpawnIndex = sideSpawnIdx
            else
                sideSpawnIdx = Utils.getNoNil(mission.nfwRearImplementSpawnIndex, 0) + 1
                mission.nfwRearImplementSpawnIndex = sideSpawnIdx
            end

            local baseDist = self:getImplementPlacementDistanceForInfo(mission, info, isFrontPlacement)
            local lateral = 0
            local isSowRearChain = self:isSowMission(mission) and not isFrontPlacement
            if isSowRearChain and sideSpawnIdx > 1 then
                -- Keep chained sowing tools inline behind the tractor (no sideways offset),
                -- so the GIANTS attach scan can resolve the rear chain directly.
                baseDist = baseDist + (sideSpawnIdx - 1) * 2.0
            elseif sideSpawnIdx > 1 then
                local lateralIdx = sideSpawnIdx - 2
                local lateralMag = 1.2 + math.floor(lateralIdx / 2) * 0.6
                local lateralSign = (lateralIdx % 2 == 0) and -1 or 1
                lateral = lateralSign * lateralMag
            end
            local perpX = -primaryDirZ
            local perpZ = primaryDirX
            local directionSign = isFrontPlacement and 1 or -1
            spawnX = primarySpawnX + primaryDirX * baseDist * directionSign + perpX * lateral
            spawnZ = primarySpawnZ + primaryDirZ * baseDist * directionSign + perpZ * lateral
            if type(mission.nfwPrimarySpawnYRot) == "number" then
                yRot = mission.nfwPrimarySpawnYRot
            end
            nfwLogAttachDebug(
                "[%s] SpawnTrace implementRelative: mission=%s idx=%d file=%s side=%s spawn=(%.2f/%.2f) dist=%.1f",
                self.MOD_NAME,
                tostring(self:getMissionKey(mission)),
                idx,
                tostring(info.filename or "unknown"),
                isFrontPlacement and "front" or "rear",
                spawnX,
                spawnZ,
                baseDist
            )
            if isHarvestTowCombineInfo then
                nfwLogHelperDiag(
                    "[%s] HelperDiag HARVEST_TOW_SPAWN: mission=%s file=%s side=%s spawn=(%.2f/%.2f) dist=%.1f",
                    self.MOD_NAME,
                    tostring(self:getMissionKey(mission)),
                    tostring(info.filename or "unknown"),
                    isFrontPlacement and "front" or "rear",
                    spawnX,
                    spawnZ,
                    baseDist
                )
            end

            nfwLogHelperDiag(
                "[%s] HelperDiag SPAWN_SIDE_DECISION: mission=%s file=%s side=%s reason=%s forcedFront=%s forcedRear=%s trailer=%s frontTank=%s weight=%s fieldTool={plow=%s,cult=%s,mow=%s,hoe=%s,weed=%s,spray=%s,sow=%s,turn=%s,baler=%s}",
                self.MOD_NAME,
                tostring(self:getMissionKey(mission)),
                tostring(info.filename or "unknown"),
                isFrontPlacement and "front" or "rear",
                tostring(sideDecisionReason),
                tostring(forcedFrontByMission),
                tostring(forcedRearByMission),
                tostring(infoMeta.isTrailer),
                tostring(infoMeta.isFrontTank),
                tostring(infoMeta.isWeight),
                tostring(infoMeta.isPlowTool),
                tostring(infoMeta.isCultivateTool),
                tostring(infoMeta.isMowerTool),
                tostring(infoMeta.isHoeTool),
                tostring(infoMeta.isWeederTool),
                tostring(infoMeta.isSprayerTool),
                tostring(infoMeta.isSowingTool),
                tostring(infoMeta.isTurnTool),
                tostring(infoMeta.isBalerTool)
            )
        else
            nfwLogAttachDebug(
                "[%s] SpawnTrace implementRelative skipped(noPrimary): mission=%s idx=%d file=%s",
                self.MOD_NAME,
                tostring(self:getMissionKey(mission)),
                idx,
                tostring(info.filename or "unknown")
            )
        end
    end

    data:setPosition(spawnX, nil, spawnZ, 0.45)
    data:setRotation(0, yRot, 0)

    if string.find(infoFilenameLower, "ux5201", 1, true) ~= nil
        or string.find(infoFilenameLower, "spray", 1, true) ~= nil
        or string.find(infoFilenameLower, "sprayer", 1, true) ~= nil
        or string.find(infoFilenameLower, "amazone", 1, true) ~= nil then
        nfwLogAttachDebug(
            "[%s] SpawnTrace vehicleInfo: mission=%s idx=%d file=%s spawn=(%.2f/%.2f)",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            idx,
            tostring(info.filename or "unknown"),
            spawnX,
            spawnZ
        )
    end

    table.insert(mission.pendingVehicleLoadingData, data)
    local loadingInfo = { loadingData = data, vehicleInfo = info }
    data:load(mission.onSpawnedVehicle, mission, loadingInfo)

    if not mission.nfwSpawnLogDone then
        mission.nfwSpawnLogDone = true
        nfwLogInfo(
            "[%s] Mission Feld-Spawn aktiviert: mission=%s fieldX=%.1f fieldZ=%.1f",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            fieldX,
            fieldZ
        )
    end

    return true
end

function NeighborFieldWorkers:createAssignmentForMission(mission)
    local key = self:getMissionKey(mission)
    if key == nil then
        return nil
    end

    local assignment = {
        key = key,
        mission = mission,
        farmId = mission.farmId,
        aiStarted = false,
        aiMode = nil,
        preparingSinceMs = 0,
        nextPreparingMissionDebugAtMs = 0,
        forceDirectStart = mission ~= nil and mission.nfwSpawnAtField == true,
        forceRecoveryReposition = false,
        vehiclesPrepared = false,
        vehiclesRelocated = false,
        lastAttachTryTime = 0,
        attachAlignMode = 1,
        attachFailedPasses = 0,
        attachFailureStreak = 0,
        attachLockState = nil,
        nextStartAfterAttachMs = 0,
        nextStartDelayLogAtMs = 0,
        nextAttachDebugLogAtMs = 0,
        nextAttachTraceAtMs = 0,
        sprayerAttachPhase = nil,
        sprayerAttachNextMs = nil,
        suppressRelocateDuringSprayerAttach = false,
        nextResourceTopupAtMs = 0,
        lastRelocateTryTime = 0,
        nextRelocateLogAtMs = 0,
        aiStartTimeMs = nil,
        nextAiStateLogAtMs = 0,
        aiInactiveSinceMs = nil,
        aiFarSinceMs = nil,
        nextPendingLoadsLogAtMs = 0,
        nextMissingAttachLogAtMs = 0,
        nextVehicleNotReadyLogAtMs = 0,
        nextAIImplementSyncLogAtMs = 0,
        nextAIImplementStabilityLogAtMs = 0,
        lastObservedAiImplementCount = nil,
        aiImplementCountStableSinceMs = 0,
        nextUnexpectedAiStopAtMs = 0,
        nextNoVehicleLogAtMs = 0,
        nextNoHelperLogAtMs = 0,
        nextVehicleStateLogAtMs = 0,
        noVehicleSinceMs = nil,
        noMovementSinceMs = nil,
        lastMovementCheckX = nil,
        lastMovementCheckZ = nil,
        stuckCheckAnchorX = nil,
        stuckCheckAnchorZ = nil,
        stuckCheckAnchorAtMs = 0,
        lastCompletionPercent = nil,
        completionUnchangedSinceMs = 0,
        nextCompletionStallLogAtMs = 0,
        nextFrontLiftEnforceAtMs = 0,
        nextSowSelectionLogAtMs = 0,
        nextSowDiagAtMs = 0,
        nextSowZeroAreaDiagAtMs = 0,
        nextSowZeroAreaRecoveryLogAtMs = 0,
        sowZeroAreaActiveSinceMs = nil,
        sowZeroAreaLastSummary = nil,
        lastSowTargetFruitType = nil,
        lastSowMissionLogKey = nil,
        helperIndex = nil,
        helperDisplayName = nil,
        helperOriginalTitle = nil,
        helperOriginalName = nil,
        helperDiagStartAttemptCount = 0,
        helperDiagLastStartAttemptMs = 0,
        helperDiagImmediateStopLogged = false,
        helperDiagLastAiActive = nil,
        helperDiagLastAiActiveChangeMs = 0,
        helperDiagLastStopReason = nil,
        helperDiagLastStopAtMs = 0,
        lastStartEdgeTargetX = nil,
        lastStartEdgeTargetZ = nil,
        edgeTargetBestDistSq = nil,
        edgeTargetBestAtMs = 0,
        edgeTargetArrivedStillTask1SinceMs = nil,
        forceRecoveryReason = nil,
        harvestCanStartBlockedSinceMs = 0,
        nextHarvestUnblockTryAtMs = 0,
        nextHarvestDeepDiagAtMs = 0,
        nextCombineDriveDiagAtMs = 0,
        nextCombineDriveBypassLogAtMs = 0,
        nextFieldCourseDriveDiagAtMs = 0,
        noFieldRetryIndex = 0,
        nextHelperStartBlockedLogAtMs = 0,
        lastHelperStartBlockedCode = nil,
        nextPendingStartMissionDebugAtMs = 0,
        lastPendingStartMissionDebugCode = nil,
        recoveredFromSave = false
    }

    self.activeAssignments[key] = assignment
    self.savedAssignmentKeys[tostring(key)] = true
    self.savedAssignmentFieldIds[tostring(key)] = self:getMissionFieldId(mission)
    return assignment
end

function NeighborFieldWorkers:getActiveAssignmentCount()
    local count = 0
    for _, assignment in pairs(self.activeAssignments) do
        if assignment ~= nil and assignment.mission ~= nil then
            local status = assignment.mission.status
            if status ~= MissionStatus.FINISHED and status ~= MissionStatus.DISMISSED then
                count = count + 1
            end
        end
    end

    return count
end

function NeighborFieldWorkers:getPendingStartAssignmentCount()
    local count = 0
    for _, assignment in pairs(self.activeAssignments) do
        if assignment ~= nil and assignment.mission ~= nil then
            local status = assignment.mission.status
            if not assignment.aiStarted and (status == MissionStatus.PREPARING or status == MissionStatus.RUNNING) then
                count = count + 1
            end
        end
    end
    return count
end

function NeighborFieldWorkers:recoverSavedAssignmentsByKey(missionsByKey)
    local recoveredCount = 0
    local missingCount = 0

    for savedKey, _ in pairs(self.savedAssignmentKeys) do
        if savedKey ~= nil and self.activeAssignments[savedKey] == nil then
            local mission = missionsByKey[tostring(savedKey)]
            if mission ~= nil then
                if mission.farmId == nil and self.neighborFarmId ~= nil then
                    mission.farmId = self.neighborFarmId
                elseif self.neighborFarmId ~= nil and mission.farmId ~= self.neighborFarmId then
                    mission.farmId = self.neighborFarmId
                end

                self:applyNeighborMissionEconomyRules(mission)
                self:filterHarvestMissionVehiclesToLoad(mission)
                self:filterStoneMissionVehiclesToLoad(mission)
                self:filterCultivateMissionVehiclesToLoad(mission)
                self:filterPlowMissionVehiclesToLoad(mission)
                self:filterMowMissionVehiclesToLoad(mission)
                self:filterHoeMissionVehiclesToLoad(mission)
                self:filterWeedMissionVehiclesToLoad(mission)
                self:filterSprayMissionVehiclesToLoad(mission)
                self:filterSowMissionVehiclesToLoad(mission)
                self:filterTurnMissionVehiclesToLoad(mission)

                local fieldInUse, fieldId, inUseReason = self:isMissionFieldInUseByNeighbor(mission, savedKey)
                if fieldInUse then
                    nfwLogInfo(
                        "[%s] Save-Recover uebersprungen (Feld bereits belegt): mission=%s field=%s reason=%s",
                        self.MOD_NAME,
                        tostring(savedKey),
                        tostring(fieldId),
                        tostring(inUseReason)
                    )
                end

                local assignment = nil
                if not fieldInUse then
                    assignment = self:createAssignmentForMission(mission)
                end
                if assignment ~= nil then
                    assignment.recoveredFromSave = true
                    assignment.forceDirectStart = true
                    assignment.forceRecoveryReposition = true

                    recoveredCount = recoveredCount + 1
                    self.savedAssignmentsMissingLog[savedKey] = nil
                    nfwLogInfo(
                        "[%s] Auftrag aus Save-Key wiederhergestellt: mission=%s status=%s farmId=%s",
                        self.MOD_NAME,
                        tostring(assignment.key),
                        tostring(mission.status),
                        tostring(mission.farmId)
                    )
                end
            else
                missingCount = missingCount + 1
                if self.savedAssignmentsMissingLog[savedKey] ~= true then
                    self.savedAssignmentsMissingLog[savedKey] = true
                    nfwLogInfo(
                        "[%s] Gespeicherter Auftrag noch nicht im Missionsmanager gefunden: mission=%s",
                        self.MOD_NAME,
                        tostring(savedKey)
                    )
                end
            end
        end
    end

    return recoveredCount, missingCount
end

function NeighborFieldWorkers:reconcileExistingNeighborMissions()
    if g_missionManager == nil or g_missionManager.getMissions == nil then
        return
    end

    local missions = g_missionManager:getMissions()
    local missionsByKey = {}
    for _, mission in ipairs(missions) do
        local missionKey = self:getMissionKey(mission)
        if missionKey ~= nil then
            missionsByKey[tostring(missionKey)] = mission
        end
    end

    local recoveredFromSavedKeys, missingSavedKeys = self:recoverSavedAssignmentsByKey(missionsByKey)

    self:inferNeighborFarmIdFromActiveMissions()
    local playerFarmId = nil
    if g_currentMission ~= nil and g_currentMission.getFarmId ~= nil then
        playerFarmId = g_currentMission:getFarmId()
    end

    for _, mission in ipairs(missions) do
        local key = self:getMissionKey(mission)
        local wasSaved = key ~= nil and self.savedAssignmentKeys[tostring(key)] == true
        local ownedByNeighbor = self:isMissionOwnedByNeighborFarm(mission)
        local canRecover = self:canMissionBeRecoveredAsActive(mission, wasSaved)
        local belongsToPlayerFarm = playerFarmId ~= nil and mission.farmId == playerFarmId

        if mission.farmId ~= nil
            and self:isAllowedMissionType(mission)
            and canRecover
            and (ownedByNeighbor or wasSaved) then
            -- Never auto-steal active contracts from the player farm.
            -- Only saved neighbor assignments may be rebound to the neighbor farm on load.
            local mayAdopt = not (belongsToPlayerFarm and not wasSaved and not ownedByNeighbor)
            if mayAdopt then
                if self.neighborFarmId ~= nil and mission.farmId ~= self.neighborFarmId and wasSaved then
                    mission.farmId = self.neighborFarmId
                end

                if key ~= nil and self.activeAssignments[key] == nil then
                    local fieldInUse, fieldId, inUseReason = self:isMissionFieldInUseByNeighbor(mission, key)
                    if fieldInUse then
                        nfwLogInfo(
                            "[%s] Reconcile uebersprungen (Feld bereits belegt): mission=%s field=%s reason=%s",
                            self.MOD_NAME,
                            tostring(key),
                            tostring(fieldId),
                            tostring(inUseReason)
                        )
                    else
                        self:applyNeighborMissionEconomyRules(mission)
                        self:filterHarvestMissionVehiclesToLoad(mission)
                        self:filterStoneMissionVehiclesToLoad(mission)
                        self:filterCultivateMissionVehiclesToLoad(mission)
                        self:filterPlowMissionVehiclesToLoad(mission)
                        self:filterMowMissionVehiclesToLoad(mission)
                        self:filterHoeMissionVehiclesToLoad(mission)
                        self:filterWeedMissionVehiclesToLoad(mission)
                        self:filterSprayMissionVehiclesToLoad(mission)
                        self:filterSowMissionVehiclesToLoad(mission)
                        self:filterTurnMissionVehiclesToLoad(mission)
                        local assignment = self:createAssignmentForMission(mission)
                        if assignment ~= nil and wasSaved then
                            assignment.recoveredFromSave = true
                            assignment.forceDirectStart = true
                            assignment.forceRecoveryReposition = true
                        end

                        if assignment ~= nil then
                            nfwLogInfo(
                                "[%s] Auftrag beim Laden wiederhergestellt: mission=%s status=%s farmId=%s saved=%s",
                                self.MOD_NAME,
                                tostring(assignment.key),
                                tostring(mission.status),
                                tostring(mission.farmId),
                                tostring(wasSaved)
                            )
                        end
                    end
                end
            end
        end
    end

    if self.settingsLoadedFromSavegame and not self.initialReconcileLogged then
        local savedCount = 0
        for _, _ in pairs(self.savedAssignmentKeys) do
            savedCount = savedCount + 1
        end

        nfwLogInfo(
            "[%s] Reconcile nach Laden: missions=%d savedAssignments=%d restoredByKey=%d missingSaved=%d activeAssignments=%d neighborFarmId=%s playerFarmId=%s",
            self.MOD_NAME,
            #missions,
            savedCount,
            recoveredFromSavedKeys,
            missingSavedKeys,
            self:getActiveAssignmentCount(),
            tostring(self.neighborFarmId),
            tostring(playerFarmId)
        )
        self.initialReconcileLogged = true
    end
end

function NeighborFieldWorkers:getMissionSelectionModeName()
    if self.allowExistingContractCompetition == true then
        return "EXISTING_COMPETITION"
    end

    return "GENERATE_NEW"
end

function NeighborFieldWorkers:collectMissionKeysSnapshot()
    local keys = {}
    if g_missionManager == nil or g_missionManager.getMissions == nil then
        return keys
    end

    for _, mission in ipairs(g_missionManager:getMissions()) do
        local missionKey = self:getMissionKey(mission)
        if missionKey ~= nil then
            keys[tostring(missionKey)] = true
        end
    end

    return keys
end

function NeighborFieldWorkers:getGeneratableAllowedMissionTypeNames()
    local candidates = {}
    if g_missionManager == nil or type(g_missionManager.missionTypes) ~= "table" then
        return candidates
    end

    for _, missionType in ipairs(g_missionManager.missionTypes) do
        local missionTypeName = missionType ~= nil and missionType.name or nil
        local classObject = missionType ~= nil and missionType.classObject or nil
        local nameLower = string.lower(tostring(missionTypeName or ""))

        local isGeneratable = classObject ~= nil and classObject.tryGenerateMission ~= nil
        local isAllowed = self:isAllowedMissionTypeName(missionTypeName)
        local isExcluded = string.find(nameLower, "bale", 1, true) ~= nil

        if missionTypeName ~= nil and isGeneratable and isAllowed and not isExcluded then
            table.insert(candidates, tostring(missionTypeName))
        end
    end

    return candidates
end

function NeighborFieldWorkers:findGeneratedMissionFromSnapshot(beforeKeys, expectedMissionTypeName)
    if g_missionManager == nil or g_missionManager.getMissions == nil then
        return nil
    end

    local expectedUpper = string.upper(tostring(expectedMissionTypeName or ""))
    local fallbackMission = nil

    for _, mission in ipairs(g_missionManager:getMissions()) do
        local missionKey = self:getMissionKey(mission)
        local keyWasPresent = missionKey ~= nil and beforeKeys ~= nil and beforeKeys[tostring(missionKey)] == true
        if missionKey ~= nil and not keyWasPresent and mission.status == MissionStatus.CREATED and mission.farmId == nil then
            local missionTypeName = self:getMissionTypeName(mission)
            if self:isAllowedMissionTypeName(missionTypeName) then
                local canStart, startReason = self:canMissionBeStartedWithVehicles(mission)
                if canStart then
                    if expectedUpper ~= "" and string.upper(tostring(missionTypeName)) == expectedUpper then
                        return mission
                    end
                    if fallbackMission == nil then
                        fallbackMission = mission
                    end
                else
                    nfwLogInfo(
                        "[%s] MissionGen: neue Mission nicht startbar -> skip mission=%s type=%s reason=%s",
                        self.MOD_NAME,
                        tostring(missionKey),
                        tostring(missionTypeName),
                        tostring(startReason)
                    )
                end
            end
        end
    end

    return fallbackMission
end

function NeighborFieldWorkers:isFieldContractEligibleForGeneration(field)
    if field == nil then
        return false, "FIELD_NIL"
    end

    if field.currentMission ~= nil then
        return false, "FIELD_HAS_CURRENT_MISSION"
    end

    if not Utils.getNoNil(field.isMissionAllowed, true) then
        return false, "MISSION_NOT_ALLOWED"
    end

    if field.getHasOwner ~= nil and field:getHasOwner() then
        return false, "FIELD_HAS_OWNER"
    end

    return true, "OK"
end

function NeighborFieldWorkers:isMissionTypeFieldReadyWithoutPreparation(missionTypeName, field)
    if missionTypeName == nil or field == nil then
        return false, "MISSION_TYPE_OR_FIELD_NIL"
    end

    if field.getFieldState == nil then
        return true, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(field.getFieldState, field)
    if not okState or fieldState == nil then
        return true, "FIELD_STATE_UNAVAILABLE"
    end

    local nameLower = string.lower(tostring(missionTypeName))
    if string.find(nameLower, "harvest", 1, true) ~= nil then
        return self:isHarvestFieldStateSuitableWithoutPreparation(fieldState)
    end

    if string.find(nameLower, "mow", 1, true) ~= nil then
        return self:isMowFieldStateSuitableWithoutPreparation(fieldState)
    end

    if string.find(nameLower, "ted", 1, true) ~= nil
        or string.find(nameLower, "windrow", 1, true) ~= nil
        or string.find(nameLower, "turn", 1, true) ~= nil
        or string.find(nameLower, "wend", 1, true) ~= nil then
        return self:isTurnFieldStateSuitableWithoutPreparation(fieldState)
    end

    if string.find(nameLower, "sow", 1, true) ~= nil or string.find(nameLower, "seed", 1, true) ~= nil then
        return self:isSowFieldStateSuitableWithoutPreparation(fieldState)
    end

    if string.find(nameLower, "fertiliz", 1, true) ~= nil then
        return self:isFertilizeFieldStateSuitableWithoutPreparation(fieldState)
    end

    if string.find(nameLower, "herbicid", 1, true) ~= nil
        or string.find(nameLower, "spray", 1, true) ~= nil then
        return self:isSprayFieldStateSuitableWithoutPreparation(fieldState)
    end

    if string.find(nameLower, "stonepick", 1, true) ~= nil or string.find(nameLower, "stone", 1, true) ~= nil then
        return self:isStoneFieldStateSuitableWithoutPreparation(fieldState)
    end

    if string.find(nameLower, "plow", 1, true) ~= nil or string.find(nameLower, "cultivat", 1, true) ~= nil then
        return self:isFieldStateDeadEmptyOrEarlyForSoilWork(fieldState)
    end

    if string.find(nameLower, "hoe", 1, true) ~= nil then
        return self:isHoeFieldStateSuitableWithoutPreparation(fieldState)
    end

    if string.find(nameLower, "weed", 1, true) ~= nil then
        return self:isWeedMissionFieldStateSuitableWithoutPreparation(fieldState)
    end

    return true, "NO_EXTRA_STATE_CHECK"
end

function NeighborFieldWorkers:hasReadyFieldCandidateForMissionType(missionTypeName)
    if missionTypeName == nil
        or g_missionManager == nil
        or g_fieldManager == nil
        or g_fieldManager.fields == nil then
        return false, 0, 0, 0, "MISSING_MANAGER"
    end

    local missionType = g_missionManager:getMissionType(missionTypeName)
    local classObject = missionType ~= nil and missionType.classObject or nil

    local inspectedFields = 0
    local availableFields = 0
    local readyFields = 0

    for _, field in pairs(g_fieldManager.fields) do
        if self:isFieldContractEligibleForGeneration(field) then
            inspectedFields = inspectedFields + 1

            local canUseField = true
            if classObject ~= nil and classObject.isAvailableForField ~= nil then
                local okAvailable, isAvailable = self:callMissionTypeIsAvailableForField(classObject, field)
                canUseField = okAvailable and isAvailable
            end

            if canUseField then
                availableFields = availableFields + 1
                local readyByState = self:isMissionTypeFieldReadyWithoutPreparation(missionTypeName, field)
                if readyByState == true then
                    readyFields = readyFields + 1
                    return true, inspectedFields, availableFields, readyFields, "READY_FIELD_FOUND"
                end
            end
        end
    end

    return false, inspectedFields, availableFields, readyFields, "NO_READY_FIELD"
end

function NeighborFieldWorkers:hasAnyReadyFieldCandidateAcrossTypes(missionTypeNames)
    if type(missionTypeNames) ~= "table" or #missionTypeNames <= 0 then
        return false, nil, "NO_TYPES"
    end

    for _, missionTypeName in ipairs(missionTypeNames) do
        local hasReady, inspected, available, ready, reason = self:hasReadyFieldCandidateForMissionType(missionTypeName)
        if hasReady then
            return true, missionTypeName, string.format(
                "inspected=%s available=%s ready=%s reason=%s",
                tostring(inspected),
                tostring(available),
                tostring(ready),
                tostring(reason)
            )
        end
    end

    return false, nil, "NO_READY_FIELDS_ACROSS_TYPES"
end

function NeighborFieldWorkers:isMissionStillRegistered(mission)
    if mission == nil or g_missionManager == nil or g_missionManager.missions == nil then
        return false
    end

    for _, existingMission in ipairs(g_missionManager.missions) do
        if existingMission == mission then
            return true
        end
    end

    return false
end

function NeighborFieldWorkers:registerMissionAndValidateGenerated(mission, missionType, missionTypeName, generatorTag)
    if mission == nil or missionType == nil or g_missionManager == nil then
        return false
    end

    g_missionManager:registerMission(mission, missionType)

    if g_missionManager.updateMissions ~= nil then
        pcall(g_missionManager.updateMissions, g_missionManager, 0)
    end

    local isRegistered = self:isMissionStillRegistered(mission)
    if not isRegistered then
        nfwLogInfo(
            "[%s] MissionGen[%s]: Mission nach Registrierung direkt entfernt type=%s",
            self.MOD_NAME,
            tostring(generatorTag),
            tostring(missionTypeName)
        )
    end

    return isRegistered
end

function NeighborFieldWorkers:callMissionTypeIsAvailableForField(classObject, field)
    if classObject == nil or classObject.isAvailableForField == nil then
        return true, true
    end

    local attempts = {}

    local function addAttempt(label, ok, valueOrError)
        attempts[#attempts + 1] = {
            label = label,
            ok = ok == true,
            value = valueOrError == true
        }
    end

    local ok1, res1 = pcall(classObject.isAvailableForField, field, nil)
    addAttempt("dot(field,nil)", ok1, res1)

    local ok2, res2 = pcall(classObject.isAvailableForField, field)
    addAttempt("dot(field)", ok2, res2)

    local ok3, res3 = pcall(classObject.isAvailableForField, classObject, field, nil)
    addAttempt("self(class,field,nil)", ok3, res3)

    local ok4, res4 = pcall(classObject.isAvailableForField, classObject, field)
    addAttempt("self(class,field)", ok4, res4)

    local anySuccess = false
    local anyTrue = false
    local anyFalse = false
    local diagParts = {}

    for _, attempt in ipairs(attempts) do
        if attempt.ok then
            anySuccess = true
            if attempt.value == true then
                anyTrue = true
            else
                anyFalse = true
            end
            diagParts[#diagParts + 1] = string.format("%s=%s", tostring(attempt.label), tostring(attempt.value))
        end
    end

    if anySuccess then
        if NFW_MISSION_DEBUG_LOG_ENABLED and anyTrue and anyFalse then
            nfwLogMissionDebug(
                "[%s] MissionGen[MISSION_DEBUG]: isAvailableForField mixedResult class=%s field=%s attempts={%s}",
                self.MOD_NAME,
                tostring(classObject.NAME),
                tostring(self:getFieldIdTextForMissionGen(field)),
                table.concat(diagParts, ";")
            )
        end

        return true, anyTrue
    end

    return false, false
end

function NeighborFieldWorkers:tryGenerateMissionOnFieldInternal(classObject, field, missionTypeName)
    if classObject == nil or classObject.tryGenerateMission == nil then
        return nil
    end

    local function callTryGenerateMission()
        local success, missionOrError = pcall(classObject.tryGenerateMission)
        if success then
            return true, missionOrError
        end

        local successWithSelf, missionWithSelf = pcall(classObject.tryGenerateMission, classObject)
        if successWithSelf then
            return true, missionWithSelf
        end

        return false, missionOrError
    end

    if g_fieldManager == nil or g_fieldManager.getFieldForMission == nil or field == nil then
        local success, mission = callTryGenerateMission()
        if success then
            return mission
        end

        nfwLogInfo(
            "[%s] MissionGen[INTERNAL]: tryGenerateMission Fehler type=%s err=%s",
            self.MOD_NAME,
            tostring(missionTypeName),
            nfwToSingleLineText(mission, 240)
        )
        return nil
    end

    local originalGetFieldForMission = g_fieldManager.getFieldForMission
    local getFieldForMissionKey = "getFieldForMission"
    g_fieldManager[getFieldForMissionKey] = function(_)
        return field
    end

    local success, mission = callTryGenerateMission()
    g_fieldManager[getFieldForMissionKey] = originalGetFieldForMission

    if success then
        return mission
    end

    nfwLogInfo(
        "[%s] MissionGen[INTERNAL]: tryGenerateMission auf erzwungenem Feld fehlgeschlagen type=%s err=%s",
        self.MOD_NAME,
        tostring(missionTypeName),
        nfwToSingleLineText(mission, 240)
    )
    return nil
end

function NeighborFieldWorkers:isFruitHarvestableInCurrentPeriodForMissionGen(fruit, growthMode, period)
    if fruit == nil then
        return false
    end

    local minHarvest = fruit.minHarvestingGrowthState or 0
    local maxHarvest = fruit.maxHarvestingGrowthState or 0
    if minHarvest <= 0 or maxHarvest <= 0 then
        return false
    end

    if growthMode ~= nil and period ~= nil then
        if fruit.getIsHarvestableInPeriod ~= nil then
            local success, isHarvestable = pcall(fruit.getIsHarvestableInPeriod, fruit, growthMode, period)
            if success and type(isHarvestable) == "boolean" then
                return isHarvestable
            end

            local swappedSuccess, isHarvestableSwapped = pcall(fruit.getIsHarvestableInPeriod, fruit, period, growthMode)
            if swappedSuccess and type(isHarvestableSwapped) == "boolean" then
                return isHarvestableSwapped
            end
        end

        local periodTableCandidates = {
            fruit.harvestPeriods,
            fruit.harvestingPeriods,
            fruit.harvestPeriod
        }

        for _, periodTable in ipairs(periodTableCandidates) do
            if type(periodTable) == "table" then
                local periodValue = periodTable[period]
                if periodValue ~= nil then
                    return periodValue == true or periodValue == 1
                end
            end
        end
    end

    if fruit.getRandomInitialState ~= nil and growthMode ~= nil then
        local randomSuccess, randomState = pcall(fruit.getRandomInitialState, fruit, growthMode)
        if randomSuccess and type(randomState) == "number" then
            return randomState >= minHarvest and randomState <= maxHarvest
        end
    end

    return true
end

function NeighborFieldWorkers:getHarvestableMissionFruitsForCurrentPeriodForMissionGen()
    local harvestableFruits = {}
    local addedByIndex = {}

    local growthMode = g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and
        g_currentMission.missionInfo.growthMode or nil
    local currentPeriod = g_currentMission ~= nil and g_currentMission.environment ~= nil and
        g_currentMission.environment.currentPeriod or nil
    local grassIndex = FruitType ~= nil and FruitType.GRASS or nil
    local unknownIndex = FruitType ~= nil and FruitType.UNKNOWN or nil

    local function tryAddFruitByIndex(fruitTypeIndex)
        if fruitTypeIndex == nil or addedByIndex[fruitTypeIndex] then
            return
        end

        local fruit = g_fruitTypeManager ~= nil
            and g_fruitTypeManager.getFruitTypeByIndex ~= nil
            and g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
            or nil
        if fruit == nil then
            return
        end

        if (grassIndex ~= nil and fruit.index == grassIndex) or (unknownIndex ~= nil and fruit.index == unknownIndex) then
            return
        end

        local isCatchCrop = false
        if fruit.getIsCatchCrop ~= nil then
            local success, result = pcall(fruit.getIsCatchCrop, fruit)
            if success then
                isCatchCrop = result == true
            end
        end

        if isCatchCrop then
            return
        end

        if self:isFruitHarvestableInCurrentPeriodForMissionGen(fruit, growthMode, currentPeriod) then
            table.insert(harvestableFruits, fruit)
            addedByIndex[fruitTypeIndex] = true
        end
    end

    if g_fieldManager ~= nil and type(g_fieldManager.availableFruitTypeIndices) == "table" then
        for _, fruitTypeIndex in ipairs(g_fieldManager.availableFruitTypeIndices) do
            tryAddFruitByIndex(fruitTypeIndex)
        end
    elseif g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypes ~= nil then
        for _, fruit in ipairs(g_fruitTypeManager:getFruitTypes() or {}) do
            if fruit ~= nil and fruit.useForFieldMissions and fruit.allowsSeeding then
                tryAddFruitByIndex(fruit.index)
            end
        end
    end

    return harvestableFruits
end

function NeighborFieldWorkers:isFieldStateHarvestReadyForMissionGen(fieldState)
    if fieldState == nil then
        return false
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    if fruitSignals.hasEffectiveFruit ~= true then
        return false
    end

    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    if fruitTypeIndex == nil or (FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return false
    end

    local growthState = tonumber(fieldState.growthState) or 0
    if growthState <= 0 then
        return false
    end

    local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
    if fruitTypeDesc == nil then
        return false
    end

    if self:isFruitGrowthWithered(fruitTypeDesc, growthState) then
        return false
    end

    local minHarvest = tonumber(fruitTypeDesc.minHarvestingGrowthState) or 0
    local maxHarvest = tonumber(fruitTypeDesc.maxHarvestingGrowthState) or 0
    return minHarvest > 0 and maxHarvest > 0 and growthState >= minHarvest and growthState <= maxHarvest
end

function NeighborFieldWorkers:isFieldStatePreparedForSowingForMissionGen(fieldState)
    if fieldState == nil then
        return false
    end

    if fieldState.canBeSown == true then
        return true
    end

    local groundType = fieldState.groundType
    if FieldGroundType ~= nil then
        if groundType == FieldGroundType.PLOWED
            or groundType == FieldGroundType.CULTIVATED
            or groundType == FieldGroundType.SEEDBED
            or groundType == FieldGroundType.ROLLED_SEEDBED
            or (FieldGroundType.RIDGE ~= nil and groundType == FieldGroundType.RIDGE)
            or (FieldGroundType.RIDGE_SOWN ~= nil and groundType == FieldGroundType.RIDGE_SOWN) then
            return true
        end
    end

    return false
end

function NeighborFieldWorkers:isFieldEligibleForForcedPrepareByMissionTypeInternal(missionTypeName, field)
    if missionTypeName == nil or field == nil then
        return false, "MISSION_TYPE_OR_FIELD_NIL"
    end

    local nameLower = string.lower(tostring(missionTypeName))

    if field.getFieldState == nil then
        return false, "NO_FIELD_STATE_API"
    end

    local okState, fieldState = pcall(field.getFieldState, field)
    if not okState or fieldState == nil then
        return false, "FIELD_STATE_UNAVAILABLE"
    end

    local isFertilize = string.find(nameLower, "fertiliz", 1, true) ~= nil
    local isSpray = string.find(nameLower, "herbicid", 1, true) ~= nil
        or string.find(nameLower, "spray", 1, true) ~= nil
    local isMow = string.find(nameLower, "mow", 1, true) ~= nil
    local isSow = string.find(nameLower, "sow", 1, true) ~= nil
        or string.find(nameLower, "seed", 1, true) ~= nil
    local isTurn = string.find(nameLower, "ted", 1, true) ~= nil
        or string.find(nameLower, "windrow", 1, true) ~= nil
        or string.find(nameLower, "turn", 1, true) ~= nil
        or string.find(nameLower, "wend", 1, true) ~= nil
    local isHarvest = string.find(nameLower, "harvest", 1, true) ~= nil
    local isStone = string.find(nameLower, "stonepick", 1, true) ~= nil
        or string.find(nameLower, "stone", 1, true) ~= nil
    local isHoe = string.find(nameLower, "hoe", 1, true) ~= nil
    local isWeed = string.find(nameLower, "weed", 1, true) ~= nil

    if isFertilize or isSpray then
        if self:isFieldStateHarvestReadyForMissionGen(fieldState) then
            return false, "HARVEST_READY"
        end
        return true, "OK"
    end

    if isMow then
        local grassNotCut = self:isFieldStateGrassLikeAndNotCutForMissionGen(fieldState)
        if grassNotCut then
            return true, "MOW_GRASS_NOT_CUT"
        end

        if self:isFieldStateNoFruitOrDeadForMissionGen(fieldState) then
            return true, "MOW_NO_FRUIT_OR_DEAD"
        end

        return false, "MOW_FILTER_NO_MATCH"
    end

    if isTurn then
        local grassNotCut = self:isFieldStateGrassLikeAndNotCutForMissionGen(fieldState)
        if grassNotCut then
            return true, "TURN_GRASS_NOT_CUT"
        end

        if self:isFieldStateNoFruitOrDeadForMissionGen(fieldState) then
            return true, "TURN_NO_FRUIT_OR_DEAD"
        end

        return false, "TURN_FILTER_NO_MATCH"
    end

    if isSow then
        if self:isFieldStateNoFruitOrDeadForMissionGen(fieldState) then
            return true, "SOW_NO_FRUIT_OR_DEAD"
        end

        if self:isFieldStateGrassLikeForMissionGen(fieldState) then
            return true, "SOW_GRASS_LIKE"
        end

        return false, "SOW_FILTER_NO_MATCH"
    end

    if isHarvest then
        if self:isFieldStateNoFruitOrDeadForMissionGen(fieldState) then
            return true, "HARVEST_NO_FRUIT_OR_DEAD"
        end

        if self:isFieldStateGrassLikeForMissionGen(fieldState) then
            return true, "HARVEST_GRASS_LIKE"
        end

        return false, "HARVEST_FILTER_NO_MATCH"
    end

    if isStone then
        if self:isFieldStateNoFruitOrDeadForMissionGen(fieldState) then
            return true, "STONE_NO_FRUIT_OR_DEAD"
        end

        return false, "STONE_FILTER_NO_MATCH"
    end

    if isHoe or isWeed then
        local cropOk = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)
        if cropOk then
            return true, "WEED_CTRL_CROP_ALIVE"
        end

        if self:isFieldStateNoFruitOrDeadForMissionGen(fieldState) then
            return true, "WEED_CTRL_NO_FRUIT_OR_DEAD"
        end

        return false, "WEED_CTRL_FILTER_NO_MATCH"
    end

    local isPlowOrCultivate = string.find(nameLower, "plow", 1, true) ~= nil
        or string.find(nameLower, "cultivat", 1, true) ~= nil
    if not isPlowOrCultivate then
        return true, "NO_TYPE_SPECIFIC_FILTER"
    end

    if self:isFieldStateHarvestReadyForMissionGen(fieldState) then
        return false, "HARVEST_READY"
    end

    if self:isFieldStatePreparedForSowingForMissionGen(fieldState) then
        return false, "ALREADY_SEEDBED_OR_CAN_BE_SOWN"
    end

    return true, "OK"
end

function NeighborFieldWorkers:isMissionTypeFertilizeOrSprayForMissionGen(missionTypeName)
    local nameLower = string.lower(tostring(missionTypeName or ""))
    return string.find(nameLower, "fertiliz", 1, true) ~= nil
        or string.find(nameLower, "herbicid", 1, true) ~= nil
        or string.find(nameLower, "spray", 1, true) ~= nil
        or string.find(nameLower, "sow", 1, true) ~= nil
        or string.find(nameLower, "seed", 1, true) ~= nil
        or string.find(nameLower, "plow", 1, true) ~= nil
        or string.find(nameLower, "cultivat", 1, true) ~= nil
        or string.find(nameLower, "mow", 1, true) ~= nil
        or string.find(nameLower, "ted", 1, true) ~= nil
        or string.find(nameLower, "windrow", 1, true) ~= nil
        or string.find(nameLower, "turn", 1, true) ~= nil
        or string.find(nameLower, "wend", 1, true) ~= nil
        or string.find(nameLower, "harvest", 1, true) ~= nil
        or string.find(nameLower, "stonepick", 1, true) ~= nil
        or string.find(nameLower, "stone", 1, true) ~= nil
        or string.find(nameLower, "hoe", 1, true) ~= nil
        or string.find(nameLower, "weed", 1, true) ~= nil
end

function NeighborFieldWorkers:getMissionPreparationFruitCandidatesForCurrentPeriodForMissionGen()
    local candidates = {}
    local growthMode = g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and
        g_currentMission.missionInfo.growthMode or nil
    local currentPeriod = g_currentMission ~= nil and g_currentMission.environment ~= nil and
        g_currentMission.environment.currentPeriod or nil

    if g_fruitTypeManager == nil or g_fruitTypeManager.getFruitTypes == nil then
        return candidates
    end

    local function isPlantableInCurrentPeriod(fruit)
        if fruit == nil then
            return false
        end

        if growthMode == nil or currentPeriod == nil then
            return true
        end

        if fruit.getIsPlantableInPeriod ~= nil then
            local okPlant, canPlant = pcall(fruit.getIsPlantableInPeriod, fruit, growthMode, currentPeriod)
            if okPlant and type(canPlant) == "boolean" then
                return canPlant
            end

            local okPlantSwapped, canPlantSwapped = pcall(fruit.getIsPlantableInPeriod, fruit, currentPeriod, growthMode)
            if okPlantSwapped and type(canPlantSwapped) == "boolean" then
                return canPlantSwapped
            end
        end

        local periodTables = {
            fruit.plantPeriods,
            fruit.plantingPeriods,
            fruit.plantPeriod,
            fruit.sowingPeriods,
            fruit.sowingPeriod,
            fruit.sowPeriods
        }

        for _, periodTable in ipairs(periodTables) do
            if type(periodTable) == "table" then
                local value = periodTable[currentPeriod]
                if value ~= nil then
                    return value == true or value == 1
                end
            end
        end

        return false
    end

    for _, fruit in ipairs(g_fruitTypeManager:getFruitTypes() or {}) do
        if fruit ~= nil and fruit.useForFieldMissions ~= false and fruit.allowsSeeding == true then
            local isCatchCrop = false
            if fruit.getIsCatchCrop ~= nil then
                local okCatch, catch = pcall(fruit.getIsCatchCrop, fruit)
                if okCatch and catch == true then
                    isCatchCrop = true
                end
            end

            if not isCatchCrop then
                local canPlant = isPlantableInCurrentPeriod(fruit)
                local canGrow = self:isFruitHarvestableInCurrentPeriodForMissionGen(fruit, growthMode, currentPeriod)
                if canPlant or canGrow then
                    table.insert(candidates, {
                        fruit = fruit,
                        canPlant = canPlant,
                        canGrow = canGrow
                    })
                end
            end
        end
    end

    return candidates
end

function NeighborFieldWorkers:buildPreparedCropFieldStateForMissionGen()
    local candidates = self:getMissionPreparationFruitCandidatesForCurrentPeriodForMissionGen()
    if #candidates <= 0 then
        return nil
    end

    local plantable = {}
    local growable = {}
    for _, entry in ipairs(candidates) do
        if entry.canPlant == true then
            table.insert(plantable, entry)
        else
            table.insert(growable, entry)
        end
    end

    local selectionPool = #plantable > 0 and plantable or growable
    if #selectionPool <= 0 then
        return nil
    end

    for i = #selectionPool, 2, -1 do
        local j = math.random(1, i)
        selectionPool[i], selectionPool[j] = selectionPool[j], selectionPool[i]
    end

    local selected = selectionPool[1]
    if selected == nil or selected.fruit == nil then
        return nil
    end

    local fruit = selected.fruit
    local growthMode = g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and
        g_currentMission.missionInfo.growthMode or nil

    local growthState = nil
    if fruit.getRandomInitialState ~= nil then
        local okRandom, randomState = pcall(fruit.getRandomInitialState, fruit, growthMode)
        if okRandom and type(randomState) == "number" then
            growthState = math.floor(randomState)
        end
    end

    if type(growthState) ~= "number" or growthState <= 0 then
        local minHarvest = tonumber(fruit.minHarvestingGrowthState) or 0
        if selected.canPlant == true then
            growthState = 1
        elseif minHarvest > 1 then
            growthState = minHarvest - 1
        else
            growthState = 1
        end
    end

    local minHarvest = tonumber(fruit.minHarvestingGrowthState) or 0
    local maxHarvest = tonumber(fruit.maxHarvestingGrowthState) or 0
    if minHarvest > 0 and maxHarvest > 0 and growthState >= minHarvest and growthState <= maxHarvest then
        growthState = math.max(1, minHarvest - 1)
    end

    if self:isFruitGrowthWithered(fruit, growthState) then
        growthState = 1
        if self:isFruitGrowthWithered(fruit, growthState) and minHarvest > 1 then
            growthState = minHarvest - 1
        end
    end

    local groundType = (FieldGroundType ~= nil and FieldGroundType.CULTIVATED) or 0
    if fruit.getGrowthStateGroundType ~= nil then
        local okGround, fruitGroundType = pcall(fruit.getGrowthStateGroundType, fruit, growthState)
        if okGround and fruitGroundType ~= nil then
            groundType = fruitGroundType
        end
    end

    return {
        fruitTypeIndex = fruit.index,
        growthState = growthState,
        groundType = groundType,
        sprayType = (FieldSprayType ~= nil and FieldSprayType.NONE) or 0
    }
end

function NeighborFieldWorkers:isFieldStateNoFruitOrDeadForMissionGen(fieldState)
    if fieldState == nil then
        return false
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    if fruitSignals.hasEffectiveFruit ~= true then
        return true
    end

    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    local growthState = tonumber(fieldState.growthState) or 0
    if fruitTypeIndex == nil or (FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return true
    end

    if growthState <= 0 then
        return true
    end

    local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
    if fruitTypeDesc == nil then
        return true
    end

    return self:isFruitGrowthWithered(fruitTypeDesc, growthState)
end

function NeighborFieldWorkers:isFieldStateGrassLikeForMissionGen(fieldState)
    if fieldState == nil then
        return false
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    if fruitSignals.hasEffectiveFruit ~= true then
        return false
    end

    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    local growthState = tonumber(fieldState.growthState) or 0
    if fruitTypeIndex == nil or (FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return false
    end

    if growthState <= 0 then
        return false
    end

    local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
    if fruitTypeDesc == nil then
        return false
    end

    if not self:isFruitTypeGrassLikeForMowMission(fruitTypeDesc) then
        return false
    end

    return not self:isFruitGrowthWithered(fruitTypeDesc, growthState)
end

function NeighborFieldWorkers:isGroundTypeRidgeForMissionGen(groundType)
    if groundType == nil or FieldGroundType == nil then
        return false
    end

    if FieldGroundType.RIDGE ~= nil and groundType == FieldGroundType.RIDGE then
        return true
    end

    if FieldGroundType.RIDGE_SOWN ~= nil and groundType == FieldGroundType.RIDGE_SOWN then
        return true
    end

    if FieldGroundType.RIDGE_PLANTED ~= nil and groundType == FieldGroundType.RIDGE_PLANTED then
        return true
    end

    return false
end

function NeighborFieldWorkers:getSowForcedPrepareGroundTypeForMissionGen()
    local groundTypeCandidates = {}

    local function addGroundTypeCandidate(groundType)
        if groundType == nil then
            return
        end

        for _, existing in ipairs(groundTypeCandidates) do
            if existing == groundType then
                return
            end
        end

        table.insert(groundTypeCandidates, groundType)
    end

    if FieldGroundType ~= nil then
        addGroundTypeCandidate(FieldGroundType.CULTIVATED)
        addGroundTypeCandidate(FieldGroundType.PLOWED)
        addGroundTypeCandidate(FieldGroundType.SEEDBED)
        addGroundTypeCandidate(FieldGroundType.ROLLED_SEEDBED)
    end

    local ridgeIsSeasonallyUseful = false
    local sowCandidates = self:getMissionPreparationFruitCandidatesForCurrentPeriodForMissionGen()
    for _, entry in ipairs(sowCandidates) do
        if entry ~= nil and entry.canPlant == true and entry.fruit ~= nil and entry.fruit.getGrowthStateGroundType ~= nil then
            local okGround, groundType = pcall(entry.fruit.getGrowthStateGroundType, entry.fruit, 1)
            if okGround and self:isGroundTypeRidgeForMissionGen(groundType) then
                ridgeIsSeasonallyUseful = true
                break
            end
        end
    end

    if ridgeIsSeasonallyUseful and FieldGroundType ~= nil then
        if FieldGroundType.RIDGE ~= nil then
            addGroundTypeCandidate(FieldGroundType.RIDGE)
        elseif FieldGroundType.RIDGE_SOWN ~= nil then
            addGroundTypeCandidate(FieldGroundType.RIDGE_SOWN)
        end
    end

    if #groundTypeCandidates <= 0 then
        return (FieldGroundType ~= nil and FieldGroundType.CULTIVATED) or 0
    end

    return groundTypeCandidates[math.random(1, #groundTypeCandidates)]
end

function NeighborFieldWorkers:isGrassFruitStateCutForMissionGen(fruitTypeDesc, growthState, groundType)
    if fruitTypeDesc == nil then
        return false
    end

    local isCutState = false
    if fruitTypeDesc.getIsCut ~= nil then
        local okCut, cut = pcall(fruitTypeDesc.getIsCut, fruitTypeDesc, growthState)
        if okCut and cut == true then
            isCutState = true
        end
    end

    if not isCutState and type(fruitTypeDesc.cutStates) == "table" and fruitTypeDesc.cutStates[growthState] == true then
        isCutState = true
    end

    if not isCutState and type(fruitTypeDesc.cutState) == "number" and fruitTypeDesc.cutState > 0 and growthState == fruitTypeDesc.cutState then
        isCutState = true
    end

    if not isCutState and FieldGroundType ~= nil and FieldGroundType.GRASS_CUT ~= nil and groundType == FieldGroundType.GRASS_CUT then
        isCutState = true
    end

    return isCutState
end

function NeighborFieldWorkers:isFieldStateGrassLikeAndNotCutForMissionGen(fieldState)
    if fieldState == nil then
        return false
    end

    local fruitSignals = self:getFieldStateFruitSignals(fieldState)
    if fruitSignals.hasEffectiveFruit ~= true then
        return false
    end

    local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
    local growthState = tonumber(fieldState.growthState) or 0
    if fruitTypeIndex == nil or (FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN) then
        return false
    end

    if growthState <= 0 then
        return false
    end

    local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
    if fruitTypeDesc == nil then
        return false
    end

    if not self:isFruitTypeGrassLikeForMowMission(fruitTypeDesc) then
        return false
    end

    if self:isFruitGrowthWithered(fruitTypeDesc, growthState) then
        return false
    end

    local isCutState = self:isGrassFruitStateCutForMissionGen(fruitTypeDesc, growthState, fieldState.groundType)
    return not isCutState
end

function NeighborFieldWorkers:getDefaultGrassFruitForMissionGen()
    local grassIndex = FruitType ~= nil and FruitType.GRASS or nil
    if grassIndex ~= nil then
        local grassFruit = self:getFruitTypeByIndexSafe(grassIndex)
        if grassFruit ~= nil then
            return grassFruit
        end
    end

    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypes ~= nil then
        for _, fruit in ipairs(g_fruitTypeManager:getFruitTypes() or {}) do
            if self:isFruitTypeGrassLikeForMowMission(fruit) then
                return fruit
            end
        end
    end

    return nil
end

function NeighborFieldWorkers:getMowReadyGrowthStateForFruitForMissionGen(fruitTypeDesc)
    if fruitTypeDesc == nil then
        return 1
    end

    local maxHarvest = tonumber(fruitTypeDesc.maxHarvestingGrowthState) or 0
    if maxHarvest > 0 then
        return maxHarvest
    end

    local minHarvest = tonumber(fruitTypeDesc.minHarvestingGrowthState) or 0
    if minHarvest > 0 then
        return minHarvest
    end

    return 1
end

function NeighborFieldWorkers:getForcedPrepareMowStateForFieldInternal(fieldState)
    if fieldState == nil then
        return nil
    end

    if self:isFieldStateGrassLikeAndNotCutForMissionGen(fieldState) then
        local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
        local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
        if fruitTypeDesc == nil then
            return nil
        end

        return {
            fruitTypeIndex = fruitTypeIndex,
            growthState = self:getMowReadyGrowthStateForFruitForMissionGen(fruitTypeDesc)
        }
    end

    if self:isFieldStateNoFruitOrDeadForMissionGen(fieldState) then
        local grassFruit = self:getDefaultGrassFruitForMissionGen()
        if grassFruit == nil then
            return nil
        end

        local growthState = self:getMowReadyGrowthStateForFruitForMissionGen(grassFruit)
        local state = {
            fruitTypeIndex = grassFruit.index,
            growthState = growthState
        }

        if grassFruit.getGrowthStateGroundType ~= nil then
            local okGround, groundType = pcall(grassFruit.getGrowthStateGroundType, grassFruit, growthState)
            if okGround and groundType ~= nil then
                state.groundType = groundType
            end
        end

        return state
    end

    return nil
end

function NeighborFieldWorkers:getTurnReadyGrowthStateForFruitForMissionGen(fruitTypeDesc)
    if fruitTypeDesc == nil then
        return 1
    end

    local cutState = tonumber(fruitTypeDesc.cutState)
    if cutState ~= nil and cutState > 0 then
        return cutState
    end

    if type(fruitTypeDesc.cutStates) == "table" then
        local minCutState = nil
        for stateIndex, isCut in pairs(fruitTypeDesc.cutStates) do
            if isCut == true then
                local numericState = tonumber(stateIndex)
                if numericState ~= nil and numericState > 0 and (minCutState == nil or numericState < minCutState) then
                    minCutState = numericState
                end
            end
        end
        if minCutState ~= nil then
            return minCutState
        end
    end

    return 1
end

function NeighborFieldWorkers:getForcedPrepareTurnStateForFieldInternal(fieldState)
    if fieldState == nil then
        return nil
    end

    if self:isFieldStateGrassLikeAndNotCutForMissionGen(fieldState) then
        local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
        local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
        if fruitTypeDesc == nil then
            return nil
        end

        return {
            fruitTypeIndex = fruitTypeIndex,
            growthState = self:getTurnReadyGrowthStateForFruitForMissionGen(fruitTypeDesc)
        }
    end

    if self:isFieldStateNoFruitOrDeadForMissionGen(fieldState) then
        local grassFruit = self:getDefaultGrassFruitForMissionGen()
        if grassFruit == nil then
            return nil
        end

        local growthState = self:getTurnReadyGrowthStateForFruitForMissionGen(grassFruit)
        local state = {
            fruitTypeIndex = grassFruit.index,
            growthState = growthState
        }

        if grassFruit.getGrowthStateGroundType ~= nil then
            local okGround, groundType = pcall(grassFruit.getGrowthStateGroundType, grassFruit, growthState)
            if okGround and groundType ~= nil then
                state.groundType = groundType
            end
        end

        return state
    end

    return nil
end

function NeighborFieldWorkers:buildPreparedHarvestStateForMissionGen()
    local harvestFruits = self:getHarvestableMissionFruitsForCurrentPeriodForMissionGen()
    if #harvestFruits <= 0 then
        return nil
    end

    local selected = harvestFruits[math.random(1, #harvestFruits)]
    if selected == nil then
        return nil
    end

    local growthState = tonumber(selected.maxHarvestingGrowthState) or tonumber(selected.minHarvestingGrowthState) or 1
    if growthState <= 0 then
        growthState = 1
    end

    local groundType = (FieldGroundType ~= nil and FieldGroundType.CULTIVATED) or 0
    if selected.getGrowthStateGroundType ~= nil then
        local okGround, resolvedGroundType = pcall(selected.getGrowthStateGroundType, selected, growthState)
        if okGround and resolvedGroundType ~= nil then
            groundType = resolvedGroundType
        end
    end

    local weedState = math.random(0, 3)

    return {
        fruitTypeIndex = selected.index,
        growthState = growthState,
        groundType = groundType,
        weedState = weedState
    }
end

function NeighborFieldWorkers:buildPreparedCropFieldStateForMissionGenNonFresh()
    local candidates = self:getMissionPreparationFruitCandidatesForCurrentPeriodForMissionGen()
    if #candidates <= 0 then
        return nil
    end

    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    for _, entry in ipairs(candidates) do
        local fruit = entry ~= nil and entry.fruit or nil
        if fruit ~= nil and not self:isFruitTypeGrassLikeForMowMission(fruit) then
            local minHarvest = tonumber(fruit.minHarvestingGrowthState) or 0
            local maxHarvest = tonumber(fruit.maxHarvestingGrowthState) or 0

            local growthState = nil
            if minHarvest > 2 then
                growthState = minHarvest - 1
            elseif maxHarvest > 2 then
                growthState = math.min(maxHarvest - 1, math.max(2, minHarvest))
            else
                growthState = 2
            end

            if growthState ~= nil and growthState > 1 then
                if minHarvest > 0 and maxHarvest > 0 and growthState >= minHarvest and growthState <= maxHarvest then
                    growthState = minHarvest - 1
                end

                if growthState ~= nil and growthState > 1 and not self:isFruitGrowthWithered(fruit, growthState) then
                    local groundType = (FieldGroundType ~= nil and FieldGroundType.CULTIVATED) or 0
                    if fruit.getGrowthStateGroundType ~= nil then
                        local okGround, resolvedGroundType = pcall(fruit.getGrowthStateGroundType, fruit, growthState)
                        if okGround and resolvedGroundType ~= nil then
                            groundType = resolvedGroundType
                        end
                    end

                    return {
                        fruitTypeIndex = fruit.index,
                        growthState = growthState,
                        groundType = groundType
                    }
                end
            end
        end
    end

    return nil
end

function NeighborFieldWorkers:getWitheredGrowthStateForFruitForMissionGen(fruitTypeDesc, fallbackGrowthState)
    if fruitTypeDesc == nil then
        return nil
    end

    local witheredState = tonumber(fruitTypeDesc.witheredState)
    if witheredState ~= nil and witheredState > 0 then
        return math.floor(witheredState)
    end

    if fruitTypeDesc.getIsWithered == nil then
        return nil
    end

    local scanMax = tonumber(fruitTypeDesc.numGrowthStates) or tonumber(fruitTypeDesc.maxHarvestingGrowthState) or
        tonumber(fallbackGrowthState) or 0
    scanMax = math.max(scanMax + 8, 8)
    scanMax = math.min(scanMax, 24)

    for state = 1, scanMax do
        local okState, isWithered = pcall(fruitTypeDesc.getIsWithered, fruitTypeDesc, state)
        if okState and isWithered == true then
            return state
        end
    end

    return nil
end

function NeighborFieldWorkers:getForcedPrepareStateForMissionTypeAndFieldInternal(missionTypeName, field)
    if missionTypeName == nil or field == nil or field.getFieldState == nil then
        return nil
    end

    local okState, fieldState = pcall(field.getFieldState, field)
    if not okState or fieldState == nil then
        return nil
    end

    local nameLower = string.lower(tostring(missionTypeName))
    local isFertilize = string.find(nameLower, "fertiliz", 1, true) ~= nil
    local isSpray = string.find(nameLower, "herbicid", 1, true) ~= nil
        or string.find(nameLower, "spray", 1, true) ~= nil
    local isSow = string.find(nameLower, "sow", 1, true) ~= nil
        or string.find(nameLower, "seed", 1, true) ~= nil
    local isPlow = string.find(nameLower, "plow", 1, true) ~= nil
    local isCultivate = string.find(nameLower, "cultivat", 1, true) ~= nil
    local isMow = string.find(nameLower, "mow", 1, true) ~= nil
    local isTurn = string.find(nameLower, "ted", 1, true) ~= nil
        or string.find(nameLower, "windrow", 1, true) ~= nil
        or string.find(nameLower, "turn", 1, true) ~= nil
        or string.find(nameLower, "wend", 1, true) ~= nil
    local isHarvest = string.find(nameLower, "harvest", 1, true) ~= nil
    local isStone = string.find(nameLower, "stonepick", 1, true) ~= nil
        or string.find(nameLower, "stone", 1, true) ~= nil
    local isHoe = string.find(nameLower, "hoe", 1, true) ~= nil
    local isWeed = string.find(nameLower, "weed", 1, true) ~= nil

    if not isFertilize and not isSpray and not isSow and not isPlow and not isCultivate and not isMow and not isTurn and not isHarvest and not isStone and not isHoe and not isWeed then
        return nil
    end

    if isPlow then
        return {
            plowLevel = 0
        }
    end

    if isCultivate then
        local preparedState = {
            plowLevel = 0
        }

        local fruitSignals = self:getFieldStateFruitSignals(fieldState)
        if fruitSignals.hasEffectiveFruit == true then
            local fruitTypeIndex = tonumber(fieldState.fruitTypeIndex)
            local growthState = tonumber(fieldState.growthState) or 0
            local fruitTypeDesc = self:getFruitTypeByIndexSafe(fruitTypeIndex)
            local witheredState = self:getWitheredGrowthStateForFruitForMissionGen(fruitTypeDesc, growthState)

            if witheredState ~= nil and witheredState > 0 and fruitTypeIndex ~= nil then
                preparedState.fruitTypeIndex = fruitTypeIndex
                preparedState.growthState = witheredState

                if fruitTypeDesc ~= nil and fruitTypeDesc.getGrowthStateGroundType ~= nil then
                    local okGround, groundType = pcall(fruitTypeDesc.getGrowthStateGroundType, fruitTypeDesc, witheredState)
                    if okGround and groundType ~= nil then
                        preparedState.groundType = groundType
                    end
                end
            elseif FruitType ~= nil and FruitType.UNKNOWN ~= nil then
                preparedState.fruitTypeIndex = FruitType.UNKNOWN
                preparedState.growthState = 1
            end
        end

        return preparedState
    end

    if isMow then
        return self:getForcedPrepareMowStateForFieldInternal(fieldState)
    end

    if isTurn then
        return self:getForcedPrepareTurnStateForFieldInternal(fieldState)
    end

    if isSow then
        return {
            fruitTypeIndex = (FruitType ~= nil and FruitType.UNKNOWN) or nil,
            growthState = 1,
            groundType = self:getSowForcedPrepareGroundTypeForMissionGen(),
            sprayType = (FieldSprayType ~= nil and FieldSprayType.NONE) or 0,
            sprayLevel = 0,
            weedState = 0
        }
    end

    if isHarvest then
        return self:buildPreparedHarvestStateForMissionGen()
    end

    if isStone then
        local stoneMax = 0
        if g_currentMission ~= nil and g_currentMission.stoneSystem ~= nil and g_currentMission.stoneSystem.getMinMaxValues ~= nil then
            local _, maxStone = g_currentMission.stoneSystem:getMinMaxValues()
            stoneMax = tonumber(maxStone) or 0
        end

        local stoneLevel = 1
        if stoneMax > 1 then
            stoneLevel = math.random(1, stoneMax)
        end

        local groundType = (FieldGroundType ~= nil and FieldGroundType.PLOWED ~= nil and FieldGroundType.PLOWED)
            or ((FieldGroundType ~= nil and FieldGroundType.CULTIVATED) or 0)

        return {
            fruitTypeIndex = (FruitType ~= nil and FruitType.UNKNOWN) or nil,
            growthState = 1,
            groundType = groundType,
            weedState = 0,
            stoneLevel = stoneLevel
        }
    end

    local cropAlive = self:isFieldStateCropAliveAndNotHarvestReady(fieldState)

    if isHoe or isWeed then
        local weedLevel = isWeed and 1 or math.random(1, 3)
        if cropAlive then
            return {
                weedState = weedLevel
            }
        end

        local preparedState = self:buildPreparedCropFieldStateForMissionGenNonFresh()
        if preparedState == nil then
            return nil
        end

        preparedState.weedState = weedLevel
        return preparedState
    end

    if isFertilize then
        if cropAlive then
            return {
                sprayType = (FieldSprayType ~= nil and FieldSprayType.NONE) or 0,
                sprayLevel = 0
            }
        end

        local preparedState = self:buildPreparedCropFieldStateForMissionGen()
        if preparedState == nil then
            return nil
        end

        preparedState.sprayType = (FieldSprayType ~= nil and FieldSprayType.NONE) or 0
        preparedState.sprayLevel = 0
        return preparedState
    end

    if isSpray then
        local weedLevel = math.random(1, 3)
        if cropAlive then
            return {
                weedState = weedLevel
            }
        end

        local preparedState = self:buildPreparedCropFieldStateForMissionGen()
        if preparedState == nil then
            return nil
        end

        preparedState.weedState = weedLevel
        return preparedState
    end

    return nil
end

function NeighborFieldWorkers:getMissionPreparationStrategiesForTypeInternal(missionTypeName)
    local strategies = {}
    local lowerName = string.lower(tostring(missionTypeName or ""))
    local isHarvestMission = string.find(lowerName, "harvest", 1, true) ~= nil

    local fruitTypes = {}
    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypes ~= nil then
        fruitTypes = g_fruitTypeManager:getFruitTypes() or {}
    end

    local grassIndex = FruitType ~= nil and FruitType.GRASS or nil
    local unknownIndex = FruitType ~= nil and FruitType.UNKNOWN or nil

    local function findFruit(predicate)
        for _, fruit in ipairs(fruitTypes) do
            if fruit ~= nil and predicate(fruit) then
                return fruit
            end
        end

        return nil
    end

    local function getGroundTypeForFruit(fruit, growthState, fallback)
        if fruit ~= nil and fruit.getGrowthStateGroundType ~= nil then
            local groundType = fruit:getGrowthStateGroundType(growthState)
            if groundType ~= nil then
                return groundType
            end
        end

        return fallback
    end

    local cropFruit = findFruit(function(fruit)
        local isCatchCrop = false
        if fruit.getIsCatchCrop ~= nil then
            local ok, result = pcall(fruit.getIsCatchCrop, fruit)
            isCatchCrop = ok and result == true
        end
        return fruit.allowsSeeding and not isCatchCrop and (grassIndex == nil or fruit.index ~= grassIndex)
    end)

    local growthMode = g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and
        g_currentMission.missionInfo.growthMode or nil
    local currentPeriod = g_currentMission ~= nil and g_currentMission.environment ~= nil and
        g_currentMission.environment.currentPeriod or nil

    local grassFruit = nil
    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypeByIndex ~= nil and grassIndex ~= nil then
        grassFruit = g_fruitTypeManager:getFruitTypeByIndex(grassIndex)
    end
    if grassFruit == nil then
        grassFruit = findFruit(function(fruit)
            return self:isFruitTypeGrassLikeForMowMission(fruit)
                and self:isFruitHarvestableInCurrentPeriodForMissionGen(fruit, growthMode, currentPeriod)
        end)
    end

    local sprayTypeNone = (FieldSprayType ~= nil and FieldSprayType.NONE) or 0
    local groundCultivated = (FieldGroundType ~= nil and FieldGroundType.CULTIVATED) or 0
    local groundPlowed = (FieldGroundType ~= nil and FieldGroundType.PLOWED) or groundCultivated

    local plowMax = (g_fieldManager ~= nil and g_fieldManager.plowLevelMaxValue) or 0
    local limeMax = (g_fieldManager ~= nil and g_fieldManager.limeLevelMaxValue) or 0
    local sprayMax = (g_fieldManager ~= nil and g_fieldManager.sprayLevelMaxValue) or 0

    local stoneMax = 0
    if g_currentMission ~= nil and g_currentMission.stoneSystem ~= nil and g_currentMission.stoneSystem.getMinMaxValues ~= nil then
        local _, maxStone = g_currentMission.stoneSystem:getMinMaxValues()
        stoneMax = maxStone or 0
    end

    local function addStrategy(name, state)
        local normalizedState = nil
        if type(state) == "table" then
            normalizedState = state
            normalizedState.groundAngle = normalizedState.groundAngle or 0
            normalizedState.clearHeightTypes = Utils.getNoNil(normalizedState.clearHeightTypes, false)
        end

        table.insert(strategies, {
            name = name,
            state = normalizedState
        })
    end

    if string.find(lowerName, "plow", 1, true) ~= nil then
        -- For plow PREP pass: filter fields strictly, but do not mutate field state.
        addStrategy("plow_no_field_mutation", nil)
    end

    if string.find(lowerName, "cultivat", 1, true) ~= nil then
        -- For cultivate PREP pass: filter fields strictly, but do not mutate field state.
        addStrategy("cultivate_no_field_mutation", nil)
    end

    if string.find(lowerName, "mow", 1, true) ~= nil then
        -- Dynamic per-field prep for mowing:
        -- - grass and not cut: only force highest mowable growth stage
        -- - no fruit or dead fruit: create normal grass in mowable state
        addStrategy("mow_dynamic_field_prep", nil)
    end

    if (string.find(lowerName, "ted", 1, true) ~= nil
            or string.find(lowerName, "turn", 1, true) ~= nil
            or string.find(lowerName, "windrow", 1, true) ~= nil
            or string.find(lowerName, "wend", 1, true) ~= nil) then
        -- Dynamic per-field prep for turning/windrowing:
        -- same field selection as mowing, but force grass to freshly cut state.
        addStrategy("turn_dynamic_field_prep", nil)
    end

    if string.find(lowerName, "hoe", 1, true) ~= nil then
        addStrategy("hoe_dynamic_field_prep", nil)
    end

    if string.find(lowerName, "weed", 1, true) ~= nil then
        addStrategy("weed_dynamic_field_prep", nil)
    end

    if string.find(lowerName, "fertiliz", 1, true) ~= nil then
        -- Dynamic per-field prep:
        -- - live crop: keep field as is, only reset fertilizer stage
        -- - no crop/dead crop: create a valid in-season growing crop and reset fertilizer stage
        addStrategy("fertilize_dynamic_field_prep", nil)
    end

    if string.find(lowerName, "spray", 1, true) ~= nil or string.find(lowerName, "herbicid", 1, true) ~= nil then
        -- Dynamic per-field prep:
        -- - live crop: keep field as is, only inject weeds
        -- - no crop/dead crop: create a valid in-season growing crop and inject weeds
        addStrategy("spray_dynamic_field_prep", nil)
    end

    if string.find(lowerName, "sow", 1, true) ~= nil or string.find(lowerName, "seed", 1, true) ~= nil then
        -- Dynamic per-field prep for sowing:
        -- - allowed input fields: no fruit, dead fruit, or grass-like crops
        -- - clear crop, reset weeds/fertilizer, and choose valid sow ground type
        -- - include ridge only when seasonally useful for in-period sowing fruits
        addStrategy("sow_dynamic_field_prep", nil)
    end

    if string.find(lowerName, "stone", 1, true) ~= nil then
        addStrategy("stone_dynamic_field_prep", nil)
    end

    if isHarvestMission then
        addStrategy("harvest_dynamic_field_prep", nil)
    end

    if #strategies == 0 then
        addStrategy("generic_empty_field", {
            fruitTypeIndex = unknownIndex,
            growthState = 1,
            groundType = groundCultivated,
            sprayType = sprayTypeNone,
            sprayLevel = 0,
            limeLevel = 0,
            plowLevel = 0,
            weedState = 0,
            stoneLevel = stoneMax,
            rollerLevel = 0,
            clearHeightTypes = true
        })
    end

    return strategies
end

function NeighborFieldWorkers:forceGenerateSingleMissionForTypeInternal(missionTypeName, classObject)
    if g_fieldManager == nil or g_fieldManager.fields == nil then
        return nil, 0, 0, 0
    end

    local fields = {}
    for _, field in pairs(g_fieldManager.fields) do
        if self:isFieldContractEligibleForGeneration(field) then
            table.insert(fields, field)
        end
    end

    if #fields == 0 then
        return nil, 0, 0, 0
    end

    local filteredFields = {}
    for _, field in ipairs(fields) do
        local canUseField = self:isFieldEligibleForForcedPrepareByMissionTypeInternal(missionTypeName, field)
        if canUseField then
            table.insert(filteredFields, field)
        end
    end

    if #filteredFields == 0 then
        nfwLogInfo(
            "[%s] MissionGen[INTERNAL]: Forced-Prepare abgebrochen type=%s reason=NO_ELIGIBLE_FIELDS totalFields=%d",
            self.MOD_NAME,
            tostring(missionTypeName),
            #fields
        )
        return nil, 0, 0, 0
    end

    local strategies = self:getMissionPreparationStrategiesForTypeInternal(missionTypeName)
    if #strategies == 0 then
        return nil, #filteredFields, 0, 0
    end

    for i = 1, #filteredFields do
        local randomIndex = math.random(i, #filteredFields)
        filteredFields[i], filteredFields[randomIndex] = filteredFields[randomIndex], filteredFields[i]
    end

    local preparedFields = 0
    local preparedVariants = 0
    local maxFields = math.min(#filteredFields, NFW_INTERNAL_MISSION_GEN_MAX_FIELDS_TO_PREPARE)
    local requiresDynamicPrepareState = self:isMissionTypeFertilizeOrSprayForMissionGen(missionTypeName)

    for fieldIndex = 1, maxFields do
        local field = filteredFields[fieldIndex]
        preparedFields = preparedFields + 1

        for _, strategy in ipairs(strategies) do
            preparedVariants = preparedVariants + 1
            local strategyName = tostring(strategy ~= nil and strategy.name or "unknown")
            local beforeStateDiag = self:getFieldStateDiagTextForMissionGen(field)

            local stateApplyOk = true
            local stateToApply = strategy ~= nil and strategy.state or nil

            if stateToApply == nil and requiresDynamicPrepareState then
                stateToApply = self:getForcedPrepareStateForMissionTypeAndFieldInternal(missionTypeName, field)
                if stateToApply == nil then
                    stateApplyOk = false
                    self:logMissionGenerationFieldFailure(
                        "PREP",
                        missionTypeName,
                        field,
                        "PREP_STATE_UNAVAILABLE",
                        beforeStateDiag,
                        self:getFieldStateDiagTextForMissionGen(field),
                        string.format("strategy=%s requiresDynamicState=true", strategyName)
                    )
                end
            end

            if stateApplyOk and stateToApply ~= nil then
                stateApplyOk = self:applyFieldStateForNeighborMission(field, stateToApply)
                if not stateApplyOk then
                    self:logMissionGenerationFieldFailure(
                        "PREP",
                        missionTypeName,
                        field,
                        "PREP_APPLY_FAILED",
                        beforeStateDiag,
                        self:getFieldStateDiagTextForMissionGen(field),
                        string.format("strategy=%s", strategyName)
                    )
                end
            end

            if stateApplyOk then
                local afterStateDiag = self:getFieldStateDiagTextForMissionGen(field)
                local canUseField = true
                local availabilityReason = "NO_AVAILABILITY_CHECK"
                if classObject ~= nil and classObject.isAvailableForField ~= nil then
                    local success, isAvailable = self:callMissionTypeIsAvailableForField(classObject, field)
                    canUseField = success and isAvailable
                    if success then
                        availabilityReason = canUseField and "AVAILABLE" or
                            string.format("NOT_AVAILABLE_FOR_FIELD(isAvailable=%s)", tostring(isAvailable))
                    else
                        availabilityReason = "AVAILABLE_CHECK_ERROR_IGNORED"
                    end
                end

                if canUseField then
                    local mission = self:tryGenerateMissionOnFieldInternal(classObject, field, missionTypeName)
                    if mission ~= nil then
                        nfwLogInfo(
                            "[%s] MissionGen[INTERNAL]: Forced-Prepare erfolgreich type=%s strategy=%s preparedFields=%d preparedVariants=%d",
                            self.MOD_NAME,
                            tostring(missionTypeName),
                            tostring(strategy.name),
                            preparedFields,
                            preparedVariants
                        )
                        return mission, #filteredFields, preparedFields, preparedVariants
                    end
                    self:logMissionGenerationFieldFailure(
                        "PREP",
                        missionTypeName,
                        field,
                        "TRY_GENERATE_NIL_AFTER_PREP",
                        beforeStateDiag,
                        afterStateDiag,
                        string.format(
                            "strategy=%s availability=%s generator=GIANTS %s %s",
                            strategyName,
                            availabilityReason,
                            self:getMissionFieldMismatchHintForMissionGen(missionTypeName, field),
                            self:buildMissionAvailabilityDetailForMissionGen(
                                missionTypeName,
                                field,
                                classObject,
                                availabilityReason
                            )
                        )
                    )
                else
                    self:logMissionGenerationFieldFailure(
                        "PREP",
                        missionTypeName,
                        field,
                        availabilityReason,
                        beforeStateDiag,
                        afterStateDiag,
                        string.format(
                            "strategy=%s availabilityCheck %s %s",
                            strategyName,
                            self:getMissionFieldMismatchHintForMissionGen(missionTypeName, field),
                            self:buildMissionAvailabilityDetailForMissionGen(
                                missionTypeName,
                                field,
                                classObject,
                                availabilityReason
                            )
                        )
                    )
                end
            end
        end
    end

    return nil, #filteredFields, preparedFields, preparedVariants
end

function NeighborFieldWorkers:tryGenerateSingleMissionForTypeInternal(missionTypeName, classObject,
                                                                      allowFallbackWithoutField)
    if g_fieldManager == nil or g_fieldManager.fields == nil then
        local mission = self:tryGenerateMissionOnFieldInternal(classObject, nil, missionTypeName)
        return mission, 0, 0
    end

    local className = tostring(classObject ~= nil and classObject.NAME or "n/a")
    local useReadyPrecheck = NFW_MISSION_GEN_USE_READY_PRECHECK == true

    local inspectedFields = 0
    local availableFields = 0
    local eligibleFields = {}

    for _, field in pairs(g_fieldManager.fields) do
        local isEligible, eligibilityReason = self:isFieldContractEligibleForGeneration(field)
        if isEligible then
            table.insert(eligibleFields, field)
        else
            nfwLogInfo(
                "[%s] MissionGen[READY_SCAN]: field=%s type=%s class=%s skip reason=%s state={%s}",
                self.MOD_NAME,
                self:getFieldIdTextForMissionGen(field),
                tostring(missionTypeName),
                className,
                tostring(eligibilityReason),
                self:getFieldStateDiagTextForMissionGen(field)
            )
        end
    end

    for i = #eligibleFields, 2, -1 do
        local j = math.random(1, i)
        eligibleFields[i], eligibleFields[j] = eligibleFields[j], eligibleFields[i]
    end

    for _, field in ipairs(eligibleFields) do
        inspectedFields = inspectedFields + 1
        local fieldIdText = self:getFieldIdTextForMissionGen(field)
        local fieldStateDiag = self:getFieldStateDiagTextForMissionGen(field)

        local readyByState = true
        local readyReason = "BYPASSED"
        if useReadyPrecheck then
            readyByState, readyReason = self:isMissionTypeFieldReadyWithoutPreparation(missionTypeName, field)
        else
            nfwLogInfo(
                "[%s] MissionGen[READY_SCAN]: field=%s type=%s class=%s info=READY_CHECK_BYPASSED state={%s}",
                self.MOD_NAME,
                fieldIdText,
                tostring(missionTypeName),
                className,
                fieldStateDiag
            )
        end

        if readyByState ~= true then
            nfwLogInfo(
                "[%s] MissionGen[READY_SCAN]: field=%s type=%s class=%s skip reason=READY_CHECK_FAIL(%s) state={%s}",
                self.MOD_NAME,
                fieldIdText,
                tostring(missionTypeName),
                className,
                tostring(readyReason),
                fieldStateDiag
            )
            self:logMissionGenerationFieldFailure(
                "READY",
                missionTypeName,
                field,
                string.format("READY_CHECK_FAIL(%s)", tostring(readyReason)),
                fieldStateDiag,
                nil,
                "precheck=true"
            )
        else
            local canUseField = true
            local availabilityReason = "NO_AVAILABILITY_CHECK"

            if classObject ~= nil and classObject.isAvailableForField ~= nil then
                local okAvailable, isAvailable = self:callMissionTypeIsAvailableForField(classObject, field)
                if okAvailable then
                    canUseField = isAvailable == true
                    availabilityReason = canUseField and "AVAILABLE" or
                        string.format("NOT_AVAILABLE_FOR_FIELD(isAvailable=%s)", tostring(isAvailable))
                else
                    availabilityReason = "AVAILABLE_CHECK_ERROR_IGNORED"
                end
            end

            if canUseField then
                availableFields = availableFields + 1
                local mission = self:tryGenerateMissionOnFieldInternal(classObject, field, missionTypeName)
                if mission ~= nil then
                    return mission, inspectedFields, availableFields
                end

                nfwLogInfo(
                    "[%s] MissionGen[READY_SCAN]: field=%s type=%s class=%s skip reason=TRY_GENERATE_NIL availability=%s state={%s}",
                    self.MOD_NAME,
                    fieldIdText,
                    tostring(missionTypeName),
                    className,
                    tostring(availabilityReason),
                    fieldStateDiag
                )
                self:logMissionGenerationFieldFailure(
                    "READY",
                    missionTypeName,
                    field,
                    string.format("TRY_GENERATE_NIL(availability=%s)", tostring(availabilityReason)),
                    fieldStateDiag,
                    nil,
                    string.format(
                        "generator=GIANTS %s %s",
                        self:getMissionFieldMismatchHintForMissionGen(missionTypeName, field),
                        self:buildMissionAvailabilityDetailForMissionGen(
                            missionTypeName,
                            field,
                            classObject,
                            availabilityReason
                        )
                    )
                )
            else
                nfwLogInfo(
                    "[%s] MissionGen[READY_SCAN]: field=%s type=%s class=%s skip reason=%s state={%s}",
                    self.MOD_NAME,
                    fieldIdText,
                    tostring(missionTypeName),
                    className,
                    tostring(availabilityReason),
                    fieldStateDiag
                )
                self:logMissionGenerationFieldFailure(
                    "READY",
                    missionTypeName,
                    field,
                    tostring(availabilityReason),
                    fieldStateDiag,
                    nil,
                    string.format(
                        "availabilityCheck %s %s",
                        self:getMissionFieldMismatchHintForMissionGen(missionTypeName, field),
                        self:buildMissionAvailabilityDetailForMissionGen(
                            missionTypeName,
                            field,
                            classObject,
                            availabilityReason
                        )
                    )
                )
            end
        end
    end

    if allowFallbackWithoutField ~= false then
        local mission = self:tryGenerateMissionOnFieldInternal(classObject, nil, missionTypeName)
        return mission, inspectedFields, availableFields
    end

    return nil, inspectedFields, availableFields
end

function NeighborFieldWorkers:generateMissionByTypeInternal(missionTypeName, count, options)
    local numericCount = tonumber(count) or 1
    local requestedCount = math.floor(numericCount)
    requestedCount = math.max(1, math.min(NFW_INTERNAL_MISSION_GEN_MAX_PER_REQUEST, requestedCount))
    options = type(options) == "table" and options or {}
    local allowForcedPrepare = options.forcePrepareFields == true
        and self:shouldAllowForcedPrepareForMissionTypeName(missionTypeName)
    local allowFallbackWithoutField = options.allowFallbackFieldSearch ~= false

    if options.forcePrepareFields == true and not allowForcedPrepare then
        nfwLogInfo(
            "[%s] MissionGen[INTERNAL]: Forced-Prepare deaktiviert type=%s",
            self.MOD_NAME,
            tostring(missionTypeName)
        )
    end

    if g_missionManager == nil then
        return requestedCount, 0
    end

    local missionType = g_missionManager:getMissionType(missionTypeName)
    if missionType == nil then
        nfwLogInfo("[%s] MissionGen[INTERNAL]: Missionstyp nicht gefunden type=%s", self.MOD_NAME,
            tostring(missionTypeName))
        return requestedCount, 0
    end

    local classObject = missionType.classObject
    if classObject == nil or classObject.tryGenerateMission == nil then
        nfwLogInfo("[%s] MissionGen[INTERNAL]: Missionstyp ohne tryGenerateMission type=%s", self.MOD_NAME,
            tostring(missionTypeName))
        return requestedCount, 0
    end

    local missionTypeData = g_missionManager:getMissionTypeDataByName(missionTypeName)
    local oldMaxNumInstances = nil
    if missionTypeData ~= nil then
        oldMaxNumInstances = missionTypeData.maxNumInstances
        missionTypeData.maxNumInstances = math.max(missionTypeData.maxNumInstances or 0,
            (missionTypeData.numInstances or 0) + requestedCount)
    end

    if MissionManager ~= nil then
        local minRequiredMissions = #g_missionManager.missions + requestedCount
        if (MissionManager.MAX_MISSIONS or 0) < minRequiredMissions then
            MissionManager.MAX_MISSIONS = minRequiredMissions
        end
    end

    local generatedCount = 0
    for index = 1, requestedCount do
        local mission, inspectedFields, availableFields =
            self:tryGenerateSingleMissionForTypeInternal(missionTypeName, classObject, allowFallbackWithoutField)
        if mission ~= nil then
            if self:registerMissionAndValidateGenerated(mission, missionType, missionTypeName, "INTERNAL") then
                generatedCount = generatedCount + 1
                nfwLogInfo(
                    "[%s] MissionGen[INTERNAL]: Mission erzeugt type=%s index=%d/%d inspectedFields=%d availableFields=%d",
                    self.MOD_NAME,
                    tostring(missionTypeName),
                    index,
                    requestedCount,
                    inspectedFields,
                    availableFields
                )
            end
        elseif allowForcedPrepare then
            local forcedMission, totalFields, preparedFields, preparedVariants =
                self:forceGenerateSingleMissionForTypeInternal(missionTypeName, classObject)
            if forcedMission ~= nil then
                if self:registerMissionAndValidateGenerated(forcedMission, missionType, missionTypeName, "INTERNAL_FORCED") then
                    generatedCount = generatedCount + 1
                    nfwLogInfo(
                        "[%s] MissionGen[INTERNAL]: Mission erzeugt via forced prepare type=%s index=%d/%d totalFields=%d preparedFields=%d preparedVariants=%d",
                        self.MOD_NAME,
                        tostring(missionTypeName),
                        index,
                        requestedCount,
                        totalFields,
                        preparedFields,
                        preparedVariants
                    )
                end
            else
                nfwLogInfo(
                    "[%s] MissionGen[INTERNAL]: Forced-Prepare erfolglos type=%s index=%d/%d totalFields=%d preparedFields=%d preparedVariants=%d",
                    self.MOD_NAME,
                    tostring(missionTypeName),
                    index,
                    requestedCount,
                    totalFields,
                    preparedFields,
                    preparedVariants
                )
            end
        else
            nfwLogInfo(
                "[%s] MissionGen[INTERNAL]: Keine Mission erzeugt type=%s index=%d/%d inspectedFields=%d availableFields=%d",
                self.MOD_NAME,
                tostring(missionTypeName),
                index,
                requestedCount,
                inspectedFields,
                availableFields
            )
        end
    end

    if missionTypeData ~= nil and oldMaxNumInstances ~= nil then
        missionTypeData.maxNumInstances = oldMaxNumInstances
    end

    return requestedCount, generatedCount
end

function NeighborFieldWorkers:tryGenerateMissionForNeighbor(triggerSource)
    local candidates = self:getGeneratableAllowedMissionTypeNames()
    if #candidates <= 0 then
        nfwLogInfo("[%s] MissionGen[%s]: Keine erlaubten generierbaren Missionstypen gefunden", self.MOD_NAME,
            tostring(triggerSource))
        return nil, "NO_GENERATABLE_ALLOWED_TYPES"
    end

    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    nfwLogInfo(
        "[%s] MissionGen[%s]: starte Generierung. Kandidaten=%d [%s] readyPrecheck=%s",
        self.MOD_NAME,
        tostring(triggerSource),
        #candidates,
        table.concat(candidates, ", "),
        tostring(NFW_MISSION_GEN_USE_READY_PRECHECK == true)
    )

    -- Pass 1: One scan pass in randomized type order.
    -- Depending on NFW_MISSION_GEN_USE_READY_PRECHECK this is either READY-filtered or direct GIANTS scanning.
    -- Only if all types fail here we continue with forced field preparation.
    local pass1ModeLabel = NFW_MISSION_GEN_USE_READY_PRECHECK == true and "READY" or "DIRECT"

    for index, missionTypeName in ipairs(candidates) do
        local beforeKeys = self:collectMissionKeysSnapshot()
        nfwLogInfo(
            "[%s] MissionGen[%s]: PASS1 %s Versuch %d/%d type=%s",
            self.MOD_NAME,
            tostring(triggerSource),
            pass1ModeLabel,
            index,
            #candidates,
            tostring(missionTypeName)
        )

        local requestedCount, generatedCount = self:generateMissionByTypeInternal(missionTypeName, 1, {
            forcePrepareFields = false,
            allowFallbackFieldSearch = false
        })
        local generatorUsed = "INTERNAL_READY"
        local generated = tonumber(generatedCount) or 0

        nfwLogInfo(
            "[%s] MissionGen[%s]: PASS1 %s Ergebnis type=%s requested=%s generated=%s generator=%s",
            self.MOD_NAME,
            tostring(triggerSource),
            pass1ModeLabel,
            tostring(missionTypeName),
            tostring(requestedCount),
            tostring(generatedCount),
            tostring(generatorUsed)
        )

        if generated > 0 then
            local mission = self:findGeneratedMissionFromSnapshot(beforeKeys, missionTypeName)
            if mission ~= nil then
                mission = self:validateGeneratedMissionForReadyUse(mission, triggerSource,
                    string.format("PASS1 %s", pass1ModeLabel))
            end

            if mission ~= nil then
                self.readyPrepBlockedCycles = 0
                nfwLogInfo(
                    "[%s] MissionGen[%s]: neue Mission gefunden mission=%s type=%s field=%s",
                    self.MOD_NAME,
                    tostring(triggerSource),
                    tostring(self:getMissionKey(mission)),
                    tostring(self:getMissionTypeName(mission)),
                    tostring(self:getMissionFieldId(mission))
                )
                return mission, string.format("GENERATED_READY_%s", tostring(missionTypeName))
            end

            nfwLogInfo(
                "[%s] MissionGen[%s]: PASS1 %s Mission erzeugt, aber keine passende CREATED-Mission gefunden type=%s",
                self.MOD_NAME,
                tostring(triggerSource),
                pass1ModeLabel,
                tostring(missionTypeName)
            )
        end
    end

    self.readyPrepBlockedCycles = 0

    if self.allowForcedFieldPreparation ~= true then
        nfwLogInfo(
            "[%s] MissionGen[%s]: PASS2 PREP uebersprungen (setting nfw_settings_forceFieldPreparation=OFF)",
            self.MOD_NAME,
            tostring(triggerSource)
        )
        return nil, "PREP_DISABLED_BY_SETTING"
    end

    -- Pass 2: Same randomized order, but now allow forced field preparation.
    nfwLogInfo(
        "[%s] MissionGen[%s]: PASS2 PREP startet (alle Typen in gleicher Zufallsreihenfolge)",
        self.MOD_NAME,
        tostring(triggerSource)
    )

    for index, missionTypeName in ipairs(candidates) do
        local beforeKeys = self:collectMissionKeysSnapshot()
        nfwLogInfo(
            "[%s] MissionGen[%s]: PASS2 PREP Versuch %d/%d type=%s",
            self.MOD_NAME,
            tostring(triggerSource),
            index,
            #candidates,
            tostring(missionTypeName)
        )

        local requestedCount, generatedCount = self:generateMissionByTypeInternal(missionTypeName, 1, {
            forcePrepareFields = true,
            allowFallbackFieldSearch = false
        })
        local generatorUsed = "INTERNAL_FORCED_PREP"
        local generated = tonumber(generatedCount) or 0

        nfwLogInfo(
            "[%s] MissionGen[%s]: PASS2 PREP Ergebnis type=%s requested=%s generated=%s generator=%s",
            self.MOD_NAME,
            tostring(triggerSource),
            tostring(missionTypeName),
            tostring(requestedCount),
            tostring(generatedCount),
            tostring(generatorUsed)
        )

        if generated > 0 then
            local mission = self:findGeneratedMissionFromSnapshot(beforeKeys, missionTypeName)
            if mission ~= nil then
                mission = self:validateGeneratedMissionForReadyUse(mission, triggerSource, "PASS2 PREP")
            end

            if mission ~= nil then
                self.readyPrepBlockedCycles = 0
                nfwLogInfo(
                    "[%s] MissionGen[%s]: PASS2 PREP Mission gefunden mission=%s type=%s field=%s",
                    self.MOD_NAME,
                    tostring(triggerSource),
                    tostring(self:getMissionKey(mission)),
                    tostring(self:getMissionTypeName(mission)),
                    tostring(self:getMissionFieldId(mission))
                )
                return mission, string.format("GENERATED_PREPARED_%s", tostring(missionTypeName))
            end
        end
    end

    return nil, "GENERATION_EXHAUSTED_READY_AND_PREPARED"
end

function NeighborFieldWorkers:selectMissionForNeighborStart(triggerSource)
    local sourceTag = tostring(triggerSource or "UNKNOWN")
    local modeName = self:getMissionSelectionModeName()
    nfwLogInfo(
        "[%s] MissionSelect[%s]: mode=%s activeAssignments=%d maxNeighbors=%d",
        self.MOD_NAME,
        sourceTag,
        modeName,
        self:getActiveAssignmentCount(),
        self.maxNeighbors
    )

    if self.allowExistingContractCompetition == true then
        local mission = self:findNextAvailableMission()
        if mission ~= nil then
            nfwLogInfo(
                "[%s] MissionSelect[%s]: bestehende Mission ausgewaehlt mission=%s type=%s field=%s",
                self.MOD_NAME,
                sourceTag,
                tostring(self:getMissionKey(mission)),
                tostring(self:getMissionTypeName(mission)),
                tostring(self:getMissionFieldId(mission))
            )
            return mission, "EXISTING"
        end

        nfwLogInfo("[%s] MissionSelect[%s]: keine bestehende passende Mission gefunden", self.MOD_NAME, sourceTag)
        return nil, "NO_EXISTING_MISSION"
    end

    local mission, generatedSource = self:tryGenerateMissionForNeighbor(sourceTag)
    if mission ~= nil then
        return mission, generatedSource
    end

    nfwLogInfo(
        "[%s] MissionSelect[%s]: keine neu generierbare Mission gefunden reason=%s",
        self.MOD_NAME,
        sourceTag,
        tostring(generatedSource)
    )
    return nil, generatedSource
end

function NeighborFieldWorkers:findNextAvailableMission()
    if g_missionManager == nil or g_missionManager.getMissions == nil then
        return nil
    end

    for _, mission in ipairs(g_missionManager:getMissions()) do
        local key = self:getMissionKey(mission)
        if key ~= nil and self.activeAssignments[key] == nil then
            if mission.status == MissionStatus.CREATED and mission.farmId == nil and self:isAllowedMissionType(mission) then
                local canStart = self:canMissionBeStartedWithVehicles(mission)
                if canStart then
                    local fieldInUse, fieldId, inUseReason = self:isMissionFieldInUseByNeighbor(mission, key)
                    if fieldInUse then
                        nfwLogInfo(
                            "[%s] MissionSelect[EXISTING]: uebersprungen (Feld bereits belegt): mission=%s field=%s reason=%s",
                            self.MOD_NAME,
                            tostring(self:getMissionKey(mission)),
                            tostring(fieldId),
                            tostring(inUseReason)
                        )
                    else
                        local isSuitable, reason, checkName = self:getNeighborMissionReadySuitability(mission)
                        if checkName == nil or isSuitable then
                            return mission
                        end

                        nfwLogInfo(
                            "[%s] MissionSelect[EXISTING]: %s uebersprungen (Feld ungueltig): mission=%s field=%s reason=%s",
                            self.MOD_NAME,
                            tostring(checkName),
                            tostring(self:getMissionKey(mission)),
                            tostring(self:getMissionFieldId(mission)),
                            tostring(reason)
                        )
                    end
                end
            end
        end
    end

    return nil
end

function NeighborFieldWorkers:missionStartStateToText(state)
    if state == MissionStartState.OK then return "OK" end
    if state == MissionStartState.LIMIT_REACHED then return "LIMIT_REACHED" end
    if state == MissionStartState.ALREADY_STARTED then return "ALREADY_STARTED" end
    if state == MissionStartState.PENDING_MISSION then return "PENDING_MISSION" end
    if state == MissionStartState.NOT_AVAILABLE_ANYMORE then return "NOT_AVAILABLE_ANYMORE" end
    if state == MissionStartState.CANNOT_BE_STARTED_NOW then return "CANNOT_BE_STARTED_NOW" end
    if state == MissionStartState.NO_ACCESS then return "NO_ACCESS" end
    if state == MissionStartState.NO_PERMISSION then return "NO_PERMISSION" end

    return tostring(state)
end

function NeighborFieldWorkers:missionStatusToText(status)
    if status == MissionStatus.CREATED then return "CREATED" end
    if status == MissionStatus.PREPARING then return "PREPARING" end
    if status == MissionStatus.RUNNING then return "RUNNING" end
    if status == MissionStatus.FINISHED then return "FINISHED" end
    if status == MissionStatus.DISMISSED then return "DISMISSED" end
    return tostring(status)
end

function NeighborFieldWorkers:getMissionStartDebugStateText(mission)
    local statusText = mission ~= nil and self:missionStatusToText(mission.status) or "nil"
    local farmId = mission ~= nil and mission.farmId or nil
    local spawnedVehicles = mission ~= nil and mission.spawnedVehicles or nil
    local vehicleCount = (mission ~= nil and mission.vehicles ~= nil) and #mission.vehicles or 0
    local pendingLoads = (mission ~= nil and mission.pendingVehicleLoadingData ~= nil) and #mission.pendingVehicleLoadingData or 0
    local vehiclesToLoad = (mission ~= nil and mission.vehiclesToLoad ~= nil) and #mission.vehiclesToLoad or 0
    local failedLoad = mission ~= nil and mission.failedToLoadVehicles == true
    local missionKey = self:getMissionKey(mission)
    local hasAssignment = missionKey ~= nil and self.activeAssignments[missionKey] ~= nil

    return string.format(
        "status=%s farmId=%s spawned=%s vehicles=%d vehiclesToLoad=%d pendingLoads=%d failedLoad=%s assignmentExists=%s",
        tostring(statusText),
        tostring(farmId),
        tostring(spawnedVehicles),
        vehicleCount,
        vehiclesToLoad,
        pendingLoads,
        tostring(failedLoad),
        tostring(hasAssignment)
    )
end

function NeighborFieldWorkers:tryFinalizeGiantsPreparingStatusIfStuck(mission, assignment, trigger)
    if mission == nil or mission.status ~= MissionStatus.PREPARING then
        return false
    end

    if mission.failedToLoadVehicles == true then
        return false
    end

    local pendingLoads = (mission.pendingVehicleLoadingData ~= nil) and #mission.pendingVehicleLoadingData or 0
    if pendingLoads > 0 then
        return false
    end

    local vehicleCount = (mission.vehicles ~= nil) and #mission.vehicles or 0
    local toLoadCount = (mission.vehiclesToLoad ~= nil) and #mission.vehiclesToLoad or 0
    if vehicleCount <= 0 or toLoadCount <= 0 then
        return false
    end

    -- GIANTS getIsPrepared() for borrowed-vehicle missions requires:
    -- #vehiclesToLoad == #vehicles.
    -- Some mission groups return multiple spawned vehicles from one vehiclesToLoad entry.
    -- In that case PREPARING can stay forever although all vehicles are fully loaded.
    if vehicleCount <= toLoadCount then
        return false
    end

    if assignment ~= nil and assignment.sprayerAttachPhase ~= nil then
        return false
    end

    if mission.getIsPrepared ~= nil then
        local okPrepared, isPrepared = pcall(mission.getIsPrepared, mission)
        if okPrepared and isPrepared == true then
            return false
        end
    end

    local fieldTaskFinished = true
    if mission.fieldPreparingTask ~= nil and mission.fieldPreparingTask.getIsFinished ~= nil then
        local okFieldTask, isFinished = pcall(mission.fieldPreparingTask.getIsFinished, mission.fieldPreparingTask)
        fieldTaskFinished = okFieldTask and isFinished == true
    end
    if not fieldTaskFinished then
        return false
    end

    nfwLogMissionDebug(
        "[%s] PREPARING_STUCK_FIX_ATTEMPT: mission=%s trigger=%s status=%s vehicles=%d vehiclesToLoad=%d pendingLoads=%d",
        self.MOD_NAME,
        tostring(self:getMissionKey(mission)),
        tostring(trigger or "UNKNOWN"),
        tostring(self:missionStatusToText(mission.status)),
        vehicleCount,
        toLoadCount,
        pendingLoads
    )

    local okFinalize = false
    if mission.finishedPreparing ~= nil then
        local okCall = false
        okCall, _ = pcall(mission.finishedPreparing, mission)
        okFinalize = okCall and mission.status == MissionStatus.RUNNING
    end

    nfwLogMissionDebug(
        "[%s] PREPARING_STUCK_FIX_RESULT: mission=%s trigger=%s ok=%s statusAfter=%s",
        self.MOD_NAME,
        tostring(self:getMissionKey(mission)),
        tostring(trigger or "UNKNOWN"),
        tostring(okFinalize),
        tostring(self:missionStatusToText(mission.status))
    )

    if okFinalize then
        nfwLogInfo(
            "[%s] GIANTS Missionsstatus von PREPARING auf RUNNING korrigiert: mission=%s vehicles=%d vehiclesToLoad=%d",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            vehicleCount,
            toLoadCount
        )
    end

    return okFinalize
end

function NeighborFieldWorkers:logMissionScanSummary()
    local now = g_time or 0
    if now < self.nextScanLogAtMs then
        return
    end
    self.nextScanLogAtMs = now + self.scanLogIntervalMs

    if g_missionManager == nil or g_missionManager.getMissions == nil then
        nfwLogInfo("[%s] Scan: g_missionManager nicht verfuegbar", self.MOD_NAME)
        return
    end

    local total = 0
    local createdUnassigned = 0
    local createdAllowed = 0
    local runningNeighbor = 0
    local createdTypes = {}

    for _, mission in ipairs(g_missionManager:getMissions()) do
        total = total + 1
        if mission.farmId ~= nil and self:isNeighborFarm(mission.farmId) and mission.status ~= MissionStatus.FINISHED and mission.status ~= MissionStatus.DISMISSED then
            runningNeighbor = runningNeighbor + 1
        end

        if mission.status == MissionStatus.CREATED and mission.farmId == nil then
            createdUnassigned = createdUnassigned + 1
            local typeName = self:getMissionTypeName(mission)
            createdTypes[typeName] = Utils.getNoNil(createdTypes[typeName], 0) + 1
            if self:isAllowedMissionType(mission) then
                createdAllowed = createdAllowed + 1
            end
        end
    end

    local typeParts = {}
    for typeName, count in pairs(createdTypes) do
        table.insert(typeParts, string.format("%s=%d", tostring(typeName), count))
    end
    table.sort(typeParts)

    local typeSummary = "-"
    if #typeParts > 0 then
        local maxParts = math.min(#typeParts, 6)
        typeSummary = table.concat(typeParts, ", ", 1, maxParts)
    end

    nfwLogInfo(
        "[%s] Scan: total=%d createdUnassigned=%d createdAllowed=%d activeNeighbor=%d maxNeighbors=%d mode=%s neighborFarmId=%s types={%s}",
        self.MOD_NAME,
        total,
        createdUnassigned,
        createdAllowed,
        runningNeighbor,
        self.maxNeighbors,
        self:getMissionSelectionModeName(),
        tostring(self.neighborFarmId),
        typeSummary
    )
end

function NeighborFieldWorkers:tryStartNewNeighborMission()
    if self:getActiveAssignmentCount() >= self.maxNeighbors then
        return
    end

    if self:getPendingStartAssignmentCount() > 0 then
        return
    end

    local mission, missionSource = self:selectMissionForNeighborStart("AUTO_SCAN")
    if mission == nil then
        nfwLogInfo(
            "[%s] Kein passender Auftrag gefunden (mode=%s)",
            self.MOD_NAME,
            self:getMissionSelectionModeName()
        )
        return
    end

    local fieldInUse, fieldId, inUseReason = self:isMissionFieldInUseByNeighbor(mission, self:getMissionKey(mission))
    if fieldInUse then
        nfwLogInfo(
            "[%s] Auto-Start uebersprungen (Feld bereits belegt): mission=%s field=%s source=%s reason=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            tostring(fieldId),
            tostring(missionSource),
            tostring(inUseReason)
        )
        return
    end

    self:forcePrepareSowMissionFieldIfNeeded(mission, missionSource, "AUTO_START", false)

    local hasFieldSpawnSetup = self:configureMissionFieldSpawnState(mission)
    if not hasFieldSpawnSetup then
        nfwLogInfo(
            "[%s] Feld-Spawn Vorbereitung fehlgeschlagen, nutze Standard-Spawn: mission=%s type=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            self:getMissionTypeName(mission)
        )
    end

    self:applyNeighborMissionEconomyRules(mission)

    nfwLogMissionDebug(
        "[%s] MissionStart[AUTO][REQUEST]: mission=%s type=%s field=%s source=%s %s",
        self.MOD_NAME,
        tostring(self:getMissionKey(mission)),
        tostring(self:getMissionTypeName(mission)),
        tostring(self:getMissionFieldId(mission)),
        tostring(missionSource),
        self:getMissionStartDebugStateText(mission)
    )

    local startState = g_missionManager:startMission(mission, self.neighborFarmId, true)
    nfwLogMissionDebug(
        "[%s] MissionStart[AUTO][RESULT]: mission=%s startState=%s %s",
        self.MOD_NAME,
        tostring(self:getMissionKey(mission)),
        tostring(self:missionStartStateToText(startState)),
        self:getMissionStartDebugStateText(mission)
    )
    if startState ~= MissionStartState.OK then
        self:clearMissionFieldSpawnState(mission)
        nfwLogInfo(
            "[%s] Start fehlgeschlagen: mission=%s type=%s reason=%s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            self:getMissionTypeName(mission),
            self:missionStartStateToText(startState)
        )
        return
    end

    local assignment = self:createAssignmentForMission(mission)
    if assignment ~= nil then
        local fieldId = self:getMissionFieldId(mission)
        local location = self:getMissionLocationText(mission)
        nfwLogInfo(
            "[%s] Neuer Nachbarauftrag gestartet: mission=%s type=%s field=%s location=%s source=%s farmId=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            self:getMissionTypeName(mission),
            tostring(fieldId),
            tostring(location),
            tostring(missionSource),
            tostring(mission.farmId)
        )
    else
        nfwLogMissionDebug(
            "[%s] MissionStart[AUTO][WARN]: startState=OK aber assignment=nil mission=%s %s",
            self.MOD_NAME,
            tostring(self:getMissionKey(mission)),
            self:getMissionStartDebugStateText(mission)
        )
    end
end

function NeighborFieldWorkers:updateActiveAssignments()
    local keys = {}
    for key, _ in pairs(self.activeAssignments) do
        table.insert(keys, key)
    end

    for _, key in ipairs(keys) do
        local assignment = self.activeAssignments[key]
        if assignment ~= nil then
            self:updateSingleAssignment(assignment)
        end
    end
end

function NeighborFieldWorkers:removeAssignment(assignment)
    if assignment ~= nil and assignment.mission ~= nil then
        self:revealHiddenMissionVehicles(assignment.mission, "ASSIGNMENT_REMOVE")
    end

    if assignment ~= nil and assignment.mission ~= nil then
        self:restoreNoTrailerHarvestVehicleOverrides(assignment.mission)
    end

    if assignment ~= nil and assignment.mission ~= nil then
        self:clearMissionFieldSpawnState(assignment.mission)
    end

    if assignment ~= nil and assignment.mission ~= nil then
        self:restoreSowAIImplementOrderOverrides(assignment.mission)
    end

    if assignment ~= nil then
        self:releaseAttachmentLeadVehicleLock(assignment)
        self:restoreAssignmentHelperTitle(assignment)
    end

    if assignment ~= nil and assignment.key ~= nil then
        self.activeAssignments[assignment.key] = nil
        self.savedAssignmentKeys[tostring(assignment.key)] = nil
        self.savedAssignmentFieldIds[tostring(assignment.key)] = nil
    end
end

function NeighborFieldWorkers:completeAssignmentAsSuccess(assignment, balanceReason, logReason)
    if assignment == nil or assignment.mission == nil then
        return false
    end

    local mission = assignment.mission
    local vehicle = assignment.vehicle
    if vehicle ~= nil and vehicle.stopCurrentAIJob ~= nil and vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() then
        local stopMessage = nil
        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
            stopMessage = AIMessageSuccessStoppedByUser.new()
        end
        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
    end

    if mission.status ~= MissionStatus.FINISHED and mission.status ~= MissionStatus.DISMISSED and mission.finish ~= nil then
        pcall(mission.finish, mission, MissionFinishState.SUCCESS)
    end

    if mission.status == MissionStatus.FINISHED then
        self:finalizeAssignment(assignment)
    elseif mission.status ~= MissionStatus.DISMISSED then
        pcall(g_missionManager.cancelMission, g_missionManager, mission)
        pcall(g_missionManager.dismissMission, g_missionManager, mission)
        self:removeAssignment(assignment)
    else
        self:removeAssignment(assignment)
    end

    self.scanTimerMs = 0
    self:setNeighborFarmBalance(1, balanceReason or "AUTO_SUCCESS")
    if logReason ~= nil and logReason ~= "" then
        nfwLogInfo(
            "[%s] Auftrag automatisch erfolgreich beendet: mission=%s reason=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(logReason)
        )
    end
    return true
end

function NeighborFieldWorkers:finalizeAssignment(assignment)
    local mission = assignment.mission
    if mission == nil then
        self:removeAssignment(assignment)
        return
    end

    if self:isMissionExiting() then
        self:removeAssignment(assignment)
        return
    end

    local fieldId = self:getMissionFieldId(mission)
    local finishState = tostring(mission.finishState)

    if mission.status == MissionStatus.FINISHED then
        g_missionManager:dismissMission(mission)
    end

    nfwLogInfo(
        "[%s] Nachbarauftrag abgeschlossen: mission=%s type=%s field=%s finishState=%s mode=%s",
        self.MOD_NAME,
        tostring(assignment.key),
        self:getMissionTypeName(mission),
        tostring(fieldId),
        finishState,
        tostring(assignment.aiMode or "none")
    )
    self:setNeighborFarmBalance(1, "MISSION_FINISHED")

    self:removeAssignment(assignment)
end

function NeighborFieldWorkers:updateSingleAssignment(assignment)
    local mission = assignment.mission
    if mission == nil then
        self:removeAssignment(assignment)
        return
    end

    if assignment.autoCompleteRequested == true then
        self:completeAssignmentAsSuccess(
            assignment,
            "AUTO_FIELD_PREP",
            tostring(assignment.autoCompleteReason or "AUTO")
        )
        return
    end

    if mission.status == MissionStatus.DISMISSED then
        self:removeAssignment(assignment)
        return
    end

    if mission.status == MissionStatus.FINISHED then
        self:finalizeAssignment(assignment)
        return
    end

    if mission.status ~= MissionStatus.PREPARING then
        assignment.preparingSinceMs = 0
    end

    if mission.status == MissionStatus.PREPARING then
        local now = g_time or 0
        if Utils.getNoNil(assignment.preparingSinceMs, 0) <= 0 then
            assignment.preparingSinceMs = now
        end

        if not assignment.aiStarted then
            self:prepareMissionVehicles(assignment)
            self:pruneSowMissionSupportVehicles(assignment)
            -- Do not move mission vehicles while loading is still in progress.
            -- Some mission groups fail if the lead vehicle is moved too early.
            self:logMissionVehicleStates(assignment)

            local spawnedVehicles, vehicleCount, expectedVehicleCount, pendingLoads, _, loadingComplete =
                self:getMissionVehicleLoadStats(mission)
            local preparingForMs = math.max(0, now - Utils.getNoNil(assignment.preparingSinceMs, now))
            self:tryFinalizeGiantsPreparingStatusIfStuck(mission, assignment, "UPDATE_PREPARING")
            local shouldForcePreparingStart = spawnedVehicles
                and vehicleCount > 0
                and pendingLoads == 0
                and preparingForMs >= 1000

            if shouldForcePreparingStart then
                nfwLogInfo(
                    "[%s] PREPARING Start: mission=%s preparingForMs=%d vehicles=%d pendingLoads=%d recovered=%s",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    preparingForMs,
                    vehicleCount,
                    pendingLoads,
                    tostring(assignment.recoveredFromSave == true)
                )
                nfwLogMissionDebug(
                    "[%s] PREPARING_TRIGGER_START: mission=%s status=%s preparingForMs=%d spawned=%s vehicles=%d expectedVehicles=%d pendingLoads=%d loadingComplete=%s recovered=%s",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    tostring(self:missionStatusToText(mission.status)),
                    preparingForMs,
                    tostring(spawnedVehicles),
                    vehicleCount,
                    expectedVehicleCount,
                    pendingLoads,
                    tostring(loadingComplete),
                    tostring(assignment.recoveredFromSave == true)
                )
                self:tryStartPendingAssignment(assignment)
            elseif now >= Utils.getNoNil(assignment.nextPreparingMissionDebugAtMs, 0) then
                assignment.nextPreparingMissionDebugAtMs = now + 2000
                local blocker = "WAITING_UNKNOWN"
                if not spawnedVehicles then
                    blocker = "SPAWN_NOT_READY"
                elseif vehicleCount <= 0 then
                    blocker = "NO_VEHICLES"
                elseif pendingLoads > 0 then
                    blocker = "PENDING_LOADS"
                elseif preparingForMs < 1000 then
                    blocker = "INITIAL_DELAY"
                elseif loadingComplete == false then
                    blocker = "LOADING_NOT_COMPLETE"
                end

                nfwLogMissionDebug(
                    "[%s] PREPARING_WAIT: mission=%s status=%s blocker=%s preparingForMs=%d spawned=%s vehicles=%d expectedVehicles=%d pendingLoads=%d loadingComplete=%s recovered=%s",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    tostring(self:missionStatusToText(mission.status)),
                    tostring(blocker),
                    preparingForMs,
                    tostring(spawnedVehicles),
                    vehicleCount,
                    expectedVehicleCount,
                    pendingLoads,
                    tostring(loadingComplete),
                    tostring(assignment.recoveredFromSave == true)
                )
            end
            return
        end

        -- Some recovered contracts stay in PREPARING although AI is already running.
        -- Keep monitoring them like running missions so they can finish/auto-recover.
        self:monitorRunningAssignment(assignment)
        return
    end

    if mission.status == MissionStatus.RUNNING and not assignment.aiStarted then
        self:tryStartPendingAssignment(assignment)
        return
    end

    if mission.status == MissionStatus.RUNNING and assignment.aiStarted then
        self:monitorRunningAssignment(assignment)
    end
end

function NeighborFieldWorkers:attemptSowMissionFieldRecovery(assignment, mission, vehicle, now, unchangedMs, triggerMode)
    if assignment == nil or mission == nil or not self:isSowMission(mission) then
        return false
    end
    if mission.field == nil then
        return false
    end

    local effectiveNow = now or (g_time or 0)
    local recoveryCount = Utils.getNoNil(assignment.sowFieldRecoveryCount, 0)
    local triggerText = tostring(triggerMode or "STALLED_PROGRESS")
    local recoveryLimit = 1
    if triggerText == "ZERO_AREA_WATCHDOG" then
        recoveryLimit = 2
    end
    if recoveryCount >= recoveryLimit then
        nfwLogHelperDiag(
            "[%s] HelperDiag SOW_RECOVERY_SKIPPED: mission=%s reason=RECOVERY_LIMIT_REACHED trigger=%s limit=%d count=%d unchangedFor=%ds",
            self.MOD_NAME,
            tostring(assignment.key),
            triggerText,
            recoveryLimit,
            recoveryCount,
            math.floor(math.max(0, unchangedMs) / 1000)
        )
        return false
    end

    local nextRecoveryAllowedAt = Utils.getNoNil(assignment.nextSowRecoveryAllowedAtMs, 0)
    if effectiveNow < nextRecoveryAllowedAt then
        return false
    end
    assignment.nextSowRecoveryAllowedAtMs = effectiveNow + 30000
    assignment.sowFieldRecoveryTriggered = true
    assignment.sowFieldRecoveryCount = recoveryCount + 1

    local prepared = false
    local prepMode = "none"
    local fieldStateInfo = "n/a"

    if mission.field.getFieldState ~= nil then
        local okState, fieldState = pcall(mission.field.getFieldState, mission.field)
        if okState and fieldState ~= nil then
            fieldStateInfo = string.format(
                "isValid=%s canBeWorked=%s canBeSown=%s hasFruit=%s",
                tostring(fieldState.isValid),
                tostring(fieldState.canBeWorked),
                tostring(fieldState.canBeSown),
                tostring(fieldState.hasFruit)
            )
        end
    end

    if self:forcePrepareSowMissionFieldIfNeeded(mission, "RUNNING_RECOVERY", "STALLED_PROGRESS", true) then
        prepared = true
        prepMode = "NFW_FORCE_PREP"
    end

    if mission.getFieldPreparingTask ~= nil
        and g_fieldManager ~= nil
        and g_fieldManager.addFieldUpdateTask ~= nil then
        local okTask, task = pcall(mission.getFieldPreparingTask, mission)
        if okTask and task ~= nil then
            if task.setNeedsSaving ~= nil then
                pcall(task.setNeedsSaving, task, false)
            end
            if task.setField ~= nil and mission.field ~= nil then
                pcall(task.setField, task, mission.field)
            end
            local okAdd = pcall(g_fieldManager.addFieldUpdateTask, g_fieldManager, task)
            if okAdd and not prepared then
                prepared = true
                prepMode = "FIELD_UPDATE_TASK"
            end
        end
    end

    if mission.prepareField ~= nil then
        local okPrepare = pcall(mission.prepareField, mission)
        if okPrepare then
            if not prepared then
                prepMode = "MISSION_PREPARE_FIELD"
            else
                prepMode = tostring(prepMode) .. "+MISSION_PREPARE_FIELD"
            end
            prepared = true
        end
    end

    if not prepared then
        nfwLogInfo(
            "[%s] SOW_RECOVERY: Feldvorbereitung nicht moeglich: mission=%s unchangedFor=%ds fieldState={%s}",
            self.MOD_NAME,
            tostring(assignment.key),
            math.floor(math.max(0, unchangedMs) / 1000),
            tostring(fieldStateInfo)
        )
        return false
    end

    nfwLogInfo(
        "[%s] SOW_RECOVERY: Feldvorbereitung neu angestossen: mission=%s mode=%s unchangedFor=%ds recoveryCount=%d fieldState={%s}",
        self.MOD_NAME,
        tostring(assignment.key),
        tostring(prepMode),
        math.floor(math.max(0, unchangedMs) / 1000),
        Utils.getNoNil(assignment.sowFieldRecoveryCount, 0),
        tostring(fieldStateInfo)
    )

    if vehicle ~= nil
        and not vehicle.isDeleted
        and vehicle.getIsAIActive ~= nil
        and vehicle.stopCurrentAIJob ~= nil
        and vehicle:getIsAIActive() then
        local stopMessage = nil
        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
            stopMessage = AIMessageSuccessStoppedByUser.new()
        end
        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
    end

    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    local bestProbeRatio = self:getBestSowFieldProbeRatio(mission, vehicle, fieldX, fieldZ)
    local forceRepositionAfterRecovery = bestProbeRatio ~= nil and bestProbeRatio < 0.95

    assignment.aiStarted = false
    assignment.giantsJob = nil
    assignment.forceDirectStart = true
    if self.fieldEdgeStartModeEnabled == true then
        assignment.disableEdgeStartForMission = true
    end
    assignment.forceRecoveryReposition = forceRepositionAfterRecovery
    assignment.forceRecoveryReason = forceRepositionAfterRecovery and "SOW_LOW_PROBE" or nil
    assignment.keepDirectStartForNextStart = forceRepositionAfterRecovery
    assignment.suppressRelocateDuringSprayerAttach = false
    assignment.aiInactiveSinceMs = nil
    assignment.aiFarSinceMs = nil
    assignment.helperDiagImmediateStopLogged = false
    assignment.nextStartAfterAttachMs = effectiveNow + 2000
    assignment.nextResourceTopupAtMs = effectiveNow + 1000
    assignment.noFieldRetryIndex = 0
    assignment.sowZeroAreaActiveSinceMs = nil
    assignment.sowZeroAreaLastSummary = nil
    assignment.nextSowZeroAreaRecoveryLogAtMs = 0

    if forceRepositionAfterRecovery then
        nfwLogInfo(
            "[%s] SOW_RECOVERY: Reposition auf Feldmitte erzwungen: mission=%s probeRatio=%.3f",
            self.MOD_NAME,
            tostring(assignment.key),
            bestProbeRatio
        )
    end

    return true
end

function NeighborFieldWorkers:monitorRunningAssignment(assignment)
    if self:isMissionExiting() then
        return
    end

    local mission = assignment.mission
    if mission == nil then
        return
    end

    local vehicle = assignment.vehicle
    if vehicle == nil or vehicle.isDeleted or vehicle.rootNode == nil then
        vehicle = self:findMissionWorkVehicle(assignment)
        assignment.vehicle = vehicle
    end
    if vehicle == nil or vehicle.rootNode == nil then
        return
    end

    self:assignLocalizedHelperNameToAssignment(assignment, vehicle)

    local now = g_time or 0
    local x, _, z = getWorldTranslation(vehicle.rootNode)
    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    local dist = nil
    if fieldX ~= nil and fieldZ ~= nil then
        dist = MathUtil.vector2Length(x - fieldX, z - fieldZ)
    end
    local isAtMissionField = self:isPositionWithinMissionField(mission, x, z)

    local isAiActive = vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() or false
    local speed = vehicle.getLastSpeed ~= nil and vehicle:getLastSpeed() or 0
    local aiImplementCount = self:getCurrentAIImplementCount(vehicle)
    local completionPercent = self:getMissionCompletionPercent(mission)
    local isUpsideDown = self:isVehicleUpsideDown(vehicle)
    local stuckDistance30s = nil
    local attachedImplementsCount = 0
    if vehicle.getAttachedImplements ~= nil then
        local implements = vehicle:getAttachedImplements()
        if implements ~= nil then
            attachedImplementsCount = #implements
        end
    end
    local canStartFieldWork = vehicle.getCanStartFieldWork ~= nil and vehicle:getCanStartFieldWork() or false
    local canContinueWork = nil
    local stopAiWork = nil
    if vehicle.getCanAIFieldWorkerContinueWork ~= nil then
        local okContinue, c, s = pcall(vehicle.getCanAIFieldWorkerContinueWork, vehicle, false)
        if okContinue then
            canContinueWork = c
            stopAiWork = s
        end
    end

    local edgeTargetDist = nil
    local edgeGuardTriggered = false
    local edgeGuardReason = nil
    if isAiActive
        and assignment.lastStartUsedEdge == true
        and assignment.disableEdgeStartForMission ~= true
        and assignment.aiStartTimeMs ~= nil
        and now <= assignment.aiStartTimeMs + 30000
        and type(assignment.lastStartEdgeTargetX) == "number"
        and type(assignment.lastStartEdgeTargetZ) == "number" then
        local edgeDx = x - assignment.lastStartEdgeTargetX
        local edgeDz = z - assignment.lastStartEdgeTargetZ
        local edgeDistSq = edgeDx * edgeDx + edgeDz * edgeDz
        edgeTargetDist = math.sqrt(edgeDistSq)

        local bestDistSq = assignment.edgeTargetBestDistSq
        if type(bestDistSq) ~= "number" or edgeDistSq < bestDistSq then
            assignment.edgeTargetBestDistSq = edgeDistSq
            assignment.edgeTargetBestAtMs = now
            bestDistSq = edgeDistSq
        end

        local currentTaskIndex = assignment.giantsJob ~= nil and tonumber(assignment.giantsJob.currentTaskIndex) or nil
        local bestDist = math.sqrt(Utils.getNoNil(bestDistSq, edgeDistSq))
        if currentTaskIndex == 1 then
            if bestDist <= 3.0 and edgeTargetDist >= bestDist + 8.0 then
                edgeGuardTriggered = true
                edgeGuardReason = "EDGE_TARGET_OVERSHOOT"
            elseif edgeTargetDist <= 1.5 and speed < 0.15 then
                if assignment.edgeTargetArrivedStillTask1SinceMs == nil then
                    assignment.edgeTargetArrivedStillTask1SinceMs = now
                elseif now >= assignment.edgeTargetArrivedStillTask1SinceMs + 5000 then
                    edgeGuardTriggered = true
                    edgeGuardReason = "EDGE_TARGET_REACHED_NO_WORK_START"
                end
            else
                assignment.edgeTargetArrivedStillTask1SinceMs = nil
            end
        else
            assignment.edgeTargetArrivedStillTask1SinceMs = nil
        end
    else
        assignment.edgeTargetArrivedStillTask1SinceMs = nil
    end

    if assignment.helperDiagLastAiActive == nil or assignment.helperDiagLastAiActive ~= isAiActive then
        local sinceStartMs = assignment.aiStartTimeMs ~= nil and math.max(0, now - assignment.aiStartTimeMs) or -1
        nfwLogHelperDiag(
            "[%s] HelperDiag AI_STATE_CHANGE: mission=%s vehicle=%s aiActive=%s sinceStartMs=%d speed=%.2f distToField=%s canStart=%s aiImpl=%d attached=%d",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
            tostring(isAiActive),
            sinceStartMs,
            speed,
            dist ~= nil and string.format("%.1f", dist) or "n/a",
            tostring(canStartFieldWork),
            aiImplementCount,
            attachedImplementsCount
        )
        assignment.helperDiagLastAiActive = isAiActive
        assignment.helperDiagLastAiActiveChangeMs = now
    end

    if assignment.aiStartTimeMs ~= nil
        and now <= assignment.aiStartTimeMs + 30000
        and not isAiActive
        and assignment.helperDiagImmediateStopLogged ~= true then
        local missingImplements = self:getUnattachedMissionImplements(mission)
        local lastStopReason = "n/a"
        local stopAgeMs = "n/a"
        if assignment.helperDiagLastStopReason ~= nil then
            lastStopReason = tostring(assignment.helperDiagLastStopReason)
            if assignment.helperDiagLastStopAtMs ~= nil and assignment.helperDiagLastStopAtMs > 0 then
                stopAgeMs = tostring(math.max(0, now - assignment.helperDiagLastStopAtMs))
            end
        end
        nfwLogHelperDiag(
            "[%s] HelperDiag IMMEDIATE_STOP_DETECTED: mission=%s vehicle=%s sinceStartMs=%d canStart=%s aiImpl=%d attached=%d missing=%d upsideDown=%s speed=%.2f distToField=%s lastStopReason=%s stopAgeMs=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
            math.max(0, now - assignment.aiStartTimeMs),
            tostring(canStartFieldWork),
            aiImplementCount,
            attachedImplementsCount,
            #missingImplements,
            tostring(isUpsideDown),
            speed,
            dist ~= nil and string.format("%.1f", dist) or "n/a",
            lastStopReason,
            stopAgeMs
        )
        assignment.helperDiagImmediateStopLogged = true
    end

    if now >= assignment.nextAiStateLogAtMs then
        assignment.nextAiStateLogAtMs = now + 10000
        nfwLogInfo(
            "[%s] Laufender Auftrag Status: mission=%s aiMode=%s aiActive=%s speed=%.2f pos=(%.1f/%.1f) distToField=%s onMissionField=%s aiImpl=%d",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(assignment.aiMode or "none"),
            tostring(isAiActive),
            speed,
            x,
            z,
            dist ~= nil and string.format("%.1f", dist) or "n/a",
            tostring(isAtMissionField),
            aiImplementCount
        )
    end

    if self:isSowMission(mission)
        and isAiActive
        and completionPercent <= 0
        and now >= Utils.getNoNil(assignment.nextSowDiagAtMs, 0) then
        assignment.nextSowDiagAtMs = now + 8000
        nfwLogInfo(
            "[%s] SOW_DIAG: mission=%s field=%s speed=%.2f distToField=%s onMissionField=%s aiImpl=%d %s",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(self:getMissionFieldId(mission)),
            speed,
            dist ~= nil and string.format("%.1f", dist) or "n/a",
            tostring(isAtMissionField),
            aiImplementCount,
            nfwToSingleLineText(self:getSowMissionRuntimeDebug(assignment, vehicle, fieldX, fieldZ), 2600)
        )
    end

    if self:isSowMission(mission) and isAiActive and completionPercent <= 0 then
        if now >= Utils.getNoNil(assignment.nextSowZeroAreaDiagAtMs, 0) then
            assignment.nextSowZeroAreaDiagAtMs = now + 5000
            local zeroAreaSummary = self:getSowZeroAreaWatchdogSummary(assignment, vehicle)
            if zeroAreaSummary ~= nil then
                local currentTaskIndex = assignment.giantsJob ~= nil and tonumber(assignment.giantsJob.currentTaskIndex) or nil
                if assignment.sowZeroAreaActiveSinceMs == nil then
                    assignment.sowZeroAreaActiveSinceMs = now
                end
                assignment.sowZeroAreaLastSummary = zeroAreaSummary
                local activeForMs = math.max(0, now - Utils.getNoNil(assignment.sowZeroAreaActiveSinceMs, now))
                nfwLogHelperDiag(
                    "[%s] HelperDiag SOW_ZERO_AREA_ACTIVE: mission=%s field=%s task=%s activeForMs=%d speed=%.2f distToField=%s onMissionField=%s details=%s",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    tostring(self:getMissionFieldId(mission)),
                    tostring(currentTaskIndex),
                    activeForMs,
                    speed,
                    dist ~= nil and string.format("%.1f", dist) or "n/a",
                    tostring(isAtMissionField),
                    nfwToSingleLineText(zeroAreaSummary, 2200)
                )

                if currentTaskIndex == 2 and activeForMs >= NFW_SOW_ZERO_AREA_RECOVERY_TRIGGER_MS then
                    local recovered = self:attemptSowMissionFieldRecovery(
                        assignment,
                        mission,
                        vehicle,
                        now,
                        activeForMs,
                        "ZERO_AREA_WATCHDOG"
                    )
                    if recovered then
                        nfwLogHelperDiag(
                            "[%s] HelperDiag SOW_ZERO_AREA_RECOVERY_TRIGGERED: mission=%s field=%s activeForMs=%d action=forcePrepare+restart",
                            self.MOD_NAME,
                            tostring(assignment.key),
                            tostring(self:getMissionFieldId(mission)),
                            activeForMs
                        )
                        assignment.sowZeroAreaActiveSinceMs = nil
                        assignment.sowZeroAreaLastSummary = nil
                        return
                    elseif now >= Utils.getNoNil(assignment.nextSowZeroAreaRecoveryLogAtMs, 0) then
                        assignment.nextSowZeroAreaRecoveryLogAtMs = now + 8000
                        nfwLogHelperDiag(
                            "[%s] HelperDiag SOW_ZERO_AREA_RECOVERY_SKIPPED: mission=%s field=%s activeForMs=%d reason=recovery_not_possible_or_limited",
                            self.MOD_NAME,
                            tostring(assignment.key),
                            tostring(self:getMissionFieldId(mission)),
                            activeForMs
                        )
                    end
                end
            else
                assignment.sowZeroAreaActiveSinceMs = nil
                assignment.sowZeroAreaLastSummary = nil
            end
        end
    elseif self:isSowMission(mission) then
        assignment.sowZeroAreaActiveSinceMs = nil
        assignment.sowZeroAreaLastSummary = nil
    end

    if now >= Utils.getNoNil(assignment.nextResourceTopupAtMs, 0) then
        assignment.nextResourceTopupAtMs = now + self:getMissionResourceTopupIntervalMs(mission)
        self:applyHarvestNoTrailerWorkaround(assignment)
        self:prepareMissionVehicleConsumables(assignment)
        local deferSowEnforce = self:shouldDeferSowOperationalStateDuringEdgeApproach(assignment, mission, vehicle)
        if not deferSowEnforce then
            self:enforceSowImplementOperationalState(assignment, vehicle, false)
        elseif now >= Utils.getNoNil(assignment.nextSowEdgeDeferLogAtMs, 0) then
            assignment.nextSowEdgeDeferLogAtMs = now + 4000
            nfwLogHelperDiag(
                "[%s] HelperDiag SOW_ENFORCE_DEFERRED: mission=%s reason=EDGE_APPROACH task=1 vehicle=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown")
            )
        end
    end

    if self:isHarvestMission(mission)
        and isAiActive
        and not canStartFieldWork
        and speed < 0.2
        and now >= Utils.getNoNil(assignment.nextHarvestRunningBlockedDiagAtMs, 0) then
        assignment.nextHarvestRunningBlockedDiagAtMs = now + 3000
        nfwLogHelperDiag(
            "[%s] HelperDiag HARVEST_RUNNING_BLOCKED: mission=%s vehicle=%s canStart=%s speed=%.2f aiImpl=%d continue={%s} caps={%s} runtime={%s}",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
            tostring(canStartFieldWork),
            speed,
            aiImplementCount,
            self:getVehicleContinueWorkDebug(vehicle),
            nfwToSingleLineText(self:getVehicleAiCapabilityDebug(vehicle), 700),
            nfwToSingleLineText(self:getHarvestVehicleRuntimeDebug(vehicle), 350)
        )
    end

    if self:isHarvestMission(mission)
        and isAiActive
        and not canStartFieldWork
        and speed < 0.2
        and now >= Utils.getNoNil(assignment.nextHarvestDeepDiagAtMs, 0) then
        assignment.nextHarvestDeepDiagAtMs = now + self.harvestDeepDiagIntervalMs
        self:logHarvestBlockedDeepDiagnostics(assignment, vehicle, mission, now, speed)
    end

    if self:isHarvestMission(mission)
        and isAiActive
        and not canStartFieldWork
        and speed < 0.2
        and now >= Utils.getNoNil(assignment.nextHarvestUnblockTryAtMs, 0) then
        assignment.nextHarvestUnblockTryAtMs = now + 1500
        self:forceHarvestVehicleContinueWork(assignment, "RUNNING_CANSTART_FALSE")
    end
    self:enforceRaisedFrontSupportImplements(assignment)

    local completionChanged = self:refreshCompletionStallTracking(assignment, completionPercent, now)
    if not completionChanged then
        if Utils.getNoNil(assignment.completionUnchangedSinceMs, 0) <= 0 then
            assignment.completionUnchangedSinceMs = now
        end

        local unchangedMs = math.max(0, now - assignment.completionUnchangedSinceMs)
        if completionPercent <= 0 and unchangedMs >= 30000 then
            if self:isSowMission(mission) then
                local blockingReason = self:getSowMissionBlockingReason(assignment, vehicle)
                if blockingReason ~= nil then
                    nfwLogInfo(
                        "[%s] SOW_RECOVERY: Auftrag als unmoeglich erkannt -> Abschluss: mission=%s reason=%s unchangedFor=%ds",
                        self.MOD_NAME,
                        tostring(assignment.key),
                        nfwToSingleLineText(blockingReason, 600),
                        math.floor(math.max(0, unchangedMs) / 1000)
                    )
                    self:completeAssignmentAsSuccess(
                        assignment,
                        "SOW_BLOCKED",
                        string.format("SOW_BLOCKED:%s", nfwToSingleLineText(blockingReason, 300))
                    )
                    return
                end
            end

            local recovered = self:attemptSowMissionFieldRecovery(
                assignment,
                mission,
                vehicle,
                now,
                unchangedMs,
                "STALLED_PROGRESS"
            )
            if recovered then
                return
            end
        end

        if unchangedMs >= 120000 then
            nfwLogInfo(
                "[%s] Auftrag auto-abgeschlossen (Fortschritt unveraendert): mission=%s progress=%d%% unchangedFor=%ds",
                self.MOD_NAME,
                tostring(assignment.key),
                completionPercent,
                math.floor(unchangedMs / 1000)
            )

            if isAiActive and vehicle.stopCurrentAIJob ~= nil then
                local stopMessage = nil
                if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
                    stopMessage = AIMessageSuccessStoppedByUser.new()
                end
                pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
            end

            if mission.status ~= MissionStatus.FINISHED and mission.status ~= MissionStatus.DISMISSED and mission.finish ~= nil then
                pcall(mission.finish, mission, MissionFinishState.SUCCESS)
            end

            if mission.status == MissionStatus.FINISHED then
                self:finalizeAssignment(assignment)
            elseif mission.status ~= MissionStatus.DISMISSED then
                pcall(g_missionManager.cancelMission, g_missionManager, mission)
                pcall(g_missionManager.dismissMission, g_missionManager, mission)
                self:removeAssignment(assignment)
            else
                self:removeAssignment(assignment)
            end

            self.scanTimerMs = 0
            self:setNeighborFarmBalance(1, "PROGRESS_STALL_TIMEOUT")
            return
        end

        if now >= Utils.getNoNil(assignment.nextCompletionStallLogAtMs, 0) then
            assignment.nextCompletionStallLogAtMs = now + 30000
            nfwLogInfo(
                "[%s] Auftrag-Fortschritt unveraendert: mission=%s progress=%d%% unchangedFor=%ds timeoutIn=%ds",
                self.MOD_NAME,
                tostring(assignment.key),
                completionPercent,
                math.floor(unchangedMs / 1000),
                math.floor(math.max(0, 120000 - unchangedMs) / 1000)
            )
        end
    end

    if not isAiActive then
        if assignment.aiInactiveSinceMs == nil then
            assignment.aiInactiveSinceMs = now
        end
        assignment.noMovementSinceMs = nil
        assignment.lastMovementCheckX = x
        assignment.lastMovementCheckZ = z
        assignment.stuckCheckAnchorX = nil
        assignment.stuckCheckAnchorZ = nil
        assignment.stuckCheckAnchorAtMs = 0
    else
        assignment.aiInactiveSinceMs = nil

        if assignment.lastMovementCheckX == nil or assignment.lastMovementCheckZ == nil then
            assignment.lastMovementCheckX = x
            assignment.lastMovementCheckZ = z
            assignment.noMovementSinceMs = now
        else
            local movedSq = MathUtil.vector2LengthSq(x - assignment.lastMovementCheckX, z - assignment
                .lastMovementCheckZ)
            local movedEnough = movedSq > (0.25 * 0.25)
            local hasUsefulSpeed = speed > 0.5

            if movedEnough or hasUsefulSpeed then
                assignment.noMovementSinceMs = nil
                assignment.lastMovementCheckX = x
                assignment.lastMovementCheckZ = z
            elseif assignment.noMovementSinceMs == nil then
                assignment.noMovementSinceMs = now
            end
        end

        if assignment.stuckCheckAnchorX == nil or assignment.stuckCheckAnchorZ == nil then
            assignment.stuckCheckAnchorX = x
            assignment.stuckCheckAnchorZ = z
            assignment.stuckCheckAnchorAtMs = now
        elseif now >= Utils.getNoNil(assignment.stuckCheckAnchorAtMs, now) + 30000 then
            local deltaX = x - assignment.stuckCheckAnchorX
            local deltaZ = z - assignment.stuckCheckAnchorZ
            local movedDistance = MathUtil.vector2Length(deltaX, deltaZ)
            if movedDistance < 1.0 then
                stuckDistance30s = movedDistance
            else
                assignment.stuckCheckAnchorX = x
                assignment.stuckCheckAnchorZ = z
                assignment.stuckCheckAnchorAtMs = now
            end
        end
    end

    local isFarFromField = dist ~= nil and dist > 180 and not isAtMissionField
    local inEarlyStartWindow = assignment.aiStartTimeMs ~= nil and now <= assignment.aiStartTimeMs + 60000
    if isFarFromField and inEarlyStartWindow then
        if assignment.aiFarSinceMs == nil then
            assignment.aiFarSinceMs = now
        end
    else
        assignment.aiFarSinceMs = nil
    end

    local shouldRecover = false
    local recoverReason = nil
    local hadRecentNoFieldStop = false
    local hadRecentSuccessStop = false
    if type(assignment.helperDiagLastStopReason) == "string"
        and string.sub(assignment.helperDiagLastStopReason, 1, 21) == "ERROR_NO_FIELD_FOUND|"
        and type(assignment.helperDiagLastStopAtMs) == "number"
        and assignment.helperDiagLastStopAtMs > 0
        and now <= assignment.helperDiagLastStopAtMs + 15000 then
        hadRecentNoFieldStop = true
    elseif type(assignment.helperDiagLastStopReason) == "string"
        and string.sub(assignment.helperDiagLastStopReason, 1, 21) == "SUCCESS_FINISHED_JOB|"
        and type(assignment.helperDiagLastStopAtMs) == "number"
        and assignment.helperDiagLastStopAtMs > 0
        and now <= assignment.helperDiagLastStopAtMs + 15000 then
        hadRecentSuccessStop = true
    end

    if not isAiActive and hadRecentSuccessStop then
        local allowAutoCompleteFromSuccessStop = true
        local completionPercent = self:getMissionCompletionPercent(mission)
        if self:isSowMission(mission) and completionPercent < 98 then
            allowAutoCompleteFromSuccessStop = false
            nfwLogHelperDiag(
                "[%s] HelperDiag RECOVERY_SUCCESS_STOP_IGNORED: mission=%s reason=SOW_LOW_PROGRESS progress=%d%%",
                self.MOD_NAME,
                tostring(assignment.key),
                completionPercent
            )
        end

        if allowAutoCompleteFromSuccessStop and self:queueAssignmentAutoCompletion(assignment, "SUCCESS_FINISHED_JOB") then
            nfwLogHelperDiag(
                "[%s] HelperDiag RECOVERY_SUPPRESSED: mission=%s reason=RECENT_SUCCESS_STOP action=queueAutoComplete progress=%d%%",
                self.MOD_NAME,
                tostring(assignment.key),
                completionPercent
            )
            return
        end
    end

    if isAiActive and isUpsideDown then
        shouldRecover = true
        recoverReason = "AI_UPSIDE_DOWN"
    elseif edgeGuardTriggered then
        shouldRecover = true
        recoverReason = edgeGuardReason
    elseif assignment.aiInactiveSinceMs ~= nil then
        local inactiveForMs = now - assignment.aiInactiveSinceMs
        if hadRecentNoFieldStop and inactiveForMs >= 1200 then
            shouldRecover = true
            recoverReason = "AI_NO_FIELD_FOUND"
        elseif inactiveForMs >= 6000 then
            shouldRecover = true
            recoverReason = "AI_INACTIVE"
        end
    elseif isAiActive and stuckDistance30s ~= nil then
        shouldRecover = true
        recoverReason = "AI_STUCK_SAME_POS_30S"
    elseif isAiActive
        and assignment.noMovementSinceMs ~= nil
        and now >= assignment.noMovementSinceMs + 45000
        and speed < 0.15 then
        shouldRecover = true
        recoverReason = "AI_STUCK_NO_MOVEMENT"
    elseif assignment.aiFarSinceMs ~= nil and now >= assignment.aiFarSinceMs + 8000 and speed < 1.0 then
        shouldRecover = true
        recoverReason = "FAR_FROM_FIELD_AFTER_START"
    end

    if not shouldRecover then
        return
    end

    if (recoverReason == "AI_STUCK_SAME_POS_30S"
            or recoverReason == "EDGE_TARGET_OVERSHOOT"
            or recoverReason == "EDGE_TARGET_REACHED_NO_WORK_START")
        and self.fieldEdgeStartModeEnabled == true
        and assignment.disableEdgeStartForMission ~= true
        and assignment.lastStartUsedEdge == true then
        assignment.disableEdgeStartForMission = true
        assignment.forceDirectStart = true
        nfwLogHelperDiag(
            "[%s] HelperDiag EDGE_FALLBACK_ARMED: mission=%s vehicle=%s reason=%s action=disableEdgeStartForMission+forceDirectStart edgeDist=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
            tostring(recoverReason),
            edgeTargetDist ~= nil and string.format("%.2f", edgeTargetDist) or "n/a"
        )
    end

    nfwLogHelperDiag(
        "[%s] HelperDiag RECOVERY_TRIGGER: mission=%s reason=%s aiActive=%s sinceStartMs=%s inactiveForMs=%s speed=%.2f distToField=%s canStart=%s aiImpl=%d attached=%d upsideDown=%s lastStopReason=%s",
        self.MOD_NAME,
        tostring(assignment.key),
        tostring(recoverReason),
        tostring(isAiActive),
        assignment.aiStartTimeMs ~= nil and tostring(math.max(0, now - assignment.aiStartTimeMs)) or "n/a",
        assignment.aiInactiveSinceMs ~= nil and tostring(math.max(0, now - assignment.aiInactiveSinceMs)) or "n/a",
        speed,
        dist ~= nil and string.format("%.1f", dist) or "n/a",
        tostring(canStartFieldWork),
        aiImplementCount,
        attachedImplementsCount,
        tostring(isUpsideDown),
        tostring(assignment.helperDiagLastStopReason or "n/a")
    )

    nfwLogInfo(
        "[%s] Auftrag Recovery gestartet: mission=%s reason=%s aiActive=%s speed=%.2f distToField=%s stuckDist30s=%s",
        self.MOD_NAME,
        tostring(assignment.key),
        tostring(recoverReason),
        tostring(isAiActive),
        speed,
        dist ~= nil and string.format("%.1f", dist) or "n/a",
        stuckDistance30s ~= nil and string.format("%.2f", stuckDistance30s) or "n/a"
    )

    if isAiActive and vehicle.stopCurrentAIJob ~= nil then
        local stopMessage = nil
        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
            stopMessage = AIMessageSuccessStoppedByUser.new()
        end
        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
    end

    self:releaseAttachmentLeadVehicleLock(assignment)
    assignment.aiStarted = false
    assignment.aiMode = nil
    assignment.aiStartTimeMs = nil
    assignment.aiInactiveSinceMs = nil
    assignment.aiFarSinceMs = nil
    assignment.harvestCanStartBlockedSinceMs = 0
    assignment.nextHarvestUnblockTryAtMs = 0
    assignment.nextHarvestDeepDiagAtMs = 0
    assignment.nextCombineDriveDiagAtMs = 0
    assignment.nextCombineDriveBypassLogAtMs = 0
    assignment.nextFieldCourseDriveDiagAtMs = 0
    assignment.noMovementSinceMs = nil
    assignment.lastMovementCheckX = nil
    assignment.lastMovementCheckZ = nil
    assignment.stuckCheckAnchorX = nil
    assignment.stuckCheckAnchorZ = nil
    assignment.stuckCheckAnchorAtMs = 0
    assignment.vehicle = nil
    assignment.attachAlignMode = 1
    assignment.attachFailedPasses = 0
    self:resetAttachWorkflowState(assignment)
    local preferSoftRestart = false
    if type(assignment.helperDiagLastStopReason) == "string" then
        preferSoftRestart = string.sub(assignment.helperDiagLastStopReason, 1, 21) == "ERROR_NO_FIELD_FOUND|"
            or string.sub(assignment.helperDiagLastStopReason, 1, 20) == "ERROR_NOT_REACHABLE|"
            or string.sub(assignment.helperDiagLastStopReason, 1, 24) == "ERROR_COULD_NOT_PREPARE|"
    end
    assignment.forceRecoveryReposition = not preferSoftRestart
    assignment.forceRecoveryReason = assignment.forceRecoveryReposition and recoverReason or nil
    if assignment.forceRecoveryReposition then
        assignment.recoveredFromSave = false
    end
    if recoverReason == "AI_STUCK_NO_MOVEMENT"
        or recoverReason == "AI_STUCK_SAME_POS_30S"
        or recoverReason == "FAR_FROM_FIELD_AFTER_START"
        or recoverReason == "AI_UPSIDE_DOWN"
        or recoverReason == "AI_NO_FIELD_FOUND"
        or recoverReason == "EDGE_TARGET_OVERSHOOT"
        or recoverReason == "EDGE_TARGET_REACHED_NO_WORK_START" then
        assignment.forceDirectStart = true
    end
    if preferSoftRestart then
        nfwLogHelperDiag(
            "[%s] HelperDiag RECOVERY_SOFT_RESTART: mission=%s reason=%s lastStop=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(recoverReason),
            tostring(assignment.helperDiagLastStopReason)
        )
    end
    assignment.nextStartAfterAttachMs = 0
    assignment.nextStartDelayLogAtMs = 0
    assignment.nextAttachDebugLogAtMs = 0
    assignment.nextResourceTopupAtMs = 0
    assignment.nextNoHelperLogAtMs = 0
    assignment.nextFrontLiftEnforceAtMs = 0
    assignment.sowZeroAreaActiveSinceMs = nil
    assignment.sowZeroAreaLastSummary = nil
    assignment.nextSowZeroAreaRecoveryLogAtMs = 0
    assignment.lastObservedAiImplementCount = nil
    assignment.aiImplementCountStableSinceMs = 0

    self:tryStartPendingAssignment(assignment)
end

function NeighborFieldWorkers:restoreSowAIImplementOrderOverrides(mission)
    if mission == nil or mission.vehicles == nil then
        return
    end

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and type(vehicle.nfwOriginalGetAttachedAIImplements) == "function"
            and vehicle.nfwSowAIImplementOrderOverrideActive == true then
            vehicle.getAttachedAIImplements = vehicle.nfwOriginalGetAttachedAIImplements
            vehicle.nfwOriginalGetAttachedAIImplements = nil
            vehicle.nfwSowAIImplementOrderOverrideActive = nil
            vehicle.nfwSowAIImplementOrderLogDone = nil
        end
    end
end

function NeighborFieldWorkers:prepareMissionVehicles(assignment)
    if assignment.vehiclesPrepared then
        return
    end

    local mission = assignment.mission
    if mission == nil or mission.vehicles == nil then
        return
    end

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle.setIsTabbable ~= nil then
            vehicle:setIsTabbable(false)
        end

        if self.neighborFarmId ~= nil
            and vehicle.setOwnerFarmId ~= nil
            and vehicle.getOwnerFarmId ~= nil
            and vehicle:getOwnerFarmId() ~= self.neighborFarmId then
            vehicle:setOwnerFarmId(self.neighborFarmId, true)
        end
    end

    assignment.vehiclesPrepared = true
end

function NeighborFieldWorkers:releaseAttachmentLeadVehicleLock(assignment)
    if assignment == nil or assignment.attachLockState == nil then
        return
    end

    -- Soft-lock only: avoid rigid body type changes (can hard-freeze physics on some setups).
    assignment.attachLockState = nil
end

function NeighborFieldWorkers:lockLeadVehicleForAttachment(assignment, vehicle)
    if assignment == nil
        or vehicle == nil
        or vehicle.isDeleted
        or vehicle.components == nil
        or vehicle.rootNode == nil then
        return false
    end

    if assignment.attachLockState ~= nil and assignment.attachLockState.vehicle == vehicle then
        return true
    end

    self:releaseAttachmentLeadVehicleLock(assignment)

    local lockX, lockY, lockZ = getWorldTranslation(vehicle.rootNode)
    local _, yRot, _ = getWorldRotation(vehicle.rootNode)
    assignment.attachLockState = {
        vehicle = vehicle,
        lockX = lockX,
        lockY = lockY,
        lockZ = lockZ,
        lockYRot = yRot,
        startedAt = g_time or 0
    }

    return true
end

function NeighborFieldWorkers:stabilizeLockedLeadVehicle(assignment)
    if assignment == nil or assignment.attachLockState == nil then
        return
    end

    local state = assignment.attachLockState
    local vehicle = state.vehicle
    if vehicle == nil
        or vehicle.isDeleted
        or vehicle.rootNode == nil
        or vehicle.setAbsolutePosition == nil
        or type(state.lockX) ~= "number"
        or type(state.lockY) ~= "number"
        or type(state.lockZ) ~= "number"
        or type(state.lockYRot) ~= "number" then
        return
    end

    vehicle:setAbsolutePosition(state.lockX, state.lockY, state.lockZ, 0, state.lockYRot, 0)
end

function NeighborFieldWorkers:detachMissionVehiclesForRecovery(assignment)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil then
        return 0
    end

    local detachedCount = 0
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.getAttachedImplements ~= nil
            and vehicle.detachImplementByObject ~= nil then
            local attachedImplements = vehicle:getAttachedImplements()
            if attachedImplements ~= nil then
                for i = #attachedImplements, 1, -1 do
                    local implement = attachedImplements[i]
                    if implement ~= nil and implement.object ~= nil then
                        local okDetach, detached = pcall(vehicle.detachImplementByObject, vehicle, implement.object, true)
                        if okDetach and detached ~= false then
                            detachedCount = detachedCount + 1
                        end
                    end
                end
            end
        end
    end

    return detachedCount
end

function NeighborFieldWorkers:relocateMissionVehiclesToField(assignment, forceRelocate)
    local mission = assignment.mission
    if mission == nil or mission.vehicles == nil or #mission.vehicles == 0 then
        return false
    end
    forceRelocate = forceRelocate == true

    local now = g_time or 0
    if now < assignment.lastRelocateTryTime + 2000 then
        return assignment.vehiclesRelocated
    end
    assignment.lastRelocateTryTime = now

    if forceRelocate then
        self:releaseAttachmentLeadVehicleLock(assignment)
    end

    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    if fieldX == nil or fieldZ == nil then
        return false
    end

    if g_currentMission == nil or g_currentMission.terrainRootNode == nil then
        return false
    end

    local moved = 0
    local nearField = 0
    local anchorX = fieldX
    local anchorZ = fieldZ + (forceRelocate and 0 or 18)
    local dirX, dirZ
    if forceRelocate then
        dirX, dirZ = self:getMissionSpawnDirection(mission)
    else
        dirX = fieldX - anchorX
        dirZ = fieldZ - anchorZ
        local dirLen = math.max(0.001, MathUtil.vector2Length(dirX, dirZ))
        dirX = dirX / dirLen
        dirZ = dirZ / dirLen
    end
    local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
    local skipDistSq = NFW_FORCE_RELOCATE_SKIP_DISTANCE_M * NFW_FORCE_RELOCATE_SKIP_DISTANCE_M
    local precheckDistSq = NFW_FORCE_RELOCATE_PRECHECK_DISTANCE_M * NFW_FORCE_RELOCATE_PRECHECK_DISTANCE_M

    local function getAngleDeltaAbs(a, b)
        local delta = (a - b + math.pi) % (math.pi * 2)
        delta = delta - math.pi
        return math.abs(delta)
    end

    local function isPlacementWithinTolerance(vehicle, targetX, targetZ, targetYRot, distSqLimit, rotLimit)
        if vehicle == nil or vehicle.isDeleted or vehicle.rootNode == nil then
            return false
        end

        local currentX, _, currentZ = getWorldTranslation(vehicle.rootNode)
        if MathUtil.vector2LengthSq(currentX - targetX, currentZ - targetZ) > distSqLimit then
            return false
        end

        local _, currentYRot, _ = getWorldRotation(vehicle.rootNode)
        if getAngleDeltaAbs(currentYRot, targetYRot) > rotLimit then
            return false
        end

        return true
    end

    if forceRelocate then
        local precheckLead = self:findPrimaryMissionVehicle(mission)
        if precheckLead ~= nil and precheckLead.rootNode ~= nil then
            local precheckAllGood = isPlacementWithinTolerance(
                precheckLead,
                anchorX,
                anchorZ,
                yRot,
                precheckDistSq,
                NFW_FORCE_RELOCATE_PRECHECK_ROT_RAD
            )
            local prePerpX = -dirZ
            local prePerpZ = dirX
            local preRearIndex = 0
            local preFrontIndex = 0

            if precheckAllGood then
                for _, vehicle in ipairs(mission.vehicles) do
                    if vehicle ~= nil
                        and vehicle ~= precheckLead
                        and vehicle.rootNode ~= nil
                        and not vehicle.isDeleted then
                        local attacherVehicle = nil
                        if vehicle.getAttacherVehicle ~= nil then
                            attacherVehicle = vehicle:getAttacherVehicle()
                        end

                        if attacherVehicle == nil then
                            local isFront = self:isLikelyFrontSupportImplement(vehicle, mission)
                            local sideIndex = 1
                            if isFront then
                                preFrontIndex = preFrontIndex + 1
                                sideIndex = preFrontIndex
                            else
                                preRearIndex = preRearIndex + 1
                                sideIndex = preRearIndex
                            end

                            local desiredDist = self:getImplementPlacementDistanceForVehicle(precheckLead, vehicle, isFront)
                            local isSowRearChain = self:isSowMission(mission) and not isFront
                            if isSowRearChain and sideIndex > 1 then
                                desiredDist = desiredDist + (sideIndex - 1) * 2.0
                            end
                            local lateral = 0
                            if sideIndex > 1 and not isSowRearChain then
                                local lateralIdx = sideIndex - 2
                                local lateralMag = 1.2 + math.floor(lateralIdx / 2) * 0.6
                                local lateralSign = (lateralIdx % 2 == 0) and -1 or 1
                                lateral = lateralSign * lateralMag
                            end

                            local directionSign = isFront and 1 or -1
                            local targetX = anchorX + dirX * desiredDist * directionSign + prePerpX * lateral
                            local targetZ = anchorZ + dirZ * desiredDist * directionSign + prePerpZ * lateral

                            if not isPlacementWithinTolerance(
                                    vehicle,
                                    targetX,
                                    targetZ,
                                    yRot,
                                    precheckDistSq,
                                    NFW_FORCE_RELOCATE_PRECHECK_ROT_RAD) then
                                precheckAllGood = false
                                break
                            end
                        end
                    end
                end
            end

            if precheckAllGood then
                for _, vehicle in ipairs(mission.vehicles) do
                    if vehicle ~= nil and not vehicle.isDeleted and vehicle.rootNode ~= nil then
                        nearField = nearField + 1
                    end
                end

                assignment.vehiclesRelocated = nearField > 0
                nfwLogInfo(
                    "[%s] Missionsfahrzeuge Feld-Position: mission=%s moved=%d nearField=%d fieldX=%.1f fieldZ=%.1f",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    0,
                    nearField,
                    fieldX,
                    fieldZ
                )
                nfwLogInfo(
                    "[%s] Missionsfahrzeuge Recovery-Reposition: mission=%s skipped(precheckAlreadyAligned=true)",
                    self.MOD_NAME,
                    tostring(assignment.key)
                )
                return true
            end
        end

        local shouldDetachForForceRelocate = assignment ~= nil and assignment.forceRecoveryReposition == true
        if shouldDetachForForceRelocate then
            self:detachMissionVehiclesForRecovery(assignment)
        else
            nfwLogAttachDebug(
                "[%s] Relocate(force): skipping detach to preserve pre-attached chains: mission=%s",
                self.MOD_NAME,
                tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission))
            )
        end

        local leadVehicle = self:findPrimaryMissionVehicle(mission)
        local perpX = -dirZ
        local perpZ = dirX
        local rearIndex = 0
        local frontIndex = 0

        if leadVehicle ~= nil and leadVehicle.rootNode ~= nil and leadVehicle.setAbsolutePosition ~= nil then
            local leadY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, anchorX, 0, anchorZ)
            if isPlacementWithinTolerance(
                    leadVehicle,
                    anchorX,
                    anchorZ,
                    yRot,
                    skipDistSq,
                    NFW_FORCE_RELOCATE_SKIP_ROT_RAD) then
                nearField = nearField + 1
            else
                leadVehicle:setAbsolutePosition(anchorX, leadY + 0.5, anchorZ, 0, yRot, 0)
                moved = moved + 1
            end
        end

        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil and vehicle.rootNode ~= nil and not vehicle.isDeleted and vehicle.setAbsolutePosition ~= nil and vehicle ~= leadVehicle then
                local attacherVehicle = nil
                if vehicle.getAttacherVehicle ~= nil then
                    attacherVehicle = vehicle:getAttacherVehicle()
                end
                if attacherVehicle ~= nil then
                    nearField = nearField + 1
                else
                    local isFront = self:isLikelyFrontSupportImplement(vehicle, mission)
                    local sideIndex = 1
                    if isFront then
                        frontIndex = frontIndex + 1
                        sideIndex = frontIndex
                    else
                        rearIndex = rearIndex + 1
                        sideIndex = rearIndex
                    end

                    local desiredDist = self:getImplementPlacementDistanceForVehicle(leadVehicle, vehicle, isFront)
                    local isSowRearChain = self:isSowMission(mission) and not isFront
                    if isSowRearChain and sideIndex > 1 then
                        -- Keep rear seeding chains (e.g. Kredo -> Versa) in line behind the tractor.
                        desiredDist = desiredDist + (sideIndex - 1) * 2.0
                    end
                    local lateral = 0
                    if sideIndex > 1 and not isSowRearChain then
                        local lateralIdx = sideIndex - 2
                        local lateralMag = 1.2 + math.floor(lateralIdx / 2) * 0.6
                        local lateralSign = (lateralIdx % 2 == 0) and -1 or 1
                        lateral = lateralSign * lateralMag
                    end

                    local directionSign = isFront and 1 or -1
                    local px = anchorX + dirX * desiredDist * directionSign + perpX * lateral
                    local pz = anchorZ + dirZ * desiredDist * directionSign + perpZ * lateral
                    local py = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 0, pz)

                    if isPlacementWithinTolerance(
                            vehicle,
                            px,
                            pz,
                            yRot,
                            skipDistSq,
                            NFW_FORCE_RELOCATE_SKIP_ROT_RAD) then
                        nearField = nearField + 1
                    else
                        vehicle:setAbsolutePosition(px, py + 0.5, pz, 0, yRot, 0)
                        moved = moved + 1
                        nfwLogHelperDiag(
                            "[%s] HelperDiag RECOVERY_RELOCATE_SIDE: mission=%s vehicle=%s side=%s pos=(%.2f/%.2f) dist=%.1f",
                            self.MOD_NAME,
                            tostring(assignment.key),
                            tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
                            isFront and "front" or "rear",
                            px,
                            pz,
                            desiredDist
                        )
                    end
                end
            end
        end
    else
        local repositionIndex = 0
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil and vehicle.rootNode ~= nil and not vehicle.isDeleted and vehicle.setAbsolutePosition ~= nil then
                local attacherVehicle = nil
                if vehicle.getAttacherVehicle ~= nil then
                    attacherVehicle = vehicle:getAttacherVehicle()
                end
                if attacherVehicle ~= nil then
                    nearField = nearField + 1
                else
                    local x, _, z = getWorldTranslation(vehicle.rootNode)
                    local distToFieldSq = MathUtil.vector2LengthSq(x - fieldX, z - fieldZ)
                    if distToFieldSq < (140 * 140) then
                        nearField = nearField + 1
                    else
                        local offset = repositionIndex * 5.0
                        local px = anchorX - dirX * offset
                        local pz = anchorZ - dirZ * offset
                        local py = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 0, pz)

                        vehicle:setAbsolutePosition(px, py + 0.5, pz, 0, yRot, 0)
                        moved = moved + 1
                        repositionIndex = repositionIndex + 1
                    end
                end
            end
        end
    end

    assignment.vehiclesRelocated = (nearField + moved) > 0

    if moved > 0 or nearField > 0 then
        local shouldLog = moved > 0
        local now = g_time or 0
        if not shouldLog and now >= assignment.nextRelocateLogAtMs then
            shouldLog = true
            assignment.nextRelocateLogAtMs = now + 15000
        end

        if shouldLog then
            nfwLogInfo(
                "[%s] Missionsfahrzeuge Feld-Position: mission=%s moved=%d nearField=%d fieldX=%.1f fieldZ=%.1f",
                self.MOD_NAME,
                tostring(assignment.key),
                moved,
                nearField,
                fieldX,
                fieldZ
            )
            if forceRelocate and moved > 0 then
                nfwLogInfo("[%s] Missionsfahrzeuge Recovery-Reposition: mission=%s forced=true", self.MOD_NAME,
                    tostring(assignment.key))
            elseif forceRelocate then
                nfwLogInfo("[%s] Missionsfahrzeuge Recovery-Reposition: mission=%s skipped(alreadyInPlace=true)",
                    self.MOD_NAME, tostring(assignment.key))
            end
        end
        return true
    end

    return false
end

function NeighborFieldWorkers:shouldSkipForcedRecoveryRepositionOnLoad(assignment)
    if assignment == nil or assignment.recoveredFromSave ~= true then
        return false
    end

    local recoveryReason = tostring(assignment.forceRecoveryReason or "")
    if recoveryReason == "SOW_LOW_PROBE" then
        return false
    end
    if recoveryReason == "AI_STUCK_SAME_POS_30S"
        or recoveryReason == "AI_STUCK_NO_MOVEMENT"
        or recoveryReason == "AI_UPSIDE_DOWN"
        or recoveryReason == "FAR_FROM_FIELD_AFTER_START"
        or recoveryReason == "AI_NO_FIELD_FOUND" then
        return false
    end

    local mission = assignment.mission
    if mission == nil or mission.vehicles == nil or #mission.vehicles == 0 then
        return false
    end

    local leadVehicle = self:findPrimaryMissionVehicle(mission)
    if leadVehicle == nil or leadVehicle.rootNode == nil then
        return false
    end

    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    if fieldX == nil or fieldZ == nil then
        return false
    end

    local leadX, _, leadZ = getWorldTranslation(leadVehicle.rootNode)
    local leadDistSq = MathUtil.vector2LengthSq(leadX - fieldX, leadZ - fieldZ)
    if leadDistSq > (220 * 220) then
        return false
    end

    local missingImplements = self:getUnattachedMissionImplements(mission)
    if #missingImplements > 0 then
        return false
    end

    return true
end

function NeighborFieldWorkers:getAttachModeName(mode)
    if mode == 2 then
        return "front-fallback"
    elseif mode == 3 then
        return "front-fallback-flip"
    end
    return "rear-first"
end

function NeighborFieldWorkers:isXt390Info(info)
    return info ~= nil and nfwIsXt390XmlPath(info.filename)
end

function NeighborFieldWorkers:isXt390Vehicle(vehicle)
    return vehicle ~= nil and not vehicle.isDeleted and nfwIsXt390XmlPath(vehicle.configFileName)
end

function NeighborFieldWorkers:missionHasXt390RearImplement(mission)
    if mission == nil then
        return false
    end

    if mission.vehicles ~= nil then
        for _, vehicle in ipairs(mission.vehicles) do
            if self:isXt390Vehicle(vehicle) and not self:isLikelyFrontSupportImplement(vehicle, mission) then
                return true
            end
        end
    end

    if mission.vehiclesToLoad ~= nil then
        for _, info in ipairs(mission.vehiclesToLoad) do
            if self:isXt390Info(info) then
                local forcedFront = false
                if mission.nfwForcedFrontImplementFilenameSet ~= nil and info ~= nil and info.filename ~= nil then
                    local infoFileKey = nfwNormalizeXmlPath(info.filename)
                    local infoFileBase = nfwGetXmlBasename(info.filename)
                    forcedFront = mission.nfwForcedFrontImplementFilenameSet[infoFileKey] == true
                        or (infoFileBase ~= nil and mission.nfwForcedFrontImplementFilenameSet[infoFileBase] == true)
                end
                if not forcedFront and not self:isLikelyFrontAttachmentInfo(info) then
                    return true
                end
            end
        end
    end

    return false
end

function NeighborFieldWorkers:getAttachPhaseWaitMs(assignment, phaseName)
    if phaseName ~= nil and string.find(tostring(phaseName), "rear", 1, true) ~= nil then
        local mission = assignment ~= nil and assignment.mission or nil
        if self:missionHasXt390RearImplement(mission) then
            return NFW_XT390_FAST_REAR_WAIT_MS
        end
    end

    return NFW_ATTACH_STEP_WAIT_MS
end

function NeighborFieldWorkers:getAttachRetryWaitMs(assignment, phaseName)
    local baseWaitMs = self:getAttachPhaseWaitMs(assignment, phaseName)
    return math.min(baseWaitMs, NFW_ATTACH_RETRY_WAIT_MS)
end

function NeighborFieldWorkers:addVehicleFilenameToPlacementSet(setTable, filename)
    if setTable == nil or filename == nil or filename == "" then
        return
    end

    local fileKey = nfwNormalizeXmlPath(filename)
    local fileBase = nfwGetXmlBasename(filename)
    if fileKey ~= nil and fileKey ~= "" then
        setTable[fileKey] = true
    end
    if fileBase ~= nil and fileBase ~= "" then
        setTable[fileBase] = true
    end
end

function NeighborFieldWorkers:canUseAttachSideSwapFallback(assignment)
    if assignment == nil or assignment.mission == nil then
        return false
    end

    local mission = assignment.mission
    if self:isSowMission(mission) then
        return false
    end

    if self:isHarvestMission(mission) and mission.vehicles ~= nil then
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil and not vehicle.isDeleted and self:isLikelyTowBehindHarvestCombineVehicle(vehicle) then
                return false
            end
        end
    end

    return true
end

function NeighborFieldWorkers:applyAttachSideSwapFallback(assignment)
    if not self:canUseAttachSideSwapFallback(assignment) then
        return false
    end

    local mission = assignment.mission
    if mission == nil or mission.vehicles == nil then
        return false
    end

    local candidates = {}
    local frontCurrent = {}
    local rearCurrent = {}

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.spec_motorized == nil
            and vehicle.rootNode ~= nil
            and vehicle.getAttacherVehicle ~= nil
            and vehicle:getAttacherVehicle() == nil then
            table.insert(candidates, vehicle)
            if self:isLikelyFrontSupportImplement(vehicle, mission) then
                table.insert(frontCurrent, vehicle)
            else
                table.insert(rearCurrent, vehicle)
            end
        end
    end

    if #candidates < 2 then
        return false
    end

    local targetFront = {}
    local targetRear = {}

    if #frontCurrent > 0 and #rearCurrent > 0 then
        for _, vehicle in ipairs(rearCurrent) do
            table.insert(targetFront, vehicle)
        end
        for _, vehicle in ipairs(frontCurrent) do
            table.insert(targetRear, vehicle)
        end
    else
        local source = #rearCurrent > 0 and rearCurrent or frontCurrent
        if #source < 2 then
            return false
        end

        local frontPickIdx = 1
        if #rearCurrent > 0 then
            for i, vehicle in ipairs(source) do
                local configLower = string.lower(tostring(vehicle.configFileName or ""))
                local isTankLike = vehicle.spec_frontTank ~= nil
                    or vehicle.spec_weight ~= nil
                    or string.find(configLower, "tank", 1, true) ~= nil
                if isTankLike then
                    frontPickIdx = i
                    break
                end
            end

            for i, vehicle in ipairs(source) do
                if i == frontPickIdx then
                    table.insert(targetFront, vehicle)
                else
                    table.insert(targetRear, vehicle)
                end
            end
        else
            local rearPickIdx = 1
            for i, vehicle in ipairs(source) do
                if self:isFieldworkMissionImplement(vehicle) then
                    rearPickIdx = i
                    break
                end
            end

            for i, vehicle in ipairs(source) do
                if i == rearPickIdx then
                    table.insert(targetRear, vehicle)
                else
                    table.insert(targetFront, vehicle)
                end
            end
        end
    end

    if #targetFront == 0 or #targetRear == 0 then
        return false
    end

    local frontSet = {}
    local rearSet = {}
    local frontNames = {}
    local rearNames = {}

    for _, vehicle in ipairs(targetFront) do
        self:addVehicleFilenameToPlacementSet(frontSet, tostring(vehicle.configFileName or ""))
        table.insert(frontNames, tostring(vehicle.getName ~= nil and vehicle:getName() or vehicle.configFileName or "unknown"))
    end

    for _, vehicle in ipairs(targetRear) do
        self:addVehicleFilenameToPlacementSet(rearSet, tostring(vehicle.configFileName or ""))
        table.insert(rearNames, tostring(vehicle.getName ~= nil and vehicle:getName() or vehicle.configFileName or "unknown"))
    end

    mission.nfwForcedFrontImplementFilenameSet = next(frontSet) ~= nil and frontSet or nil
    mission.nfwForcedRearImplementFilenameSet = next(rearSet) ~= nil and rearSet or nil

    nfwLogInfo(
        "[%s] Attach-Fallback Seitenwechsel: mission=%s front=[%s] rear=[%s]",
        self.MOD_NAME,
        tostring(assignment.key),
        table.concat(frontNames, ", "),
        table.concat(rearNames, ", ")
    )

    return true
end

function NeighborFieldWorkers:ensureSprayMissionFrontRearPlacementHints(mission)
    if mission == nil or mission.vehicles == nil then
        return
    end
    if not self:isSprayMission(mission) and not self:isFertilizeMission(mission) then
        return
    end

    local implements = {}
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.spec_motorized == nil
            and vehicle.rootNode ~= nil
            and vehicle.getAttacherVehicle ~= nil
            and vehicle:getAttacherVehicle() == nil then
            table.insert(implements, vehicle)
        end
    end

    if #implements < 2 then
        return
    end

    local frontCandidate = nil
    local rearCandidate = nil

    for _, vehicle in ipairs(implements) do
        local configLower = string.lower(tostring(vehicle.configFileName or ""))
        local hasExplicitTankToken = nfwContainsAny(configLower, { "fronttank", "front_tank", "_tank", " tank" })
        local isTankLike = vehicle.spec_frontTank ~= nil
            or vehicle.spec_weight ~= nil
            or string.find(configLower, "fronttank", 1, true) ~= nil
            or string.find(configLower, "tank", 1, true) ~= nil
        if hasExplicitTankToken or vehicle.spec_frontTank ~= nil or vehicle.spec_weight ~= nil then
            frontCandidate = vehicle
            break
        end
        if isTankLike and not self:isFieldworkMissionImplement(vehicle) then
            frontCandidate = vehicle
            break
        end
    end

    if frontCandidate ~= nil then
        for _, vehicle in ipairs(implements) do
            if vehicle ~= frontCandidate and self:isFieldworkMissionImplement(vehicle) then
                rearCandidate = vehicle
                break
            end
        end
        if rearCandidate == nil then
            for _, vehicle in ipairs(implements) do
                if vehicle ~= frontCandidate then
                    rearCandidate = vehicle
                    break
                end
            end
        end
    end

    if frontCandidate == nil or rearCandidate == nil then
        return
    end

    local frontSet = {}
    local rearSet = {}
    self:addVehicleFilenameToPlacementSet(frontSet, tostring(frontCandidate.configFileName or ""))
    self:addVehicleFilenameToPlacementSet(rearSet, tostring(rearCandidate.configFileName or ""))
    mission.nfwForcedFrontImplementFilenameSet = next(frontSet) ~= nil and frontSet or nil
    mission.nfwForcedRearImplementFilenameSet = next(rearSet) ~= nil and rearSet or nil
end

function NeighborFieldWorkers:handleAttachFailureFallback(assignment, side, pendingCount, attachWarnings)
    if assignment == nil then
        return false
    end

    assignment.attachFailureStreak = Utils.getNoNil(assignment.attachFailureStreak, 0) + 1
    assignment.attachFailedPasses = Utils.getNoNil(assignment.attachFailedPasses, 0) + 1

    if assignment.attachFailureStreak >= NFW_ATTACH_FAILED_PASSES_BEFORE_SIDE_SWAP then
        local swappedSides = self:applyAttachSideSwapFallback(assignment)
        assignment.attachFailureStreak = 0
        if swappedSides then
            assignment.attachFailedPasses = 0
            self:respawnAssignmentVehiclesAtStartPosition(assignment, "ATTACH_SIDE_SWAP")
            return true
        end
    end

    if assignment.attachFailedPasses < NFW_ATTACH_FAILED_PASSES_BEFORE_RESPAWN then
        return false
    end

    local warningText = "none"
    if type(attachWarnings) == "table" and #attachWarnings > 0 then
        warningText = table.concat(attachWarnings, " | ")
    end

    nfwLogInfo(
        "[%s] Auto-Recovery wegen Attach-Fehlschlaegen: mission=%s side=%s failedPasses=%d pending=%s warnings=%s",
        self.MOD_NAME,
        tostring(assignment.key),
        tostring(side or "unknown"),
        assignment.attachFailedPasses,
        tostring(pendingCount),
        warningText
    )

    assignment.attachFailedPasses = 0
    self:respawnAssignmentVehiclesAtStartPosition(assignment,
        string.format("ATTACH_%s_STUCK", string.upper(tostring(side or "UNKNOWN"))))
    return true
end

function NeighborFieldWorkers:tryAutoAttachMissionImplements(assignment)
    local mission = assignment.mission
    if mission == nil or mission.vehicles == nil then
        self:releaseAttachmentLeadVehicleLock(assignment)
        return
    end

    self:ensureSprayMissionFrontRearPlacementHints(mission)

    local missingBefore = self:getUnattachedMissionImplements(mission)
    if #missingBefore == 0 then
        assignment.attachFailedPasses = 0
        assignment.attachFailureStreak = 0
        self:resetAttachWorkflowState(assignment)
        self:releaseAttachmentLeadVehicleLock(assignment)
        return
    end

    local now = g_time or 0
    local phase = assignment.sprayerAttachPhase
    if phase == nil then
        local rearPending, frontPending = self:getPendingMissionImplementsBySide(mission)
        if #frontPending == 0 and #rearPending == 0 then
            self:resetAttachWorkflowState(assignment)
            self:releaseAttachmentLeadVehicleLock(assignment)
            return
        end

        local nextPhase = #rearPending > 0 and "wait_before_rear" or "wait_before_front"
        local waitMs = self:getAttachPhaseWaitMs(assignment, nextPhase)
        assignment.attachFailedPasses = 0
        assignment.sprayerAttachPhase = nextPhase
        assignment.sprayerAttachNextMs = now + waitMs
        assignment.suppressRelocateDuringSprayerAttach = true
        nfwLogAttachDebug(
            "[%s] AttachPhase init: mission=%s phase=%s waitMs=%d",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(nextPhase),
            waitMs
        )
        return
    end

    if assignment.sprayerAttachNextMs ~= nil and now < assignment.sprayerAttachNextMs then
        return
    end

    local leadVehicle = self:findPrimaryMissionVehicle(mission)
    if leadVehicle == nil or leadVehicle.rootNode == nil then
        self:releaseAttachmentLeadVehicleLock(assignment)
        return
    end
    local leadX, _, leadZ = getWorldTranslation(leadVehicle.rootNode)
    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    local leadOnMissionField = self:isPositionWithinMissionField(mission, leadX, leadZ)
    if not leadOnMissionField and fieldX ~= nil and fieldZ ~= nil then
        local distToField = MathUtil.vector2Length(leadX - fieldX, leadZ - fieldZ)
        if distToField > 120 then
            nfwLogHelperDiag(
                "[%s] HelperDiag ATTACH_OUT_OF_FIELD_RECOVER: mission=%s vehicle=%s pos=(%.1f/%.1f) field=(%.1f/%.1f) dist=%.1f phase=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(leadVehicle.getName ~= nil and leadVehicle:getName() or "unknown"),
                leadX,
                leadZ,
                fieldX,
                fieldZ,
                distToField,
                tostring(assignment.sprayerAttachPhase)
            )
            self:releaseAttachmentLeadVehicleLock(assignment)
            self:resetAttachWorkflowState(assignment)
            assignment.sprayerAttachNextMs = now + 800
            assignment.suppressRelocateDuringSprayerAttach = false
            assignment.lastRelocateTryTime = 0
            self:relocateMissionVehiclesToField(assignment, true)
            return
        end
    end
    if self:isVehicleUpsideDown(leadVehicle) then
        self:respawnAssignmentVehiclesAtStartPosition(assignment, "ATTACH_PHASE_UPSIDE_DOWN")
        return
    end
    self:lockLeadVehicleForAttachment(assignment, leadVehicle)
    self:stabilizeLockedLeadVehicle(assignment)

    local phaseName = assignment.sprayerAttachPhase
    local rearPending, frontPending = self:getPendingMissionImplementsBySide(mission)
    local attachWarnings = {}
    local attachedCount = 0

    if phaseName == "wait_before_front" or phaseName == "wait_before_front_retry" then
        rearPending, frontPending = self:getPendingMissionImplementsBySide(mission)
        if #frontPending > 0 then
            local waitMs = self:getAttachPhaseWaitMs(assignment, phaseName)
            self:alignMissionVehiclesForAttachment(assignment, "front")
            assignment.sprayerAttachPhase = "attach_front"
            assignment.sprayerAttachNextMs = now + waitMs
            assignment.suppressRelocateDuringSprayerAttach = true
            nfwLogAttachDebug(
                "[%s] AttachPhase front-aligned: mission=%s waitMs=%d",
                self.MOD_NAME,
                tostring(assignment.key),
                waitMs
            )
            return
        elseif #rearPending > 0 then
            local waitMs = self:getAttachPhaseWaitMs(assignment, "wait_before_rear")
            assignment.sprayerAttachPhase = "wait_before_rear"
            assignment.sprayerAttachNextMs = now + waitMs
            assignment.suppressRelocateDuringSprayerAttach = true
            return
        else
            assignment.sprayerAttachPhase = "wait_before_front_lift"
            assignment.sprayerAttachNextMs = now + NFW_ATTACH_STEP_WAIT_MS
            assignment.suppressRelocateDuringSprayerAttach = true
            return
        end
    end

    if phaseName == "attach_front" then
        attachedCount, attachWarnings = self:tryAttachMissionImplementsForSide(assignment, mission, "front")
        rearPending, frontPending = self:getPendingMissionImplementsBySide(mission)
        if attachedCount > 0 then
            for _, vehicle in ipairs(mission.vehicles) do
                if vehicle.startAttacherJointCombo ~= nil then
                    vehicle:startAttacherJointCombo(true)
                end
            end
        end

        if #frontPending > 0 then
            if attachedCount == 0 then
                if self:handleAttachFailureFallback(assignment, "front", #frontPending, attachWarnings) then
                    return
                end
            else
                assignment.attachFailedPasses = 0
                assignment.attachFailureStreak = 0
            end
            if attachedCount == 0 and #rearPending > 0 then
                local waitMs = self:getAttachPhaseWaitMs(assignment, "wait_before_rear")
                assignment.sprayerAttachPhase = "wait_before_rear"
                assignment.sprayerAttachNextMs = now + waitMs
                assignment.suppressRelocateDuringSprayerAttach = true
                return
            end
            assignment.sprayerAttachPhase = "wait_before_front_retry"
            assignment.sprayerAttachNextMs = now + self:getAttachRetryWaitMs(assignment, "wait_before_front_retry")
            assignment.suppressRelocateDuringSprayerAttach = true
            if now >= Utils.getNoNil(assignment.nextAttachDebugLogAtMs, 0) then
                assignment.nextAttachDebugLogAtMs = now + 5000
                local warningText = #attachWarnings > 0 and table.concat(attachWarnings, " | ") or "none"
                nfwLogAttachDebug(
                    "[%s] AttachPhase front-pending: mission=%s pending=%d warnings=%s",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    #frontPending,
                    warningText
                )
            end
            return
        end

        if #rearPending > 0 then
            local waitMs = self:getAttachPhaseWaitMs(assignment, "wait_before_rear")
            assignment.sprayerAttachPhase = "wait_before_rear"
            assignment.sprayerAttachNextMs = now + waitMs
        else
            assignment.sprayerAttachPhase = "wait_before_front_lift"
            assignment.sprayerAttachNextMs = now + NFW_ATTACH_STEP_WAIT_MS
        end
        assignment.suppressRelocateDuringSprayerAttach = true
        assignment.attachFailedPasses = 0
        assignment.attachFailureStreak = 0
        nfwLogAttachDebug("[%s] AttachPhase front-complete: mission=%s", self.MOD_NAME, tostring(assignment.key))
        return
    end

    if phaseName == "wait_before_rear" or phaseName == "wait_before_rear_retry" then
        rearPending, frontPending = self:getPendingMissionImplementsBySide(mission)
        if #rearPending > 0 then
            local waitMs = self:getAttachPhaseWaitMs(assignment, phaseName)
            self:alignMissionVehiclesForAttachment(assignment, "rear")
            assignment.sprayerAttachPhase = "attach_rear"
            assignment.sprayerAttachNextMs = now + waitMs
            assignment.suppressRelocateDuringSprayerAttach = true
            nfwLogAttachDebug(
                "[%s] AttachPhase rear-aligned: mission=%s waitMs=%d",
                self.MOD_NAME,
                tostring(assignment.key),
                waitMs
            )
            return
        elseif #frontPending > 0 then
            local waitMs = self:getAttachPhaseWaitMs(assignment, "wait_before_front")
            assignment.sprayerAttachPhase = "wait_before_front"
            assignment.sprayerAttachNextMs = now + waitMs
            assignment.suppressRelocateDuringSprayerAttach = true
            return
        else
            assignment.sprayerAttachPhase = "wait_before_front_lift"
            assignment.sprayerAttachNextMs = now + NFW_ATTACH_STEP_WAIT_MS
            assignment.suppressRelocateDuringSprayerAttach = true
            return
        end
    end

    if phaseName == "attach_rear" then
        if #rearPending > 0 then
            attachedCount, attachWarnings = self:tryAttachMissionImplementsForSide(assignment, mission, "rear")
            rearPending, frontPending = self:getPendingMissionImplementsBySide(mission)
            if attachedCount > 0 then
                for _, vehicle in ipairs(mission.vehicles) do
                    if vehicle.startAttacherJointCombo ~= nil then
                        vehicle:startAttacherJointCombo(true)
                    end
                end
            end
        end

        if #rearPending > 0 then
            if attachedCount == 0 then
                if self:handleAttachFailureFallback(assignment, "rear", #rearPending, attachWarnings) then
                    return
                end
            else
                assignment.attachFailedPasses = 0
                assignment.attachFailureStreak = 0
            end
            if attachedCount == 0 and #frontPending > 0 then
                local waitMs = self:getAttachPhaseWaitMs(assignment, "wait_before_front")
                assignment.sprayerAttachPhase = "wait_before_front"
                assignment.sprayerAttachNextMs = now + waitMs
                assignment.suppressRelocateDuringSprayerAttach = true
                return
            end
            local waitMs = self:getAttachRetryWaitMs(assignment, "wait_before_rear_retry")
            assignment.sprayerAttachPhase = "wait_before_rear_retry"
            assignment.sprayerAttachNextMs = now + waitMs
            assignment.suppressRelocateDuringSprayerAttach = true
            if now >= Utils.getNoNil(assignment.nextAttachDebugLogAtMs, 0) then
                assignment.nextAttachDebugLogAtMs = now + 5000
                local warningText = #attachWarnings > 0 and table.concat(attachWarnings, " | ") or "none"
                nfwLogAttachDebug(
                    "[%s] AttachPhase rear-pending: mission=%s pending=%d warnings=%s",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    #rearPending,
                    warningText
                )
            end
            return
        end

        assignment.sprayerAttachPhase = "wait_before_front_lift"
        assignment.sprayerAttachNextMs = now + NFW_ATTACH_STEP_WAIT_MS
        assignment.suppressRelocateDuringSprayerAttach = true
        assignment.attachFailedPasses = 0
        assignment.attachFailureStreak = 0
        nfwLogAttachDebug("[%s] AttachPhase rear-complete: mission=%s", self.MOD_NAME, tostring(assignment.key))
        return
    end

    if phaseName == "wait_before_front_lift" then
        local allRaised = self:enforceRaisedFrontSupportImplements(assignment, true, leadVehicle)
        if not allRaised then
            assignment.sprayerAttachNextMs = now + NFW_ATTACH_STEP_WAIT_MS
            assignment.suppressRelocateDuringSprayerAttach = true
            return
        end

        assignment.sprayerAttachPhase = "wait_before_start"
        assignment.sprayerAttachNextMs = now + NFW_ATTACH_STEP_WAIT_MS
        assignment.suppressRelocateDuringSprayerAttach = true
        return
    end

    if phaseName == "wait_before_start" then
        assignment.nextStartAfterAttachMs = math.max(Utils.getNoNil(assignment.nextStartAfterAttachMs, 0),
            now + NFW_ATTACH_STEP_WAIT_MS)
        self:resetAttachWorkflowState(assignment)
        self:releaseAttachmentLeadVehicleLock(assignment)
    end
end

function NeighborFieldWorkers:findPrimaryMissionVehicle(mission)
    if mission == nil or mission.vehicles == nil then
        return nil
    end

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_motorized ~= nil and vehicle.rootNode ~= nil then
            return vehicle
        end
    end

    return nil
end

function NeighborFieldWorkers:resetAttachWorkflowState(assignment)
    if assignment == nil then
        return
    end

    assignment.sprayerPreAlignDone = false
    assignment.sprayerPreAlignUntilMs = nil
    assignment.sprayerAttachPhase = nil
    assignment.sprayerAttachNextMs = nil
    assignment.suppressRelocateDuringSprayerAttach = false
    assignment.attachFailedPasses = 0
    assignment.attachObservedSides = nil
end

function NeighborFieldWorkers:isLikelyFrontSupportImplement(vehicle, mission)
    if vehicle == nil or vehicle.isDeleted or vehicle.spec_motorized ~= nil then
        return false
    end

    if nfwIsGmd8730XmlPath(vehicle.configFileName) then
        return false
    end
    if nfwIsGmd3123FXmlPath(vehicle.configFileName) then
        return true
    end
    if self:isMowMission(mission) then
        if nfwIsMcdonR216XmlPath(vehicle.configFileName) then
            return true
        end
        if vehicle.getName ~= nil then
            local okName, displayName = pcall(vehicle.getName, vehicle)
            if okName and nfwIsMcdonR216DisplayName(displayName) then
                return true
            end
        end
    end

    if self:isHarvestMission(mission)
        and (self:isMarkedHarvestTowCombineFilename(mission, tostring(vehicle.configFileName or ""))
            or self:isLikelyTowBehindHarvestCombineVehicle(vehicle)) then
        return false
    end

    if self:isHarvestMission(mission)
        and vehicle.spec_combine ~= nil
        and vehicle.spec_motorized == nil
        and not self:isLikelyTowBehindHarvestCombineVehicle(vehicle) then
        return true
    end

    if vehicle.spec_cutter ~= nil and vehicle.spec_cutterTrailer == nil then
        return true
    end

    if mission ~= nil then
        local configKey = nfwNormalizeXmlPath(vehicle.configFileName or "")
        local configBase = nfwGetXmlBasename(vehicle.configFileName or "")
        if mission.nfwForcedRearImplementFilenameSet ~= nil then
            if mission.nfwForcedRearImplementFilenameSet[configKey] == true
                or (configBase ~= nil and mission.nfwForcedRearImplementFilenameSet[configBase] == true) then
                return false
            end
        end

        if mission.nfwForcedFrontImplementFilenameSet ~= nil then
            if mission.nfwForcedFrontImplementFilenameSet[configKey] == true
                or (configBase ~= nil and mission.nfwForcedFrontImplementFilenameSet[configBase] == true) then
                return true
            end
        end
    end

    if vehicle.spec_weight ~= nil then
        return true
    end
    if vehicle.spec_frontTank ~= nil then
        return true
    end

    if nfwIsPickUp900Text(vehicle.configFileName) then
        return true
    end
    if vehicle.getName ~= nil then
        local okName, displayName = pcall(vehicle.getName, vehicle)
        if okName and nfwIsPickUp900Text(displayName) then
            return true
        end
    end

    local configLower = string.lower(tostring(vehicle.configFileName or ""))
    if (self:isSprayMission(mission) or self:isFertilizeMission(mission)) then
        if nfwContainsAny(configLower, { "fronttank", "front_tank", "_tank", " tank" }) then
            return true
        end
        if string.find(configLower, "tank", 1, true) ~= nil
            and not self:isFieldworkMissionImplement(vehicle) then
            return true
        end
    end

    if (self:isSprayMission(mission) or self:isFertilizeMission(mission))
        and vehicle.getName ~= nil then
        local okName, displayName = pcall(vehicle.getName, vehicle)
        if okName and displayName ~= nil then
            local nameLower = string.lower(tostring(displayName))
            if nfwContainsAny(nameLower, { "front tank", "fronttank", " tank" }) then
                return true
            end
        end
    end

    if vehicle.spec_trailer ~= nil and not nfwContainsAny(configLower, { "fronttank", "front_tank", "front tank" }) then
        return false
    end
    if nfwContainsAny(configLower, { "fronttank", "front_tank", "front tank" }) then
        return true
    end
    if nfwContainsAny(configLower, { "weight", "gewicht", "ballast" }) then
        return true
    end
    if nfwContainsAny(configLower, { "gusscom", "ft1001", "kdf341", "kdf" }) then
        return true
    end
    if self:isFieldworkMissionImplement(vehicle) then
        return false
    end
    if vehicle.spec_sprayer ~= nil
        and vehicle.spec_trailer == nil
        and not self:isFieldworkMissionImplement(vehicle) then
        return true
    end

    if vehicle.getName ~= nil then
        local okName, displayName = pcall(vehicle.getName, vehicle)
        if okName and displayName ~= nil then
            local nameLower = string.lower(tostring(displayName))
            if nfwContainsAny(nameLower, { "front tank", "fronttank", "weight", "gewicht", "ballast", "front", "vorn", "frontal", "fronte", "gusscom", "ft1001", "kdf341", "kdf" }) then
                return true
            end
        end
    end

    return false
end

function NeighborFieldWorkers:getPendingMissionImplementsBySide(mission)
    local rearPending = {}
    local frontPending = {}
    if mission == nil or mission.vehicles == nil then
        return rearPending, frontPending
    end

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.spec_motorized == nil
            and vehicle.rootNode ~= nil
            and vehicle.getAttacherVehicle ~= nil
            and vehicle:getAttacherVehicle() == nil then
            if self:isLikelyFrontSupportImplement(vehicle, mission) then
                table.insert(frontPending, vehicle)
            else
                table.insert(rearPending, vehicle)
            end
        end
    end

    return rearPending, frontPending
end

function NeighborFieldWorkers:isAttachImplementsManuallyModeEnabledForVehicle(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return false
    end

    if vehicle.spec_attachConnectionHosesManually == nil and vehicle.spec_attachPowerTakeOffsManually == nil then
        return false
    end

    if type(AttachImplementsManuallySettingsManager) == "table"
        and type(AttachImplementsManuallySettingsManager.getInstance) == "function" then
        local okInstance, settingsManager = pcall(AttachImplementsManuallySettingsManager.getInstance)
        if okInstance and settingsManager ~= nil
            and type(settingsManager.getEnableAttachImplementsManually) == "function" then
            local okEnabled, enabled = pcall(settingsManager.getEnableAttachImplementsManually, settingsManager)
            if okEnabled then
                return enabled == true
            end
        end
    end

    -- If settings manager is not available but specialization exists, assume active.
    return true
end

function NeighborFieldWorkers:isManualAttachModeEnabledForPair(attacherVehicle, attachable)
    if attacherVehicle == nil or attacherVehicle.isDeleted or attachable == nil or attachable.isDeleted then
        return false
    end

    if type(g_modIsLoaded) == "table" and g_manualAttachModName ~= nil then
        local loaded = g_modIsLoaded[g_manualAttachModName]
        if loaded == false then
            return false
        end
    end

    if attachable.spec_manualAttachConnectionHoses ~= nil
        or attachable.spec_manualAttachPowerTakeOff ~= nil
        or attacherVehicle.spec_manualAttachConnectionHoses ~= nil
        or attacherVehicle.spec_manualAttachPowerTakeOff ~= nil then
        return true
    end

    -- Fallback detection when spec aliases are not exposed.
    if type(attachable.hasAttachedHoses) == "function"
        and type(attachable.connectHosesToAttacherVehicle) == "function" then
        return true
    end

    if type(attachable.isPtoAttached) == "function"
        and type(attacherVehicle.attachPowerTakeOff) == "function" then
        return true
    end

    return false
end

function NeighborFieldWorkers:ensureManualAttachConnectionsForNeighbor(attacherVehicle, attachable, attacherJointDescIndex,
                                                                        attachableJointDescIndex, assignment, mission)
    if attacherVehicle == nil or attachable == nil then
        return
    end

    local isNeighborAssignment = assignment ~= nil
        and assignment.farmId ~= nil
        and self:isNeighborFarm(assignment.farmId)
    local isNeighborMission = mission ~= nil and self:isMissionOwnedByNeighborFarm(mission)

    if not isNeighborAssignment and not isNeighborMission then
        return
    end

    local useAttachImplementsManually = self:isAttachImplementsManuallyModeEnabledForVehicle(attacherVehicle)
    local useManualAttach = self:isManualAttachModeEnabledForPair(attacherVehicle, attachable)
    if not useAttachImplementsManually and not useManualAttach then
        return
    end

    local forcedParts = {}

    local function resolveJointIndices()
        local resolvedJointDescIndex = attacherJointDescIndex
        local resolvedInputJointDescIndex = attachableJointDescIndex

        if type(attacherVehicle.getImplementIndexByObject) == "function"
            and type(attacherVehicle.getAttacherJointIndexFromImplementIndex) == "function" then
            local okIndex, implementIndex = pcall(attacherVehicle.getImplementIndexByObject, attacherVehicle, attachable)
            if okIndex and implementIndex ~= nil then
                local okJoint, jointIndex = pcall(attacherVehicle.getAttacherJointIndexFromImplementIndex, attacherVehicle,
                    implementIndex)
                if okJoint and jointIndex ~= nil then
                    resolvedJointDescIndex = jointIndex
                end
            end
        end

        if type(attachable.getActiveInputAttacherJointDescIndex) == "function" then
            local okInput, inputJointIndex = pcall(attachable.getActiveInputAttacherJointDescIndex, attachable)
            if okInput and inputJointIndex ~= nil then
                resolvedInputJointDescIndex = inputJointIndex
            end
        end

        if resolvedInputJointDescIndex == nil and attachable.spec_attachable ~= nil then
            resolvedInputJointDescIndex = attachable.spec_attachable.inputAttacherJointDescIndex
        end

        if resolvedJointDescIndex == nil
            and type(attacherVehicle.getAttachedImplements) == "function" then
            local okImplements, attachedImplements = pcall(attacherVehicle.getAttachedImplements, attacherVehicle)
            if okImplements and type(attachedImplements) == "table" then
                for _, implement in pairs(attachedImplements) do
                    if implement ~= nil and implement.object == attachable and implement.jointDescIndex ~= nil then
                        resolvedJointDescIndex = implement.jointDescIndex
                        if resolvedInputJointDescIndex == nil then
                            resolvedInputJointDescIndex = implement.inputJointDescIndex
                        end
                        break
                    end
                end
            end
        end

        if resolvedJointDescIndex == nil and type(attacherVehicle.getImplementByObject) == "function" then
            local okImplement, implement = pcall(attacherVehicle.getImplementByObject, attacherVehicle, attachable)
            if okImplement and type(implement) == "table" then
                if resolvedJointDescIndex == nil then
                    resolvedJointDescIndex = implement.jointDescIndex
                end
                if resolvedInputJointDescIndex == nil then
                    resolvedInputJointDescIndex = implement.inputJointDescIndex
                end
            end
        end

        return resolvedJointDescIndex, resolvedInputJointDescIndex
    end

    local resolvedJointDescIndex, resolvedInputJointDescIndex = resolveJointIndices()
    local info = {
        attacherVehicle = attacherVehicle,
        attachable = attachable,
        attacherVehicleJointDescIndex = resolvedJointDescIndex,
        attachableJointDescIndex = resolvedInputJointDescIndex
    }

    local function getManualAttachStateSnapshot()
        local state = {
            hoses = "n/a",
            pto = "n/a"
        }

        if type(attachable.hasAttachedHoses) == "function" then
            local okHoses, hasHoses = pcall(attachable.hasAttachedHoses, attachable)
            if okHoses then
                state.hoses = tostring(hasHoses == true)
            else
                state.hoses = "err"
            end
        end

        if type(attachable.isPtoAttached) == "function" then
            local okPto, isPto = pcall(attachable.isPtoAttached, attachable)
            if okPto then
                state.pto = tostring(isPto == true)
            else
                state.pto = "err"
            end
        end

        return state
    end

    if useAttachImplementsManually then
        local hosesSpec = attacherVehicle.spec_attachConnectionHosesManually
        if hosesSpec ~= nil
            and type(hosesSpec.attachedHoses) == "table" then
            local hosesAttached = resolvedJointDescIndex ~= nil and hosesSpec.attachedHoses[resolvedJointDescIndex] == true
            if not hosesAttached then
                local skipAutoHoseToggle = false
                if type(AttacherJointUtil) == "table" then
                    if type(AttacherJointUtil.getUsesFrontloaderToolAttacher) == "function" then
                        local okFrontloader, usesFrontloader = pcall(AttacherJointUtil.getUsesFrontloaderToolAttacher, info,
                            true)
                        if okFrontloader and usesFrontloader then
                            skipAutoHoseToggle = true
                        end
                    end
                    if not skipAutoHoseToggle and type(AttacherJointUtil.getAttachHosesIfAttachedFromInside) == "function" then
                        local okAutoHoses, autoHoses = pcall(AttacherJointUtil.getAttachHosesIfAttachedFromInside, info)
                        if okAutoHoses and autoHoses then
                            skipAutoHoseToggle = true
                        end
                    end
                end

                if not skipAutoHoseToggle then
                    local hasErrors = false

                    if type(attachable.connectHosesToAttacherVehicle) == "function" then
                        local okConnectHoses, hoseError = pcall(
                            attachable.connectHosesToAttacherVehicle,
                            attachable,
                            attacherVehicle,
                            resolvedInputJointDescIndex,
                            resolvedJointDescIndex
                        )
                        if not okConnectHoses then
                            hasErrors = true
                            nfwLogAttachDebug(
                                "[%s] ManualAttachCompat: connectHoses failed mission=%s vehicle=%s attachable=%s error=%s",
                                self.MOD_NAME,
                                tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                                tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                                tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
                                tostring(hoseError)
                            )
                        end
                    end

                    if type(attachable.connectCustomHosesToAttacherVehicle) == "function" then
                        local okConnectCustomHoses, customHoseError = pcall(
                            attachable.connectCustomHosesToAttacherVehicle,
                            attachable,
                            attacherVehicle,
                            resolvedInputJointDescIndex,
                            resolvedJointDescIndex
                        )
                        if not okConnectCustomHoses then
                            hasErrors = true
                            nfwLogAttachDebug(
                                "[%s] ManualAttachCompat: connectCustomHoses failed mission=%s vehicle=%s attachable=%s error=%s",
                                self.MOD_NAME,
                                tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                                tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                                tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
                                tostring(customHoseError)
                            )
                        end
                    end

                    if resolvedJointDescIndex ~= nil then
                        hosesSpec.attachedHoses[resolvedJointDescIndex] = true
                        table.insert(forcedParts, "hoses")
                    elseif hasErrors then
                        nfwLogAttachDebug(
                            "[%s] ManualAttachCompat: hoses unresolved joint mission=%s vehicle=%s attachable=%s",
                            self.MOD_NAME,
                            tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                            tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                            tostring(attachable.getName ~= nil and attachable:getName() or "unknown")
                        )
                    end
                end
            end
        end

        local ptoSpec = attacherVehicle.spec_attachPowerTakeOffsManually
        if ptoSpec ~= nil
            and type(ptoSpec.attachedPTOs) == "table" then
            local ptoAttached = resolvedJointDescIndex ~= nil and ptoSpec.attachedPTOs[resolvedJointDescIndex] == true
            if not ptoAttached then
                local skipAutoPTOToggle = false
                if type(AttacherJointUtil) == "table" and type(AttacherJointUtil.getAttachPTOIfAttachedFromInside) == "function" then
                    local okAutoPTO, autoPTO = pcall(AttacherJointUtil.getAttachPTOIfAttachedFromInside, info)
                    if okAutoPTO and autoPTO then
                        skipAutoPTOToggle = true
                    end
                end

                if not skipAutoPTOToggle then
                    if type(attacherVehicle.attachPowerTakeOff) == "function" then
                        local okAttachPTO, ptoError = pcall(
                            attacherVehicle.attachPowerTakeOff,
                            attacherVehicle,
                            attachable,
                            resolvedInputJointDescIndex,
                            resolvedJointDescIndex
                        )
                        if not okAttachPTO then
                            nfwLogAttachDebug(
                                "[%s] ManualAttachCompat: attachPowerTakeOff failed mission=%s vehicle=%s attachable=%s error=%s",
                                self.MOD_NAME,
                                tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                                tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                                tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
                                tostring(ptoError)
                            )
                        end
                    end

                    local powerTakeOffsSpec = attacherVehicle.spec_powerTakeOffs
                    if powerTakeOffsSpec ~= nil and type(powerTakeOffsSpec.delayedPowerTakeOffsMountings) == "table" then
                        for i = #powerTakeOffsSpec.delayedPowerTakeOffsMountings, 1, -1 do
                            local delayedMounting = powerTakeOffsSpec.delayedPowerTakeOffsMountings[i]
                            if delayedMounting ~= nil and delayedMounting.jointDescIndex == resolvedJointDescIndex then
                                local input = delayedMounting.input
                                local output = delayedMounting.output
                                if input ~= nil and input.attachFunc ~= nil then
                                    pcall(input.attachFunc, attacherVehicle, input, output)
                                end

                                if type(ObjectChangeUtil) == "table" and type(ObjectChangeUtil.setObjectChanges) == "function" then
                                    pcall(ObjectChangeUtil.setObjectChanges, input ~= nil and input.objectChanges or nil,
                                        true,
                                        attacherVehicle, attacherVehicle.setMovingToolDirty)
                                    pcall(ObjectChangeUtil.setObjectChanges, output ~= nil and output.objectChanges or nil,
                                        true,
                                        attacherVehicle, attacherVehicle.setMovingToolDirty)
                                end
                                table.remove(powerTakeOffsSpec.delayedPowerTakeOffsMountings, i)
                            end
                        end
                    end

                    if resolvedJointDescIndex ~= nil then
                        ptoSpec.attachedPTOs[resolvedJointDescIndex] = true
                        table.insert(forcedParts, "pto")
                    else
                        nfwLogAttachDebug(
                            "[%s] ManualAttachCompat: pto unresolved joint mission=%s vehicle=%s attachable=%s",
                            self.MOD_NAME,
                            tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                            tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                            tostring(attachable.getName ~= nil and attachable:getName() or "unknown")
                        )
                    end
                end
            end
        end
    end

    if useManualAttach then
        local function getManualAttachHoseTypeState()
            local states = {}
            local types = { "hydraulic", "air", "electric", "isobus" }
            for _, hoseType in ipairs(types) do
                local required = nil
                local attached = nil

                if type(ConnectionHosesExtension) == "table"
                    and type(ConnectionHosesExtension.hasConnectionHoses) == "function" then
                    local okRequired, hasType = pcall(ConnectionHosesExtension.hasConnectionHoses, attachable, attacherVehicle,
                        hoseType)
                    if okRequired then
                        required = hasType == true
                    end
                end

                if type(ConnectionHosesExtension) == "table"
                    and type(ConnectionHosesExtension.hasAttachedConnectionHoses) == "function" then
                    local okAttached, isAttached = pcall(ConnectionHosesExtension.hasAttachedConnectionHoses, attachable,
                        hoseType)
                    if okAttached then
                        attached = isAttached == true
                    end
                end

                if type(attachable.hasAttachedHosesOfType) == "function" and attached == nil then
                    local okAttachedOfType, isAttachedOfType = pcall(attachable.hasAttachedHosesOfType, attachable, hoseType)
                    if okAttachedOfType then
                        attached = isAttachedOfType == true
                    end
                end

                states[hoseType] = {
                    required = required,
                    attached = attached
                }
            end

            states.__rawTotal = 0
            states.__rawUsed = 0
            states.__allRawAttached = nil
            if type(attachable.getConnectionHosesByInputAttacherJoint) == "function"
                and type(attachable.getIsConnectionHoseUsed) == "function" then
                local inputIndices = {}
                local inputIndexSet = {}

                local function addInputIndex(index)
                    if index ~= nil and inputIndexSet[index] ~= true then
                        table.insert(inputIndices, index)
                        inputIndexSet[index] = true
                    end
                end

                addInputIndex(resolvedInputJointDescIndex)
                if attachable.spec_attachable ~= nil then
                    addInputIndex(attachable.spec_attachable.inputAttacherJointDescIndex)
                end

                for _, inputIndex in ipairs(inputIndices) do
                    local okHoseList, hoseList = pcall(attachable.getConnectionHosesByInputAttacherJoint, attachable,
                        inputIndex)
                    if okHoseList and type(hoseList) == "table" then
                        local total = 0
                        local used = 0
                        for _, hose in ipairs(hoseList) do
                            if hose ~= nil then
                                total = total + 1
                                local okUsed, isUsed = pcall(attachable.getIsConnectionHoseUsed, attachable, hose)
                                if okUsed and isUsed then
                                    used = used + 1
                                end
                            end
                        end
                        states.__rawTotal = total
                        states.__rawUsed = used
                        if total > 0 then
                            states.__allRawAttached = used >= total
                            break
                        end
                    end
                end
            end

            return states
        end

        local function areAllRequiredHoseTypesAttached(states)
            if type(states) ~= "table" then
                return false
            end

            for _, hoseType in ipairs({ "hydraulic", "air", "electric", "isobus" }) do
                local entry = states[hoseType]
                if type(entry) == "table" and entry.required == true then
                    if entry.attached ~= true then
                        return false
                    end
                end
            end

            if states.__allRawAttached ~= nil and states.__allRawAttached ~= true then
                return false
            end

            return true
        end

        local function formatHoseTypeState(states)
            if type(states) ~= "table" then
                return "n/a"
            end

            local parts = {}
            for _, hoseType in ipairs({ "hydraulic", "air", "electric", "isobus" }) do
                local entry = states[hoseType] or {}
                table.insert(parts,
                    string.format("%s(req=%s,att=%s)", hoseType, tostring(entry.required), tostring(entry.attached)))
            end
            table.insert(parts,
                string.format("raw(total=%s,used=%s,all=%s)", tostring(states.__rawTotal), tostring(states.__rawUsed),
                    tostring(states.__allRawAttached)))
            return table.concat(parts, ";")
        end

        local manualStateBefore = getManualAttachStateSnapshot()
        local hasManualAttachHoseSpec = attachable.spec_manualAttachConnectionHoses ~= nil
            or (type(attachable.hasAttachedHoses) == "function" and type(attachable.connectHosesToAttacherVehicle) == "function")
        if hasManualAttachHoseSpec then
            local hasHosesAttachedState = false
            local hosesAlreadyAttached = false

            if type(ConnectionHosesExtension) == "table"
                and type(ConnectionHosesExtension.hasAttachedConnectionHoses) == "function" then
                local okAttachedAny, attachedAny = pcall(ConnectionHosesExtension.hasAttachedConnectionHoses, attachable)
                if okAttachedAny then
                    hasHosesAttachedState = true
                    hosesAlreadyAttached = attachedAny == true
                end
            end

            if not hasHosesAttachedState and type(attachable.hasAttachedHoses) == "function" then
                local okHasHoses, hasHoses = pcall(attachable.hasAttachedHoses, attachable)
                if okHasHoses then
                    hasHosesAttachedState = true
                    hosesAlreadyAttached = hasHoses == true
                end
            end

            local hasConnectableHoses = true
            if type(ConnectionHosesExtension) == "table" and type(ConnectionHosesExtension.hasConnectionHoses) == "function" then
                local okHasConnectable, hasConnectable = pcall(ConnectionHosesExtension.hasConnectionHoses, attachable,
                    attacherVehicle)
                if okHasConnectable then
                    hasConnectableHoses = hasConnectable == true
                end
            end

            if not hasConnectableHoses
                and type(attachable.getConnectionHosesByInputAttacherJoint) == "function" then
                local inputIndices = {}
                local inputIndexSet = {}

                local function addInputIndex(index)
                    if index ~= nil and inputIndexSet[index] ~= true then
                        table.insert(inputIndices, index)
                        inputIndexSet[index] = true
                    end
                end

                addInputIndex(resolvedInputJointDescIndex)
                if attachable.spec_attachable ~= nil then
                    addInputIndex(attachable.spec_attachable.inputAttacherJointDescIndex)
                end

                for _, inputIndex in ipairs(inputIndices) do
                    local okHoseList, hoseList = pcall(attachable.getConnectionHosesByInputAttacherJoint, attachable,
                        inputIndex)
                    if okHoseList and type(hoseList) == "table" and #hoseList > 0 then
                        hasConnectableHoses = true
                        break
                    end
                end
            end

            local hoseTypeStates = getManualAttachHoseTypeState()
            local fullTypeAttachOk = areAllRequiredHoseTypesAttached(hoseTypeStates)
            local shouldForceHoseReconnect = hasConnectableHoses
                and ((not hasHosesAttachedState or not hosesAlreadyAttached) or not fullTypeAttachOk)

            nfwLogAttachDebug(
                "[%s] ManualAttachCompat(manualAttach): hose-precheck mission=%s vehicle=%s attachable=%s anyAttached=%s fullTypes=%s states=%s",
                self.MOD_NAME,
                tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
                tostring(hosesAlreadyAttached),
                tostring(fullTypeAttachOk),
                formatHoseTypeState(hoseTypeStates)
            )

            if shouldForceHoseReconnect then
                local hosesConnected = false
                if type(g_manualAttach) == "table" and type(g_manualAttach.attachConnectionHoses) == "function" then
                    local okManualAttachHoses, manualAttachHoseError = pcall(
                        g_manualAttach.attachConnectionHoses,
                        g_manualAttach,
                        attacherVehicle,
                        attachable,
                        false
                    )
                    if okManualAttachHoses then
                        hosesConnected = true
                    else
                        nfwLogAttachDebug(
                            "[%s] ManualAttachCompat(manualAttach): attachConnectionHoses failed mission=%s vehicle=%s attachable=%s error=%s",
                            self.MOD_NAME,
                            tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                            tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                            tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
                            tostring(manualAttachHoseError)
                        )
                    end
                else
                    local directHoseOk = true
                    if type(attachable.connectHosesToAttacherVehicle) == "function" then
                        local okConnectHoses = pcall(
                            attachable.connectHosesToAttacherVehicle,
                            attachable,
                            attacherVehicle,
                            resolvedInputJointDescIndex,
                            resolvedJointDescIndex
                        )
                        directHoseOk = directHoseOk and okConnectHoses
                    end
                    if type(attachable.connectCustomHosesToAttacherVehicle) == "function" then
                        local okConnectCustom = pcall(
                            attachable.connectCustomHosesToAttacherVehicle,
                            attachable,
                            attacherVehicle,
                            resolvedInputJointDescIndex,
                            resolvedJointDescIndex
                        )
                        directHoseOk = directHoseOk and okConnectCustom
                    end
                    if type(attachable.updateAttachedConnectionHoses) == "function" then
                        pcall(attachable.updateAttachedConnectionHoses, attachable, attacherVehicle)
                    end
                    hosesConnected = directHoseOk
                end

                hoseTypeStates = getManualAttachHoseTypeState()
                fullTypeAttachOk = areAllRequiredHoseTypesAttached(hoseTypeStates)

                if not fullTypeAttachOk
                    and type(attachable.connectHosesToAttacherVehicle) == "function" then
                    pcall(
                        attachable.connectHosesToAttacherVehicle,
                        attachable,
                        attacherVehicle,
                        resolvedInputJointDescIndex,
                        resolvedJointDescIndex
                    )
                    if type(attachable.connectCustomHosesToAttacherVehicle) == "function" then
                        pcall(
                            attachable.connectCustomHosesToAttacherVehicle,
                            attachable,
                            attacherVehicle,
                            resolvedInputJointDescIndex,
                            resolvedJointDescIndex
                        )
                    end
                    if type(attachable.updateAttachedConnectionHoses) == "function" then
                        pcall(attachable.updateAttachedConnectionHoses, attachable, attacherVehicle)
                    end
                    hoseTypeStates = getManualAttachHoseTypeState()
                    fullTypeAttachOk = areAllRequiredHoseTypesAttached(hoseTypeStates)
                end

                if not hosesConnected and fullTypeAttachOk then
                    hosesConnected = true
                end

                if hosesConnected and fullTypeAttachOk then
                    table.insert(forcedParts, "manual_hoses_full")
                elseif hosesConnected then
                    table.insert(forcedParts, "manual_hoses_partial")
                    nfwLogAttachDebug(
                        "[%s] ManualAttachCompat(manualAttach): incomplete hose types mission=%s vehicle=%s attachable=%s states=%s",
                        self.MOD_NAME,
                        tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                        tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                        tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
                        formatHoseTypeState(hoseTypeStates)
                    )
                end
            end
        end

        local hasManualAttachPtoSpec = attachable.spec_manualAttachPowerTakeOff ~= nil
            or (type(attachable.isPtoAttached) == "function" and type(attacherVehicle.attachPowerTakeOff) == "function")
        if hasManualAttachPtoSpec then
            local ptoRequired = true
            if type(PowerTakeOffExtension) == "table" and type(PowerTakeOffExtension.hasPowerTakeOffs) == "function" then
                local okPtoRequired, hasPto = pcall(PowerTakeOffExtension.hasPowerTakeOffs, attachable, attacherVehicle)
                if okPtoRequired then
                    ptoRequired = hasPto == true
                end
            end

            local hasPtoAttachedState = false
            local ptoAlreadyAttached = false
            if type(attachable.isPtoAttached) == "function" then
                local okPtoAttached, isAttached = pcall(attachable.isPtoAttached, attachable)
                if okPtoAttached then
                    hasPtoAttachedState = true
                    ptoAlreadyAttached = isAttached == true
                end
            elseif type(PowerTakeOffExtension) == "table"
                and type(PowerTakeOffExtension.hasAttachedPowerTakeOffs) == "function" then
                local okPtoAttached, isAttached = pcall(PowerTakeOffExtension.hasAttachedPowerTakeOffs, attachable,
                    attacherVehicle)
                if okPtoAttached then
                    hasPtoAttachedState = true
                    ptoAlreadyAttached = isAttached == true
                end
            end

            if ptoRequired and (not hasPtoAttachedState or not ptoAlreadyAttached) then
                local ptoConnected = false
                if type(g_manualAttach) == "table" and type(g_manualAttach.attachPowerTakeOff) == "function" then
                    local okManualAttachPto, manualAttachPtoError = pcall(
                        g_manualAttach.attachPowerTakeOff,
                        g_manualAttach,
                        attacherVehicle,
                        attachable,
                        false
                    )
                    if okManualAttachPto then
                        ptoConnected = true
                    else
                        nfwLogAttachDebug(
                            "[%s] ManualAttachCompat(manualAttach): attachPowerTakeOff failed mission=%s vehicle=%s attachable=%s error=%s",
                            self.MOD_NAME,
                            tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                            tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                            tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
                            tostring(manualAttachPtoError)
                        )
                    end
                else
                    local okAttachPto = true
                    if type(attacherVehicle.attachPowerTakeOff) == "function" then
                        local okPtoAttach = pcall(
                            attacherVehicle.attachPowerTakeOff,
                            attacherVehicle,
                            attachable,
                            resolvedInputJointDescIndex,
                            resolvedJointDescIndex
                        )
                        okAttachPto = okAttachPto and okPtoAttach
                    end
                    if type(attacherVehicle.handlePowerTakeOffPostAttach) == "function" and resolvedJointDescIndex ~= nil then
                        local okPostAttach = pcall(attacherVehicle.handlePowerTakeOffPostAttach, attacherVehicle,
                            resolvedJointDescIndex)
                        okAttachPto = okAttachPto and okPostAttach
                    end
                    ptoConnected = okAttachPto
                end

                local ptoNowAttached = false
                if type(attachable.isPtoAttached) == "function" then
                    local okPtoNow, isPtoNow = pcall(attachable.isPtoAttached, attachable)
                    if okPtoNow then
                        ptoNowAttached = isPtoNow == true
                    end
                end

                if not ptoNowAttached and type(attacherVehicle.attachPowerTakeOff) == "function" then
                    pcall(
                        attacherVehicle.attachPowerTakeOff,
                        attacherVehicle,
                        attachable,
                        resolvedInputJointDescIndex,
                        resolvedJointDescIndex
                    )
                    if type(attacherVehicle.handlePowerTakeOffPostAttach) == "function" and resolvedJointDescIndex ~= nil then
                        pcall(attacherVehicle.handlePowerTakeOffPostAttach, attacherVehicle, resolvedJointDescIndex)
                    end
                    if type(attachable.isPtoAttached) == "function" then
                        local okPtoNow, isPtoNow = pcall(attachable.isPtoAttached, attachable)
                        if okPtoNow then
                            ptoNowAttached = isPtoNow == true
                        end
                    end
                end

                if ptoConnected and ptoNowAttached then
                    table.insert(forcedParts, "manual_pto_ok")
                elseif ptoConnected then
                    table.insert(forcedParts, "manual_pto_partial")
                    nfwLogAttachDebug(
                        "[%s] ManualAttachCompat(manualAttach): pto still not attached mission=%s vehicle=%s attachable=%s",
                        self.MOD_NAME,
                        tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
                        tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
                        tostring(attachable.getName ~= nil and attachable:getName() or "unknown")
                    )
                end
            end
        end

        local manualStateAfter = getManualAttachStateSnapshot()
        nfwLogAttachDebug(
            "[%s] ManualAttachCompat(manualAttach): mission=%s vehicle=%s attachable=%s stateBefore{hoses=%s,pto=%s} stateAfter{hoses=%s,pto=%s}",
            self.MOD_NAME,
            tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
            tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
            tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
            tostring(manualStateBefore.hoses),
            tostring(manualStateBefore.pto),
            tostring(manualStateAfter.hoses),
            tostring(manualStateAfter.pto)
        )
    end

    if #forcedParts > 0 then
        nfwLogInfo(
            "[%s] ManualAttachCompat: forced AI connections mission=%s vehicle=%s attachable=%s parts=%s",
            self.MOD_NAME,
            tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission)),
            tostring(attacherVehicle.getName ~= nil and attacherVehicle:getName() or "unknown"),
            tostring(attachable.getName ~= nil and attachable:getName() or "unknown"),
            table.concat(forcedParts, ",")
        )
    end
end

function NeighborFieldWorkers:ensureManualAttachConnectionsForAssignment(assignment, rootVehicle)
    if assignment == nil then
        return 0
    end

    local mission = assignment.mission
    local startVehicle = rootVehicle
    if startVehicle == nil or startVehicle.isDeleted then
        startVehicle = self:findMissionWorkVehicle(assignment)
    end
    if startVehicle == nil or startVehicle.isDeleted then
        return 0
    end

    local processed = 0
    local visited = {}

    local function processAttacherTree(attacherVehicle)
        if attacherVehicle == nil or attacherVehicle.isDeleted or visited[attacherVehicle] then
            return
        end
        visited[attacherVehicle] = true

        if attacherVehicle.getAttachedImplements == nil then
            return
        end

        local implements = attacherVehicle:getAttachedImplements()
        if type(implements) ~= "table" then
            return
        end

        for _, implement in pairs(implements) do
            if implement ~= nil and implement.object ~= nil and not implement.object.isDeleted then
                self:ensureManualAttachConnectionsForNeighbor(
                    attacherVehicle,
                    implement.object,
                    implement.jointDescIndex,
                    implement.inputJointDescIndex,
                    assignment,
                    mission
                )
                processed = processed + 1
                processAttacherTree(implement.object)
            end
        end
    end

    processAttacherTree(startVehicle)
    return processed
end

function NeighborFieldWorkers:tryAttachMissionImplementsForSide(assignment, mission, side)
    local attachedCount = 0
    local attachWarnings = {}
    if mission == nil or mission.vehicles == nil then
        return attachedCount, attachWarnings
    end

    local seenWarnings = {}
    local missionVehicleSet = {}
    local crossSideAttachCount = 0
    for _, missionVehicle in ipairs(mission.vehicles) do
        if missionVehicle ~= nil and not missionVehicle.isDeleted then
            missionVehicleSet[missionVehicle] = true
        end
    end

    local function addAttachWarning(value)
        if value == nil then
            return
        end

        local text = tostring(value)
        if text == "" or seenWarnings[text] then
            return
        end

        seenWarnings[text] = true
        table.insert(attachWarnings, text)
    end

    local function getObjectNameSafe(object)
        if object == nil then
            return "n/a"
        end
        if object.getName ~= nil then
            local okName, name = pcall(object.getName, object)
            if okName and name ~= nil and tostring(name) ~= "" then
                return tostring(name)
            end
        end
        return tostring(object)
    end

    local function tryAttachCandidate(attacherVehicle, attacherJointIndex, attachable, attachableJointIndex)
        local effectiveAttacher = attacherVehicle
        if effectiveAttacher == nil or effectiveAttacher.attachImplementFromInfo == nil then
            addAttachWarning("INVALID_ATTACHER")
            return false, "INVALID_ATTACHER"
        end

        local info = {
            attacherVehicle = effectiveAttacher,
            attacherVehicleJointDescIndex = attacherJointIndex,
            attachable = attachable,
            attachableJointDescIndex = attachableJointIndex
        }

        local canAttach = true
        if attachable.isAttachAllowed ~= nil and effectiveAttacher.getActiveFarm ~= nil then
            local okAllowed, allowed = pcall(attachable.isAttachAllowed, attachable,
                effectiveAttacher:getActiveFarm(), effectiveAttacher)
            if not okAllowed then
                addAttachWarning("ATTACH_ALLOWED_CHECK_ERROR")
            end
            canAttach = okAllowed and allowed == true
        end

        if not canAttach then
            addAttachWarning("ATTACH_NOT_ALLOWED")
            return false, "ATTACH_NOT_ALLOWED"
        end

        local okAttach, attachedOrError = pcall(effectiveAttacher.attachImplementFromInfo, effectiveAttacher, info)
        if okAttach and attachedOrError then
            self:ensureManualAttachConnectionsForNeighbor(
                effectiveAttacher,
                attachable,
                attacherJointIndex,
                attachableJointIndex,
                assignment,
                mission
            )
            return true, "ATTACHED"
        end

        if okAttach then
            addAttachWarning("ATTACH_RETURN_FALSE")
            return false, "ATTACH_RETURN_FALSE"
        else
            local errorText = string.format("ATTACH_ERROR(%s)", tostring(attachedOrError))
            addAttachWarning(errorText)
            return false, errorText
        end
    end

    local sideFilter = side or "any"
    local scanDistance = sideFilter == "any" and 100 or NFW_ATTACH_SIDE_SCAN_DISTANCE
    local missionKey = tostring(assignment ~= nil and assignment.key or self:getMissionKey(mission))
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle.spec_attacherJoints ~= nil
            and vehicle.attachImplementFromInfo ~= nil
            and type(AttacherJoints) == "table"
            and AttacherJoints.updateVehiclesInAttachRange ~= nil then
            local passVehicleName = getObjectNameSafe(vehicle)
            for attemptIndex = 1, NFW_ATTACH_ATTEMPTS_PER_PASS do
                local attacherVehicle, attacherVehicleJointDescIndex, attachable, attachableJointDescIndex, warning =
                    AttacherJoints.updateVehiclesInAttachRange(vehicle, scanDistance, 0.5, true)

                if attacherVehicle == nil or attachable == nil then
                    if warning ~= nil then
                        addAttachWarning(warning)
                    end
                    nfwLogAttachDebug(
                        "[%s] AttachScan: mission=%s passVehicle=%s sideReq=%s try=%d/%d scanDistSq=%.1f result=NO_CANDIDATE warning=%s",
                        self.MOD_NAME,
                        missionKey,
                        passVehicleName,
                        tostring(sideFilter),
                        attemptIndex,
                        NFW_ATTACH_ATTEMPTS_PER_PASS,
                        scanDistance,
                        tostring(warning)
                    )
                    break
                end

                local attacherName = getObjectNameSafe(attacherVehicle)
                local attachableName = getObjectNameSafe(attachable)
                if missionVehicleSet[attachable] ~= true then
                    addAttachWarning(string.format(
                        "NON_MISSION_CANDIDATE(side=%s,attachable=%s)",
                        tostring(sideFilter),
                        attachableName
                    ))
                    if warning ~= nil then
                        addAttachWarning(warning)
                    end
                    nfwLogAttachDebug(
                        "[%s] AttachScan: mission=%s passVehicle=%s sideReq=%s try=%d/%d scanDistSq=%.1f attacher=%s attachable=%s result=NON_MISSION_CANDIDATE warning=%s",
                        self.MOD_NAME,
                        missionKey,
                        passVehicleName,
                        tostring(sideFilter),
                        attemptIndex,
                        NFW_ATTACH_ATTEMPTS_PER_PASS,
                        scanDistance,
                        attacherName,
                        attachableName,
                        tostring(warning)
                    )
                else
                    local candidateSide = self:isLikelyFrontSupportImplement(attachable, mission) and "front" or "rear"
                    local sideMismatch = sideFilter ~= "any" and candidateSide ~= sideFilter
                    if sideMismatch then
                        addAttachWarning(string.format(
                            "SIDE_MISMATCH(side=%s,actual=%s,attachable=%s)",
                            tostring(sideFilter),
                            tostring(candidateSide),
                            attachableName
                        ))
                    end

                    local attached, attachResult = tryAttachCandidate(
                        attacherVehicle,
                        attacherVehicleJointDescIndex,
                        attachable,
                        attachableJointDescIndex
                    )
                    nfwLogAttachDebug(
                        "[%s] AttachScan: mission=%s passVehicle=%s sideReq=%s try=%d/%d scanDistSq=%.1f attacher=%s attachable=%s candidateSide=%s sideMismatch=%s result=%s warning=%s",
                        self.MOD_NAME,
                        missionKey,
                        passVehicleName,
                        tostring(sideFilter),
                        attemptIndex,
                        NFW_ATTACH_ATTEMPTS_PER_PASS,
                        scanDistance,
                        attacherName,
                        attachableName,
                        tostring(candidateSide),
                        tostring(sideMismatch),
                        tostring(attachResult),
                        tostring(warning)
                    )
                    if attached then
                        attachedCount = attachedCount + 1
                        if sideMismatch then
                            crossSideAttachCount = crossSideAttachCount + 1
                            if assignment ~= nil then
                                assignment.attachObservedSides = assignment.attachObservedSides or {}
                                    assignment.attachObservedSides[candidateSide] = true
                            end
                            nfwLogAttachDebug(
                                "[%s] AttachPhase cross-side-attach: mission=%s requested=%s actual=%s attachable=%s",
                                self.MOD_NAME,
                                missionKey,
                                tostring(sideFilter),
                                tostring(candidateSide),
                                attachableName
                            )
                        end
                    elseif warning ~= nil then
                        addAttachWarning(warning)
                    end
                end
            end
        end
    end

    if crossSideAttachCount > 0 and assignment ~= nil then
        assignment.attachObservedSides = assignment.attachObservedSides or {}
        assignment.attachObservedSides.front = assignment.attachObservedSides.front or false
        assignment.attachObservedSides.rear = assignment.attachObservedSides.rear or false
    end

    return attachedCount, attachWarnings
end

function NeighborFieldWorkers:alignMissionVehiclesForAttachment(assignment, side)
    local mission = assignment.mission
    if mission == nil or mission.vehicles == nil or #mission.vehicles < 2 then
        return
    end

    local leadVehicle = self:findPrimaryMissionVehicle(mission)
    if leadVehicle == nil or leadVehicle.rootNode == nil then
        return
    end

    if g_currentMission == nil or g_currentMission.terrainRootNode == nil then
        return
    end

    local leadX, _, leadZ = getWorldTranslation(leadVehicle.rootNode)
    local originalLeadX = leadX
    local originalLeadZ = leadZ
    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    local leadOnMissionField = self:isPositionWithinMissionField(mission, leadX, leadZ)
    local useFieldAnchor = false

    if not leadOnMissionField and fieldX ~= nil and fieldZ ~= nil then
        local distToFieldSq = MathUtil.vector2LengthSq(leadX - fieldX, leadZ - fieldZ)
        if distToFieldSq > (120 * 120) then
            useFieldAnchor = true
        end
    end

    local dirX, dirZ
    if useFieldAnchor then
        dirX, dirZ = self:getMissionSpawnDirection(mission)
        leadX = fieldX
        leadZ = fieldZ
    else
        local localDirX, _, localDirZ = localDirectionToWorld(leadVehicle.rootNode, 0, 0, 1)
        local dirLen = MathUtil.vector2Length(localDirX, localDirZ)
        if dirLen < 0.001 and fieldX ~= nil and fieldZ ~= nil then
            dirX, dirZ = self:getMissionSpawnDirection(mission)
        else
            dirLen = math.max(0.001, dirLen)
            dirX = localDirX / dirLen
            dirZ = localDirZ / dirLen
        end
    end
    local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
    if useFieldAnchor and leadVehicle.setAbsolutePosition ~= nil then
        local leadY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, leadX, 0, leadZ)
        leadVehicle:setAbsolutePosition(leadX, leadY + 0.5, leadZ, 0, yRot, 0)
        nfwLogHelperDiag(
            "[%s] HelperDiag ATTACH_ALIGN_FIELD_ANCHOR: mission=%s vehicle=%s old=(%.2f/%.2f) new=(%.2f/%.2f)",
            self.MOD_NAME,
            tostring(assignment ~= nil and assignment.key or "n/a"),
            tostring(leadVehicle.getName ~= nil and leadVehicle:getName() or "unknown"),
            originalLeadX,
            originalLeadZ,
            leadX,
            leadZ
        )
    end
    local phaseSide = side or "all"
    local perpX = -dirZ
    local perpZ = dirX
    local rearIndex = 0
    local frontIndex = 0
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and vehicle ~= leadVehicle
            and vehicle.rootNode ~= nil
            and not vehicle.isDeleted
            and (vehicle.getAttacherVehicle == nil or vehicle:getAttacherVehicle() == nil)
            and vehicle.setAbsolutePosition ~= nil then
            local isFront = self:isLikelyFrontSupportImplement(vehicle, mission)
            local shouldAlign = true
            if phaseSide == "rear" and isFront then
                shouldAlign = false
            elseif phaseSide == "front" and not isFront then
                shouldAlign = false
            end

            if shouldAlign then
                local sideIndex = 1
                if isFront then
                    frontIndex = frontIndex + 1
                    sideIndex = frontIndex
                else
                    rearIndex = rearIndex + 1
                    sideIndex = rearIndex
                end

                local desiredDist = self:getImplementPlacementDistanceForVehicle(leadVehicle, vehicle, isFront)
                local isSowRearChain = self:isSowMission(mission) and not isFront
                if isSowRearChain and sideIndex > 1 then
                    -- For chained sowing tools we avoid side offsets and keep strict rear ordering.
                    desiredDist = desiredDist + (sideIndex - 1) * 2.0
                end
                local lateral = 0
                if sideIndex > 1 and not isSowRearChain then
                    local lateralIdx = sideIndex - 2
                    local lateralMag = 1.2 + math.floor(lateralIdx / 2) * 0.6
                    local lateralSign = (lateralIdx % 2 == 0) and -1 or 1
                    lateral = lateralSign * lateralMag
                end

                local directionSign = isFront and 1 or -1
                local px = leadX + dirX * desiredDist * directionSign + perpX * lateral
                local pz = leadZ + dirZ * desiredDist * directionSign + perpZ * lateral
                local oldX, _, oldZ = getWorldTranslation(vehicle.rootNode)
                local py = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 0, pz)
                vehicle:setAbsolutePosition(px, py + 0.3, pz, 0, yRot, 0)
                nfwLogAttachDebug(
                    "[%s] AttachAlign side=%s mission=%s vehicle=%s front=%s old=(%.2f/%.2f) new=(%.2f/%.2f) dist=%.1f",
                    self.MOD_NAME,
                    tostring(phaseSide),
                    tostring(assignment ~= nil and assignment.key or "n/a"),
                    tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
                    tostring(isFront),
                    oldX,
                    oldZ,
                    px,
                    pz,
                    desiredDist
                )
            end
        end
    end
end

function NeighborFieldWorkers:isTowBehindSprayerImplement(vehicle)
    if vehicle == nil or vehicle.isDeleted or vehicle.spec_motorized ~= nil then
        return false
    end

    if vehicle.spec_sprayer ~= nil and vehicle.spec_trailer ~= nil then
        return true
    end

    local configLower = string.lower(tostring(vehicle.configFileName or ""))
    if string.find(configLower, "fronttank", 1, true) ~= nil then
        return false
    end
    if string.find(configLower, "sprayer", 1, true) ~= nil
        or string.find(configLower, "spray", 1, true) ~= nil
        or string.find(configLower, "herbicide", 1, true) ~= nil then
        return true
    end

    if vehicle.getName ~= nil then
        local okName, displayName = pcall(vehicle.getName, vehicle)
        if okName and displayName ~= nil then
            local nameLower = string.lower(tostring(displayName))
            if string.find(nameLower, "front tank", 1, true) ~= nil
                or string.find(nameLower, "fronttank", 1, true) ~= nil then
                return false
            end
            if string.find(nameLower, "sprayer", 1, true) ~= nil
                or string.find(nameLower, "spritz", 1, true) ~= nil
                or string.find(nameLower, "ux ", 1, true) ~= nil
                or string.find(nameLower, "herb", 1, true) ~= nil then
                return true
            end
        end
    end

    return false
end

function NeighborFieldWorkers:isAmazoneUx5201SuperSprayer(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return false
    end

    local configLower = string.lower(tostring(vehicle.configFileName or ""))
    if string.find(configLower, "ux5201", 1, true) ~= nil
        or string.find(configLower, "ux_5201", 1, true) ~= nil
        or string.find(configLower, "ux-5201", 1, true) ~= nil then
        return true
    end
    if string.find(configLower, "amazone", 1, true) ~= nil
        and string.find(configLower, "ux", 1, true) ~= nil
        and string.find(configLower, "5201", 1, true) ~= nil then
        return true
    end

    if vehicle.getName ~= nil then
        local okName, displayName = pcall(vehicle.getName, vehicle)
        if okName and displayName ~= nil then
            local nameLower = string.lower(tostring(displayName))
            if string.find(nameLower, "ux 5201", 1, true) ~= nil
                or string.find(nameLower, "ux5201", 1, true) ~= nil
                or (string.find(nameLower, "amazone", 1, true) ~= nil
                    and string.find(nameLower, "ux", 1, true) ~= nil
                    and string.find(nameLower, "5201", 1, true) ~= nil)
                or (vehicle.spec_sprayer ~= nil
                    and vehicle.spec_trailer ~= nil
                    and string.find(nameLower, "5201", 1, true) ~= nil) then
                return true
            end
        end
    end

    return false
end

function NeighborFieldWorkers:logMissionVehicleStates(assignment)
    local mission = assignment.mission
    if mission == nil or mission.vehicles == nil then
        return
    end

    local now = g_time or 0
    if now < assignment.nextVehicleStateLogAtMs then
        return
    end
    assignment.nextVehicleStateLogAtMs = now + 15000

    local parts = {}
    for i, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and vehicle.rootNode ~= nil and not vehicle.isDeleted then
            local x, _, z = getWorldTranslation(vehicle.rootNode)
            local name = vehicle.getName ~= nil and vehicle:getName() or ("vehicle" .. tostring(i))
            local isAttached = vehicle.getAttacherVehicle ~= nil and vehicle:getAttacherVehicle() ~= nil
            local canFieldWork = vehicle.getCanStartFieldWork ~= nil and vehicle:getCanStartFieldWork() or false

            table.insert(
                parts,
                string.format(
                    "%d:%s pos=(%.1f/%.1f) attached=%s fw=%s",
                    i,
                    tostring(name),
                    x,
                    z,
                    tostring(isAttached),
                    tostring(canFieldWork)
                )
            )
        end
    end

    if #parts > 0 then
        nfwLogInfo("[%s] Mission Fahrzeugstatus: mission=%s %s", self.MOD_NAME, tostring(assignment.key),
            table.concat(parts, " | "))
    end
end

function NeighborFieldWorkers:getMissionVehicleLoadStats(mission)
    local vehicleCount = (mission ~= nil and mission.vehicles ~= nil) and #mission.vehicles or 0
    local expectedCount = (mission ~= nil and mission.vehiclesToLoad ~= nil) and #mission.vehiclesToLoad or vehicleCount
    if mission ~= nil and self:isHarvestMission(mission) then
        if type(mission.nfwHarvestExpectedVehicleCount) == "number" and mission.nfwHarvestExpectedVehicleCount > 0 then
            expectedCount = mission.nfwHarvestExpectedVehicleCount
        elseif mission.nfwHarvestRoleFallbackUsed ~= true and mission.vehiclesToLoad ~= nil then
            local harvestExpected = 0
            local combineCount = 0
            local cutterCount = 0
            local tractorCount = 0
            local combineNeedsTractor = false
            for _, info in ipairs(mission.vehiclesToLoad) do
                local role = self:getHarvestVehicleRoleByInfo(info)
                if role == "combine" and combineCount < 1 then
                    harvestExpected = harvestExpected + 1
                    combineCount = combineCount + 1
                    local meta = self:getVehicleInfoMetaByInfo(info)
                    combineNeedsTractor = not meta.isMotorized
                elseif role == "cutter" and cutterCount < 1 then
                    harvestExpected = harvestExpected + 1
                    cutterCount = cutterCount + 1
                elseif combineNeedsTractor and tractorCount < 1 then
                    local meta = self:getVehicleInfoMetaByInfo(info)
                    if meta.isTractor then
                        harvestExpected = harvestExpected + 1
                        tractorCount = tractorCount + 1
                    end
                end
            end
            if harvestExpected > 0 then
                expectedCount = harvestExpected
            end
        end
    end

    if mission ~= nil and self:isStoneMission(mission) then
        if type(mission.nfwStoneExpectedVehicleCount) == "number" and mission.nfwStoneExpectedVehicleCount > 0 then
            expectedCount = mission.nfwStoneExpectedVehicleCount
        elseif mission.nfwStoneRoleFallbackUsed ~= true and mission.vehiclesToLoad ~= nil then
            local stoneExpected = 0
            local tractorCount = 0
            local pickerCount = 0
            for _, info in ipairs(mission.vehiclesToLoad) do
                local role = self:getStoneVehicleRoleByInfo(info)
                if role == "tractor" and tractorCount < 1 then
                    stoneExpected = stoneExpected + 1
                    tractorCount = tractorCount + 1
                elseif role == "stonePicker" and pickerCount < 1 then
                    stoneExpected = stoneExpected + 1
                    pickerCount = pickerCount + 1
                end
            end
            if stoneExpected > 0 then
                expectedCount = stoneExpected
            end
        end
    end

    if mission ~= nil and self:isCultivateMission(mission) then
        if type(mission.nfwCultivateExpectedVehicleCount) == "number" and mission.nfwCultivateExpectedVehicleCount > 0 then
            expectedCount = mission.nfwCultivateExpectedVehicleCount
        elseif mission.nfwCultivateMetaFallbackUsed ~= true and mission.vehiclesToLoad ~= nil then
            local cultivateExpected = 0
            local tractorCount = 0
            local toolCount = 0
            for _, info in ipairs(mission.vehiclesToLoad) do
                local meta = self:getVehicleInfoMetaByInfo(info)
                if meta.isTractor and tractorCount < 1 then
                    cultivateExpected = cultivateExpected + 1
                    tractorCount = tractorCount + 1
                elseif not meta.isMotorized and not meta.isTrailer and not meta.isWeight and toolCount < 1 then
                    cultivateExpected = cultivateExpected + 1
                    toolCount = toolCount + 1
                end
            end
            if cultivateExpected > 0 then
                expectedCount = cultivateExpected
            end
        end
    end

    if mission ~= nil and self:isPlowMission(mission) then
        if type(mission.nfwPlowExpectedVehicleCount) == "number" and mission.nfwPlowExpectedVehicleCount > 0 then
            expectedCount = mission.nfwPlowExpectedVehicleCount
        elseif mission.nfwPlowMetaFallbackUsed ~= true and mission.vehiclesToLoad ~= nil then
            local plowExpected = 0
            local tractorCount = 0
            local weightCount = 0
            local plowCount = 0
            for _, info in ipairs(mission.vehiclesToLoad) do
                local meta = self:getVehicleInfoMetaByInfo(info)
                if meta.isTractor and tractorCount < 1 then
                    plowExpected = plowExpected + 1
                    tractorCount = tractorCount + 1
                elseif meta.isWeight and not meta.isMotorized and not meta.isTrailer and weightCount < 1 then
                    plowExpected = plowExpected + 1
                    weightCount = weightCount + 1
                elseif not meta.isMotorized and not meta.isTrailer and not meta.isWeight and meta.isPlowTool and plowCount < 1 then
                    plowExpected = plowExpected + 1
                    plowCount = plowCount + 1
                end
            end
            if plowExpected > 0 then
                expectedCount = plowExpected
            end
        end
    end

    if mission ~= nil and self:isSowMission(mission) then
        if type(mission.nfwSowExpectedVehicleCount) == "number" and mission.nfwSowExpectedVehicleCount > 0 then
            expectedCount = mission.nfwSowExpectedVehicleCount
        elseif mission.nfwSowMetaFallbackUsed ~= true and mission.vehiclesToLoad ~= nil then
            local sowExpected = 0
            local tractorCount = 0
            local weightCount = 0
            local toolCount = 0
            for _, info in ipairs(mission.vehiclesToLoad) do
                local meta = self:getVehicleInfoMetaByInfo(info)
                if meta.isTractor and tractorCount < 1 then
                    sowExpected = sowExpected + 1
                    tractorCount = tractorCount + 1
                elseif meta.isWeight and not meta.isMotorized and not meta.isTrailer and weightCount < 1 then
                    sowExpected = sowExpected + 1
                    weightCount = weightCount + 1
                elseif self:isSimpleToolInfo(meta) and meta.isSowingTool and toolCount < 1 then
                    sowExpected = sowExpected + 1
                    toolCount = toolCount + 1
                end
            end
            if sowExpected > 0 then
                expectedCount = sowExpected
            end
        end
    end

    local pendingLoads = (mission ~= nil and mission.pendingVehicleLoadingData ~= nil) and
        #mission.pendingVehicleLoadingData or 0
    local spawnedVehicles = mission ~= nil and mission.spawnedVehicles == true
    local failedLoad = mission ~= nil and mission.failedToLoadVehicles == true

    local loadingComplete = true
    if spawnedVehicles then
        loadingComplete = pendingLoads == 0 and (expectedCount <= 0 or vehicleCount >= expectedCount)
    end

    return spawnedVehicles, vehicleCount, expectedCount, pendingLoads, failedLoad, loadingComplete
end

function NeighborFieldWorkers:getUnattachedMissionImplements(mission)
    local missingNames = {}
    if mission == nil or mission.vehicles == nil then
        return missingNames
    end

    for i, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.spec_motorized == nil
            and vehicle.getAttacherVehicle ~= nil then
            local attacherVehicle = vehicle:getAttacherVehicle()
            if attacherVehicle == nil then
                local name = vehicle.getName ~= nil and vehicle:getName() or ("implement" .. tostring(i))
                table.insert(missingNames, tostring(name))
            end
        end
    end

    return missingNames
end

function NeighborFieldWorkers:pruneHarvestMissionSupportVehicles(assignment)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or not self:isHarvestMission(mission) then
        return
    end

    local bestCombine = nil
    local bestCombineScore = -math.huge
    local bestCombineMotorized = false
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_combine ~= nil then
            local isMotorized = vehicle.spec_motorized ~= nil
            local score = self:getVehiclePowerScore(vehicle)
            if isMotorized then
                score = score + 1000000
            end
            if bestCombine == nil or score > bestCombineScore then
                bestCombine = vehicle
                bestCombineScore = score
                bestCombineMotorized = isMotorized
            end
        end
    end

    local bestCutter = nil
    for _, vehicle in ipairs(mission.vehicles) do
        local isHeaderLikeNonMotorizedCombine = vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.spec_combine ~= nil
            and vehicle.spec_motorized == nil
            and not self:isLikelyTowBehindHarvestCombineVehicle(vehicle)
        if vehicle ~= nil
            and not vehicle.isDeleted
            and ((vehicle.spec_cutter ~= nil and vehicle.spec_cutterTrailer == nil)
                or isHeaderLikeNonMotorizedCombine) then
            if bestCutter == nil then
                bestCutter = vehicle
            elseif bestCombine ~= nil and self:isImplementAttachedToVehicle(vehicle, bestCombine) then
                bestCutter = vehicle
                break
            end
        end
    end

    if bestCombine == nil then
        -- Safety: avoid deleting mission vehicles if we cannot reliably identify a working harvester.
        return
    end

    local combineNeedsTractor = (bestCombine ~= nil and not bestCombineMotorized)
    local bestTractor = nil
    local bestTractorScore = -math.huge
    if combineNeedsTractor then
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil
                and not vehicle.isDeleted
                and vehicle.spec_motorized ~= nil
                and vehicle.spec_combine == nil
                and vehicle.spec_cutter == nil
                and vehicle.spec_trailer == nil then
                local score = self:getVehiclePowerScore(vehicle)
                if bestTractor == nil or score > bestTractorScore then
                    bestTractor = vehicle
                    bestTractorScore = score
                end
            end
        end
    end

    local removedNames = {}
    for i = #mission.vehicles, 1, -1 do
        local vehicle = mission.vehicles[i]
        if vehicle ~= nil and not vehicle.isDeleted then
            local keepVehicle = vehicle == bestCombine
                or vehicle == bestCutter
                or (combineNeedsTractor and vehicle == bestTractor)

            if not keepVehicle then
                if vehicle.getIsAIActive ~= nil and vehicle.stopCurrentAIJob ~= nil then
                    local okActive, isActive = pcall(vehicle.getIsAIActive, vehicle)
                    if okActive and isActive then
                        local stopMessage = nil
                        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
                            stopMessage = AIMessageSuccessStoppedByUser.new()
                        end
                        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
                    end
                end

                local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                table.insert(removedNames, tostring(vehicleName))
                if vehicle.delete ~= nil then
                    pcall(vehicle.delete, vehicle)
                end
                table.remove(mission.vehicles, i)
            end
        end
    end

    local keptHarvestCount = 0
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            keptHarvestCount = keptHarvestCount + 1
        end
    end
    mission.nfwHarvestRoleFallbackUsed = nil
    mission.nfwHarvestExpectedVehicleCount = keptHarvestCount > 0 and keptHarvestCount or nil

    if #removedNames > 0 then
        nfwLogInfo(
            "[%s] Ernte-Mission reduziert: mission=%s kept=%d removed=%d needsTractor=%s vehicles=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            keptHarvestCount,
            #removedNames,
            tostring(combineNeedsTractor),
            table.concat(removedNames, ", ")
        )
    end
end

function NeighborFieldWorkers:pruneStoneMissionSupportVehicles(assignment)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or not self:isStoneMission(mission) then
        return
    end

    local removedNames = {}
    local keptTractorCount = 0
    local keptPickerCount = 0
    for i = #mission.vehicles, 1, -1 do
        local vehicle = mission.vehicles[i]
        if vehicle ~= nil and not vehicle.isDeleted then
            local isPicker = vehicle.spec_stonePicker ~= nil
            local isTrailer = vehicle.spec_trailer ~= nil or vehicle.spec_cutterTrailer ~= nil
            local isMotorized = vehicle.spec_motorized ~= nil

            local keepVehicle = false
            if isPicker and keptPickerCount < 1 then
                keepVehicle = true
                keptPickerCount = keptPickerCount + 1
            elseif isMotorized and not isTrailer and not isPicker and keptTractorCount < 1 then
                keepVehicle = true
                keptTractorCount = keptTractorCount + 1
            end

            if not keepVehicle then
                if vehicle.getIsAIActive ~= nil and vehicle.stopCurrentAIJob ~= nil then
                    local okActive, isActive = pcall(vehicle.getIsAIActive, vehicle)
                    if okActive and isActive then
                        local stopMessage = nil
                        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
                            stopMessage = AIMessageSuccessStoppedByUser.new()
                        end
                        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
                    end
                end

                local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                table.insert(removedNames, tostring(vehicleName))
                if vehicle.delete ~= nil then
                    pcall(vehicle.delete, vehicle)
                end
                table.remove(mission.vehicles, i)
            end
        end
    end

    local keptStoneCount = 0
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            local isPicker = vehicle.spec_stonePicker ~= nil
            local isTrailer = vehicle.spec_trailer ~= nil or vehicle.spec_cutterTrailer ~= nil
            local isMotorized = vehicle.spec_motorized ~= nil
            if isPicker or (isMotorized and not isTrailer and not isPicker) then
                keptStoneCount = keptStoneCount + 1
            end
        end
    end
    mission.nfwStoneRoleFallbackUsed = nil
    mission.nfwStoneExpectedVehicleCount = keptStoneCount > 0 and keptStoneCount or nil

    if #removedNames > 0 then
        nfwLogInfo(
            "[%s] Stein-Mission Supportfahrzeuge entfernt: mission=%s removed=%d vehicles=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            #removedNames,
            table.concat(removedNames, ", ")
        )
    end
end

function NeighborFieldWorkers:pruneCultivateMissionSupportVehicles(assignment)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or not self:isCultivateMission(mission) then
        return
    end

    local bestTractor = nil
    local bestTractorScore = -math.huge
    local bestTool = nil

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            if vehicle.spec_motorized ~= nil
                and vehicle.spec_trailer == nil
                and vehicle.spec_combine == nil
                and vehicle.spec_stonePicker == nil then
                local score = self:getVehiclePowerScore(vehicle)
                if bestTractor == nil or score > bestTractorScore then
                    bestTractor = vehicle
                    bestTractorScore = score
                end
            elseif vehicle.spec_motorized == nil then
                if self:isFieldworkMissionImplement(vehicle) and bestTool == nil then
                    bestTool = vehicle
                end
            end
        end
    end

    if bestTool == nil then
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_motorized == nil and vehicle.spec_trailer == nil then
                bestTool = vehicle
                break
            end
        end
    end

    local removedNames = {}
    for i = #mission.vehicles, 1, -1 do
        local vehicle = mission.vehicles[i]
        if vehicle ~= nil and not vehicle.isDeleted then
            local keepVehicle = vehicle == bestTractor or vehicle == bestTool
            if not keepVehicle then
                if vehicle.getIsAIActive ~= nil and vehicle.stopCurrentAIJob ~= nil then
                    local okActive, isActive = pcall(vehicle.getIsAIActive, vehicle)
                    if okActive and isActive then
                        local stopMessage = nil
                        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
                            stopMessage = AIMessageSuccessStoppedByUser.new()
                        end
                        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
                    end
                end

                local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                table.insert(removedNames, tostring(vehicleName))
                if vehicle.delete ~= nil then
                    pcall(vehicle.delete, vehicle)
                end
                table.remove(mission.vehicles, i)
            end
        end
    end

    local keptCultivateCount = 0
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            keptCultivateCount = keptCultivateCount + 1
        end
    end
    mission.nfwCultivateMetaFallbackUsed = nil
    mission.nfwCultivateExpectedVehicleCount = keptCultivateCount > 0 and keptCultivateCount or nil

    if #removedNames > 0 then
        nfwLogInfo(
            "[%s] Kultivator-Mission reduziert: mission=%s kept=%d removed=%d vehicles=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            keptCultivateCount,
            #removedNames,
            table.concat(removedNames, ", ")
        )
    end
end

function NeighborFieldWorkers:prunePlowMissionSupportVehicles(assignment)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or not self:isPlowMission(mission) then
        return
    end

    local bestTractor = nil
    local bestTractorScore = -math.huge
    local bestPlow = nil
    local bestWeight = nil
    local fallbackTool = nil

    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            local isMotorized = vehicle.spec_motorized ~= nil
            local isTrailer = vehicle.spec_trailer ~= nil or vehicle.spec_cutterTrailer ~= nil
            local isWeight = false
            if not isMotorized and not isTrailer then
                if vehicle.spec_weight ~= nil then
                    isWeight = true
                else
                    local configNameLower = string.lower(tostring(vehicle.configFileName or ""))
                    local displayNameLower = string.lower(tostring(vehicle.getName ~= nil and vehicle:getName() or ""))
                    if string.find(configNameLower, "weight", 1, true) ~= nil
                        or string.find(configNameLower, "gewicht", 1, true) ~= nil
                        or string.find(displayNameLower, "weight", 1, true) ~= nil
                        or string.find(displayNameLower, "gewicht", 1, true) ~= nil then
                        isWeight = true
                    end
                end
            end

            local isPlowTool = false
            if not isMotorized and not isTrailer and not isWeight then
                if vehicle.spec_plow ~= nil then
                    isPlowTool = true
                elseif self:isFieldworkMissionImplement(vehicle) then
                    local configNameLower = string.lower(tostring(vehicle.configFileName or ""))
                    local displayNameLower = string.lower(tostring(vehicle.getName ~= nil and vehicle:getName() or ""))
                    if string.find(configNameLower, "plow", 1, true) ~= nil
                        or string.find(configNameLower, "pflug", 1, true) ~= nil
                        or string.find(displayNameLower, "plow", 1, true) ~= nil
                        or string.find(displayNameLower, "pflug", 1, true) ~= nil then
                        isPlowTool = true
                    end
                end
            end

            if isMotorized and not isTrailer and not isWeight and vehicle.spec_combine == nil and vehicle.spec_stonePicker == nil then
                local score = self:getVehiclePowerScore(vehicle)
                if bestTractor == nil or score > bestTractorScore then
                    bestTractor = vehicle
                    bestTractorScore = score
                end
            elseif isWeight and bestWeight == nil then
                bestWeight = vehicle
            elseif isPlowTool and bestPlow == nil then
                bestPlow = vehicle
            elseif not isMotorized and not isTrailer and not isWeight and self:isFieldworkMissionImplement(vehicle) and fallbackTool == nil then
                fallbackTool = vehicle
            end
        end
    end

    if bestPlow == nil then
        bestPlow = fallbackTool
    end

    local removedNames = {}
    for i = #mission.vehicles, 1, -1 do
        local vehicle = mission.vehicles[i]
        if vehicle ~= nil and not vehicle.isDeleted then
            local keepVehicle = vehicle == bestTractor or vehicle == bestWeight or vehicle == bestPlow
            if not keepVehicle then
                if vehicle.getIsAIActive ~= nil and vehicle.stopCurrentAIJob ~= nil then
                    local okActive, isActive = pcall(vehicle.getIsAIActive, vehicle)
                    if okActive and isActive then
                        local stopMessage = nil
                        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
                            stopMessage = AIMessageSuccessStoppedByUser.new()
                        end
                        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
                    end
                end

                local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                table.insert(removedNames, tostring(vehicleName))
                if vehicle.delete ~= nil then
                    pcall(vehicle.delete, vehicle)
                end
                table.remove(mission.vehicles, i)
            end
        end
    end

    local keptPlowCount = 0
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            keptPlowCount = keptPlowCount + 1
        end
    end
    mission.nfwPlowMetaFallbackUsed = nil
    mission.nfwPlowExpectedVehicleCount = keptPlowCount > 0 and keptPlowCount or nil

    if #removedNames > 0 then
        nfwLogInfo(
            "[%s] Pflug-Mission reduziert: mission=%s kept=%d removed=%d vehicles=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            keptPlowCount,
            #removedNames,
            table.concat(removedNames, ", ")
        )
    end
end

function NeighborFieldWorkers:pruneSowMissionSupportVehicles(assignment)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil or not self:isSowMission(mission) then
        return
    end

    local function getLower(text)
        return string.lower(tostring(text or ""))
    end

    local function getVehicleToolKey(vehicle)
        if vehicle == nil then
            return nil
        end
        local fileName = tostring(vehicle.configFileName or "")
        local key = nfwNormalizeXmlPath(fileName)
        if key ~= nil and key ~= "" then
            return key
        end
        local okName, displayName = false, nil
        if vehicle.getName ~= nil then
            okName, displayName = pcall(vehicle.getName, vehicle)
        end
        if okName and displayName ~= nil and tostring(displayName) ~= "" then
            return string.lower(tostring(displayName))
        end
        return nil
    end

    local function isSowingToolVehicle(vehicle)
        if vehicle == nil or vehicle.isDeleted or vehicle.spec_motorized ~= nil then
            return false
        end

        local isSowingTool = vehicle.spec_sowingMachine ~= nil or vehicle.spec_planter ~= nil
        if isSowingTool then
            return true
        end

        local configNameLower = getLower(vehicle.configFileName)
        local displayNameLower = getLower(vehicle.getName ~= nil and vehicle:getName() or "")
        return string.find(configNameLower, "sow", 1, true) ~= nil
            or string.find(configNameLower, "seed", 1, true) ~= nil
            or string.find(configNameLower, "seeder", 1, true) ~= nil
            or string.find(configNameLower, "planter", 1, true) ~= nil
            or string.find(displayNameLower, "sow", 1, true) ~= nil
            or string.find(displayNameLower, "seed", 1, true) ~= nil
            or string.find(displayNameLower, "seeder", 1, true) ~= nil
            or string.find(displayNameLower, "planter", 1, true) ~= nil
    end

    local function getTopNonMotorizedParent(vehicle)
        local current = vehicle
        local depth = 0
        while current ~= nil and depth < 10 and current.getAttacherVehicle ~= nil do
            local okParent, parentVehicle = pcall(current.getAttacherVehicle, current)
            if not okParent or parentVehicle == nil or parentVehicle == current then
                break
            end
            if parentVehicle.spec_motorized ~= nil then
                break
            end
            current = parentVehicle
            depth = depth + 1
        end
        return current
    end

    local function isDescendantOf(candidate, ancestor)
        if candidate == nil or ancestor == nil then
            return false
        end
        if candidate == ancestor then
            return true
        end
        local current = candidate
        local depth = 0
        while current ~= nil and depth < 10 and current.getAttacherVehicle ~= nil do
            local okParent, parentVehicle = pcall(current.getAttacherVehicle, current)
            if not okParent or parentVehicle == nil or parentVehicle == current then
                break
            end
            if parentVehicle == ancestor then
                return true
            end
            current = parentVehicle
            depth = depth + 1
        end
        return false
    end

    local bestTractor = nil
    local bestTractorScore = -math.huge
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            local isMotorized = vehicle.spec_motorized ~= nil
            local isTrailer = vehicle.spec_trailer ~= nil or vehicle.spec_cutterTrailer ~= nil
            local isForbiddenMotorized = vehicle.spec_combine ~= nil or vehicle.spec_stonePicker ~= nil
            if isMotorized and not isTrailer and not isForbiddenMotorized then
                local score = self:getVehiclePowerScore(vehicle)
                if bestTractor == nil or score > bestTractorScore then
                    bestTractor = vehicle
                    bestTractorScore = score
                end
            end
        end
    end

    local bestWeight = nil
    if bestTractor ~= nil and bestTractor.rootNode ~= nil then
        local tx, _, tz = getWorldTranslation(bestTractor.rootNode)
        local bestWeightDist = math.huge
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_motorized == nil then
                local isWeight = vehicle.spec_weight ~= nil
                if not isWeight then
                    local configNameLower = getLower(vehicle.configFileName)
                    local displayNameLower = getLower(vehicle.getName ~= nil and vehicle:getName() or "")
                    isWeight = string.find(configNameLower, "weight", 1, true) ~= nil
                        or string.find(configNameLower, "gewicht", 1, true) ~= nil
                        or string.find(displayNameLower, "weight", 1, true) ~= nil
                        or string.find(displayNameLower, "gewicht", 1, true) ~= nil
                        or string.find(displayNameLower, "pickup 900", 1, true) ~= nil
                end

                if isWeight and vehicle.rootNode ~= nil then
                    local vx, _, vz = getWorldTranslation(vehicle.rootNode)
                    local distSq = MathUtil.vector2LengthSq(vx - tx, vz - tz)
                    if bestWeight == nil or distSq < bestWeightDist then
                        bestWeight = vehicle
                        bestWeightDist = distSq
                    end
                end
            end
        end
    end

    local selectedTopImplement = nil
    local selectedScore = -math.huge
    for _, vehicle in ipairs(mission.vehicles) do
        if isSowingToolVehicle(vehicle) then
            local topImplement = getTopNonMotorizedParent(vehicle)
            if topImplement ~= nil then
                local score = 0
                if bestTractor ~= nil and self:isImplementAttachedToVehicle(vehicle, bestTractor) then
                    score = score + 1000000
                end
                if bestTractor ~= nil and bestTractor.rootNode ~= nil and topImplement.rootNode ~= nil then
                    local tx, _, tz = getWorldTranslation(bestTractor.rootNode)
                    local ix, _, iz = getWorldTranslation(topImplement.rootNode)
                    local dist = MathUtil.vector2Length(ix - tx, iz - tz)
                    score = score - dist
                end
                if selectedTopImplement == nil or score > selectedScore then
                    selectedTopImplement = topImplement
                    selectedScore = score
                end
            end
        end
    end

    local preferredToolKeys = mission.nfwSowPreferredToolKeys
    local chainToolKeys = {}
    if type(preferredToolKeys) ~= "table" then
        preferredToolKeys = nil
    end

    if preferredToolKeys == nil and selectedTopImplement ~= nil then
        preferredToolKeys = {}
        local topKey = getVehicleToolKey(selectedTopImplement)
        if topKey ~= nil then
            preferredToolKeys[topKey] = true
        end

        local sowTools = {}
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_motorized == nil then
                if isDescendantOf(vehicle, selectedTopImplement) then
                    local chainKey = getVehicleToolKey(vehicle)
                    if chainKey ~= nil then
                        preferredToolKeys[chainKey] = true
                        chainToolKeys[chainKey] = true
                    end
                end
                if isSowingToolVehicle(vehicle) then
                    table.insert(sowTools, vehicle)
                end
            end
        end

        -- Keep chained two-part seeding setups stable (e.g. power harrow + seeder).
        if next(preferredToolKeys) ~= nil and #sowTools >= 2 and topKey ~= nil then
            local hasSecond = false
            for key, _ in pairs(preferredToolKeys) do
                if key ~= topKey then
                    hasSecond = true
                    break
                end
            end

            if not hasSecond then
                local bestCompanion = nil
                local bestCompanionDist = math.huge
                if selectedTopImplement.rootNode ~= nil then
                    local tx, _, tz = getWorldTranslation(selectedTopImplement.rootNode)
                    for _, candidate in ipairs(sowTools) do
                        if candidate ~= selectedTopImplement and candidate.rootNode ~= nil then
                            local cx, _, cz = getWorldTranslation(candidate.rootNode)
                            local distSq = MathUtil.vector2LengthSq(cx - tx, cz - tz)
                            if distSq < bestCompanionDist then
                                bestCompanion = candidate
                                bestCompanionDist = distSq
                            end
                        end
                    end
                end

                if bestCompanion ~= nil then
                    local companionKey = getVehicleToolKey(bestCompanion)
                    if companionKey ~= nil then
                        preferredToolKeys[companionKey] = true
                    end
                end
            end
        end

        if next(preferredToolKeys) ~= nil then
            mission.nfwSowPreferredToolKeys = preferredToolKeys
        else
            preferredToolKeys = nil
        end
    end

    if selectedTopImplement ~= nil then
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_motorized == nil then
                if isDescendantOf(vehicle, selectedTopImplement) then
                    local chainKey = getVehicleToolKey(vehicle)
                    if chainKey ~= nil then
                        chainToolKeys[chainKey] = true
                    end
                end
            end
        end
    end

    local keptPreferredByKey = {}
    local function keepByPreferredKeys(vehicle)
        if preferredToolKeys == nil or vehicle == nil or vehicle.isDeleted then
            return false
        end
        if vehicle.spec_motorized ~= nil then
            return false
        end
        local key = getVehicleToolKey(vehicle)
        if key == nil or preferredToolKeys[key] ~= true then
            return false
        end
        if chainToolKeys[key] == true then
            return false
        end
        local used = Utils.getNoNil(keptPreferredByKey[key], 0)
        if used >= 1 then
            return false
        end
        keptPreferredByKey[key] = used + 1
        return true
    end

    local removedNames = {}
    for i = #mission.vehicles, 1, -1 do
        local vehicle = mission.vehicles[i]
        if vehicle ~= nil and not vehicle.isDeleted then
            local keepVehicle = vehicle == bestTractor
                or vehicle == bestWeight
                or isDescendantOf(vehicle, selectedTopImplement)
                or keepByPreferredKeys(vehicle)
            if not keepVehicle then
                if vehicle.getIsAIActive ~= nil and vehicle.stopCurrentAIJob ~= nil then
                    local okActive, isActive = pcall(vehicle.getIsAIActive, vehicle)
                    if okActive and isActive then
                        local stopMessage = nil
                        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
                            stopMessage = AIMessageSuccessStoppedByUser.new()
                        end
                        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
                    end
                end

                local vehicleName = vehicle.getName ~= nil and vehicle:getName() or tostring(vehicle)
                table.insert(removedNames, tostring(vehicleName))
                if vehicle.delete ~= nil then
                    pcall(vehicle.delete, vehicle)
                end
                table.remove(mission.vehicles, i)
            end
        end
    end

    local keptSowCount = 0
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted then
            keptSowCount = keptSowCount + 1
        end
    end
    mission.nfwSowMetaFallbackUsed = nil
    mission.nfwSowExpectedVehicleCount = keptSowCount > 0 and keptSowCount or nil

    if #removedNames > 0 then
        local tractorName = bestTractor ~= nil and (bestTractor.getName ~= nil and bestTractor:getName() or "tractor") or
            "none"
        local toolName = selectedTopImplement ~= nil and
            (selectedTopImplement.getName ~= nil and selectedTopImplement:getName() or "tool") or "none"
        local weightName = bestWeight ~= nil and (bestWeight.getName ~= nil and bestWeight:getName() or "weight") or
            "none"
        nfwLogInfo(
            "[%s] Sae-Mission reduziert: mission=%s kept=%d removed=%d tractor=%s tool=%s weight=%s vehicles=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            keptSowCount,
            #removedNames,
            tostring(tractorName),
            tostring(toolName),
            tostring(weightName),
            table.concat(removedNames, ", ")
        )
    end
end

function NeighborFieldWorkers:isFieldworkMissionImplement(vehicle)
    if vehicle == nil or vehicle.isDeleted or vehicle.spec_motorized ~= nil then
        return false
    end

    if vehicle.getAIMarkers ~= nil then
        local okMarkers, leftMarker, rightMarker, backMarker = pcall(vehicle.getAIMarkers, vehicle)
        if okMarkers and leftMarker ~= nil and rightMarker ~= nil and backMarker ~= nil then
            return true
        end
    end

    if vehicle.aiImplementStartLine ~= nil then
        return true
    end

    return false
end

function NeighborFieldWorkers:isImplementCurrentlyUsedByAI(workVehicle, implementObject)
    if workVehicle == nil
        or implementObject == nil
        or workVehicle.getAttachedAIImplements == nil then
        return false
    end

    local okImplements, aiImplements = pcall(workVehicle.getAttachedAIImplements, workVehicle)
    if not okImplements or aiImplements == nil then
        return false
    end

    for _, aiImplement in ipairs(aiImplements) do
        if aiImplement ~= nil and aiImplement.object == implementObject then
            return true
        end
    end

    return false
end

function NeighborFieldWorkers:isFrontAttachmentOnVehicle(vehicle, attachedImplement)
    if vehicle == nil
        or attachedImplement == nil
        or attachedImplement.object == nil
        or vehicle.rootNode == nil
        or attachedImplement.object.rootNode == nil then
        return false
    end

    local jointDescIndex = attachedImplement.jointDescIndex
    if jointDescIndex ~= nil and vehicle.getAttacherJointByJointDescIndex ~= nil then
        local okJoint, jointDesc = pcall(vehicle.getAttacherJointByJointDescIndex, vehicle, jointDescIndex)
        if okJoint and jointDesc ~= nil then
            if jointDesc.jointTransform ~= nil then
                local _, _, jointLocalZ = localToLocal(jointDesc.jointTransform, vehicle.rootNode, 0, 0, 0)
                if math.abs(jointLocalZ) > 0.05 then
                    return jointLocalZ > 0
                end
            end

            if jointDesc.attacherJointDirection ~= nil and jointDesc.attacherJointDirection ~= 0 then
                return jointDesc.attacherJointDirection > 0
            end
        end
    end

    local vx, _, vz = getWorldTranslation(vehicle.rootNode)
    local ix, _, iz = getWorldTranslation(attachedImplement.object.rootNode)
    local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
    local dirLen = math.max(0.001, MathUtil.vector2Length(dirX, dirZ))
    dirX = dirX / dirLen
    dirZ = dirZ / dirLen

    local dot = (ix - vx) * dirX + (iz - vz) * dirZ
    return dot > 0.1
end

function NeighborFieldWorkers:enforceRaisedFrontSupportImplements(assignment, forceImmediate, onlyVehicle)
    if assignment == nil then
        return true
    end

    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil or mission.vehicles == nil then
        return true
    end

    local now = g_time or 0
    if not forceImmediate and now < Utils.getNoNil(assignment.nextFrontLiftEnforceAtMs, 0) then
        return true
    end
    assignment.nextFrontLiftEnforceAtMs = now + 2000

    local raisedEntries = {}
    local stillLoweredEntries = {}
    local allRaised = true
    local attachedCount = 0
    local nonAICount = 0
    local frontSupportCount = 0
    for _, missionVehicle in ipairs(mission.vehicles) do
        if missionVehicle ~= nil
            and not missionVehicle.isDeleted
            and missionVehicle.spec_motorized ~= nil
            and (onlyVehicle == nil or missionVehicle == onlyVehicle)
            and missionVehicle.getAttachedImplements ~= nil
            and missionVehicle.getJointMoveDown ~= nil
            and missionVehicle.setJointMoveDown ~= nil then
            local implements = missionVehicle:getAttachedImplements()
            if implements ~= nil then
                for _, attachedImplement in ipairs(implements) do
                    local implementObject = attachedImplement.object
                    local jointDescIndex = attachedImplement.jointDescIndex
                    attachedCount = attachedCount + 1
                    local isUsedByAI = self:isImplementCurrentlyUsedByAI(missionVehicle, implementObject)
                    if not isUsedByAI then
                        nonAICount = nonAICount + 1
                    end
                    if implementObject ~= nil
                        and not implementObject.isDeleted
                        and jointDescIndex ~= nil
                        and not isUsedByAI
                        and self:isFrontAttachmentOnVehicle(missionVehicle, attachedImplement) then
                        frontSupportCount = frontSupportCount + 1
                        local vehicleName = missionVehicle.getName ~= nil and missionVehicle:getName() or
                            tostring(missionVehicle)
                        local implementName = implementObject.getName ~= nil and implementObject:getName() or
                            tostring(implementObject)
                        local entry = string.format("%s->%s", tostring(vehicleName), tostring(implementName))

                        local okMoveDown, moveDown = pcall(missionVehicle.getJointMoveDown, missionVehicle,
                            jointDescIndex)
                        if okMoveDown and moveDown == true then
                            pcall(missionVehicle.setJointMoveDown, missionVehicle, jointDescIndex, false, false)
                            table.insert(raisedEntries, entry)
                        end

                        local okAfter, moveDownAfter = pcall(missionVehicle.getJointMoveDown, missionVehicle,
                            jointDescIndex)
                        if okAfter and moveDownAfter == true then
                            allRaised = false
                            table.insert(stillLoweredEntries, entry)
                        end
                    end
                end
            end
        end
    end

    if #raisedEntries > 0 then
        nfwLogInfo(
            "[%s] Front-Anbau automatisch angehoben: mission=%s entries=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            table.concat(raisedEntries, ", ")
        )
    end

    if forceImmediate and #stillLoweredEntries > 0 then
        nfwLogInfo(
            "[%s] Front-Anbau noch nicht oben, AI-Start wird verschoben: mission=%s entries=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            table.concat(stillLoweredEntries, ", ")
        )
    elseif forceImmediate and frontSupportCount == 0 and nonAICount > 0 then
        nfwLogInfo(
            "[%s] Front-Anbau Pruefung: keine Front-Support-Geraete erkannt: mission=%s attached=%d nonAI=%d",
            self.MOD_NAME,
            tostring(assignment.key),
            attachedCount,
            nonAICount
        )
    end

    return allRaised
end

function NeighborFieldWorkers:ensureTransportStateBeforeAIStart(assignment, vehicle)
    if vehicle == nil or vehicle.isDeleted then
        return false
    end

    local now = g_time or 0
    local changedEntries = {}
    local visited = {}
    local enforceCooldownMs = 12000
    local edgeFallbackBlockedMs = enforceCooldownMs + 4000
    local directStartBypassBlockedMs = 12000
    local shouldEnforceTransportNow = true
    if assignment ~= nil then
        shouldEnforceTransportNow = now >= Utils.getNoNil(assignment.transportPrepareNextEnforceAtMs, 0)
    end

    local function getObjectName(obj)
        if obj == nil then
            return "nil"
        end
        return tostring(obj.getName ~= nil and obj:getName() or obj)
    end

    local function recordTransportChange(obj, changeTag)
        table.insert(
            changedEntries,
            string.format("%s:%s", nfwToSingleLineText(getObjectName(obj), 38), tostring(changeTag))
        )
    end

    local function enforceTransportOnObject(obj)
        if obj == nil or obj.isDeleted or visited[obj] then
            return
        end
        visited[obj] = true

        if obj.getCanBeTurnedOn ~= nil
            and obj.getIsTurnedOn ~= nil
            and obj.setIsTurnedOn ~= nil then
            local okCanTurn, canTurn = pcall(obj.getCanBeTurnedOn, obj)
            local okTurnedOn, isTurnedOn = pcall(obj.getIsTurnedOn, obj)
            if okCanTurn and canTurn and okTurnedOn and isTurnedOn then
                pcall(obj.setIsTurnedOn, obj, false, true)
                recordTransportChange(obj, "turnOff")
            end
        end

        if obj.spec_pipe ~= nil and obj.setPipeState ~= nil then
            local currentState = obj.spec_pipe.currentState
            if type(currentState) == "number" and currentState ~= 1 then
                pcall(obj.setPipeState, obj, 1, true)
                recordTransportChange(obj, string.format("pipe->1(from=%s)", tostring(currentState)))
            end
        end

        if obj.spec_foldable ~= nil
            and obj.spec_foldable.hasFoldingParts
            and obj.spec_foldable.allowUnfoldingByAI == true
            and obj.getFoldAnimTime ~= nil
            and obj.setFoldDirection ~= nil then
            local okFold, foldTime = pcall(obj.getFoldAnimTime, obj)
            if okFold and type(foldTime) == "number" then
                local moveDirection = tonumber(obj.spec_foldable.moveDirection) or 0
                local turnOnDir = tonumber(obj.spec_foldable.turnOnFoldDirection) or 0
                local transportReady = false
                if turnOnDir > 0 then
                    transportReady = foldTime <= 0.001
                elseif turnOnDir < 0 then
                    transportReady = foldTime >= 0.999
                else
                    transportReady = foldTime <= 0.001 or foldTime >= 0.999
                end

                if not transportReady then
                    local foldDirection = nil
                    if math.abs(moveDirection) > 0.001 then
                        foldDirection = nil
                    elseif turnOnDir > 0 then
                        foldDirection = -1
                    elseif turnOnDir < 0 then
                        foldDirection = 1
                    else
                        foldDirection = foldTime > 0.5 and -1 or 1
                    end
                    if foldDirection ~= nil then
                        pcall(obj.setFoldDirection, obj, foldDirection, true)
                        recordTransportChange(
                            obj,
                            string.format("foldDir=%d time=%.3f turnOnDir=%s", foldDirection, foldTime,
                                tostring(turnOnDir))
                        )
                    end
                end
            end
        end
    end

    local function visitCarrier(carrier, depth)
        if carrier == nil or depth > 10 or carrier.getAttachedImplements == nil then
            return
        end

        local implements = carrier:getAttachedImplements()
        if implements == nil then
            return
        end

        for _, attachedImplement in ipairs(implements) do
            if attachedImplement ~= nil and attachedImplement.object ~= nil then
                if attachedImplement.jointDescIndex ~= nil
                    and carrier.getJointMoveDown ~= nil
                    and carrier.setJointMoveDown ~= nil then
                    local okMoveDown, moveDown = pcall(
                        carrier.getJointMoveDown,
                        carrier,
                        attachedImplement.jointDescIndex
                    )
                    if okMoveDown and moveDown == true then
                        pcall(carrier.setJointMoveDown, carrier, attachedImplement.jointDescIndex, false, true)
                        local carrierName = tostring(carrier.getName ~= nil and carrier:getName() or carrier)
                        local implementName = tostring(attachedImplement.object.getName ~= nil and
                            attachedImplement.object:getName() or attachedImplement.object)
                        table.insert(
                            changedEntries,
                            string.format(
                                "%s->%s",
                                nfwToSingleLineText(carrierName, 28),
                                nfwToSingleLineText(implementName, 28)
                            )
                        )
                    end
                end

                enforceTransportOnObject(attachedImplement.object)
                visitCarrier(attachedImplement.object, depth + 1)
            end
        end
    end

    if shouldEnforceTransportNow then
        enforceTransportOnObject(vehicle)
        visitCarrier(vehicle, 0)
        if assignment ~= nil then
            assignment.transportPrepareNextEnforceAtMs = now + enforceCooldownMs
        end
    end

    if #changedEntries > 0 then
        nfwLogHelperDiag(
            "[%s] HelperDiag START_TRANSPORT_LOWERING_RESET: mission=%s vehicle=%s changed=%s",
            self.MOD_NAME,
            tostring(assignment ~= nil and assignment.key or "n/a"),
            tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
            nfwToSingleLineText(table.concat(changedEntries, ", "), 900)
        )
    end

    if vehicle.prepareForAIDriving ~= nil then
        pcall(vehicle.prepareForAIDriving, vehicle)
    end

    local isReadyToDrive = true
    local blockingVehicle = nil
    if vehicle.getIsAIReadyToDrive ~= nil then
        local okReady, readyResult, blockingResult = pcall(vehicle.getIsAIReadyToDrive, vehicle)
        if okReady then
            isReadyToDrive = readyResult ~= false
            blockingVehicle = blockingResult
        end
    end

    local isPreparingToDrive = false
    if not isReadyToDrive and vehicle.getIsAIPreparingToDrive ~= nil then
        local okPreparing, preparingResult = pcall(vehicle.getIsAIPreparingToDrive, vehicle)
        if okPreparing then
            isPreparingToDrive = preparingResult == true
        end
    end

    if isReadyToDrive then
        if assignment ~= nil then
            assignment.transportPrepareSinceMs = 0
            assignment.nextTransportPrepareLogAtMs = 0
            assignment.transportPrepareNextEnforceAtMs = 0
        end
        return true
    end

    if assignment ~= nil then
        if Utils.getNoNil(assignment.transportPrepareSinceMs, 0) <= 0 then
            assignment.transportPrepareSinceMs = now
        end

        local blockedForMs = math.max(0, now - assignment.transportPrepareSinceMs)
        assignment.nextStartAfterAttachMs = math.max(
            Utils.getNoNil(assignment.nextStartAfterAttachMs, 0),
            now + 900
        )

        local blockingName = "n/a"
        local blockingUnfolded = "n/a"
        local blockingLowered = "n/a"
        if blockingVehicle ~= nil then
            if blockingVehicle.getName ~= nil then
                blockingName = tostring(blockingVehicle:getName())
            else
                blockingName = tostring(blockingVehicle)
            end
            if blockingVehicle.getIsUnfolded ~= nil then
                local okUnfolded, unfolded = pcall(blockingVehicle.getIsUnfolded, blockingVehicle)
                if okUnfolded then
                    blockingUnfolded = tostring(unfolded)
                end
            end
            if blockingVehicle.getIsLowered ~= nil then
                local okLowered, lowered = pcall(blockingVehicle.getIsLowered, blockingVehicle, false)
                if okLowered then
                    blockingLowered = tostring(lowered)
                end
            end
        end

        if now >= Utils.getNoNil(assignment.nextTransportPrepareLogAtMs, 0) then
            assignment.nextTransportPrepareLogAtMs = now + 3000
            nfwLogHelperDiag(
                "[%s] HelperDiag START_TRANSPORT_WAIT: mission=%s vehicle=%s blockedForMs=%d preparing=%s blocking=%s unfolded=%s lowered=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
                blockedForMs,
                tostring(isPreparingToDrive),
                blockingName,
                blockingUnfolded,
                blockingLowered
            )
        end

        local bypassDueToDirectStart = assignment.forceDirectStart == true and
            blockedForMs >= directStartBypassBlockedMs
        if bypassDueToDirectStart then
            nfwLogHelperDiag(
                "[%s] HelperDiag START_TRANSPORT_BYPASS: mission=%s vehicle=%s blockedForMs=%d action=allowStartDirect",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
                blockedForMs
            )
            assignment.transportPrepareSinceMs = 0
            assignment.nextTransportPrepareLogAtMs = 0
            assignment.transportPrepareNextEnforceAtMs = 0
            return true
        end

        if blockedForMs >= edgeFallbackBlockedMs
            and self.fieldEdgeStartModeEnabled == true
            and assignment.disableEdgeStartForMission ~= true then
            assignment.disableEdgeStartForMission = true
            assignment.forceDirectStart = true
            nfwLogHelperDiag(
                "[%s] HelperDiag EDGE_FALLBACK_ARMED: mission=%s vehicle=%s reason=TRANSPORT_PREP_BLOCKED action=disableEdgeStartForMission+forceDirectStart blockedForMs=%d thresholdMs=%d enforceCooldownMs=%d",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown"),
                blockedForMs,
                edgeFallbackBlockedMs,
                enforceCooldownMs
            )
        end
    end

    return false
end

function NeighborFieldWorkers:isImplementAttachedToVehicle(implement, workVehicle)
    if implement == nil or workVehicle == nil or implement.isDeleted then
        return false
    end

    if implement.getRootVehicle ~= nil then
        local okRoot, rootVehicle = pcall(implement.getRootVehicle, implement)
        if okRoot and rootVehicle == workVehicle then
            return true
        end
    elseif implement.rootVehicle ~= nil and implement.rootVehicle == workVehicle then
        return true
    end

    if implement.getAttacherVehicle ~= nil then
        local okAttacher, attacherVehicle = pcall(implement.getAttacherVehicle, implement)
        if okAttacher and attacherVehicle ~= nil then
            local depth = 0
            while attacherVehicle ~= nil and depth < 10 do
                if attacherVehicle == workVehicle then
                    return true
                end
                if attacherVehicle.getAttacherVehicle == nil then
                    break
                end
                local okParent, parentVehicle = pcall(attacherVehicle.getAttacherVehicle, attacherVehicle)
                if not okParent or parentVehicle == attacherVehicle then
                    break
                end
                attacherVehicle = parentVehicle
                depth = depth + 1
            end
        end
    end

    return false
end

function NeighborFieldWorkers:getCurrentAIImplementCount(workVehicle)
    if workVehicle == nil or workVehicle.isDeleted or workVehicle.getAttachedAIImplements == nil then
        return 0
    end

    local okImplements, aiImplements = pcall(workVehicle.getAttachedAIImplements, workVehicle)
    if not okImplements or aiImplements == nil then
        return 0
    end

    return #aiImplements
end

function NeighborFieldWorkers:stopUnexpectedMissionVehicleAI(assignment, reason)
    if assignment == nil or assignment.mission == nil or assignment.mission.vehicles == nil then
        return false
    end

    local now = g_time or 0
    if now < Utils.getNoNil(assignment.nextUnexpectedAiStopAtMs, 0) then
        return false
    end

    local stopMessage = nil
    if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
        stopMessage = AIMessageSuccessStoppedByUser.new()
    end

    local stopped = 0
    local stoppedVehicles = {}
    for _, vehicle in ipairs(assignment.mission.vehicles) do
        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.getIsAIActive ~= nil
            and vehicle.stopCurrentAIJob ~= nil then
            local okActive, isActive = pcall(vehicle.getIsAIActive, vehicle)
            if okActive and isActive then
                local okStop = pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
                if okStop then
                    stopped = stopped + 1
                    local vehicleName = vehicle.getName ~= nil and vehicle:getName() or "unknown"
                    table.insert(stoppedVehicles, tostring(vehicleName))
                end
            end
        end
    end

    assignment.nextUnexpectedAiStopAtMs = now + 3000

    if stopped > 0 then
        nfwLogHelperDiag(
            "[%s] HelperDiag UNEXPECTED_AI_STOP: mission=%s reason=%s aiStarted=%s stopped=%d vehicles=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(reason or "unknown"),
            tostring(assignment.aiStarted == true),
            stopped,
            #stoppedVehicles > 0 and table.concat(stoppedVehicles, ", ") or "n/a"
        )
        nfwLogInfo(
            "[%s] Unerwartet aktive Missions-AI gestoppt: mission=%s stopped=%d reason=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            stopped,
            tostring(reason or "unknown")
        )
        return true
    end

    return false
end

function NeighborFieldWorkers:adoptExistingMissionVehicleAI(assignment)
    -- Disabled: adopting externally running mission AI from savegame can create
    -- recursive mount chains (Mountable stack overflow) in some mission setups.
    -- We always use the controlled NFW start path instead.
    return false
end

function NeighborFieldWorkers:findMissionWorkVehicle(assignment)
    local mission = assignment.mission
    if mission == nil or mission.vehicles == nil then
        return nil
    end

    if self:isHarvestMission(mission) then
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil
                and not vehicle.isDeleted
                and vehicle.spec_combine ~= nil
                and vehicle.spec_motorized ~= nil
                and vehicle.getCanStartFieldWork ~= nil
                and vehicle:getCanStartFieldWork() then
                return vehicle
            end
        end
    end

    if self:isStoneMission(mission) then
        for _, vehicle in ipairs(mission.vehicles) do
            if vehicle ~= nil
                and not vehicle.isDeleted
                and vehicle.spec_motorized ~= nil
                and vehicle.spec_stonePicker == nil
                and vehicle.getCanStartFieldWork ~= nil
                and vehicle:getCanStartFieldWork() then
                return vehicle
            end
        end
    end

    local bestVehicle = nil
    local bestScore = -1
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil
            and not vehicle.isDeleted
            and vehicle.spec_motorized ~= nil
            and vehicle.getCanStartFieldWork ~= nil
            and vehicle:getCanStartFieldWork() then
            local aiImplCount = self:getCurrentAIImplementCount(vehicle)
            local attachedCount = 0
            if vehicle.getAttachedImplements ~= nil then
                local implements = vehicle:getAttachedImplements()
                if implements ~= nil then
                    attachedCount = #implements
                end
            end

            local score = aiImplCount * 100 + attachedCount * 10 + 1
            if score > bestScore then
                bestScore = score
                bestVehicle = vehicle
            end
        end
    end
    if bestVehicle ~= nil then
        return bestVehicle
    end

    bestVehicle = nil
    bestScore = -1
    for _, vehicle in ipairs(mission.vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_motorized ~= nil and vehicle.getAttachedImplements ~= nil then
            local implements = vehicle:getAttachedImplements()
            if implements ~= nil and #implements > 0 then
                local score = #implements
                if score > bestScore then
                    bestScore = score
                    bestVehicle = vehicle
                end
            end
        end
    end

    return bestVehicle
end

function NeighborFieldWorkers:objectContainsSowingToolForAIOrdering(obj, depth, visited)
    if obj == nil or depth > 8 then
        return false
    end

    visited = visited or {}
    if visited[obj] then
        return false
    end
    visited[obj] = true

    if obj.spec_sowingMachine ~= nil or obj.spec_planter ~= nil or obj.spec_fertilizingSowingMachine ~= nil then
        return true
    end

    if obj.getAttachedImplements ~= nil then
        local attached = obj:getAttachedImplements()
        if attached ~= nil then
            for _, impl in ipairs(attached) do
                if impl ~= nil
                    and impl.object ~= nil
                    and self:objectContainsSowingToolForAIOrdering(impl.object, depth + 1, visited) then
                    return true
                end
            end
        end
    end

    return false
end

function NeighborFieldWorkers:applySowAIImplementOrderOverride(assignment, workVehicle)
    local mission = assignment ~= nil and assignment.mission or nil
    if mission == nil
        or not self:isSowMission(mission)
        or workVehicle == nil
        or workVehicle.isDeleted
        or type(workVehicle.getAttachedAIImplements) ~= "function" then
        return
    end

    if workVehicle.nfwSowAIImplementOrderOverrideActive == true then
        return
    end

    local originalGetAttachedAIImplements = workVehicle.getAttachedAIImplements
    workVehicle.nfwOriginalGetAttachedAIImplements = originalGetAttachedAIImplements

    workVehicle.getAttachedAIImplements = function(vehicleSelf, ...)
        local impls = originalGetAttachedAIImplements(vehicleSelf, ...)
        if type(impls) ~= "table" or #impls <= 1 then
            return impls
        end

        local ordered = {}
        for idx, aiImpl in ipairs(impls) do
            table.insert(ordered, {
                __idx = idx,
                __impl = aiImpl
            })
        end

        local function getPriority(aiImpl)
            local obj = aiImpl ~= nil and aiImpl.object or nil
            if obj == nil then
                return 100
            end
            if obj.spec_sowingMachine ~= nil or obj.spec_planter ~= nil or obj.spec_fertilizingSowingMachine ~= nil then
                return 0
            end
            if obj.spec_powerHarrow ~= nil or obj.spec_cultivator ~= nil or obj.spec_seedbed ~= nil then
                return 1
            end
            if self:objectContainsSowingToolForAIOrdering(obj, 0, {}) then
                return 2
            end
            return 10
        end

        table.sort(ordered, function(a, b)
            local pa = getPriority(a.__impl)
            local pb = getPriority(b.__impl)
            if pa ~= pb then
                return pa < pb
            end
            return a.__idx < b.__idx
        end)

        local changed = false
        local result = {}
        local beforeNames = {}
        local afterNames = {}
        for idx, entry in ipairs(ordered) do
            result[idx] = entry.__impl
            local beforeName = tostring(
                impls[idx] ~= nil and impls[idx].object ~= nil and impls[idx].object.getName ~= nil and impls[idx].object:getName() or
                "nil"
            )
            local afterName = tostring(
                entry.__impl ~= nil and entry.__impl.object ~= nil and entry.__impl.object.getName ~= nil and entry.__impl.object:getName() or
                "nil"
            )
            table.insert(beforeNames, beforeName)
            table.insert(afterNames, afterName)
            if impls[idx] ~= entry.__impl then
                changed = true
            end
        end

        if changed and vehicleSelf.nfwSowAIImplementOrderLogDone ~= true then
            vehicleSelf.nfwSowAIImplementOrderLogDone = true
            nfwLogHelperDiag(
                "[%s] HelperDiag SOW_AI_ORDER_OVERRIDE: mission=%s vehicle=%s before={%s} after={%s}",
                self.MOD_NAME,
                tostring(assignment ~= nil and assignment.key or "n/a"),
                tostring(vehicleSelf.getName ~= nil and vehicleSelf:getName() or "unknown"),
                table.concat(beforeNames, ","),
                table.concat(afterNames, ",")
            )
        end

        return result
    end

    workVehicle.nfwSowAIImplementOrderOverrideActive = true
end

function NeighborFieldWorkers:enforceHeadlandsFirstForVehicle(vehicle)
    if vehicle == nil or vehicle.isDeleted then
        nfwLogHelperDiag(
            "[%s] HelperDiag HEADLAND_SETTINGS: skipped reason=vehicle_nil_or_deleted",
            self.MOD_NAME
        )
        return false
    end

    local settingsVehicle = vehicle
    if settingsVehicle.getAIModeFieldCourseSettings == nil
        and vehicle.rootVehicle ~= nil
        and vehicle.rootVehicle.getAIModeFieldCourseSettings ~= nil then
        settingsVehicle = vehicle.rootVehicle
    end

    if settingsVehicle.initializeLoadedAIModeUserSettings ~= nil then
        pcall(settingsVehicle.initializeLoadedAIModeUserSettings, settingsVehicle)
    end

    if settingsVehicle.getAIModeFieldCourseSettings == nil then
        nfwLogHelperDiag(
            "[%s] HelperDiag HEADLAND_SETTINGS: skipped vehicle=%s reason=no_getAIModeFieldCourseSettings",
            self.MOD_NAME,
            tostring(settingsVehicle.getName ~= nil and settingsVehicle:getName() or "unknown")
        )
        return false
    end

    local okSettings, settings = pcall(settingsVehicle.getAIModeFieldCourseSettings, settingsVehicle)
    if (not okSettings or settings == nil or type(settings) ~= "table")
        and type(FieldCourseSettings) == "table"
        and type(FieldCourseSettings.generate) == "function" then
        local okGenerated, generatedSettings = pcall(FieldCourseSettings.generate, settingsVehicle)
        if okGenerated and type(generatedSettings) == "table" then
            okSettings = true
            settings = generatedSettings
            if settingsVehicle.setAIModeFieldCourseSettings ~= nil then
                pcall(settingsVehicle.setAIModeFieldCourseSettings, settingsVehicle, settings)
            end
        end
    end

    if settings == nil or type(settings) ~= "table" then
        nfwLogHelperDiag(
            "[%s] HelperDiag HEADLAND_SETTINGS: skipped vehicle=%s reason=settings_unavailable ok=%s type=%s",
            self.MOD_NAME,
            tostring(settingsVehicle.getName ~= nil and settingsVehicle:getName() or "unknown"),
            tostring(okSettings),
            tostring(type(settings))
        )
        return false
    end

    local changed = false

    if settings.headlandsFirst ~= true then
        settings.headlandsFirst = true
        changed = true
    end

    local numHeadlands = tonumber(settings.numHeadlands)
    if numHeadlands == nil or numHeadlands < 1 then
        settings.numHeadlands = 1
        changed = true
    end

    -- We want work to begin on the initial segment at the field edge so the helper
    -- starts headland work instead of drifting toward inner lanes first.
    if settings.workInitialSegment ~= true then
        settings.workInitialSegment = true
        changed = true
    end

    if changed and settingsVehicle.setAIModeFieldCourseSettings ~= nil then
        pcall(settingsVehicle.setAIModeFieldCourseSettings, settingsVehicle, settings)
    end

    nfwLogHelperDiag(
        "[%s] HelperDiag HEADLAND_SETTINGS: vehicle=%s changed=%s headlandsFirst=%s numHeadlands=%s workInitialSegment=%s",
        self.MOD_NAME,
        tostring(settingsVehicle.getName ~= nil and settingsVehicle:getName() or "unknown"),
        tostring(changed),
        tostring(settings.headlandsFirst),
        tostring(settings.numHeadlands),
        tostring(settings.workInitialSegment)
    )

    return true
end

function NeighborFieldWorkers:startGiantsFieldWorkJob(assignment, vehicle)
    local now = g_time or 0
    if self:isMissionExiting() then
        return false
    end

    if vehicle == nil or vehicle.isDeleted or vehicle.rootNode == nil then
        return false
    end

    local mission = assignment ~= nil and assignment.mission or nil
    local missionKey = tostring(assignment ~= nil and assignment.key or "n/a")
    local vehicleName = tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown")
    local fieldId = self:getMissionFieldId(mission)
    local isDirectStart = assignment ~= nil and assignment.forceDirectStart == true
    local edgeStartSuppressedForMission = assignment ~= nil and assignment.disableEdgeStartForMission == true
    local useFieldEdgeStart = self.fieldEdgeStartModeEnabled == true and not edgeStartSuppressedForMission
    local hadNoFieldStop = assignment ~= nil
        and type(assignment.helperDiagLastStopReason) == "string"
        and string.sub(assignment.helperDiagLastStopReason, 1, 21) == "ERROR_NO_FIELD_FOUND|"
    local effectiveDirectStart = isDirectStart
    if useFieldEdgeStart then
        effectiveDirectStart = false
    end

    local function isSowDirectStartAllowed()
        if mission == nil or vehicle == nil or vehicle.rootNode == nil or not self:isSowMission(mission) then
            return false
        end

        local vx, _, vz = getWorldTranslation(vehicle.rootNode)
        if self:isPositionWithinMissionField(mission, vx, vz) then
            return true
        end

        local fieldX, fieldZ = self:getMissionFieldPosition(mission)
        if type(fieldX) == "number" and type(fieldZ) == "number" then
            local dist = MathUtil.vector2Length(vx - fieldX, vz - fieldZ)
            if dist <= 35 then
                return true
            end
        end

        if g_farmlandManager ~= nil and g_farmlandManager.getFarmlandIdAtWorldPosition ~= nil then
            local okFarm, farmlandAtPos = pcall(g_farmlandManager.getFarmlandIdAtWorldPosition, g_farmlandManager, vx, vz)
            if okFarm and farmlandAtPos ~= nil and fieldId ~= nil and tostring(farmlandAtPos) == tostring(fieldId) then
                return true
            end
        end

        return false
    end

    if effectiveDirectStart and mission ~= nil and self:isSowMission(mission) then
        if not isSowDirectStartAllowed() then
            effectiveDirectStart = false
            nfwLogHelperDiag(
                "[%s] HelperDiag START_DIRECT_OVERRIDE: mission=%s vehicle=%s reason=SOW_FORCE_FIELD_DETECTION_OUTSIDE_FIELD",
                self.MOD_NAME,
                missionKey,
                vehicleName
            )
        else
            nfwLogHelperDiag(
                "[%s] HelperDiag START_DIRECT_KEEP: mission=%s vehicle=%s reason=SOW_ON_OR_NEAR_FIELD",
                self.MOD_NAME,
                missionKey,
                vehicleName
            )
        end
    end

    if assignment ~= nil then
        assignment.helperDiagStartAttemptCount = Utils.getNoNil(assignment.helperDiagStartAttemptCount, 0) + 1
        assignment.helperDiagLastStartAttemptMs = now
        assignment.helperDiagLastStopReason = nil
        assignment.helperDiagLastStopAtMs = 0
        assignment.sowZeroAreaActiveSinceMs = nil
        assignment.sowZeroAreaLastSummary = nil
        assignment.nextSowZeroAreaRecoveryLogAtMs = 0
        assignment.lastStartUsedEdge = useFieldEdgeStart
        assignment.lastStartEdgeTargetX = nil
        assignment.lastStartEdgeTargetZ = nil
        assignment.edgeTargetBestDistSq = nil
        assignment.edgeTargetBestAtMs = 0
        assignment.edgeTargetArrivedStillTask1SinceMs = nil
    end

    nfwLogHelperDiag(
        "[%s] HelperDiag START_ATTEMPT: mission=%s try=%d vehicle=%s field=%s directStart=%s effectiveDirectStart=%s edgeMode=%s edgeSuppressed=%s",
        self.MOD_NAME,
        missionKey,
        Utils.getNoNil(assignment ~= nil and assignment.helperDiagStartAttemptCount or nil, 0),
        vehicleName,
        tostring(fieldId),
        tostring(isDirectStart),
        tostring(effectiveDirectStart),
        tostring(useFieldEdgeStart),
        tostring(edgeStartSuppressedForMission)
    )

    local function logStartBlocked(code, detail)
        local shouldLog = true
        if assignment ~= nil then
            local nextAt = Utils.getNoNil(assignment.nextHelperStartBlockedLogAtMs, 0)
            local lastCode = tostring(Utils.getNoNil(assignment.lastHelperStartBlockedCode, ""))
            if now < nextAt and lastCode == tostring(code) then
                shouldLog = false
            else
                assignment.nextHelperStartBlockedLogAtMs = now + 3000
                assignment.lastHelperStartBlockedCode = tostring(code)
            end
        end
        if not shouldLog then
            return
        end

        local canStart = vehicle.getCanStartFieldWork ~= nil and vehicle:getCanStartFieldWork() or false
        local isAiActive = vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() or false
        local speed = vehicle.getLastSpeed ~= nil and vehicle:getLastSpeed() or 0
        local aiImplCount = self:getCurrentAIImplementCount(vehicle)
        local attachedCount = 0
        if vehicle.getAttachedImplements ~= nil then
            local implements = vehicle:getAttachedImplements()
            if implements ~= nil then
                attachedCount = #implements
            end
        end
        local missingCount = 0
        if assignment ~= nil and assignment.mission ~= nil then
            local missingImplements = self:getUnattachedMissionImplements(assignment.mission)
            missingCount = #missingImplements
        end

        nfwLogHelperDiag(
            "[%s] HelperDiag START_BLOCKED: mission=%s code=%s vehicle=%s canStart=%s aiActive=%s aiImpl=%d attached=%d missing=%d speed=%.2f detail=%s",
            self.MOD_NAME,
            missionKey,
            tostring(code),
            vehicleName,
            tostring(canStart),
            tostring(isAiActive),
            aiImplCount,
            attachedCount,
            missingCount,
            speed,
            tostring(detail or "n/a")
        )
    end

    if vehicle.getIsSynchronized ~= nil and not vehicle:getIsSynchronized() then
        logStartBlocked("NOT_SYNCHRONIZED", "vehicle_not_synchronized")
        nfwLogInfo(
            "[%s] GIANTS AI Start verschoben: Fahrzeug noch nicht synchronisiert: mission=%s vehicle=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            vehicleName
        )
        return false
    end

    local forcedManualConnections = self:ensureManualAttachConnectionsForAssignment(assignment, vehicle)
    if forcedManualConnections > 0 then
        nfwLogAttachDebug(
            "[%s] ManualAttachCompat: pre-start refresh mission=%s vehicle=%s links=%d",
            self.MOD_NAME,
            missionKey,
            vehicleName,
            forcedManualConnections
        )
    end

    if vehicle.getCanStartFieldWork ~= nil and not vehicle:getCanStartFieldWork() then
        logStartBlocked("CANNOT_START_FIELDWORK", "vehicle_getCanStartFieldWork_false")
        return false
    end

    if self.headlandsFirstModeEnabled == true then
        self:enforceHeadlandsFirstForVehicle(vehicle)
    end

    self:releaseAttachmentLeadVehicleLock(assignment)

    local frontRaised = self:enforceRaisedFrontSupportImplements(assignment, true, vehicle)
    if not frontRaised then
        assignment.nextStartAfterAttachMs = math.max(Utils.getNoNil(assignment.nextStartAfterAttachMs, 0),
            (g_time or 0) + 1200)
        logStartBlocked("FRONT_NOT_RAISED", "front_support_not_raised")
        return false
    end

    local skipTransportPrepare = mission ~= nil and self:isSowMission(mission) and effectiveDirectStart
    if skipTransportPrepare then
        if assignment ~= nil then
            assignment.transportPrepareSinceMs = 0
            assignment.nextTransportPrepareLogAtMs = 0
            assignment.transportPrepareNextEnforceAtMs = 0
        end
        nfwLogHelperDiag(
            "[%s] HelperDiag START_TRANSPORT_SKIP: mission=%s vehicle=%s reason=SOW_DIRECT_START",
            self.MOD_NAME,
            missionKey,
            vehicleName
        )
    else
        if not self:ensureTransportStateBeforeAIStart(assignment, vehicle) then
            logStartBlocked("TRANSPORT_NOT_READY", "getIsAIReadyToDrive_false")
            return false
        end
    end

    if mission ~= nil and self:isSowMission(mission) then
        self:applySowAIImplementOrderOverride(assignment, vehicle)
    end

    if vehicle.getIsAIActive ~= nil and vehicle.stopCurrentAIJob ~= nil and vehicle:getIsAIActive() then
        local stopMessage = nil
        if type(AIMessageSuccessStoppedByUser) == "table" and AIMessageSuccessStoppedByUser.new ~= nil then
            stopMessage = AIMessageSuccessStoppedByUser.new()
        end
        pcall(vehicle.stopCurrentAIJob, vehicle, stopMessage)
        logStartBlocked("ALREADY_AI_ACTIVE", "stopped_existing_ai_before_start")
        nfwLogInfo(
            "[%s] GIANTS AI Start verschoben: Fahrzeug hatte bereits aktiven AI-Job: mission=%s vehicle=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            vehicleName
        )
        return false
    end

    if AIJobType == nil or AIJobType.FIELDWORK == nil then
        logStartBlocked("JOBTYPE_UNAVAILABLE", "AIJobType.FIELDWORK_nil")
        return false
    end

    if g_currentMission == nil or g_currentMission.aiJobTypeManager == nil then
        logStartBlocked("AI_MANAGER_UNAVAILABLE", "aiJobTypeManager_nil")
        return false
    end

    self:ensureDynamicHelperPoolCapacity()

    local availableHelpers = 0
    if g_helperManager ~= nil and g_helperManager.availableHelpers ~= nil then
        availableHelpers = #g_helperManager.availableHelpers
    end
    if availableHelpers <= 0 then
        if now >= Utils.getNoNil(assignment.nextNoHelperLogAtMs, 0) then
            assignment.nextNoHelperLogAtMs = now + 5000
            nfwLogInfo(
                "[%s] GIANTS AI Start verschoben: kein freier Helper verfuegbar: mission=%s vehicle=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                vehicleName
            )
        end
        logStartBlocked("NO_AVAILABLE_HELPER", "available_helpers_zero")
        return false
    end

    local job = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK)
    if job == nil then
        logStartBlocked("CREATE_JOB_FAILED", "aiJobTypeManager_createJob_returned_nil")
        return false
    end

    local fieldX, fieldZ = self:getMissionFieldPosition(mission)
    if fieldX == nil or fieldZ == nil then
        local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
        fieldX, _, fieldZ = getWorldTranslation(vehicle.rootNode)
        job.positionAngleParameter:setAngle(MathUtil.getYRotationFromDirection(dirX, dirZ))
    end
    local detectionX = fieldX
    local detectionZ = fieldZ
    local driveTargetX = detectionX
    local driveTargetZ = detectionZ
    local noFieldRetryIndex = 0
    if hadNoFieldStop then
        noFieldRetryIndex = math.max(1, Utils.getNoNil(assignment ~= nil and assignment.noFieldRetryIndex or nil, 1))
        local baseX = fieldX
        local baseZ = fieldZ
        local vx, _, vz = getWorldTranslation(vehicle.rootNode)
        if type(vx) == "number" and type(vz) == "number" then
            baseX = vx
            baseZ = vz
        end
        local retryOffsets = {
            { 0, 0 }, { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 },
            { 9, 9 }, { 9, -9 }, { -9, 9 }, { -9, -9 },
            { 12, 0 }, { -12, 0 }, { 0, 12 }, { 0, -12 }
        }
        local offsetEntry = retryOffsets[((noFieldRetryIndex - 1) % #retryOffsets) + 1]
        detectionX = baseX + offsetEntry[1]
        detectionZ = baseZ + offsetEntry[2]
        driveTargetX = detectionX
        driveTargetZ = detectionZ
        nfwLogHelperDiag(
            "[%s] HelperDiag START_NO_FIELD_RETRY: mission=%s retryIndex=%d baseVehicle=(%.1f/%.1f) baseField=(%.1f/%.1f) detect=(%.1f/%.1f)",
            self.MOD_NAME,
            missionKey,
            noFieldRetryIndex,
            baseX,
            baseZ,
            fieldX,
            fieldZ,
            detectionX,
            detectionZ
        )
    end

    if useFieldEdgeStart and not hadNoFieldStop then
        local aiRefNode = self:getAIDriveReferenceNode(vehicle)
        local vx, _, vz = getWorldTranslation(aiRefNode ~= nil and aiRefNode or vehicle.rootNode)
        local forwardX, _, forwardZ = localDirectionToWorld(aiRefNode ~= nil and aiRefNode or vehicle.rootNode, 0, 0, 1)
        local dynamicInset = NFW_EDGE_TARGET_INSET_M
        local frontDistance = self:getAIAgentFrontDistanceFromReference(vehicle)
        if type(frontDistance) == "number" then
            dynamicInset = math.max(0.5, frontDistance + NFW_EDGE_FRONT_CLEARANCE_M)
        end
        local edgeX, edgeZ, edgeReason = self:getMissionFieldEdgeStartPosition(
            mission,
            vx,
            vz,
            dynamicInset,
            forwardX,
            forwardZ
        )
        if type(edgeX) == "number" and type(edgeZ) == "number" then
            driveTargetX = edgeX
            driveTargetZ = edgeZ
            detectionX = edgeX
            detectionZ = edgeZ

            local edgeDetectX, edgeDetectZ = self:getMissionFieldEdgeStartPosition(
                mission,
                vx,
                vz,
                NFW_EDGE_TARGET_INSET_M,
                forwardX,
                forwardZ
            )
            if type(edgeDetectX) == "number" and type(edgeDetectZ) == "number" then
                detectionX = edgeDetectX
                detectionZ = edgeDetectZ
            end

            if assignment ~= nil then
                assignment.lastStartEdgeTargetX = driveTargetX
                assignment.lastStartEdgeTargetZ = driveTargetZ
            end

            local toTargetX = driveTargetX - vx
            local toTargetZ = driveTargetZ - vz
            local targetAheadDot = toTargetX * forwardX + toTargetZ * forwardZ
            if targetAheadDot <= 0 then
                effectiveDirectStart = true
                if assignment ~= nil then
                    assignment.lastStartUsedEdge = false
                    assignment.disableEdgeStartForMission = true
                end
                nfwLogHelperDiag(
                    "[%s] HelperDiag START_EDGE_TARGET_BEHIND: mission=%s vehicle=%s dot=%.2f action=directStart+disableEdgeForMission",
                    self.MOD_NAME,
                    missionKey,
                    vehicleName,
                    targetAheadDot
                )
            end

            nfwLogHelperDiag(
                "[%s] HelperDiag START_EDGE_TARGET: mission=%s vehicle=%s drive=(%.1f/%.1f) detect=(%.1f/%.1f) mode=FIELD_EDGE source=%s inset=%.2f frontDist=%s",
                self.MOD_NAME,
                missionKey,
                vehicleName,
                driveTargetX,
                driveTargetZ,
                detectionX,
                detectionZ,
                tostring(edgeReason),
                dynamicInset,
                type(frontDistance) == "number" and string.format("%.2f", frontDistance) or "n/a"
            )
        else
            nfwLogHelperDiag(
                "[%s] HelperDiag START_EDGE_TARGET_FALLBACK: mission=%s vehicle=%s reason=%s",
                self.MOD_NAME,
                missionKey,
                vehicleName,
                tostring(edgeReason)
            )
        end
    elseif self.fieldEdgeStartModeEnabled == true and edgeStartSuppressedForMission then
        nfwLogHelperDiag(
            "[%s] HelperDiag START_EDGE_TARGET_BYPASSED: mission=%s vehicle=%s reason=EDGE_SUPPRESSED_FOR_MISSION",
            self.MOD_NAME,
            missionKey,
            vehicleName
        )
    end

    if mission ~= nil and self:isSowMission(mission) then
        local fieldCourseProbe = self:getFieldCourseStartProbe(vehicle, mission.farmId)
        local blockStart = fieldCourseProbe.available
            and fieldCourseProbe.ok
            and (fieldCourseProbe.notOwned == true or not fieldCourseProbe.hasClosest)
        if blockStart then
            local switchedEdgeToDirect = false
            if useFieldEdgeStart and assignment ~= nil then
                assignment.disableEdgeStartForMission = true
                assignment.lastStartUsedEdge = false
                assignment.lastStartEdgeTargetX = nil
                assignment.lastStartEdgeTargetZ = nil
                if isSowDirectStartAllowed() then
                    effectiveDirectStart = true
                    switchedEdgeToDirect = true
                    if type(fieldX) == "number" and type(fieldZ) == "number" then
                        driveTargetX = fieldX
                        driveTargetZ = fieldZ
                        detectionX = fieldX
                        detectionZ = fieldZ
                    end
                    nfwLogHelperDiag(
                        "[%s] HelperDiag START_EDGE_DISABLED: mission=%s vehicle=%s reason=SOW_FIELDCOURSE_INVALID action=forceDirectStart+disableEdgeForMission",
                        self.MOD_NAME,
                        missionKey,
                        vehicleName
                    )
                end
            end

            local detail = string.format(
                "closest=(%s/%s) notOwned=%s settings=%s detect=(%.1f/%.1f)",
                type(fieldCourseProbe.closestX) == "number" and string.format("%.1f", fieldCourseProbe.closestX) or
                tostring(fieldCourseProbe.closestX),
                type(fieldCourseProbe.closestZ) == "number" and string.format("%.1f", fieldCourseProbe.closestZ) or
                tostring(fieldCourseProbe.closestZ),
                tostring(fieldCourseProbe.notOwned),
                tostring(fieldCourseProbe.settingsAvailable),
                tonumber(detectionX) or 0,
                tonumber(detectionZ) or 0
            )

            nfwLogHelperDiag(
                "[%s] HelperDiag START_PRECHECK_WARN: mission=%s vehicle=%s reason=SOW_FIELDCOURSE_INVALID %s",
                self.MOD_NAME,
                missionKey,
                vehicleName,
                detail
            )

            if effectiveDirectStart then
                local keepDirectStartForRecovery = assignment ~= nil
                    and (
                        assignment.keepDirectStartForNextStart == true
                        or tostring(assignment.forceRecoveryReason or "") == "SOW_LOW_PROBE"
                    )
                if not switchedEdgeToDirect
                    and not edgeStartSuppressedForMission
                    and not hadNoFieldStop
                    and not keepDirectStartForRecovery then
                    effectiveDirectStart = false
                    nfwLogHelperDiag(
                        "[%s] HelperDiag START_DIRECT_OVERRIDE: mission=%s vehicle=%s reason=SOW_FIELDCOURSE_INVALID+PREFER_DETECT -> directStart=false",
                        self.MOD_NAME,
                        missionKey,
                        vehicleName
                    )
                elseif not isSowDirectStartAllowed() then
                    effectiveDirectStart = false
                    nfwLogHelperDiag(
                        "[%s] HelperDiag START_DIRECT_OVERRIDE: mission=%s vehicle=%s reason=SOW_FIELDCOURSE_INVALID+OUTSIDE_FIELD -> directStart=false",
                        self.MOD_NAME,
                        missionKey,
                        vehicleName
                    )
                elseif switchedEdgeToDirect then
                    nfwLogHelperDiag(
                        "[%s] HelperDiag START_DIRECT_KEEP: mission=%s vehicle=%s reason=SOW_FIELDCOURSE_INVALID+EDGE_DISABLED",
                        self.MOD_NAME,
                        missionKey,
                        vehicleName
                    )
                else
                    nfwLogHelperDiag(
                        "[%s] HelperDiag START_DIRECT_KEEP: mission=%s vehicle=%s reason=SOW_FIELDCOURSE_INVALID+ON_OR_NEAR_FIELD",
                        self.MOD_NAME,
                        missionKey,
                        vehicleName
                    )
                end
            end
        end
    end

    if job.applyCurrentState ~= nil then
        job:applyCurrentState(vehicle, g_currentMission, mission.farmId, effectiveDirectStart)
    end
    job.vehicleParameter:setVehicle(vehicle)
    if effectiveDirectStart then
        local startX = nil
        local startZ = nil
        if mission ~= nil and self:isSowMission(mission) then
            startX = fieldX
            startZ = fieldZ
        end
        if type(startX) ~= "number" or type(startZ) ~= "number" then
            local vx, _, vz = getWorldTranslation(vehicle.rootNode)
            startX = vx
            startZ = vz
        end
        job.positionAngleParameter:setPosition(startX, startZ)
    else
        job.positionAngleParameter:setPosition(driveTargetX, driveTargetZ)
    end

    local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
    job.positionAngleParameter:setAngle(MathUtil.getYRotationFromDirection(dirX, dirZ))
    job:setValues()

    local targetX, targetZ = job.positionAngleParameter:getPosition()
    self:logHelperStartFieldDiagnostics(assignment, vehicle, targetX, targetZ, effectiveDirectStart)

    if job.driveToTask == nil
        or job.driveToTask.vehicle == nil
        or job.fieldWorkTask == nil
        or job.fieldWorkTask.vehicle == nil then
        logStartBlocked("JOB_TASKS_NOT_READY", "driveToTask_or_fieldWorkTask_vehicle_nil")
        nfwLogInfo(
            "[%s] GIANTS AI Start verschoben: Job-Fahrzeug noch nicht bereit: mission=%s vehicle=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            vehicleName
        )
        return false
    end

    job.getPricePerMs = function()
        return 0
    end

    local success, errorMessage = job:validate(mission.farmId)
    if not success then
        logStartBlocked("JOB_VALIDATE_FAILED", tostring(errorMessage))
        nfwLogInfo(
            "[%s] GIANTS AI Start fehlgeschlagen: mission=%s vehicle=%s reason=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            vehicleName,
            tostring(errorMessage)
        )
        return false
    end

    self:registerPendingFieldDetectionOverride(assignment, vehicle, detectionX, detectionZ)
    g_currentMission.aiSystem:startJob(job, mission.farmId)
    local aiActiveAfterStart = vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() or false
    local aiImplAfterStart = self:getCurrentAIImplementCount(vehicle)
    nfwLogHelperDiag(
        "[%s] HelperDiag START_JOB_SENT: mission=%s vehicle=%s aiActiveNow=%s aiImpl=%d farmId=%s",
        self.MOD_NAME,
        missionKey,
        vehicleName,
        tostring(aiActiveAfterStart),
        aiImplAfterStart,
        tostring(mission.farmId)
    )

    assignment.aiStarted = true
    assignment.aiMode = "giants"
    assignment.vehicle = vehicle
    assignment.giantsJob = job
    self:assignLocalizedHelperNameToAssignment(assignment, vehicle)
    assignment.aiStartTimeMs = now
    assignment.aiInactiveSinceMs = nil
    assignment.aiFarSinceMs = nil
    assignment.forceDirectStart = false
    assignment.forceRecoveryReposition = false
    assignment.forceRecoveryReason = nil
    assignment.noMovementSinceMs = nil
    assignment.lastMovementCheckX = nil
    assignment.lastMovementCheckZ = nil
    assignment.stuckCheckAnchorX = nil
    assignment.stuckCheckAnchorZ = nil
    assignment.stuckCheckAnchorAtMs = 0
    if vehicle.rootNode ~= nil then
        local sx, _, sz = getWorldTranslation(vehicle.rootNode)
        assignment.lastMovementCheckX = sx
        assignment.lastMovementCheckZ = sz
        assignment.stuckCheckAnchorX = sx
        assignment.stuckCheckAnchorZ = sz
        assignment.stuckCheckAnchorAtMs = now
    end
    assignment.nextStartAfterAttachMs = 0
    assignment.nextNoHelperLogAtMs = 0
    assignment.nextResourceTopupAtMs = now + 4000
    self:refreshCompletionStallTracking(assignment, self:getMissionCompletionPercent(assignment.mission), now)
    assignment.harvestCanStartBlockedSinceMs = 0
    assignment.nextHarvestUnblockTryAtMs = 0
    assignment.nextHarvestDeepDiagAtMs = 0
    assignment.nextCombineDriveDiagAtMs = 0
    assignment.nextCombineDriveBypassLogAtMs = 0
    assignment.nextFieldCourseDriveDiagAtMs = 0
    assignment.nextFrontLiftEnforceAtMs = 0
    assignment.transportPrepareSinceMs = 0
    assignment.nextTransportPrepareLogAtMs = 0
    assignment.transportPrepareNextEnforceAtMs = 0
    assignment.keepDirectStartForNextStart = nil
    assignment.helperDiagImmediateStopLogged = false
    assignment.helperDiagLastAiActive = aiActiveAfterStart
    assignment.helperDiagLastAiActiveChangeMs = now

    nfwLogInfo(
        "[%s] Nachbar startet Auftrag mit GIANTS AI: mission=%s type=%s field=%s vehicle=%s farmId=%s directStart=%s",
        self.MOD_NAME,
        tostring(assignment.key),
        self:getMissionTypeName(mission),
        tostring(fieldId),
        vehicleName,
        tostring(mission.farmId),
        tostring(effectiveDirectStart)
    )

    return true
end

function NeighborFieldWorkers:tryStartPendingAssignment(assignment)
    if self:isMissionExiting() then
        return
    end

    local mission = assignment.mission
    local now = g_time or 0
    self:tryFinalizeGiantsPreparingStatusIfStuck(mission, assignment, "PENDING_START")
    local function logPendingStartBlocker(code, detail, vehicleForDiag)
        if not NFW_MISSION_DEBUG_LOG_ENABLED then
            return
        end

        local currentNow = g_time or now
        local codeText = tostring(code or "UNKNOWN")
        local nextAt = Utils.getNoNil(assignment.nextPendingStartMissionDebugAtMs, 0)
        local lastCode = tostring(Utils.getNoNil(assignment.lastPendingStartMissionDebugCode, ""))
        if currentNow < nextAt and lastCode == codeText then
            return
        end
        assignment.nextPendingStartMissionDebugAtMs = currentNow + 2000
        assignment.lastPendingStartMissionDebugCode = codeText

        local spawnedVehicles, vehicleCount, expectedVehicleCount, pendingLoads, failedToLoadVehicles, loadingComplete =
            self:getMissionVehicleLoadStats(mission)
        local missingImplements = mission ~= nil and self:getUnattachedMissionImplements(mission) or {}
        local preparingForMs = -1
        if Utils.getNoNil(assignment.preparingSinceMs, 0) > 0 then
            preparingForMs = math.max(0, currentNow - assignment.preparingSinceMs)
        end

        local diagVehicle = vehicleForDiag or assignment.vehicle
        local vehicleName = "n/a"
        local canStart = "n/a"
        local aiImplCount = -1
        local attachedCount = -1
        local aiActive = "n/a"
        if diagVehicle ~= nil and not diagVehicle.isDeleted then
            if diagVehicle.getName ~= nil then
                vehicleName = tostring(diagVehicle:getName())
            end
            if diagVehicle.getCanStartFieldWork ~= nil then
                canStart = tostring(diagVehicle:getCanStartFieldWork())
            end
            aiImplCount = self:getCurrentAIImplementCount(diagVehicle)
            if diagVehicle.getAttachedImplements ~= nil then
                local attachedImplements = diagVehicle:getAttachedImplements()
                attachedCount = attachedImplements ~= nil and #attachedImplements or 0
            end
            if diagVehicle.getIsAIActive ~= nil then
                aiActive = tostring(diagVehicle:getIsAIActive())
            end
        end

        nfwLogMissionDebug(
            "[%s] PENDING_START_BLOCKER: mission=%s status=%s code=%s detail=%s preparingForMs=%s spawned=%s vehicles=%d expected=%d pendingLoads=%d loadingComplete=%s failedLoad=%s missing=%d aiStarted=%s sprayerPhase=%s nextStartDelayMs=%s vehicle=%s canStart=%s aiImpl=%d attached=%d aiActive=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(self:missionStatusToText(mission ~= nil and mission.status or nil)),
            codeText,
            tostring(detail or "n/a"),
            preparingForMs >= 0 and tostring(preparingForMs) or "n/a",
            tostring(spawnedVehicles),
            vehicleCount,
            expectedVehicleCount,
            pendingLoads,
            tostring(loadingComplete),
            tostring(failedToLoadVehicles),
            #missingImplements,
            tostring(assignment.aiStarted == true),
            tostring(assignment.sprayerAttachPhase),
            tostring(Utils.getNoNil(assignment.nextStartAfterAttachMs, 0) - currentNow),
            vehicleName,
            canStart,
            aiImplCount,
            attachedCount,
            aiActive
        )
    end

    if self:isSowMission(mission) and self:getMissionCompletionPercent(mission) <= 0 then
        self:forcePrepareSowMissionFieldIfNeeded(mission, "RUNNING_RECOVERY", "PENDING_START", false)
    end

    if self:adoptExistingMissionVehicleAI(assignment) then
        logPendingStartBlocker("ADOPT_EXISTING_AI", "mission_vehicle_ai_adopted")
        return
    end

    if self:stopUnexpectedMissionVehicleAI(assignment, "PENDING_START") then
        assignment.nextStartAfterAttachMs = math.max(Utils.getNoNil(assignment.nextStartAfterAttachMs, 0),
            now + NFW_ATTACH_STEP_WAIT_MS)
        logPendingStartBlocker("UNEXPECTED_AI_STOPPED", "stopped_unexpected_mission_vehicle_ai")
        return
    end

    self:prepareMissionVehicles(assignment)
    self:filterHarvestMissionVehiclesToLoad(mission)
    self:filterStoneMissionVehiclesToLoad(mission)
    self:filterCultivateMissionVehiclesToLoad(mission)
    self:filterPlowMissionVehiclesToLoad(mission)
    self:filterMowMissionVehiclesToLoad(mission)
    self:filterHoeMissionVehiclesToLoad(mission)
    self:filterWeedMissionVehiclesToLoad(mission)
    self:filterSprayMissionVehiclesToLoad(mission)
    self:filterSowMissionVehiclesToLoad(mission)
    self:filterTurnMissionVehiclesToLoad(mission)

    local spawnedVehicles, vehicleCount, expectedVehicleCount, pendingLoads, failedToLoadVehicles, loadingComplete =
        self:getMissionVehicleLoadStats(mission)

    if self:shouldUseTransparentSpawnModeForMission(mission) then
        if mission ~= nil and type(mission.vehicles) == "table" and #mission.vehicles > 0 then
            self:hideMissionVehiclesUntilHelperStart(mission, mission.vehicles)
        end
        self:enforceHiddenMissionVehicleState(mission)
    end

    if failedToLoadVehicles then
        logPendingStartBlocker(
            "FAILED_TO_LOAD_ABORT",
            string.format("spawned=%s vehicles=%d expected=%d pendingLoads=%d", tostring(spawnedVehicles), vehicleCount,
                expectedVehicleCount, pendingLoads)
        )
        nfwLogInfo(
            "[%s] Auftrag abgebrochen: Missionsfahrzeuge konnten nicht geladen werden: mission=%s status=%s spawnedVehicles=%s numVehicles=%d expectedVehicles=%d pendingLoads=%d",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(mission ~= nil and mission.status or "nil"),
            tostring(spawnedVehicles),
            vehicleCount,
            expectedVehicleCount,
            pendingLoads
        )

        if mission ~= nil and mission.status ~= MissionStatus.DISMISSED then
            pcall(g_missionManager.cancelMission, g_missionManager, mission)
            pcall(g_missionManager.dismissMission, g_missionManager, mission)
        end
        self:removeAssignment(assignment)
        self.scanTimerMs = 0
        return
    end

    -- If borrowed mission vehicles failed to load, do not get stuck forever.
    -- Reset this mission and let the system try another suitable contract.
    if (not spawnedVehicles and vehicleCount == 0 and pendingLoads == 0) then
        if assignment.noVehicleSinceMs == nil then
            assignment.noVehicleSinceMs = now
            logPendingStartBlocker("WAIT_NO_VEHICLES", "noVehicleSinceMs_initialized")
        elseif now >= assignment.noVehicleSinceMs + 25000 then
            logPendingStartBlocker(
                "NO_VEHICLES_TIMEOUT_ABORT",
                string.format("waitedMs=%d", math.max(0, now - assignment.noVehicleSinceMs))
            )
            nfwLogInfo(
                "[%s] Auftrag ohne Fahrzeuge abgebrochen: mission=%s status=%s spawnedVehicles=%s numVehicles=%d pendingLoads=%d",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(mission ~= nil and mission.status or "nil"),
                tostring(spawnedVehicles),
                vehicleCount,
                pendingLoads
            )

            if mission ~= nil and mission.status ~= MissionStatus.DISMISSED then
                pcall(g_missionManager.cancelMission, g_missionManager, mission)
                pcall(g_missionManager.dismissMission, g_missionManager, mission)
            end
            self:removeAssignment(assignment)
            self.scanTimerMs = 0
            return
        else
            logPendingStartBlocker(
                "WAIT_NO_VEHICLES",
                string.format("waitedMs=%d", math.max(0, now - assignment.noVehicleSinceMs))
            )
        end
    else
        assignment.noVehicleSinceMs = nil
    end

    if spawnedVehicles and vehicleCount > 0 then
        self:learnVehicleInfoMetaFromMissionVehicles(mission)
        self:pruneHarvestMissionSupportVehicles(assignment)
        self:pruneStoneMissionSupportVehicles(assignment)
        self:pruneCultivateMissionSupportVehicles(assignment)
        self:prunePlowMissionSupportVehicles(assignment)
        self:pruneSowMissionSupportVehicles(assignment)
        self:applyHarvestNoTrailerWorkaround(assignment)
        local lengthRelayoutForce = loadingComplete == true
            and mission ~= nil
            and mission.nfwLengthFallbackUsed == true
            and mission.nfwLengthResolvedRelayoutDone ~= true
        local forceRelocate = assignment.forceRecoveryReposition == true or lengthRelayoutForce
        if forceRelocate and not lengthRelayoutForce and self:shouldSkipForcedRecoveryRepositionOnLoad(assignment) then
            forceRelocate = false
            assignment.forceRecoveryReposition = false
            assignment.forceRecoveryReason = nil
            nfwLogHelperDiag(
                "[%s] HelperDiag RECOVERY_RELOCATE_SKIPPED_ON_LOAD: mission=%s reason=already_near_field_and_attached",
                self.MOD_NAME,
                tostring(assignment.key)
            )
        end
        local skipRelocate = assignment.suppressRelocateDuringSprayerAttach == true and not forceRelocate
        if not skipRelocate then
            self:relocateMissionVehiclesToField(assignment, forceRelocate)
        end
        if lengthRelayoutForce and mission ~= nil then
            mission.nfwLengthResolvedRelayoutDone = true
            mission.nfwLengthFallbackUsed = nil
            nfwLogHelperDiag(
                "[%s] HelperDiag LENGTH_RELAYOUT_APPLIED: mission=%s mode=postSpawnVehicleLength",
                self.MOD_NAME,
                tostring(assignment.key)
            )
        end
        if forceRelocate then
            assignment.forceRecoveryReposition = false
            assignment.forceRecoveryReason = nil
            assignment.suppressRelocateDuringSprayerAttach = false
        end
        self:tryAutoAttachMissionImplements(assignment)
        self:prepareMissionVehicleConsumables(assignment)
        self:enforceRaisedFrontSupportImplements(assignment)
    end

    spawnedVehicles, vehicleCount, expectedVehicleCount, pendingLoads, failedToLoadVehicles, loadingComplete =
        self:getMissionVehicleLoadStats(mission)
    if spawnedVehicles and not loadingComplete then
        local now = g_time or 0
        if now >= assignment.nextPendingLoadsLogAtMs then
            assignment.nextPendingLoadsLogAtMs = now + 5000
            nfwLogInfo(
                "[%s] Warte auf Missionsfahrzeuge: mission=%s numVehicles=%d expectedVehicles=%d pendingLoads=%d",
                self.MOD_NAME,
                tostring(assignment.key),
                vehicleCount,
                expectedVehicleCount,
                pendingLoads
            )
        end
        logPendingStartBlocker(
            "WAIT_PENDING_LOADS",
            string.format("vehicles=%d expected=%d pendingLoads=%d", vehicleCount, expectedVehicleCount, pendingLoads)
        )
        return
    end

    local missingImplements = self:getUnattachedMissionImplements(mission)
    if #missingImplements > 0 then
        assignment.lastObservedAiImplementCount = nil
        assignment.aiImplementCountStableSinceMs = 0
        local now = g_time or 0
        if now >= assignment.nextMissingAttachLogAtMs then
            assignment.nextMissingAttachLogAtMs = now + 5000
            nfwLogInfo(
                "[%s] Warte auf vollstaendiges Ankuppeln: mission=%s missing=%d implements=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                #missingImplements,
                table.concat(missingImplements, ", ")
            )
        end
        logPendingStartBlocker(
            "WAIT_ATTACH_MISSING",
            string.format("missing=%d implements=%s", #missingImplements, table.concat(missingImplements, ", "))
        )
        return
    end

    if assignment.sprayerAttachPhase ~= nil then
        assignment.lastObservedAiImplementCount = nil
        assignment.aiImplementCountStableSinceMs = 0
        if now >= assignment.nextMissingAttachLogAtMs then
            assignment.nextMissingAttachLogAtMs = now + 5000
            nfwLogAttachDebug(
                "[%s] Warte auf Attach-Sequenz: mission=%s phase=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(assignment.sprayerAttachPhase)
            )
        end
        logPendingStartBlocker(
            "WAIT_ATTACH_PHASE",
            string.format("phase=%s", tostring(assignment.sprayerAttachPhase))
        )
        return
    end

    local vehicle = self:findMissionWorkVehicle(assignment)
    if vehicle == nil then
        assignment.lastObservedAiImplementCount = nil
        assignment.aiImplementCountStableSinceMs = 0
        self:logMissionVehicleStates(assignment)
        local numVehicles = (mission ~= nil and mission.vehicles ~= nil) and #mission.vehicles or 0
        local numPendingLoads = (mission ~= nil and mission.pendingVehicleLoadingData ~= nil) and
            #mission.pendingVehicleLoadingData or 0
        if now >= assignment.nextNoVehicleLogAtMs then
            assignment.nextNoVehicleLogAtMs = now + 15000
            local status = mission ~= nil and tostring(mission.status) or "nil"
            local spawnedVehiclesText = mission ~= nil and tostring(mission.spawnedVehicles) or "nil"
            local failedLoad = mission ~= nil and mission.failedToLoadVehicles == true
            nfwLogInfo(
                "[%s] Warte auf geeignetes Arbeitsfahrzeug: mission=%s status=%s spawnedVehicles=%s numVehicles=%d pendingLoads=%d failedLoad=%s",
                self.MOD_NAME,
                tostring(assignment.key),
                status,
                spawnedVehiclesText,
                numVehicles,
                numPendingLoads,
                tostring(failedLoad)
            )
        end
        logPendingStartBlocker(
            "NO_WORK_VEHICLE",
            string.format("status=%s spawned=%s vehicles=%d pendingLoads=%d", tostring(mission ~= nil and mission.status or "nil"),
                tostring(mission ~= nil and mission.spawnedVehicles or nil), numVehicles, numPendingLoads)
        )
        return
    end

    assignment.vehicle = vehicle
    local deferSowEnforce = self:shouldDeferSowOperationalStateBeforeStart(assignment, mission)
    if not deferSowEnforce then
        self:enforceSowImplementOperationalState(assignment, vehicle, true)
    elseif now >= Utils.getNoNil(assignment.nextSowEdgeDeferLogAtMs, 0) then
        assignment.nextSowEdgeDeferLogAtMs = now + 3000
        nfwLogHelperDiag(
            "[%s] HelperDiag SOW_ENFORCE_DEFERRED: mission=%s reason=WAIT_FOR_EDGE_START vehicle=%s",
            self.MOD_NAME,
            tostring(assignment.key),
            tostring(vehicle.getName ~= nil and vehicle:getName() or "unknown")
        )
        logPendingStartBlocker("SOW_ENFORCE_DEFERRED", "WAIT_FOR_EDGE_START", vehicle)
    end

    if self:isHarvestMission(mission) then
        self:applyHarvestNoTrailerWorkaround(assignment)
    end

    if vehicle.getCanStartFieldWork ~= nil and not vehicle:getCanStartFieldWork() then
        local stillBlocked = vehicle.getCanStartFieldWork ~= nil and not vehicle:getCanStartFieldWork()
        if stillBlocked then
            if assignment.cannotStartVehicle ~= vehicle then
                assignment.cannotStartVehicle = vehicle
                assignment.cannotStartSinceMs = now
            end

            local blockedForMs = math.max(0, now - Utils.getNoNil(assignment.cannotStartSinceMs, now))
            local shouldAutoComplete, autoReason = self:shouldAutoCompleteStartBlockedAssignment(assignment, vehicle,
                blockedForMs)
            if shouldAutoComplete then
                nfwLogHelperDiag(
                    "[%s] HelperDiag START_BLOCKED_AUTOCOMPLETE: mission=%s vehicle=%s blockedForMs=%d reason=%s",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    tostring(vehicle:getName()),
                    blockedForMs,
                    tostring(autoReason)
                )
                logPendingStartBlocker(
                    "START_BLOCKED_AUTOCOMPLETE",
                    string.format("blockedForMs=%d reason=%s", blockedForMs, tostring(autoReason)),
                    vehicle
                )
                self:queueAssignmentAutoCompletion(assignment, autoReason)
                return
            end

            if blockedForMs >= NFW_PENDING_START_BLOCKED_TIMEOUT_MS then
                logPendingStartBlocker(
                    "START_BLOCKED_TIMEOUT_ABORT",
                    string.format("blockedForMs=%d timeoutMs=%d", blockedForMs, NFW_PENDING_START_BLOCKED_TIMEOUT_MS),
                    vehicle
                )
                nfwLogInfo(
                    "[%s] Pending-Start Timeout: Auftrag abgebrochen: mission=%s vehicle=%s blockedForMs=%d timeoutMs=%d",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    tostring(vehicle:getName()),
                    blockedForMs,
                    NFW_PENDING_START_BLOCKED_TIMEOUT_MS
                )

                if mission ~= nil and mission.status ~= MissionStatus.DISMISSED then
                    pcall(g_missionManager.cancelMission, g_missionManager, mission)
                    pcall(g_missionManager.dismissMission, g_missionManager, mission)
                end

                self:removeAssignment(assignment)
                self.scanTimerMs = 0
                self:setNeighborFarmBalance(1, "PENDING_START_TIMEOUT")
                return
            end

            assignment.lastObservedAiImplementCount = nil
            assignment.aiImplementCountStableSinceMs = 0
            if now >= assignment.nextVehicleNotReadyLogAtMs then
                assignment.nextVehicleNotReadyLogAtMs = now + 5000
                nfwLogInfo(
                    "[%s] Warte auf fahrbereites Arbeitsfahrzeug: mission=%s vehicle=%s blockedForMs=%d",
                    self.MOD_NAME,
                    tostring(assignment.key),
                    tostring(vehicle:getName()),
                    blockedForMs
                )
            end
            logPendingStartBlocker(
                "WAIT_VEHICLE_CAN_START",
                string.format("blockedForMs=%d", blockedForMs),
                vehicle
            )
            return
        end
    end
    assignment.cannotStartVehicle = nil
    assignment.cannotStartSinceMs = nil

    local aiImplementCount = self:getCurrentAIImplementCount(vehicle)
    local attachedImplementsCount = 0
    if vehicle.getAttachedImplements ~= nil then
        local implements = vehicle:getAttachedImplements()
        if implements ~= nil then
            attachedImplementsCount = #implements
        end
    end

    if assignment.lastObservedAiImplementCount ~= aiImplementCount then
        assignment.lastObservedAiImplementCount = aiImplementCount
        assignment.aiImplementCountStableSinceMs = now
    end

    local stableSince = Utils.getNoNil(assignment.aiImplementCountStableSinceMs, now)
    if attachedImplementsCount > 0 and aiImplementCount == 0 then
        if now >= assignment.nextAIImplementStabilityLogAtMs then
            assignment.nextAIImplementStabilityLogAtMs = now + 5000
            nfwLogInfo(
                "[%s] Warte auf AI-Implement-Erkennung: mission=%s vehicle=%s aiImpl=%d attached=%d",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(vehicle:getName()),
                aiImplementCount,
                attachedImplementsCount
            )
        end
        logPendingStartBlocker(
            "WAIT_AI_IMPLEMENT_DISCOVERY",
            string.format("aiImpl=%d attached=%d", aiImplementCount, attachedImplementsCount),
            vehicle
        )
        return
    end

    if now < stableSince + 2000 then
        if now >= assignment.nextAIImplementStabilityLogAtMs then
            assignment.nextAIImplementStabilityLogAtMs = now + 5000
            nfwLogInfo(
                "[%s] Warte auf stabile AI-Implement-Anzahl: mission=%s vehicle=%s aiImpl=%d stableForMs=%d",
                self.MOD_NAME,
                tostring(assignment.key),
                tostring(vehicle:getName()),
                aiImplementCount,
                math.max(0, math.floor(now - stableSince))
            )
        end
        logPendingStartBlocker(
            "WAIT_AI_IMPLEMENT_STABILITY",
            string.format("aiImpl=%d stableForMs=%d", aiImplementCount, math.max(0, math.floor(now - stableSince))),
            vehicle
        )
        return
    end

    if assignment.nextStartAfterAttachMs ~= nil and now < assignment.nextStartAfterAttachMs then
        if now >= assignment.nextStartDelayLogAtMs then
            assignment.nextStartDelayLogAtMs = now + 3000
            nfwLogInfo(
                "[%s] Warte kurz nach Auto-Attach vor AI-Start: mission=%s remainingMs=%d",
                self.MOD_NAME,
                tostring(assignment.key),
                math.max(0, math.floor(assignment.nextStartAfterAttachMs - now))
            )
        end
        logPendingStartBlocker(
            "WAIT_START_DELAY",
            string.format("remainingMs=%d", math.max(0, math.floor(assignment.nextStartAfterAttachMs - now))),
            vehicle
        )
        return
    end

    if self:isVehicleUpsideDown(vehicle) then
        logPendingStartBlocker("PRE_START_UPSIDE_DOWN", "respawnAssignmentVehiclesAtStartPosition", vehicle)
        self:respawnAssignmentVehiclesAtStartPosition(assignment, "PRE_START_UPSIDE_DOWN")
        return
    end

    if self:shouldUseTransparentSpawnModeForMission(mission) then
        self:revealHiddenMissionVehicles(mission, "PRE_HELPER_START")
    end

    if not self:startGiantsFieldWorkJob(assignment, vehicle) then
        assignment.nextStartAfterAttachMs = math.max(Utils.getNoNil(assignment.nextStartAfterAttachMs, 0),
            now + NFW_ATTACH_STEP_WAIT_MS)
        logPendingStartBlocker("START_GIANTS_FAILED_RETRY", "startGiantsFieldWorkJob=false", vehicle)
    end
end

NeighborFieldWorkers:tryInstallSingleplayerMergeHook()

addModEventListener(NeighborFieldWorkers)
