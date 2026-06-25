-- LSX | Car Sales 2
-- Developer: Kyzen (Owner of LSX)
-- Discord: discord.gg/UG4TujqUeq

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local RS               = game:GetService("ReplicatedStorage")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")

local lp       = Players.LocalPlayer
local username = lp.Name
local dispName = lp.DisplayName

local char, hrp, hum
local function getChar()
    char = lp.Character or lp.CharacterAdded:Wait()
    hrp  = char:WaitForChild("HumanoidRootPart")
    hum  = char:WaitForChild("Humanoid")
end
getChar()
lp.CharacterAdded:Connect(function()
    task.wait(0.3)
    getChar()
end)

-- Config
local scriptActive = true
local menuBind     = Enum.KeyCode.C
local accentColor  = Color3.fromRGB(70, 150, 255)
local CONFIG_PATH  = "LSX_CS2_Config.json"

-- Feature state
-- FIX 7: savedPos replaced with savedPositions table (up to 5 named positions)
local state = {
    notifSpawns   = true,
    walkspeed     = 16,
    jumppower     = 50,
    infJump       = false,
    noclip        = false,
    carESP        = false,
    carESPunowned = false,
    playerESP     = false,
    espSkeleton   = false,
    espBoxes      = false,
    espDistance   = false,
    espHealth     = false,
    fullbright    = false,
    hidePlayers   = false,
    fov           = 70,
    antiAFK       = false,
    savedPositions = {},  -- [{name, pos={X,Y,Z}}]
    distTracker   = 0,
    distUnit      = "mi",
}

local function saveConfig()
    local data = {
        bind = menuBind.Name, accent = {accentColor.R, accentColor.G, accentColor.B},
        notifSpawns = state.notifSpawns, walkspeed = state.walkspeed, jumppower = state.jumppower,
        fov = state.fov, distUnit = state.distUnit,
        savedPositions = state.savedPositions,
    }
    pcall(function() writefile(CONFIG_PATH, HttpService:JSONEncode(data)) end)
end

local function loadConfig()
    local ok, raw = pcall(function() return readfile(CONFIG_PATH) end)
    if not ok or not raw then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or not data then return end
    if data.bind then
        local kc = Enum.KeyCode[data.bind]
        if kc then menuBind = kc end
    end
    if data.accent then accentColor = Color3.new(data.accent[1], data.accent[2], data.accent[3]) end
    if data.notifSpawns ~= nil then state.notifSpawns = data.notifSpawns end
    if data.walkspeed then state.walkspeed = data.walkspeed end
    if data.jumppower then state.jumppower = data.jumppower end
    if data.fov then state.fov = data.fov end
    if data.distUnit then state.distUnit = data.distUnit end
    -- FIX 7: load new savedPositions format; also migrate old savedPos if present
    if data.savedPositions then
        state.savedPositions = data.savedPositions
    elseif data.savedPos then
        state.savedPositions = {{name="Saved Position", pos=data.savedPos}}
    end
end
loadConfig()

-- Theme (LSX: white/blue gradient, black glass)
local T = {
    bg        = Color3.fromRGB(10, 12, 16),
    bgGlass   = Color3.fromRGB(16, 19, 26),
    card      = Color3.fromRGB(22, 26, 34),
    cardBorder= Color3.fromRGB(45, 52, 66),
    sidebar   = Color3.fromRGB(13, 16, 22),
    text      = Color3.fromRGB(238, 242, 248),
    textSec   = Color3.fromRGB(150, 160, 175),
    textTer   = Color3.fromRGB(95, 105, 120),
    green     = Color3.fromRGB(60, 210, 130),
    red       = Color3.fromRGB(255, 95, 95),
    blue      = Color3.fromRGB(70, 150, 255),
    blueLight = Color3.fromRGB(130, 190, 255),
}
local function acc() return accentColor end

-- FIX 1: accent color registry so changes apply live everywhere
local accentObjects = {}  -- [{obj, prop}]
local function registerAccent(obj, prop)
    accentObjects[#accentObjects+1] = {obj=obj, prop=prop}
    obj[prop] = accentColor
end
local function applyAccentColor(col)
    accentColor = col
    for _, e in ipairs(accentObjects) do
        pcall(function() e.obj[e.prop] = col end)
    end
end

-- Helpers
local function corner(p, r)
    local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r); return c
end
local function stroke(p, col, t)
    local s = Instance.new("UIStroke", p); s.Color = col or T.cardBorder
    s.Transparency = t or 0; s.Thickness = 1; return s
end
local H = {}
H.gradient = function(p, c1, c2, rot)
    local g = Instance.new("UIGradient", p)
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot or 0
    return g
end
H.mkLbl = function(par, txt, sz, x, y, w, h, wt, col)
    local l = Instance.new("TextLabel", par)
    l.Text = txt; l.TextSize = sz; l.Position = UDim2.new(0, x, 0, y)
    l.Size = UDim2.new(1, -(x*2), 0, h or 20); l.BackgroundTransparency = w or 1
    l.TextColor3 = col or T.text; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = wt == "bold" and Enum.Font.GothamBold or (wt == "medium" and Enum.Font.GothamMedium or Enum.Font.Gotham)
    return l
end
H.mkCard = function(par, h, order)
    local c = Instance.new("Frame", par)
    c.Size = UDim2.new(1, 0, 0, h); c.BackgroundColor3 = T.card
    c.BackgroundTransparency = 0.15; c.BorderSizePixel = 0; c.LayoutOrder = order or 0
    corner(c, 10); stroke(c, T.cardBorder, 0.4)
    return c
end
H.mkSection = function(par, txt, order)
    local l = Instance.new("TextLabel", par)
    l.Text = txt; l.TextSize = 11; l.Size = UDim2.new(1, 0, 0, 22)
    l.BackgroundTransparency = 1; l.TextColor3 = T.textTer
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Font = Enum.Font.GothamBold
    l.LayoutOrder = order or 0
    return l
end

-- Teleport helpers
local function getTpPart(name)
    local tl = Workspace:FindFirstChild("TeleportLocations")
    if tl then
        local p = tl:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end

-- FIX 4: improved tpToPos - handles vehicle seats and uses CFrame properly
local function tpToPos(pos, yOff, zOff)
    if not hrp or not hrp.Parent then return false end
    local targetCF = CFrame.new(pos.X, pos.Y + (yOff or 3), pos.Z + (zOff or 0))
    local seat = hum and hum.SeatPart
    if seat and seat:IsA("BasePart") then
        local veh = seat:FindFirstAncestorWhichIsA("Model")
        if veh and veh.PrimaryPart then
            veh:SetPrimaryPartCFrame(targetCF)
            return true
        end
    end
    hrp.CFrame = targetCF
    return true
end

-- FIX 4: teleport to a part/position near a car slot - tries multiple fallback offsets
local function tpToCarPart(part, slotPos)
    if not hrp or not hrp.Parent then return false end
    local targetPos = part and part.Position or slotPos
    if not targetPos then return false end
    -- Try a nearby safe offset to avoid spawning inside the car
    local offsets = {
        Vector3.new(0, 4, 6),
        Vector3.new(0, 4, -6),
        Vector3.new(6, 4, 0),
        Vector3.new(-6, 4, 0),
        Vector3.new(0, 5, 0),
    }
    local seat = hum and hum.SeatPart
    if seat and seat:IsA("BasePart") then
        local veh = seat:FindFirstAncestorWhichIsA("Model")
        if veh and veh.PrimaryPart then
            veh:SetPrimaryPartCFrame(CFrame.new(targetPos + offsets[1]))
            return true
        end
    end
    hrp.CFrame = CFrame.new(targetPos + offsets[1])
    return true
end

-- Find player's own plot dynamically (changes per game)
local function findMyPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("CurrentOwner")
        local ownerVal = nil
        if owner and owner:IsA("StringValue") then ownerVal = owner.Value end
        if not ownerVal then ownerVal = plot:GetAttribute("CurrentOwner") end
        if ownerVal == username or ownerVal == dispName then
            return plot
        end
    end
    return nil
end

local function getPlotTpPart(plot)
    if not plot then return nil end
    local tp = plot:FindFirstChild("TpPart")
    if tp and tp:IsA("BasePart") then return tp end
    local center = plot:FindFirstChild("Center")
    if center and center:IsA("BasePart") then return center end
    return plot:FindFirstChildWhichIsA("BasePart")
end

