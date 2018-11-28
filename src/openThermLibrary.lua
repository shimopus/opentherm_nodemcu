--
-- OpenTherm Communication Library
-- By: Sergey Babinskiy
-- Email: shimopus@gmail.com
-- Date: November 25th, 2018
--

local ENVIRONMENT = "DEV";

local function log(...)
    if (ENVIRONMENT ~= "PROD") then
        print(...)
    end
end

local ot = {}

ot.OpenThermResponseStatus = {
    NONE = 10000,
    SUCCESS = 10001,
    INVALID = 10002,
    TIMEOUT = 10003
}

ot.OpenThermRequestType = {
    READ = 0,
    WRITE = 1,
    INVALID = 2
}

ot.OpenThermStatus = enum({
    NOT_INITIALIZED = 20000,
    READY = 20001,
    DELAY = 20002,
    REQUEST_SENDING = 20003,
    RESPONSE_WAITING = 20004,
    RESPONSE_START_BIT = 20005,
    RESPONSE_RECEIVING = 20006,
    RESPONSE_READY = 20007,
    RESPONSE_INVALID = 20008
})

ot.OpenThermMessageID = {
    Status = 0, -- flag8 / flag8  Master and Slave Status flags. 
    TSet = 1, -- f8.8  Control setpoint  ie CH  water temperature setpoint (°C)
    MConfigMMemberIDcode = 2, -- flag8 / u8  Master Configuration Flags /  Master MemberID Code 
    SConfigSMemberIDcode = 3, -- flag8 / u8  Slave Configuration Flags /  Slave MemberID Code 
    Command = 4, -- u8 / u8  Remote Command 
    ASFflags = 5, -- / OEM-fault-code  flag8 / u8  Application-specific fault flags and OEM fault code 
    RBPflags = 6, -- flag8 / flag8  Remote boiler parameter transfer-enable & read/write flags 
    CoolingControl = 7, -- f8.8  Cooling control signal (%) 
    TsetCH2 = 8, -- f8.8  Control setpoint for 2e CH circuit (°C)
    TrOverride = 9, -- f8.8  Remote override room setpoint 
    TSP = 10, -- u8 / u8  Number of Transparent-Slave-Parameters supported by slave 
    TSPindexTSPvalue = 11, -- u8 / u8  Index number / Value of referred-to transparent slave parameter. 
    FHBsize = 12, -- u8 / u8  Size of Fault-History-Buffer supported by slave 
    FHBindexFHBvalue = 13, -- u8 / u8  Index number / Value of referred-to fault-history buffer entry. 
    MaxRelModLevelSetting = 14, -- f8.8  Maximum relative modulation level setting (%) 
    MaxCapacityMinModLevel = 15, -- u8 / u8  Maximum boiler capacity (kW) / Minimum boiler modulation level(%) 
    TrSet = 16, -- f8.8  Room Setpoint (°C)
    RelModLevel = 17, -- f8.8  Relative Modulation Level (%) 
    CHPressure = 18, -- f8.8  Water pressure in CH circuit  (bar) 
    DHWFlowRate = 19, -- f8.8  Water flow rate in DHW circuit. (litres/minute) 
    DayTime = 20, -- special / u8  Day of Week and Time of Day 
    Date = 21, -- u8 / u8  Calendar date 
    Year = 22, -- u16  Calendar year 
    TrSetCH2 = 23, -- f8.8  Room Setpoint for 2nd CH circuit (°C)
    Tr = 24, -- f8.8  Room temperature (°C)
    Tboiler = 25, -- f8.8  Boiler flow water temperature (°C)
    Tdhw = 26, -- f8.8  DHW temperature (°C)
    Toutside = 27, -- f8.8  Outside temperature (°C)
    Tret = 28, -- f8.8  Return water temperature (°C)
    Tstorage = 29, -- f8.8  Solar storage temperature (°C)
    Tcollector = 30, -- f8.8  Solar collector temperature (°C)
    TflowCH2 = 31, -- f8.8  Flow water temperature CH2 circuit (°C)
    Tdhw2 = 32, -- f8.8  Domestic hot water temperature 2 (°C)
    Texhaust = 33, -- s16  Boiler exhaust temperature (°C)
    TdhwSetUBTdhwSetLB = 48, -- s8 / s8  DHW setpoint upper & lower bounds for adjustment  (°C)
    MaxTSetUBMaxTSetLB = 49, -- s8 / s8  Max CH water setpoint upper & lower bounds for adjustment  (°C)
    HcratioUBHcratioLB = 50, -- s8 / s8  OTC heat curve ratio upper & lower bounds for adjustment  
    TdhwSet = 56, -- f8.8  DHW setpoint (°C)    (Remote parameter 1)
    MaxTSet = 57, -- f8.8  Max CH water setpoint (°C)  (Remote parameters 2)
    Hcratio = 58, -- f8.8  OTC heat curve ratio (°C)  (Remote parameter 3)
    RemoteOverrideFunction = 100, -- flag8 / -  Function of manual and program changes in master and remote room setpoint. 
    OEMDiagnosticCode = 115, -- u16  OEM-specific diagnostic/service code 
    BurnerStarts = 116, -- u16  Number of starts burner 
    CHPumpStarts = 117, -- u16  Number of starts CH pump 
    DHWPumpValveStarts = 118, -- u16  Number of starts DHW pump/valve 
    DHWBurnerStarts = 119, -- u16  Number of starts burner during DHW mode 
    BurnerOperationHours = 120, -- u16  Number of hours that burner is in operation (i.e. flame on) 
    CHPumpOperationHours = 121, -- u16  Number of hours that CH pump has been running 
    DHWPumpValveOperationHours = 122, -- u16  Number of hours that DHW pump has been running or DHW valve has been opened 
    DHWBurnerOperationHours = 123, -- u16  Number of hours that burner is in operation during DHW mode 
    OpenThermVersionMaster = 124, -- f8.8  The implemented version of the OpenTherm Protocol Specification in the master. 
    OpenThermVersionSlave = 125, -- f8.8  The implemented version of the OpenTherm Protocol Specification in the slave. 
    MasterVersion = 126, -- u8 / u8  Master product version number and type 
    SlaveVersion = 127 -- u8 / u8  Slave product version number and type
}

