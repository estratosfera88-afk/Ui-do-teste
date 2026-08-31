-- [[ AKATSUKI UI [v2.0 - BLOX FRUITS EDITION] - FIXED & UNIFIED ]]
-- Correções: callbacks race condition, toggles duplicados, canvas size,
-- dropdowns cortados, sliders, hover effects, active bar, search, drag.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local ContentProvider   = game:GetService("ContentProvider")

local player = Players.LocalPlayer

-- Encerra instância anterior com segurança
if _G.AkatUIShutdown then
	pcall(_G.AkatUIShutdown)
end
_G.AkatUIShutdown = nil

-- ==================== ESTADO DOS TOGGLES ====================
local Configs = {
	AutoFarmLevel     = false,
	AutoFarmBoss      = false,
	AutoCollectDrops  = false,
	AutoSkills        = false,
	AutoFarmMastery   = false,
	SmartTargeting    = true,
	AutoFarmMaterials = false,
	AutoFarmChests    = false,
	MobAura           = false,
	AuraRange         = 30,
	AutoQuest         = false,
	Speed             = false,
	SpeedValue        = 16,
	JumpPower         = false,
	JumpPowerValue    = 50,
}
_G.AkatConfigs = Configs

-- ==================== LISTAS ====================
local BOSS_LIST       = { "Gorilla King","Saber Expert","Vice Admiral","Warden","Chief Warden","Swan","Yeti","Mob Leader","Greybeard","Wysper","Thunder God" }
local MASTERY_TYPES   = { "Fruit","Gun","Sword" }
local MATERIAL_TYPES  = { "Bones","Materials","All" }

local DropdownState = {
	SelectedBoss   = BOSS_LIST[1],
	MasteryType    = "Fruit",
	MaterialTarget = "Bones",
}

-- ==================== TEXTOS DA UI ====================
local UI_TEXT = {
	SearchPlaceholder = "Pesquisar...",
	ConfirmCloseTitle = "Deseja fechar o script?",
	ConfirmBtn        = "Sim",
	CancelBtn         = "Não",
	Intro             = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKATSUKI</font>',
	Tabs = {
		Main    = "Main",
		Boss    = "Boss",
		Mastery = "Mastery",
		Farm    = "Farm Settings",
		Player  = "Player",
	},
	Options = {
		AutoFarmLevel    = { Title = "Auto Farm Level",    Desc = "Farm automático de nível. Detecta a ilha/quest correta e eleva seu nível automaticamente." },
		AutoFarmBoss     = { Title = "Auto Farm Boss",     Desc = "Ativa o farm de boss. Selecione o boss na aba Boss." },
		AutoFarmMastery  = { Title = "Auto Farm Mastery",  Desc = "Farm automático de mastery pelo tipo selecionado (Fruit/Gun/Sword)." },
		AutoFarmMaterials= { Title = "Auto Farm Materials",Desc = "Farm automático de Bones, Materials e drops de NPCs." },
		AutoFarmChests   = { Title = "Auto Farm Chests",   Desc = "Percorre ilhas coletando baús automaticamente." },
		AutoCollectDrops = { Title = "Auto Collect Drops", Desc = "Coleta drops automaticamente após derrotar o boss." },
		SmartTargeting   = { Title = "Smart Targeting",    Desc = "Seleciona mobs com HP suficiente para maximizar ganho de mastery." },
		MobAura          = { Title = "Mob Aura",           Desc = "Aura que ataca automaticamente NPCs dentro do alcance configurado." },
		AutoQuest        = { Title = "Auto Quest",         Desc = "Aceita, completa e entrega quests automaticamente conforme seu nível." },
		AutoSkills       = { Title = "Auto Skills",        Desc = "Usa habilidades automaticamente durante o farm." },
		Speed            = { Title = "Speed",              Desc = "Aumenta a velocidade de movimento do personagem." },
		JumpPower        = { Title = "Jump Power",         Desc = "Aumenta a altura do pulo do personagem." },
		SelectedBoss     = { Title = "Boss Alvo" },
		MasteryType      = { Title = "Tipo de Mastery" },
		MaterialTarget   = { Title = "Material Alvo" },
		AuraRange        = { Title = "Aura Range" },
	}
}

-- ==================== ESTADO GLOBAL ====================
local UIState         = "CLOSED"
local activeTab       = "Main"
local tabButtons      = {}
local isExpanded      = false
local originalTrans   = {}
local isConfirmOpen   = false
local isTransitioning = false
local statusLabel     = nil
local mainWrapper     = nil
local openDropdown    = nil

local NORMAL_SIZE   = Vector2.new(580, 400)
local EXPANDED_SIZE = Vector2.new(920, 420)
local UI_MARGIN     = 14

-- ==================== HELPERS DE VIEWPORT ====================
local function GetViewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function GetResponsiveSizes()
	local vp   = GetViewport()
	local maxW = math.max(1, vp.X - UI_MARGIN * 2)
	local maxH = math.max(1, vp.Y - UI_MARGIN * 2)
	return UDim2.fromOffset(math.min(NORMAL_SIZE.X,   maxW), math.min(NORMAL_SIZE.Y,   maxH)),
	       UDim2.fromOffset(math.min(EXPANDED_SIZE.X, maxW), math.min(EXPANDED_SIZE.Y, maxH))
end

local function ClampWrapper()
	if not mainWrapper or not mainWrapper.Parent then return end
	local vp   = GetViewport()
	local size = mainWrapper.AbsoluteSize
	local pos  = mainWrapper.AbsolutePosition + size * 0.5
	local hw   = math.min(size.X / 2, vp.X / 2 - UI_MARGIN)
	local hh   = math.min(size.Y / 2, vp.Y / 2 - UI_MARGIN)
	local x    = math.clamp(pos.X, hw + UI_MARGIN, vp.X - hw - UI_MARGIN)
	local y    = math.clamp(pos.Y, hh + UI_MARGIN, vp.Y - hh - UI_MARGIN)
	mainWrapper.Position = UDim2.fromOffset(x, y)
end

-- ==================== STATUS LABEL ====================
local function UpdateStatus()
	if not statusLabel or not statusLabel.Parent then return end
	pcall(function()
		statusLabel.Text = "● " .. (tostring(_G.BFFarmStatus or "Idle"))
	end)
end

-- ==================== SCREENGUI ====================
local screenGui          = Instance.new("ScreenGui")
screenGui.Name           = "AkatBFUI_v2"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then
	uiParent = gethui()
else
	pcall(function() uiParent = game:GetService("CoreGui") end)
end

-- Remove instância antiga
local old = uiParent:FindFirstChild("AkatBFUI_v2")
if old then pcall(function() old:Destroy() end) end
-- Remove também a v1 se existir
local oldV1 = uiParent:FindFirstChild("DeltaAkatBFUI")
if oldV1 then pcall(function() oldV1:Destroy() end) end

-- Remove blur legado
for _, bf in ipairs(Lighting:GetChildren()) do
	if bf:IsA("BlurEffect") and (bf.Name == "ConfirmBlur" or bf.Name == "IntroBlur") then
		pcall(function() bf:Destroy() end)
	end
end

screenGui.Parent = uiParent

-- Sons
local ClickSound       = Instance.new("Sound", screenGui)
ClickSound.SoundId     = "rbxassetid://6895079853"
ClickSound.Volume      = 0.5

local function PlayClick()
	pcall(function() ClickSound.TimePosition = 0 ClickSound:Play() end)
end

-- ==================== SISTEMA DE FADE ====================
local function RegTrans(obj)
	if originalTrans[obj] then return end
	if obj:IsA("Frame") or obj:IsA("ScrollingFrame") or obj:IsA("CanvasGroup") then
		originalTrans[obj] = { BackgroundTransparency = obj.BackgroundTransparency }
	elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		originalTrans[obj] = { TextTransparency = obj.TextTransparency, BackgroundTransparency = obj.BackgroundTransparency }
	elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		originalTrans[obj] = { ImageTransparency = obj.ImageTransparency, BackgroundTransparency = obj.BackgroundTransparency }
	elseif obj:IsA("UIStroke") then
		originalTrans[obj] = { Transparency = obj.Transparency }
	end
end

local function ApplyFade(root, fadeOut, dur)
	if not root or not root.Parent then return end
	local info = TweenInfo.new(dur, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local function proc(obj)
		if not obj or not obj.Parent then return end
		RegTrans(obj)
		local orig = originalTrans[obj]
		if not orig then return end
		local function tw(prop, target)
			if obj[prop] == nil then return end
			if dur == 0 then obj[prop] = target
			else TweenService:Create(obj, info, { [prop] = target }):Play() end
		end
		if orig.BackgroundTransparency ~= nil then tw("BackgroundTransparency", fadeOut and 1 or orig.BackgroundTransparency) end
		if orig.TextTransparency       ~= nil then tw("TextTransparency",       fadeOut and 1 or orig.TextTransparency)       end
		if orig.ImageTransparency      ~= nil then tw("ImageTransparency",      fadeOut and 1 or orig.ImageTransparency)      end
		if orig.Transparency           ~= nil then tw("Transparency",           fadeOut and 1 or orig.Transparency)           end
	end
	proc(root)
	for _, d in ipairs(root:GetDescendants()) do proc(d) end
end

-- ==================== FLOATING BUTTON ====================
local FloatBtn           = Instance.new("ImageButton", screenGui)
FloatBtn.Name            = "FloatBtn"
FloatBtn.AnchorPoint     = Vector2.new(0.5, 0.5)
FloatBtn.Size            = UDim2.new(0, 44, 0, 44)
FloatBtn.Position        = UDim2.new(0.06, 0, 0.2, 0)
FloatBtn.Image           = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3= Color3.fromRGB(15, 0, 0)
FloatBtn.Visible         = false
FloatBtn.ZIndex          = 100
FloatBtn.AutoButtonColor = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatSound         = Instance.new("Sound", FloatBtn)
FloatSound.SoundId       = "rbxassetid://6310837681"
FloatSound.Volume        = 0.2

task.spawn(function()
	pcall(function() ContentProvider:PreloadAsync({ ClickSound, FloatSound }) end)
end)

-- ==================== MAIN WRAPPER ====================
mainWrapper              = Instance.new("Frame", screenGui)
mainWrapper.Name         = "MainWrapper"
mainWrapper.AnchorPoint  = Vector2.new(0.5, 0.5)
mainWrapper.Size         = UDim2.fromOffset(NORMAL_SIZE.X, NORMAL_SIZE.Y)
mainWrapper.Position     = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible      = false
mainWrapper.ClipsDescendants = false
mainWrapper.ZIndex       = 1

local mainFrame          = Instance.new("Frame", mainWrapper)
mainFrame.Name           = "MainFrame"
mainFrame.Size           = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex         = 2
mainFrame.ClipsDescendants = false

-- ==================== DRAG — FLOAT BUTTON ====================
local dfToggle, dfInput, dfStart, dfPos, dfDragging = false, nil, nil, nil, false
local SetUIState  -- forward

FloatBtn.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
		dfToggle  = true
		dfInput   = inp
		dfDragging= false
		dfStart   = inp.Position
		dfPos     = FloatBtn.Position
	end
end)

