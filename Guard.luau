local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TS = game:GetService("TweenService")

local OWNER = owner
if not OWNER then return end
local function getChar() return OWNER.Character end
local function getRoot() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end

local WARN_DIST = 15
local hostiles = {}
local warned = {}
local allUnits = {}
local allDrones = {}
local running = true

local CONFIGS = {
	Guard = {HP=500,DMG=25,SPD=16,Name="Bodyguard",Offset=Vector3.new(6,0,2),
		Colors={Head="Medium stone grey",Torso="Medium blue",Arms="Medium stone grey",Legs="Dark stone grey"}},
	Elite = {HP=750,DMG=40,SPD=20,Name="Elite Unit",Offset=Vector3.new(-6,0,2),
		Colors={Head="Institutional white",Torso="Really black",Arms="Bright yellow",Legs="Really black"}},
	Juggernaut = {HP=1500,DMG=75,SPD=12,Name="Juggernaut",Offset=Vector3.new(0,0,8),
		Colors={Head="Bright red",Torso="Crimson",Arms="Dark stone grey",Legs="Crimson"}},
}

local function makePart(parent, name, size, color, mat, trans)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.BrickColor = BrickColor.new(color)
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = trans or 0
	p.CanCollide = false
	p.Anchored = false
	p.Parent = parent
	return p
end

local function makeMotor(parent, name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = parent
	return m
end

local function makeLabel(parent, text, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0,200,0,50)
	bb.StudsOffset = Vector3.new(0,3,0)
	bb.Adornee = parent
	bb.AlwaysOnTop = true
	bb.Parent = parent
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1,0,1,0)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextColor3 = color or Color3.new(1,1,1)
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Parent = bb
	return bb
end

local function buildRig(cfg)
	local model = Instance.new("Model")
	model.Name = cfg.Name
	local hrp = makePart(model,"HumanoidRootPart",Vector3.new(2,2,1),cfg.Colors.Torso,nil,1)
	local head = makePart(model,"Head",Vector3.new(1.2,1.2,1.2),cfg.Colors.Head)
	local torso = makePart(model,"Torso",Vector3.new(2,2,1),cfg.Colors.Torso)
	local la = makePart(model,"Left Arm",Vector3.new(1,2,1),cfg.Colors.Arms)
	local ra = makePart(model,"Right Arm",Vector3.new(1,2,1),cfg.Colors.Arms)
	local ll = makePart(model,"Left Leg",Vector3.new(1,2,1),cfg.Colors.Legs)
	local rl = makePart(model,"Right Leg",Vector3.new(1,2,1),cfg.Colors.Legs)
	torso.CanCollide = true
	makeMotor(hrp,"RootJoint",hrp,torso,CFrame.new(0,0,0),CFrame.new(0,0,0))
	makeMotor(torso,"Neck",torso,head,CFrame.new(0,1,0),CFrame.new(0,-0.6,0))
	makeMotor(torso,"Right Shoulder",torso,ra,CFrame.new(1,0.5,0),CFrame.new(-0.5,0.5,0))
	makeMotor(torso,"Left Shoulder",torso,la,CFrame.new(-1,0.5,0),CFrame.new(0.5,0.5,0))
	makeMotor(torso,"Right Hip",torso,rl,CFrame.new(1,-1,0),CFrame.new(0.5,1,0))
	makeMotor(torso,"Left Hip",torso,ll,CFrame.new(-1,-1,0),CFrame.new(-0.5,1,0))
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxassetid://7075502"
	face.Parent = head
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = cfg.HP
	hum.Health = cfg.HP
	hum.WalkSpeed = cfg.SPD
	hum.DisplayName = cfg.Name
	hum.Parent = model
	model.PrimaryPart = hrp
	makeLabel(head, cfg.Name, Color3.fromRGB(100,200,255))
	return model
end

local function buildDrone(droneName, parentUnit)
	local drone = Instance.new("Part")
	drone.Name = droneName
	drone.Size = Vector3.new(2,1,2)
	drone.Shape = Enum.PartType.Ball
	drone.BrickColor = BrickColor.new("Cyan")
	drone.Material = Enum.Material.Neon
	drone.CanCollide = false
	drone.Anchored = true
	drone.Parent = workspace
	makeLabel(drone, "Drone", Color3.fromRGB(0,255,255))
	return drone
end

