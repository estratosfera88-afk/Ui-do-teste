-- [[ AKATSUKI UI ONLY [v2.0 - BLOX FRUITS FARM MANAGER] - REFINED UNIFIED EDITION ]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local ContentProvider   = game:GetService("ContentProvider")

local player = Players.LocalPlayer

-- Limpa instância anterior da UI para evitar conexões e objetos duplicados.
if _G.AkatUIShutdown then
	pcall(_G.AkatUIShutdown)
end

-- ==================== ESTADO DOS TOGGLES DA UI ====================
local Configs = {
	-- FARM
	AutoFarm         = false,
	AutoQuest        = false,
	AutoLevel        = false,
	KillAura         = false,
	FarmPosition     = "Above NPC",
	FarmHeight       = 8,
	FightingStyle    = "Current",
	-- MASTERY
	AutoMastery      = false,
	MasteryType      = "Fighting Style",
	MasteryTarget    = 300,
	-- BOSS
	AutoBoss         = false,
	BossName         = "",
	BossQuest        = false,
	BossMode         = "Selected Boss",
	AutoServerSearch = false,
	ServerReason     = "Boss",
	-- MATERIAL
	AutoMaterial     = false,
	MaterialName     = "",
	MaterialAmount   = 10,
	-- FRUIT
	DetectFruit      = false,
	FruitNotification = false,
	FruitFilter      = "Any",
	-- SEA EVENTS
	AutoSeaEvent     = false,
	SeaEventName     = "Any",
	-- STATS
	AutoStats        = false,
	StatPrimary      = "Blox Fruit",
	StatSecondary    = "Defense",
	StatTertiary     = "Melee",
}

-- ==================== DYNAMIC UI COMPONENT & STATE MACHINE ====================
local UIState = "CLOSED"

local UI_TEXT = {
	SearchPlaceholder = "Pesquisar...",
	ConfirmCloseTitle = "Deseja fechar o script?",
	ConfirmBtn        = "Sim",
	CancelBtn         = "Não",
	Intro             = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKATSUKI</font>',
	Tabs = {
		Farm      = "Farm",
		Mastery   = "Mastery",
		Boss      = "Boss",
		Material  = "Material",
		Extras    = "Extras",
		Status    = "Status",
	},
	Options = {
		-- FARM
		AutoFarm        = { Title = "Auto Farm",       Desc = "Ativa o Farm Manager central. Detecta Level, Sea, Quest e NPC automaticamente." },
		AutoQuest       = { Title = "Auto Quest",      Desc = "Aceita e entrega Quests automaticamente conforme o Level atual." },
		AutoLevel       = { Title = "Auto Level",      Desc = "Detecta mudança de Level e atualiza área, Quest e NPC automaticamente." },
		KillAura        = { Title = "Kill Aura",       Desc = "Ataca o NPC alvo continuamente enquanto mantém a posição relativa." },
		FarmHeight      = { Title = "Farm Height",     Desc = "Distância (studs) acima do NPC para posicionamento do personagem." },
		-- MASTERY
		AutoMastery     = { Title = "Auto Mastery",    Desc = "Faz farm para aumentar o Mastery do equipamento selecionado." },
		-- BOSS
		AutoBoss        = { Title = "Auto Boss",       Desc = "Localiza e ataca o Boss selecionado automaticamente." },
		BossQuest       = { Title = "Boss Quest",      Desc = "Aceita a Quest do Boss antes de atacá-lo." },
		AutoServerSearch = { Title = "Auto Server",    Desc = "Troca de servidor automaticamente quando necessário." },
		-- MATERIAL
		AutoMaterial    = { Title = "Auto Material",   Desc = "Faz farm de material até atingir a quantidade configurada." },
		-- FRUIT
		DetectFruit     = { Title = "Detect Fruit",    Desc = "Monitora o workspace em busca de frutas spawned." },
		FruitNotification = { Title = "Fruit Notif",   Desc = "Exibe notificação quando uma fruta relevante for detectada." },
		-- SEA EVENTS
		AutoSeaEvent    = { Title = "Auto Sea Event",  Desc = "Participa automaticamente de eventos no mar." },
		-- STATS
		AutoStats       = { Title = "Auto Stats",      Desc = "Distribui pontos de atributo conforme a prioridade configurada." },
	}
}

local activeTab     = "Farm"
local tabButtons    = {}
local isExpanded    = false
local originalTrans = {}
local isConfirmOpen = false

-- ==================== DIMENSIONAMENTO RESPONSIVO ====================
local NORMAL_UI_SIZE   = Vector2.new(565, 385)
local EXPANDED_UI_SIZE = Vector2.new(905, 405)
local UI_SAFE_MARGIN   = 14

local function GetViewportSize()
	local camera = workspace.CurrentCamera
	if camera then return camera.ViewportSize end
	return Vector2.new(1280, 720)
end

local FLOATING_BUTTON_SIZE = Vector2.new(150, 48)
local FLOATING_GAP = 18

local function ClampFloatingPosition(pos)
	local vp = GetViewportSize()
	local halfW, halfH = FLOATING_BUTTON_SIZE.X / 2, FLOATING_BUTTON_SIZE.Y / 2
	local minX = halfW + 8
	local maxX = vp.X - halfW - 8
	local minY = halfH + 8
	local maxY = vp.Y - halfH - 8
	if pos.X < 210 and pos.Y > vp.Y - 210 then
		pos = Vector2.new(220, math.min(pos.Y, vp.Y - 230))
	end
	return Vector2.new(math.clamp(pos.X, minX, maxX), math.clamp(pos.Y, minY, maxY))
end

local function GetResponsiveUISizes()
	local vp = GetViewportSize()
	local maxW = math.max(1, vp.X - (UI_SAFE_MARGIN * 2))
	local maxH = math.max(1, vp.Y - (UI_SAFE_MARGIN * 2))
	local normalW   = math.min(NORMAL_UI_SIZE.X,   maxW)
	local normalH   = math.min(NORMAL_UI_SIZE.Y,   maxH)
	local expandedW = math.min(EXPANDED_UI_SIZE.X, maxW)
	local expandedH = math.min(EXPANDED_UI_SIZE.Y, maxH)
	return UDim2.fromOffset(normalW, normalH), UDim2.fromOffset(expandedW, expandedH)
end

local function ClampMainWrapperToViewport()
	if not mainWrapper or not mainWrapper.Parent then return end
	local vp   = GetViewportSize()
	local size = mainWrapper.AbsoluteSize
	local halfW = math.min(size.X / 2, math.max(0, vp.X / 2 - UI_SAFE_MARGIN))
	local halfH = math.min(size.Y / 2, math.max(0, vp.Y / 2 - UI_SAFE_MARGIN))
	local pos = mainWrapper.AbsolutePosition + (size / 2)
	local x = math.clamp(pos.X, halfW + UI_SAFE_MARGIN, vp.X - halfW - UI_SAFE_MARGIN)
	local y = math.clamp(pos.Y, halfH + UI_SAFE_MARGIN, vp.Y - halfH - UI_SAFE_MARGIN)
	mainWrapper.Position = UDim2.fromOffset(x, y)
end

-- ==================== SCREENGUI ====================
local screenGui           = Instance.new("ScreenGui")
screenGui.Name            = "DeltaAkatBFUI"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then
	uiParent = gethui()
else
	pcall(function() uiParent = game:GetService("CoreGui") end)
end

if uiParent:FindFirstChild("DeltaAkatBFUI") then
	pcall(function() uiParent.DeltaAkatBFUI:Destroy() end)
end

for _, bf in ipairs(Lighting:GetChildren()) do
	if bf:IsA("BlurEffect") and (bf.Name == "ConfirmBlur" or bf.Name == "IntroBlur") then
		pcall(function() bf:Destroy() end)
	end
end

screenGui.Parent = uiParent

local SharedClickSound     = Instance.new("Sound", screenGui)
SharedClickSound.Name      = "SharedClickSound"
SharedClickSound.SoundId   = "rbxassetid://6895079853"
SharedClickSound.Volume    = 0.6
SharedClickSound.Looped    = false

local function PlayUI_Click()
	pcall(function()
		SharedClickSound.TimePosition = 0
		SharedClickSound:Play()
	end)
end

local function RegistrarTransparencias(objeto)
	if originalTrans[objeto] then return end
	if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") or objeto:IsA("CanvasGroup") then
		originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
	elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
		originalTrans[objeto] = { TextTransparency = objeto.TextTransparency, BackgroundTransparency = objeto.BackgroundTransparency, TextStrokeTransparency = objeto.TextStrokeTransparency or 1 }
	elseif objeto:IsA("ImageLabel") or objeto:IsA("ImageButton") then
		originalTrans[objeto] = { ImageTransparency = objeto.ImageTransparency, BackgroundTransparency = objeto.BackgroundTransparency }
	elseif objeto:IsA("UIStroke") then
		originalTrans[objeto] = { Transparency = objeto.Transparency }
	end
end

local function AplicarFadeSincronizado(raiz, fadeOut, duracao)
	if not raiz or not raiz.Parent then return end
	local info = TweenInfo.new(duracao, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local function tratarObjeto(obj)
		if not obj or not obj.Parent then return end
		RegistrarTransparencias(obj)
		local orig = originalTrans[obj]
		if not orig then return end
		if orig.BackgroundTransparency ~= nil then
			local t = fadeOut and 1 or orig.BackgroundTransparency
			if obj.BackgroundTransparency ~= t then
				if duracao == 0 then obj.BackgroundTransparency = t
				else TweenService:Create(obj, info, {BackgroundTransparency = t}):Play() end
			end
		end
		if orig.TextTransparency ~= nil then
			local t = fadeOut and 1 or orig.TextTransparency
			if obj.TextTransparency ~= t then
				if duracao == 0 then obj.TextTransparency = t
				else TweenService:Create(obj, info, {TextTransparency = t}):Play() end
			end
		end
		if orig.ImageTransparency ~= nil then
			local t = fadeOut and 1 or orig.ImageTransparency
			if obj.ImageTransparency ~= t then
				if duracao == 0 then obj.ImageTransparency = t
				else TweenService:Create(obj, info, {ImageTransparency = t}):Play() end
			end
		end
		if orig.Transparency ~= nil then
			local t = fadeOut and 1 or orig.Transparency
			if obj.Transparency ~= t then
				if duracao == 0 then obj.Transparency = t
				else TweenService:Create(obj, info, {Transparency = t}):Play() end
			end
		end
	end
	tratarObjeto(raiz)
	for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name                = "FloatBtn"
FloatBtn.AnchorPoint         = Vector2.new(0.5, 0.5)
FloatBtn.Size                = UDim2.new(0, 44, 0, 44)
FloatBtn.Position            = UDim2.new(0.06, 0, 0.2, 0)
FloatBtn.Image               = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3    = Color3.fromRGB(15, 0, 0)
FloatBtn.Visible             = false
FloatBtn.ZIndex              = 100
FloatBtn.ClipsDescendants    = false
FloatBtn.AutoButtonColor     = false
if not FloatBtn:FindFirstChildOfClass("UICorner") then
	Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)
end

local FloatOpenSound         = Instance.new("Sound", FloatBtn)
FloatOpenSound.Name          = "FloatOpenSound"
FloatOpenSound.SoundId       = "rbxassetid://6310837681"
FloatOpenSound.Volume        = 0.2
FloatOpenSound.Looped        = false

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({FloatOpenSound, SharedClickSound})
	end)