local pin_in = 5
local pin_out = 4
local status = ot.OpenThermStatus.NOT_INITIALIZED
local localResponse
local localResponseStatus
local responseTimestamp = 0
local responseBitIndex = 0

local requestsQueue = {}

local HIGH = 1
local LOW = 0

local TIME_FROM_MASTER_REQUEST_TO_SLAVE_RESPONSE_MS = 1000 -- TODO by specification it should be 200 - 800 ms
local TIME_FROM_RESPONSE_TO_NEXT_REQUEST_MS = 100 -- by specification
local TIME_MAX_DELAY_MkS = 1000000 -- 1 sec
local TIME_RESPONSE_WAITING_MS = 32 -- 1ms on each bit

local function isReady()
    return status == ot.OpenThermStatus.READY;
end

local function setIdleState(afterIdleFunction)
    gpio.write(pin_out, gpio.HIGH);
    tmr.create():alarm(TIME_FROM_MASTER_REQUEST_TO_SLAVE_RESPONSE_MS, tmr.ALARM_SINGLE, afterIdleFunction)
end

local function activateBoiler(nextFunction)
    setIdleState(nextFunction);
end

local function sendBit(bit)
    gpio.serout(pin_out, bit == 1 and gpio.LOW or gpio.HIGH, { 500, 500 })
end

-- Returns HIGH or LOW accordingly
-- number - 32 bit unsigned integer to read bit from
-- position - position of bit in number to read. Starts from 0
local function bitRead(number, position)
    if (position < 0) then
        return
    end

    local mask = bit.bit(31 - position)

    return bit.rshift(bit.band(number, mask), 31 - position)
end

-- TODO need to catch response with invalid response message type
local function isValidResponse(response)
    if (parity(response)) then
        return false
    end
    local msgType = bit.rshift(bit.lshift(response, 1), 29)

    return msgType == 4 or msgType == 5 --4 - read, 5 - write