-- CAR DATA
local DATA = {}
DATA.CARDB = {
    {"Rodster","Tesla","Roadster","Limited",49700000},
    {"Fenomenos","Lamborghini","Fenomeno","Limited",12400000},
    {"Varoni","Ferrari","F40","Limited",10000000},
    {"Bacero","Bentley","Bacalar","Limited",7800000},
    {"Bentarra","Bentley","Flying Spur","Limited",5000000},
    {"Ditoni","Ferrari","Daytona","Limited",5000000},
    {"Yurus","Lamborghini","Urus","Limited",999999},
    {"Viojner","N/A","Viojner","Limited",999900},
    {"GT Nismo","Nissan","GT-R Nismo","Limited",949999},
    {"Galang Demon","Dodge","Challenger SRT Demon","Limited",949999},
    {"Fiper","Dodge","Viper ACR","Limited",550000},
    {"Hammera","N/A","Hammera","Limited",450000},
    {"Branco","Ford","Bronco","Limited",285000},
    {"SkyLine","Nissan","GT-R Skyline R34","Limited",185000},
    {"Supry","Toyota","Supra","Limited",185000},
    {"RX","Mazda","RX-7","Limited",150000},
    {"Rovalto","Lamborghini","Revuelto","Limited",4400000},
    {"Heura","Pagani","Huayra","Limited",49700000},
    {"Goster","Rolls Royce","Ghost","Limited",5450000},
    {"Dedsona","Nissan","Ddsen","Limited",80000},
    {"Teutara","SSC","Tuatara","Standard",7020000},
    {"Audira","Audi","RS7","Standard",730000},
    {"Escali","Cadillac","Escalade","Standard",540000},
    {"Quxan","Infinity","QX80","Standard",395000},
    {"Doringo","Dodge","Durango SRT Hellcat","Standard",273000},
    {"Pradr","Toyota","Land Cruiser Prado","Standard",251000},
    {"Tahiro","Chevrolet","Tahoe","Standard",220000},
    {"Blasd","Hyundai","Palisade","Standard",218000},
    {"Cadira CT4","Cadillac","CT4","Standard",192000},
    {"Rangera","Range Rover","SV Autobiography","Standard",172000},
    {"Kronza","Toyota","Crown","Standard",163000},
    {"Genera J80","Toyota","Land Cruiser J80","Standard",144000},
    {"Altera","Nissan","Altima","Standard",133000},
    {"Kimora","Toyota","Camry","Standard",128000},
    {"Sonera","Hyundai","Sonata","Standard",129000},
    {"Santaf","Hyundai","Santa Fe","Standard",126000},
    {"Genera JV70","Genesis","GV70","Standard",128000},
    {"C4","Kia","K4","Standard",115000},
    {"Alantar","Hyundai","Elantra","Standard",103000},
    {"MGara 7","MG Motor","7","Standard",91050},
    {"Q5","Kia","K5 GT-Line","Standard",95000},
    {"Telluri","Kia","Telluride","Standard",92000},
    {"Unix V","Changan","UNI-V","Standard",75000},
    {"Charjero CRT","Dodge","Charger SRT","Standard",75000},
    {"Sportana","Mazda","CX-5","Standard",73000},
    {"Ambara","Mercedes-Benz","GL-Class","Standard",58000},
    {"Mazdr","Mazda","3","Standard",53800},
    {"Sbakir","Chevrolet","Spark","Standard",31000},
    {"ACCENJ","Hyundai","Accent","Standard",28000},
    {"Crown Victora","Ford","Crown Victoria","Standard",14000},
    {"Serao","Mercedes-Benz","AMG ONE","Legendary",20500000},
    {"Chiror","Bugatti","Chiron","Legendary",10580000},
    {"Maybar","Mercedes-Benz","Maybach Vision","Legendary",11000000},
    {"Mekleren","McLaren","P1","Legendary",4440000},
    {"Divao","Bugatti","Divo","Ultra Rare",21000000},
    {"Spocra","Rolls-Royce","Specter","Ultra Rare",2950000},
    {"Borcha","Porsche","GT3 RS","Ultra Rare",1295000},
    {"Lambo","Lamborghini","Huracan","Very Rare",1320000},
    {"Avandor","Lamborghini","Aventador","Very Rare",2101000},
    {"Baybar","Mercedes-Benz","S-Class","Rare",2280000},
    {"Culinar","Rolls-Royce","Cullinan","Rare",1900000},
    {"Fantur","Rolls-Royce","Phantom","Rare",1910000},
    {"Black Horse","Ford","Mustang Dark Horse","Rare",310000},
    {"Bentyagr","Bentley","Bentayga","Semi-Rare",305000},
    {"Ranger","Range Rover","Autobiography","Semi-Rare",755000},
    {"Lucaid","Lucid","Air","Semi-Rare",455555},
    {"Syper","Tesla","Cybertruck","Semi-Rare",455555},
    {"G-Cross","Mercedes-Benz","G-Class","Semi-Rare",342000},
    {"Lexira","Lexus","LX600","Uncommon",555555},
    {"GT Class","Mercedes-Benz","AMG GT-63 S","Uncommon",520000},
    {"Audlra","Audi","RS8","Uncommon",558500},
    {"N5","BMW","M5","Moderate",548500},
    {"Defenda","Land Rover","Defender 110","Moderate",485000},
    {"C8","BMW","M8","Moderate",670000},
    {"N4","BMW","M4","Moderate",595000},
    {"Caeenr","Porsche","Cayenne","Moderate",410000},
    {"Corver","Chevrolet","Corvette C8","Moderate",360000},
    {"Charjero Helksa","Dodge","Charger Hellcat","Moderate",332000},
    {"Genera J70","Genesis","G70","Moderate",160000},
    {"Christo SRT","Chrysler","300 SRT","Common",192000},
    {"T Class","Mercedes-Benz","AMG C63","Common",165000},
    {"AZORA","Hyundai","Azera","Common",88000},
    {"Aura S4","Audi","S4","Common",219981},
    {"Raf TRX","Dodge","RAM TRX","Common",390000},
    {"Crucer","Toyota","Land Cruiser","Common",310000},
    {"Yakon","GMC","Yukon","Common",231000},
    {"N2","BMW","M2","Common",220000},
    {"Sierro","GMC","Sierra","Common",172000},
    {"Shilpa","Ford","Mustang Shelby","Common",145000},
    {"Ceres 3","BMW","Series 3","Common",138000},
    {"J70","Genesis","G90","Common",135000},
    {"Tori","Ford","Taurus","Very Common",132000},
    {"Charjero GT","Dodge","Charger GT","Very Common",110000},
    {"Lexira AS","Lexus","ES","Very Common",175000},
    {"Rafter F15","Ford","F150 Raptor","Very Common",397000},
    {"Patrel","Nissan","Patrol","Very Common",292000},
    {"Siora","GMC","Sierra","Very Common",263000},
    {"Avalyn","Toyota","Avalon","Very Common",45555},
    {"Kadi","Kia","Cadenza","Very Common",132000},
    {"C5","Kia","K5","Very Common",115000},
    {"Raptor","Ford","Raptor","Very Common",115000},
    {"Kora","Hyundai","Kona","Very Common",98520},
    {"Sonira","Hyundai","Sonata","Very Common",95000},
    {"Ramarro","Chevrolet","Camaro","Very Common",65000},
    {"Sqora","Toyota","Sequoia","Very Common",67000},
    {"Optoma","Kia","Optima","Very Common",65000},
    {"Helix","Toyota","Hilux","Very Common",128000},
    {"Charjero","Dodge","Charger SXT","Very Common",45000},
    {"Akura","Honda","Accord","Very Common",132885},
    {"Alanter","Hyundai","Elantra","Very Common",105000},
    {"Ariza 8","Chery","Arrizo 8","Very Common",106000},
    {"Maxina","Nissan","Maxima","Very Common",91000},
    {"Cemora","Toyota","Camry","Very Common",88000},
    {"Empora","GAC Motor","EMPOW","Very Common",66000},
    {"MGera GT","MG Motor","GT","Super Common",64975},
    {"Yarsr","Toyota","Yaris","Super Common",65000},
    {"Azeora","Hyundai","Azera","Super Common",115000},
    {"Searo","GMC","Sierra","Super Common",115000},
    {"Q8","Kia","K8","Super Common",115000},
    {"Cadi","Kia","Cadenza","Super Common",65555},
    {"Titan-X","Toyota","RAV4","Super Common",65000},
    {"Aurian","Toyota","Aurion","Super Common",65000},
    {"Acora","Honda","Accord","Super Common",45555},
    {"Jelira Emgrand","Geely","Emgrand","Super Common",48000},
    {"Capas","Chevrolet","Caprice","Super Common",45555},
    {"Kemora","Toyota","Camry","Super Common",35000},
    {"Aurioz","Toyota","Aurion","Super Common",25000},
    {"Optira","Kia","Optim","Super Common",35000},
    {"Craoz","Chevrolet","Cruze","Super Common",78000},
    {"Lexira LS 430","Lexus","LS 420","Super Common",19000},
    {"Fusior","Ford","Fusion","Extremely Common",39000},
    {"Audira A4","Audi","A4","Extremely Common",24000},
    {"Krause","Chevrolet","Cruze","Extremely Common",17000},
    {"Solira","Nissan","Sunny","Extremely Common",45680},
    {"Altira","Nissan","Altima","Extremely Common",25000},
    {"Land","Toyota","Land Cruiser","Very Common",212000},
    {"RB3","BMW","Series 3","Common",138000},
    {"E320","Mercedes-Benz","E-Class","Common",120000},
    {"M3","BMW","M3","Moderate",250000},
    {"Rs7","Audi","RS7","Standard",730000},
    {"N3","BMW","Series 3","Common",138000},
    {"Land_07","Land Rover","Defender 110","Moderate",485000},
    {"LandRover-Defender-110","Land Rover","Defender 110","Moderate",485000},
}

DATA.RARITY_COL = {
    ["Limited"]=Color3.fromRGB(255,69,58), ["Legendary"]=Color3.fromRGB(255,214,10),
    ["Ultra Rare"]=Color3.fromRGB(175,82,222), ["Very Rare"]=Color3.fromRGB(255,159,10),
    ["Rare"]=Color3.fromRGB(255,100,30), ["Semi-Rare"]=Color3.fromRGB(255,204,0),
    ["Uncommon"]=Color3.fromRGB(52,199,89), ["Moderate"]=Color3.fromRGB(10,132,255),
    ["Common"]=Color3.fromRGB(152,152,157), ["Very Common"]=Color3.fromRGB(120,120,120),
    ["Super Common"]=Color3.fromRGB(90,90,90), ["Extremely Common"]=Color3.fromRGB(70,70,70),
    ["Standard"]=Color3.fromRGB(100,180,255),
}
local function rcol(r) return DATA.RARITY_COL[r] or Color3.fromRGB(152,152,157) end

DATA.NOTIFY_RARITIES = {
    ["Limited"]=true, ["Legendary"]=true, ["Ultra Rare"]=true,
    ["Very Rare"]=true, ["Rare"]=true,
}

local function normName(s)
    s = tostring(s)
    s = s:gsub("[_%-]", " ")
    s = s:gsub("%d", "")
    s = s:gsub("%s+", "")
    return s:lower()
end

DATA.CODE_MAP = {
    ["rb3"]={"BMW","Series 3"}, ["m3"]={"BMW","M3"}, ["c63"]={"Mercedes-Benz","AMG C63"},
    ["e320"]={"Mercedes-Benz","E-Class"}, ["rs8"]={"Audi","RS8"}, ["rs7"]={"Audi","RS7"},
    ["k524"]={"Kia","K5"}, ["k5"]={"Kia","K5"}, ["k4"]={"Kia","K4"}, ["k8"]={"Kia","K8"},
    ["ls420"]={"Lexus","LS 420"}, ["m5"]={"BMW","M5"}, ["m4"]={"BMW","M4"}, ["m8"]={"BMW","M8"},
    ["m2"]={"BMW","M2"}, ["n5"]={"BMW","M5"}, ["n4"]={"BMW","M4"},
    ["elantra"]={"Hyundai","Elantra"}, ["accord"]={"Honda","Accord"},
    ["land"]={"Toyota","Land Cruiser"}, ["taurus"]={"Ford","Taurus"},
    ["yokon"]={"GMC","Yukon"}, ["yukon"]={"GMC","Yukon"}, ["camry"]={"Toyota","Camry"},
    ["newcamry"]={"Toyota","Camry"}, ["avalon"]={"Toyota","Avalon"},
    ["kona"]={"Hyundai","Kona"}, ["cruze"]={"Chevrolet","Cruze"},
    ["malibu"]={"Chevrolet","Malibu"}, ["levante"]={"Maserati","Levante"},
    ["aurion"]={"Toyota","Aurion"}, ["impala"]={"Chevrolet","Impala"},
    ["spark"]={"Chevrolet","Spark"}, ["emgrand"]={"Geely","Emgrand"},
    ["soqoia"]={"Toyota","Sequoia"}, ["sequoia"]={"Toyota","Sequoia"},
    ["cheryarrizo"]={"Chery","Arrizo 8"}, ["lexusls"]={"Lexus","LS 600h"},
    ["camaro"]={"Chevrolet","Camaro"}, ["cadinza"]={"Kia","Cadenza"},
    ["cadenza"]={"Kia","Cadenza"}, ["serra"]={"GMC","Sierra"}, ["serao"]={"GMC","Sierra"},
    ["sierra"]={"GMC","Sierra"}, ["charger"]={"Dodge","Charger"},
    ["sonata"]={"Hyundai","Sonata"}, ["altima"]={"Nissan","Altima"},
    ["sonera"]={"Hyundai","Sonata"}, ["azera"]={"Hyundai","Azera"},
    ["optima"]={"Kia","Optima"}, ["maxima"]={"Nissan","Maxima"},
    ["caprice"]={"Chevrolet","Caprice"}, ["supra"]={"Toyota","Supra"},
    ["mustang"]={"Ford","Mustang"}, ["tahoe"]={"Chevrolet","Tahoe"},
    ["patrol"]={"Nissan","Patrol"}, ["telluride"]={"Kia","Telluride"},
    ["sportage"]={"Kia","Sportage"}, ["palisade"]={"Hyundai","Palisade"},
    ["crown"]={"Toyota","Crown"}, ["hilux"]={"Toyota","Hilux"},
    ["yaris"]={"Toyota","Yaris"}, ["fusion"]={"Ford","Fusion"},
    ["altera"]={"Nissan","Altima"}, ["aura"]={"Audi","S4"},
}

