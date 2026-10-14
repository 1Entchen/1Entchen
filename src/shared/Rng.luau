--!strict
-- Small deterministic PRNG (xorshift32) so seeded rolls (daily quests) give
-- identical results on any server and under the Lune test runner, where
-- Roblox's Random class is unavailable.

local Rng = {}

function Rng.new(seed: number): () -> number
	local state = math.floor(math.abs(seed)) % 4294967296
	if state == 0 then
		state = 2463534242
	end
	return function(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state / 4294967296
	end
end

-- Mixes several integers into one seed.
function Rng.hash(...: number): number
	local h = 2166136261
	for i = 1, select("#", ...) do
		local value = math.floor(math.abs((select(i, ...))))
		for _ = 1, 4 do
			h = bit32.bxor(h, value % 256)
			h = (h * 16777619) % 4294967296
			value = value // 256
		end
	end
	return h
end

return Rng