end)

-- ==================== DRAG DO FLOATING BUTTON ====================
local dragToggleF  = false
local dragInputF   = nil
local dragStartF   = nil
local startPosF    = nil
local isDraggingF  = false

FloatBtn.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch)
		and not dragToggleF then
		dragToggleF  = true
		dragInputF   = input
		isDraggingF  = false
		dragStartF   = input.Position
		startPosF    = FloatBtn.Position
	end
end)

local SetUIState

-- ==================== DRAG DA JANELA PRINCIPAL ====================
local mainWrapper         = Instance.new("Frame", screenGui)
mainWrapper.Name          = "MainWrapper"
mainWrapper.AnchorPoint   = Vector2.new(0.5, 0.5)
mainWrapper.Size          = UDim2.new(0, 640, 0, 360)
mainWrapper.Position      = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible       = false
mainWrapper.ClipsDescendants = false
mainWrapper.ZIndex        = 1

local mainFrame           = Instance.new("Frame", mainWrapper)
mainFrame.Name            = "MainFrame"
mainFrame.Size            = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex          = 2
mainFrame.ClipsDescendants = false

local dragUIToggle = false
local dragUIInput  = nil
local dragUIStart  = nil
local startUIPos   = nil

mainFrame.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch)
		and not dragUIToggle then
		dragUIToggle = true
		dragUIInput  = input
		dragUIStart  = input.Position
		startUIPos   = mainWrapper.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragUIToggle and input == dragUIInput then
		local delta = input.Position - dragUIStart
		local vp    = workspace.CurrentCamera.ViewportSize
		local hw    = mainWrapper.Size.X.Offset / 2
		local hh    = mainWrapper.Size.Y.Offset / 2
		local newX  = startUIPos.X.Offset + delta.X
		local newY  = startUIPos.Y.Offset + delta.Y
		local absX  = vp.X * startUIPos.X.Scale + newX
		local absY  = vp.Y * startUIPos.Y.Scale + newY
		absX        = math.clamp(absX, hw, vp.X - hw)
		absY        = math.clamp(absY, hh, vp.Y - hh)
		mainWrapper.Position = UDim2.new(0, absX, 0, absY)
	end

	if dragToggleF and input == dragInputF then
		local delta   = input.Position - dragStartF
		if delta.Magnitude > 5 then isDraggingF = true end
		local vp      = workspace.CurrentCamera.ViewportSize
		local half    = 22
		local baseAbsX = vp.X * startPosF.X.Scale + startPosF.X.Offset
		local baseAbsY = vp.Y * startPosF.Y.Scale + startPosF.Y.Offset
		local newAbsX  = math.clamp(baseAbsX + delta.X, half, vp.X - half)
		local newAbsY  = math.clamp(baseAbsY + delta.Y, half, vp.Y - half)
		FloatBtn.Position = UDim2.new(0, newAbsX, 0, newAbsY)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == dragInputF then
		if dragToggleF and not isDraggingF then
			if UIState == "MINIMIZED" or UIState == "CLOSED" then
				pcall(function()
					FloatOpenSound.TimePosition = 0
					FloatOpenSound:Play()
				end)
				SetUIState("OPEN")
			elseif UIState == "OPEN" then
				SetUIState("MINIMIZED")
			end
		end
		dragToggleF = false
		dragInputF  = nil
	end
	if input == dragUIInput then
		dragUIToggle = false
		dragUIInput  = nil
	end
end)

-- ==================== SHUTDOWN DA UI ====================
_G.AkatUIShutdown = function()
	pcall(function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
	end)
end

-- ==================== ESTRUTURA UNIFICADA DA JANELA ====================
local Shadow               = Instance.new("ImageLabel", mainFrame)
Shadow.Name                = "WindowShadow"
Shadow.AnchorPoint         = Vector2.new(0, 0)
Shadow.Position            = UDim2.new(0, -12, 0, -12)
Shadow.Size                = UDim2.new(1, 24, 1, 24)
Shadow.BackgroundTransparency = 1
Shadow.Image               = "rbxassetid://5554831957"
Shadow.ImageColor3         = Color3.fromRGB(5, 0, 1)
Shadow.ImageTransparency   = 0.40
Shadow.ScaleType           = Enum.ScaleType.Slice
Shadow.SliceCenter         = Rect.new(36, 36, 114, 114)
Shadow.ZIndex              = 3

local MainBackground       = Instance.new("Frame", mainFrame)
MainBackground.Name        = "MainBackground"
MainBackground.Size        = UDim2.new(1, 0, 1, 0)
MainBackground.BackgroundColor3 = Color3.fromRGB(15, 0, 3)
MainBackground.BorderSizePixel = 0
MainBackground.ClipsDescendants = true
MainBackground.ZIndex      = 4
Instance.new("UICorner", MainBackground).CornerRadius = UDim.new(0, 10)

local MainStroke           = Instance.new("UIStroke", MainBackground)
MainStroke.Name            = "MainStroke"
MainStroke.Thickness       = 2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Color           = Color3.fromRGB(255, 255, 255)

local MainStrokeGrad       = Instance.new("UIGradient", MainStroke)
MainStrokeGrad.Rotation    = 45
MainStrokeGrad.Color       = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(50,  0,  5)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 30))
})

local RedGradientOverlay   = Instance.new("Frame", MainBackground)
RedGradientOverlay.Name    = "RedGradientOverlay"
RedGradientOverlay.Size    = UDim2.new(1, 0, 1, 0)
RedGradientOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RedGradientOverlay.BackgroundTransparency = 0
RedGradientOverlay.BorderSizePixel = 0
RedGradientOverlay.ZIndex  = 4
Instance.new("UICorner", RedGradientOverlay).CornerRadius = UDim.new(0, 10)

local SingleRedGrad        = Instance.new("UIGradient", RedGradientOverlay)
SingleRedGrad.Rotation     = 90
SingleRedGrad.Color        = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(40, 0, 5)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 15, 22)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(40, 0, 5))
})

local LeftPanel            = Instance.new("Frame", MainBackground)
LeftPanel.Name             = "LeftPanel"
LeftPanel.Size             = UDim2.new(0, 220, 1, 0)
LeftPanel.Position         = UDim2.new(0, 0, 0, 0)
LeftPanel.BackgroundTransparency = 1
LeftPanel.ZIndex           = 5

local RightPanel           = Instance.new("Frame", MainBackground)
RightPanel.Name            = "RightPanel"
RightPanel.Size            = UDim2.new(1, -220, 1, 0)
RightPanel.Position        = UDim2.new(0, 220, 0, 0)
RightPanel.BackgroundTransparency = 1
RightPanel.ZIndex          = 5

-- ==================== HEADER ====================
local HeaderLeft           = Instance.new("Frame", LeftPanel)
HeaderLeft.Size            = UDim2.new(1, 0, 0, 36)
HeaderLeft.Position        = UDim2.new(0, 0, 0, 0)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex          = 20