local function codeTokens(carName)
    local s = tostring(carName)
    local out = {}
    local alnum = s:match("^(%a+%d+)")
    if alnum then out[#out+1] = alnum:lower() end
    local alpha = s:match("^(%a+)")
    if alpha then out[#out+1] = alpha:lower() end
    return out
end

local function lookupCar(carName, price)
    if carName then
        for _, tok in ipairs(codeTokens(carName)) do
            local cm = DATA.CODE_MAP[tok]
            if cm then
                local rarity = "Standard"
                for _, e in ipairs(DATA.CARDB) do
                    if e[2] == cm[1] and e[3] == cm[2] then rarity = e[4]; break end
                end
                return {game=carName, make=cm[1], model=cm[2], rarity=rarity, buy=price or 0}
            end
        end
        local target = normName(carName)
        if target ~= "" then
            for _, e in ipairs(DATA.CARDB) do
                if normName(e[1]) == target then
                    return {game=e[1], make=e[2], model=e[3], rarity=e[4], buy=e[5]}
                end
            end
        end
    end
    return nil
end

local function fmtPrice(n)
    if n >= 1000000 then return string.format("%.2fM", n/1000000)
    elseif n >= 1000 then return string.format("%.0fK", n/1000)
    else return tostring(n) end
end

-- ═══════════════ GUI ROOT ═══════════════
local gui = Instance.new("ScreenGui")
gui.Name = "LSX_CS2"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

-- ─────────── LOADING SCREEN ───────────
local function showLoadingScreen(onDone)
    local load = Instance.new("Frame", gui)
    load.Size = UDim2.new(1, 0, 1, 0); load.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
    load.BackgroundTransparency = 0; load.ZIndex = 100; load.BorderSizePixel = 0

    local glow = Instance.new("Frame", load)
    glow.Size = UDim2.new(0, 400, 0, 400); glow.Position = UDim2.new(0.5, -200, 0.5, -200)
    glow.BackgroundColor3 = T.blue; glow.BackgroundTransparency = 0.9; glow.BorderSizePixel = 0
    glow.ZIndex = 100; corner(glow, 200)

    local title = Instance.new("TextLabel", load)
    title.Size = UDim2.new(0, 400, 0, 80); title.Position = UDim2.new(0.5, -200, 0.5, -80)
    title.BackgroundTransparency = 1; title.Text = "LSX"; title.TextColor3 = T.text
    title.Font = Enum.Font.GothamBold; title.TextSize = 64; title.ZIndex = 101
    H.gradient(title, T.text, T.blueLight, 90)

    local sub = Instance.new("TextLabel", load)
    sub.Size = UDim2.new(0, 400, 0, 24); sub.Position = UDim2.new(0.5, -200, 0.5, 6)
    sub.BackgroundTransparency = 1; sub.Text = "Car Sales 2"; sub.TextColor3 = T.textSec
    sub.Font = Enum.Font.GothamMedium; sub.TextSize = 16; sub.ZIndex = 101

    local barBg = Instance.new("Frame", load)
    barBg.Size = UDim2.new(0, 240, 0, 4); barBg.Position = UDim2.new(0.5, -120, 0.5, 50)
    barBg.BackgroundColor3 = T.card; barBg.BorderSizePixel = 0; barBg.ZIndex = 101; corner(barBg, 99)
    local bar = Instance.new("Frame", barBg)
    bar.Size = UDim2.new(0, 0, 1, 0); bar.BackgroundColor3 = T.blue; bar.BorderSizePixel = 0
    bar.ZIndex = 102; corner(bar, 99); H.gradient(bar, T.blue, T.blueLight, 0)

    local stat = Instance.new("TextLabel", load)
    stat.Size = UDim2.new(0, 240, 0, 18); stat.Position = UDim2.new(0.5, -120, 0.5, 62)
    stat.BackgroundTransparency = 1; stat.Text = "Initializing..."; stat.TextColor3 = T.textTer
    stat.Font = Enum.Font.Gotham; stat.TextSize = 11; stat.ZIndex = 101

    local credit = Instance.new("TextLabel", load)
    credit.Size = UDim2.new(1, 0, 0, 18); credit.Position = UDim2.new(0, 0, 1, -34)
    credit.BackgroundTransparency = 1; credit.Text = "by Kyzen  |  discord.gg/UG4TujqUeq"
    credit.TextColor3 = T.textTer; credit.Font = Enum.Font.Gotham; credit.TextSize = 11; credit.ZIndex = 101

    task.spawn(function()
        local steps = {"Initializing...", "Loading car database...", "Hooking market...", "Building interface...", "Ready"}
        for i, s in ipairs(steps) do
            stat.Text = s
            TweenService:Create(bar, TweenInfo.new(0.35), {Size = UDim2.new(i/#steps, 0, 1, 0)}):Play()
            task.wait(0.32)
        end
        task.wait(0.2)
        TweenService:Create(load, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        TweenService:Create(title, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        for _, c in ipairs({sub, stat, credit}) do
            TweenService:Create(c, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        end
        TweenService:Create(barBg, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        TweenService:Create(bar, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        TweenService:Create(glow, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        task.wait(0.45)
        load:Destroy()
        if onDone then onDone() end
    end)
end

-- ─────────── NOTIFICATIONS ───────────
local notifHolder = Instance.new("Frame", gui)
notifHolder.Size = UDim2.new(0, 320, 1, -40); notifHolder.Position = UDim2.new(1, -332, 0, 20)
notifHolder.BackgroundTransparency = 1; notifHolder.ZIndex = 50
local notifLay = Instance.new("UIListLayout", notifHolder)
notifLay.SortOrder = Enum.SortOrder.LayoutOrder; notifLay.Padding = UDim.new(0, 8)
notifLay.VerticalAlignment = Enum.VerticalAlignment.Top
notifLay.HorizontalAlignment = Enum.HorizontalAlignment.Right

local function notify(title, body, col)
    col = col or accentColor
    local card = Instance.new("Frame", notifHolder)
    card.Size = UDim2.new(0, 300, 0, 64); card.BackgroundColor3 = T.bgGlass
    card.BackgroundTransparency = 0.05; card.BorderSizePixel = 0; card.ZIndex = 51
    card.Position = UDim2.new(1, 320, 0, 0); corner(card, 10); stroke(card, T.cardBorder, 0.3)

    local accent = Instance.new("Frame", card)
    accent.Size = UDim2.new(0, 4, 1, -16); accent.Position = UDim2.new(0, 0, 0, 8)
    accent.BackgroundColor3 = col; accent.BorderSizePixel = 0; accent.ZIndex = 52; corner(accent, 99)

    local t = Instance.new("TextLabel", card)
    t.Size = UDim2.new(1, -28, 0, 20); t.Position = UDim2.new(0, 16, 0, 10)
    t.BackgroundTransparency = 1; t.Text = title; t.TextColor3 = T.text
    t.Font = Enum.Font.GothamBold; t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = 52; t.TextTruncate = Enum.TextTruncate.AtEnd

    local b = Instance.new("TextLabel", card)
    b.Size = UDim2.new(1, -28, 0, 28); b.Position = UDim2.new(0, 16, 0, 30)
    b.BackgroundTransparency = 1; b.Text = body; b.TextColor3 = T.textSec
    b.Font = Enum.Font.Gotham; b.TextSize = 11; b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextYAlignment = Enum.TextYAlignment.Top; b.TextWrapped = true; b.ZIndex = 52

    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, 0, 0, 0)}):Play()
    task.delay(4.5, function()
        TweenService:Create(card, TweenInfo.new(0.3), {Position = UDim2.new(1, 320, 0, 0)}):Play()
        task.wait(0.32); card:Destroy()
    end)
end

-- ─────────── MAIN WINDOW ───────────
local MAIN_W, FULL_H = 920, 600
local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, MAIN_W, 0, FULL_H)
main.Position = UDim2.new(0.5, -MAIN_W/2, 0.5, -FULL_H/2)
main.BackgroundColor3 = T.bg; main.BackgroundTransparency = 0.08
main.BorderSizePixel = 0; main.Visible = false; corner(main, 14); stroke(main, T.cardBorder, 0.2)

local mainGrad = Instance.new("Frame", main)
mainGrad.Size = UDim2.new(1,0,1,0); mainGrad.BackgroundColor3 = T.bg
mainGrad.BackgroundTransparency = 0.4; mainGrad.BorderSizePixel = 0; corner(mainGrad, 14)
H.gradient(mainGrad, Color3.fromRGB(14,18,28), Color3.fromRGB(8,10,14), 135)

-- Title bar
local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1, 0, 0, 54); titleBar.BackgroundTransparency = 1; titleBar.BorderSizePixel = 0

local logoTxt = Instance.new("TextLabel", titleBar)
logoTxt.Size = UDim2.new(0, 120, 0, 30); logoTxt.Position = UDim2.new(0, 20, 0, 12)
logoTxt.BackgroundTransparency = 1; logoTxt.Text = "LSX"; logoTxt.TextColor3 = T.text
logoTxt.Font = Enum.Font.GothamBold; logoTxt.TextSize = 26; logoTxt.TextXAlignment = Enum.TextXAlignment.Left
H.gradient(logoTxt, T.text, T.blueLight, 90)

local subTitle = Instance.new("TextLabel", titleBar)
subTitle.Size = UDim2.new(0, 200, 0, 16); subTitle.Position = UDim2.new(0, 66, 0, 20)
subTitle.BackgroundTransparency = 1; subTitle.Text = "Car Sales 2"; subTitle.TextColor3 = T.textTer
subTitle.Font = Enum.Font.GothamMedium; subTitle.TextSize = 12; subTitle.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -42, 0, 12)
closeBtn.BackgroundColor3 = T.card; closeBtn.BackgroundTransparency = 0.3
closeBtn.Text = "X"; closeBtn.TextColor3 = T.textSec; closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold; closeBtn.BorderSizePixel = 0; closeBtn.AutoButtonColor = false
corner(closeBtn, 8)

-- Body container
local body = Instance.new("Frame", main)
body.Size = UDim2.new(1, -24, 1, -66); body.Position = UDim2.new(0, 12, 0, 56)
body.BackgroundTransparency = 1; body.BorderSizePixel = 0

-- Sidebar
local sidebar = Instance.new("Frame", body)
sidebar.Size = UDim2.new(0, 160, 1, 0); sidebar.BackgroundColor3 = T.sidebar
sidebar.BackgroundTransparency = 0.25; sidebar.BorderSizePixel = 0; corner(sidebar, 10)
stroke(sidebar, T.cardBorder, 0.5)
local sideLay = Instance.new("UIListLayout", sidebar)
sideLay.SortOrder = Enum.SortOrder.LayoutOrder; sideLay.Padding = UDim.new(0, 4)
local sidePad = Instance.new("UIPadding", sidebar)
sidePad.PaddingTop = UDim.new(0, 10); sidePad.PaddingLeft = UDim.new(0, 10); sidePad.PaddingRight = UDim.new(0, 10)

-- Content area
local content = Instance.new("Frame", body)
content.Size = UDim2.new(1, -172, 1, 0); content.Position = UDim2.new(0, 172, 0, 0)
content.BackgroundTransparency = 1; content.BorderSizePixel = 0

-- ─────────── TAB SYSTEM ───────────
local TABS = {"Main", "Cars", "ESP", "Movement", "Teleport", "Misc", "Settings", "Credits"}
local tabPanels = {}
local tabBtns = {}
local currentTab = nil

for i, name in ipairs(TABS) do
    local btn = Instance.new("TextButton", sidebar)
    btn.Size = UDim2.new(1, 0, 0, 38); btn.BackgroundColor3 = T.card
    btn.BackgroundTransparency = 1; btn.Text = ""; btn.BorderSizePixel = 0
    btn.AutoButtonColor = false; btn.LayoutOrder = i; corner(btn, 8)

    local ind = Instance.new("Frame", btn)
    ind.Size = UDim2.new(0, 3, 0.5, 0); ind.Position = UDim2.new(0, 0, 0.25, 0)
    ind.BackgroundColor3 = accentColor; ind.BorderSizePixel = 0
    ind.BackgroundTransparency = 1; corner(ind, 99)
    registerAccent(ind, "BackgroundColor3")  -- FIX 1

    local lbl = Instance.new("TextLabel", btn)
    lbl.Size = UDim2.new(1, -16, 1, 0); lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = name; lbl.TextColor3 = T.textSec
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left

    tabBtns[name] = {btn=btn, ind=ind, lbl=lbl}

    -- Scrolling panel
    local panel = Instance.new("ScrollingFrame", content)
    panel.Size = UDim2.new(1, 0, 1, 0); panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0; panel.Visible = false
    panel.ScrollBarThickness = 4; panel.ScrollBarImageColor3 = T.textTer
    panel.CanvasSize = UDim2.new(0, 0, 0, 0); panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    panel.ScrollingDirection = Enum.ScrollingDirection.Y
    local pLay = Instance.new("UIListLayout", panel)
    pLay.SortOrder = Enum.SortOrder.LayoutOrder; pLay.Padding = UDim.new(0, 10)
    local pPad = Instance.new("UIPadding", panel)
    pPad.PaddingRight = UDim.new(0, 8); pPad.PaddingBottom = UDim.new(0, 10)

    tabPanels[name] = {panel = panel, built = false}
end

local function switchTab(name)
    currentTab = name
    for n, t in pairs(tabBtns) do
        local active = (n == name)
        tabPanels[n].panel.Visible = active
        TweenService:Create(t.btn, TweenInfo.new(0.15), {BackgroundTransparency = active and 0.2 or 1}):Play()
        TweenService:Create(t.ind, TweenInfo.new(0.15), {BackgroundTransparency = active and 0 or 1}):Play()
        TweenService:Create(t.lbl, TweenInfo.new(0.15), {TextColor3 = active and T.text or T.textSec}):Play()
    end
end

for n, t in pairs(tabBtns) do
    t.btn.MouseButton1Click:Connect(function() switchTab(n) end)
    t.btn.MouseEnter:Connect(function()
        if currentTab == n then return end
        TweenService:Create(t.btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.6}):Play()
    end)
    t.btn.MouseLeave:Connect(function()
        if currentTab == n then return end
        TweenService:Create(t.btn, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
    end)
end

-- ─────────── REUSABLE CONTROLS ───────────
H.mkToggle = function(parent, labelText, descText, default, order, callback)
    local card = H.mkCard(parent, descText ~= "" and 56 or 44, order)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -80, 0, 20); lbl.Position = UDim2.new(0, 14, 0, descText ~= "" and 10 or 12)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = T.text
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left
    if descText ~= "" then
        local d = Instance.new("TextLabel", card)
        d.Size = UDim2.new(1, -80, 0, 16); d.Position = UDim2.new(0, 14, 0, 32)
        d.BackgroundTransparency = 1; d.Text = descText; d.TextColor3 = T.textSec
        d.Font = Enum.Font.Gotham; d.TextSize = 11; d.TextXAlignment = Enum.TextXAlignment.Left
    end
    local sw = Instance.new("TextButton", card)
    sw.Size = UDim2.new(0, 46, 0, 24); sw.Position = UDim2.new(1, -60, 0.5, -12)
    sw.BackgroundColor3 = default and accentColor or T.card; sw.Text = ""
    sw.BorderSizePixel = 0; sw.AutoButtonColor = false; corner(sw, 12); stroke(sw, T.cardBorder, 0.4)
    -- FIX 1: register toggle bg for accent
    if default then registerAccent(sw, "BackgroundColor3") end
    local knob = Instance.new("Frame", sw)
    knob.Size = UDim2.new(0, 18, 0, 18); knob.Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.BorderSizePixel = 0; corner(knob, 9)
    local val = default
    sw.MouseButton1Click:Connect(function()
        val = not val
        if val then
            registerAccent(sw, "BackgroundColor3")
            TweenService:Create(sw, TweenInfo.new(0.18), {BackgroundColor3 = accentColor}):Play()
        else
            -- Remove from accent registry
            for i = #accentObjects, 1, -1 do
                if accentObjects[i].obj == sw then table.remove(accentObjects, i); break end
            end
            TweenService:Create(sw, TweenInfo.new(0.18), {BackgroundColor3 = T.card}):Play()
        end
        TweenService:Create(knob, TweenInfo.new(0.18), {Position = val and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)}):Play()
        callback(val)
    end)
    return card, function(v)
        val = v
        sw.BackgroundColor3 = v and accentColor or T.card
        knob.Position = v and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    end
end

H.mkSlider = function(parent, labelText, minV, maxV, default, order, callback)
    local card = H.mkCard(parent, 60, order)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -80, 0, 20); lbl.Position = UDim2.new(0, 14, 0, 10)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = T.text
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local valLbl = Instance.new("TextLabel", card)
    valLbl.Size = UDim2.new(0, 60, 0, 20); valLbl.Position = UDim2.new(1, -74, 0, 10)
    valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(default); valLbl.TextColor3 = accentColor
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 13; valLbl.TextXAlignment = Enum.TextXAlignment.Right
    registerAccent(valLbl, "TextColor3")  -- FIX 1
    local track = Instance.new("Frame", card)
    track.Size = UDim2.new(1, -28, 0, 6); track.Position = UDim2.new(0, 14, 0, 40)
    track.BackgroundColor3 = T.card; track.BorderSizePixel = 0; corner(track, 99); stroke(track, T.cardBorder, 0.5)
    local fill = Instance.new("Frame", track)
    local pct = (default - minV) / (maxV - minV)
    fill.Size = UDim2.new(pct, 0, 1, 0); fill.BackgroundColor3 = accentColor; fill.BorderSizePixel = 0; corner(fill, 99)
    registerAccent(fill, "BackgroundColor3")  -- FIX 1
    H.gradient(fill, T.blue, T.blueLight, 0)
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14); knob.Position = UDim2.new(pct, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.BorderSizePixel = 0; knob.ZIndex = 3; corner(knob, 7)
    local dragging = false
    local function update(inputX)
        local rel = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor(minV + (maxV - minV) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        valLbl.Text = tostring(v)
        callback(v)
    end
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(inp.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then update(inp.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    return card
end

H.mkButton = function(parent, labelText, btnText, col, order, callback)
    local card = H.mkCard(parent, 48, order)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -120, 1, 0); lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = T.text
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 96, 0, 32); btn.Position = UDim2.new(1, -108, 0.5, -16)
    btn.BackgroundColor3 = col or accentColor; btn.TextColor3 = Color3.fromRGB(8,8,8)
    btn.Text = btnText; btn.TextSize = 12; btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false; corner(btn, 8)
    -- FIX 1: register accent buttons that use accentColor
    if col == nil or col == accentColor then registerAccent(btn, "BackgroundColor3") end
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency=0.2}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency=0}):Play() end)
    btn.MouseButton1Click:Connect(function() callback(btn) end)
    return card, btn