-- ==================== DRAG — MAIN WINDOW ====================
local dwToggle, dwInput, dwStart, dwPos = false, nil, nil, nil

mainFrame.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
		dwToggle = true
		dwInput  = inp
		dwStart  = inp.Position
		dwPos    = mainWrapper.Position
	end
end)

UserInputService.InputChanged:Connect(function(inp)
	-- Float drag
	if dfToggle and inp == dfInput then
		local delta = inp.Position - dfStart
		if delta.Magnitude > 5 then dfDragging = true end
		local vp   = GetViewport()
		local half = 22
		local baseX = vp.X * dfPos.X.Scale + dfPos.X.Offset
		local baseY = vp.Y * dfPos.Y.Scale + dfPos.Y.Offset
		FloatBtn.Position = UDim2.fromOffset(
			math.clamp(baseX + delta.X, half, vp.X - half),
			math.clamp(baseY + delta.Y, half, vp.Y - half)
		)
	end
	-- Window drag
	if dwToggle and inp == dwInput then
		local delta = inp.Position - dwStart
		local vp    = GetViewport()
		local hw    = mainWrapper.Size.X.Offset / 2
		local hh    = mainWrapper.Size.Y.Offset / 2
		local absX  = vp.X * dwPos.X.Scale + dwPos.X.Offset + delta.X
		local absY  = vp.Y * dwPos.Y.Scale + dwPos.Y.Offset + delta.Y
		mainWrapper.Position = UDim2.fromOffset(
			math.clamp(absX, hw, vp.X - hw),
			math.clamp(absY, hh, vp.Y - hh)
		)
	end
end)

UserInputService.InputEnded:Connect(function(inp)
	if inp == dfInput then
		if dfToggle and not dfDragging then
			if UIState == "MINIMIZED" or UIState == "CLOSED" then
				pcall(function() FloatSound.TimePosition = 0 FloatSound:Play() end)
				SetUIState("OPEN")
			elseif UIState == "OPEN" then
				SetUIState("MINIMIZED")
			end
		end
		dfToggle = false dfInput = nil
	end
	if inp == dwInput then
		dwToggle = false dwInput = nil
	end
end)

-- ==================== ESTRUTURA VISUAL ====================
local Shadow              = Instance.new("ImageLabel", mainFrame)
Shadow.AnchorPoint        = Vector2.new(0, 0)
Shadow.Position           = UDim2.new(0, -12, 0, -12)
Shadow.Size               = UDim2.new(1, 24, 1, 24)
Shadow.BackgroundTransparency = 1
Shadow.Image              = "rbxassetid://5554831957"
Shadow.ImageColor3        = Color3.fromRGB(5, 0, 1)
Shadow.ImageTransparency  = 0.40
Shadow.ScaleType          = Enum.ScaleType.Slice
Shadow.SliceCenter        = Rect.new(36, 36, 114, 114)
Shadow.ZIndex             = 3

local MainBg              = Instance.new("Frame", mainFrame)
MainBg.Name               = "MainBg"
MainBg.Size               = UDim2.new(1, 0, 1, 0)
MainBg.BackgroundColor3   = Color3.fromRGB(15, 0, 3)
MainBg.BorderSizePixel    = 0
MainBg.ClipsDescendants   = true
MainBg.ZIndex             = 4
Instance.new("UICorner", MainBg).CornerRadius = UDim.new(0, 10)

local MainStroke          = Instance.new("UIStroke", MainBg)
MainStroke.Thickness      = 2
MainStroke.ApplyStrokeMode= Enum.ApplyStrokeMode.Border

local MainStrokeGrad      = Instance.new("UIGradient", MainStroke)
MainStrokeGrad.Rotation   = 45
MainStrokeGrad.Color      = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 0, 5)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 30))
})

local RedOverlay          = Instance.new("Frame", MainBg)
RedOverlay.Size           = UDim2.new(1, 0, 1, 0)
RedOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RedOverlay.BorderSizePixel = 0
RedOverlay.ZIndex         = 4
Instance.new("UICorner", RedOverlay).CornerRadius = UDim.new(0, 10)

local RedGrad             = Instance.new("UIGradient", RedOverlay)
RedGrad.Rotation          = 90
RedGrad.Color             = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(40, 0, 5)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 15, 22)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(40, 0, 5))
})

local LeftPanel           = Instance.new("Frame", MainBg)
LeftPanel.Name            = "LeftPanel"
LeftPanel.Size            = UDim2.new(0, 220, 1, 0)
LeftPanel.BackgroundTransparency = 1
LeftPanel.ZIndex          = 5

local RightPanel          = Instance.new("Frame", MainBg)
RightPanel.Name           = "RightPanel"
RightPanel.Size           = UDim2.new(1, -220, 1, 0)
RightPanel.Position       = UDim2.new(0, 220, 0, 0)
RightPanel.BackgroundTransparency = 1
RightPanel.ZIndex         = 5

-- ==================== HEADER ESQUERDO ====================
local HeaderLeft          = Instance.new("Frame", LeftPanel)
HeaderLeft.Size           = UDim2.new(1, 0, 0, 36)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex         = 20

local HeaderImage         = Instance.new("ImageLabel", HeaderLeft)
HeaderImage.Size          = UDim2.new(0, 24, 0, 24)
HeaderImage.Position      = UDim2.new(0, 10, 0.5, -12)
HeaderImage.BackgroundTransparency = 1
HeaderImage.Image         = "rbxthumb://type=Asset&id=134217291845443&w=150&h=150"
HeaderImage.ZIndex        = 21

local TitleLabel          = Instance.new("TextLabel", HeaderLeft)
TitleLabel.Size           = UDim2.new(1, -44, 0, 16)
TitleLabel.Position       = UDim2.new(0, 40, 0, 4)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text           = "AKATSUKI SCRIPTS HUB"
TitleLabel.TextColor3     = Color3.fromRGB(245, 245, 245)
TitleLabel.TextSize       = 13
TitleLabel.Font           = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex         = 21

local SubLabel            = Instance.new("TextLabel", HeaderLeft)
SubLabel.Size             = UDim2.new(1, -44, 0, 12)
SubLabel.Position         = UDim2.new(0, 40, 0, 20)
SubLabel.BackgroundTransparency = 1
SubLabel.Text             = "BLOX FRUITS | by zeni"
SubLabel.TextColor3       = Color3.fromRGB(180, 180, 180)
SubLabel.TextTransparency = 0.2
SubLabel.TextSize         = 9.5
SubLabel.Font             = Enum.Font.Gotham
SubLabel.TextXAlignment   = Enum.TextXAlignment.Left
SubLabel.ZIndex           = 21

-- ==================== BARRA DE PESQUISA ====================
local SearchContainer     = Instance.new("Frame", LeftPanel)
SearchContainer.Name      = "SearchContainer"
SearchContainer.Size      = UDim2.new(1, -16, 0, 34)
SearchContainer.Position  = UDim2.new(0, 8, 0, 42)
SearchContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
SearchContainer.BackgroundTransparency = 0.82
SearchContainer.ZIndex    = 20
Instance.new("UICorner", SearchContainer).CornerRadius = UDim.new(0, 8)
local sStroke             = Instance.new("UIStroke", SearchContainer)
sStroke.Color             = Color3.fromRGB(60, 20, 20)
sStroke.Transparency      = 0.6

local SearchBox           = Instance.new("TextBox", SearchContainer)
SearchBox.Size            = UDim2.new(1, -36, 1, 0)
SearchBox.Position        = UDim2.new(0, 32, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.PlaceholderText = UI_TEXT.SearchPlaceholder
SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
SearchBox.Text            = ""
SearchBox.TextColor3      = Color3.fromRGB(230, 230, 230)
SearchBox.Font            = Enum.Font.GothamMedium
SearchBox.TextSize        = 13
SearchBox.TextXAlignment  = Enum.TextXAlignment.Left
SearchBox.ZIndex          = 22
SearchBox.ClearTextOnFocus= false

-- Ícone de pesquisa simplificado
local SIcon               = Instance.new("TextLabel", SearchContainer)
SIcon.Size                = UDim2.new(0, 28, 1, 0)
SIcon.BackgroundTransparency = 1
SIcon.Text                = "🔍"
SIcon.TextSize            = 13
SIcon.ZIndex              = 22

-- ==================== TABS CONTAINER ====================
local TabsContainer       = Instance.new("ScrollingFrame", LeftPanel)
TabsContainer.Name        = "TabsContainer"
TabsContainer.Size        = UDim2.new(1, -8, 1, -148)
TabsContainer.Position    = UDim2.new(0, 4, 0, 84)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex      = 10
TabsContainer.CanvasSize  = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 2
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(200, 50, 50)
TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local TabsLayout          = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder      = Enum.SortOrder.LayoutOrder
TabsLayout.Padding        = UDim.new(0, 2)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
	TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(
		TabsLayout.AbsoluteContentSize.Y + 8,
		TabsContainer.AbsoluteSize.Y + 12
	))
end
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