local HeaderImage          = Instance.new("ImageLabel", HeaderLeft)
HeaderImage.Size           = UDim2.new(0, 24, 0, 24)
HeaderImage.Position       = UDim2.new(0, 10, 0.5, -12)
HeaderImage.BackgroundTransparency = 1
HeaderImage.Image          = "rbxthumb://type=Asset&id=134217291845443&w=150&h=150"
HeaderImage.ZIndex         = 21

local title                = Instance.new("TextLabel", HeaderLeft)
title.Size                 = UDim2.new(1, -44, 0, 16)
title.Position             = UDim2.new(0, 40, 0, 4)
title.BackgroundTransparency = 1
title.Text                 = "AKATSUKI SCRIPTS HUB"
title.TextColor3           = Color3.fromRGB(245, 245, 245)
title.TextSize             = 13
title.Font                 = Enum.Font.GothamBold
title.TextXAlignment       = Enum.TextXAlignment.Left
title.ZIndex               = 21

local subtitle             = Instance.new("TextLabel", HeaderLeft)
subtitle.Size              = UDim2.new(1, -44, 0, 12)
subtitle.Position          = UDim2.new(0, 40, 0, 20)
subtitle.BackgroundTransparency = 1
subtitle.Text              = "BLOX FRUITS | by zeni"
subtitle.TextColor3        = Color3.fromRGB(180, 180, 180)
subtitle.TextTransparency  = 0.2
subtitle.TextSize          = 9.5
subtitle.Font              = Enum.Font.Gotham
subtitle.TextXAlignment    = Enum.TextXAlignment.Left
subtitle.ZIndex            = 21

-- ==================== BARRA DE PESQUISA ====================
local SearchContainer      = Instance.new("Frame", LeftPanel)
SearchContainer.Name       = "SearchContainer"
SearchContainer.Size       = UDim2.new(1, -16, 0, 36)
SearchContainer.Position   = UDim2.new(0, 8, 0, 44)
SearchContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
SearchContainer.BackgroundTransparency = 0.85
SearchContainer.ZIndex     = 20
Instance.new("UICorner", SearchContainer).CornerRadius = UDim.new(0, 8)

local searchStroke         = Instance.new("UIStroke", SearchContainer)
searchStroke.Color         = Color3.fromRGB(60, 20, 20)
searchStroke.Transparency  = 0.75
searchStroke.Thickness     = 1

local searchTextBox        = Instance.new("TextBox", SearchContainer)
searchTextBox.Size         = UDim2.new(1, -16, 1, 0)
searchTextBox.Position     = UDim2.new(0, 10, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText  = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
searchTextBox.Text         = ""
searchTextBox.TextColor3   = Color3.fromRGB(230, 230, 230)
searchTextBox.Font         = Enum.Font.GothamMedium
searchTextBox.TextSize     = 13
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex       = 22
searchTextBox.Active       = true
searchTextBox.ClearTextOnFocus = false

-- ==================== TABS CONTAINER ====================
local TabsContainer        = Instance.new("ScrollingFrame", LeftPanel)
TabsContainer.Name         = "TabsContainer"
TabsContainer.Size         = UDim2.new(1, -8, 1, -152)
TabsContainer.Position     = UDim2.new(0, 4, 0, 87)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex       = 10
TabsContainer.CanvasSize   = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 2
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(200, 50, 50)
TabsContainer.ScrollBarImageTransparency = 0.45
TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local TabsLayout           = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder       = Enum.SortOrder.LayoutOrder
TabsLayout.Padding         = UDim.new(0, 2)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
	local contentH = TabsLayout.AbsoluteContentSize.Y + 8
	local minH     = TabsContainer.AbsoluteSize.Y + 12
	TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH, minH))
end

TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

-- ==================== ACTIVEBAR ====================
local ActiveBarContainer   = Instance.new("Frame", LeftPanel)
ActiveBarContainer.Name    = "ActiveBarContainer"
ActiveBarContainer.Size    = UDim2.new(1, -8, 1, -152)
ActiveBarContainer.Position = UDim2.new(0, 4, 0, 87)
ActiveBarContainer.BackgroundTransparency = 1
ActiveBarContainer.ClipsDescendants = true
ActiveBarContainer.ZIndex  = 8

local sharedActiveBar      = Instance.new("Frame", ActiveBarContainer)
sharedActiveBar.Name       = "SharedActiveBar"
sharedActiveBar.AnchorPoint = Vector2.new(0, 0.5)
sharedActiveBar.Size       = UDim2.new(0, 3, 0, 22)
sharedActiveBar.Position   = UDim2.new(0, 7, 0, 0)
sharedActiveBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sharedActiveBar.BorderSizePixel = 0
sharedActiveBar.Visible    = false
sharedActiveBar.ZIndex     = 8
Instance.new("UICorner", sharedActiveBar).CornerRadius = UDim.new(1, 0)

local activeBarScale = Instance.new("UIScale", sharedActiveBar)
activeBarScale.Scale = 1

local sharedBarGrad        = Instance.new("UIGradient", sharedActiveBar)
sharedBarGrad.Rotation     = 90
sharedBarGrad.Color        = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120, 0, 10)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(120, 0, 10))
})

-- ==================== USER PROFILE BADGE ====================
local UserProfileFrame     = Instance.new("Frame", LeftPanel)
UserProfileFrame.Size      = UDim2.new(1, -16, 0, 55)
UserProfileFrame.Position  = UDim2.new(0, 8, 1, -63)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
UserProfileFrame.BackgroundTransparency = 0.35
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex    = 20
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)

local userStroke           = Instance.new("UIStroke", UserProfileFrame)
userStroke.Thickness       = 0.9
userStroke.Color           = Color3.fromRGB(255, 255, 255)
local uGrad                = Instance.new("UIGradient", userStroke)
uGrad.Color                = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0))
})

local AvatarImage          = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size           = UDim2.new(0, 34, 0, 34)
AvatarImage.Position       = UDim2.new(0, 10, 0.5, -17)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image          = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex         = 21
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local AvatarStroke         = Instance.new("UIStroke", AvatarImage)
AvatarStroke.Thickness     = 0.9
AvatarStroke.Color         = Color3.fromRGB(255, 255, 255)
local avGrad               = Instance.new("UIGradient", AvatarStroke)
avGrad.Color               = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0))
})

local StatusIndicator      = Instance.new("Frame", AvatarImage)
StatusIndicator.Size       = UDim2.new(0, 9, 0, 9)
StatusIndicator.Position   = UDim2.new(1, -7, 1, -7)
StatusIndicator.BackgroundColor3 = Color3.fromRGB(40, 220, 80)
StatusIndicator.BorderSizePixel = 0
StatusIndicator.ZIndex     = 22
Instance.new("UICorner", StatusIndicator).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel     = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size      = UDim2.new(1, -82, 0, 16)
DisplayNameLabel.Position  = UDim2.new(0, 54, 0.5, -16)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text      = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
DisplayNameLabel.Font      = Enum.Font.GothamBold
DisplayNameLabel.TextSize  = 13.5
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex    = 21

local UsernameLabel        = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size         = UDim2.new(1, -82, 0, 14)
UsernameLabel.Position     = UDim2.new(0, 54, 0.5, 2)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text         = "@" .. player.Name
UsernameLabel.TextColor3   = Color3.fromRGB(110, 110, 110)
UsernameLabel.Font         = Enum.Font.Gotham
UsernameLabel.TextSize     = 11.5
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex       = 21

-- ==================== RIGHT PANEL HEADER ====================
local topButtons           = Instance.new("Frame", RightPanel)
topButtons.Size            = UDim2.new(1, -12, 0, 36)
topButtons.Position        = UDim2.new(0, 0, 0, 0)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex          = 20

local ControlsFrame        = Instance.new("Frame", topButtons)
ControlsFrame.Size         = UDim2.new(0, 130, 1, 0)
ControlsFrame.Position     = UDim2.new(1, -130, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex       = 25

local UIListTop            = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection    = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding          = UDim.new(0, 2)
UIListTop.SortOrder        = Enum.SortOrder.LayoutOrder

local TOP_BTN_COLOR        = Color3.fromRGB(150, 150, 150)

local function CriarBotaoTopo(nome, idAsset, ordem)
	local btn              = Instance.new("ImageButton", ControlsFrame)
	btn.Name               = nome
	btn.LayoutOrder        = ordem
	btn.Size               = UDim2.new(0, 28, 0, 28)
	btn.BackgroundTransparency = 1
	btn.ZIndex             = 25
	btn.AutoButtonColor    = false
	local icon             = Instance.new("ImageLabel", btn)
	icon.Name              = "Icon"
	icon.AnchorPoint       = Vector2.new(0.5, 0.5)
	icon.Position          = UDim2.new(0.5, 0, 0.5, 0)
	icon.Size              = UDim2.new(0, 14, 0, 14)
	icon.BackgroundTransparency = 1
	icon.Image             = idAsset
	icon.ImageColor3       = TOP_BTN_COLOR
	icon.ZIndex            = 26
	return btn, icon
end

local MinimizeBtn, MinimizeIcon = CriarBotaoTopo("MinimizeBtn", "rbxthumb://type=Asset&id=97090905107587&w=150&h=150", 1)
local ExpandBtn,   ExpandIcon   = CriarBotaoTopo("ExpandBtn",   "rbxthumb://type=Asset&id=78749046909931&w=150&h=150", 2)
local CloseBtn,    CloseIcon    = CriarBotaoTopo("CloseBtn",    "rbxthumb://type=Asset&id=70710316269357&w=150&h=150", 3)

local BadgeFrame           = Instance.new("Frame", RightPanel)
BadgeFrame.Name            = "BadgeFrame"
BadgeFrame.Size            = UDim2.new(0, 44, 0, 18)
BadgeFrame.Position        = UDim2.new(0, 12, 0, 9)
BadgeFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
BadgeFrame.BorderSizePixel = 0
BadgeFrame.ZIndex          = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(0, 8)

local badgeStroke          = Instance.new("UIStroke", BadgeFrame)
badgeStroke.Thickness      = 0.9
badgeStroke.Color          = Color3.fromRGB(255, 255, 255)

local badgeGrad            = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation         = 45
badgeGrad.Color            = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})