end

-- ═══════════════ MAIN TAB ═══════════════
local B = {}
B.buildMainTab = function()
    local panel = tabPanels["Main"].panel

    local hero = H.mkCard(panel, 110, 0)
    local av = Instance.new("ImageLabel", hero)
    av.Size = UDim2.new(0, 72, 0, 72); av.Position = UDim2.new(0, 18, 0, 19)
    av.BackgroundColor3 = T.card; av.BorderSizePixel = 0; corner(av, 36)
    local avStroke = stroke(av, accentColor, 0.2)
    registerAccent(avStroke, "Color")  -- FIX 1
    pcall(function()
        av.Image = Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    local greet = Instance.new("TextLabel", hero)
    greet.Size = UDim2.new(1, -120, 0, 28); greet.Position = UDim2.new(0, 104, 0, 28)
    greet.BackgroundTransparency = 1; greet.Text = "Welcome, " .. dispName; greet.TextColor3 = T.text
    greet.Font = Enum.Font.GothamBold; greet.TextSize = 20; greet.TextXAlignment = Enum.TextXAlignment.Left
    local uname = Instance.new("TextLabel", hero)
    uname.Size = UDim2.new(1, -120, 0, 18); uname.Position = UDim2.new(0, 104, 0, 56)
    uname.BackgroundTransparency = 1; uname.Text = "@" .. username; uname.TextColor3 = T.textSec
    uname.Font = Enum.Font.Gotham; uname.TextSize = 13; uname.TextXAlignment = Enum.TextXAlignment.Left

    H.mkSection(panel, "QUICK ACTIONS", 1)
    H.mkButton(panel, "Cars Dealership", "GO", accentColor, 2, function()
        local p = getTpPart("Dealership"); if p then tpToPos(p.Position, 3, 0); notify("Teleported", "Cars Dealership", accentColor) end
    end)
    H.mkButton(panel, "The Neighborhood", "GO", accentColor, 3, function()
        local p = getTpPart("Neighborhood"); if p then tpToPos(p.Position, 3, 0); notify("Teleported", "The Neighborhood", accentColor) end
    end)
    H.mkButton(panel, "Your Dealership", "GO", T.green, 4, function()
        local plot = findMyPlot()
        local tp = getPlotTpPart(plot)
        if tp then tpToPos(tp.Position, 3, 0); notify("Teleported", "Your Dealership ("..(plot and plot.Name or "?")..")", T.green)
        else notify("Not Found", "Could not find your plot", T.red) end
    end)

    H.mkSection(panel, "ABOUT", 5)
    local about = H.mkCard(panel, 70, 6)
    local at = Instance.new("TextLabel", about)
    at.Size = UDim2.new(1, -28, 0, 20); at.Position = UDim2.new(0, 14, 0, 12)
    at.BackgroundTransparency = 1; at.Text = "LSX | Car Sales 2"; at.TextColor3 = T.text
    at.Font = Enum.Font.GothamBold; at.TextSize = 14; at.TextXAlignment = Enum.TextXAlignment.Left
    local ab = Instance.new("TextLabel", about)
    ab.Size = UDim2.new(1, -28, 0, 18); ab.Position = UDim2.new(0, 14, 0, 36)
    ab.BackgroundTransparency = 1; ab.Text = "Press "..menuBind.Name.." to toggle  -  by Kyzen"; ab.TextColor3 = T.textSec
    ab.Font = Enum.Font.Gotham; ab.TextSize = 12; ab.TextXAlignment = Enum.TextXAlignment.Left
end

-- ═══════════════ CARS TAB ═══════════════
-- FIX 2: Reordered to Lowest Mileage, Cheapest, Most Expensive
-- FIX 2: Auto-refresh synced with dealership timer
B.buildCarsTab = function()
    local panel = tabPanels["Cars"].panel

    local function getSlotPart(slot)
        local npc = slot:FindFirstChild("NpcSlot")
        if npc and npc:IsA("BasePart") then return npc end
        if npc then local p = npc:FindFirstChildWhichIsA("BasePart"); if p then return p end end
        local cs = slot:FindFirstChild("CarSlot")
        if cs and cs:IsA("BasePart") then return cs end
        if cs then local p = cs:FindFirstChildWhichIsA("BasePart"); if p then return p end end
        for _, child in ipairs(slot:GetChildren()) do
            if child:IsA("Model") then
                local pp = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                if pp then return pp end
            end
        end
        for _, d in ipairs(slot:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
        return nil
    end

    local function scanCars()
        local results = {}
        local slots = Workspace:FindFirstChild("Slots")
        if not slots then return results end
        for _, slot in ipairs(slots:GetChildren()) do
            local price = slot:GetAttribute("Price")
            local owner = slot:GetAttribute("CurrentUser") or ""
            local isLoaded = slot:GetAttribute("IsLoaded")
            if price and type(price)=="number" and price > 0
               and (owner == nil or owner == "")
               and (isLoaded == nil or isLoaded == true) then
                local part = getSlotPart(slot)
                local carName = tostring(slot:GetAttribute("CarName") or slot.Name)
                local year = tostring(slot:GetAttribute("Year") or "")
                local mileage = slot:GetAttribute("Mileage") or 0
                local info = lookupCar(carName, price)
                results[#results+1] = {
                    slot=slot, part=part, price=price, carName=carName, year=year,
                    mileage=(type(mileage)=="number" and mileage or 0), info=info,
                }
            end
        end
        return results
    end

    -- FIX 4: use improved car teleport
    local function tpToCar(car)
        if not hrp or not hrp.Parent then return false end
        local part = car.part
        if not part or not part.Parent then part = getSlotPart(car.slot) end
        return tpToCarPart(part, car.slot and car.slot:IsA("BasePart") and car.slot.Position or nil)
    end

    local function dispName2(car)
        if car.info then
            return car.info.make .. " " .. car.info.model .. " (" .. car.carName .. (car.year~="" and " "..car.year or "") .. ")"
        end
        return car.carName .. (car.year~="" and " "..car.year or "")
    end

    -- Overview
    H.mkSection(panel, "MARKET OVERVIEW", 0)
    local ov = H.mkCard(panel, 46, 1)
    local ovc = Instance.new("TextLabel", ov)
    ovc.Size = UDim2.new(1,-110,1,0); ovc.Position = UDim2.new(0,14,0,0)
    ovc.BackgroundTransparency=1; ovc.TextColor3=T.textSec; ovc.TextSize=12
    ovc.Font=Enum.Font.GothamMedium; ovc.TextXAlignment=Enum.TextXAlignment.Left; ovc.Text="Scanning..."
    local refBtn = Instance.new("TextButton", ov)
    refBtn.Size = UDim2.new(0,84,0,30); refBtn.Position = UDim2.new(1,-96,0.5,-15)
    refBtn.BackgroundColor3 = accentColor; refBtn.TextColor3 = Color3.fromRGB(8,8,8)
    refBtn.Text = "REFRESH"; refBtn.TextSize = 11; refBtn.Font = Enum.Font.GothamBold
    refBtn.BorderSizePixel = 0; refBtn.AutoButtonColor = false; corner(refBtn, 8)
    registerAccent(refBtn, "BackgroundColor3")  -- FIX 1

    -- Result card factory
    local function resultCard(title, col, order)
        local card = H.mkCard(panel, 86, order)
        local bar = Instance.new("Frame", card); bar.Size=UDim2.new(0,4,1,-14); bar.Position=UDim2.new(0,0,0,7)
        bar.BackgroundColor3=col; bar.BorderSizePixel=0; corner(bar,99)
        local nameL = Instance.new("TextLabel", card)
        nameL.Size=UDim2.new(1,-130,0,22); nameL.Position=UDim2.new(0,16,0,10)
        nameL.BackgroundTransparency=1; nameL.TextColor3=T.text; nameL.TextSize=14
        nameL.Font=Enum.Font.GothamBold; nameL.TextXAlignment=Enum.TextXAlignment.Left
        nameL.TextTruncate=Enum.TextTruncate.AtEnd; nameL.Text="Press scan"
        local priceL = Instance.new("TextLabel", card)
        priceL.Size=UDim2.new(1,-130,0,18); priceL.Position=UDim2.new(0,16,0,34)
        priceL.BackgroundTransparency=1; priceL.TextColor3=col; priceL.TextSize=13
        priceL.Font=Enum.Font.GothamBold; priceL.TextXAlignment=Enum.TextXAlignment.Left; priceL.Text=""
        local subL = Instance.new("TextLabel", card)
        subL.Size=UDim2.new(1,-130,0,16); subL.Position=UDim2.new(0,16,0,56)
        subL.BackgroundTransparency=1; subL.TextColor3=T.textSec; subL.TextSize=11
        subL.Font=Enum.Font.Gotham; subL.TextXAlignment=Enum.TextXAlignment.Left; subL.Text=title
        local goBtn = Instance.new("TextButton", card)
        goBtn.Size=UDim2.new(0,84,0,56); goBtn.Position=UDim2.new(1,-96,0.5,-28)
        goBtn.BackgroundColor3=col; goBtn.TextColor3=Color3.fromRGB(8,8,8)
        goBtn.Text="GO"; goBtn.TextSize=14; goBtn.Font=Enum.Font.GothamBold
        goBtn.BorderSizePixel=0; goBtn.AutoButtonColor=false; corner(goBtn,10)
        goBtn.MouseEnter:Connect(function() TweenService:Create(goBtn,TweenInfo.new(0.12),{BackgroundTransparency=0.2}):Play() end)
        goBtn.MouseLeave:Connect(function() TweenService:Create(goBtn,TweenInfo.new(0.12),{BackgroundTransparency=0}):Play() end)
        return card, nameL, priceL, subL, goBtn
    end

    -- FIX 2: Reordered sections - Lowest Mileage first, Cheapest second, Most Expensive third
    H.mkSection(panel, "LOWEST MILEAGE CAR", 2)
    local _, mN, mP, mS, mGo = resultCard("Least driven in market", T.blueLight, 3)
    H.mkSection(panel, "CHEAPEST CAR", 4)
    local _, cN, cP, cS, cGo = resultCard("Lowest price in market", T.green, 5)
    H.mkSection(panel, "MOST EXPENSIVE CAR", 6)
    local _, eN, eP, eS, eGo = resultCard("Highest price in market", Color3.fromRGB(255,159,10), 7)

    H.mkSection(panel, "ALL CARS FOR SALE (CHEAPEST FIRST)", 8)
    local listScroll = Instance.new("ScrollingFrame", panel)
    listScroll.Size = UDim2.new(1, 0, 0, 320); listScroll.BackgroundColor3 = T.card
    listScroll.BackgroundTransparency = 0.5; listScroll.BorderSizePixel = 0
    listScroll.ScrollBarThickness = 4; listScroll.ScrollBarImageColor3 = T.textTer
    listScroll.CanvasSize = UDim2.new(0,0,0,0); listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.ScrollingDirection = Enum.ScrollingDirection.Y; listScroll.LayoutOrder = 9
    corner(listScroll, 10); stroke(listScroll, T.cardBorder, 0.4)
    local listLay = Instance.new("UIListLayout", listScroll)
    listLay.SortOrder = Enum.SortOrder.LayoutOrder; listLay.Padding = UDim.new(0, 3)
    local listPad = Instance.new("UIPadding", listScroll)
    listPad.PaddingTop = UDim.new(0,6); listPad.PaddingBottom = UDim.new(0,6)
    listPad.PaddingLeft = UDim.new(0,6); listPad.PaddingRight = UDim.new(0,6)

    local cheapCar, expCar, lowMileCar

    local function buildList(cars)
        for _, ch in ipairs(listScroll:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end
        for i, car in ipairs(cars) do
            local row = Instance.new("Frame", listScroll)
            row.Size = UDim2.new(1, 0, 0, 46); row.BackgroundColor3 = T.bgGlass
            row.BackgroundTransparency = 0.2; row.BorderSizePixel = 0; row.LayoutOrder = i
            corner(row, 6); stroke(row, T.cardBorder, 0.6)
            local info = car.info
            -- FIX 5: Only show rarity color if rarity is known (not ?)
            local rcolor = info and DATA.RARITY_COL[info.rarity] and rcol(info.rarity) or T.textTer
            local rb = Instance.new("Frame", row); rb.Size=UDim2.new(0,3,1,-8); rb.Position=UDim2.new(0,0,0,4)
            rb.BackgroundColor3=rcolor; rb.BorderSizePixel=0; corner(rb,99)
            local rank = Instance.new("TextLabel", row); rank.Text="#"..i
            rank.Size=UDim2.new(0,28,1,0); rank.Position=UDim2.new(0,6,0,0)
            rank.BackgroundTransparency=1; rank.TextColor3=T.textTer; rank.TextSize=10
            rank.Font=Enum.Font.GothamBold; rank.TextXAlignment=Enum.TextXAlignment.Center
            local nm = Instance.new("TextLabel", row)
            nm.Text = dispName2(car); nm.Size=UDim2.new(0.46,0,0,18); nm.Position=UDim2.new(0,38,0,6)
            nm.BackgroundTransparency=1; nm.TextColor3=T.text; nm.TextSize=12
            nm.Font=Enum.Font.GothamBold; nm.TextXAlignment=Enum.TextXAlignment.Left; nm.TextTruncate=Enum.TextTruncate.AtEnd
            -- FIX 5: Don't show "?" rarity - show nothing if unknown
            local rarityStr = (info and DATA.RARITY_COL[info.rarity]) and info.rarity or ""
            local metaText = rarityStr ~= "" and (rarityStr .. "  -  " .. fmtPrice(car.price) .. " SAR") or (fmtPrice(car.price) .. " SAR")
            local meta = Instance.new("TextLabel", row)
            meta.Text = metaText
            meta.Size=UDim2.new(0.46,0,0,14); meta.Position=UDim2.new(0,38,0,25)
            meta.BackgroundTransparency=1; meta.TextColor3=rcolor; meta.TextSize=10
            meta.Font=Enum.Font.Gotham; meta.TextXAlignment=Enum.TextXAlignment.Left
            local go = Instance.new("TextButton", row)
            go.Size=UDim2.new(0,60,0,30); go.Position=UDim2.new(1,-68,0.5,-15)
            go.BackgroundColor3=accentColor; go.TextColor3=Color3.fromRGB(8,8,8)
            go.Text="GO"; go.TextSize=12; go.Font=Enum.Font.GothamBold
            go.BorderSizePixel=0; go.AutoButtonColor=false; corner(go,8)
            registerAccent(go, "BackgroundColor3")  -- FIX 1
            local thisCar = car
            go.MouseButton1Click:Connect(function()
                if tpToCar(thisCar) then notify("Teleported", dispName2(thisCar).." - Hold E", accentColor) end
            end)
        end
    end

    local function doRefresh()
        local cars = scanCars()
        ovc.Text = #cars .. " cars for sale"
        ovc.TextColor3 = #cars > 0 and T.green or T.red
        if #cars == 0 then
            mN.Text="No cars"; mP.Text=""; cN.Text="No cars"; cP.Text=""; eN.Text="No cars"; eP.Text=""
            buildList({})
            return
        end
        table.sort(cars, function(a,b) return a.price < b.price end)
        cheapCar = cars[1]; expCar = cars[#cars]
        cN.Text = dispName2(cheapCar); cP.Text = fmtPrice(cheapCar.price).." SAR"
        eN.Text = dispName2(expCar);   eP.Text = fmtPrice(expCar.price).." SAR"
        local withMiles = {}
        for _, c in ipairs(cars) do if c.mileage > 0 then withMiles[#withMiles+1] = c end end
        if #withMiles > 0 then
            table.sort(withMiles, function(a,b) return a.mileage < b.mileage end)
            lowMileCar = withMiles[1]
            mN.Text = dispName2(lowMileCar)
            mP.Text = string.format("%d mi  -  %s SAR", lowMileCar.mileage, fmtPrice(lowMileCar.price))
        else
            lowMileCar = nil
            mN.Text = "No mileage data"; mP.Text = "Mileage not available in market"
        end
        buildList(cars)
    end

    mGo.MouseButton1Click:Connect(function() if lowMileCar and tpToCar(lowMileCar) then notify("Teleported", dispName2(lowMileCar).." - Hold E", T.blueLight) end end)
    cGo.MouseButton1Click:Connect(function() if cheapCar and tpToCar(cheapCar) then notify("Teleported", dispName2(cheapCar).." - Hold E", T.green) end end)
    eGo.MouseButton1Click:Connect(function() if expCar and tpToCar(expCar) then notify("Teleported", dispName2(expCar).." - Hold E", Color3.fromRGB(255,159,10)) end end)
    refBtn.MouseButton1Click:Connect(doRefresh)

    task.spawn(function() task.wait(0.5); doRefresh() end)

    -- FIX 2: auto-refresh synced with dealership reset timer
    -- Watch the reset timer and trigger refresh when it hits 0 (reset fires)
    task.spawn(function()
        local lastSeconds = nil
        while panel.Parent do
            task.wait(1)
            local drt = Workspace:FindFirstChild("DealershipResetTimer")
            if drt then
                for _, v in ipairs(drt:GetDescendants()) do
                    if v:IsA("TextLabel") then
                        local t = v.Text or ""
                        local mm, ss = t:match("(%d+):(%d+)")
                        if mm and ss then
                            local secs = tonumber(mm)*60 + tonumber(ss)
                            -- Detect reset: last tick was near 0, now jumped up (reset happened)
                            if lastSeconds and lastSeconds <= 5 and secs > 10 then
                                task.wait(1.5)  -- small delay for market to update
                                doRefresh()
                                notify("Market Refreshed", "Dealership reset - market updated", accentColor)
                            end
                            lastSeconds = secs
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- ═══════════════ ESP SYSTEM ═══════════════
local Camera = Workspace.CurrentCamera
local espHolder = Instance.new("Folder", gui); espHolder.Name = "LSX_ESP"

local carEspTags = {}

local E = {}
E.makeCarTag = function(slot, part)
    local bb = Instance.new("BillboardGui")
    bb.Name = "carTag"; bb.Adornee = part; bb.Size = UDim2.new(0, 170, 0, 56)
    bb.AlwaysOnTop = true; bb.MaxDistance = 600; bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Parent = espHolder
    local frame = Instance.new("Frame", bb)
    frame.Size = UDim2.new(1,0,1,0); frame.BackgroundColor3 = T.bg
    frame.BackgroundTransparency = 0.25; frame.BorderSizePixel = 0; corner(frame, 8)
    local fStroke = stroke(frame, accentColor, 0.3)
    registerAccent(fStroke, "Color")  -- FIX 1
    local nameL = Instance.new("TextLabel", frame)
    nameL.Size = UDim2.new(1,-8,0,18); nameL.Position = UDim2.new(0,4,0,4)
    nameL.BackgroundTransparency = 1; nameL.TextColor3 = T.text; nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 12; nameL.Text = "Car"
    local priceL = Instance.new("TextLabel", frame)
    priceL.Size = UDim2.new(1,-8,0,14); priceL.Position = UDim2.new(0,4,0,22)
    priceL.BackgroundTransparency = 1; priceL.TextColor3 = T.green; priceL.Font = Enum.Font.GothamMedium
    priceL.TextSize = 11; priceL.Text = ""
    local metaL = Instance.new("TextLabel", frame)
    metaL.Size = UDim2.new(1,-8,0,14); metaL.Position = UDim2.new(0,4,0,37)
    metaL.BackgroundTransparency = 1; metaL.TextColor3 = T.textSec; metaL.Font = Enum.Font.Gotham
    metaL.TextSize = 10; metaL.Text = ""
    return {bb=bb, nameL=nameL, priceL=priceL, metaL=metaL, frame=frame, fStroke=fStroke}
end

E.clearCarESP = function()
    for slot, tag in pairs(carEspTags) do
        if tag.bb then tag.bb:Destroy() end
        carEspTags[slot] = nil
    end
end

E.getSlotPartESP = function(slot)
    local npc = slot:FindFirstChild("NpcSlot")
    if npc and npc:IsA("BasePart") then return npc end
    local cs = slot:FindFirstChild("CarSlot")
    if cs and cs:IsA("BasePart") then return cs end
    for _, d in ipairs(slot:GetDescendants()) do if d:IsA("BasePart") then return d end end
    return nil
end

E.refreshCarESP = function()
    if not state.carESP then E.clearCarESP(); return end
    local slots = Workspace:FindFirstChild("Slots")
    if not slots then return end
    if not hrp then return end

    local seen = {}
    for _, slot in ipairs(slots:GetChildren()) do
        local price = slot:GetAttribute("Price")
        local owner = slot:GetAttribute("CurrentUser") or ""
        local isLoaded = slot:GetAttribute("IsLoaded")
        local valid = price and type(price)=="number" and price>0
                      and (isLoaded == nil or isLoaded == true)
        if state.carESPunowned then
            valid = valid and (owner == nil or owner == "")
        end
        if valid then
            local part = E.getSlotPartESP(slot)
            if part then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist <= 600 then
                    seen[slot] = true
                    local tag = carEspTags[slot]
                    if not tag or not tag.bb or not tag.bb.Parent then
                        tag = E.makeCarTag(slot, part)
                        carEspTags[slot] = tag
                    else
                        tag.bb.Adornee = part
                    end
                    local carName = tostring(slot:GetAttribute("CarName") or slot.Name)
                    local year = tostring(slot:GetAttribute("Year") or "")
                    local info = lookupCar(carName, price)
                    local nm = info and (info.make.." "..info.model) or carName
                    tag.nameL.Text = nm .. (year~="" and " '"..year:sub(3,4) or "")
                    tag.priceL.Text = fmtPrice(price) .. " SAR"
                    -- FIX 5: Don't show ? rarity
                    local rar = info and DATA.RARITY_COL[info.rarity] and info.rarity or nil
                    tag.metaL.Text = string.format("%s  %.0fm", rar and (rar.."  -") or "", dist):gsub("^%s+","")
                    if not rar then
                        tag.metaL.Text = string.format("%.0fm", dist)
                    end
                    tag.metaL.TextColor3 = rar and rcol(info.rarity) or T.textSec
                    local own = (owner~=nil and owner~="")
                    tag.fStroke.Color = own and T.red or accentColor
                end
            end
        end
    end
    for slot, tag in pairs(carEspTags) do
        if not seen[slot] then
            if tag.bb then tag.bb:Destroy() end
            carEspTags[slot] = nil
        end
    end
end

-- ─────────── PLAYER ESP ───────────
local playerEsp = {}

local SKELETON_PAIRS = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local espScreen = Instance.new("Frame", gui)
espScreen.Size = UDim2.new(1,0,1,0); espScreen.BackgroundTransparency = 1
espScreen.BorderSizePixel = 0; espScreen.ZIndex = 40; espScreen.Name = "espScreen"
espScreen.Active = false

E.newLine = function()
    local f = Instance.new("Frame", espScreen)
    f.BackgroundColor3 = Color3.fromRGB(255,255,255); f.BorderSizePixel = 0
    f.AnchorPoint = Vector2.new(0.5, 0.5); f.ZIndex = 41
    return f
end

E.drawLine = function(f, p1, p2, col)
    local center = (p1 + p2) / 2
    local diff = p2 - p1
    local len = diff.Magnitude
    f.Position = UDim2.new(0, center.X, 0, center.Y)
    f.Size = UDim2.new(0, len, 0, 2)
    f.Rotation = math.deg(math.atan2(diff.Y, diff.X))
    f.BackgroundColor3 = col
    f.Visible = true
end

local pBoxes = {}

E.makePBox = function(plr)
    local holder = Instance.new("Frame", espScreen)
    holder.BackgroundTransparency = 1; holder.BorderSizePixel = 0; holder.ZIndex = 41
    holder.AnchorPoint = Vector2.new(0.5, 0)
    local boxF = Instance.new("Frame", holder)
    boxF.BackgroundTransparency = 1; boxF.BorderSizePixel = 0
    local bStroke = stroke(boxF, accentColor, 0)
    bStroke.Thickness = 1.5
    registerAccent(bStroke, "Color")  -- FIX 1
    local nameL = Instance.new("TextLabel", holder)
    nameL.BackgroundTransparency = 1; nameL.TextColor3 = T.text; nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 12; nameL.Size = UDim2.new(0, 200, 0, 14); nameL.AnchorPoint = Vector2.new(0.5,1)
    nameL.ZIndex = 42
    local healthBg = Instance.new("Frame", holder)
    healthBg.BackgroundColor3 = Color3.fromRGB(0,0,0); healthBg.BorderSizePixel = 0; healthBg.ZIndex = 41
    local healthFill = Instance.new("Frame", healthBg)
    healthFill.BackgroundColor3 = T.green; healthFill.BorderSizePixel = 0; healthFill.ZIndex = 42
    local distL = Instance.new("TextLabel", holder)
    distL.BackgroundTransparency = 1; distL.TextColor3 = T.textSec; distL.Font = Enum.Font.Gotham
    distL.TextSize = 11; distL.Size = UDim2.new(0, 200, 0, 12); distL.AnchorPoint = Vector2.new(0.5, 0); distL.ZIndex = 42
    local skel = {}
    for i = 1, #SKELETON_PAIRS do skel[i] = E.newLine(); skel[i].Visible = false end
    pBoxes[plr] = {holder=holder, boxF=boxF, nameL=nameL, healthBg=healthBg, healthFill=healthFill, distL=distL, skel=skel}
    return pBoxes[plr]
end

E.clearPlayerESP = function()
    for plr, d in pairs(pBoxes) do
        if d.holder then d.holder:Destroy() end
        for _, l in ipairs(d.skel) do if l then l:Destroy() end end
        pBoxes[plr] = nil
    end
end

E.updatePlayerESP = function()
    if not state.playerESP then E.clearPlayerESP(); espScreen.Visible = false; return end
    espScreen.Visible = true
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            local pchar = plr.Character
            local phrp = pchar and pchar:FindFirstChild("HumanoidRootPart")
            local phum = pchar and pchar:FindFirstChildOfClass("Humanoid")
            local head = pchar and pchar:FindFirstChild("Head")
            if phrp and phum and phum.Health > 0 then
                local d = pBoxes[plr] or E.makePBox(plr)
                local screenPos, onScreen = Camera:WorldToViewportPoint(phrp.Position)
                if onScreen then
                    d.holder.Visible = true
                    local headPos = Camera:WorldToViewportPoint((head and head.Position or phrp.Position) + Vector3.new(0,1.5,0))
                    local legPos = Camera:WorldToViewportPoint(phrp.Position - Vector3.new(0,3,0))
                    local h = math.abs(legPos.Y - headPos.Y)
                    local w = h * 0.5
                    if state.espBoxes then
                        d.boxF.Visible = true
                        d.boxF.Size = UDim2.new(0, w, 0, h)
                        d.boxF.Position = UDim2.new(0, screenPos.X - w/2, 0, headPos.Y)
                    else d.boxF.Visible = false end
                    d.nameL.Visible = true
                    d.nameL.Text = plr.DisplayName
                    d.nameL.Position = UDim2.new(0, screenPos.X, 0, headPos.Y - 4)
                    if state.espHealth then
                        d.healthBg.Visible = true; d.healthFill.Visible = true
                        d.healthBg.Size = UDim2.new(0, 3, 0, h)
                        d.healthBg.Position = UDim2.new(0, screenPos.X - w/2 - 6, 0, headPos.Y)
                        local hp = phum.Health / phum.MaxHealth
                        d.healthFill.Size = UDim2.new(1, 0, hp, 0)
                        d.healthFill.Position = UDim2.new(0, 0, 1-hp, 0)
                        d.healthFill.BackgroundColor3 = Color3.fromRGB(255*(1-hp), 255*hp, 60)
                    else d.healthBg.Visible = false; d.healthFill.Visible = false end
                    if state.espDistance and hrp then
                        d.distL.Visible = true
                        local dist = (phrp.Position - hrp.Position).Magnitude
                        d.distL.Text = string.format("%.0fm", dist)
                        d.distL.Position = UDim2.new(0, screenPos.X, 0, legPos.Y + 2)
                    else d.distL.Visible = false end
                    if state.espSkeleton and pchar then
                        for i, pair in ipairs(SKELETON_PAIRS) do
                            local a = pchar:FindFirstChild(pair[1])
                            local b = pchar:FindFirstChild(pair[2])
                            if a and b then
                                local pa, va = Camera:WorldToViewportPoint(a.Position)
                                local pb, vb = Camera:WorldToViewportPoint(b.Position)
                                if va and vb then
                                    E.drawLine(d.skel[i], Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y), accentColor)
                                else d.skel[i].Visible = false end
                            else d.skel[i].Visible = false end
                        end
                    else
                        for _, l in ipairs(d.skel) do l.Visible = false end
                    end
                else
                    if d.holder then d.holder.Visible = false end
                    for _, l in ipairs(d.skel) do l.Visible = false end
                end
            elseif pBoxes[plr] then
                pBoxes[plr].holder.Visible = false
                for _, l in ipairs(pBoxes[plr].skel) do l.Visible = false end
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(plr)
    if pBoxes[plr] then
        pBoxes[plr].holder:Destroy()
        for _, l in ipairs(pBoxes[plr].skel) do if l then l:Destroy() end end
        pBoxes[plr] = nil
    end
end)

-- ═══════════════ ESP TAB ═══════════════
B.buildESPTab = function()
    local panel = tabPanels["ESP"].panel

    H.mkSection(panel, "CAR ESP", 0)
    H.mkToggle(panel, "Car ESP", "Show price, name, distance, rarity on cars", false, 1, function(v)
        state.carESP = v
        if not v then E.clearCarESP() end
    end)
    H.mkToggle(panel, "Unowned Only", "Only show cars that are for sale", false, 2, function(v)
        state.carESPunowned = v
    end)

    H.mkSection(panel, "PLAYER ESP", 3)
    H.mkToggle(panel, "Player ESP", "Master toggle for player visuals", false, 4, function(v)
        state.playerESP = v
        if not v then E.clearPlayerESP() end
    end)
    H.mkToggle(panel, "Boxes", "Draw boxes around players", false, 5, function(v) state.espBoxes = v end)
    H.mkToggle(panel, "Skeleton", "Draw player skeletons", false, 6, function(v) state.espSkeleton = v end)
    H.mkToggle(panel, "Health", "Show health bars", false, 7, function(v) state.espHealth = v end)
    H.mkToggle(panel, "Distance", "Show distance to players", false, 8, function(v) state.espDistance = v end)
end

-- ═══════════════ MOVEMENT TAB ═══════════════
B.buildMovementTab = function()
    local panel = tabPanels["Movement"].panel

    H.mkSection(panel, "SPEED & JUMP", 0)
    H.mkSlider(panel, "Walk Speed", 16, 200, state.walkspeed, 1, function(v)
        state.walkspeed = v
        if hum then hum.WalkSpeed = v end
    end)
    H.mkSlider(panel, "Jump Power", 50, 350, state.jumppower, 2, function(v)
        state.jumppower = v
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v
        end
    end)

    H.mkSection(panel, "ABILITIES", 3)
    H.mkToggle(panel, "Infinite Jump", "Jump again any time mid-air", false, 4, function(v) state.infJump = v end)
    H.mkToggle(panel, "No Clip", "Walk through walls and objects", false, 5, function(v) state.noclip = v end)

    if hum then
        hum.WalkSpeed = state.walkspeed
        hum.UseJumpPower = true
        hum.JumpPower = state.jumppower
    end
end

UserInputService.JumpRequest:Connect(function()
    if state.infJump and hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

RunService.Stepped:Connect(function()
    if state.noclip and char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end
    if hum then
        if state.walkspeed ~= 16 and hum.WalkSpeed ~= state.walkspeed then hum.WalkSpeed = state.walkspeed end
        if state.jumppower ~= 50 then hum.UseJumpPower = true; if hum.JumpPower ~= state.jumppower then hum.JumpPower = state.jumppower end end
    end
end)

-- ═══════════════ TELEPORT TAB ═══════════════
-- FIX 6: Removed "Your Dealership" (duplicate of Inside Your Plot)
-- FIX 7: Multi-position custom teleport system (5 max)
B.buildTeleportTab = function()
    local panel = tabPanels["Teleport"].panel

    H.mkSection(panel, "LOCATIONS", 0)
    H.mkButton(panel, "Cars Dealership", "GO", accentColor, 1, function()
        local p = getTpPart("Dealership"); if p then tpToPos(p.Position,3,0); notify("Teleported","Cars Dealership",accentColor)
        else notify("Error","Dealership not found",T.red) end
    end)
    H.mkButton(panel, "The Neighborhood", "GO", accentColor, 2, function()
        local p = getTpPart("Neighborhood"); if p then tpToPos(p.Position,3,0); notify("Teleported","The Neighborhood",accentColor)
        else notify("Error","Neighborhood not found",T.red) end
    end)

    -- FIX 6: Only "Inside Your Plot" - removed "Your Dealership"
    H.mkSection(panel, "YOUR PLOT", 3)
    H.mkButton(panel, "Inside Your Plot", "GO", T.green, 4, function()
        local plot = findMyPlot()
        if not plot then notify("Not Found","Could not find your plot",T.red); return end
        local center = plot:FindFirstChild("Center") or getPlotTpPart(plot)
        if center then
            local targetCF = CFrame.new(center.Position.X, center.Position.Y+4, center.Position.Z)
            local seat = hum and hum.SeatPart
            if seat and seat:IsA("BasePart") then
                local veh = seat:FindFirstAncestorWhichIsA("Model")
                if veh and veh.PrimaryPart then
                    veh:SetPrimaryPartCFrame(targetCF)
                else seat.CFrame = targetCF end
            else
                if hrp then hrp.CFrame = targetCF end
            end
            notify("Teleported","Inside your plot ("..plot.Name..")",T.green)
        end
    end)

    -- FIX 7: Multi-position system
    H.mkSection(panel, "CUSTOM POSITIONS  (max 5)", 5)

    -- Container for saved position entries (rebuilt on change)
    local posListContainer = Instance.new("Frame", panel)
    posListContainer.Size = UDim2.new(1, 0, 0, 0)
    posListContainer.BackgroundTransparency = 1
    posListContainer.BorderSizePixel = 0
    posListContainer.AutomaticSize = Enum.AutomaticSize.Y
    posListContainer.LayoutOrder = 6
    local posListLayout = Instance.new("UIListLayout", posListContainer)
    posListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    posListLayout.Padding = UDim.new(0, 6)

    -- "Add Position" button (shown at bottom)
    local addPosCard = H.mkCard(panel, 48, 7)
    local addPosBtn = Instance.new("TextButton", addPosCard)
    addPosBtn.Size = UDim2.new(1, -28, 0, 32); addPosBtn.Position = UDim2.new(0, 14, 0.5, -16)
    addPosBtn.BackgroundColor3 = accentColor; addPosBtn.TextColor3 = Color3.fromRGB(8,8,8)
    addPosBtn.Text = "+ Save Current Position"; addPosBtn.TextSize = 12; addPosBtn.Font = Enum.Font.GothamBold
    addPosBtn.BorderSizePixel = 0; addPosBtn.AutoButtonColor = false; corner(addPosBtn, 8)
    registerAccent(addPosBtn, "BackgroundColor3")  -- FIX 1

    local function rebuildPosList()
        -- Clear existing children
        for _, ch in ipairs(posListContainer:GetChildren()) do
            if not ch:IsA("UIListLayout") then ch:Destroy() end
        end

        if #state.savedPositions == 0 then
            local empty = Instance.new("TextLabel", posListContainer)
            empty.Size = UDim2.new(1, 0, 0, 30); empty.BackgroundTransparency = 1
            empty.Text = "No saved positions. Press Save to add one."; empty.TextColor3 = T.textTer
            empty.Font = Enum.Font.Gotham; empty.TextSize = 11
            empty.LayoutOrder = 1
        end

        for idx, posEntry in ipairs(state.savedPositions) do
            local row = Instance.new("Frame", posListContainer)
            row.Size = UDim2.new(1, 0, 0, 54); row.BackgroundColor3 = T.card
            row.BackgroundTransparency = 0.15; row.BorderSizePixel = 0; row.LayoutOrder = idx
            corner(row, 10); stroke(row, T.cardBorder, 0.4)

            -- Name label (editable on click)
            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size = UDim2.new(1, -290, 0, 22); nameLbl.Position = UDim2.new(0, 14, 0, 7)
            nameLbl.BackgroundTransparency = 1; nameLbl.TextColor3 = T.text
            nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.Text = posEntry.name

            local coordLbl = Instance.new("TextLabel", row)
            coordLbl.Size = UDim2.new(1, -290, 0, 16); coordLbl.Position = UDim2.new(0, 14, 0, 30)
            coordLbl.BackgroundTransparency = 1; coordLbl.TextColor3 = T.textTer
            coordLbl.Font = Enum.Font.Gotham; coordLbl.TextSize = 10
            coordLbl.TextXAlignment = Enum.TextXAlignment.Left
            coordLbl.Text = string.format("%.0f, %.0f, %.0f", posEntry.pos[1], posEntry.pos[2], posEntry.pos[3])

            -- GO button
            local goBtn = Instance.new("TextButton", row)
            goBtn.Size = UDim2.new(0, 54, 0, 34); goBtn.Position = UDim2.new(1, -272, 0.5, -17)
            goBtn.BackgroundColor3 = T.green; goBtn.TextColor3 = Color3.fromRGB(8,8,8)
            goBtn.Text = "GO"; goBtn.TextSize = 12; goBtn.Font = Enum.Font.GothamBold
            goBtn.BorderSizePixel = 0; goBtn.AutoButtonColor = false; corner(goBtn, 7)

            -- RENAME button
            local renameBtn = Instance.new("TextButton", row)
            renameBtn.Size = UDim2.new(0, 72, 0, 34); renameBtn.Position = UDim2.new(1, -210, 0.5, -17)
            renameBtn.BackgroundColor3 = accentColor; renameBtn.TextColor3 = Color3.fromRGB(8,8,8)
            renameBtn.Text = "RENAME"; renameBtn.TextSize = 11; renameBtn.Font = Enum.Font.GothamBold
            renameBtn.BorderSizePixel = 0; renameBtn.AutoButtonColor = false; corner(renameBtn, 7)
            registerAccent(renameBtn, "BackgroundColor3")  -- FIX 1

            -- UPDATE button (re-save position)
            local updateBtn = Instance.new("TextButton", row)
            updateBtn.Size = UDim2.new(0, 72, 0, 34); updateBtn.Position = UDim2.new(1, -130, 0.5, -17)
            updateBtn.BackgroundColor3 = Color3.fromRGB(255, 159, 10); updateBtn.TextColor3 = Color3.fromRGB(8,8,8)
            updateBtn.Text = "UPDATE"; updateBtn.TextSize = 11; updateBtn.Font = Enum.Font.GothamBold
            updateBtn.BorderSizePixel = 0; updateBtn.AutoButtonColor = false; corner(updateBtn, 7)

            -- DELETE button
            local delBtn = Instance.new("TextButton", row)
            delBtn.Size = UDim2.new(0, 54, 0, 34); delBtn.Position = UDim2.new(1, -68, 0.5, -17)
            delBtn.BackgroundColor3 = T.red; delBtn.TextColor3 = Color3.fromRGB(8,8,8)
            delBtn.Text = "DEL"; delBtn.TextSize = 12; delBtn.Font = Enum.Font.GothamBold
            delBtn.BorderSizePixel = 0; delBtn.AutoButtonColor = false; corner(delBtn, 7)

            local thisIdx = idx

            goBtn.MouseButton1Click:Connect(function()
                if hrp then
                    local e = state.savedPositions[thisIdx]
                    if e then
                        hrp.CFrame = CFrame.new(e.pos[1], e.pos[2], e.pos[3])
                        notify("Teleported", e.name, T.green)
                    end
                end
            end)

            -- Rename: cycle to an inline TextBox
            renameBtn.MouseButton1Click:Connect(function()
                -- Replace name label with a TextBox briefly
                nameLbl.Visible = false
                local tb = Instance.new("TextBox", row)
                tb.Size = UDim2.new(1, -290, 0, 22); tb.Position = UDim2.new(0, 14, 0, 7)
                tb.BackgroundColor3 = T.card; tb.BorderSizePixel = 0
                tb.TextColor3 = T.text; tb.Font = Enum.Font.GothamBold; tb.TextSize = 13
                tb.PlaceholderText = "Enter name..."; tb.Text = state.savedPositions[thisIdx].name
                tb.ClearTextOnFocus = false; corner(tb, 6); stroke(tb, accentColor, 0.2)
                tb:CaptureFocus()

                local function commitRename()
                    local newName = tb.Text ~= "" and tb.Text or state.savedPositions[thisIdx].name
                    state.savedPositions[thisIdx].name = newName
                    saveConfig()
                    tb:Destroy()
                    nameLbl.Text = newName
                    nameLbl.Visible = true
                end
                tb.FocusLost:Connect(commitRename)
            end)

            updateBtn.MouseButton1Click:Connect(function()
                if hrp then
                    local pos = hrp.Position
                    state.savedPositions[thisIdx].pos = {pos.X, pos.Y, pos.Z}
                    saveConfig()
                    coordLbl.Text = string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
                    notify("Updated", state.savedPositions[thisIdx].name .. " position updated", Color3.fromRGB(255, 159, 10))
                end
            end)

            delBtn.MouseButton1Click:Connect(function()
                table.remove(state.savedPositions, thisIdx)
                saveConfig()
                rebuildPosList()
                notify("Deleted", "Position removed", T.red)
            end)
        end

        -- Update addPosBtn visibility
        addPosBtn.Visible = #state.savedPositions < 5
        addPosCard.Visible = #state.savedPositions < 5
    end

    addPosBtn.MouseButton1Click:Connect(function()
        if #state.savedPositions >= 5 then
            notify("Max Reached", "You can only save 5 positions", T.red); return
        end
        if not hrp then return end
        local pos = hrp.Position
        local name = "Position " .. (#state.savedPositions + 1)
        table.insert(state.savedPositions, {name=name, pos={pos.X, pos.Y, pos.Z}})
        saveConfig()
        rebuildPosList()
        notify("Saved", name .. " saved", accentColor)
    end)

    rebuildPosList()
end

-- ═══════════════ MISC TAB ═══════════════
B.buildMiscTab = function()
    local panel = tabPanels["Misc"].panel

    H.mkSection(panel, "VISUAL", 0)
    H.mkToggle(panel, "Full Bright", "Remove darkness, max brightness", false, 1, function(v)
        state.fullbright = v
        if v then
            Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false; Lighting.Ambient = Color3.fromRGB(178,178,178)
        else
            Lighting.Brightness = 1; Lighting.GlobalShadows = true
            Lighting.Ambient = Color3.fromRGB(0,0,0)
        end
    end)
    H.mkToggle(panel, "Hide Other Players", "Hide all other player characters", false, 2, function(v)
        state.hidePlayers = v
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character then
                for _, p in ipairs(plr.Character:GetDescendants()) do
                    if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency = v and 1 or 0 end
                end
            end
        end
    end)
    H.mkSlider(panel, "Field of View", 30, 120, state.fov, 3, function(v)
        state.fov = v
        if Camera then Camera.FieldOfView = v end
    end)

    H.mkSection(panel, "UTILITY", 4)
    H.mkToggle(panel, "Anti AFK", "Prevent being kicked for inactivity", false, 5, function(v) state.antiAFK = v end)

    -- Distance tracker
    H.mkSection(panel, "DISTANCE TRACKER", 6)
    local distCard = H.mkCard(panel, 56, 7)
    local distLbl = Instance.new("TextLabel", distCard)
    distLbl.Size = UDim2.new(1,-180,1,0); distLbl.Position = UDim2.new(0,14,0,0)
    distLbl.BackgroundTransparency = 1; distLbl.TextColor3 = T.text; distLbl.TextSize = 18
    distLbl.Font = Enum.Font.GothamBold; distLbl.TextXAlignment = Enum.TextXAlignment.Left; distLbl.Text = "0.00 mi"
    local unitBtn = Instance.new("TextButton", distCard)
    unitBtn.Size = UDim2.new(0,60,0,30); unitBtn.Position = UDim2.new(1,-160,0.5,-15)
    unitBtn.BackgroundColor3 = T.card; unitBtn.TextColor3 = T.text; unitBtn.Text = state.distUnit
    unitBtn.TextSize = 12; unitBtn.Font = Enum.Font.GothamBold; unitBtn.BorderSizePixel = 0
    unitBtn.AutoButtonColor = false; corner(unitBtn, 8); stroke(unitBtn, T.cardBorder, 0.4)
    local resetBtn = Instance.new("TextButton", distCard)
    resetBtn.Size = UDim2.new(0,84,0,30); resetBtn.Position = UDim2.new(1,-94,0.5,-15)
    resetBtn.BackgroundColor3 = T.red; resetBtn.TextColor3 = Color3.fromRGB(8,8,8); resetBtn.Text = "RESET"
    resetBtn.TextSize = 11; resetBtn.Font = Enum.Font.GothamBold; resetBtn.BorderSizePixel = 0
    resetBtn.AutoButtonColor = false; corner(resetBtn, 8)

    unitBtn.MouseButton1Click:Connect(function()
        state.distUnit = state.distUnit == "mi" and "km" or "mi"
        unitBtn.Text = state.distUnit; saveConfig()
    end)
    resetBtn.MouseButton1Click:Connect(function()
        state.distTracker = 0; notify("Reset","Distance tracker reset",accentColor)
    end)

    task.spawn(function()
        while panel.Parent do
            local meters = state.distTracker
            if state.distUnit == "mi" then
                distLbl.Text = string.format("%.2f mi", meters / 1609.34)
            else
                distLbl.Text = string.format("%.2f km", meters / 1000)
            end
            task.wait(0.3)
        end
    end)

    H.mkSection(panel, "SERVER", 8)
    H.mkButton(panel, "Rejoin Server", "REJOIN", accentColor, 9, function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
    end)
    H.mkButton(panel, "Leave Game", "LEAVE", T.red, 10, function()
        lp:Kick("LSX | You left the game")
    end)
end

-- ═══════════════ SETTINGS TAB ═══════════════
B.buildSettingsTab = function()
    local panel = tabPanels["Settings"].panel

    H.mkSection(panel, "NOTIFICATIONS", 0)
    H.mkToggle(panel, "Rare Spawn Alerts", "Notify when Rare+ cars spawn in", state.notifSpawns, 1, function(v)
        state.notifSpawns = v; saveConfig()
    end)

    H.mkSection(panel, "KEYBIND", 2)
    local bindCard = H.mkCard(panel, 48, 3)
    local bindLbl = Instance.new("TextLabel", bindCard)
    bindLbl.Size = UDim2.new(1,-120,1,0); bindLbl.Position = UDim2.new(0,14,0,0)
    bindLbl.BackgroundTransparency = 1; bindLbl.Text = "Menu Toggle Key"; bindLbl.TextColor3 = T.text
    bindLbl.Font = Enum.Font.GothamMedium; bindLbl.TextSize = 13; bindLbl.TextXAlignment = Enum.TextXAlignment.Left
    local bindBtn = Instance.new("TextButton", bindCard)
    bindBtn.Size = UDim2.new(0,96,0,32); bindBtn.Position = UDim2.new(1,-108,0.5,-16)
    bindBtn.BackgroundColor3 = accentColor; bindBtn.TextColor3 = Color3.fromRGB(8,8,8)
    bindBtn.Text = menuBind.Name; bindBtn.TextSize = 12; bindBtn.Font = Enum.Font.GothamBold
    bindBtn.BorderSizePixel = 0; bindBtn.AutoButtonColor = false; corner(bindBtn, 8)
    registerAccent(bindBtn, "BackgroundColor3")  -- FIX 1
    local listening = false
    bindBtn.MouseButton1Click:Connect(function()
        listening = true; bindBtn.Text = "..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                menuBind = inp.KeyCode; bindBtn.Text = menuBind.Name
                listening = false; saveConfig(); conn:Disconnect()
            end
        end)
    end)

    -- FIX 1: Accent color presets apply live
    H.mkSection(panel, "ACCENT COLOR", 4)
    local colorCard = H.mkCard(panel, 56, 5)
    local presets = {
        Color3.fromRGB(70,150,255), Color3.fromRGB(130,190,255),
        Color3.fromRGB(60,210,130), Color3.fromRGB(255,159,10),
        Color3.fromRGB(175,82,222), Color3.fromRGB(255,95,95),
    }
    for i, col in ipairs(presets) do
        local sw = Instance.new("TextButton", colorCard)
        sw.Size = UDim2.new(0,40,0,32); sw.Position = UDim2.new(0,14+(i-1)*48,0.5,-16)
        sw.BackgroundColor3 = col; sw.Text = ""; sw.BorderSizePixel = 0
        sw.AutoButtonColor = false; corner(sw, 8); stroke(sw, T.cardBorder, 0.3)
        sw.MouseButton1Click:Connect(function()
            applyAccentColor(col)  -- FIX 1: apply live everywhere
            saveConfig()
            notify("Accent Changed", "Applied live everywhere", col)
        end)
    end

    H.mkSection(panel, "CONFIG", 6)
    H.mkButton(panel, "Save Config", "SAVE", T.green, 7, function() saveConfig(); notify("Saved","Config saved",T.green) end)

    H.mkSection(panel, "PANIC", 8)
    H.mkButton(panel, "Unload LSX (Shift+K)", "KILL", T.red, 9, function()
        scriptActive = false
        E.clearCarESP(); E.clearPlayerESP()
        gui:Destroy()
    end)
end

-- ═══════════════ CREDITS TAB ═══════════════
B.buildCreditsTab = function()
    local panel = tabPanels["Credits"].panel

    local logoCard = H.mkCard(panel, 120, 0)
    local big = Instance.new("TextLabel", logoCard)
    big.Size = UDim2.new(1,0,0,60); big.Position = UDim2.new(0,0,0,20)
    big.BackgroundTransparency = 1; big.Text = "LSX"; big.TextColor3 = T.text
    big.Font = Enum.Font.GothamBold; big.TextSize = 48
    H.gradient(big, T.text, T.blueLight, 90)
    local tag = Instance.new("TextLabel", logoCard)
    tag.Size = UDim2.new(1,0,0,20); tag.Position = UDim2.new(0,0,0,82)
    tag.BackgroundTransparency = 1; tag.Text = "Car Sales 2"; tag.TextColor3 = T.textSec
    tag.Font = Enum.Font.GothamMedium; tag.TextSize = 14

    H.mkSection(panel, "TEAM", 1)
    local devCard = H.mkCard(panel, 52, 2)
    local dt = Instance.new("TextLabel", devCard)
    dt.Size = UDim2.new(1,-28,0,20); dt.Position = UDim2.new(0,14,0,8)
    dt.BackgroundTransparency = 1; dt.Text = "Kyzen"; dt.TextColor3 = T.text
    dt.Font = Enum.Font.GothamBold; dt.TextSize = 14; dt.TextXAlignment = Enum.TextXAlignment.Left
    local dd = Instance.new("TextLabel", devCard)
    dd.Size = UDim2.new(1,-28,0,16); dd.Position = UDim2.new(0,14,0,28)
    dd.BackgroundTransparency = 1; dd.Text = "Developer & Owner of LSX"; dd.TextColor3 = T.textSec
    dd.Font = Enum.Font.Gotham; dd.TextSize = 11; dd.TextXAlignment = Enum.TextXAlignment.Left

    H.mkSection(panel, "GAME", 3)
    local gameCard = H.mkCard(panel, 44, 4)
    local gt = Instance.new("TextLabel", gameCard)
    gt.Size = UDim2.new(1,-28,1,0); gt.Position = UDim2.new(0,14,0,0)
    gt.BackgroundTransparency = 1; gt.Text = "Car Sales 2"; gt.TextColor3 = T.text
    gt.Font = Enum.Font.GothamMedium; gt.TextSize = 13; gt.TextXAlignment = Enum.TextXAlignment.Left

    H.mkSection(panel, "COMMUNITY", 5)
    local _, discBtn = H.mkButton(panel, "Join the Discord", "COPY LINK", accentColor, 6, function()
        local link = "https://discord.gg/UG4TujqUeq"
        pcall(function() setclipboard(link) end)
        notify("Discord","Link copied: discord.gg/UG4TujqUeq",accentColor)
    end)
end

-- ═══════════════ RESET TIMER WIDGET ═══════════════
local timerWidget = Instance.new("Frame", gui)
timerWidget.Size = UDim2.new(0, 150, 0, 64); timerWidget.Position = UDim2.new(1, -166, 1, -80)
timerWidget.BackgroundColor3 = T.bg; timerWidget.BackgroundTransparency = 0.1
timerWidget.BorderSizePixel = 0; corner(timerWidget, 12); stroke(timerWidget, T.cardBorder, 0.3)
local twGrad = Instance.new("Frame", timerWidget)
twGrad.Size = UDim2.new(1,0,1,0); twGrad.BackgroundTransparency = 0.6; twGrad.BorderSizePixel = 0; corner(twGrad,12)
H.gradient(twGrad, Color3.fromRGB(20,28,44), Color3.fromRGB(10,12,16), 135)
local twTitle = Instance.new("TextLabel", timerWidget)
twTitle.Size = UDim2.new(1,-20,0,16); twTitle.Position = UDim2.new(0,12,0,8)
twTitle.BackgroundTransparency = 1; twTitle.Text = "DEALERSHIP RESET"; twTitle.TextColor3 = T.textSec
twTitle.Font = Enum.Font.GothamBold; twTitle.TextSize = 10; twTitle.TextXAlignment = Enum.TextXAlignment.Left
local twTime = Instance.new("TextLabel", timerWidget)
twTime.Size = UDim2.new(1,-20,0,30); twTime.Position = UDim2.new(0,12,0,26)
twTime.BackgroundTransparency = 1; twTime.Text = "--:--"; twTime.TextColor3 = T.text
twTime.Font = Enum.Font.GothamBold; twTime.TextSize = 26; twTime.TextXAlignment = Enum.TextXAlignment.Left
H.gradient(twTime, T.text, T.blueLight, 90)

-- FIX 3: Corrected dealership timer
-- The 9-second pause at 00:00 is the server-side reset animation/delay.
-- We detect this and show "RESETTING..." then cleanly jump to 05:00 after the pause ends.
do
    local RESET_CYCLE = 300  -- 5 minutes
    local localSeconds = nil
    local lastTick = tick()
    local lastRealSeconds = nil
    local resetting = false
    local resetStartTick = nil

    task.spawn(function()
        while true do
            local realText = nil
            local drt = Workspace:FindFirstChild("DealershipResetTimer")
            if drt then
                for _, v in ipairs(drt:GetDescendants()) do
                    if v:IsA("TextLabel") then
                        local t = v.Text or ""
                        if t:match("%d%d?:%d%d") then realText = t; break end
                    end
                end
            end

            local now = tick()
            local elapsed = now - lastTick
            lastTick = now

            if realText then
                local mm, ss = realText:match("(%d+):(%d+)")
                if mm and ss then
                    local secs = tonumber(mm)*60 + tonumber(ss)

                    -- FIX 3: detect the 00:00 -> pause -> 05:00 cycle
                    -- When we see secs <= 2 and previously we were above 5, the reset is starting
                    if lastRealSeconds and lastRealSeconds > 5 and secs <= 2 then
                        -- Timer hit near 00:00, enter resetting state
                        resetting = true
                        resetStartTick = now
                        twTime.Text = "RESETTING"
                        twTime.TextColor3 = T.red
                    elseif resetting then
                        -- We are in resetting state: once timer jumps back up to > 10, reset is done
                        if secs > 10 then
                            resetting = false
                            localSeconds = secs
                            twTime.Text = string.format("%02d:%02d", math.floor(secs/60), secs%60)
                            twTime.TextColor3 = T.text
                        else
                            -- Keep showing RESETTING during the 9s pause
                            twTime.Text = "RESETTING"
                            twTime.TextColor3 = T.red
                        end
                    else
                        -- Normal countdown display
                        localSeconds = secs
                        twTime.Text = realText
                        twTime.TextColor3 = T.text
                    end
                    lastRealSeconds = secs
                end
            elseif not resetting then
                -- No timer visible, count down locally
                if localSeconds then
                    localSeconds = localSeconds - elapsed
                    if localSeconds < 0 then
                        localSeconds = RESET_CYCLE + localSeconds
                    end
                    local m = math.floor(localSeconds / 60)
                    local s = math.floor(localSeconds % 60)
                    twTime.Text = string.format("%02d:%02d", m, s)
                    twTime.TextColor3 = T.text
                else
                    twTime.Text = "--:--"
                    twTime.TextColor3 = T.textSec
                end
            end

            task.wait(0.5)
        end
    end)
end

-- ═══════════════ RARE SPAWN NOTIFIER ═══════════════
local knownSlots = {}

task.spawn(function()
    task.wait(2)
    local slots = Workspace:FindFirstChild("Slots")
    if slots then
        for _, slot in ipairs(slots:GetChildren()) do
            knownSlots[slot] = tostring(slot:GetAttribute("CarName")) .. "|" .. tostring(slot:GetAttribute("Price"))
        end
    end

    while true do
        if state.notifSpawns then
            local sl = Workspace:FindFirstChild("Slots")
            if sl then
                for _, slot in ipairs(sl:GetChildren()) do
                    local cn = slot:GetAttribute("CarName")
                    local price = slot:GetAttribute("Price")
                    local sig = tostring(cn) .. "|" .. tostring(price)
                    if cn and price and knownSlots[slot] ~= sig then
                        knownSlots[slot] = sig
                        local info = lookupCar(cn, price)
                        if info and DATA.NOTIFY_RARITIES[info.rarity] then
                            local part = slot:FindFirstChild("NpcSlot") or slot:FindFirstChild("CarSlot")
                            local zone = "the market"
                            if part and part:IsA("BasePart") then
                                local dDealer = (part.Position - Vector3.new(-2907,8.9,3386)).Magnitude
                                local dHood = (part.Position - Vector3.new(-1197,6.8,-520)).Magnitude
                                zone = dDealer < dHood and "the Dealership" or "the Neighborhood"
                            end
                            local year = tostring(slot:GetAttribute("Year") or "")
                            notify(
                                info.rarity .. " Spawned!",
                                info.make.." "..info.model.." ("..tostring(cn)..(year~="" and " "..year or "")..") spawned in at "..zone,
                                rcol(info.rarity)
                            )
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

-- ═══════════════ GLOBAL LOOPS ═══════════════
RunService.RenderStepped:Connect(function()
    if not scriptActive then return end
    pcall(E.updatePlayerESP)
end)

task.spawn(function()
    while scriptActive do
        pcall(E.refreshCarESP)
        task.wait(1)
    end
end)

-- Distance tracker
task.spawn(function()
    local lastPos = hrp and hrp.Position
    while scriptActive do
        task.wait(0.5)
        if hrp and lastPos then
            local d = (hrp.Position - lastPos).Magnitude
            if d < 200 then
                state.distTracker = state.distTracker + d
            end
            lastPos = hrp.Position
        elseif hrp then
            lastPos = hrp.Position
        end
    end
end)

-- Anti AFK
local vu = game:GetService("VirtualUser")
lp.Idled:Connect(function()
    if state.antiAFK then
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end
end)

-- Keep fullbright/fov applied
RunService.Heartbeat:Connect(function()
    if state.fullbright then
        if Lighting.Brightness < 2 then Lighting.Brightness = 2 end
        if Lighting.ClockTime ~= 14 then Lighting.ClockTime = 14 end
    end
    if Camera and state.fov ~= 70 and Camera.FieldOfView ~= state.fov then
        Camera.FieldOfView = state.fov
    end
end)

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(c)
        if state.hidePlayers then
            task.wait(0.5)
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency = 1 end
            end
        end
    end)
end)

-- ═══════════════ DRAG ═══════════════
do
    local dragging, dragStart, startPos = false, nil, nil
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = inp.Position; startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- ═══════════════ TOGGLE / OPEN-CLOSE ═══════════════
local guiVisible = false
local animating = false
local function toggleGUI()
    if animating then return end
    animating = true
    guiVisible = not guiVisible
    if guiVisible then
        main.Visible = true
        local target = UDim2.new(0.5, -MAIN_W/2, 0.5, -FULL_H/2)
        main.Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset - 18)
        main.BackgroundTransparency = 1
        TweenService:Create(main, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.08, Position = target}):Play()
        task.wait(0.33)
    else
        local cur = main.Position
        TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            {BackgroundTransparency = 1, Position = UDim2.new(cur.X.Scale, cur.X.Offset, cur.Y.Scale, cur.Y.Offset - 18)}):Play()
        task.wait(0.26)
        main.Visible = false
    end
    animating = false
end

closeBtn.MouseButton1Click:Connect(toggleGUI)

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == menuBind then
        toggleGUI()
    elseif inp.KeyCode == Enum.KeyCode.K and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        scriptActive = false
        E.clearCarESP(); E.clearPlayerESP()
        gui:Destroy()
    end
end)

-- ═══════════════ INIT ═══════════════
B.buildMainTab()
B.buildCarsTab()
B.buildESPTab()
B.buildMovementTab()
B.buildTeleportTab()
B.buildMiscTab()
B.buildSettingsTab()
B.buildCreditsTab()
switchTab("Main")

showLoadingScreen(function()
    guiVisible = true
    main.Visible = true
    main.BackgroundTransparency = 0.08
    notify("LSX Loaded", "Press " .. menuBind.Name .. " to toggle  -  by Kyzen", accentColor)
end)
