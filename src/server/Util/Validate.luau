--!strict
-- Argument validators for remote payloads. Remote arguments are hostile:
-- they may be nil, NaN, infinite, huge strings or tables of any shape.

local Validate = {}

function Validate.integer(value: unknown, minimum: number, maximum: number): number?
	if typeof(value) ~= "number" then
		return nil
	end
	local n = value :: number
	if n ~= n or n ~= math.floor(n) or n < minimum or n > maximum then
		return nil
	end
	return n
end

function Validate.shortString(value: unknown, maxLength: number): string?
	if typeof(value) ~= "string" then
		return nil
	end
	local s = value :: string
	if #s == 0 or #s > maxLength then
		return nil
	end
	return s
end

function Validate.boolean(value: unknown): boolean?
	if typeof(value) ~= "boolean" then
		return nil
	end
	return value :: boolean
end

-- Character root position, or nil if the character is missing / dead.
function Validate.rootPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

function Validate.near(player: Player, position: Vector3, maxDistance: number): boolean
	local rootPosition = Validate.rootPosition(player)
	if not rootPosition then
		return false
	end
	return (rootPosition - position).Magnitude <= maxDistance
end

return Validate
