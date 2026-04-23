local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local OwnerName = "takipakipayer"

local function createGuard(ownerCharacter)
    local guard = Instance.new("Model")
    guard.Name = "Bodyguard"

    local rootPart = Instance.new("Part")
    rootPart.Name = "HumanoidRootPart"
    rootPart.Size = Vector3.new(2, 2, 1)
    rootPart.Transparency = 1
    rootPart.CanCollide = true
    rootPart.Parent = guard

    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = guard

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1, 1, 1)
    head.CanCollide = true
    head.Parent = guard

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.CanCollide = true
    torso.Parent = guard

    local baton = Instance.new("Part")
    baton.Name = "StunBaton"
    baton.Size = Vector3.new(0.5, 3, 0.5)
    baton.Color = Color3.fromRGB(255, 255, 0)
    baton.CanCollide = false
    baton.Parent = guard

    local function createMotor(name, p0, p1, c0)
        local m = Instance.new("Motor6D")
        m.Name = name
        m.Part0 = p0
        m.Part1 = p1
        m.C0 = c0
        m.Parent = p0
        return m
    end

    createMotor("RootJoint", rootPart, torso, CFrame.new(0, 0, 0))
    createMotor("Neck", torso, head, CFrame.new(0, 1.5, 0))

    local weld = Instance.new("Weld")
    weld.Part0 = torso
    weld.Part1 = baton
    weld.C0 = CFrame.new(1.5, 0, -1) * CFrame.Angles(math.pi/4, 0, 0)
    weld.Parent = torso

    guard.Parent = Workspace
    rootPart.CFrame = ownerCharacter.PrimaryPart.CFrame * CFrame.new(3, 0, 3)

    local debounce = false

    RunService.Heartbeat:Connect(function()
        if not ownerCharacter or not ownerCharacter:FindFirstChild("HumanoidRootPart") then return end
        if not rootPart or not guard.Parent then return end

        local target = nil
        local nearestDist = 50

        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name ~= OwnerName and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                local dist = (p.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    target = p.Character
                end
            end
        end

        if target then
            humanoid:MoveTo(target.HumanoidRootPart.Position)
            if nearestDist < 5 and not debounce then
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
                        if enemyHum then
                            enemyHum.WalkSpeed = oldSpeed
                        end
                    end)
                end
                task.delay(1.5, function()
                    debounce = false
                end)
            end
        else
            humanoid:MoveTo(ownerCharacter.HumanoidRootPart.Position + Vector3.new(4, 0, 4))
        end
    end)
end

local function createDrone(ownerCharacter)
    local drone = Instance.new("Part")
    drone.Name = "Drone"
    drone.Size = Vector3.new(2, 0.5, 2)
    drone.Color = Color3.fromRGB(100, 100, 100)
    drone.Anchored = true
    drone.CanCollide = false
    drone.Parent = Workspace

    local debounce = false

    RunService.Heartbeat:Connect(function()
        if not ownerCharacter or not ownerCharacter:FindFirstChild("HumanoidRootPart") then return end
        if not drone or not drone.Parent then return end

        local target = nil
        local nearestDist = 60

        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name ~= OwnerName and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                local dist = (p.Character.HumanoidRootPart.Position - drone.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    target = p.Character
                end
            end
        end

        if target then
            local targetPos = target.HumanoidRootPart.Position + Vector3.new(0, 6, 0)
            drone.CFrame = drone.CFrame:Lerp(CFrame.new(targetPos, target.HumanoidRootPart.Position), 0.1)

            if nearestDist < 12 and not debounce then
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
                        if enemyHum then
                            enemyHum.WalkSpeed = oldSpeed
                        end
                    end)
                end
                task.delay(3, function()
                    debounce = false
                end)
            end
        else
            local ownerPos = ownerCharacter.HumanoidRootPart.Position + Vector3.new(-4, 6, -4)
            drone.CFrame = drone.CFrame:Lerp(CFrame.new(ownerPos, ownerCharacter.HumanoidRootPart.Position), 0.1)
        end
    end)
end

local function onCharacterAdded(character, player)
    if player.Name == OwnerName then
        task.wait(1)
        createGuard(character)
        createDrone(character)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(character, player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        onCharacterAdded(player.Character, player)
    end
end