local function distTo(a, b)
	if not a or not b then return math.huge end
	local p1 = (typeof(a) == "Instance" and a:IsA("Model")) and (a.PrimaryPart and a.PrimaryPart.Position) or (typeof(a) == "Instance" and a.Position) or nil
	local p2 = (typeof(b) == "Instance" and b:IsA("Model")) and (b.PrimaryPart and b.PrimaryPart.Position) or (typeof(b) == "Instance" and b.Position) or nil
	if not p1 or not p2 then return math.huge end
	return (p1 - p2).Magnitude
end

local function getPos(obj)
	if not obj then return nil end
	if typeof(obj) == "Instance" then
		if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart.Position end
		if obj:IsA("BasePart") then return obj.Position end
	end
	return nil
end

local function findThreat()
	local root = getRoot()
	if not root then return nil end
	local closest, dist = nil, math.huge
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= OWNER and plr.Character then
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			local r = plr.Character:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and r and hostiles[plr.Name] then
				local d = (root.Position - r.Position).Magnitude
				if d < dist then
					dist = d
					closest = plr
				end
			end
		end
	end
	return closest
end

local function fireProjectile(from, target, dmg)
	local startPos = (typeof(from) == "Instance" and from:IsA("BasePart") and from.Position) or getPos(from)
	local endPos = getPos(target)
	if not startPos or not endPos then return end
	local proj = Instance.new("Part")
	proj.Size = Vector3.new(0.5,0.5,2)
	proj.BrickColor = BrickColor.new("Bright red")
	proj.Material = Enum.Material.Neon
	proj.Anchored = true
	proj.CanCollide = false
	proj.CFrame = CFrame.lookAt(startPos, endPos)
	proj.Parent = workspace
	Debris:AddItem(proj, 1)
	local dir = (endPos - startPos).Unit
	local steps = 20
	task.spawn(function()
		for i = 1, steps do
			if not proj.Parent then break end
			proj.CFrame = CFrame.lookAt(startPos + dir * (i * 3), startPos + dir * ((i+1) * 3))
			local tRoot = nil
			if typeof(target) == "Instance" and target:IsA("Model") then
				tRoot = target:FindFirstChild("HumanoidRootPart")
			elseif typeof(target) == "Instance" and target:IsA("BasePart") then
				tRoot = target
			end
			if tRoot and (proj.Position - tRoot.Position).Magnitude < 4 then
				local hum = nil
				if target:IsA("Model") then hum = target:FindFirstChildOfClass("Humanoid") end
				if target.Parent and target.Parent:FindFirstChildOfClass("Humanoid") then hum = target.Parent:FindFirstChildOfClass("Humanoid") end
				if hum then hum:TakeDamage(dmg) end
				proj:Destroy()
				break
			end
			task.wait(0.03)
		end
		if proj.Parent then proj:Destroy() end
	end)
end

local function abilityShieldBash(unit)
	local pos = getPos(unit.Model)
	if not pos then return end
	local ring = Instance.new("Part")
	ring.Size = Vector3.new(12,1,12)
	ring.Shape = Enum.PartType.Cylinder
	ring.BrickColor = BrickColor.new("Bright blue")
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.5
	ring.Anchored = true
	ring.CanCollide = false
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0,0,math.rad(90))
	ring.Parent = workspace
	Debris:AddItem(ring, 0.5)
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= OWNER and plr.Character then
			local r = plr.Character:FindFirstChild("HumanoidRootPart")
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			if r and h and (pos - r.Position).Magnitude < 12 and hostiles[plr.Name] then
				h:TakeDamage(unit.Config.DMG * 1.5)
				local bv = Instance.new("BodyVelocity")
				bv.MaxForce = Vector3.new(1e5,1e5,1e5)
				bv.Velocity = (r.Position - pos).Unit * 80 + Vector3.new(0,40,0)
				bv.Parent = r
				Debris:AddItem(bv, 0.3)
			end
		end
	end
end

local function abilityRallyCry(unit)
	local pos = getPos(unit.Model)
	if not pos then return end
	for _, u in pairs(allUnits) do
		if u.Model and u.Model.Parent then
			local h = u.Model:FindFirstChildOfClass("Humanoid")
			if h then
				h.WalkSpeed = u.Config.SPD * 1.5
				task.delay(5, function() if h.Parent then h.WalkSpeed = u.Config.SPD end end)
			end
		end
	end
	local glow = Instance.new("Part")
	glow.Size = Vector3.new(8,8,8)
	glow.Shape = Enum.PartType.Ball
	glow.BrickColor = BrickColor.new("Bright green")
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.7
	glow.Anchored = true
	glow.CanCollide = false
	glow.Position = pos
	glow.Parent = workspace
	Debris:AddItem(glow, 1)