local badgeStrokeGrad      = Instance.new("UIGradient", badgeStroke)
badgeStrokeGrad.Rotation   = 45
badgeStrokeGrad.Color      = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})

local BadgeText            = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size             = UDim2.new(1, 0, 1, 0)
BadgeText.BackgroundTransparency = 1
BadgeText.Text             = "V2.0"
BadgeText.TextColor3       = Color3.fromRGB(255, 255, 255)
BadgeText.Font             = Enum.Font.GothamBold
BadgeText.TextSize         = 8.5
BadgeText.ZIndex           = 16

-- ==================== STATUS PANEL (Farm Manager Display) ====================
local StatusPanel          = Instance.new("Frame", RightPanel)
StatusPanel.Name           = "StatusPanel"
StatusPanel.Size           = UDim2.new(1, -12, 0, 80)
StatusPanel.Position       = UDim2.new(0, 6, 1, -90)
StatusPanel.BackgroundColor3 = Color3.fromRGB(12, 5, 6)
StatusPanel.BackgroundTransparency = 0.4
StatusPanel.BorderSizePixel = 0
StatusPanel.ZIndex         = 10
StatusPanel.ClipsDescendants = true
Instance.new("UICorner", StatusPanel).CornerRadius = UDim.new(0, 8)
local statusStroke         = Instance.new("UIStroke", StatusPanel)
statusStroke.Color         = Color3.fromRGB(80, 0, 10)
statusStroke.Thickness     = 1
statusStroke.Transparency  = 0.5

local statusLayout         = Instance.new("UIListLayout", StatusPanel)
statusLayout.SortOrder     = Enum.SortOrder.LayoutOrder
statusLayout.Padding       = UDim.new(0, 2)
statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
Instance.new("UIPadding", StatusPanel).PaddingLeft = UDim.new(0, 8)

local function MakeStatusRow(label, tag, order)
	local row = Instance.new("Frame", StatusPanel)
	row.Name  = tag .. "Row"
	row.Size  = UDim2.new(1, -8, 0, 14)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.ZIndex = 11

	local lbl = Instance.new("TextLabel", row)
	lbl.Size  = UDim2.new(0, 70, 1, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text  = label .. ":"
	lbl.TextColor3 = Color3.fromRGB(130, 130, 130)
	lbl.Font  = Enum.Font.Gotham
	lbl.TextSize = 10
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 12

	local val = Instance.new("TextLabel", row)
	val.Name  = tag .. "Value"
	val.Size  = UDim2.new(1, -74, 1, 0)
	val.Position = UDim2.new(0, 74, 0, 0)
	val.BackgroundTransparency = 1
	val.Text  = "—"
	val.TextColor3 = Color3.fromRGB(220, 220, 220)
	val.Font  = Enum.Font.GothamMedium
	val.TextSize = 10
	val.TextXAlignment = Enum.TextXAlignment.Left
	val.TextTruncate = Enum.TextTruncate.AtEnd
	val.ZIndex = 12

	return val
end

Instance.new("UIPadding", StatusPanel).PaddingTop = UDim.new(0, 6)
local statusValueMap = {}
local labelOffset = 0
statusValueMap["Status"]  = MakeStatusRow("Status",  "Status",  labelOffset + 1)
statusValueMap["Task"]    = MakeStatusRow("Task",    "Task",    labelOffset + 2)
statusValueMap["Target"]  = MakeStatusRow("Target",  "Target",  labelOffset + 3)
statusValueMap["Area"]    = MakeStatusRow("Area",    "Area",    labelOffset + 4)
statusValueMap["Level"]   = MakeStatusRow("Level",   "Level",   labelOffset + 5)

-- Atualiza o status display a cada 0.5s
task.spawn(function()
	while true do
		task.wait(0.5)
		local fs = _G.FarmState
		if not fs then continue end
		pcall(function()
			if statusValueMap["Status"] then statusValueMap["Status"].Text = fs.Status or "—" end
			if statusValueMap["Task"]   then statusValueMap["Task"].Text   = fs.CurrentTask or "—" end
			if statusValueMap["Target"] then statusValueMap["Target"].Text = fs.CurrentTarget or "—" end
			if statusValueMap["Area"]   then statusValueMap["Area"].Text   = fs.CurrentArea or "—" end
			if statusValueMap["Level"]  then statusValueMap["Level"].Text  = tostring(fs.Level or 0) .. " (Sea " .. tostring(fs.Sea or 1) .. ")" end
		end)
	end
end)

-- ==================== TOGGLES CONTAINER ====================
local togglesContainer     = Instance.new("ScrollingFrame", RightPanel)
togglesContainer.Name      = "TogglesContainer"
togglesContainer.Size      = UDim2.new(1, -12, 1, -134)
togglesContainer.Position  = UDim2.new(0, 6, 0, 42)
togglesContainer.BackgroundColor3 = Color3.fromRGB(30, 12, 14)
togglesContainer.BackgroundTransparency = 0.7
togglesContainer.BorderSizePixel = 0
togglesContainer.ClipsDescendants = true
togglesContainer.ZIndex    = 10
togglesContainer.ScrollBarThickness = 2
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
togglesContainer.ScrollBarImageTransparency = 0.35
togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.None
Instance.new("UICorner", togglesContainer).CornerRadius = UDim.new(0, 8)

local containerLayout      = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder  = Enum.SortOrder.LayoutOrder
containerLayout.Padding    = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding            = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingTop       = UDim.new(0, 8)
uiPadding.PaddingBottom    = UDim.new(0, 8)
uiPadding.PaddingLeft      = UDim.new(0, 4)
uiPadding.PaddingRight     = UDim.new(0, 6)

local function UpdateCanvasSize()
	local contentHeight = containerLayout.AbsoluteContentSize.Y + 24
	local minHeight     = togglesContainer.AbsoluteSize.Y + 1
	togglesContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentHeight, minHeight))
end

containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
togglesContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

-- ==================== CONFIRM FRAME ====================
local confirmBlur          = Instance.new("BlurEffect", Lighting)
confirmBlur.Name           = "ConfirmBlur"
confirmBlur.Size           = 0

local confirmOverlay       = Instance.new("Frame", screenGui)
confirmOverlay.Name        = "ConfirmOverlay"
confirmOverlay.Size        = UDim2.new(1, 0, 1, 0)
confirmOverlay.Position    = UDim2.new(0, 0, 0, 0)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.55
confirmOverlay.Visible     = false
confirmOverlay.ZIndex      = 990
confirmOverlay.ClipsDescendants = true

local confirmCard          = Instance.new("Frame", confirmOverlay)
confirmCard.Name           = "ConfirmCard"
confirmCard.Size           = UDim2.new(0, 300, 0, 130)
confirmCard.AnchorPoint    = Vector2.new(0.5, 0.5)
confirmCard.Position       = UDim2.new(0.5, 0, 0.5, 0)
confirmCard.BackgroundColor3 = Color3.fromRGB(18, 8, 8)
confirmCard.BackgroundTransparency = 0
confirmCard.BorderSizePixel = 0
confirmCard.ZIndex         = 995
Instance.new("UICorner", confirmCard).CornerRadius = UDim.new(0, 14)

local confirmStroke        = Instance.new("UIStroke", confirmCard)
confirmStroke.Thickness    = 1.5
confirmStroke.Color        = Color3.fromRGB(255, 255, 255)

local confStrokeGrad       = Instance.new("UIGradient", confirmStroke)
confStrokeGrad.Color       = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120, 0, 10)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(120, 0, 10))
})

local confirmLabel         = Instance.new("TextLabel", confirmCard)
confirmLabel.Size          = UDim2.new(1, -24, 0, 22)
confirmLabel.Position      = UDim2.new(0, 12, 0, 18)
confirmLabel.BackgroundTransparency = 1
confirmLabel.TextColor3    = Color3.fromRGB(235, 235, 235)
confirmLabel.Font          = Enum.Font.GothamBold
confirmLabel.TextSize      = 13
confirmLabel.TextXAlignment = Enum.TextXAlignment.Center
confirmLabel.Text          = UI_TEXT.ConfirmCloseTitle
confirmLabel.ZIndex        = 1000

