local width = 320
local height = 480

--print (display.pixelWidth, display.pixelHeight)

if string.sub(system.getInfo("model"),1,4) == "iPad" then
    width = 360
elseif string.sub(system.getInfo("model"),1,2) == "iP" then
    -- iPhone
    if display.pixelHeight == 480 or display.pixelHeight == 960 then
        -- do nothing
    elseif display.pixelHeight == 1136 then
        height = 568
    else
        height = 570
    end
elseif display.pixelHeight / display.pixelWidth > 1.72 then -- 720 x 1280
    height = 570
elseif display.pixelHeight / display.pixelWidth > 1.7 then -- 600 x 1024
    height = 546
elseif display.pixelHeight / display.pixelWidth > 1.6 then
    height = 526
else
    height = 533
end

--print (width,height)
application = 
{
    content =
    {
        width = width,
        height = height,
        scale = "letterBox",
        imageSuffix = 
        {
            ["@2x"] = 2,
        },
    },
    notification = 
    {
        google =
        {
            projectNumber = "627983564881"
        },
        iphone = {
            types = {
                "badge", "sound", "alert"
            }
        }
    }
}