end

local function abilityDashStrike(unit, target)
	local uPos = getPos(unit.Model)
	local tChar = target and target.Character
	if not uPos or not tChar then return end
	local tRoot = tChar:FindFirstChild("HumanoidRootPart")
	local tHum = tChar:FindFirstChildOfClass("Humanoid")
	if not tRoot or not tHum then return end
	local hrp = unit.Model.PrimaryPart
	if hrp then
		hrp.CFrame = CFrame.new(tRoot.Position + (uPos - tRoot.Position).Unit * 3, tRoot.Position)
		tHum:TakeDamage(unit.Config.DMG * 2)
		local fx = Instance.new("Part")
		fx.Size = Vector3.new(4,4,4)
		fx.Shape = Enum.PartType.Ball
		fx.BrickColor = BrickColor.new("Bright yellow")
		fx.Material = Enum.Material.Neon
		fx.Transparency = 0.3
		fx.Anchored = true
		fx.CanCollide = false
		fx.Position = tRoot.Position
		fx.Parent = workspace
		Debris:AddItem(fx, 0.5)
	end
end

local function abilityBarrier()
	local root = getRoot()
	if not root then return end
	local shield = Instance.new("Part")
	shield.Size = Vector3.new(16,16,16)
	shield.Shape = Enum.PartType.Ball
	shield.BrickColor = BrickColor.new("Gold")
	shield.Material = Enum.Material.ForceField
	shield.Transparency = 0.6
	shield.Anchored = true
	shield.CanCollide = false
	shield.Position = root.Position
	shield.Parent = workspace
	local ff = Instance.new("ForceField")
	ff.Parent = getChar()
	Debris:AddItem(shield, 4)
	Debris:AddItem(ff, 4)
end

local function abilityGroundSlam(unit)
	local pos = getPos(unit.Model)
	if not pos then return end
	for i = 1, 3 do
		local ring = Instance.new("Part")
		ring.Size = Vector3.new(i*8, 0.5, i*8)
		ring.Shape = Enum.PartType.Cylinder
		ring.BrickColor = BrickColor.new("Bright red")
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.4
		ring.Anchored = true
		ring.CanCollide = false
		ring.CFrame = CFrame.new(pos - Vector3.new(0,2,0)) * CFrame.Angles(0,0,math.rad(90))
		ring.Parent = workspace
		Debris:AddItem(ring, 0.8)
	end
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= OWNER and plr.Character and hostiles[plr.Name] then
			local r = plr.Character:FindFirstChild("HumanoidRootPart")
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			if r and h and (pos - r.Position).Magnitude < 20 then
				h:TakeDamage(unit.Config.DMG * 2.5)
				local bv = Instance.new("BodyVelocity")
				bv.MaxForce = Vector3.new(1e5,1e5,1e5)
				bv.Velocity = Vector3.new(0,60,0)
				bv.Parent = r
				Debris:AddItem(bv, 0.4)
			end
		end
	end
end

local function abilityRageMode(unit)
	local h = unit.Model and unit.Model:FindFirstChildOfClass("Humanoid")
	if not h then return end
	h.MaxHealth = unit.Config.HP * 2
	h.Health = h.MaxHealth
	h.WalkSpeed = unit.Config.SPD * 2
	unit.RageDMG = unit.Config.DMG * 3
	local torso = unit.Model:FindFirstChild("Torso")
	local glow
	if torso then
		glow = Instance.new("PointLight")
		glow.Color = Color3.new(1,0,0)
		glow.Brightness = 5
		glow.Range = 15
		glow.Parent = torso
	end
	task.delay(8, function()
		if h.Parent then
			h.MaxHealth = unit.Config.HP
			h.Health = math.min(h.Health, unit.Config.HP)
			h.WalkSpeed = unit.Config.SPD
			unit.RageDMG = nil
			if glow then glow:Destroy() end
		end
	end)
end

local function abilityDroneLaser(drone, target)
	local tChar = target and target.Character
	if not tChar or not drone or not drone.Parent then return end
	for i = 1, 5 do
		fireProjectile(drone, tChar, 10)
		task.wait(0.15)
	end
end

