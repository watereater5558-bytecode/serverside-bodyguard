local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local OwnerName = localPlayer and localPlayer.Name or "takipakipayer"

local AggressorList = {}
local ActiveUnits = {}

local function addAggressor(player)
    if player.Name == OwnerName then return end
    AggressorList[player.Name] = os.time() + 60
end

local function checkAggressors()
    local now = os.time()
    for name, time in pairs(AggressorList) do
        if now > time then
            AggressorList[name] = nil
        end
    end
end

local function trackDamage(player, character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    local lastHealth = humanoid.Health
    humanoid.HealthChanged:Connect(function(health)
        if health < lastHealth then
            local creator = humanoid:FindFirstChild("creator")
            if creator and creator.Value and creator.Value:IsA("Player") then
                addAggressor(creator.Value)
            else
                local nearestDist = 15
                local suspected = nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (p.Character.HumanoidRootPart.Position - character.HumanoidRootPart.Position).Magnitude
                        if dist < nearestDist then
                            nearestDist = dist
                            suspected = p
                        end
                    end
                end
                if suspected then
                    addAggressor(suspected)
                end
            end
        end
        lastHealth = health
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        trackDamage(player, character)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        trackDamage(player, player.Character)
    end
end

local function createMotor(name, p0, p1, c0)
    local m = Instance.new("Motor6D")
    m.Name = name
    m.Part0 = p0
    m.Part1 = p1
    m.C0 = c0
    m.Parent = p0
    return m
end

local function buildHumanoidModel(name, sizeMult, color)
    local guard = Instance.new("Model")
    guard.Name = name

    local rootPart = Instance.new("Part")
    rootPart.Name = "HumanoidRootPart"
    rootPart.Size = Vector3.new(2, 2, 1) * sizeMult
    rootPart.Transparency = 1
    rootPart.CanCollide = true
    rootPart.Parent = guard

    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = guard

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1, 1, 1) * sizeMult
    head.Color = color
    head.CanCollide = true
    head.Parent = guard

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1) * sizeMult
    torso.Color = color
    torso.CanCollide = true
    torso.Parent = guard

    createMotor("RootJoint", rootPart, torso, CFrame.new(0, 0, 0))
    createMotor("Neck", torso, head, CFrame.new(0, 1.5 * sizeMult, 0))

    return guard, rootPart, humanoid, torso
end

local function getNearestAggressor(center)
    checkAggressors()
    local target = nil
    local nearestDist = math.huge
    for name, _ in pairs(AggressorList) do
        local p = Players:FindFirstChild(name)
        if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local dist = (p.Character.HumanoidRootPart.Position - center).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                target = p.Character
            end
        end
    end
    return target, nearestDist
end

local function spawnStandardGuard(ownerCharacter)
    local guard, rootPart, humanoid, torso = buildHumanoidModel("StandardGuard", 1, Color3.fromRGB(150, 150, 150))
    
    local baton = Instance.new("Part")
    baton.Name = "StunBaton"
    baton.Size = Vector3.new(0.5, 3, 0.5)
    baton.Color = Color3.fromRGB(255, 255, 0)
    baton.CanCollide = false
    baton.Parent = guard

    local weld = Instance.new("Weld")
    weld.Part0 = torso
    weld.Part1 = baton
    weld.C0 = CFrame.new(1.5, 0, -1) * CFrame.Angles(math.pi/4, 0, 0)
    weld.Parent = torso

    guard.Parent = Workspace
    rootPart.CFrame = ownerCharacter.PrimaryPart.CFrame * CFrame.new(3, 0, 3)

    local debounce = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not guard.Parent or not ownerCharacter:FindFirstChild("HumanoidRootPart") then conn:Disconnect() return end
        
        local target, dist = getNearestAggressor(rootPart.Position)
        if target then
            humanoid:MoveTo(target.HumanoidRootPart.Position)
            if dist < 5 and not debounce then
                debounce = true
                local enemyHum = target:FindFirstChild("Humanoid")
                if enemyHum then
                    enemyHum:TakeDamage(20)
                    local oldSpeed = enemyHum.WalkSpeed
                    enemyHum.WalkSpeed = oldSpeed * 0.5
                    local sparks = Instance.new("ParticleEmitter")
                    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
                    sparks.Size = NumberSequence.new(0.5)
                    sparks.Rate = 50
                    sparks.Speed = NumberRange.new(5, 10)
                    sparks.Parent = baton
                    Debris:AddItem(sparks, 0.5)
                    task.delay(2, function()
                        if enemyHum then enemyHum.WalkSpeed = oldSpeed end
                    end)
                end
                task.delay(1.5, function() debounce = false end)
            end
        else
            humanoid:MoveTo(ownerCharacter.HumanoidRootPart.Position + Vector3.new(4, 0, 4))
        end
    end)
    return guard