end

local function responseWaiting(responseCallback)
    if (isReady()) then
        return
    end

    if (status ~= ot.OpenThermStatus.NOT_INITIALIZED and tmr.now() - responseTimestamp > TIME_MAX_DELAY_MkS) then
        localResponseStatus = ot.OpenThermResponseStatus.TIMEOUT
        status = ot.OpenThermStatus.READY

        responseCallback(localResponse, localResponseStatus)
    elseif (status == ot.OpenThermStatus.RESPONSE_INVALID) then
        localResponseStatus = ot.OpenThermResponseStatus.INVALID
        status = ot.OpenThermStatus.READY

        responseCallback(localResponse, localResponseStatus)
    elseif (st == ot.OpenThermStatus.RESPONSE_READY) then
        localResponseStatus = isValidResponse(localResponse)
                and ot.OpenThermResponseStatus.SUCCESS or ot.OpenThermResponseStatus.INVALID
        status = ot.OpenThermStatus.READY

        responseCallback(localResponse, localResponseStatus)
    end
end

local function sendRequest(request, responseCallback)
    status = ot.OpenThermStatus.REQUEST_SENDING;

    localResponse = 0;
    localResponseStatus = ot.OpenThermResponseStatus.NONE;

    sendBit(HIGH); --start bit
    for i = 31, 0, -1 do
        sendBit(bitRead(request, i))
    end
    sendBit(HIGH); --stop bit
    setIdleState(function()
        status = ot.OpenThermStatus.RESPONSE_WAITING
        responseTimestamp = tmr.now()

        tmr.create():alarm(TIME_RESPONSE_WAITING_MS, tmr.ALARM_AUTO, function(timer)
            responseWaiting(function(response, responseStatus)
                --TODO check response and status and make decision
                --TODO Retry if ot.OpenThermStatus.RESPONSE_INVALID
                timer:unregister()
                responseCallback(response, responseStatus)
            end)
        end)
    end)
end

local function processNextRequest(timer)
    local request
    local requestCallback

    if (table.getn(requestsQueue) > 0 and isReady()) then
        local reqRes = table.remove(requestsQueue, 1)
        request = reqRes[1]
        requestCallback = reqRes[2]
    elseif (tmr.now() - responseTimestamp > TIME_MAX_DELAY_MkS) then
        -- max delay has been exceeded
        request = ot.buildGetBoilerStatusRequest(true, true, false, false, false)
        requestCallback = function(_, responseStatus)
            log("Max Delay. Status requested. ResponseStatus is => ", responseStatus)
        end
    else
        -- no request
        timer:start()
        return
    end

    log("process request => ", request)
    sendRequest(request, function(response, responseStatus)
        requestCallback(response, responseStatus)
        timer:start()
    end)
end

local function initRequestProcessor()
    -- The distance (delay) between last response and next request should not be less then 100ms
    tmr.create():alarm(TIME_FROM_RESPONSE_TO_NEXT_REQUEST_MS, tmr.ALARM_AUTO, function(timer)
        timer:stop()
        processNextRequest(timer)
    end)
end

local function responseReading(level, when, eventcount)
    if (isReady()) then
        return
    end

    local newTs = when

    if (status == ot.OpenThermStatus.RESPONSE_WAITING) then
        if (level == gpio.HIGH) then
            status = ot.OpenThermStatus.RESPONSE_START_BIT
        else
            status = ot.OpenThermStatus.RESPONSE_INVALID;
        end

        responseTimestamp = newTs
    elseif (status == ot.OpenThermStatus.RESPONSE_START_BIT) then
        if (newTs - responseTimestamp < 750 and level == gpio.LOW) then
            status = ot.OpenThermStatus.RESPONSE_RECEIVING
            responseTimestamp = newTs
            responseBitIndex = 0
        else
            status = ot.OpenThermStatus.RESPONSE_INVALID
            responseTimestamp = newTs
        end
    elseif (status == ot.OpenThermStatus.RESPONSE_RECEIVING) then
        if (newTs - responseTimestamp > 750) then
            if (responseBitIndex < 32) then
                -- Manchester encoding
                localResponse = bit.bor(bit.lshift(localResponse, 1), level == gpio.HIGH and LOW or HIGH)
                responseTimestamp = newTs
                responseBitIndex = responseBitIndex + 1
            else
                --stop bit
                status = ot.OpenThermStatus.RESPONSE_READY;
                responseTimestamp = newTs
            end
        end
    end
