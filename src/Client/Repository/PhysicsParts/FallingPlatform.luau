--!strict

-->insert-repository-warning<--

local GOLDEN_MASS = 4.8 -- this is the mass in cubic studs
local RELEASE_FORCE = Vector3.one * math.huge
local RELEASE_VELOCITY = math.huge

local _T = require(game:GetService("ReplicatedStorage").ClientTypes)

return function(scope: _T.Variables)
	local fallingPlatform, trove, utility = scope.parent, scope.trove, scope.utility
	if not fallingPlatform then return end

	local endPart = fallingPlatform:FindFirstChild("End")
	local platform = fallingPlatform:FindFirstChild("Platform")
	if not ((platform and platform:IsA("BasePart")) and (endPart and endPart:IsA("BasePart"))) then return end

	-- set up main platform --
	local platformAlign: AlignPosition? = platform:FindFirstChildWhichIsA("AlignPosition")
	if not platformAlign then return end

	for _, part: BasePart in platform:GetConnectedParts() do
		if part == platform then continue end
		if utility.hasTag(part, "Ignore") then continue end
		part.Massless = true
	end

	local massValue = utility.getConfig(fallingPlatform, "CustomMass", GOLDEN_MASS)
	local oldCustomPhysical = platform.CustomPhysicalProperties or platform.CurrentPhysicalProperties
	platform.CustomPhysicalProperties = PhysicalProperties.new(
		(1 / (platform.Mass * oldCustomPhysical.Density)) * massValue,
		oldCustomPhysical.Friction,
		oldCustomPhysical.Elasticity,
		oldCustomPhysical.FrictionWeight,
		oldCustomPhysical.ElasticityWeight
	)

	platformAlign.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	platformAlign.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	platformAlign.Position = platform.Position
	platform.Position = platform.Position - (platform.CFrame.UpVector * 2)
	platform.Anchored = false

	local oldForce: Vector3 = platformAlign.MaxAxesForce
	local oldVelocity: number = platformAlign.MaxVelocity
	local function reset(time: number)
		platformAlign.MaxAxesForce = RELEASE_FORCE
		platformAlign.MaxVelocity = RELEASE_VELOCITY
		task.wait(time)
		platformAlign.MaxAxesForce = oldForce
		platformAlign.MaxVelocity = oldVelocity
	end

	task.spawn(reset, 0.5)

	-- set up end platform --
	local platforms = {}
	for _, part: Instance in utility.tableUtil.Extend(platform:GetDescendants(), { platform }) do
		if not part:IsA("BasePart") then continue end
		if utility.hasTag(part, "Ignore") then continue end
		table.insert(platforms, {
			platform = part,
			transparency = part.Transparency,
			releaseTransparency = utility.getConfig(part, "ReleaseTransparency", 0.8),
			ignoreCanCollide = utility.hasTag(part, "IgnoreCanCollide"),
			ignoreTransparency = utility.hasTag(part, "IgnoreTransparency"),
			invert = utility.hasTag(part, "Invert"),
		})
	end

	local function togglePlatforms(toggle: boolean)
		for _, platformData in platforms do
			local isToggled = if platformData.invert then not toggle else toggle

			if not platformData.ignoreTransparency then
				platformData.platform.Transparency = if isToggled then platformData.transparency else platformData.releaseTransparency
			end
			if not platformData.ignoreCanCollide then --
				platformData.platform.CanCollide = isToggled
			end
		end
	end

	local currentTrove = trove:Extend()
	currentTrove:Add(function() trove:Remove(currentTrove) end)

	local debounce = false
	endPart.CanCollide = false
	currentTrove:Connect(endPart.Touched, function(hit: BasePart)
		if hit ~= platform then return end
		if debounce then return end
		debounce = true
		togglePlatforms(false)
		reset(1.5)
		togglePlatforms(true)
		debounce = false
	end)
end
