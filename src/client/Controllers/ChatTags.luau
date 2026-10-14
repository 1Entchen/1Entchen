--!strict
-- VIP chat tag (the VIP attribute is set by the server from verified pass
-- ownership; it is purely cosmetic).

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTags = {}

function ChatTags.start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local source = message.TextSource
		if not source then
			return nil
		end
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if not speaker or not speaker:GetAttribute("VIP") then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = `<font color="#FFC42E">[VIP]</font> {message.PrefixText}`
		return properties
	end
end

return ChatTags