end

local function spawnStandardDrone(ownerCharacter)
    local drone = Instance.new("Part")
    drone.Size = Vector3.new(2, 0.5, 2)
    drone.Color = Color3.fromRGB(100, 100, 100)
    drone.Anchored = true
    drone.CanCollide = false
    drone.Parent = Workspace

    local debounce = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not drone.Parent or not ownerCharacter:FindFirstChild("HumanoidRootPart") then conn:Disconnect() return end
        
        local target, dist = getNearestAggressor(drone.Position)
        if target then
            local targetPos = target.HumanoidRootPart.Position + Vector3.new(0, 6, 0)
            drone.CFrame = drone.CFrame:Lerp(CFrame.new(targetPos, target.HumanoidRootPart.Position), 0.1)
            if dist < 12 and not debounce then
                debounce = true
                local enemyHum = target:FindFirstChild("Humanoid")
                if enemyHum then
                    local oldSpeed = enemyHum.WalkSpeed
                    enemyHum.WalkSpeed = 0
                    local ice = Instance.new("Part")
                    ice.Size = Vector3.new(4, 6, 4)
                    ice.CFrame = target.HumanoidRootPart.CFrame
                    ice.Color = Color3.fromRGB(150, 200, 255)
                    ice.Transparency = 0.5
                    ice.Material = Enum.Material.Ice
                    ice.Anchored = true
                    ice.CanCollide = false
                    ice.Parent = Workspace
                    Debris:AddItem(ice, 1)
                    task.delay(1, function()
                        if enemyHum then enemyHum.WalkSpeed = oldSpeed end
                    end)
                end
                task.delay(3, function() debounce = false end)
            end
        else
            local ownerPos = ownerCharacter.HumanoidRootPart.Position + Vector3.new(-4, 6, -4)
            drone.CFrame = drone.CFrame:Lerp(CFrame.new(ownerPos, ownerCharacter.HumanoidRootPart.Position), 0.1)
        end
    end)
    return drone
end

local function spawnJuggernautGuard(ownerCharacter)
    local guard, rootPart, humanoid, torso = buildHumanoidModel("JuggernautGuard", 1.5, Color3.fromRGB(50, 50, 50))
    humanoid.WalkSpeed = 10
    guard.Parent = Workspace
    rootPart.CFrame = ownerCharacter.PrimaryPart.CFrame * CFrame.new(-4, 0, 4)

    local debounce = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not guard.Parent or not ownerCharacter:FindFirstChild("HumanoidRootPart") then conn:Disconnect() return end
        
        local target, dist = getNearestAggressor(rootPart.Position)
        if target then
            humanoid:MoveTo(target.HumanoidRootPart.Position)
            if dist < 7 and not debounce then
                debounce = true
                local enemyHum = target:FindFirstChild("Humanoid")
                if enemyHum then
                    enemyHum:TakeDamage(50)
                    local bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(100000, 100000, 100000)
                    local dir = (target.HumanoidRootPart.Position - rootPart.Position).Unit
                    bv.Velocity = dir * 50 + Vector3.new(0, 20, 0)
                    bv.Parent = target.HumanoidRootPart
                    Debris:AddItem(bv, 0.2)
                    
                    local explosion = Instance.new("Explosion")
                    explosion.Position = target.HumanoidRootPart.Position
                    explosion.BlastRadius = 0
                    explosion.Parent = Workspace
                end
                task.delay(2.5, function() debounce = false end)
            end
        else
            humanoid:MoveTo(ownerCharacter.HumanoidRootPart.Position + Vector3.new(-6, 0, 6))
        end
    end)
    return guard
end

local function spawnJuggernautDrone(ownerCharacter)
    local drone = Instance.new("Part")
    drone.Size = Vector3.new(3, 1, 3)
    drone.Color = Color3.fromRGB(0, 0, 0)
    drone.Anchored = true
    drone.CanCollide = false
    drone.Parent = Workspace

    local debounce = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not drone.Parent or not ownerCharacter:FindFirstChild("HumanoidRootPart") then conn:Disconnect() return end
        
        local ownerPos = ownerCharacter.HumanoidRootPart.Position + Vector3.new(4, 8, -4)
        drone.CFrame = drone.CFrame:Lerp(CFrame.new(ownerPos, ownerCharacter.HumanoidRootPart.Position), 0.05)

        local ownerHum = ownerCharacter:FindFirstChild("Humanoid")
        if ownerHum and ownerHum.Health < ownerHum.MaxHealth and not debounce then
            debounce = true
            local ff = Instance.new("ForceField")
            ff.Parent = ownerCharacter
            Debris:AddItem(ff, 3)
            task.delay(10, function() debounce = false end)
        end
    end)
    return drone