end

local function parity(frame)
    --odd parity
    local p = 0
    while (frame > 0) do
        if (bit.band(frame, 1)) then
            p = p + 1
        end
        frame = bit.rshift(frame, 1)
    end

    return bit.band(p, 1) == 1
end

local function levelToBool(level)
    return level == HIGH
end

------- LOW LEVEL API -------

function ot.init(pinIn, pinOut)
    pin_in = pinIn
    pin_out = pinOut
end

function ot.begin()
    gpio.mode(pin_in, gpio.INT);
    gpio.mode(pin_out, gpio.OUTPUT);

    gpio.trig(pin_in, "both", responseReading)

    activateBoiler(function()
        status = ot.OpenThermStatus.READY
        initRequestProcessor()
    end)
end

function ot.buildRequest(requestType, messageId, data)
    log("ot.buildRequest start")
    local request = data

    if (requestType == ot.OpenThermRequestType.WRITE) then
        request = bit.bor(request, bit.lshift(1, 28))
    end

    request = bit.bor(request, bit.lshift(messageId, 16))

    if (parity(request)) then
        request = bit.bor(request, bit.lshift(1, 31))
    end

    log("ot.buildRequest end => request", request)
    return request
end

function ot.sendRequest(request, responseCallback)
    table.insert(requestsQueue, { request, responseCallback })
end

------- UTILS -------

function ot.floatToU88(floatData)
    return temperature * 256.0 --TODO works only for positive values
end

function ot.u88ToFloat(u88Data)
    -- if u88Data < 0
    if (u88Data & 0x8000) then
        return -(0x10000 - u88Data) / 256.0
    else
        return u88Data / 256.0
    end
end

------- HIGH LEVEL API -------

--[[
Gets current status of Boiler (slave)
@return responseStatus,
        CentralHeatingEnabled,
        HotWaterEnabled,
        isFlameOn,
        CoolingEnabled,
        OutsideTemperatureCompensationActive,
        CentralHeating2Enabled,
        CentralHeatingActive,
        HotWaterActive,
        isFlameOn,
        CoolingActive,
        CentralHeating2Active,
        DiagnosticIndication
]]
function ot.getBoilerStatus()
    local data = 0
    data = bit.lshift(data, 8)
    log(data)

    local request = ot.buildRequest(ot.OpenThermRequestType.READ, ot.OpenThermMessageID.Status, data)
    co = coroutine.create(function ()
        ot.sendRequest(request,function(response, responseStatus)
            coroutine.yield(response, responseStatus)
        end);
    end)

    local _,response, responseStatus = coroutine.resume(co)

    return responseStatus,
        levelToBool(bit.band(response, 0x8000)), --CentralHeatingEnabled
        levelToBool(bit.band(response, 0x4000)), --HotWaterEnabled
        levelToBool(bit.band(response, 0x2000)), --CoolingEnabled
        levelToBool(bit.band(response, 0x1000)), --OutsideTemperatureCompensationActive
        levelToBool(bit.band(response, 0x800)), --CentralHeating2Enabled
        levelToBool(bit.band(response, 0x2)), --CentralHeatingActive
        levelToBool(bit.band(response, 0x4)), --HotWaterActive
        levelToBool(bit.band(response, 0x8)), --isFlameOn
        levelToBool(bit.band(response, 0x10)), --CoolingActive
        levelToBool(bit.band(response, 0x20)), --CentralHeating2Active
        levelToBool(bit.band(response, 0x40)) --DiagnosticIndication
end

return ot