local btnYes               = Instance.new("TextButton", confirmCard)
btnYes.Size                = UDim2.new(0, 118, 0, 32)
btnYes.Position            = UDim2.new(0.5, -124, 0, 62)
btnYes.BackgroundColor3    = Color3.fromRGB(139, 0, 0)
btnYes.TextColor3          = Color3.fromRGB(255, 255, 255)
btnYes.Font                = Enum.Font.GothamMedium
btnYes.TextSize            = 14
btnYes.Text                = UI_TEXT.ConfirmBtn
btnYes.ZIndex              = 1000
btnYes.BorderSizePixel     = 0
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 14)

local btnNo                = Instance.new("TextButton", confirmCard)
btnNo.Size                 = UDim2.new(0, 118, 0, 32)
btnNo.Position             = UDim2.new(0.5, 6, 0, 62)
btnNo.BackgroundColor3     = Color3.fromRGB(30, 30, 30)
btnNo.TextColor3           = Color3.fromRGB(170, 170, 170)
btnNo.Font                 = Enum.Font.GothamMedium
btnNo.TextSize             = 14
btnNo.Text                 = UI_TEXT.CancelBtn
btnNo.ZIndex               = 1000
btnNo.BorderSizePixel      = 0
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 14)

AplicarFadeSincronizado(confirmCard, true, 0)

-- ==================== RENDERSTEP ====================
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	SingleRedGrad.Rotation   = 90 + math.sin(t * 0.55) * 28
	confStrokeGrad.Rotation  = 90 + math.sin(t * 0.70) * 25
	uGrad.Rotation           = 45 + math.sin(t * 0.80) * 35
	avGrad.Rotation          = 45 + math.sin(t * 0.80) * 35
	badgeGrad.Rotation       = 45 + math.sin(t * 0.45) * 20
	badgeStrokeGrad.Rotation = 45 + math.sin(t * 0.45) * 20
end)

-- ==================== NOTIFICAÇÃO ====================
local ActiveNotifications = {}
local NOTIF_DURATION      = 10

local function UpdateNotifications()
	local currentY = -24
	for _, notif in ipairs(ActiveNotifications) do
		if notif and notif.Parent then
			local h = notif.Size.Y.Offset
			if h == 0 then h = 96 end
			TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -20, 1, currentY)
			}):Play()
			currentY = currentY - (h + 12)
		end
	end
end

local function CriarNotificacao(titulo, descricao)
	local notifHolder              = Instance.new("Frame", screenGui)
	notifHolder.Name               = "NotifHolder"
	notifHolder.AnchorPoint        = Vector2.new(1, 1)
	notifHolder.Size               = UDim2.new(0, 330, 0, 96)
	notifHolder.Position           = UDim2.new(1, 340, 1, -24)
	notifHolder.BackgroundTransparency = 1
	notifHolder.ZIndex             = 200
	notifHolder.ClipsDescendants   = false

	local notifScale = Instance.new("UIScale", notifHolder)
	notifScale.Scale = 0.96

	local notifCard                = Instance.new("Frame", notifHolder)
	notifCard.Name                 = "NotifCard"
	notifCard.Size                 = UDim2.new(1, 0, 1, 0)
	notifCard.BackgroundColor3     = Color3.fromRGB(16, 16, 18)
	notifCard.BackgroundTransparency = 0.25
	notifCard.BorderSizePixel      = 0
	notifCard.ZIndex               = 201
	Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

	local accentBar = Instance.new("Frame", notifCard)
	accentBar.Size  = UDim2.new(0, 4, 0, 52)
	accentBar.Position = UDim2.new(0, 14, 0.5, -26)
	accentBar.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 202
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

	local notifTitle = Instance.new("TextLabel", notifCard)
	notifTitle.Size  = UDim2.new(1, -56, 0, 18)
	notifTitle.Position = UDim2.new(0, 26, 0.5, -19)
	notifTitle.BackgroundTransparency = 1
	notifTitle.Text  = titulo or "AKATSUKI"
	notifTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
	notifTitle.Font  = Enum.Font.GothamBold
	notifTitle.TextSize = 16
	notifTitle.TextXAlignment = Enum.TextXAlignment.Left
	notifTitle.ZIndex = 203

	local notifDesc  = Instance.new("TextLabel", notifCard)
	notifDesc.Size   = UDim2.new(1, -56, 0, 18)
	notifDesc.Position = UDim2.new(0, 26, 0.5, 1)
	notifDesc.BackgroundTransparency = 1
	notifDesc.Text   = descricao or ""
	notifDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
	notifDesc.Font   = Enum.Font.Gotham
	notifDesc.TextSize = 12
	notifDesc.TextXAlignment = Enum.TextXAlignment.Left
	notifDesc.TextWrapped = true
	notifDesc.ZIndex = 203

	table.insert(ActiveNotifications, 1, notifHolder)
	UpdateNotifications()

	TweenService:Create(notifHolder, TweenInfo.new(0.30, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -20, 1, -24)
	}):Play()
	TweenService:Create(notifScale, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()

	task.delay(NOTIF_DURATION, function()
		for i, v in ipairs(ActiveNotifications) do
			if v == notifHolder then table.remove(ActiveNotifications, i) break end
		end
		UpdateNotifications()
		TweenService:Create(notifHolder, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 360, notifHolder.Position.Y.Scale, notifHolder.Position.Y.Offset)
		}):Play()
		task.delay(0.28, function()
			if notifHolder and notifHolder.Parent then notifHolder:Destroy() end
		end)
	end)
end

-- Expõe notificação para o backend
if _G.AkatCallbacks then
	_G.AkatCallbacks.Notification = CriarNotificacao
end

-- ==================== FILTRO / PESQUISA ====================
local filterDebounceThread = nil

local function filterToggles(currentActiveTab, query)
	local searchQuery = (query or ""):lower()
	local itemIndex   = 0
	for _, child in ipairs(togglesContainer:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
			local itemTab = child:GetAttribute("Tab") or "Farm"
			local shouldBeVisible = false
			if searchQuery ~= "" then
				local titleLabel = child:FindFirstChild("Title")
				local descLabel  = child:FindFirstChild("Description")
				local matchTitle = titleLabel and titleLabel.Text:lower():find(searchQuery) ~= nil
				local matchDesc  = descLabel  and descLabel.Text:lower():find(searchQuery)  ~= nil
				shouldBeVisible  = matchTitle or matchDesc
			else
				shouldBeVisible = (itemTab == currentActiveTab)
			end

			child.Visible = shouldBeVisible
			if shouldBeVisible then
				itemIndex = itemIndex + 1
				child.Size = UDim2.new(1, -10, 0, 0)
				child.BackgroundTransparency = 1
				local t = child:FindFirstChild("Title")
				local d = child:FindFirstChild("Description")
				if t then t.TextTransparency = 1 end
				if d then d.TextTransparency = 1 end
				local delay = (itemIndex - 1) * 0.02
				task.delay(delay, function()
					if not child or not child.Parent then return end
					TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, -10, 0, child:GetAttribute("ItemHeight") or 60), BackgroundTransparency = 0.45
					}):Play()
					if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
					if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
				end)
			end
		end
	end
	task.delay(0.05, function() pcall(UpdateCanvasSize) end)
end

-- ==================== ACTIVEBAR POSITION ====================
local function UpdateActiveBarPosition(animar)
	local targetBtn = tabButtons[activeTab]
	if not targetBtn or not sharedActiveBar.Visible then return end

	local MAX_DEFER  = 8
	local deferCount = 0

	local function aplicar()
		if not targetBtn or not targetBtn.Parent then return end
		deferCount = deferCount + 1
		local btnAbsSize = targetBtn.AbsoluteSize.Y
		local btnAbsPos  = targetBtn.AbsolutePosition.Y
		local panelAbsY  = ActiveBarContainer.AbsolutePosition.Y
		if (btnAbsSize == 0 or btnAbsPos == 0 or panelAbsY == 0) and deferCount < MAX_DEFER then
			task.defer(aplicar)
			return
		end
		local targetCenterY = btnAbsPos + (btnAbsSize / 2)
		local targetYPos    = targetCenterY - panelAbsY
		if animar then
			TweenService:Create(sharedActiveBar, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0, 7, 0, targetYPos)}):Play()
			activeBarScale.Scale = 1.08
			TweenService:Create(activeBarScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
		else
			sharedActiveBar.Position = UDim2.new(0, 7, 0, targetYPos)
			activeBarScale.Scale = 1
		end
	end

	task.defer(aplicar)
end

TabsContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	UpdateActiveBarPosition(false)
end)

-- ==================== SELECIONAR ABA ====================
local function selectTab(tabName)
	activeTab = tabName
	for name, btn in pairs(tabButtons) do
		local label         = btn:FindFirstChild("Label")
		local iconContainer = btn:FindFirstChild("Icon")
		local animSpeed     = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		if name == tabName then
			TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(45, 10, 15), BackgroundTransparency = 0.5}):Play()
			if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
			if iconContainer and iconContainer:FindFirstChild("AccentImage") then
				TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			end
		else
			TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 1}):Play()
			if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play() end
			if iconContainer and iconContainer:FindFirstChild("AccentImage") then
				TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
			end
		end
	end
	local targetBtn = tabButtons[tabName]
	if targetBtn then
		sharedActiveBar.Visible = true
		UpdateActiveBarPosition(true)
	end
	togglesContainer.CanvasPosition = Vector2.new(0, 0)
	searchTextBox.Text = ""
	filterToggles(tabName, "")