-- ==================== ACTIVE BAR ====================
local ActiveBarContainer  = Instance.new("Frame", LeftPanel)
ActiveBarContainer.Name   = "ActiveBarContainer"
ActiveBarContainer.Size   = UDim2.new(1, -8, 1, -148)
ActiveBarContainer.Position = UDim2.new(0, 4, 0, 84)
ActiveBarContainer.BackgroundTransparency = 1
ActiveBarContainer.ClipsDescendants = true
ActiveBarContainer.ZIndex = 8

local ActiveBar           = Instance.new("Frame", ActiveBarContainer)
ActiveBar.Name            = "ActiveBar"
ActiveBar.AnchorPoint     = Vector2.new(0, 0.5)
ActiveBar.Size            = UDim2.new(0, 3, 0, 20)
ActiveBar.Position        = UDim2.new(0, 6, 0, 0)
ActiveBar.BackgroundColor3= Color3.fromRGB(255, 255, 255)
ActiveBar.BorderSizePixel = 0
ActiveBar.Visible         = false
ActiveBar.ZIndex          = 8
Instance.new("UICorner", ActiveBar).CornerRadius = UDim.new(1, 0)

local BarScale            = Instance.new("UIScale", ActiveBar)
BarScale.Scale            = 1

local BarGrad             = Instance.new("UIGradient", ActiveBar)
BarGrad.Rotation          = 90
BarGrad.Color             = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(120, 0, 10)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(120, 0, 10))
})

-- ==================== USER PROFILE ====================
local UserFrame           = Instance.new("Frame", LeftPanel)
UserFrame.Size            = UDim2.new(1, -16, 0, 54)
UserFrame.Position        = UDim2.new(0, 8, 1, -62)
UserFrame.BackgroundColor3= Color3.fromRGB(20, 12, 12)
UserFrame.BackgroundTransparency = 0.35
UserFrame.BorderSizePixel = 0
UserFrame.ZIndex          = 20
Instance.new("UICorner", UserFrame).CornerRadius = UDim.new(0, 8)

local uStroke             = Instance.new("UIStroke", UserFrame)
uStroke.Thickness         = 0.9
local uGrad               = Instance.new("UIGradient", uStroke)
uGrad.Color               = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0))
})

local AvatarImg           = Instance.new("ImageLabel", UserFrame)
AvatarImg.Size            = UDim2.new(0, 34, 0, 34)
AvatarImg.Position        = UDim2.new(0, 10, 0.5, -17)
AvatarImg.BackgroundTransparency = 1
AvatarImg.Image           = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImg.ZIndex          = 21
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

local AvStroke            = Instance.new("UIStroke", AvatarImg)
AvStroke.Thickness        = 0.9
local avGrad              = Instance.new("UIGradient", AvStroke)
avGrad.Color              = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0))
})

local StatusDot           = Instance.new("Frame", AvatarImg)
StatusDot.Size            = UDim2.new(0, 9, 0, 9)
StatusDot.Position        = UDim2.new(1, -7, 1, -7)
StatusDot.BackgroundColor3= Color3.fromRGB(40, 220, 80)
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex          = 22
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local DispName            = Instance.new("TextLabel", UserFrame)
DispName.Size             = UDim2.new(1, -82, 0, 16)
DispName.Position         = UDim2.new(0, 54, 0.5, -16)
DispName.BackgroundTransparency = 1
DispName.Text             = player.DisplayName
DispName.TextColor3       = Color3.fromRGB(240, 240, 240)
DispName.Font             = Enum.Font.GothamBold
DispName.TextSize         = 13
DispName.TextXAlignment   = Enum.TextXAlignment.Left
DispName.TextTruncate     = Enum.TextTruncate.AtEnd
DispName.ZIndex           = 21

local UserName            = Instance.new("TextLabel", UserFrame)
UserName.Size             = UDim2.new(1, -82, 0, 14)
UserName.Position         = UDim2.new(0, 54, 0.5, 2)
UserName.BackgroundTransparency = 1
UserName.Text             = "@" .. player.Name
UserName.TextColor3       = Color3.fromRGB(110, 110, 110)
UserName.Font             = Enum.Font.Gotham
UserName.TextSize         = 11
UserName.TextXAlignment   = Enum.TextXAlignment.Left
UserName.TextTruncate     = Enum.TextTruncate.AtEnd
UserName.ZIndex           = 21

-- Botão de privacidade
local PrivBtn             = Instance.new("ImageButton", UserFrame)
PrivBtn.Size              = UDim2.new(0, 20, 0, 20)
PrivBtn.Position          = UDim2.new(1, -26, 0.5, -10)
PrivBtn.BackgroundColor3  = Color3.fromRGB(15, 15, 15)
PrivBtn.BackgroundTransparency = 0.2
PrivBtn.BorderSizePixel   = 0
PrivBtn.ZIndex            = 22
PrivBtn.AutoButtonColor   = false
PrivBtn.Image             = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
Instance.new("UICorner", PrivBtn).CornerRadius = UDim.new(0, 5)

local isPrivate = false
PrivBtn.MouseButton1Click:Connect(function()
	PlayClick()
	isPrivate = not isPrivate
	if isPrivate then
		PrivBtn.Image  = "rbxthumb://type=Asset&id=85795266774996&w=150&h=150"
		DispName.Text  = string.rep("*", math.clamp(#player.DisplayName, 3, 8))
		UserName.Text  = "@" .. string.rep("*", math.clamp(#player.Name, 3, 8))
	else
		PrivBtn.Image  = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
		DispName.Text  = player.DisplayName
		UserName.Text  = "@" .. player.Name
	end
end)

-- ==================== RIGHT PANEL — TOPO ====================
local TopBar              = Instance.new("Frame", RightPanel)
TopBar.Size               = UDim2.new(1, -12, 0, 36)
TopBar.BackgroundTransparency = 1
TopBar.ZIndex             = 20

local CtrlFrame           = Instance.new("Frame", TopBar)
CtrlFrame.Size            = UDim2.new(0, 100, 1, 0)
CtrlFrame.Position        = UDim2.new(1, -100, 0, 0)
CtrlFrame.BackgroundTransparency = 1
CtrlFrame.ZIndex          = 25

local CtrlLayout          = Instance.new("UIListLayout", CtrlFrame)
CtrlLayout.FillDirection  = Enum.FillDirection.Horizontal
CtrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
CtrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
CtrlLayout.Padding        = UDim.new(0, 2)

local TOP_ICON_COLOR      = Color3.fromRGB(150, 150, 150)

local function MakeTopBtn(name, img, order)
	local btn              = Instance.new("ImageButton", CtrlFrame)
	btn.Name               = name
	btn.LayoutOrder        = order
	btn.Size               = UDim2.new(0, 28, 0, 28)
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor    = false
	btn.ZIndex             = 25
	local icon             = Instance.new("ImageLabel", btn)
	icon.Name              = "Icon"
	icon.AnchorPoint       = Vector2.new(0.5, 0.5)
	icon.Position          = UDim2.new(0.5, 0, 0.5, 0)
	icon.Size              = UDim2.new(0, 14, 0, 14)
	icon.BackgroundTransparency = 1
	icon.Image             = img
	icon.ImageColor3       = TOP_ICON_COLOR
	icon.ZIndex            = 26
	return btn, icon
end

local MinBtn,  MinIcon  = MakeTopBtn("MinBtn",   "rbxthumb://type=Asset&id=97090905107587&w=150&h=150", 1)
local ExpBtn,  ExpIcon  = MakeTopBtn("ExpBtn",   "rbxthumb://type=Asset&id=78749046909931&w=150&h=150", 2)
local CloseBtn,CloseIcon= MakeTopBtn("CloseBtn", "rbxthumb://type=Asset&id=70710316269357&w=150&h=150", 3)

-- Badge
local BadgeFrame          = Instance.new("Frame", RightPanel)
BadgeFrame.Size           = UDim2.new(0, 52, 0, 18)
BadgeFrame.Position       = UDim2.new(0, 12, 0, 9)
BadgeFrame.BorderSizePixel= 0
BadgeFrame.ZIndex         = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(0, 8)

local badgeGrad           = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation        = 45
badgeGrad.Color           = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})

local BadgeText           = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size            = UDim2.new(1, 0, 1, 0)
BadgeText.BackgroundTransparency = 1
BadgeText.Text            = "BF V2.0"
BadgeText.TextColor3      = Color3.fromRGB(255, 255, 255)
BadgeText.Font            = Enum.Font.GothamBold
BadgeText.TextSize        = 8.5
BadgeText.ZIndex          = 16

-- ==================== STATUS BAR ====================
local StatusBar           = Instance.new("Frame", RightPanel)
StatusBar.Name            = "StatusBar"
StatusBar.Size            = UDim2.new(1, -12, 0, 22)
StatusBar.Position        = UDim2.new(0, 6, 0, 36)
StatusBar.BackgroundColor3= Color3.fromRGB(20, 8, 8)
StatusBar.BackgroundTransparency = 0.5
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex          = 15
Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 6)

statusLabel               = Instance.new("TextLabel", StatusBar)
statusLabel.Size          = UDim2.new(1, -10, 1, 0)
statusLabel.Position      = UDim2.new(0, 8, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text          = "● Idle"
statusLabel.TextColor3    = Color3.fromRGB(180, 220, 180)
statusLabel.Font          = Enum.Font.GothamMedium
statusLabel.TextSize      = 11
statusLabel.TextXAlignment= Enum.TextXAlignment.Left
statusLabel.TextYAlignment= Enum.TextYAlignment.Center
statusLabel.ZIndex        = 16

-- ==================== TOGGLES CONTAINER ====================
local TogglesScroll       = Instance.new("ScrollingFrame", RightPanel)
TogglesScroll.Name        = "TogglesScroll"
TogglesScroll.Size        = UDim2.new(1, -12, 1, -64)
TogglesScroll.Position    = UDim2.new(0, 6, 0, 62)
TogglesScroll.BackgroundColor3 = Color3.fromRGB(30, 12, 14)
TogglesScroll.BackgroundTransparency = 0.7
TogglesScroll.BorderSizePixel = 0
TogglesScroll.ClipsDescendants = true
TogglesScroll.ZIndex      = 10
TogglesScroll.ScrollBarThickness = 2
TogglesScroll.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
TogglesScroll.ScrollBarImageTransparency = 0.35
TogglesScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
TogglesScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
Instance.new("UICorner", TogglesScroll).CornerRadius = UDim.new(0, 8)

local ContainerLayout     = Instance.new("UIListLayout", TogglesScroll)
ContainerLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContainerLayout.Padding   = UDim.new(0, 5)
ContainerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local ContainerPad        = Instance.new("UIPadding", TogglesScroll)
ContainerPad.PaddingTop   = UDim.new(0, 8)
ContainerPad.PaddingBottom= UDim.new(0, 8)
ContainerPad.PaddingLeft  = UDim.new(0, 4)
ContainerPad.PaddingRight = UDim.new(0, 6)

local function UpdateCanvas()
	local contentH = ContainerLayout.AbsoluteContentSize.Y + 24
	TogglesScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH, TogglesScroll.AbsoluteSize.Y + 1))
