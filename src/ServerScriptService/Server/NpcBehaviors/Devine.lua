local stats = {
	ViewDistance = 200,
	AttackDelay = { Min = 2, Max = 10 },
	MoveDelay = { Min = 2, Max = 7 },
	AttackCooldown = 0.1,
	ProjectileSpeed = 300,
	AttackAmount = 3,
	NpcType = "Enemy",
}

local module = {
	OnStep = {
		{ Function = "SearchForTarget", Parameters = { "Player", stats.ViewDistance } },
		{ Function = "LeadTarget", Parameters = { true, 300, 2 } },
		{
			Function = "ShootProjectile",
			Parameters = { stats.AttackDelay, stats.AttackCooldown, stats.AttackAmount, stats.ProjectileSpeed },
			true,
		},

		{ Function = "MoveRandom", Parameters = { 20, stats.MoveDelay } },
	},

	TargetFound = {
		{ Function = "SwitchToState", Parameters = { "Attacking" } },
		{ Function = "MoveTowardsTarget" },
	},

	TargetLost = {
		{ Function = "SwitchToState", Parameters = { "Chasing" } },
		{ Function = "MoveTowardsTarget" },
	},

	OnSpawned = {
		{ Function = "PlayAnimation", Parameters = { "Idle", Enum.AnimationPriority.Core } },
		{ Function = "AddTag", Parameters = { "Enemy" } },
	},

	OnDied = {
		{ Function = "SwitchToState", Parameters = { "Dead" } },
		{ Function = "RemoveWithDelay", Parameters = { 1 } },
	},
}

return module
