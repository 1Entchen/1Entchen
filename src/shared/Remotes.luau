--!strict
-- The single list of remotes. The server creates them at startup; clients
-- only wait for them. Adding a remote = one line here.

local Remotes = {}

-- Client -> server requests. Every handler validates and rate limits.
Remotes.ClientToServer = {
	"Plant", -- (tile: number, speciesId: string)
	"Harvest", -- (tile: number)
	"HarvestAll", -- ()
	"SellAll", -- ()
	"SellSlime", -- (slimeId: number)
	"ToggleFavorite", -- (slimeId: number)
	"BuySeed", -- (speciesId: string)
	"UnlockTile", -- ()
	"ClaimDaily", -- ()
	"ClaimQuest", -- (index: number)
	"Rebirth", -- ()
	"UsePotion", -- (potion: string)
	"UseInstantGrow", -- ()
	"SetAutoHarvest", -- (enabled: boolean)
	"RequestSync", -- () client finished loading; resend full state
	"DevGrant", -- (productKey: string) -- Studio only, rejected in live servers
}

-- Server -> client pushes.
Remotes.ServerToClient = {
	"Sync", -- (sections: { [string]: any })
	"Stock", -- (StockState)
	"Weather", -- (WeatherState)
	"Notify", -- (text: string, kind: string?)
	"Announce", -- (text: string, color: Color3?)
	"Effect", -- (kind: string, data: { [string]: any })
}

return Remotes