end

-- ==================== CRIAR BOTÃO DE ABA ====================
local TAB_ICONS = {
	Farm     = "rbxthumb://type=Asset&id=71234705040146&w=150&h=150",
	Mastery  = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150",
	Boss     = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150",
	Material = "rbxthumb://type=Asset&id=88409765080516&w=150&h=150",
	Extras   = "rbxthumb://type=Asset&id=97681798175944&w=150&h=150",
	Status   = "rbxthumb://type=Asset&id=131082536388353&w=150&h=150",
}

local function createTabBtn(tabName)
	local tabBtn               = Instance.new("TextButton", TabsContainer)
	tabBtn.Name                = tabName .. "TabBtn"
	tabBtn.Size                = UDim2.new(1, -16, 0, 36)
	tabBtn.BackgroundColor3    = Color3.fromRGB(15, 15, 15)
	tabBtn.BackgroundTransparency = 1
	tabBtn.Text                = ""
	tabBtn.ZIndex              = 11
	Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)

	local iconContainer        = Instance.new("Frame", tabBtn)
	iconContainer.Name         = "Icon"
	iconContainer.Size         = UDim2.new(0, 14, 0, 14)
	iconContainer.Position     = UDim2.new(0, 14, 0.5, -7)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex       = 12
	local imageLabel           = Instance.new("ImageLabel", iconContainer)
	imageLabel.Name            = "AccentImage"
	imageLabel.Size            = UDim2.new(1, 0, 1, 0)
	imageLabel.BackgroundTransparency = 1
	imageLabel.ZIndex          = 13
	imageLabel.ImageColor3     = Color3.fromRGB(150, 150, 150)
	imageLabel.Image           = TAB_ICONS[tabName] or ""

	local tabLabel             = Instance.new("TextLabel", tabBtn)
	tabLabel.Name              = "Label"
	tabLabel.Size              = UDim2.new(1, -42, 1, 0)
	tabLabel.Position          = UDim2.new(0, 38, 0, 0)
	tabLabel.BackgroundTransparency = 1
	tabLabel.TextColor3        = Color3.fromRGB(150, 150, 150)
	tabLabel.Font              = Enum.Font.GothamMedium
	tabLabel.TextSize          = 13
	tabLabel.TextXAlignment    = Enum.TextXAlignment.Left
	tabLabel.Text              = UI_TEXT.Tabs[tabName] or tabName
	tabLabel.ZIndex            = 12

	local tabScale = Instance.new("UIScale", tabBtn)
	tabScale.Scale = 1

	tabBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(tabScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.97}):Play()
		end
	end)
	tabBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(tabScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)
	tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
	tabButtons[tabName] = tabBtn
end

-- ==================== CRIAR TOGGLE ====================
local function createToggle(parent, configKey, tabCategory)
	local toggleFrame              = Instance.new("Frame")
	toggleFrame.Name               = configKey
	toggleFrame.Size               = UDim2.new(1, -10, 0, 60)
	toggleFrame:SetAttribute("ItemHeight", 60)
	toggleFrame.BackgroundColor3   = Color3.fromRGB(15, 5, 5)
	toggleFrame.BackgroundTransparency = 0.45
	toggleFrame.ZIndex             = 11
	toggleFrame.ClipsDescendants   = true
	toggleFrame:SetAttribute("Tab",       tabCategory)
	toggleFrame:SetAttribute("ConfigKey", configKey)
	toggleFrame.Parent             = parent
	Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 8)

	local optData                  = UI_TEXT.Options[configKey]
	local titleLabel               = Instance.new("TextLabel", toggleFrame)
	titleLabel.Name                = "Title"
	titleLabel.Size                = UDim2.new(0.7, 0, 0, 18)
	titleLabel.Position            = UDim2.new(0, 12, 0, 9)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3          = Color3.fromRGB(210, 210, 210)
	titleLabel.Font                = Enum.Font.GothamBold
	titleLabel.TextSize            = 13
	titleLabel.TextXAlignment      = Enum.TextXAlignment.Left
	titleLabel.Text                = optData and optData.Title or configKey
	titleLabel.ZIndex              = 11

	local descLabel                = Instance.new("TextLabel", toggleFrame)
	descLabel.Name                 = "Description"
	descLabel.Size                 = UDim2.new(0.7, 0, 0, 28)
	descLabel.Position             = UDim2.new(0, 12, 0, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3           = Color3.fromRGB(130, 130, 130)
	descLabel.Font                 = Enum.Font.Gotham
	descLabel.TextSize             = 10.5
	descLabel.TextXAlignment       = Enum.TextXAlignment.Left
	descLabel.TextYAlignment       = Enum.TextYAlignment.Top
	descLabel.TextWrapped          = true
	descLabel.Text                 = optData and optData.Desc or ""
	descLabel.ZIndex               = 11

	local switchTrack              = Instance.new("Frame", toggleFrame)
	switchTrack.Size               = UDim2.new(0, 48, 0, 24)
	switchTrack.Position           = UDim2.new(1, -54, 0.5, -12)
	switchTrack.BackgroundColor3   = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
	switchTrack.ZIndex             = 11
	Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

	local switchCircle             = Instance.new("Frame", switchTrack)
	switchCircle.Size              = UDim2.new(0, 18, 0, 18)
	switchCircle.Position          = Configs[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	switchCircle.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
	switchCircle.ZIndex            = 12
	Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)

	local triggerBtn               = Instance.new("TextButton", toggleFrame)
	triggerBtn.Size                = UDim2.new(1, 0, 1, 0)
	triggerBtn.BackgroundTransparency = 1
	triggerBtn.Text                = ""
	triggerBtn.ZIndex              = 13

	triggerBtn.MouseButton1Click:Connect(function()
		PlayUI_Click()
		Configs[configKey] = not Configs[configKey]
		local targetPos   = Configs[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
		local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
		local anim        = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
		TweenService:Create(switchTrack,  anim, {BackgroundColor3 = targetColor}):Play()

		-- Sincroniza com o backend
		if _G.AkatCallbacks and type(_G.AkatCallbacks[configKey]) == "function" then
			task.spawn(function()
				pcall(_G.AkatCallbacks[configKey], Configs[configKey])
			end)
		end
	end)

	return toggleFrame
end

-- ==================== CRIAR SLIDER ====================
local function createCompactSlider(parent, configKey, tabCategory, minValue, maxValue, defaultValue)
	local frame                    = Instance.new("Frame")
	frame.Name                     = configKey .. "Slider"
	frame.Size                     = UDim2.new(1, -10, 0, 60)
	frame:SetAttribute("ItemHeight", 60)
	frame.BackgroundColor3         = Color3.fromRGB(15, 5, 5)
	frame.BackgroundTransparency   = 0.45
	frame.ZIndex                   = 11
	frame.ClipsDescendants         = true
	frame:SetAttribute("Tab",       tabCategory)
	frame:SetAttribute("ConfigKey", configKey)
	frame.Parent                   = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local optData = UI_TEXT.Options[configKey]

	local titleLabel               = Instance.new("TextLabel", frame)
	titleLabel.Name                = "Title"
	titleLabel.Size                = UDim2.new(0.6, 0, 0, 16)
	titleLabel.Position            = UDim2.new(0, 12, 0, 9)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3          = Color3.fromRGB(210, 210, 210)
	titleLabel.Font                = Enum.Font.GothamBold
	titleLabel.TextSize            = 13
	titleLabel.TextXAlignment      = Enum.TextXAlignment.Left
	titleLabel.Text                = optData and optData.Title or configKey
	titleLabel.ZIndex              = 12

	local valueLabel               = Instance.new("TextLabel", frame)
	valueLabel.Name                = "Value"
	valueLabel.Size                = UDim2.new(0.35, 0, 0, 16)
	valueLabel.Position            = UDim2.new(0.65, -8, 0, 9)
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextColor3          = Color3.fromRGB(200, 80, 80)
	valueLabel.Font                = Enum.Font.GothamBold
	valueLabel.TextSize            = 12
	valueLabel.TextXAlignment      = Enum.TextXAlignment.Right
	valueLabel.Text                = tostring(defaultValue)
	valueLabel.ZIndex              = 12

	local track                    = Instance.new("Frame", frame)
	track.Name                     = "Track"
	track.Size                     = UDim2.new(1, -24, 0, 6)
	track.Position                 = UDim2.new(0, 12, 0, 38)
	track.BackgroundColor3         = Color3.fromRGB(40, 15, 18)
	track.ZIndex                   = 11
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill                     = Instance.new("Frame", track)
	fill.Name                      = "Fill"
	fill.Size                      = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3          = Color3.fromRGB(180, 20, 20)
	fill.ZIndex                    = 12
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local hit                      = Instance.new("TextButton", frame)
	hit.Size                       = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency     = 1
	hit.Text                       = ""
	hit.ZIndex                     = 15

	local dragging = false
	local currentValue = Configs[configKey] or defaultValue

	local function setValue(v, callback)
		v = math.clamp(v, minValue, maxValue)
		v = math.floor(v + 0.5)
		currentValue = v
		Configs[configKey] = v
		valueLabel.Text = tostring(v)
		local alpha = (v - minValue) / math.max(1, maxValue - minValue)
		TweenService:Create(fill, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
		if callback and _G.AkatCallbacks and type(_G.AkatCallbacks[configKey]) == "function" then
			pcall(_G.AkatCallbacks[configKey], v)
		end
	end

	local function updateFromInput(input)
		local x     = input.Position.X
		local left  = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		local alpha = math.clamp((x - left) / width, 0, 1)
		setValue(minValue + (maxValue - minValue) * alpha, true)
	end

	setValue(currentValue, false)

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return frame
end

-- ==================== CRIAR DROPDOWN (Simples) ====================
local function createDropdown(parent, configKey, tabCategory, options, defaultIndex)
	local frame                    = Instance.new("Frame")
	frame.Name                     = configKey .. "Dropdown"
	frame.Size                     = UDim2.new(1, -10, 0, 60)
	frame:SetAttribute("ItemHeight", 60)
	frame.BackgroundColor3         = Color3.fromRGB(15, 5, 5)
	frame.BackgroundTransparency   = 0.45
	frame.ZIndex                   = 11
	frame.ClipsDescendants         = true
	frame:SetAttribute("Tab",       tabCategory)
	frame:SetAttribute("ConfigKey", configKey)
	frame.Parent                   = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local optData = UI_TEXT.Options[configKey]

	local titleLabel               = Instance.new("TextLabel", frame)
	titleLabel.Name                = "Title"
	titleLabel.Size                = UDim2.new(0.55, 0, 0, 18)
	titleLabel.Position            = UDim2.new(0, 12, 0, 9)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3          = Color3.fromRGB(210, 210, 210)
	titleLabel.Font                = Enum.Font.GothamBold
	titleLabel.TextSize            = 13
	titleLabel.TextXAlignment      = Enum.TextXAlignment.Left
	titleLabel.Text                = optData and optData.Title or configKey
	titleLabel.ZIndex              = 11

	local selectedIdx = defaultIndex or 1
	local selectedVal = options[selectedIdx] or options[1]
	Configs[configKey] = selectedVal

	local valueBtn                 = Instance.new("TextButton", frame)
	valueBtn.Size                  = UDim2.new(0, 130, 0, 22)
	valueBtn.Position              = UDim2.new(1, -138, 0.5, -11)
	valueBtn.BackgroundColor3      = Color3.fromRGB(30, 10, 12)
	valueBtn.BackgroundTransparency = 0.3
	valueBtn.TextColor3            = Color3.fromRGB(220, 100, 100)
	valueBtn.Font                  = Enum.Font.GothamMedium
	valueBtn.TextSize              = 11
	valueBtn.Text                  = selectedVal
	valueBtn.ZIndex                = 12
	valueBtn.TextTruncate          = Enum.TextTruncate.AtEnd
	valueBtn.AutoButtonColor       = false
	Instance.new("UICorner", valueBtn).CornerRadius = UDim.new(0, 6)

	-- Dropdown list (simples, inline)
	local listOpen = false

	local function cycleOption()
		selectedIdx = (selectedIdx % #options) + 1
		selectedVal = options[selectedIdx]
		Configs[configKey] = selectedVal
		valueBtn.Text = selectedVal
		if _G.AkatCallbacks and type(_G.AkatCallbacks[configKey]) == "function" then
			task.spawn(function() pcall(_G.AkatCallbacks[configKey], selectedVal) end)
		end
	end

	valueBtn.MouseButton1Click:Connect(function()
		PlayUI_Click()
		cycleOption()
	end)

	return frame
end

-- ==================== EXPAND / UI STATE ====================
local function ApplyResponsiveWindowSize(animate)
	local normalSize, expandedSize = GetResponsiveUISizes()
	local targetSize = isExpanded and expandedSize or normalSize
	if animate then
		TweenService:Create(mainWrapper, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = targetSize}):Play()
	else
		mainWrapper.Size = targetSize
	end
	task.defer(ClampMainWrapperToViewport)
end

local isTransitioning = false

SetUIState = function(newState)
	if UIState == newState then return end
	if isTransitioning then return end
	isTransitioning = true

	local tempoAnim  = 0.25
	local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	if newState == "OPEN" then
		mainWrapper.Visible = true
		do local normalSize = select(1, GetResponsiveUISizes()); mainWrapper.Size = normalSize end
		AplicarFadeSincronizado(mainWrapper, true, 0)
		AplicarFadeSincronizado(mainWrapper, false, tempoAnim)
		local normalSize, expandedSize = GetResponsiveUISizes()
		local targetSize = isExpanded and expandedSize or normalSize
		local openTween  = TweenService:Create(mainWrapper, windowAnim, {Size = targetSize})
		openTween:Play()
		openTween.Completed:Connect(function()
			UIState         = "OPEN"
			isTransitioning = false
			selectTab(activeTab)
			filterToggles(activeTab, searchTextBox.Text)
			UpdateActiveBarPosition(false)
		end)

	elseif newState == "MINIMIZED" or newState == "CLOSED" then
		AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
		local vp = GetViewportSize()
		local shrinkSize = UDim2.fromOffset(
			math.min(NORMAL_UI_SIZE.X, math.max(1, vp.X - (UI_SAFE_MARGIN * 2))),
			math.min(NORMAL_UI_SIZE.Y, math.max(1, vp.Y - (UI_SAFE_MARGIN * 2)))
		)
		local closeTween = TweenService:Create(mainWrapper, windowAnim, {Size = shrinkSize})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			mainWrapper.Visible = false
			UIState             = newState
			isTransitioning     = false
		end)
	else
		isTransitioning = false
	end
end

ExpandBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	if UIState ~= "OPEN" then return end
	isExpanded = not isExpanded
	ApplyResponsiveWindowSize(true)
end)

MinimizeBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	SetUIState("MINIMIZED")
end)

