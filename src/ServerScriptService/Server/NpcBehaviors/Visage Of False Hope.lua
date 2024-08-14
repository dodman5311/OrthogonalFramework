local CollectionService = game:GetService("CollectionService")
local rng = Random.new()

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Globals = require(ReplicatedStorage.Shared.Globals)
local spawners = require(Globals.Server.Services.Spawners)
local net = require(Globals.Packages.Net)
local util = require(Globals.Vendor.Util)
local timer = require(Globals.Vendor.Timer)

local vfx = net:RemoteEvent("ReplicateEffect")
local createProjectileRemote = net:RemoteEvent("CreateProjectile")

local moveChances = {
	--{ "SinkRoom", 10 },
	--{ "Geysers", 25 },
	--{ "Sacrifice", 15 },

	{ "Fire", 25 },
	{ "Grenades", 40 },
	{ "Rockets", 100 },
}

local function indicateAttack(npc, color)
	net:RemoteEvent("ReplicateEffect"):FireAllClients("IndicateVisageAttack", "Server", true, npc.Instance, color)
	timer.wait(0.5)
end

local function doForBarrels(npc, callback)
	for _, barrel in ipairs(npc.Instance.Apature:GetChildren()) do
		if barrel.Name ~= "Barrel" then
			continue
		end

		callback(barrel)
	end
end

local function MoveApatureTo(npc, yAlpha, rotationAngle, speed)
	local root = npc.Instance.PrimaryPart

	if speed then
		npc.Instance.Apature.AlignPosition.MaxVelocity = speed
	else
		npc.Instance.Apature.AlignPosition.MaxVelocity = 2500
	end

	if yAlpha then
		local yPos = (yAlpha * (75 * 2)) - 75
		root.ApatureRoot.Position = Vector3.new(0, yPos, 0)
	end

	if rotationAngle then
		root.ApatureRoot.Orientation = Vector3.new(0, rotationAngle, 0)
	end
end

local function shootFireHitboxes(npc)
	doForBarrels(npc, function(barrel)
		local origin = barrel.Attachment.WorldCFrame

		local newPart = game.ReplicatedStorage.FireHitbox:Clone()
		newPart.Parent = workspace

		newPart.Position = origin.Position
		local goal = origin * CFrame.new(0, 0, -170)

		Debris:AddItem(newPart, 2)

		table.insert(npc.fireHitboxes, {
			part = newPart,
			startPosition = origin.Position,
			startSize = newPart.Size,
			goal = goal.Position,
			createdAt = os.clock(),
		})
	end)
end

local function processHitboxes(npc)
	for index, hitbox in ipairs(npc.fireHitboxes) do
		local t = os.clock() - hitbox.createdAt

		hitbox.part.Position = hitbox.startPosition:Lerp(hitbox.goal, t / 1.5)
		hitbox.part.Size = hitbox.startSize:Lerp(Vector3.new(20, 50, 50), t / 1.5)

		if t >= 1.5 then
			hitbox.part:Destroy()
			table.remove(npc.fireHitboxes, index)
		end
	end
end

local function checkHitboxes(npc)
	local playersHit = {}

	for _, hitbox in ipairs(npc.fireHitboxes) do
		local part = hitbox.part

		if not part then
			continue
		end

		for _, partHit in ipairs(workspace:GetPartsInPart(part)) do
			local humanoid, model = util.checkForHumanoid(partHit)

			local playerHit = Players:GetPlayerFromCharacter(model)

			if not playerHit or table.find(playersHit, playerHit) then
				continue
			end

			humanoid:TakeDamage(1)

			table.insert(playersHit, playerHit)
		end
	end
end

