-- The menus: Shop (Robux), Locker (your cosmetics and the coin shop), Quests,
-- and Arena (private server owners pick the arena).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Cosmetics)
local Shop = require(Shared.Shop)
local Arenas = require(Shared.Arenas)
local Quests = require(Shared.Quests)
local Level = require(Shared.Level)
local Format = require(Shared.Format)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local T = UI.Theme

local player = Players.LocalPlayer
local Panels = {}

local function act(actionName, argument)
	local ok, message = State.Action(actionName, argument)
	if not ok and message then
		Notifications.Show(message, "warning")
	end
	return ok
end

-- Robux prices come from Roblox, so they always match the Creator Dashboard
local priceCache = {}
local function robuxPrice(id, infoType, onReady)
	local key = tostring(infoType) .. id
	if priceCache[key] then
		onReady(priceCache[key])
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, infoType)
		end)
		if not ok then
			ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
		end
		if ok and info and info.PriceInRobux then
			priceCache[key] = info.PriceInRobux
			onReady(info.PriceInRobux)
		end
	end)
end

local function row(parent, height, order)
	return UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = T.Card,
		LayoutOrder = order or 0,
		Parent = parent,
	}, { UI.corner(10) })
end

local function heading(parent, text, order)
	UI.label(text, { Size = UDim2.new(1, -8, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Gold, LayoutOrder = order, Parent = parent })
end

local function note(parent, text, order)
	UI.label(text, { Size = UDim2.new(1, -8, 0, 20), Font = T.BodyFont, TextColor3 = T.Muted, TextWrapped = true, LayoutOrder = order, Parent = parent })
end

-- A small colour swatch so you can tell items apart at a glance
-- An item's name on its card, all at the same size whether it's short or long
local function itemName(card, text, width)
	local label = UI.label(text, { Position = UDim2.fromOffset(48, 0), Size = UDim2.new(width, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	UI.new("UITextSizeConstraint", { MaxTextSize = 20, Parent = label })
	return label
end

local function swatch(card, item)
	local color = item.head or item.color or (item.colors and item.colors[1]) or T.Muted
	UI.new("Frame", { Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = color, Parent = card }, { UI.corner(14), UI.stroke(T.Background, 2) })
end

local function cardButton(card, text, color, onClick)
	return UI.button(text, color, onClick, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 36), Parent = card })
end

------------------------------------------------------------------ Shop (Robux)
local function renderShop(body)
	local data = State.data
	if not data then
		return
	end
	UI.list(8).Parent = body
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	note(body, "Everything here is looks only. Nothing you buy helps you win.", nextOrder())

	heading(body, "Game pass (yours forever)", nextOrder())
	for _, pass in ipairs(Shop.Passes) do
		local card = row(body, 64, nextOrder())
		UI.label(pass.name, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.6, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		UI.label(pass.description, { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(0.68, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = T.BodyFont, TextColor3 = T.Muted, Parent = card })
		local button = cardButton(card, "...", T.Good)
		if State.HasPass(pass.id) then
			button.Text = "Owned"
			button.BackgroundColor3 = T.Card
		elseif pass.gamePassId == 0 then
			button.Text = "Coming soon"
			button.BackgroundColor3 = T.Card
		else
			robuxPrice(pass.gamePassId, Enum.InfoType.GamePass, function(price)
				button.Text = "R$ " .. price
			end)
			button.Activated:Connect(function()
				MarketplaceService:PromptGamePassPurchase(player, pass.gamePassId)
			end)
		end
	end

	for _, kind in ipairs(Cosmetics.Kinds) do
		local items = {}
		for _, item in ipairs(Cosmetics.List) do
			if item.kind == kind.id and item.source == "robux" then
				table.insert(items, item)
			end
		end
		if #items > 0 then
			heading(body, kind.name, nextOrder())
			for _, item in ipairs(items) do
				local card = row(body, 52, nextOrder())
				swatch(card, item)
				itemName(card, item.name, 0.6)
				local owned = data.cosmetics.owned[item.id]
				local equipped = data.cosmetics.equipped[item.kind] == item.id
				local button = cardButton(card, "...", T.Good)
				if owned then
					button.Text = equipped and "Equipped" or "Equip"
					button.BackgroundColor3 = equipped and T.Card or T.Accent
					button.Activated:Connect(function()
						act("EquipCosmetic", item.id)
					end)
				elseif item.productId == 0 then
					button.Text = "Coming soon"
					button.BackgroundColor3 = T.Card
				else
					robuxPrice(item.productId, Enum.InfoType.Product, function(price)
						button.Text = "R$ " .. price
					end)
					button.Activated:Connect(function()
						MarketplaceService:PromptProductPurchase(player, item.productId)
					end)
				end
			end
		end
	end
end

------------------------------------------------------------------ Locker
local lockerTab = "hammer"

local function howToGet(item, data)
	if item.source == "level" then
		return string.format("Reach level %d", item.level)
	elseif item.source == "earned" then
		local have = data.stats[item.rule] or 0
		local what = item.rule == "wins" and "wins" or "knockouts"
		return string.format("%d/%d %s", math.min(have, item.amount), item.amount, what)
	elseif item.source == "vip" then
		return "VIP pass"
	elseif item.source == "robux" then
		return "In the Shop"
	elseif item.source == "community" then
		return "Free Gift"
	end
	return ""
end

local function renderLocker(body)
	local data = State.data
	if not data then
		return
	end
	UI.list(8).Parent = body
	local vip = State.HasPass("VIP")

	-- Tabs, one per kind of cosmetic
	local tabs = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 36), BackgroundTransparency = 1, LayoutOrder = 0, Parent = body }, { UI.list(6, Enum.FillDirection.Horizontal) })
	for _, kind in ipairs(Cosmetics.Kinds) do
		UI.button(kind.short, kind.id == lockerTab and T.Accent or T.Card, function()
			lockerTab = kind.id
			Panels.Locker.refresh()
		end, { Size = UDim2.fromOffset(104, 34), Parent = tabs })
	end
	note(body, string.format("You have %s coins. Win matches, knock rivals out and finish quests to earn more.", Format.Number(data.coins)), 1)

	local order = 1
	for _, item in ipairs(Cosmetics.List) do
		if item.kind == lockerTab then
			order += 1
			local owns = Cosmetics.Owns(data, item, vip)
			local equipped = Cosmetics.Equipped(data, item.kind, vip)
			local isEquipped = equipped and equipped.id == item.id
			local card = row(body, 52, order)
			swatch(card, item)
			itemName(card, item.name, 0.55)
			if owns then
				local canTakeOff = isEquipped and not Cosmetics.Defaults[item.kind]
				cardButton(card, isEquipped and (canTakeOff and "Take off" or "Equipped") or "Equip", isEquipped and T.Card or T.Accent, function()
					if not isEquipped or canTakeOff then
						act("EquipCosmetic", item.id)
					end
				end)
			elseif item.source == "coins" then
				cardButton(card, Format.Number(item.price) .. " coins", data.coins >= item.price and T.Good or T.Card, function()
					act("BuyCosmetic", item.id)
				end)
			else
				cardButton(card, howToGet(item, data), T.Card, function()
					if item.source == "robux" or item.source == "vip" then
						Panels.Shop.open()
					elseif item.source == "community" and Panels.Community then
						Panels.Community.open()
					end
				end)
			end
		end
	end
end

------------------------------------------------------------------ Quests
local function renderQuests(body)
	local data = State.data
	if not data then
		return
	end
	UI.list(8).Parent = body
	local resetIn = 86400 - (os.time() % 86400)
	note(body, string.format("Three new quests every day. New quests in %s.", Format.Duration(resetIn)), 0)
	for index, entry in ipairs(data.quests.list) do
		local quest = Quests.ById[entry.id]
		if quest then
			local card = row(body, 64, index)
			UI.label(Quests.Text(entry), { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.62, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = entry.done and T.Good or T.Text, Parent = card })
			local back = UI.new("Frame", { Position = UDim2.fromOffset(12, 40), Size = UDim2.new(0.62, 0, 0, 12), BackgroundColor3 = T.Background, Parent = card }, { UI.corner(6) })
			UI.new("Frame", { Size = UDim2.fromScale(math.clamp(entry.progress / entry.goal, 0, 1), 1), BackgroundColor3 = entry.done and T.Good or T.Accent, Parent = back }, { UI.corner(6) })
			UI.label(entry.done and "Done!" or string.format("%d/%d  -  %d coins", entry.progress, entry.goal, quest.coins), {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(170, 26),
				TextColor3 = entry.done and T.Good or T.Gold,
				Parent = card,
			})
		end
	end
	heading(body, "Your record", 10)
	local stats = data.stats
	local _, level = Level.Progress(data.xp)
	note(body, string.format("Level %d  -  %d matches  -  %d wins  -  %d rounds won  -  %d knockouts  -  %d bonks landed", level, stats.matches, stats.wins, stats.rounds, stats.kos, stats.bonks), 11)
	note(body, string.format("Daily login streak: %d day%s", data.dailyStreak, data.dailyStreak == 1 and "" or "s"), 12)
end

------------------------------------------------------------------ Arena (private servers)
local function renderArena(body)
	UI.list(8).Parent = body
	note(body, "Your private server, your rules: pick the arena every round uses.", 0)
	local pick = ReplicatedStorage:GetAttribute("ArenaPick")
	local card = row(body, 52, 1)
	UI.label("Random (a different arena each round)", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	cardButton(card, pick == nil and "Picked" or "Pick", pick == nil and T.Card or T.Accent, function()
		act("PickArena", "random")
		task.wait(0.2)
		Panels.Arena.refresh()
	end)
	for index, arena in ipairs(Arenas.List) do
		local arenaCard = row(body, 64, index + 1)
		UI.label(arena.name, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.6, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = arena.color, Parent = arenaCard })
		UI.label(arena.description, { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(0.66, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = T.BodyFont, TextColor3 = T.Muted, Parent = arenaCard })
		cardButton(arenaCard, pick == arena.id and "Picked" or "Pick", pick == arena.id and T.Card or T.Accent, function()
			act("PickArena", arena.id)
			task.wait(0.2)
			Panels.Arena.refresh()
		end)
	end
end

function Panels.Init(screenGui)
	Panels.Shop = UI.window(screenGui, "Shop", renderShop)
	Panels.Locker = UI.window(screenGui, "Locker", renderLocker)
	Panels.Quests = UI.window(screenGui, "Daily Quests", renderQuests)
	Panels.Arena = UI.window(screenGui, "Pick the Arena", renderArena)

	State.Changed:Connect(function()
		for _, name in ipairs({ "Shop", "Locker", "Quests" }) do
			Panels[name].refresh()
		end
	end)
end

return Panels