end

local function spawnEPUGuard(ownerCharacter)
    local guard, rootPart, humanoid, torso = buildHumanoidModel("EPUGuard", 1, Color3.fromRGB(255, 0, 0))
    humanoid.WalkSpeed = 24
    
    local blade1 = Instance.new("Part")
    blade1.Size = Vector3.new(0.2, 4, 0.5)
    blade1.Color = Color3.fromRGB(0, 255, 255)
    blade1.Material = Enum.Material.Neon
    blade1.CanCollide = false
    blade1.Parent = guard

    local weld1 = Instance.new("Weld")
    weld1.Part0 = torso
    weld1.Part1 = blade1
    weld1.C0 = CFrame.new(1.2, 0, -1) * CFrame.Angles(math.pi/4, 0, 0)
    weld1.Parent = torso

    local blade2 = blade1:Clone()
    blade2.Parent = guard
    local weld2 = Instance.new("Weld")
    weld2.Part0 = torso
    weld2.Part1 = blade2
    weld2.C0 = CFrame.new(-1.2, 0, -1) * CFrame.Angles(math.pi/4, 0, 0)
    weld2.Parent = torso

    guard.Parent = Workspace
    rootPart.CFrame = ownerCharacter.PrimaryPart.CFrame * CFrame.new(0, 0, 6)

    local debounce = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not guard.Parent or not ownerCharacter:FindFirstChild("HumanoidRootPart") then conn:Disconnect() return end
        
        local target, dist = getNearestAggressor(rootPart.Position)
        if target then
            if dist > 30 and dist < 100 then
                rootPart.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
            end
            humanoid:MoveTo(target.HumanoidRootPart.Position)
            if dist < 6 and not debounce then
                debounce = true
                local enemyHum = target:FindFirstChild("Humanoid")
                if enemyHum then
                    enemyHum:TakeDamage(30)
                end
                task.delay(0.5, function() debounce = false end)
            end
        else
            humanoid:MoveTo(ownerCharacter.HumanoidRootPart.Position + Vector3.new(0, 0, 6))
        end
    end)
    return guard
end

local function spawnEPUDrone(ownerCharacter)
    local drone = Instance.new("Part")
    drone.Size = Vector3.new(2, 0.5, 2)
    drone.Color = Color3.fromRGB(255, 0, 0)
    drone.Material = Enum.Material.Neon
    drone.Anchored = true
    drone.CanCollide = false
    drone.Parent = Workspace

    local debounce = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not drone.Parent or not ownerCharacter:FindFirstChild("HumanoidRootPart") then conn:Disconnect() return end
        
        local target, dist = getNearestAggressor(drone.Position)
        if target then
            local targetPos = target.HumanoidRootPart.Position + Vector3.new(0, 15, 0)
            drone.CFrame = drone.CFrame:Lerp(CFrame.new(targetPos, target.HumanoidRootPart.Position), 0.2)
            if dist < 20 and not debounce then
                debounce = true
                local enemyHum = target:FindFirstChild("Humanoid")
                if enemyHum then
                    local laser = Instance.new("Part")
                    laser.Size = Vector3.new(0.5, dist, 0.5)
                    laser.Color = Color3.fromRGB(255, 0, 0)
                    laser.Material = Enum.Material.Neon
                    laser.Anchored = true
                    laser.CanCollide = false
                    laser.CFrame = CFrame.new(drone.Position, target.HumanoidRootPart.Position) * CFrame.new(0, 0, -dist/2)
                    laser.Parent = Workspace
                    Debris:AddItem(laser, 0.2)
                    enemyHum:TakeDamage(15)
                end
                task.delay(1, function() debounce = false end)
            end
        else
            local ownerPos = ownerCharacter.HumanoidRootPart.Position + Vector3.new(0, 10, -6)
            drone.CFrame = drone.CFrame:Lerp(CFrame.new(ownerPos, ownerCharacter.HumanoidRootPart.Position), 0.1)
        end
    end)
    return drone
end

local function deployAllUnits(character)
    for _, unit in ipairs(ActiveUnits) do
        if unit then unit:Destroy() end
    end
    table.clear(ActiveUnits)
    
    table.insert(ActiveUnits, spawnStandardGuard(character))
    table.insert(ActiveUnits, spawnStandardDrone(character))
    table.insert(ActiveUnits, spawnJuggernautGuard(character))
    table.insert(ActiveUnits, spawnJuggernautDrone(character))
    table.insert(ActiveUnits, spawnEPUGuard(character))
    table.insert(ActiveUnits, spawnEPUDrone(character))
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        if player.Name == OwnerName then
            task.wait(1)
            deployAllUnits(character)
        end
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player.Name == OwnerName and player.Character then
        deployAllUnits(player.Character)
    end
end