end
ContainerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
TogglesScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvas)

-- ==================== CONFIRM DIALOG ====================
local confirmBlur         = Instance.new("BlurEffect", Lighting)
confirmBlur.Name          = "ConfirmBlur"
confirmBlur.Size          = 0

local ConfirmOverlay      = Instance.new("Frame", screenGui)
ConfirmOverlay.Size       = UDim2.new(1, 0, 1, 0)
ConfirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ConfirmOverlay.BackgroundTransparency = 0.55
ConfirmOverlay.Visible    = false
ConfirmOverlay.ZIndex     = 990

local ConfirmCard         = Instance.new("Frame", ConfirmOverlay)
ConfirmCard.Size          = UDim2.new(0, 300, 0, 130)
ConfirmCard.AnchorPoint   = Vector2.new(0.5, 0.5)
ConfirmCard.Position      = UDim2.new(0.5, 0, 0.5, 0)
ConfirmCard.BackgroundColor3 = Color3.fromRGB(18, 8, 8)
ConfirmCard.BorderSizePixel  = 0
ConfirmCard.ZIndex        = 995
Instance.new("UICorner", ConfirmCard).CornerRadius = UDim.new(0, 14)

local ConfirmStroke       = Instance.new("UIStroke", ConfirmCard)
ConfirmStroke.Thickness   = 1.5
local ConfStrokeGrad      = Instance.new("UIGradient", ConfirmStroke)
ConfStrokeGrad.Color      = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 10)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 0, 10))
})

Instance.new("UIGradient", ConfirmCard).Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 10, 10)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 4, 4))
})

local ConfirmLabel        = Instance.new("TextLabel", ConfirmCard)
ConfirmLabel.Size         = UDim2.new(1, -24, 0, 22)
ConfirmLabel.Position     = UDim2.new(0, 12, 0, 18)
ConfirmLabel.BackgroundTransparency = 1
ConfirmLabel.TextColor3   = Color3.fromRGB(235, 235, 235)
ConfirmLabel.Font         = Enum.Font.GothamBold
ConfirmLabel.TextSize     = 13
ConfirmLabel.TextXAlignment = Enum.TextXAlignment.Center
ConfirmLabel.Text         = UI_TEXT.ConfirmCloseTitle
ConfirmLabel.ZIndex       = 1000

local Sep                 = Instance.new("Frame", ConfirmCard)
Sep.Size                  = UDim2.new(1, -40, 0, 1)
Sep.Position              = UDim2.new(0, 20, 0, 48)
Sep.BackgroundColor3      = Color3.fromRGB(120, 20, 20)
Sep.BackgroundTransparency= 0.6
Sep.BorderSizePixel       = 0
Sep.ZIndex                = 999
Instance.new("UICorner", Sep).CornerRadius = UDim.new(1, 0)

local function MakeConfirmBtn(text, bgColor, xOff)
	local btn              = Instance.new("TextButton", ConfirmCard)
	btn.Size               = UDim2.new(0, 118, 0, 32)
	btn.Position           = UDim2.new(0.5, xOff, 0, 62)
	btn.BackgroundColor3   = bgColor
	btn.TextColor3         = Color3.fromRGB(255, 255, 255)
	btn.Font               = Enum.Font.GothamMedium
	btn.TextSize           = 14
	btn.Text               = text
	btn.ZIndex             = 1000
	btn.BorderSizePixel    = 0
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)
	return btn
end

local BtnYes = MakeConfirmBtn(UI_TEXT.ConfirmBtn, Color3.fromRGB(139, 0, 0), -124)
local BtnNo  = MakeConfirmBtn(UI_TEXT.CancelBtn,  Color3.fromRGB(30, 30, 30),  6)
do
	local g = Instance.new("UIGradient", BtnYes)
	g.Rotation = 90
	g.Color    = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 20, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 0, 0))
	})
end

BtnYes.MouseEnter:Connect(function() TweenService:Create(BtnYes, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(180, 20, 20)}):Play() end)
BtnYes.MouseLeave:Connect(function() TweenService:Create(BtnYes, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(139, 0, 0)}):Play() end)
BtnNo.MouseEnter:Connect( function() TweenService:Create(BtnNo,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}):Play() end)
BtnNo.MouseLeave:Connect( function() TweenService:Create(BtnNo,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play() end)

ApplyFade(ConfirmCard, true, 0)

-- ==================== RENDERLOOP ====================
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	RedGrad.Rotation        = 90  + math.sin(t * 0.55) * 28
	ConfStrokeGrad.Rotation = 90  + math.sin(t * 0.70) * 25
	uGrad.Rotation          = 45  + math.sin(t * 0.80) * 35
	avGrad.Rotation         = 45  + math.sin(t * 0.80) * 35
	badgeGrad.Rotation      = 45  + math.sin(t * 0.45) * 20
	UpdateStatus()
end)

-- ==================== NOTIFICAÇÕES ====================
local ActiveNotifs = {}
local NOTIF_DUR   = 9

local function ReposNotifs()
	local y = -24
	for _, n in ipairs(ActiveNotifs) do
		if n and n.Parent then
			local h = n.Size.Y.Offset
			TweenService:Create(n, TweenInfo.new(0.28, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1, -20, 1, y) }):Play()
			y = y - (h + 10)
		end
	end
end

local function Notif(title, desc, accentColor)
	accentColor = accentColor or Color3.fromRGB(180, 20, 20)
	local holder  = Instance.new("Frame", screenGui)
	holder.AnchorPoint  = Vector2.new(1, 1)
	holder.Size         = UDim2.new(0, 320, 0, 88)
	holder.Position     = UDim2.new(1, 350, 1, -24)
	holder.BackgroundTransparency = 1
	holder.ZIndex       = 200

	local card      = Instance.new("Frame", holder)
	card.Size       = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel= 0
	card.ZIndex     = 201
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

	local accent    = Instance.new("Frame", card)
	accent.Size     = UDim2.new(0, 4, 0, 46)
	accent.Position = UDim2.new(0, 12, 0.5, -23)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel  = 0
	accent.ZIndex   = 202
	Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

	local lTitle    = Instance.new("TextLabel", card)
	lTitle.Size     = UDim2.new(1, -50, 0, 18)
	lTitle.Position = UDim2.new(0, 24, 0.5, -20)
	lTitle.BackgroundTransparency = 1
	lTitle.Text     = title or "AKATSUKI"
	lTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
	lTitle.Font     = Enum.Font.GothamBold
	lTitle.TextSize = 14
	lTitle.TextXAlignment = Enum.TextXAlignment.Left
	lTitle.ZIndex   = 203

	local lDesc     = Instance.new("TextLabel", card)
	lDesc.Size      = UDim2.new(1, -50, 0, 16)
	lDesc.Position  = UDim2.new(0, 24, 0.5, 2)
	lDesc.BackgroundTransparency = 1
	lDesc.Text      = desc or ""
	lDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
	lDesc.Font      = Enum.Font.Gotham
	lDesc.TextSize  = 11
	lDesc.TextXAlignment = Enum.TextXAlignment.Left
	lDesc.TextWrapped = true
	lDesc.ZIndex    = 203

	local closeB    = Instance.new("TextButton", card)
	closeB.Size     = UDim2.new(0, 22, 0, 22)
	closeB.Position = UDim2.new(1, -30, 0, 8)
	closeB.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
	closeB.BackgroundTransparency = 0.2
	closeB.Text     = "✕"
	closeB.TextColor3 = Color3.fromRGB(180, 180, 180)
	closeB.TextSize = 11
	closeB.Font     = Enum.Font.GothamBold
	closeB.ZIndex   = 205
	closeB.BorderSizePixel = 0
	Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 6)

	local progBg    = Instance.new("Frame", card)
	progBg.Size     = UDim2.new(1, -24, 0, 3)
	progBg.Position = UDim2.new(0, 12, 1, -8)
	progBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	progBg.BorderSizePixel  = 0
	progBg.ZIndex   = 202
	progBg.ClipsDescendants = true
	Instance.new("UICorner", progBg).CornerRadius = UDim.new(1, 0)

	local progBar   = Instance.new("Frame", progBg)
	progBar.Size    = UDim2.new(1, 0, 1, 0)
	progBar.BackgroundColor3 = accentColor
	progBar.BorderSizePixel  = 0
	progBar.ZIndex  = 203
	Instance.new("UICorner", progBar).CornerRadius = UDim.new(1, 0)

	table.insert(ActiveNotifs, 1, holder)
	ReposNotifs()

	TweenService:Create(holder, TweenInfo.new(0.28, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -20, 1, -24) }):Play()

	local dismissed = false
	local function Dismiss()
		if dismissed then return end
		dismissed = true
		for i, v in ipairs(ActiveNotifs) do
			if v == holder then table.remove(ActiveNotifs, i) break end
		end
		ReposNotifs()
		TweenService:Create(holder, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 360, 1, holder.Position.Y.Offset) }):Play()
		task.delay(0.25, function()
			if holder and holder.Parent then holder:Destroy() end
		end)
	end

	closeB.MouseButton1Click:Connect(Dismiss)
	task.delay(0.1, function()
		TweenService:Create(progBar, TweenInfo.new(NOTIF_DUR, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 0, 1, 0) }):Play()
	end)
	task.delay(NOTIF_DUR + 0.1, Dismiss)
