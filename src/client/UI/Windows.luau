--!strict
-- Modal window manager: one window open at a time, dimmed backdrop, pop-in
-- animation, close button and tap-outside-to-close.

local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

export type WindowSpec = {
	title: string,
	color: Color3?,
	size: Vector2?, -- preferred virtual size
	build: (content: Frame) -> (),
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

type WindowRecord = {
	spec: WindowSpec,
	frame: Frame,
	content: Frame,
	built: boolean,
}

local Windows = {}

local root: Frame? = nil
local backdrop: TextButton? = nil
local windows: { [string]: WindowRecord } = {}
local current: string? = nil
local listeners: { (string?) -> () } = {}

local function ensureRoot(): Frame
	if root then
		return root
	end
	local _, canvas = Kit.screen("SlimeWindows", 10)
	root = canvas
	backdrop = Kit.new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = canvas,
	});
	(backdrop :: TextButton).Activated:Connect(function()
		Windows.close()
	end)
	return canvas
end

local function fitSize(record: WindowRecord)
	local canvas = Kit.canvasSize(ensureRoot())
	local preferred = record.spec.size or Vector2.new(760, 470)
	local width = math.min(preferred.X, canvas.X - 40)
	local height = math.min(preferred.Y, canvas.Y - 70)
	record.frame.Size = UDim2.fromOffset(width, height)
end

function Windows.register(name: string, spec: WindowSpec)
	local parent = ensureRoot()
	local color = spec.color or Theme.Colors.Green
	local frame: Frame = Kit.new("Frame", {
		Name = name,
		BackgroundColor3 = Theme.Colors.Panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 12),
		Visible = false,
		ZIndex = 2,
		Parent = parent,
	})
	Kit.corner(18).Parent = frame
	Kit.stroke(Theme.Colors.Stroke, 4).Parent = frame
	Kit.new("UIScale", { Name = "OpenScale", Parent = frame })

	local titleBar: Frame = Kit.new("Frame", {
		Name = "TitleBar",
		BackgroundColor3 = color,
		Size = UDim2.new(1, 0, 0, 52),
		ZIndex = 3,
		Parent = frame,
	})
	Kit.corner(18).Parent = titleBar
	Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)).Parent = titleBar
	-- square off the bottom corners of the title bar
	Kit.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		ZIndex = 3,
		Parent = titleBar,
	})
	Kit.label({
		Name = "Title",
		Text = spec.title,
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.new(0, 20, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		MaxTextSize = 34,
		Parent = titleBar,
	})
	local close = Kit.button({
		text = "X",
		color = Theme.Colors.Red,
		size = UDim2.fromOffset(44, 44),
		position = UDim2.new(1, -8, 0, 4),
		anchor = Vector2.new(1, 0),
		onClick = function()
			Windows.close()
		end,
	})
	close.ZIndex = 5
	close.Parent = titleBar

	local content: Frame = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -70),
		Position = UDim2.fromOffset(12, 60),
		ZIndex = 3,
		Parent = frame,
	})

	windows[name] = { spec = spec, frame = frame, content = content, built = false }
end

function Windows.isOpen(name: string): boolean
	return current == name
end

function Windows.current(): string?
	return current
end

function Windows.onChanged(fn: (string?) -> ())
	table.insert(listeners, fn)
end

local function notify()
	for _, fn in listeners do
		task.spawn(fn, current)
	end
end

function Windows.close()
	if not current then
		return
	end
	local record = windows[current]
	current = nil
	if record then
		record.frame.Visible = false
		if record.spec.onClose then
			record.spec.onClose()
		end
	end
	local b = backdrop :: TextButton
	TweenService:Create(b, Theme.Tween.Fast, { BackgroundTransparency = 1 }):Play()
	task.delay(0.12, function()
		if not current then
			b.Visible = false
		end
	end)
	notify()
end

function Windows.open(name: string)
	local record = windows[name]
	if not record then
		return
	end
	if current == name then
		return
	end
	if current then
		local previous = windows[current]
		current = nil
		previous.frame.Visible = false
		if previous.spec.onClose then
			previous.spec.onClose()
		end
	end
	current = name
	if not record.built then
		record.built = true
		record.spec.build(record.content)
	end
	fitSize(record)
	local b = backdrop :: TextButton
	b.Visible = true
	TweenService:Create(b, Theme.Tween.Fast, { BackgroundTransparency = 0.45 }):Play()
	record.frame.Visible = true
	local scale = record.frame:FindFirstChild("OpenScale") :: UIScale
	scale.Scale = 0.8
	TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()
	if record.spec.onOpen then
		record.spec.onOpen()
	end
	notify()
end

function Windows.toggle(name: string)
	if current == name then
		Windows.close()
	else
		Windows.open(name)
	end
end

-- Small yes/no dialog on top of everything.
function Windows.confirm(title: string, body: string, confirmText: string, onConfirm: () -> ())
	local parent = ensureRoot()
	local existing = parent:FindFirstChild("Confirm")
	if existing then
		existing:Destroy()
	end
	local frame: Frame = Kit.new("Frame", {
		Name = "Confirm",
		BackgroundColor3 = Theme.Colors.Panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 230),
		ZIndex = 20,
		Parent = parent,
	})
	Kit.corner(18).Parent = frame
	Kit.stroke(Theme.Colors.Stroke, 4).Parent = frame
	Kit.label({
		Text = title,
		Size = UDim2.new(1, -30, 0, 40),
		Position = UDim2.fromOffset(15, 12),
		ZIndex = 21,
		MaxTextSize = 30,
		Parent = frame,
	})
	Kit.label({
		Text = body,
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.TextDim,
		Size = UDim2.new(1, -30, 0, 80),
		Position = UDim2.fromOffset(15, 58),
		TextWrapped = true,
		ZIndex = 21,
		MaxTextSize = 22,
		NoStroke = true,
		Parent = frame,
	})
	local yes = Kit.button({
		text = confirmText,
		color = Theme.Colors.Green,
		size = UDim2.fromOffset(170, 52),
		position = UDim2.new(0.5, 8, 1, -16),
		anchor = Vector2.new(0, 1),
		onClick = function()
			frame:Destroy()
			onConfirm()
		end,
	})
	yes.ZIndex = 21
	yes.Parent = frame
	local no = Kit.button({
		text = "Cancel",
		color = Theme.Colors.Grey,
		size = UDim2.fromOffset(170, 52),
		position = UDim2.new(0.5, -8, 1, -16),
		anchor = Vector2.new(1, 1),
		onClick = function()
			frame:Destroy()
		end,
	})
	no.ZIndex = 21
	no.Parent = frame
	Kit.pop(frame, 0.85)
end

return Windows
