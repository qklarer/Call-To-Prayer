debug = true
json = require('json')
Count = 0
End_Point_URL = "http://api.aladhan.com"
Active_Prayer = nil
Total_Duration = nil
Time_Stamp = nil
Prayer_decodedJSON = nil
Start = true
Locked_Time = false
Refresh_Time = NamedControl.GetText("Refresh_Time")

--Used to assign numeric values to Prayers. Ex. Controls.Outputs["Some prayer number related to an output pin"].Value
Current_Prayer =
{
    Fajr = 1,
    Sunrise = 2,
    Dhuhr = 3,
    Asr = 4,
    Sunset = 5,
    Maghrib = 6,
    Isha = 7,
    Imsak = 8,
    Midnight = 9
}

--First HTTP call using local time based off of DSP time.
function Get_Prayer_Time()

    if Start == true then
        print("Refresh Triggered on " .. (os.date("%H:%M")))
        local Latitude = NamedControl.GetText("Latitude")
        local Longitude = NamedControl.GetText("Longitude")
        local Time_Url = HttpClient.DecodeString(HttpClient.CreateUrl({
        Host = End_Point_URL,
        Path = "v1/timings/" .. (os.date('%d-%m-%Y')) .. "?latitude=" .. Latitude .. "&longitude=" .. Longitude .. "&method=2"}))

        HttpClient.Upload({
        Url = Time_Url,
        Data = "",
        Method = "GET",
        EventHandler = Get_Prayer_Time_Response})
        Start = false
    else
        Notification(Prayer_decodedJSON)
    end
end

--Response for encoded JSON, use that response to get prayer times.
function Get_Prayer_Time_Response(Table, ReturnCode, Data, Error, Headers)

    Prayer_decodedJSON = json.decode(Data)
    Notification(Prayer_decodedJSON)

    if debug then 
        --print(ReturnCode)
        --print(Data)
    end
end

function Notification(Times)
    
    Get_Time_stamp(Times)
    local Prayer_Times =
    {
        Fajr = (Times.data.timings.Fajr),
        Sunrise = (Times.data.timings.Sunrise),
        Dhuhr = (Times.data.timings.Dhuhr),
        Asr = (Times.data.timings.Asr),
        Sunset = (Times.data.timings.Sunset),
        Maghrib = (Times.data.timings.Maghrib),
        Isha = (Times.data.timings.Isha),
        Imsak = (Times.data.timings.Imsak),
        Midnight = (Times.data.timings.Midnight)
    }

    -- Ability to use hardcoded times for debugging.
    -- local Prayer_Times =
    -- {
    --     Fajr = "16:30",
    --     Sunrise = "16:32",
    --     Dhuhr = "16:35",
    --     Asr = "16:41",
    --     Sunset = "16:50",
    --     Maghrib = "15:40",
    --     Isha = "15:42",
    --     Imsak = "15:44",
    --     Midnight = "15:46"
    -- }

    --Takes prayer times and prints them to labels in module.
    for k,v in pairs(Prayer_Times) do
        NamedControl.SetText(tostring(k), v)

        --If a time is equal to the OS time, store it in a variable for future use.
        if v == (os.date("%H:%M")) then
            Active_Prayer = k
        end
    end

    --Checks what output pin that prayer is assosiated with and turns it on and off based on the duration time in module.
    for k,v in pairs(Current_Prayer) do
        if k == Active_Prayer then

            --Takes a current timestamp and stores it until total duration time is over.
            if Locked_Time == false then
                local Duration = (tonumber(NamedControl.GetText(k .. "Dur")) * 60) --Multiply by 60 to convert seconds to minutes.
                Total_Duration = Duration + tonumber(Time_Stamp)
                Locked_Time = true
                
                --Sets the Active Prayers pin to 1.
                if tonumber(Time_Stamp) < Total_Duration  then
                    Controls.Outputs[v].Value = 1
                    print(k .. " Triggered on " .. (os.date("%H:%M:%S")))
                end
            end

            --Sets active Prayers pin to 0.
            if tonumber(Time_Stamp) > Total_Duration then
                Controls.Outputs[v].Value = 0
                print(k .. " Triggered off " .. (os.date("%H:%M:%S")))
                Locked_Time = false
                Active_Prayer = nil
            end
        end
    end
end 

--Used to get time stamp of the API. Want to check to make sure their Unix time is updating as it should
function Get_Time_stamp(Timezone)

    local Timezone = Timezone.data.meta.timezone
    local Time_stamp_Url = HttpClient.DecodeString(HttpClient.CreateUrl({
    Host = End_Point_URL,
    Path = "v1/currentTimestamp?zone=" .. Timezone}))

    HttpClient.Upload({
    Url = Time_stamp_Url,
    Data = "",
    Method = "GET",
    EventHandler = Get_Time_Stamp_Response})
end

function Get_Time_Stamp_Response(Table, ReturnCode, Data, Error, Headers)
    
    local Time_Stamp_decodedJSON = json.decode(Data)
    Time_Stamps(Time_Stamp_decodedJSON)
    
    if debug then
        --print(ReturnCode) 
        --print(Data)
    end

    if (200 == ReturnCode or ReturnCode == 201) then
        NamedControl.SetPosition("Connected", 1)
     else
        NamedControl.SetPosition("Connected", 0) 
  end  
end

--Prints timestamp and OS time. 
function Time_Stamps(Time)

    Time_Stamp = Time.data
    NamedControl.SetText("Time_Stamp", "Unix Time Stamp: " .. Time_Stamp)
    NamedControl.SetText("Current_Time", (os.date("%H:%M")))
end

function TimerClick()

    --Once the refresh time is reached, update no more then one time within that minute. 
    Count = Count + 5

    if Refresh_Time == (os.date("%H:%M")) and Count == 15 then
        Start = true
    end

    if Count > 20 then
        Count = 0
    end

    Get_Prayer_Time()
end

MyTimer = Timer.New()
MyTimer.EventHandler = TimerClick
MyTimer:Start(5)