local function rotateForFire(npc)
	local startTime = os.clock()
	local lastStep = os.clock()
	local alpha = 0
	local hitBoxAlpha = 0

	local raiseTime = 10
	local rotateTime = 3

	npc.fireHitboxes = {}

	return RunService.Heartbeat:Connect(function()
		local currentTime = os.clock() - startTime
		local step = os.clock() - lastStep

		alpha += step / raiseTime
		hitBoxAlpha += step

		MoveApatureTo(npc, alpha, (currentTime * 90) / rotateTime)

		if alpha >= 0.5 then
			alpha = -0.05
		end

		processHitboxes(npc)

		if hitBoxAlpha >= 0.075 then
			hitBoxAlpha = 0
			shootFireHitboxes(npc)
			checkHitboxes(npc)
		end

		lastStep = os.clock()
	end)
end

local function aimYAxisAtPlayer(npc)
	return RunService.Heartbeat:Connect(function()
		local target = npc:GetTarget()
		if not target then
			return
		end

		local root = npc.Instance.PrimaryPart

		local xyP = root.ApatureRoot.WorldPosition * Vector3.new(1, 0, 1)
		local npcPos2 = npc.Instance:GetPivot().Position * Vector3.new(1, 0, 1)
		local targetPos2 = target:GetPivot().Position * Vector3.new(1, 0, 1)

		local targetDistance = (npcPos2 - targetPos2).Magnitude

		root.ApatureRoot.WorldPosition = xyP + Vector3.new(0, target:GetPivot().Position.Y + (targetDistance / 3), 0)
	end)
end

local moves = {
	Fire = function(npc)
		local model = npc.Instance

		npc.Acts:createAct("InAction")

		MoveApatureTo(npc, 0, 0)

		indicateAttack(npc, Color3.fromRGB(255, 175, 100))

		util.PlaySound(model.PrimaryPart.Fire, model.PrimaryPart)

		vfx:FireAllClients("VisageFire", "Server", true, npc.Instance, true)
		local rotateOnStep = rotateForFire(npc)

		npc.Janitor:Add(rotateOnStep, "Disconnect")

		timer.wait(15)

		vfx:FireAllClients("VisageFire", "Server", true, npc.Instance, false)
		rotateOnStep:Disconnect()

		timer.wait(2)

		MoveApatureTo(npc, 0, 0)

		npc.Acts:removeAct("InAction")
	end,

	Rockets = function(npc)
		local model = npc.Instance

		npc.Acts:createAct("InAction")

		indicateAttack(npc, Color3.fromRGB(255, 150, 150))

		MoveApatureTo(npc, 0.8, 0, 250)
		timer.wait(2)

		for i = 1, 5 do
			util.PlaySound(model.PrimaryPart.Launch, model.PrimaryPart, 0.1)

			doForBarrels(npc, function(barrel)
				barrel.Attachment.Flash:Emit(3)
				barrel.Attachment.Smoke:Emit(3)

				createProjectileRemote:FireAllClients(200, barrel.Attachment.WorldCFrame, 0, 1, 5, 0, {
					Seeking = rng:NextNumber(0.5, 1),
					SeekProgression = -0.025,
					SplashRange = 12,
					SplashDamage = 3,
					SeekDistance = 9000,
					Size = 0,
				}, nil, "RocketProjectile")
			end)

			timer.wait(0.5)
			MoveApatureTo(npc, nil, i * 90)
			timer.wait(1)
		end

		timer.wait(2)

		MoveApatureTo(npc, 0, 0)

		npc.Acts:removeAct("InAction")
	end,

	Grenades = function(npc)
		local target = npc:GetTarget()

		if not target then
			return
		end

		local model = npc.Instance

		npc.Acts:createAct("InAction")

		local aimOnStep = aimYAxisAtPlayer(npc)

		indicateAttack(npc, Color3.fromRGB(230, 100, 255))

		npc.Janitor:Add(aimOnStep, "Disconnect")

		local offset = false
		for _ = 1, 10 do
			local npcPos2 = model:GetPivot().Position * Vector3.new(1, 0, 1)
			local targetPos2 = target:GetPivot().Position * Vector3.new(1, 0, 1)

			local targetDistance = (npcPos2 - targetPos2).Magnitude

			util.PlaySound(model.PrimaryPart.Launch, model.PrimaryPart, 0.1)

			doForBarrels(npc, function(barrel)
				barrel.Attachment.Flash:Emit(3)
				barrel.Attachment.Smoke:Emit(3)

				createProjectileRemote:FireAllClients(
					targetDistance / 1.5,
					barrel.Attachment.WorldCFrame,
					0,
					0,
					1.5,
					0,
					{
						Dropping = 0.65,
						Bouncing = true,
						SplashRange = 50,
						SplashDamage = 6,
					},
					nil,
					"GrenadeProjectile"
				)
			end)

			MoveApatureTo(npc, nil, offset and 0 or 45)

			offset = not offset

			timer.wait(1)
		end

		timer.wait(1)

		MoveApatureTo(npc, 0, 0)
		aimOnStep:Disconnect()
		npc.Acts:removeAct("InAction")
	end,
}