end

local function NotifDiscord()
	local holder  = Instance.new("Frame", screenGui)
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Size   = UDim2.new(0, 320, 0, 96)
	holder.Position = UDim2.new(1, 360, 1, -24)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 200

	local card    = Instance.new("Frame", holder)
	card.Size     = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.ZIndex   = 201
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

	local accent  = Instance.new("Frame", card)
	accent.Size   = UDim2.new(0, 4, 0, 50)
	accent.Position = UDim2.new(0, 12, 0.5, -25)
	accent.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	accent.BorderSizePixel  = 0
	accent.ZIndex = 202
	Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

	local t1      = Instance.new("TextLabel", card)
	t1.Size       = UDim2.new(1, -50, 0, 18)
	t1.Position   = UDim2.new(0, 24, 0.5, -22)
	t1.BackgroundTransparency = 1
	t1.Text       = "DISCORD SERVER"
	t1.TextColor3 = Color3.fromRGB(240, 240, 240)
	t1.Font       = Enum.Font.GothamBold
	t1.TextSize   = 14
	t1.TextXAlignment = Enum.TextXAlignment.Left
	t1.ZIndex     = 203

	local t2      = Instance.new("TextLabel", card)
	t2.Size       = UDim2.new(1, -105, 0, 16)
	t2.Position   = UDim2.new(0, 24, 0.5, 2)
	t2.BackgroundTransparency = 1
	t2.Text       = "discord.gg/rZuYzZ7zvt"
	t2.TextColor3 = Color3.fromRGB(150, 150, 155)
	t2.Font       = Enum.Font.Gotham
	t2.TextSize   = 11
	t2.ZIndex     = 203

	local copyBtn = Instance.new("TextButton", card)
	copyBtn.Size  = UDim2.new(0, 60, 0, 22)
	copyBtn.AnchorPoint = Vector2.new(1, 0.5)
	copyBtn.Position = UDim2.new(1, -12, 0.75, 0)
	copyBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	copyBtn.Text  = "COPY"
	copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	copyBtn.Font  = Enum.Font.GothamBold
	copyBtn.TextSize = 11
	copyBtn.ZIndex= 205
	copyBtn.BorderSizePixel = 0
	Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

	local closeB  = Instance.new("TextButton", card)
	closeB.Size   = UDim2.new(0, 22, 0, 22)
	closeB.Position = UDim2.new(1, -30, 0, 8)
	closeB.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
	closeB.BackgroundTransparency = 0.2
	closeB.Text   = "✕"
	closeB.TextColor3 = Color3.fromRGB(180, 180, 180)
	closeB.TextSize = 11
	closeB.Font   = Enum.Font.GothamBold
	closeB.ZIndex = 205
	closeB.BorderSizePixel = 0
	Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 6)

	table.insert(ActiveNotifs, 1, holder)
	ReposNotifs()
	TweenService:Create(holder, TweenInfo.new(0.28, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -20, 1, -24) }):Play()

	local dismissed = false
	local function Dismiss()
		if dismissed then return end
		dismissed = true
		for i, v in ipairs(ActiveNotifs) do
			if v == holder then table.remove(ActiveNotifs, i) break end
		end
		ReposNotifs()
		TweenService:Create(holder, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 360, 1, holder.Position.Y.Offset) }):Play()
		task.delay(0.25, function() if holder and holder.Parent then holder:Destroy() end end)
	end

	copyBtn.MouseButton1Click:Connect(function()
		PlayClick()
		pcall(function()
			if setclipboard then setclipboard("https://discord.gg/rZuYzZ7zvt") end
		end)
		Notif("LINK COPIADO", "discord.gg/rZuYzZ7zvt")
	end)
	closeB.MouseButton1Click:Connect(Dismiss)
	task.delay(NOTIF_DUR + 0.1, Dismiss)
end

-- ==================== FILTRO / PESQUISA ====================
local filterThread = nil

local function FilterToggles(tab, query)
	local q = (query or ""):lower()
	local idx = 0
	for _, child in ipairs(TogglesScroll:GetChildren()) do
		if not child:IsA("Frame") or child.Name == "UIPadding" then continue end
		local childTab = child:GetAttribute("Tab") or "Main"
		local show = false
		if q ~= "" then
			local tl = child:FindFirstChild("Title")
			local dl = child:FindFirstChild("Description")
			show = (tl and tl.Text:lower():find(q, 1, true) ~= nil)
			    or (dl and dl.Text:lower():find(q, 1, true) ~= nil)
		else
			show = childTab == tab
		end
		child.Visible = show
		if show then
			idx = idx + 1
			local h = child:GetAttribute("ItemHeight") or 60
			child.Size = UDim2.new(1, -10, 0, 0)
			child.BackgroundTransparency = 1
			local tl = child:FindFirstChild("Title")
			local dl = child:FindFirstChild("Description")
			if tl then tl.TextTransparency = 1 end
			if dl then dl.TextTransparency = 1 end
			task.delay((idx - 1) * 0.018, function()
				if not child or not child.Parent then return end
				TweenService:Create(child, TweenInfo.new(0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
					{ Size = UDim2.new(1, -10, 0, h), BackgroundTransparency = 0.45 }):Play()
				if tl then TweenService:Create(tl, TweenInfo.new(0.14), {TextTransparency = 0}):Play() end
				if dl then TweenService:Create(dl, TweenInfo.new(0.14), {TextTransparency = 0}):Play() end
			end)
		end
	end
	task.delay(0.05, UpdateCanvas)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	if filterThread then task.cancel(filterThread) end
	filterThread = task.delay(0.08, function()
		filterThread = nil
		FilterToggles(activeTab, SearchBox.Text)
	end)
end)

-- ==================== ACTIVE BAR POSITION ====================
local function UpdateBarPos(animate)
	local targetBtn = tabButtons[activeTab]
	if not targetBtn or not ActiveBar.Visible then return end
	local defer = 0
	local function apply()
		defer = defer + 1
		if not targetBtn or not targetBtn.Parent then return end
		local bSize = targetBtn.AbsoluteSize.Y
		local bPos  = targetBtn.AbsolutePosition.Y
		local pPos  = ActiveBarContainer.AbsolutePosition.Y
		if (bSize == 0 or bPos == 0) and defer < 8 then
			task.defer(apply); return
		end
		local y = bPos + bSize / 2 - pPos
		if animate then
			TweenService:Create(ActiveBar,
				TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0, 6, 0, y) }):Play()
			BarScale.Scale = 1.1
			TweenService:Create(BarScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
		else
			ActiveBar.Position = UDim2.new(0, 6, 0, y)
			BarScale.Scale = 1
		end
	end
	task.defer(apply)
end

TabsContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	UpdateBarPos(false)
end)

-- ==================== SELECIONAR ABA ====================
local function SelectTab(name)
	activeTab = name
	for n, btn in pairs(tabButtons) do
		local lbl  = btn:FindFirstChild("Label")
		local icon = btn:FindFirstChild("Icon")
		local ai   = icon and icon:FindFirstChild("AccentImage")
		local info = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		if n == name then
			TweenService:Create(btn,  info, { BackgroundColor3 = Color3.fromRGB(45, 10, 15), BackgroundTransparency = 0.5 }):Play()
			if lbl then TweenService:Create(lbl,  info, { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play() end
			if ai  then TweenService:Create(ai,   info, { ImageColor3 = Color3.fromRGB(255, 255, 255) }):Play() end
		else
			TweenService:Create(btn,  info, { BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 1 }):Play()
			if lbl then TweenService:Create(lbl,  info, { TextColor3 = Color3.fromRGB(150, 150, 150) }):Play() end
			if ai  then TweenService:Create(ai,   info, { ImageColor3 = Color3.fromRGB(150, 150, 150) }):Play() end
		end
	end
	ActiveBar.Visible = true
	UpdateBarPos(true)
	TogglesScroll.CanvasPosition = Vector2.zero
	SearchBox.Text = ""
	FilterToggles(name, "")
end

-- ==================== CRIAR ABA ====================
local TAB_ICONS = {
	Main    = "rbxthumb://type=Asset&id=71234705040146&w=150&h=150",
	Boss    = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150",
	Mastery = "rbxthumb://type=Asset&id=97681798175944&w=150&h=150",
	Farm    = "rbxthumb://type=Asset&id=131082536388353&w=150&h=150",
	Player  = "rbxthumb://type=Asset&id=88409765080516&w=150&h=150",
}

local function CreateTab(name)
	local btn              = Instance.new("TextButton", TabsContainer)
	btn.Name               = name .. "Tab"
	btn.Size               = UDim2.new(1, -16, 0, 36)
	btn.BackgroundColor3   = Color3.fromRGB(15, 15, 15)
	btn.BackgroundTransparency = 1
	btn.Text               = ""
	btn.ZIndex             = 11
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local iconHolder       = Instance.new("Frame", btn)
	iconHolder.Name        = "Icon"
	iconHolder.Size        = UDim2.new(0, 14, 0, 14)
	iconHolder.Position    = UDim2.new(0, 14, 0.5, -7)
	iconHolder.BackgroundTransparency = 1
	iconHolder.ZIndex      = 12

	local ai               = Instance.new("ImageLabel", iconHolder)
	ai.Name                = "AccentImage"
	ai.Size                = UDim2.new(1, 0, 1, 0)
	ai.BackgroundTransparency = 1
	ai.Image               = TAB_ICONS[name] or ""
	ai.ImageColor3         = Color3.fromRGB(150, 150, 150)
	ai.ZIndex              = 13

	local lbl              = Instance.new("TextLabel", btn)
	lbl.Name               = "Label"
	lbl.Size               = UDim2.new(1, -42, 1, 0)
	lbl.Position           = UDim2.new(0, 38, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = Color3.fromRGB(150, 150, 150)
	lbl.Font               = Enum.Font.GothamMedium
	lbl.TextSize           = 13
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Text               = UI_TEXT.Tabs[name] or name
	lbl.ZIndex             = 12

	local sc               = Instance.new("UIScale", btn)
	sc.Scale               = 1

	btn.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(sc, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.97}):Play()
		end
	end)
	btn.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)
	btn.MouseButton1Click:Connect(function() SelectTab(name) end)
	tabButtons[name] = btn
