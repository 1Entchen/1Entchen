--!strict
-- Wrapper over AnalyticsService. Every call is pcall-protected so analytics
-- can never break gameplay. View results in Creator Dashboard > Analytics
-- (Economy, Funnels, Progression, Custom events).

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local function safe(fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn(`[Analytics] {err}`)
	end
end

-- Coins entering the economy (selling, rewards, purchases).
function Analytics.coinSource(
	player: Player,
	amount: number,
	balance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string
)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coins",
			amount,
			balance,
			transaction.Name,
			sku
		)
	end)
end

-- Coins leaving the economy (seeds, tiles, rebirth).
function Analytics.coinSink(
	player: Player,
	amount: number,
	balance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string
)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Coins",
			amount,
			balance,
			transaction.Name,
			sku
		)
	end)
end

function Analytics.onboarding(player: Player, step: number, stepName: string)
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function Analytics.funnel(player: Player, funnel: string, sessionId: string?, step: number, stepName: string)
	safe(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, stepName)
	end)
end

function Analytics.progression(player: Player, path: string, level: number, levelName: string?)
	safe(function()
		AnalyticsService:LogProgressionCompleteEvent(player, path, level, levelName)
	end)
end

function Analytics.custom(player: Player, eventName: string, value: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, eventName, value)
	end)
end

return Analytics