local function abilityDroneShield(drone)
	if not drone or not drone.Parent then return end
	local s = Instance.new("Part")
	s.Size = Vector3.new(6,6,6)
	s.Shape = Enum.PartType.Ball
	s.Material = Enum.Material.ForceField
	s.Transparency = 0.7
	s.BrickColor = BrickColor.new("Cyan")
	s.Anchored = true
	s.CanCollide = false
	s.Position = drone.Position
	s.Parent = workspace
	Debris:AddItem(s, 3)
end

local function abilityDroneEMP(drone)
	if not drone or not drone.Parent then return end
	local emp = Instance.new("Part")
	emp.Size = Vector3.new(20,20,20)
	emp.Shape = Enum.PartType.Ball
	emp.Material = Enum.Material.Neon
	emp.BrickColor = BrickColor.new("Electric blue")
	emp.Transparency = 0.6
	emp.Anchored = true
	emp.CanCollide = false
	emp.Position = drone.Position
	emp.Parent = workspace
	Debris:AddItem(emp, 0.6)
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= OWNER and plr.Character and hostiles[plr.Name] then
			local r = plr.Character:FindFirstChild("HumanoidRootPart")
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			if r and h and (drone.Position - r.Position).Magnitude < 20 then
				h.WalkSpeed = 4
				task.delay(3, function() if h.Parent then h.WalkSpeed = 16 end end)
			end
		end
	end
end

local function warnPlayer(plr)
	if warned[plr.Name] and tick() - warned[plr.Name] < 5 then return end
	warned[plr.Name] = tick()
	local head = plr.Character and plr.Character:FindFirstChild("Head")
	if head then
		local w = makeLabel(head, "⚠ BACK AWAY ⚠", Color3.fromRGB(255,50,50))
		Debris:AddItem(w, 3)
	end
	for _, u in pairs(allUnits) do
		local uHead = u.Model and u.Model:FindFirstChild("Head")
		if uHead then
			local hum = u.Model:FindFirstChildOfClass("Humanoid")
			if hum then pcall(function() hum:Chat("Warning: Step away from the VIP!") end) end
		end
	end
end

local function spawnUnit(unitType, cfg)
	local model = buildRig(cfg)
	local root = getRoot()
	if root then
		model:SetPrimaryPartCFrame(CFrame.new(root.Position + cfg.Offset))
	end
	model.Parent = workspace
	local unit = {Model = model, Type = unitType, Config = cfg, AbilityCooldown = 0, Target = nil, Drones = {}, RageDMG = nil}
	for i = 1, 3 do
		local d = buildDrone(unitType .. "_Drone_" .. i, model)
		table.insert(unit.Drones, {Part = d, Angle = (i-1) * (2*math.pi/3), AbilityCooldown = 0})
	end
	table.insert(allUnits, unit)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			task.wait(5)
			if running then
				for idx, u in pairs(allUnits) do
					if u == unit then
						for _, dr in pairs(u.Drones) do
							if dr.Part and dr.Part.Parent then dr.Part:Destroy() end
						end
						table.remove(allUnits, idx)
						break
					end
				end
				local newUnit = spawnUnit(unitType, cfg)
			end
		end)
	end
	return unit
end

local mainDrone = buildDrone("MainDrone", nil)
local mainDroneData = {Part = mainDrone, Angle = 0, AbilityCooldown = 0}

local function setupDamageDetection()
	local function onCharAdded(plr, char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then return end
		local lastHP = hum.Health
		hum.HealthChanged:Connect(function(newHP)
			if newHP < lastHP then
				if plr == OWNER then
					for _, other in pairs(Players:GetPlayers()) do
						if other ~= OWNER and other.Character then
							local r = other.Character:FindFirstChild("HumanoidRootPart")
							local oRoot = getRoot()
							if r and oRoot and (r.Position - oRoot.Position).Magnitude < 60 then
								hostiles[other.Name] = tick()
							end
						end
					end
				else
					for _, attacker in pairs(Players:GetPlayers()) do
						if attacker ~= OWNER and attacker ~= plr and attacker.Character then
							local r = attacker.Character:FindFirstChild("HumanoidRootPart")
							local vRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
							if r and vRoot and (r.Position - vRoot.Position).Magnitude < 15 then
								hostiles[attacker.Name] = tick()
							end
						end
					end
				end
			end
			lastHP = newHP
		end)
	end
	for _, plr in pairs(Players:GetPlayers()) do
		if plr.Character then onCharAdded(plr, plr.Character) end
		plr.CharacterAdded:Connect(function(c) onCharAdded(plr, c) end)
	end
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(c) onCharAdded(plr, c) end)
	end)