end

-- ==================== HELPER: DISPARAR CALLBACK ====================
-- CORREÇÃO PRINCIPAL: callbacks são chamados de forma segura sem depender
-- de _G.AkatCallbacks estar pronto imediatamente.
local function FireCallback(key, value)
	task.spawn(function()
		-- Espera até 5 segundos pelos callbacks estarem disponíveis
		local deadline = os.clock() + 5
		while (not _G.AkatCallbacks or type(_G.AkatCallbacks[key]) ~= "function") and os.clock() < deadline do
			task.wait(0.1)
		end
		if _G.AkatCallbacks and type(_G.AkatCallbacks[key]) == "function" then
			local ok, err = pcall(_G.AkatCallbacks[key], value)
			if not ok then
				warn("[AKAT UI] Callback error [" .. tostring(key) .. "]: " .. tostring(err))
			end
		else
			warn("[AKAT UI] Callback não encontrado: " .. tostring(key))
		end
	end)
end

-- ==================== CRIAR TOGGLE PADRÃO (60px) ====================
local function CreateToggle(tab, configKey)
	local opt = UI_TEXT.Options[configKey]
	local h   = 60

	local frame                = Instance.new("Frame", TogglesScroll)
	frame.Name                 = configKey .. "_" .. tab
	frame.Size                 = UDim2.new(1, -10, 0, h)
	frame.BackgroundColor3     = Color3.fromRGB(15, 5, 5)
	frame.BackgroundTransparency = 0.45
	frame.ZIndex               = 11
	frame.ClipsDescendants     = true
	frame:SetAttribute("Tab",        tab)
	frame:SetAttribute("ConfigKey",  configKey)
	frame:SetAttribute("ItemHeight", h)
	frame.Parent               = TogglesScroll
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local sc                   = Instance.new("UIScale", frame)
	sc.Scale                   = 1

	local titleLbl             = Instance.new("TextLabel", frame)
	titleLbl.Name              = "Title"
	titleLbl.Size              = UDim2.new(0.7, 0, 0, 18)
	titleLbl.Position          = UDim2.new(0, 12, 0, 9)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3        = Color3.fromRGB(210, 210, 210)
	titleLbl.Font              = Enum.Font.GothamBold
	titleLbl.TextSize          = 13
	titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
	titleLbl.Text              = opt and opt.Title or configKey
	titleLbl.ZIndex            = 12

	local descLbl              = Instance.new("TextLabel", frame)
	descLbl.Name               = "Description"
	descLbl.Size               = UDim2.new(0.7, 0, 0, 28)
	descLbl.Position           = UDim2.new(0, 12, 0, 28)
	descLbl.BackgroundTransparency = 1
	descLbl.TextColor3         = Color3.fromRGB(130, 130, 130)
	descLbl.Font               = Enum.Font.Gotham
	descLbl.TextSize           = 10.5
	descLbl.TextXAlignment     = Enum.TextXAlignment.Left
	descLbl.TextYAlignment     = Enum.TextYAlignment.Top
	descLbl.TextWrapped        = true
	descLbl.Text               = opt and opt.Desc or ""
	descLbl.ZIndex             = 12

	local track                = Instance.new("Frame", frame)
	track.Size                 = UDim2.new(0, 46, 0, 22)
	track.Position             = UDim2.new(1, -52, 0.5, -11)
	track.BackgroundColor3     = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
	track.ZIndex               = 12
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local circle               = Instance.new("Frame", track)
	circle.Size                = UDim2.new(0, 16, 0, 16)
	circle.Position            = Configs[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
	circle.BackgroundColor3    = Color3.fromRGB(255, 255, 255)
	circle.ZIndex              = 13
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

	local hit                  = Instance.new("TextButton", frame)
	hit.Size                   = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Text                   = ""
	hit.ZIndex                 = 14

	hit.MouseButton1Click:Connect(function()
		PlayClick()
		Configs[configKey] = not Configs[configKey]
		local on   = Configs[configKey]
		local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(circle, info, { Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
		TweenService:Create(track,  info, { BackgroundColor3 = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30) }):Play()
		sc.Scale = 0.97
		TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()
		FireCallback(configKey, on)
	end)
end

-- ==================== CRIAR TOGGLE COMPACTO (42px) ====================
local function CreateCompactToggle(tab, configKey)
	local opt = UI_TEXT.Options[configKey]
	local h   = 42

	local frame                = Instance.new("Frame", TogglesScroll)
	frame.Name                 = configKey .. "_" .. tab
	frame.Size                 = UDim2.new(1, -10, 0, h)
	frame.BackgroundColor3     = Color3.fromRGB(15, 5, 5)
	frame.BackgroundTransparency = 0.45
	frame.ZIndex               = 11
	frame.ClipsDescendants     = true
	frame:SetAttribute("Tab",        tab)
	frame:SetAttribute("ConfigKey",  configKey)
	frame:SetAttribute("ItemHeight", h)
	frame.Parent               = TogglesScroll
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local titleLbl             = Instance.new("TextLabel", frame)
	titleLbl.Name              = "Title"
	titleLbl.Size              = UDim2.new(1, -70, 1, 0)
	titleLbl.Position          = UDim2.fromOffset(12, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3        = Color3.fromRGB(210, 210, 210)
	titleLbl.Font              = Enum.Font.GothamBold
	titleLbl.TextSize          = 13
	titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
	titleLbl.TextYAlignment    = Enum.TextYAlignment.Center
	titleLbl.Text              = opt and opt.Title or configKey
	titleLbl.ZIndex            = 12

	local track                = Instance.new("Frame", frame)
	track.Size                 = UDim2.fromOffset(40, 20)
	track.Position             = UDim2.new(1, -48, 0.5, -10)
	track.BackgroundColor3     = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
	track.ZIndex               = 12
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local circle               = Instance.new("Frame", track)
	circle.Size                = UDim2.fromOffset(14, 14)
	circle.Position            = Configs[configKey] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
	circle.BackgroundColor3    = Color3.fromRGB(255, 255, 255)
	circle.ZIndex              = 13
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

	local hit                  = Instance.new("TextButton", frame)
	hit.Size                   = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text                   = ""
	hit.ZIndex                 = 14

	hit.MouseButton1Click:Connect(function()
		PlayClick()
		Configs[configKey] = not Configs[configKey]
		local on   = Configs[configKey]
		local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(circle, info, { Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) }):Play()
		TweenService:Create(track,  info, { BackgroundColor3 = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30) }):Play()
		FireCallback(configKey, on)
	end)
end

-- ==================== CRIAR SLIDER (42px) ====================
local function CreateSlider(tab, configKey, minV, maxV, defV)
	local opt = UI_TEXT.Options[configKey]
	local h   = 42

	local frame                = Instance.new("Frame", TogglesScroll)
	frame.Name                 = configKey .. "_" .. tab
	frame.Size                 = UDim2.new(1, -10, 0, h)
	frame.BackgroundColor3     = Color3.fromRGB(15, 5, 5)
	frame.BackgroundTransparency = 0.45
	frame.ZIndex               = 11
	frame.ClipsDescendants     = true
	frame:SetAttribute("Tab",        tab)
	frame:SetAttribute("ConfigKey",  configKey)
	frame:SetAttribute("ItemHeight", h)
	frame.Parent               = TogglesScroll
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local titleLbl             = Instance.new("TextLabel", frame)
	titleLbl.Name              = "Title"
	titleLbl.Size              = UDim2.new(0, 95, 1, 0)
	titleLbl.Position          = UDim2.fromOffset(12, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3        = Color3.fromRGB(210, 210, 210)
	titleLbl.Font              = Enum.Font.GothamBold
	titleLbl.TextSize          = 12
	titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
	titleLbl.TextYAlignment    = Enum.TextYAlignment.Center
	titleLbl.Text              = opt and opt.Title or configKey
	titleLbl.ZIndex            = 12

	local track                = Instance.new("Frame", frame)
	track.Name                 = "Track"
	track.Size                 = UDim2.new(1, -160, 0, 6)
	track.Position             = UDim2.new(0, 110, 0.5, -3)
	track.BackgroundColor3     = Color3.fromRGB(45, 25, 27)
	track.BorderSizePixel      = 0
	track.ZIndex               = 12
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill                 = Instance.new("Frame", track)
	fill.Size                  = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3      = Color3.fromRGB(139, 0, 0)
	fill.BorderSizePixel       = 0
	fill.ZIndex                = 13
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob                 = Instance.new("Frame", track)
	knob.Size                  = UDim2.fromOffset(14, 14)
	knob.AnchorPoint           = Vector2.new(0.5, 0.5)
	knob.Position              = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel       = 0
	knob.ZIndex                = 14
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local valLbl               = Instance.new("TextLabel", frame)
	valLbl.Name                = "Value"
	valLbl.Size                = UDim2.fromOffset(44, 22)
	valLbl.AnchorPoint         = Vector2.new(1, 0.5)
	valLbl.Position            = UDim2.new(1, -8, 0.5, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.TextColor3          = Color3.fromRGB(255, 255, 255)
	valLbl.Font                = Enum.Font.GothamBold
	valLbl.TextSize            = 15
	valLbl.TextXAlignment      = Enum.TextXAlignment.Right
	valLbl.ZIndex              = 13

	local hit                  = Instance.new("TextButton", frame)
	hit.Size                   = UDim2.new(1, -145, 0, 28)
	hit.Position               = UDim2.new(0, 106, 0.5, -14)
	hit.BackgroundTransparency = 1
	hit.Text                   = ""
	hit.AutoButtonColor        = false
	hit.ZIndex                 = 15

	local curVal = math.clamp(tonumber(defV) or minV, minV, maxV)
	local dragging = false

	local function SetVal(v)
		curVal = math.clamp(v, minV, maxV)
		local alpha = (curVal - minV) / (maxV - minV)
		valLbl.Text    = tostring(math.floor(curVal + 0.5))
		fill.Size      = UDim2.new(alpha, 0, 1, 0)
		knob.Position  = UDim2.new(alpha, 0, 0.5, 0)
		-- CORREÇÃO: salva o valor no configKey correto para o slider
		local intVal = math.floor(curVal + 0.5)
		if configKey == "Speed" or configKey == "JumpPower" then
			Configs[configKey .. "Value"] = intVal
			Configs[configKey] = true
		elseif configKey == "AuraRange" then
			Configs.AuraRange = intVal
		end
	end

	local function UpdateFromInput(inp)
		local left  = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		local alpha = math.clamp((inp.Position.X - left) / width, 0, 1)
		local v     = minV + (maxV - minV) * alpha
		SetVal(math.floor(v + 0.5))
		-- Dispara callback com o valor numérico
		FireCallback(configKey, math.floor(curVal + 0.5))
	end

	SetVal(curVal)

	hit.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			UpdateFromInput(inp)
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			UpdateFromInput(inp)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- ==================== CRIAR DROPDOWN (42px) ====================
-- CORREÇÃO: painel filho do screenGui para não ser cortado pelo ClipsDescendants
local function CreateDropdown(tab, configKey, options, defValue, onChange)
	local opt  = UI_TEXT.Options[configKey]
	local h    = 42
	local cur  = defValue or options[1]
	local isOpen = false
	local items  = {}

	local frame                = Instance.new("Frame", TogglesScroll)
	frame.Name                 = configKey .. "_" .. tab
	frame.Size                 = UDim2.new(1, -10, 0, h)
	frame.BackgroundColor3     = Color3.fromRGB(15, 5, 5)
	frame.BackgroundTransparency = 0.45
	frame.ZIndex               = 11
	frame.ClipsDescendants     = false -- não cortar o dropdown
	frame:SetAttribute("Tab",        tab)
	frame:SetAttribute("ConfigKey",  configKey)
	frame:SetAttribute("ItemHeight", h)
	frame.Parent               = TogglesScroll
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local titleLbl             = Instance.new("TextLabel", frame)
	titleLbl.Name              = "Title"
	titleLbl.Size              = UDim2.new(0.52, 0, 1, 0)
	titleLbl.Position          = UDim2.fromOffset(12, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3        = Color3.fromRGB(210, 210, 210)
	titleLbl.Font              = Enum.Font.GothamBold
	titleLbl.TextSize          = 12
	titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
	titleLbl.TextYAlignment    = Enum.TextYAlignment.Center
	titleLbl.Text              = opt and opt.Title or configKey
	titleLbl.ZIndex            = 12

	local valBtn               = Instance.new("TextButton", frame)
	valBtn.Size                = UDim2.new(0, 130, 0, 26)
	valBtn.AnchorPoint         = Vector2.new(1, 0.5)
	valBtn.Position            = UDim2.new(1, -8, 0.5, 0)
	valBtn.BackgroundColor3    = Color3.fromRGB(30, 10, 10)
	valBtn.TextColor3          = Color3.fromRGB(220, 220, 220)
	valBtn.Font                = Enum.Font.GothamMedium
	valBtn.TextSize            = 12
	valBtn.Text                = cur .. " ▾"
	valBtn.ZIndex              = 30
	valBtn.BorderSizePixel     = 0
	valBtn.AutoButtonColor     = false
	Instance.new("UICorner", valBtn).CornerRadius = UDim.new(0, 6)
	local vStroke              = Instance.new("UIStroke", valBtn)
	vStroke.Color              = Color3.fromRGB(100, 20, 20)
	vStroke.Thickness          = 1
	vStroke.Transparency       = 0.4

	-- Painel flutuante pai = screenGui para não ser cortado
	local dropPanel            = Instance.new("Frame", screenGui)
	dropPanel.Name             = configKey .. "DropPanel"
	dropPanel.BackgroundColor3 = Color3.fromRGB(20, 8, 8)
	dropPanel.BackgroundTransparency = 0.08
	dropPanel.BorderSizePixel  = 0
	dropPanel.ZIndex           = 600
	dropPanel.Visible          = false
	dropPanel.ClipsDescendants = true
	dropPanel.Size             = UDim2.fromOffset(138, 0)
	Instance.new("UICorner", dropPanel).CornerRadius = UDim.new(0, 8)
	local dpStroke             = Instance.new("UIStroke", dropPanel)
	dpStroke.Color             = Color3.fromRGB(120, 20, 20)
	dpStroke.Thickness         = 1
	dpStroke.Transparency      = 0.25

	local dpLayout             = Instance.new("UIListLayout", dropPanel)
	dpLayout.SortOrder         = Enum.SortOrder.LayoutOrder
	dpLayout.Padding           = UDim.new(0, 2)
	local dpPad                = Instance.new("UIPadding", dropPanel)
	dpPad.PaddingTop           = UDim.new(0, 4)
	dpPad.PaddingBottom        = UDim.new(0, 4)
	dpPad.PaddingLeft          = UDim.new(0, 4)
	dpPad.PaddingRight         = UDim.new(0, 4)

	local ITEM_H   = 28
	local MAX_SHOW = math.min(6, #options)
	local FULL_H   = MAX_SHOW * (ITEM_H + 2) + 8

	for _, opt2 in ipairs(options) do
		local ib               = Instance.new("TextButton", dropPanel)
		ib.Size                = UDim2.new(1, 0, 0, ITEM_H)
		ib.BackgroundColor3    = Color3.fromRGB(30, 10, 10)
		ib.BackgroundTransparency = opt2 == cur and 0.2 or 0.8
		ib.TextColor3          = opt2 == cur and Color3.fromRGB(255, 200, 200) or Color3.fromRGB(200, 200, 200)
		ib.Font                = Enum.Font.GothamMedium
		ib.TextSize            = 12
		ib.Text                = opt2
		ib.ZIndex              = 601
		ib.BorderSizePixel     = 0
		ib.AutoButtonColor     = false
		Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 6)
		items[opt2]            = ib

		ib.MouseButton1Click:Connect(function()
			PlayClick()
			cur = opt2
			valBtn.Text = opt2 .. " ▾"
			for o, b in pairs(items) do
				b.BackgroundTransparency = o == opt2 and 0.2 or 0.8
				b.TextColor3            = o == opt2 and Color3.fromRGB(255, 200, 200) or Color3.fromRGB(200, 200, 200)
			end
			TweenService:Create(dropPanel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = UDim2.fromOffset(138, 0) }):Play()
			task.delay(0.15, function() dropPanel.Visible = false end)
			isOpen = false
			if openDropdown == dropPanel then openDropdown = nil end
			if onChange then onChange(opt2) end
		end)
		ib.MouseEnter:Connect(function()
			if opt2 ~= cur then
				TweenService:Create(ib, TweenInfo.new(0.1), {BackgroundTransparency = 0.5}):Play()
			end
		end)
		ib.MouseLeave:Connect(function()
			if opt2 ~= cur then
				TweenService:Create(ib, TweenInfo.new(0.1), {BackgroundTransparency = 0.8}):Play()
			end
		end)
	end

	local function OpenDrop()
		if openDropdown and openDropdown ~= dropPanel then
			openDropdown.Visible = false
			openDropdown = nil
		end
		isOpen    = true
		openDropdown = dropPanel
		-- Posição: abaixo do botão
		local absP = valBtn.AbsolutePosition
		local absS = valBtn.AbsoluteSize
		local vp   = GetViewport()
		local panelH = math.min(FULL_H, vp.Y - absP.Y - absS.Y - 12)
		dropPanel.Position = UDim2.fromOffset(absP.X - 4, absP.Y + absS.Y + 4)
		dropPanel.Size     = UDim2.fromOffset(138, 0)
		dropPanel.Visible  = true
		TweenService:Create(dropPanel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(138, panelH) }):Play()
	end

	local function CloseDrop()
		isOpen = false
		if openDropdown == dropPanel then openDropdown = nil end
		TweenService:Create(dropPanel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.fromOffset(138, 0) }):Play()
		task.delay(0.15, function() dropPanel.Visible = false end)
	end

	valBtn.MouseButton1Click:Connect(function()
		PlayClick()
		if isOpen then CloseDrop() else OpenDrop() end
	end)

	-- Fechar ao clicar fora
	frame.AncestryChanged:Connect(function()
		if not frame.Parent then
			dropPanel.Visible = false
			if dropPanel.Parent then dropPanel:Destroy() end
		end
	end)
end

-- ==================== EXPAND ====================
local function ApplyWindowSize(animate)
	local n, e  = GetResponsiveSizes()
	local target = isExpanded and e or n
	if animate then
		TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = target}):Play()
	else
		mainWrapper.Size = target
	end
	task.defer(ClampWrapper)