local function spawnEnemy(OriginCFrame)
	local spawnRange = 150
	local enemyToSpawn = "Tollsman"

	if rng:NextNumber(0, 100) <= 5 then
		enemyToSpawn = "Specimen"
	elseif rng:NextNumber(0, 100) <= 50 then
		enemyToSpawn = "Sentinel"
	end

	local spawnCFrame = OriginCFrame
		* CFrame.new(rng:NextNumber(-spawnRange, spawnRange), 2, rng:NextNumber(-spawnRange, spawnRange))

	local enemyModel = spawners.placeNewObject(10, spawnCFrame, "Enemy", enemyToSpawn)

	if not enemyModel then
		return
	end

	net:RemoteEvent("ReplicateEffect"):FireAllClients("EnemySpawned", "Server", true, spawnCFrame.Position)
end

local function runAttackTimer(npc)
	npc.Instance.PrimaryPart.Anchored = true

	if npc.Acts:checkAct("Run", "InAttack", "Melee") then
		return
	end

	local AttackTimer = npc:GetTimer(npc, "Special")

	AttackTimer.WaitTime = rng:NextNumber(2, 4)
	AttackTimer.Function = function()
		if npc.StatusEffects["Ice"] then
			return
		end

		for _, value in ipairs(moveChances) do
			if rng:NextNumber(0, 100) > value[2] then
				continue
			end

			if not npc.Acts:checkAct("InAction") then
				moves[value[1]](npc)
			end

			return
		end
	end
	AttackTimer.Parameters = { npc }

	AttackTimer:Run()
end

local function spawnEnemies(npc) -- 250 studs
	local origin = npc.Instance:GetPivot()

	local spawnTimer = npc:GetTimer("SpawnEnemies")

	spawnTimer.WaitTime = 8
	spawnTimer.Function = function()
		if #CollectionService:GetTagged("Enemy") > 7 then
			return
		end

		spawnEnemy(origin)
	end

	spawnTimer.Parameters = { npc }

	spawnTimer:Run()
end

-- local function setUp(npc)

-- end

local module = {
	OnStep = {
		{ Function = "Custom", Parameters = { spawnEnemies } },
		{ Function = "Custom", Parameters = { runAttackTimer } },
		{ Function = "SearchForTarget", Parameters = { "Player", math.huge } },
	},

	OnSpawned = {
		--{ Function = "Custom", Parameters = { setUp } },
		{ Function = "PlayAnimation", Parameters = { "Idle", Enum.AnimationPriority.Core } },
		{ Function = "AddTag", Parameters = { "Enemy" } },
	},

	OnDied = {
		{ Function = "SetCollision", Parameters = { "DeadBody" } },
		{ Function = "SwitchToState", Parameters = { "Dead" } },
		{ Function = "RemoveWithDelay", Parameters = { 1 } },
	},
}

return module