end

local function updateUnit(unit, dt)
	local model = unit.Model
	if not model or not model.Parent then return end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = model.PrimaryPart
	if not hum or not hrp or hum.Health <= 0 then return end
	local root = getRoot()
	if not root then return end
	local threat = findThreat()
	if threat and threat.Character then
		local tRoot = threat.Character:FindFirstChild("HumanoidRootPart")
		if tRoot then
			local dist = (hrp.Position - tRoot.Position).Magnitude
			if dist > 5 then
				hum:MoveTo(tRoot.Position)
			else
				local dmg = unit.RageDMG or unit.Config.DMG
				local tHum = threat.Character:FindFirstChildOfClass("Humanoid")
				if tHum and tHum.Health > 0 then
					tHum:TakeDamage(dmg * dt)
				end
			end
			if tick() > unit.AbilityCooldown then
				unit.AbilityCooldown = tick() + 10
				if unit.Type == "Guard" then
					abilityShieldBash(unit)
					task.delay(3, function() abilityRallyCry(unit) end)
				elseif unit.Type == "Elite" then
					abilityDashStrike(unit, threat)
					task.delay(4, function() abilityBarrier() end)
				elseif unit.Type == "Juggernaut" then
					abilityGroundSlam(unit)
					task.delay(5, function() abilityRageMode(unit) end)
				end
			end
		end
	else
		local targetPos = root.Position + root.CFrame:VectorToWorldSpace(unit.Config.Offset)
		local dist = (hrp.Position - targetPos).Magnitude
		if dist > 4 then
			hum:MoveTo(targetPos)
		end
	end
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= OWNER and plr.Character then
			local pRoot = plr.Character:FindFirstChild("HumanoidRootPart")
			if pRoot and root and (pRoot.Position - root.Position).Magnitude < WARN_DIST then
				warnPlayer(plr)
			end
		end
	end
end

local function updateDrone(droneData, anchorPos, dt, threat)
	local drone = droneData.Part
	if not drone or not drone.Parent then return end
	droneData.Angle = droneData.Angle + dt * 2
	local orbitR = 5
	local orbitH = 4
	local targetPos = anchorPos + Vector3.new(math.cos(droneData.Angle)*orbitR, orbitH, math.sin(droneData.Angle)*orbitR)
	drone.CFrame = drone.CFrame:Lerp(CFrame.new(targetPos), 0.1)
	if threat and threat.Character then
		local tRoot = threat.Character:FindFirstChild("HumanoidRootPart")
		if tRoot and (drone.Position - tRoot.Position).Magnitude < 50 then
			fireProjectile(drone, threat.Character, 8)
		end
		if tick() > droneData.AbilityCooldown then
			droneData.AbilityCooldown = tick() + 8
			local pick = math.random(1,3)
			if pick == 1 then abilityDroneLaser(drone, threat)
			elseif pick == 2 then abilityDroneShield(drone)
			else abilityDroneEMP(drone) end
		end
	end
end

local function cleanHostiles()
	for name, t in pairs(hostiles) do
		if tick() - t > 30 then hostiles[name] = nil end
		local plr = Players:FindFirstChild(name)
		if not plr or not plr.Character then hostiles[name] = nil end
		if plr and plr.Character then
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			if not h or h.Health <= 0 then hostiles[name] = nil end
		end
	end
end

setupDamageDetection()

for unitType, cfg in pairs(CONFIGS) do
	spawnUnit(unitType, cfg)
end

OWNER.CharacterAdded:Connect(function(char)
	task.wait(1)
	for _, u in pairs(allUnits) do
		local root = getRoot()
		if root and u.Model and u.Model.PrimaryPart then
			u.Model:SetPrimaryPartCFrame(CFrame.new(root.Position + u.Config.Offset))
		end
	end
end)

RS.Heartbeat:Connect(function(dt)
	if not running then return end
	local root = getRoot()
	if not root then return end
	local threat = findThreat()
	for _, unit in pairs(allUnits) do
		updateUnit(unit, dt)
		local uPos = getPos(unit.Model)
		if uPos then
			for _, droneData in pairs(unit.Drones) do
				updateDrone(droneData, uPos, dt, threat)
			end
		end
	end
	updateDrone(mainDroneData, root.Position, dt, threat)
	cleanHostiles()
end)