end

-- Resize responsivo
local vcConn
local function BindResize()
	if vcConn then vcConn:Disconnect() vcConn = nil end
	local cam = workspace.CurrentCamera
	if not cam then return end
	vcConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if mainWrapper and mainWrapper.Parent then
			ApplyWindowSize(UIState == "OPEN")
			ClampWrapper()
			UpdateBarPos(false)
			task.defer(UpdateCanvas)
			task.defer(UpdateTabsCanvas)
		end
	end)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindResize)
BindResize()

ExpBtn.MouseButton1Click:Connect(function()
	PlayClick()
	if UIState ~= "OPEN" then return end
	isExpanded = not isExpanded
	ApplyWindowSize(true)
end)

-- ==================== MÁQUINA DE ESTADO ====================
SetUIState = function(newState)
	if UIState == newState or isTransitioning then return end
	isTransitioning = true
	local dur  = 0.24
	local info = TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	if newState == "OPEN" then
		mainWrapper.Visible = true
		local n = GetResponsiveSizes()
		mainWrapper.Size = n
		ApplyFade(mainWrapper, true, 0)
		ApplyFade(mainWrapper, false, dur)
		local n2, e2 = GetResponsiveSizes()
		local target = isExpanded and e2 or n2
		local tw = TweenService:Create(mainWrapper, info, {Size = target})
		tw:Play()
		tw.Completed:Connect(function()
			UIState         = "OPEN"
			isTransitioning = false
			SelectTab(activeTab)
			FilterToggles(activeTab, SearchBox.Text)
			UpdateBarPos(false)
		end)
	elseif newState == "MINIMIZED" or newState == "CLOSED" then
		ApplyFade(mainWrapper, true, dur)
		local n = GetResponsiveSizes()
		local tw = TweenService:Create(mainWrapper, info, {Size = n})
		tw:Play()
		tw.Completed:Connect(function()
			mainWrapper.Visible = false
			UIState             = newState
			isTransitioning     = false
		end)
	else
		isTransitioning = false
	end