-- ==================== CONFIRMAÇÃO DE FECHAMENTO ====================
local function AlternarConfirmacao(exibir)
	isConfirmOpen = exibir
	local tempoAnim = 0.25
	if exibir then
		mainWrapper.Visible    = false
		FloatBtn.Visible       = false
		confirmOverlay.Visible = true
		TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 28}):Play()
		local cardScale = Instance.new("UIScale", confirmCard)
		cardScale.Scale = 0.88
		TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		AplicarFadeSincronizado(confirmCard, false, tempoAnim)
	else
		TweenService:Create(confirmBlur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
		AplicarFadeSincronizado(confirmCard, true, tempoAnim)
		task.delay(tempoAnim + 0.05, function()
			if not isConfirmOpen then
				confirmOverlay.Visible = false
				if UIState == "OPEN" then mainWrapper.Visible = true end
				FloatBtn.Visible = true
			end
		end)
	end
end

CloseBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	AlternarConfirmacao(true)
end)

btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)

btnYes.MouseButton1Click:Connect(function()
	local syncTime = 0.2
	TweenService:Create(confirmBlur, TweenInfo.new(syncTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
	AplicarFadeSincronizado(confirmCard, true, syncTime)
	task.wait(syncTime)
	pcall(function() confirmBlur:Destroy() end)
	if _G.AkatUIShutdown then pcall(_G.AkatUIShutdown) end
	if _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
		pcall(_G.AkatCallbacks.ShutdownAll)
	end
end)

-- ==================== HOVER NOS BOTÕES DO TOPO ====================
local function AplicarEfeitoFisicoBotao(btn, icon, hoverColor)
	local btnScale = Instance.new("UIScale", btn)
	btnScale.Scale = 1
	btn.MouseEnter:Connect(function()
		if UIState ~= "OPEN" then return end
		TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = hoverColor}):Play()
	end)
	btn.MouseLeave:Connect(function()
		if UIState ~= "OPEN" then return end
		TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = TOP_BTN_COLOR}):Play()
		TweenService:Create(btnScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(btnScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.92}):Play()
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(btnScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)
end