end

-- ==================== TOP BUTTONS ====================
local function SetupTopBtn(btn, icon, hoverColor)
	local sc = Instance.new("UIScale", btn)
	sc.Scale = 1
	btn.MouseEnter:Connect(function()
		if UIState ~= "OPEN" then return end
		TweenService:Create(icon, TweenInfo.new(0.14), {ImageColor3 = hoverColor}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(icon, TweenInfo.new(0.14), {ImageColor3 = TOP_ICON_COLOR}):Play()
		TweenService:Create(sc, TweenInfo.new(0.12), {Scale = 1}):Play()
	end)
	btn.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(sc, TweenInfo.new(0.07), {Scale = 0.92}):Play()
		end
	end)
	btn.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)
	btn.MouseButton1Click:Connect(function()
		local flash = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
		TweenService:Create(icon, flash, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)
end

SetupTopBtn(MinBtn,   MinIcon,   Color3.fromRGB(255, 255, 255))
SetupTopBtn(ExpBtn,   ExpIcon,   Color3.fromRGB(255, 255, 255))
SetupTopBtn(CloseBtn, CloseIcon, Color3.fromRGB(255, 60, 60))

MinBtn.MouseButton1Click:Connect(function() PlayClick() SetUIState("MINIMIZED") end)

-- ==================== CONFIRM ====================
local function ToggleConfirm(show)
	isConfirmOpen = show
	local dur = 0.22
	if show then
		mainWrapper.Visible    = false
		FloatBtn.Visible       = false
		ConfirmOverlay.Visible = true
		TweenService:Create(confirmBlur, TweenInfo.new(dur), {Size = 26}):Play()
		local sc = confirmBlur and ConfirmCard:FindFirstChildOfClass("UIScale")
		if sc then sc:Destroy() end
		local cs = Instance.new("UIScale", ConfirmCard)
		cs.Scale = 0.88
		TweenService:Create(cs, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		ApplyFade(ConfirmCard, false, dur)
	else
		TweenService:Create(confirmBlur, TweenInfo.new(0.18), {Size = 0}):Play()
		ApplyFade(ConfirmCard, true, dur)
		local cs2 = ConfirmCard:FindFirstChildOfClass("UIScale")
		if cs2 then TweenService:Create(cs2, TweenInfo.new(0.16), {Scale = 0.88}):Play() end
		task.delay(dur + 0.05, function()
			if isConfirmOpen then return end
			ConfirmOverlay.Visible = false
			local cs3 = ConfirmCard:FindFirstChildOfClass("UIScale")
			if cs3 then cs3:Destroy() end
			if UIState == "OPEN" then mainWrapper.Visible = true end
			FloatBtn.Visible = true
		end)
	end
end

CloseBtn.MouseButton1Click:Connect(function() PlayClick() ToggleConfirm(true) end)
BtnNo.MouseButton1Click:Connect(function()   ToggleConfirm(false) end)
BtnYes.MouseButton1Click:Connect(function()
	local dur = 0.18
	TweenService:Create(confirmBlur, TweenInfo.new(dur), {Size = 0}):Play()
	ApplyFade(ConfirmCard, true, dur)
	task.wait(dur)
	pcall(function() confirmBlur:Destroy() end)
	if _G.AkatCallbacks and type(_G.AkatCallbacks.ShutdownAll) == "function" then
		pcall(_G.AkatCallbacks.ShutdownAll)
	end
	if _G.AkatUIShutdown then pcall(_G.AkatUIShutdown) end
end)

-- ==================== SHUTDOWN GLOBAL ====================
_G.AkatUIShutdown = function()
	pcall(function()
		if screenGui and screenGui.Parent then screenGui:Destroy() end
	end)
end

-- ==================== CRIAR ABAS ====================
CreateTab("Main")
CreateTab("Boss")
CreateTab("Mastery")
CreateTab("Farm")
CreateTab("Player")

-- ==================== CRIAR CONTROLES — ORGANIZADOS ====================
-- Ordem mantida por LayoutOrder implícito (ordem de criação)

-- ===== ABA: MAIN =====
-- Toggles principais de farm — sem repetição
CreateToggle("Main", "AutoFarmLevel")
CreateToggle("Main", "AutoFarmBoss")
CreateToggle("Main", "AutoFarmMastery")
CreateToggle("Main", "AutoFarmMaterials")
CreateToggle("Main", "AutoFarmChests")

-- ===== ABA: BOSS =====
-- Dropdown de seleção + toggle dedicado + opções de boss
CreateDropdown("Boss", "SelectedBoss", BOSS_LIST, DropdownState.SelectedBoss, function(v)
	DropdownState.SelectedBoss = v
	FireCallback("SelectedBoss", v)
end)
CreateToggle("Boss",         "AutoFarmBoss")
CreateCompactToggle("Boss",  "AutoCollectDrops")
CreateCompactToggle("Boss",  "AutoSkills")

-- ===== ABA: MASTERY =====
CreateDropdown("Mastery", "MasteryType", MASTERY_TYPES, DropdownState.MasteryType, function(v)
	DropdownState.MasteryType = v
	FireCallback("MasteryType", v)
end)
CreateToggle("Mastery",        "AutoFarmMastery")
CreateCompactToggle("Mastery", "SmartTargeting")
CreateCompactToggle("Mastery", "AutoSkills")

-- ===== ABA: FARM =====
CreateToggle("Farm",        "MobAura")
CreateSlider("Farm",        "AuraRange",  5, 100, 30)
CreateToggle("Farm",        "AutoQuest")
CreateCompactToggle("Farm", "AutoSkills")
CreateDropdown("Farm", "MaterialTarget", MATERIAL_TYPES, DropdownState.MaterialTarget, function(v)
	DropdownState.MaterialTarget = v
	FireCallback("MaterialTarget", v)
end)
CreateToggle("Farm", "AutoFarmMaterials")
CreateToggle("Farm", "AutoFarmChests")

-- ===== ABA: PLAYER =====
CreateSlider("Player", "Speed",     16, 100, 16)
CreateSlider("Player", "JumpPower", 50, 150, 50)

-- ==================== INTRO ====================
local function RunIntro()
	local Blur         = Instance.new("BlurEffect", Lighting)
	Blur.Name          = "IntroBlur"
	Blur.Size          = 0

	local IntroFrame   = Instance.new("Frame", screenGui)
	IntroFrame.Size    = UDim2.new(1, 0, 1, 0)
	IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	IntroFrame.BackgroundTransparency = 1
	IntroFrame.ZIndex  = 500

	local MaskFrame    = Instance.new("Frame", IntroFrame)
	MaskFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MaskFrame.Position = UDim2.new(0.5, 0, 0.5, -10)
	MaskFrame.Size     = UDim2.new(0, 420, 0, 40)
	MaskFrame.BackgroundTransparency = 1
	MaskFrame.ClipsDescendants = true

	local IntroText    = Instance.new("TextLabel", MaskFrame)
	IntroText.Size     = UDim2.new(1, 0, 1, 0)
	IntroText.Position = UDim2.new(0, 0, 1, 0)
	IntroText.BackgroundTransparency = 1
	IntroText.Font     = Enum.Font.GothamBold
	IntroText.TextSize = 26
	IntroText.RichText = true
	IntroText.Text     = UI_TEXT.Intro

	local IntroLine    = Instance.new("Frame", IntroFrame)
	IntroLine.AnchorPoint = Vector2.new(0.5, 0.5)
	IntroLine.Position = UDim2.new(0.5, 0, 0.5, 16)
	IntroLine.Size     = UDim2.new(0, 0, 0, 2)
	IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
	IntroLine.BorderSizePixel  = 0
	IntroLine.BackgroundTransparency = 1
	Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

	TweenService:Create(IntroFrame, TweenInfo.new(0.45), {BackgroundTransparency = 0.06}):Play()
	TweenService:Create(Blur,       TweenInfo.new(0.45), {Size = 22}):Play()
	task.wait(0.1)
	TweenService:Create(IntroText, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Position = UDim2.new(0, 0, 0, 0)}):Play()
	task.wait(0.18)
	TweenService:Create(IntroLine, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play()
	task.wait(1.5)
	TweenService:Create(IntroText, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
	TweenService:Create(IntroLine, TweenInfo.new(0.35), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
	task.wait(0.28)
	TweenService:Create(IntroFrame, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Blur,       TweenInfo.new(0.35), {Size = 0}):Play()
	task.wait(0.3)

	-- Registra transparências antes de exibir
	RegTrans(mainWrapper)
	for _, d in ipairs(mainWrapper:GetDescendants()) do RegTrans(d) end

	local normalSize = GetResponsiveSizes()
	mainWrapper.Size    = normalSize
	mainWrapper.Visible = true
	FloatBtn.Visible    = true
	UIState             = "OPEN"
	isTransitioning     = false

	local sc = Instance.new("UIScale", mainWrapper)
	sc.Scale = 0.86
	ApplyFade(mainWrapper, true,  0)
	ApplyFade(mainWrapper, false, 0.3)

	local tw = TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
	tw:Play()

	FloatBtn.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(FloatBtn, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = UDim2.new(0, 44, 0, 44)}):Play()

	Notif("AKATSUKI SCRIPTS", "Blox Fruits v2.0 iniciado! Bem-vindo, " .. player.DisplayName .. "!")
	task.delay(0.9, NotifDiscord)

	tw.Completed:Connect(function()
		pcall(function() sc:Destroy() end)
		pcall(function() Blur:Destroy() end)
		IntroFrame:Destroy()
		task.defer(function() SelectTab("Main") end)
	end)
end

RunIntro()