AplicarEfeitoFisicoBotao(MinimizeBtn, MinimizeIcon, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(ExpandBtn,   ExpandIcon,   Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(CloseBtn,    CloseIcon,    Color3.fromRGB(255, 60,  60))

-- ==================== CRIAR ABAS ====================
createTabBtn("Farm")
createTabBtn("Mastery")
createTabBtn("Boss")
createTabBtn("Material")
createTabBtn("Extras")
createTabBtn("Status")

-- ==================== CRIAR TOGGLES E SLIDERS ====================

-- FARM
createToggle(togglesContainer, "AutoFarm",    "Farm")
createToggle(togglesContainer, "AutoQuest",   "Farm")
createToggle(togglesContainer, "AutoLevel",   "Farm")
createToggle(togglesContainer, "KillAura",    "Farm")
createCompactSlider(togglesContainer, "FarmHeight", "Farm", 2, 30, 8)
createDropdown(togglesContainer, "FightingStyle", "Farm",
	{"Current", "Black Leg", "Death Step", "Electric Claw", "Godhuman", "Dragon Talon", "Superhuman", "Fishman Karate"},
	1)
createDropdown(togglesContainer, "FarmPosition", "Farm",
	{"Above NPC", "Behind NPC", "Front of NPC", "Near NPC"},
	1)

-- MASTERY
createToggle(togglesContainer, "AutoMastery", "Mastery")
createDropdown(togglesContainer, "MasteryType", "Mastery",
	{"Fighting Style", "Sword", "Gun", "Blox Fruit"},
	1)
createCompactSlider(togglesContainer, "MasteryTarget", "Mastery", 1, 5000, 300)

-- BOSS
createToggle(togglesContainer, "AutoBoss",    "Boss")
createToggle(togglesContainer, "BossQuest",   "Boss")
createDropdown(togglesContainer, "BossName", "Boss",
	{"", "Saber Expert", "Warlord", "Rip_Indra", "Soul Reaper", "Stone", "Island Empress", "Darkbeard", "Control"},
	1)
createDropdown(togglesContainer, "BossMode", "Boss",
	{"Selected Boss", "Available Boss", "Boss Rotation"},
	1)
createToggle(togglesContainer, "AutoServerSearch", "Boss")
createDropdown(togglesContainer, "ServerReason", "Boss",
	{"Boss", "Event", "Material", "Fruit", "Other"},
	1)

-- MATERIAL
createToggle(togglesContainer, "AutoMaterial", "Material")
createDropdown(togglesContainer, "MaterialName", "Material",
	{"", "Leather", "Scrap Metal", "Angel Wings", "Fish Tail", "Mystic Droplet", "Saber Essence"},
	1)
createCompactSlider(togglesContainer, "MaterialAmount", "Material", 1, 999, 10)

-- EXTRAS (Fruit, Sea Events, Stats)
createToggle(togglesContainer, "DetectFruit",       "Extras")
createToggle(togglesContainer, "FruitNotification", "Extras")
createDropdown(togglesContainer, "FruitFilter", "Extras",
	{"Any", "Leopard", "Dragon", "Kitsune", "Spirit", "Dough"},
	1)
createToggle(togglesContainer, "AutoSeaEvent",  "Extras")
createDropdown(togglesContainer, "SeaEventName", "Extras",
	{"Any", "Raid", "Sea Beast", "Castle on the Sea"},
	1)
createToggle(togglesContainer, "AutoStats",    "Extras")
createDropdown(togglesContainer, "StatPrimary", "Extras",
	{"Blox Fruit", "Sword", "Gun", "Defense", "Melee"},
	1)
createDropdown(togglesContainer, "StatSecondary", "Extras",
	{"Defense", "Blox Fruit", "Sword", "Gun", "Melee"},
	1)
createDropdown(togglesContainer, "StatTertiary", "Extras",
	{"Melee", "Defense", "Blox Fruit", "Sword", "Gun"},
	1)

-- STATUS (display only — preenchido pelo updateStatus loop acima)
-- A aba Status mostra os valores do FarmState via statusValueMap.
-- Nenhum toggle aqui: é só leitura.
do
	local infoFrame = Instance.new("Frame")
	infoFrame.Name  = "StatusDisplay"
	infoFrame.Size  = UDim2.new(1, -10, 0, 120)
	infoFrame:SetAttribute("ItemHeight", 120)
	infoFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
	infoFrame.BackgroundTransparency = 0.45
	infoFrame.ZIndex = 11
	infoFrame.ClipsDescendants = true
	infoFrame:SetAttribute("Tab", "Status")
	infoFrame.Parent = togglesContainer
	Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 8)

	local infoTitle = Instance.new("TextLabel", infoFrame)
	infoTitle.Name  = "Title"
	infoTitle.Size  = UDim2.new(1, -12, 0, 18)
	infoTitle.Position = UDim2.new(0, 12, 0, 8)
	infoTitle.BackgroundTransparency = 1
	infoTitle.TextColor3 = Color3.fromRGB(210, 210, 210)
	infoTitle.Font = Enum.Font.GothamBold
	infoTitle.TextSize = 13
	infoTitle.TextXAlignment = Enum.TextXAlignment.Left
	infoTitle.Text = "Farm Manager Status"
	infoTitle.ZIndex = 12

	local infoDesc = Instance.new("TextLabel", infoFrame)
	infoDesc.Name  = "Description"
	infoDesc.Size  = UDim2.new(1, -12, 0, 90)
	infoDesc.Position = UDim2.new(0, 12, 0, 28)
	infoDesc.BackgroundTransparency = 1
	infoDesc.TextColor3 = Color3.fromRGB(130, 130, 130)
	infoDesc.Font = Enum.Font.Gotham
	infoDesc.TextSize = 10.5
	infoDesc.TextXAlignment = Enum.TextXAlignment.Left
	infoDesc.TextYAlignment = Enum.TextYAlignment.Top
	infoDesc.TextWrapped = true
	infoDesc.Text = "Status em tempo real na barra inferior da janela (painel Status)."
	infoDesc.ZIndex = 12
end

-- ==================== SEARCH BOX ====================
searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if filterDebounceThread then task.cancel(filterDebounceThread) end
	filterDebounceThread = task.delay(0.08, function()
		filterDebounceThread = nil
		filterToggles(activeTab, searchTextBox.Text)
	end)
end)

-- ==================== RESIZE RESPONSIVO ====================
local viewportConnection
local function BindViewportResize()
	if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
	local camera = workspace.CurrentCamera
	if not camera then return end
	viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if not mainWrapper or not mainWrapper.Parent then return end
		ApplyResponsiveWindowSize(UIState == "OPEN")
		ClampMainWrapperToViewport()
		UpdateActiveBarPosition(false)
		task.defer(UpdateCanvasSize)
		task.defer(UpdateTabsCanvas)
	end)
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindViewportResize)
BindViewportResize()

-- ==================== ANIMAÇÃO DE INTRODUÇÃO ====================
local function ExecutarIntroAkat()
	local Blur             = Instance.new("BlurEffect")
	Blur.Name              = "IntroBlur"
	Blur.Size              = 0
	Blur.Parent            = Lighting

	local IntroFrame       = Instance.new("Frame", screenGui)
	IntroFrame.Size        = UDim2.new(1, 0, 1, 0)
	IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	IntroFrame.BackgroundTransparency = 1
	IntroFrame.ZIndex      = 500

	local MaskContainer    = Instance.new("Frame", IntroFrame)
	MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10)
	MaskContainer.Size     = UDim2.new(0, 420, 0, 40)
	MaskContainer.BackgroundTransparency = 1
	MaskContainer.ClipsDescendants = true
	MaskContainer.ZIndex   = 501

	local IntroText        = Instance.new("TextLabel", MaskContainer)
	IntroText.Size         = UDim2.new(1, 0, 1, 0)
	IntroText.Position     = UDim2.new(0, 0, 1, 0)
	IntroText.BackgroundTransparency = 1
	IntroText.Font         = Enum.Font.GothamBold
	IntroText.TextSize     = 26
	IntroText.RichText     = true
	IntroText.Text         = UI_TEXT.Intro
	IntroText.ZIndex       = 502

	local IntroLine        = Instance.new("Frame", IntroFrame)
	IntroLine.AnchorPoint  = Vector2.new(0.5, 0.5)
	IntroLine.Position     = UDim2.new(0.5, 0, 0.5, 16)
	IntroLine.Size         = UDim2.new(0, 0, 0, 2)
	IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
	IntroLine.BorderSizePixel = 0
	IntroLine.BackgroundTransparency = 1
	IntroLine.ZIndex       = 503
	Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

	TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
	TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play()
	task.wait(0.1)
	TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
	task.wait(0.2)
	TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play()
	task.wait(1.6)
	TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
	TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
	task.wait(0.3)
	TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
	task.wait(0.3)

	RegistrarTransparencias(mainWrapper)
	for _, item in ipairs(mainWrapper:GetDescendants()) do RegistrarTransparencias(item) end

	local introNormalSize = select(1, GetResponsiveUISizes())
	mainWrapper.Size    = introNormalSize
	mainWrapper.Visible = true
	FloatBtn.Visible    = true
	UIState             = "OPEN"
	isTransitioning     = false

	local oldMainScale = mainWrapper:FindFirstChild("IntroMainScale")
	if oldMainScale then oldMainScale:Destroy() end
	local MainScale    = Instance.new("UIScale", mainWrapper)
	MainScale.Name     = "IntroMainScale"
	MainScale.Scale    = 0.85
	AplicarFadeSincronizado(mainWrapper, true, 0)
	AplicarFadeSincronizado(mainWrapper, false, 0.35)

	local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
	openScale:Play()

	FloatBtn.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(FloatBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()

	CriarNotificacao(
		"AKATSUKI SCRIPTS",
		"Blox Fruits Script iniciado com sucesso. Bem-vindo, " .. player.DisplayName .. "."
	)

	openScale.Completed:Connect(function()
		MainScale:Destroy()
		pcall(function() Blur:Destroy() end)
		IntroFrame:Destroy()
		task.defer(function()
			selectTab("Farm")
		end)
	end)
end

ExecutarIntroAkat()
