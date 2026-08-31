-- [[ AKATSUKI UI — BLOX FRUITS EDITION [v6.0 - UNIFIED PANEL] ]]
-- Interface visual pura — sem lógica de jogo.
-- Requer bf_logic.lua carregado primeiro (via _G.AkatCallbacks).

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local ContentProvider  = game:GetService("ContentProvider")

local player = Players.LocalPlayer

-- Limpa instância anterior
if _G.AkatUIShutdown then pcall(_G.AkatUIShutdown) end

-- ==================== TEXTOS DA UI ====================
local UI_TEXT = {
    SearchPlaceholder = "Pesquisar...",
    ConfirmCloseTitle = "Deseja fechar o script?",
    ConfirmBtn        = "Sim",
    CancelBtn         = "Não",
    Intro             = '<font color="#FFFFFF">Scripts by | </font><font color="#FFD700">AKATSUKI</font>',
    Tabs = {
        Farm     = "Farm",
        Combat   = "Combat",
        Visuals  = "Visuals",
        Player   = "Player",
        Settings = "Settings",
    },
    Options = {
        -- Farm
        AutoFarmLevel   = { Title = "Auto Farm Level",   Desc = "Teleporta até a ilha/quest correta, mata mobs via Mob Aura e entrega quests automaticamente." },
        AutoFarmBoss    = { Title = "Auto Farm Boss",     Desc = "Teleporta até os bosses do First Sea, usa skills em loop e aguarda respawn para repetir." },
        AutoFarmMastery = { Title = "Auto Mastery",       Desc = "Seleciona arma/fruto e usa skills repetidamente em mobs balanceados para ganho rápido de mastery." },
        AutoFarmBones   = { Title = "Auto Farm Bones",    Desc = "Teleporta aos spawn de Bones e Materials, coleta automaticamente ao matar mobs corretos." },
        AutoFarmChests  = { Title = "Auto Farm Chests",   Desc = "Vasculha ilhas em busca de baús, teleportando de ponto em ponto para coletar Beli e fragmentos." },
        AutoQuest       = { Title = "Auto Quest",         Desc = "Aceita a quest, vai até a área, mata os mobs necessários e entrega — tudo automático." },
        MobAura         = { Title = "Mob Aura",           Desc = "Raio invisível ao redor do personagem que elimina NPCs automaticamente. Ajuste o alcance no slider." },
        AuraRadius      = { Title = "Aura Radius",        Desc = "Define o raio de alcance da Mob Aura em studs." },
        AutoSkills      = { Title = "Auto Skills",        Desc = "Usa habilidades do fruto e da espada em loop sem input do jogador." },
        -- Combat
        InstantKill     = { Title = "Instant Kill",       Desc = "Mata players com um único hit usando exploit de damage." },
        AntiKill        = { Title = "Anti Kill",          Desc = "Dificulta que outros players te eliminem (god mode parcial)." },
        NoClip          = { Title = "No Clip",            Desc = "Atravessa paredes e terreno livremente." },
        -- Visuals
        ESP             = { Title = "Player ESP",         Desc = "Destaca players e NPCs através de paredes com caixas coloridas." },
        NameESP         = { Title = "Name ESP",           Desc = "Exibe nomes dos jogadores e nível acima dos personagens." },
        Tracer          = { Title = "Tracer ESP",         Desc = "Desenha linha até outros jogadores com cor personalizada." },
        -- Player
        Speed           = { Title = "Speed",              Desc = "Aumenta a velocidade de movimento do personagem." },
        JumpPower       = { Title = "Jump Power",         Desc = "Aumenta a altura do pulo." },
        AntiFling       = { Title = "Anti-Fling",         Desc = "Desativa colisões para evitar ser lançado por outros jogadores." },
        Invisibility    = { Title = "Invisibility",       Desc = "Torna o personagem invisível para outros jogadores." },
        TpPlayer        = { Title = "TP to Player",       Desc = "Teleporta até um jogador específico selecionado na lista." },
        -- Settings
        AntiAFK         = { Title = "Anti-AFK",           Desc = "Previne kick por inatividade simulando inputs periódicos." },
        AntiKick        = { Title = "Anti-Kick",          Desc = "Reduz chance de kick por exploits com delays e bypasses." },
        ChatLog         = { Title = "Chat Log",           Desc = "Mostra no console o chat de todos os jogadores da sala." },
        XRay            = { Title = "X-Ray",              Desc = "Permite enxergar através de objetos e terreno." },
    },
}

-- ==================== CONFIGS LOCAIS (espelho) ====================
local Configs = {
    AutoFarmLevel   = false,
    AutoFarmBoss    = false,
    AutoFarmMastery = false,
    AutoFarmBones   = false,
    AutoFarmChests  = false,
    AutoQuest       = false,
    MobAura         = false,
    AuraRadius      = false, AuraRadiusValue = 20,
    AutoSkills      = false,
    InstantKill     = false,
    AntiKill        = false,
    NoClip          = false,
    ESP             = false,
    NameESP         = false,
    Tracer          = false,
    Speed           = false, SpeedValue    = 16,
    JumpPower       = false, JumpPowerValue = 50,
    AntiFling       = false,
    Invisibility    = false,
    TpPlayer        = false,
    AntiAFK         = false,
    AntiKick        = false,
    ChatLog         = false,
    XRay            = false,
}

-- ==================== ESTADO ====================
local UIState        = "CLOSED"
local activeTab      = "Farm"
local tabButtons     = {}
local isExpanded     = false
local originalTrans  = {}
local isConfirmOpen  = false

-- ==================== DIMENSIONAMENTO RESPONSIVO ====================
local NORMAL_UI_SIZE   = Vector2.new(575, 400)
local EXPANDED_UI_SIZE = Vector2.new(920, 420)
local UI_SAFE_MARGIN   = 14

local function GetViewportSize()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function GetResponsiveUISizes()
    local vp   = GetViewportSize()
    local maxW = math.max(1, vp.X - UI_SAFE_MARGIN * 2)
    local maxH = math.max(1, vp.Y - UI_SAFE_MARGIN * 2)
    return
        UDim2.fromOffset(math.min(NORMAL_UI_SIZE.X, maxW),   math.min(NORMAL_UI_SIZE.Y, maxH)),
        UDim2.fromOffset(math.min(EXPANDED_UI_SIZE.X, maxW), math.min(EXPANDED_UI_SIZE.Y, maxH))
end

local function ClampMainWrapper(wrapper)
    if not wrapper or not wrapper.Parent then return end
    local vp   = GetViewportSize()
    local size = wrapper.AbsoluteSize
    local hw   = math.min(size.X / 2, vp.X / 2 - UI_SAFE_MARGIN)
    local hh   = math.min(size.Y / 2, vp.Y / 2 - UI_SAFE_MARGIN)
    local pos  = wrapper.AbsolutePosition + size / 2
    wrapper.Position = UDim2.fromOffset(
        math.clamp(pos.X, hw + UI_SAFE_MARGIN, vp.X - hw - UI_SAFE_MARGIN),
        math.clamp(pos.Y, hh + UI_SAFE_MARGIN, vp.Y - hh - UI_SAFE_MARGIN)
    )
end

-- ==================== SCREENGUI ====================
local screenGui              = Instance.new("ScreenGui")
screenGui.Name               = "AkatBFUI"
screenGui.ResetOnSpawn       = false
screenGui.IgnoreGuiInset     = true
screenGui.ZIndexBehavior     = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then uiParent = gethui()
else pcall(function() uiParent = game:GetService("CoreGui") end) end

if uiParent:FindFirstChild("AkatBFUI") then
    pcall(function() uiParent.AkatBFUI:Destroy() end)
end
for _, bf in ipairs(Lighting:GetChildren()) do
    if bf:IsA("BlurEffect") and (bf.Name == "ConfirmBlur" or bf.Name == "IntroBlur") then
        pcall(function() bf:Destroy() end)
    end
end
screenGui.Parent = uiParent

-- Som de clique
local ClickSound           = Instance.new("Sound", screenGui)
ClickSound.SoundId         = "rbxassetid://6895079853"
ClickSound.Volume          = 0.5
ClickSound.Looped          = false
local function PlayClick() pcall(function() ClickSound.TimePosition = 0; ClickSound:Play() end) end

-- ==================== FADE SINCRONIZADO ====================
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

local function FadeSync(root, fadeOut, dur)
    if not root or not root.Parent then return end
    local info = TweenInfo.new(dur, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local function handle(obj)
        if not obj or not obj.Parent then return end
        RegTrans(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        local function tw(prop, target)
            if obj[prop] == nil then return end
            if dur == 0 then obj[prop] = target
            else TweenService:Create(obj, info, {[prop] = target}):Play() end
        end
        if orig.BackgroundTransparency ~= nil then tw("BackgroundTransparency", fadeOut and 1 or orig.BackgroundTransparency) end
        if orig.TextTransparency       ~= nil then tw("TextTransparency",       fadeOut and 1 or orig.TextTransparency)       end
        if orig.ImageTransparency      ~= nil then tw("ImageTransparency",      fadeOut and 1 or orig.ImageTransparency)      end
        if orig.Transparency           ~= nil then tw("Transparency",           fadeOut and 1 or orig.Transparency)           end
    end
    handle(root)
    for _, d in ipairs(root:GetDescendants()) do handle(d) end
end

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn            = Instance.new("ImageButton", screenGui)
FloatBtn.Name             = "FloatBtn"
FloatBtn.AnchorPoint      = Vector2.new(0.5, 0.5)
FloatBtn.Size             = UDim2.new(0, 44, 0, 44)
FloatBtn.Position         = UDim2.new(0.06, 0, 0.2, 0)
FloatBtn.Image            = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 8, 0)
FloatBtn.Visible          = false
FloatBtn.ZIndex           = 100
FloatBtn.AutoButtonColor  = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatOpenSound      = Instance.new("Sound", FloatBtn)
FloatOpenSound.SoundId    = "rbxassetid://6310837681"
FloatOpenSound.Volume     = 0.2

task.spawn(function() pcall(function() ContentProvider:PreloadAsync({FloatOpenSound, ClickSound}) end) end)

-- ==================== DRAG FLOAT ====================
local dragToggleF, dragInputF, dragStartF, startPosF, isDraggingF = false, nil, nil, nil, false

FloatBtn.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not dragToggleF then
        dragToggleF = true; dragInputF = input; isDraggingF = false
        dragStartF = input.Position; startPosF = FloatBtn.Position
    end
end)

-- ==================== JANELA PRINCIPAL ====================
local mainWrapper            = Instance.new("Frame", screenGui)
mainWrapper.Name             = "MainWrapper"
mainWrapper.AnchorPoint      = Vector2.new(0.5, 0.5)
mainWrapper.Size             = UDim2.new(0, 640, 0, 380)
mainWrapper.Position         = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible          = false
mainWrapper.ClipsDescendants = false
mainWrapper.ZIndex           = 1

local mainFrame              = Instance.new("Frame", mainWrapper)
mainFrame.Size               = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex             = 2
mainFrame.ClipsDescendants   = false

-- Drag janela principal
local dragUIToggle, dragUIInput, dragUIStart, startUIPos = false, nil, nil, nil
mainFrame.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not dragUIToggle then
        dragUIToggle = true; dragUIInput = input; dragUIStart = input.Position; startUIPos = mainWrapper.Position
    end
end)

local SetUIState

UserInputService.InputChanged:Connect(function(input)
    if dragUIToggle and input == dragUIInput then
        local delta = input.Position - dragUIStart
        local vp = workspace.CurrentCamera.ViewportSize
        local hw = mainWrapper.Size.X.Offset / 2
        local hh = mainWrapper.Size.Y.Offset / 2
        local absX = math.clamp(vp.X * startUIPos.X.Scale + startUIPos.X.Offset + delta.X, hw, vp.X - hw)
        local absY = math.clamp(vp.Y * startUIPos.Y.Scale + startUIPos.Y.Offset + delta.Y, hh, vp.Y - hh)
        mainWrapper.Position = UDim2.new(0, absX, 0, absY)
    end
    if dragToggleF and input == dragInputF then
        local delta = input.Position - dragStartF
        if delta.Magnitude > 5 then isDraggingF = true end
        local vp = workspace.CurrentCamera.ViewportSize
        local baseX = vp.X * startPosF.X.Scale + startPosF.X.Offset
        local baseY = vp.Y * startPosF.Y.Scale + startPosF.Y.Offset
        FloatBtn.Position = UDim2.new(0, math.clamp(baseX + delta.X, 22, vp.X - 22), 0, math.clamp(baseY + delta.Y, 22, vp.Y - 22))
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input == dragInputF then
        if dragToggleF and not isDraggingF then
            if UIState == "MINIMIZED" or UIState == "CLOSED" then
                pcall(function() FloatOpenSound.TimePosition = 0; FloatOpenSound:Play() end)
                SetUIState("OPEN")
            elseif UIState == "OPEN" then
                SetUIState("MINIMIZED")
            end
        end
        dragToggleF = false; dragInputF = nil
    end
    if input == dragUIInput then dragUIToggle = false; dragUIInput = nil end
end)

-- ==================== FUNDO PRINCIPAL ====================
local Shadow                   = Instance.new("ImageLabel", mainFrame)
Shadow.AnchorPoint             = Vector2.new(0, 0)
Shadow.Position                = UDim2.new(0, -12, 0, -12)
Shadow.Size                    = UDim2.new(1, 24, 1, 24)
Shadow.BackgroundTransparency  = 1
Shadow.Image                   = "rbxassetid://5554831957"
Shadow.ImageColor3             = Color3.fromRGB(0, 2, 5)
Shadow.ImageTransparency       = 0.40
Shadow.ScaleType               = Enum.ScaleType.Slice
Shadow.SliceCenter             = Rect.new(36, 36, 114, 114)
Shadow.ZIndex                  = 3

local MainBG                   = Instance.new("Frame", mainFrame)
MainBG.Size                    = UDim2.new(1, 0, 1, 0)
MainBG.BackgroundColor3        = Color3.fromRGB(5, 10, 20)
MainBG.BorderSizePixel         = 0
MainBG.ClipsDescendants        = true
MainBG.ZIndex                  = 4
Instance.new("UICorner", MainBG).CornerRadius = UDim.new(0, 10)

local MainStroke               = Instance.new("UIStroke", MainBG)
MainStroke.Thickness           = 2
MainStroke.ApplyStrokeMode     = Enum.ApplyStrokeMode.Border

local MainStrokeGrad           = Instance.new("UIGradient", MainStroke)
MainStrokeGrad.Rotation        = 45
MainStrokeGrad.Color           = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 60, 140)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 160, 0)),
})

-- Overlay de gradiente azul-dourado
local BGOverlay                = Instance.new("Frame", MainBG)
BGOverlay.Size                 = UDim2.new(1, 0, 1, 0)
BGOverlay.BackgroundColor3     = Color3.fromRGB(255, 255, 255)
BGOverlay.BackgroundTransparency = 0
BGOverlay.BorderSizePixel      = 0
BGOverlay.ZIndex               = 4
Instance.new("UICorner", BGOverlay).CornerRadius = UDim.new(0, 10)

local BGGrad                   = Instance.new("UIGradient", BGOverlay)
BGGrad.Rotation                = 90
BGGrad.Color                   = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(5, 15, 40)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 25, 60)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(5, 15, 40)),
})

-- ==================== PANELS ====================
local LeftPanel                = Instance.new("Frame", MainBG)
LeftPanel.Size                 = UDim2.new(0, 225, 1, 0)
LeftPanel.BackgroundTransparency = 1
LeftPanel.ZIndex               = 5

local RightPanel               = Instance.new("Frame", MainBG)
RightPanel.Size                = UDim2.new(1, -225, 1, 0)
RightPanel.Position            = UDim2.new(0, 225, 0, 0)
RightPanel.BackgroundTransparency = 1
RightPanel.ZIndex              = 5

-- Separador vertical
local Divider                  = Instance.new("Frame", MainBG)
Divider.Size                   = UDim2.new(0, 1, 0.85, 0)
Divider.Position               = UDim2.new(0, 224, 0.075, 0)
Divider.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
Divider.BorderSizePixel        = 0
Divider.ZIndex                 = 6
local DivGrad                  = Instance.new("UIGradient", Divider)
DivGrad.Rotation               = 90
DivGrad.Color                  = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 60, 140)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 160, 0)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 60, 140)),
})

-- ==================== HEADER LEFT ====================
local HeaderLeft               = Instance.new("Frame", LeftPanel)
HeaderLeft.Size                = UDim2.new(1, 0, 0, 38)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex              = 20

local HeaderImg                = Instance.new("ImageLabel", HeaderLeft)
HeaderImg.Size                 = UDim2.new(0, 26, 0, 26)
HeaderImg.Position             = UDim2.new(0, 10, 0.5, -13)
HeaderImg.BackgroundTransparency = 1
HeaderImg.Image                = "rbxthumb://type=Asset&id=134217291845443&w=150&h=150"
HeaderImg.ZIndex               = 21

local TitleLbl                 = Instance.new("TextLabel", HeaderLeft)
TitleLbl.Size                  = UDim2.new(1, -44, 0, 16)
TitleLbl.Position              = UDim2.new(0, 42, 0, 5)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text                  = "AKATSUKI SCRIPTS HUB"
TitleLbl.TextColor3            = Color3.fromRGB(255, 215, 0)
TitleLbl.TextSize              = 12
TitleLbl.Font                  = Enum.Font.GothamBold
TitleLbl.TextXAlignment        = Enum.TextXAlignment.Left
TitleLbl.ZIndex                = 21

local SubLbl                   = Instance.new("TextLabel", HeaderLeft)
SubLbl.Size                    = UDim2.new(1, -44, 0, 12)
SubLbl.Position                = UDim2.new(0, 42, 0, 21)
SubLbl.BackgroundTransparency  = 1
SubLbl.Text                    = "BLOX FRUITS SCRIPT | by zeni"
SubLbl.TextColor3              = Color3.fromRGB(140, 180, 255)
SubLbl.TextTransparency        = 0.15
SubLbl.TextSize                = 9.5
SubLbl.Font                    = Enum.Font.Gotham
SubLbl.TextXAlignment          = Enum.TextXAlignment.Left
SubLbl.ZIndex                  = 21

-- ==================== BARRA DE PESQUISA ====================
local SearchCont               = Instance.new("Frame", LeftPanel)
SearchCont.Size                = UDim2.new(1, -16, 0, 34)
SearchCont.Position            = UDim2.new(0, 8, 0, 46)
SearchCont.BackgroundColor3    = Color3.fromRGB(8, 14, 28)
SearchCont.BackgroundTransparency = 0.55
SearchCont.ZIndex              = 20
Instance.new("UICorner", SearchCont).CornerRadius = UDim.new(0, 8)
local sStroke                  = Instance.new("UIStroke", SearchCont)
sStroke.Color                  = Color3.fromRGB(0, 80, 180)
sStroke.Transparency           = 0.6
sStroke.Thickness              = 1

local SearchBox                = Instance.new("TextBox", SearchCont)
SearchBox.Size                 = UDim2.new(1, -14, 1, 0)
SearchBox.Position             = UDim2.new(0, 10, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.PlaceholderText      = UI_TEXT.SearchPlaceholder
SearchBox.PlaceholderColor3    = Color3.fromRGB(100, 120, 160)
SearchBox.Text                 = ""
SearchBox.TextColor3           = Color3.fromRGB(220, 230, 255)
SearchBox.Font                 = Enum.Font.GothamMedium
SearchBox.TextSize             = 13
SearchBox.TextXAlignment       = Enum.TextXAlignment.Left
SearchBox.ZIndex               = 22
SearchBox.ClearTextOnFocus     = false

-- ==================== TABS CONTAINER ====================
local TabsCont                 = Instance.new("ScrollingFrame", LeftPanel)
TabsCont.Size                  = UDim2.new(1, -8, 1, -155)
TabsCont.Position              = UDim2.new(0, 4, 0, 87)
TabsCont.BackgroundTransparency = 1
TabsCont.BorderSizePixel       = 0
TabsCont.ZIndex                = 10
TabsCont.CanvasSize            = UDim2.new(0, 0, 0, 0)
TabsCont.ScrollBarThickness    = 2
TabsCont.ScrollBarImageColor3  = Color3.fromRGB(200, 160, 0)
TabsCont.ScrollBarImageTransparency = 0.4
TabsCont.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local TabsLayout               = Instance.new("UIListLayout", TabsCont)
TabsLayout.SortOrder           = Enum.SortOrder.LayoutOrder
TabsLayout.Padding             = UDim.new(0, 2)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
    local h = TabsLayout.AbsoluteContentSize.Y + 8
    TabsCont.CanvasSize = UDim2.new(0, 0, 0, math.max(h, TabsCont.AbsoluteSize.Y + 12))
end
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsCont:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

-- ==================== ACTIVE BAR ====================
local ActiveBarCont            = Instance.new("Frame", LeftPanel)
ActiveBarCont.Size             = UDim2.new(1, -8, 1, -155)
ActiveBarCont.Position         = UDim2.new(0, 4, 0, 87)
ActiveBarCont.BackgroundTransparency = 1
ActiveBarCont.ClipsDescendants = true
ActiveBarCont.ZIndex           = 8

local sharedActiveBar          = Instance.new("Frame", ActiveBarCont)
sharedActiveBar.AnchorPoint    = Vector2.new(0, 0.5)
sharedActiveBar.Size           = UDim2.new(0, 3, 0, 22)
sharedActiveBar.Position       = UDim2.new(0, 7, 0, 0)
sharedActiveBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
sharedActiveBar.BorderSizePixel = 0
sharedActiveBar.Visible        = false
sharedActiveBar.ZIndex         = 8
Instance.new("UICorner", sharedActiveBar).CornerRadius = UDim.new(1, 0)

local activeBarScale           = Instance.new("UIScale", sharedActiveBar)
activeBarScale.Scale           = 1

local sharedBarGrad            = Instance.new("UIGradient", sharedActiveBar)
sharedBarGrad.Rotation         = 90
sharedBarGrad.Color            = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 60, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 60, 0)),
})

-- ==================== USER PROFILE ====================
local UserFrame                = Instance.new("Frame", LeftPanel)
UserFrame.Size                 = UDim2.new(1, -16, 0, 55)
UserFrame.Position             = UDim2.new(0, 8, 1, -63)
UserFrame.BackgroundColor3     = Color3.fromRGB(8, 16, 36)
UserFrame.BackgroundTransparency = 0.30
UserFrame.BorderSizePixel      = 0
UserFrame.ZIndex               = 20
Instance.new("UICorner", UserFrame).CornerRadius = UDim.new(0, 8)

local uStroke                  = Instance.new("UIStroke", UserFrame)
uStroke.Thickness              = 0.9
local uGrad                    = Instance.new("UIGradient", uStroke)
uGrad.Color                    = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 80, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 160, 0)),
})

local AvatarImg                = Instance.new("ImageLabel", UserFrame)
AvatarImg.Size                 = UDim2.new(0, 34, 0, 34)
AvatarImg.Position             = UDim2.new(0, 10, 0.5, -17)
AvatarImg.BackgroundTransparency = 1
AvatarImg.Image                = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImg.ZIndex               = 21
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)
local avStroke                 = Instance.new("UIStroke", AvatarImg)
avStroke.Thickness             = 0.9
local avGrad                   = Instance.new("UIGradient", avStroke)
avGrad.Color                   = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 80, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 160, 0)),
})

local StatusDot                = Instance.new("Frame", AvatarImg)
StatusDot.Size                 = UDim2.new(0, 9, 0, 9)
StatusDot.Position             = UDim2.new(1, -7, 1, -7)
StatusDot.BackgroundColor3     = Color3.fromRGB(40, 220, 80)
StatusDot.BorderSizePixel      = 0
StatusDot.ZIndex               = 22
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)
local dotStroke                = Instance.new("UIStroke", StatusDot)
dotStroke.Color                = Color3.fromRGB(5, 10, 20)
dotStroke.Thickness            = 1.5

local DisplayLbl               = Instance.new("TextLabel", UserFrame)
DisplayLbl.Size                = UDim2.new(1, -56, 0, 16)
DisplayLbl.Position            = UDim2.new(0, 54, 0.5, -16)
DisplayLbl.BackgroundTransparency = 1
DisplayLbl.Text                = player.DisplayName
DisplayLbl.TextColor3          = Color3.fromRGB(240, 240, 240)
DisplayLbl.Font                = Enum.Font.GothamBold
DisplayLbl.TextSize            = 13
DisplayLbl.TextXAlignment      = Enum.TextXAlignment.Left
DisplayLbl.TextTruncate        = Enum.TextTruncate.AtEnd
DisplayLbl.ZIndex              = 21

local UsernameLbl              = Instance.new("TextLabel", UserFrame)
UsernameLbl.Size               = UDim2.new(1, -56, 0, 13)
UsernameLbl.Position           = UDim2.new(0, 54, 0.5, 2)
UsernameLbl.BackgroundTransparency = 1
UsernameLbl.Text               = "@" .. player.Name
UsernameLbl.TextColor3         = Color3.fromRGB(100, 130, 200)
UsernameLbl.Font               = Enum.Font.Gotham
UsernameLbl.TextSize           = 11
UsernameLbl.TextXAlignment     = Enum.TextXAlignment.Left
UsernameLbl.TextTruncate       = Enum.TextTruncate.AtEnd
UsernameLbl.ZIndex             = 21

-- ==================== RIGHT PANEL HEADER ====================
local TopBtns                  = Instance.new("Frame", RightPanel)
TopBtns.Size                   = UDim2.new(1, -12, 0, 36)
TopBtns.BackgroundTransparency = 1
TopBtns.ZIndex                 = 20

local CtrlFrame                = Instance.new("Frame", TopBtns)
CtrlFrame.Size                 = UDim2.new(0, 130, 1, 0)
CtrlFrame.Position             = UDim2.new(1, -130, 0, 0)
CtrlFrame.BackgroundTransparency = 1
CtrlFrame.ZIndex               = 25

local CtrlLayout               = Instance.new("UIListLayout", CtrlFrame)
CtrlLayout.FillDirection       = Enum.FillDirection.Horizontal
CtrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
CtrlLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
CtrlLayout.Padding             = UDim.new(0, 2)
CtrlLayout.SortOrder           = Enum.SortOrder.LayoutOrder

local TOP_COLOR = Color3.fromRGB(160, 160, 160)

local function MakeTopBtn(name, imageId, order)
    local btn              = Instance.new("ImageButton", CtrlFrame)
    btn.Name               = name
    btn.LayoutOrder        = order
    btn.Size               = UDim2.new(0, 28, 0, 28)
    btn.BackgroundTransparency = 1
    btn.ZIndex             = 25
    btn.AutoButtonColor    = false
    local icon             = Instance.new("ImageLabel", btn)
    icon.AnchorPoint       = Vector2.new(0.5, 0.5)
    icon.Position          = UDim2.new(0.5, 0, 0.5, 0)
    icon.Size              = UDim2.new(0, 14, 0, 14)
    icon.BackgroundTransparency = 1
    icon.Image             = imageId
    icon.ImageColor3       = TOP_COLOR
    icon.ZIndex            = 26
    return btn, icon
end

local MinBtn, MinIcon   = MakeTopBtn("MinBtn",   "rbxthumb://type=Asset&id=97090905107587&w=150&h=150", 1)
local ExpBtn, ExpIcon   = MakeTopBtn("ExpBtn",   "rbxthumb://type=Asset&id=78749046909931&w=150&h=150", 2)
local CloseBtn, CloseIc = MakeTopBtn("CloseBtn", "rbxthumb://type=Asset&id=70710316269357&w=150&h=150", 3)

-- Badge versão
local BadgeF                   = Instance.new("Frame", RightPanel)
BadgeF.Size                    = UDim2.new(0, 50, 0, 18)
BadgeF.Position                = UDim2.new(0, 12, 0, 9)
BadgeF.BackgroundColor3        = Color3.fromRGB(255, 255, 255)
BadgeF.BorderSizePixel         = 0
BadgeF.ZIndex                  = 15
Instance.new("UICorner", BadgeF).CornerRadius = UDim.new(0, 8)
local badgeGrad                = Instance.new("UIGradient", BadgeF)
badgeGrad.Rotation             = 45
badgeGrad.Color                = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 80, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 140, 0)),
})
local BadgeTxt                 = Instance.new("TextLabel", BadgeF)
BadgeTxt.Size                  = UDim2.new(1, 0, 1, 0)
BadgeTxt.BackgroundTransparency = 1
BadgeTxt.Text                  = "BF v6"
BadgeTxt.TextColor3            = Color3.fromRGB(255, 255, 255)
BadgeTxt.Font                  = Enum.Font.GothamBold
BadgeTxt.TextSize              = 8.5
BadgeTxt.ZIndex                = 16

-- ==================== PAINEL DE SELEÇÃO DE BOSS (animado) ====================
-- Aparece acima do togglesContainer quando AutoFarmBoss está ativo.
local BossPanel                = Instance.new("Frame", RightPanel)
BossPanel.Name                 = "BossPanel"
BossPanel.Size                 = UDim2.new(1, -12, 0, 0)  -- começa colapsado
BossPanel.Position             = UDim2.new(0, 6, 0, 38)
BossPanel.BackgroundColor3     = Color3.fromRGB(6, 18, 40)
BossPanel.BackgroundTransparency = 0.30
BossPanel.BorderSizePixel      = 0
BossPanel.ClipsDescendants     = true
BossPanel.Visible              = false
BossPanel.ZIndex               = 12
Instance.new("UICorner", BossPanel).CornerRadius = UDim.new(0, 8)

local BossStroke               = Instance.new("UIStroke", BossPanel)
BossStroke.Thickness           = 1
BossStroke.Color               = Color3.fromRGB(200, 160, 0)
BossStroke.Transparency        = 0.4

local BossTitle                = Instance.new("TextLabel", BossPanel)
BossTitle.Size                 = UDim2.new(1, -10, 0, 22)
BossTitle.Position             = UDim2.new(0, 8, 0, 4)
BossTitle.BackgroundTransparency = 1
BossTitle.Text                 = "🎯  Selecionar Boss"
BossTitle.TextColor3           = Color3.fromRGB(255, 215, 0)
BossTitle.Font                 = Enum.Font.GothamBold
BossTitle.TextSize             = 12
BossTitle.TextXAlignment       = Enum.TextXAlignment.Left
BossTitle.ZIndex               = 13

local BossScroll               = Instance.new("ScrollingFrame", BossPanel)
BossScroll.Size                = UDim2.new(1, -8, 1, -32)
BossScroll.Position            = UDim2.new(0, 4, 0, 28)
BossScroll.BackgroundTransparency = 1
BossScroll.BorderSizePixel     = 0
BossScroll.ScrollBarThickness  = 2
BossScroll.ScrollBarImageColor3 = Color3.fromRGB(200, 160, 0)
BossScroll.ZIndex              = 13

local BossLayout               = Instance.new("UIListLayout", BossScroll)
BossLayout.SortOrder           = Enum.SortOrder.LayoutOrder
BossLayout.Padding             = UDim.new(0, 3)

local BOSSES = {
    "Gorilla King", "Saber Expert", "Cursed Captain",
    "Yeti", "Smoke Admiral", "Magma Admiral",
    "Ice Admiral", "Sand Boss", "Thunder God",
    "Lord of Destruction",
}

local selectedBoss = BOSSES[1]

local function MakeBossBtn(bossName, order)
    local btn                  = Instance.new("TextButton", BossScroll)
    btn.Name                   = bossName
    btn.LayoutOrder            = order
    btn.Size                   = UDim2.new(1, -4, 0, 26)
    btn.BackgroundColor3       = Color3.fromRGB(10, 25, 55)
    btn.BackgroundTransparency = 0.35
    btn.BorderSizePixel        = 0
    btn.Text                   = bossName
    btn.TextColor3             = Color3.fromRGB(180, 200, 255)
    btn.Font                   = Enum.Font.GothamMedium
    btn.TextSize               = 12
    btn.ZIndex                 = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function highlight(active)
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and Color3.fromRGB(20, 60, 120) or Color3.fromRGB(10, 25, 55),
            TextColor3 = active and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(180, 200, 255),
        }):Play()
    end

    btn.MouseButton1Click:Connect(function()
        PlayClick()
        selectedBoss = bossName
        if _G.AkatCallbacks and _G.AkatCallbacks.SetBossTarget then
            _G.AkatCallbacks.SetBossTarget(bossName)
        end
        for _, child in ipairs(BossScroll:GetChildren()) do
            if child:IsA("TextButton") then
                local isSelected = child.Name == bossName
                TweenService:Create(child, TweenInfo.new(0.15), {
                    BackgroundColor3 = isSelected and Color3.fromRGB(20, 60, 120) or Color3.fromRGB(10, 25, 55),
                    TextColor3 = isSelected and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(180, 200, 255),
                }):Play()
            end
        end
    end)
    btn.MouseEnter:Connect(function() if btn.Name ~= selectedBoss then highlight(true) end end)
    btn.MouseLeave:Connect(function() if btn.Name ~= selectedBoss then highlight(false) end end)
    return btn
end

for i, bossName in ipairs(BOSSES) do MakeBossBtn(bossName, i) end
BossScroll.CanvasSize = UDim2.new(0, 0, 0, BossLayout.AbsoluteContentSize.Y + 8)
BossLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    BossScroll.CanvasSize = UDim2.new(0, 0, 0, BossLayout.AbsoluteContentSize.Y + 8)
end)

local function SetBossPanel(show)
    BossPanel.Visible = show
    local targetH = show and 130 or 0
    TweenService:Create(BossPanel, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, -12, 0, targetH)
    }):Play()
end

-- ==================== PAINEL DE SELEÇÃO DE MAESTRIA ====================
local MasteryPanel             = Instance.new("Frame", RightPanel)
MasteryPanel.Name              = "MasteryPanel"
MasteryPanel.Size              = UDim2.new(1, -12, 0, 0)
MasteryPanel.Position          = UDim2.new(0, 6, 0, 38)
MasteryPanel.BackgroundColor3  = Color3.fromRGB(6, 18, 40)
MasteryPanel.BackgroundTransparency = 0.30
MasteryPanel.BorderSizePixel   = 0
MasteryPanel.ClipsDescendants  = true
MasteryPanel.Visible           = false
MasteryPanel.ZIndex            = 12
Instance.new("UICorner", MasteryPanel).CornerRadius = UDim.new(0, 8)
local MastStroke               = Instance.new("UIStroke", MasteryPanel)
MastStroke.Thickness           = 1
MastStroke.Color               = Color3.fromRGB(0, 140, 255)
MastStroke.Transparency        = 0.4

local MastTitle                = Instance.new("TextLabel", MasteryPanel)
MastTitle.Size                 = UDim2.new(1, -10, 0, 22)
MastTitle.Position             = UDim2.new(0, 8, 0, 4)
MastTitle.BackgroundTransparency = 1
MastTitle.Text                 = "⚡  Tipo de Mastery"
MastTitle.TextColor3           = Color3.fromRGB(100, 180, 255)
MastTitle.Font                 = Enum.Font.GothamBold
MastTitle.TextSize             = 12
MastTitle.TextXAlignment       = Enum.TextXAlignment.Left
MastTitle.ZIndex               = 13

local MASTERY_TYPES = { "Fruto", "Espada", "Arma de Fogo" }
local selectedMastery = MASTERY_TYPES[1]

local MastBtnsFrame            = Instance.new("Frame", MasteryPanel)
MastBtnsFrame.Size             = UDim2.new(1, -8, 0, 62)
MastBtnsFrame.Position         = UDim2.new(0, 4, 0, 28)
MastBtnsFrame.BackgroundTransparency = 1
MastBtnsFrame.ZIndex           = 13

local MastBtnsLayout           = Instance.new("UIListLayout", MastBtnsFrame)
MastBtnsLayout.FillDirection   = Enum.FillDirection.Horizontal
MastBtnsLayout.Padding         = UDim.new(0, 4)
MastBtnsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
MastBtnsLayout.VerticalAlignment   = Enum.VerticalAlignment.Center

for _, mtype in ipairs(MASTERY_TYPES) do
    local mb                   = Instance.new("TextButton", MastBtnsFrame)
    mb.Name                    = mtype
    mb.Size                    = UDim2.new(0, 88, 0, 28)
    mb.BackgroundColor3        = Color3.fromRGB(8, 22, 50)
    mb.BackgroundTransparency  = 0.30
    mb.BorderSizePixel         = 0
    mb.Text                    = mtype
    mb.TextColor3              = Color3.fromRGB(160, 200, 255)
    mb.Font                    = Enum.Font.GothamMedium
    mb.TextSize                = 11
    mb.ZIndex                  = 14
    Instance.new("UICorner", mb).CornerRadius = UDim.new(0, 6)

    mb.MouseButton1Click:Connect(function()
        PlayClick()
        selectedMastery = mtype
        if _G.AkatCallbacks and _G.AkatCallbacks.SetMasteryType then
            _G.AkatCallbacks.SetMasteryType(mtype)
        end
        for _, ch in ipairs(MastBtnsFrame:GetChildren()) do
            if ch:IsA("TextButton") then
                local sel = ch.Name == mtype
                TweenService:Create(ch, TweenInfo.new(0.14), {
                    BackgroundColor3 = sel and Color3.fromRGB(0, 60, 140) or Color3.fromRGB(8, 22, 50),
                    TextColor3       = sel and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(160, 200, 255),
                }):Play()
            end
        end
    end)
end

local function SetMasteryPanel(show)
    MasteryPanel.Visible = show
    local targetH = show and 100 or 0
    TweenService:Create(MasteryPanel, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, -12, 0, targetH)
    }):Play()
end

-- ==================== TOGGLES CONTAINER ====================
local TogglesCont              = Instance.new("ScrollingFrame", RightPanel)
TogglesCont.Name               = "TogglesContainer"
TogglesCont.Size               = UDim2.new(1, -12, 1, -48)
TogglesCont.Position           = UDim2.new(0, 6, 0, 42)
TogglesCont.BackgroundColor3   = Color3.fromRGB(8, 16, 36)
TogglesCont.BackgroundTransparency = 0.65
TogglesCont.BorderSizePixel    = 0
TogglesCont.ClipsDescendants   = true
TogglesCont.ZIndex             = 10
TogglesCont.ScrollBarThickness = 2
TogglesCont.ScrollBarImageColor3 = Color3.fromRGB(200, 160, 0)
TogglesCont.ScrollBarImageTransparency = 0.3
TogglesCont.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
TogglesCont.AutomaticCanvasSize = Enum.AutomaticSize.None
Instance.new("UICorner", TogglesCont).CornerRadius = UDim.new(0, 8)

local ContLayout               = Instance.new("UIListLayout", TogglesCont)
ContLayout.SortOrder           = Enum.SortOrder.LayoutOrder
ContLayout.Padding             = UDim.new(0, 5)
ContLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local ContPad                  = Instance.new("UIPadding", TogglesCont)
ContPad.PaddingTop             = UDim.new(0, 7)
ContPad.PaddingBottom          = UDim.new(0, 7)
ContPad.PaddingLeft            = UDim.new(0, 4)
ContPad.PaddingRight           = UDim.new(0, 5)

local function UpdateCanvasSize()
    local h = ContLayout.AbsoluteContentSize.Y + 22
    TogglesCont.CanvasSize = UDim2.new(0, 0, 0, math.max(h, TogglesCont.AbsoluteSize.Y + 1))
end
ContLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
TogglesCont:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

-- ==================== CONFIRM OVERLAY ====================
local confirmBlur              = Instance.new("BlurEffect", Lighting)
confirmBlur.Name               = "ConfirmBlur"
confirmBlur.Size               = 0

local confirmOverlay           = Instance.new("Frame", screenGui)
confirmOverlay.Size            = UDim2.new(1, 0, 1, 0)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.55
confirmOverlay.Visible         = false
confirmOverlay.ZIndex          = 990

local confirmCard              = Instance.new("Frame", confirmOverlay)
confirmCard.Size               = UDim2.new(0, 300, 0, 130)
confirmCard.AnchorPoint        = Vector2.new(0.5, 0.5)
confirmCard.Position           = UDim2.new(0.5, 0, 0.5, 0)
confirmCard.BackgroundColor3   = Color3.fromRGB(5, 15, 35)
confirmCard.BorderSizePixel    = 0
confirmCard.ZIndex             = 995
Instance.new("UICorner", confirmCard).CornerRadius = UDim.new(0, 14)

local cStroke                  = Instance.new("UIStroke", confirmCard)
cStroke.Thickness              = 1.5
local cStrokeGrad              = Instance.new("UIGradient", cStroke)
cStrokeGrad.Color              = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 80, 200)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 160, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 80, 200)),
})

local confirmLbl               = Instance.new("TextLabel", confirmCard)
confirmLbl.Size                = UDim2.new(1, -24, 0, 22)
confirmLbl.Position            = UDim2.new(0, 12, 0, 18)
confirmLbl.BackgroundTransparency = 1
confirmLbl.TextColor3          = Color3.fromRGB(235, 235, 235)
confirmLbl.Font                = Enum.Font.GothamBold
confirmLbl.TextSize            = 13
confirmLbl.TextXAlignment      = Enum.TextXAlignment.Center
confirmLbl.Text                = UI_TEXT.ConfirmCloseTitle
confirmLbl.ZIndex              = 1000

local cSep                     = Instance.new("Frame", confirmCard)
cSep.Size                      = UDim2.new(1, -40, 0, 1)
cSep.Position                  = UDim2.new(0, 20, 0, 48)
cSep.BackgroundColor3          = Color3.fromRGB(0, 80, 180)
cSep.BackgroundTransparency    = 0.5
cSep.BorderSizePixel           = 0
cSep.ZIndex                    = 999
Instance.new("UICorner", cSep).CornerRadius = UDim.new(1, 0)

local btnYes                   = Instance.new("TextButton", confirmCard)
btnYes.Size                    = UDim2.new(0, 118, 0, 32)
btnYes.Position                = UDim2.new(0.5, -124, 0, 62)
btnYes.BackgroundColor3        = Color3.fromRGB(0, 80, 180)
btnYes.TextColor3              = Color3.fromRGB(255, 255, 255)
btnYes.Font                    = Enum.Font.GothamMedium
btnYes.TextSize                = 14
btnYes.Text                    = UI_TEXT.ConfirmBtn
btnYes.ZIndex                  = 1000
btnYes.BorderSizePixel         = 0
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 10)
local yesGrad                  = Instance.new("UIGradient", btnYes)
yesGrad.Rotation               = 90
yesGrad.Color                  = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 100, 220)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 50, 120)),
})

local btnNo                    = Instance.new("TextButton", confirmCard)
btnNo.Size                     = UDim2.new(0, 118, 0, 32)
btnNo.Position                 = UDim2.new(0.5, 6, 0, 62)
btnNo.BackgroundColor3         = Color3.fromRGB(25, 25, 30)
btnNo.TextColor3               = Color3.fromRGB(170, 170, 170)
btnNo.Font                     = Enum.Font.GothamMedium
btnNo.TextSize                 = 14
btnNo.Text                     = UI_TEXT.CancelBtn
btnNo.ZIndex                   = 1000
btnNo.BorderSizePixel          = 0
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 10)

FadeSync(confirmCard, true, 0)

-- ==================== RENDERLOOP (animações contínuas) ====================
RunService.RenderStepped:Connect(function()
    local t = os.clock()
    BGGrad.Rotation          = 90 + math.sin(t * 0.4) * 20
    cStrokeGrad.Rotation     = 90 + math.sin(t * 0.65) * 22
    uGrad.Rotation           = 45 + math.sin(t * 0.75) * 30
    avGrad.Rotation          = 45 + math.sin(t * 0.75) * 30
    badgeGrad.Rotation       = 45 + math.sin(t * 0.5)  * 18
    MainStrokeGrad.Rotation  = 45 + math.sin(t * 0.35) * 25
end)

-- ==================== NOTIFICAÇÕES ====================
local ActiveNotifs = {}
local NOTIF_DUR    = 8

local function UpdateNotifPositions()
    local currentY = -24
    for _, n in ipairs(ActiveNotifs) do
        if n and n.Parent then
            local h = n.Size.Y.Offset
            if h == 0 then h = 90 end
            TweenService:Create(n, TweenInfo.new(0.28, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                Position = UDim2.new(1, -20, 1, currentY)
            }):Play()
            currentY = currentY - (h + 10)
        end
    end
end

local function CreateNotif(title, desc)
    local holder               = Instance.new("Frame", screenGui)
    holder.AnchorPoint         = Vector2.new(1, 1)
    holder.Size                = UDim2.new(0, 320, 0, 88)
    holder.Position            = UDim2.new(1, 340, 1, -24)
    holder.BackgroundTransparency = 1
    holder.ZIndex              = 200
    holder.ClipsDescendants    = false

    local sc = Instance.new("UIScale", holder)
    sc.Scale = 0.95

    local card                 = Instance.new("Frame", holder)
    card.Size                  = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3      = Color3.fromRGB(8, 16, 36)
    card.BackgroundTransparency = 0.22
    card.BorderSizePixel       = 0
    card.ZIndex                = 201
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

    local ns                   = Instance.new("UIStroke", card)
    ns.Thickness               = 1
    ns.Color                   = Color3.fromRGB(200, 160, 0)
    ns.Transparency            = 0.45

    local accent               = Instance.new("Frame", card)
    accent.Size                = UDim2.new(0, 3, 0, 48)
    accent.Position            = UDim2.new(0, 12, 0.5, -24)
    accent.BackgroundColor3    = Color3.fromRGB(200, 160, 0)
    accent.BorderSizePixel     = 0
    accent.ZIndex              = 202
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

    local nt                   = Instance.new("TextLabel", card)
    nt.Size                    = UDim2.new(1, -56, 0, 18)
    nt.Position                = UDim2.new(0, 22, 0.5, -18)
    nt.BackgroundTransparency  = 1
    nt.Text                    = title
    nt.TextColor3              = Color3.fromRGB(240, 240, 240)
    nt.Font                    = Enum.Font.GothamBold
    nt.TextSize                = 14
    nt.TextXAlignment          = Enum.TextXAlignment.Left
    nt.ZIndex                  = 203

    local nd                   = Instance.new("TextLabel", card)
    nd.Size                    = UDim2.new(1, -56, 0, 16)
    nd.Position                = UDim2.new(0, 22, 0.5, 2)
    nd.BackgroundTransparency  = 1
    nd.Text                    = desc
    nd.TextColor3              = Color3.fromRGB(140, 160, 200)
    nd.Font                    = Enum.Font.Gotham
    nd.TextSize                = 11
    nd.TextXAlignment          = Enum.TextXAlignment.Left
    nd.TextWrapped             = true
    nd.ZIndex                  = 203

    local closebtn             = Instance.new("TextButton", card)
    closebtn.Size              = UDim2.new(0, 22, 0, 22)
    closebtn.Position          = UDim2.new(1, -30, 0, 8)
    closebtn.BackgroundColor3  = Color3.fromRGB(20, 30, 60)
    closebtn.BackgroundTransparency = 0.2
    closebtn.Text              = "✕"
    closebtn.TextColor3        = Color3.fromRGB(150, 160, 200)
    closebtn.Font              = Enum.Font.GothamBold
    closebtn.TextSize          = 11
    closebtn.ZIndex            = 205
    closebtn.BorderSizePixel   = 0
    Instance.new("UICorner", closebtn).CornerRadius = UDim.new(0, 6)

    local pbg                  = Instance.new("Frame", card)
    pbg.Size                   = UDim2.new(1, -24, 0, 3)
    pbg.Position               = UDim2.new(0, 12, 1, -8)
    pbg.BackgroundColor3       = Color3.fromRGB(20, 30, 60)
    pbg.BorderSizePixel        = 0
    pbg.ZIndex                 = 202
    pbg.ClipsDescendants       = true
    Instance.new("UICorner", pbg).CornerRadius = UDim.new(1, 0)
    local pb                   = Instance.new("Frame", pbg)
    pb.Size                    = UDim2.new(1, 0, 1, 0)
    pb.BackgroundColor3        = Color3.fromRGB(200, 160, 0)
    pb.BorderSizePixel         = 0
    pb.ZIndex                  = 203
    Instance.new("UICorner", pb).CornerRadius = UDim.new(1, 0)

    table.insert(ActiveNotifs, 1, holder)
    UpdateNotifPositions()

    TweenService:Create(holder, TweenInfo.new(0.28, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 1, -24)}):Play()
    TweenService:Create(sc, TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        for i, v in ipairs(ActiveNotifs) do if v == holder then table.remove(ActiveNotifs, i) break end end
        UpdateNotifPositions()
        TweenService:Create(holder, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Position = UDim2.new(1, 340, 1, holder.Position.Y.Offset)}):Play()
        task.delay(0.25, function() if holder.Parent then holder:Destroy() end end)
    end

    closebtn.MouseButton1Click:Connect(dismiss)
    TweenService:Create(pb, TweenInfo.new(NOTIF_DUR, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)}):Play()
    task.delay(NOTIF_DUR, dismiss)
end

-- ==================== FILTRO DE TOGGLES ====================
local filterThread = nil

local function FilterToggles(currentTab, query)
    local q = (query or ""):lower()
    local idx = 0
    for _, child in ipairs(TogglesCont:GetChildren()) do
        if child:IsA("Frame") then
            local itemTab   = child:GetAttribute("Tab") or ""
            local visible   = false
            if q ~= "" then
                local tl = child:FindFirstChild("Title")
                local dl = child:FindFirstChild("Description")
                visible = (tl and tl.Text:lower():find(q)) ~= nil
                    or (dl and dl.Text:lower():find(q)) ~= nil
            else
                visible = itemTab == currentTab
            end
            child.Visible = visible
            if visible then
                idx = idx + 1
                local t = child:FindFirstChild("Title")
                local d = child:FindFirstChild("Description")
                child.BackgroundTransparency = 1
                if t then t.TextTransparency = 1 end
                if d then d.TextTransparency = 1 end
                task.delay((idx - 1) * 0.018, function()
                    if not child.Parent then return end
                    TweenService:Create(child, TweenInfo.new(0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, -10, 0, child:GetAttribute("ItemHeight") or 58),
                        BackgroundTransparency = 0.42,
                    }):Play()
                    if t then TweenService:Create(t, TweenInfo.new(0.14), {TextTransparency = 0}):Play() end
                    if d then TweenService:Create(d, TweenInfo.new(0.14), {TextTransparency = 0}):Play() end
                end)
            end
        end
    end
    task.delay(0.05, function() pcall(UpdateCanvasSize) end)
end

-- ==================== ACTIVE BAR UPDATE ====================
local function UpdateActiveBar(animate)
    local btn = tabButtons[activeTab]
    if not btn or not sharedActiveBar.Visible then return end

    local function apply()
        local btnY    = btn.AbsolutePosition.Y
        local btnH    = btn.AbsoluteSize.Y
        local panelY  = ActiveBarCont.AbsolutePosition.Y
        if btnH == 0 then task.defer(apply); return end
        local targetY = btnY + btnH / 2 - panelY
        if animate then
            TweenService:Create(sharedActiveBar, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0, 7, 0, targetY)}):Play()
            activeBarScale.Scale = 1.08
            TweenService:Create(activeBarScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
        else
            sharedActiveBar.Position = UDim2.new(0, 7, 0, targetY)
        end
    end
    task.defer(apply)
end

-- ==================== SELECT TAB ====================
local function SelectTab(name)
    activeTab = name

    -- Mostra/esconde painéis especiais
    SetBossPanel(name == "Farm" and Configs.AutoFarmBoss)
    SetMasteryPanel(name == "Farm" and Configs.AutoFarmMastery)

    for n, btn in pairs(tabButtons) do
        local lbl  = btn:FindFirstChild("Label")
        local icon = btn:FindFirstChild("Icon")
        local sel  = n == name
        local anim = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        TweenService:Create(btn, anim, {BackgroundColor3 = sel and Color3.fromRGB(10, 30, 70) or Color3.fromRGB(5, 12, 28), BackgroundTransparency = sel and 0.45 or 1}):Play()
        if lbl  then TweenService:Create(lbl,  anim, {TextColor3 = sel and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(140, 160, 200)}):Play() end
        if icon then
            local ai = icon:FindFirstChild("AccentImage")
            if ai then TweenService:Create(ai, anim, {ImageColor3 = sel and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(140, 160, 200)}):Play() end
        end
    end

    sharedActiveBar.Visible = true
    UpdateActiveBar(true)
    TogglesCont.CanvasPosition = Vector2.new(0, 0)
    SearchBox.Text = ""
    FilterToggles(name, "")
end

-- ==================== CRIAR TAB BUTTON ====================
local tabIconIds = {
    Farm     = "rbxthumb://type=Asset&id=71234705040146&w=150&h=150",
    Combat   = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150",
    Visuals  = "rbxthumb://type=Asset&id=97681798175944&w=150&h=150",
    Player   = "rbxthumb://type=Asset&id=71234705040146&w=150&h=150",
    Settings = "rbxthumb://type=Asset&id=88409765080516&w=150&h=150",
}

local function CreateTabBtn(name)
    local btn                  = Instance.new("TextButton", TabsCont)
    btn.Name                   = name .. "Tab"
    btn.Size                   = UDim2.new(1, -16, 0, 34)
    btn.BackgroundColor3       = Color3.fromRGB(5, 12, 28)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.ZIndex                 = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local iconF                = Instance.new("Frame", btn)
    iconF.Name                 = "Icon"
    iconF.Size                 = UDim2.new(0, 14, 0, 14)
    iconF.Position             = UDim2.new(0, 13, 0.5, -7)
    iconF.BackgroundTransparency = 1
    iconF.ZIndex               = 12
    local ai                   = Instance.new("ImageLabel", iconF)
    ai.Name                    = "AccentImage"
    ai.Size                    = UDim2.new(1, 0, 1, 0)
    ai.BackgroundTransparency  = 1
    ai.Image                   = tabIconIds[name] or ""
    ai.ImageColor3             = Color3.fromRGB(140, 160, 200)
    ai.ZIndex                  = 13

    local lbl                  = Instance.new("TextLabel", btn)
    lbl.Name                   = "Label"
    lbl.Size                   = UDim2.new(1, -38, 1, 0)
    lbl.Position               = UDim2.new(0, 35, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = Color3.fromRGB(140, 160, 200)
    lbl.Font                   = Enum.Font.GothamMedium
    lbl.TextSize               = 13
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Text                   = UI_TEXT.Tabs[name] or name
    lbl.ZIndex                 = 12

    local sc = Instance.new("UIScale", btn)
    sc.Scale = 1

    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(sc, TweenInfo.new(0.07), {Scale = 0.96}):Play()
        end
    end)
    btn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function() SelectTab(name) end)
    tabButtons[name] = btn
end

-- ==================== CRIAR TOGGLE ====================
local function CreateToggle(parent, key, tab, compact)
    local h = compact and 40 or 58
    local frame                = Instance.new("Frame")
    frame.Name                 = key
    frame.Size                 = UDim2.new(1, -10, 0, h)
    frame:SetAttribute("ItemHeight", h)
    frame:SetAttribute("Tab", tab)
    frame:SetAttribute("ConfigKey", key)
    frame.BackgroundColor3     = Color3.fromRGB(8, 18, 42)
    frame.BackgroundTransparency = 0.42
    frame.ZIndex               = 11
    frame.ClipsDescendants     = true
    frame.Parent               = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

    local opt = UI_TEXT.Options[key]

    local tl                   = Instance.new("TextLabel", frame)
    tl.Name                    = "Title"
    tl.BackgroundTransparency  = 1
    tl.TextColor3              = Color3.fromRGB(210, 220, 240)
    tl.Font                    = Enum.Font.GothamBold
    tl.TextSize                = 12
    tl.TextXAlignment          = Enum.TextXAlignment.Left
    tl.Text                    = opt and opt.Title or key
    tl.ZIndex                  = 12

    if compact then
        tl.Size     = UDim2.new(1, -72, 1, 0)
        tl.Position = UDim2.fromOffset(12, 0)
        tl.TextYAlignment = Enum.TextYAlignment.Center
    else
        tl.Size     = UDim2.new(0.68, 0, 0, 18)
        tl.Position = UDim2.new(0, 12, 0, 8)

        local dl               = Instance.new("TextLabel", frame)
        dl.Name                = "Description"
        dl.Size                = UDim2.new(0.68, 0, 0, 26)
        dl.Position            = UDim2.new(0, 12, 0, 27)
        dl.BackgroundTransparency = 1
        dl.TextColor3          = Color3.fromRGB(100, 130, 190)
        dl.Font                = Enum.Font.Gotham
        dl.TextSize            = 10
        dl.TextXAlignment      = Enum.TextXAlignment.Left
        dl.TextYAlignment      = Enum.TextYAlignment.Top
        dl.TextWrapped         = true
        dl.Text                = opt and opt.Desc or ""
        dl.ZIndex              = 12
    end

    local trackW, trackH = compact and 40 or 46, compact and 20 or 22
    local track            = Instance.new("Frame", frame)
    track.Size             = UDim2.fromOffset(trackW, trackH)
    track.Position         = UDim2.new(1, -(trackW + 8), 0.5, -trackH / 2)
    track.BackgroundColor3 = Configs[key] and Color3.fromRGB(0, 80, 200) or Color3.fromRGB(25, 30, 50)
    track.ZIndex           = 11
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local cR = compact and 14 or 16
    local circle           = Instance.new("Frame", track)
    circle.Size            = UDim2.fromOffset(cR, cR)
    circle.Position        = Configs[key] and UDim2.new(1, -(cR + 2), 0.5, -cR / 2) or UDim2.new(0, 2, 0.5, -cR / 2)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.ZIndex          = 12
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local hit              = Instance.new("TextButton", frame)
    hit.Size               = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text               = ""
    hit.ZIndex             = 13
    hit.AutoButtonColor    = false

    local sc = Instance.new("UIScale", frame)
    sc.Scale = 1

    hit.MouseButton1Click:Connect(function()
        PlayClick()
        Configs[key] = not Configs[key]
        local on   = Configs[key]
        local onP  = on and UDim2.new(1, -(cR + 2), 0.5, -cR / 2) or UDim2.new(0, 2, 0.5, -cR / 2)
        local onC  = on and Color3.fromRGB(0, 80, 200) or Color3.fromRGB(25, 30, 50)
        local anim = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(circle, anim, {Position = onP}):Play()
        TweenService:Create(track,  anim, {BackgroundColor3 = onC}):Play()

        sc.Scale = 0.97
        TweenService:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()

        -- Painéis especiais animados
        if key == "AutoFarmBoss" and activeTab == "Farm" then SetBossPanel(on) end
        if key == "AutoFarmMastery" and activeTab == "Farm" then SetMasteryPanel(on) end

        if _G.AkatCallbacks and type(_G.AkatCallbacks[key]) == "function" then
            pcall(function() _G.AkatCallbacks[key](on) end)
        end
    end)
end

-- ==================== CRIAR SLIDER ====================
local function CreateSlider(parent, key, tab, minV, maxV, defV)
    local frame                = Instance.new("Frame")
    frame.Name                 = key
    frame.Size                 = UDim2.new(1, -10, 0, 40)
    frame:SetAttribute("ItemHeight", 40)
    frame:SetAttribute("Tab", tab)
    frame.BackgroundColor3     = Color3.fromRGB(8, 18, 42)
    frame.BackgroundTransparency = 0.42
    frame.ZIndex               = 11
    frame.ClipsDescendants     = true
    frame.Parent               = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

    local opt = UI_TEXT.Options[key]
    local tl                   = Instance.new("TextLabel", frame)
    tl.Name                    = "Title"
    tl.Size                    = UDim2.new(0, 110, 1, 0)
    tl.Position                = UDim2.fromOffset(12, 0)
    tl.BackgroundTransparency  = 1
    tl.TextColor3              = Color3.fromRGB(210, 220, 240)
    tl.Font                    = Enum.Font.GothamBold
    tl.TextSize                = 12
    tl.TextXAlignment          = Enum.TextXAlignment.Left
    tl.TextYAlignment          = Enum.TextYAlignment.Center
    tl.Text                    = opt and opt.Title or key
    tl.ZIndex                  = 12

    local track                = Instance.new("Frame", frame)
    track.Size                 = UDim2.new(1, -172, 0, 5)
    track.Position             = UDim2.new(0, 122, 0.5, -2.5)
    track.BackgroundColor3     = Color3.fromRGB(20, 40, 80)
    track.BorderSizePixel      = 0
    track.ZIndex               = 12
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill                 = Instance.new("Frame", track)
    fill.Size                  = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3      = Color3.fromRGB(0, 100, 220)
    fill.BorderSizePixel       = 0
    fill.ZIndex                = 13
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob                 = Instance.new("Frame", track)
    knob.Size                  = UDim2.fromOffset(12, 12)
    knob.AnchorPoint           = Vector2.new(0.5, 0.5)
    knob.Position              = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel       = 0
    knob.ZIndex                = 14
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local valLbl               = Instance.new("TextLabel", frame)
    valLbl.Size                = UDim2.fromOffset(44, 20)
    valLbl.AnchorPoint         = Vector2.new(1, 0.5)
    valLbl.Position            = UDim2.new(1, -8, 0.5, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3          = Color3.fromRGB(200, 215, 255)
    valLbl.Font                = Enum.Font.GothamBold
    valLbl.TextSize            = 14
    valLbl.TextXAlignment      = Enum.TextXAlignment.Right
    valLbl.ZIndex              = 13

    local hit                  = Instance.new("TextButton", frame)
    hit.Size                   = UDim2.new(1, -150, 0, 28)
    hit.Position               = UDim2.new(0, 116, 0.5, -14)
    hit.BackgroundTransparency = 1
    hit.Text                   = ""
    hit.AutoButtonColor        = false
    hit.ZIndex                 = 15

    local value   = math.clamp(defV or Configs[key .. "Value"] or minV, minV, maxV)
    local dragging = false

    local function SetValue(v, notify)
        value = math.clamp(v, minV, maxV)
        local alpha = (value - minV) / (maxV - minV)
        valLbl.Text = string.format("%.0f", value)
        fill.Size   = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        Configs[key .. "Value"] = value
        Configs[key] = true
        if notify and _G.AkatCallbacks and type(_G.AkatCallbacks[key]) == "function" then
            pcall(function() _G.AkatCallbacks[key](value) end)
        end
    end

    local function UpdateFromInput(input)
        local left  = track.AbsolutePosition.X
        local width = math.max(1, track.AbsoluteSize.X)
        local alpha = math.clamp((input.Position.X - left) / width, 0, 1)
        SetValue(math.floor(minV + (maxV - minV) * alpha + 0.5), true)
    end

    SetValue(value, false)

    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then UpdateFromInput(i) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

-- ==================== CRIAR ACTION (clique único) ====================
local function CreateAction(parent, key, tab)
    local frame                = Instance.new("Frame")
    frame.Name                 = key .. "Action"
    frame.Size                 = UDim2.new(1, -10, 0, 40)
    frame:SetAttribute("ItemHeight", 40)
    frame:SetAttribute("Tab", tab)
    frame.BackgroundColor3     = Color3.fromRGB(5, 20, 50)
    frame.BackgroundTransparency = 0.42
    frame.ZIndex               = 11
    frame.ClipsDescendants     = true
    frame.Parent               = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

    local opt = UI_TEXT.Options[key]
    local tl                   = Instance.new("TextLabel", frame)
    tl.Name                    = "Title"
    tl.Size                    = UDim2.new(1, -24, 1, 0)
    tl.Position                = UDim2.fromOffset(12, 0)
    tl.BackgroundTransparency  = 1
    tl.TextColor3              = Color3.fromRGB(200, 220, 255)
    tl.Font                    = Enum.Font.GothamBold
    tl.TextSize                = 12
    tl.TextXAlignment          = Enum.TextXAlignment.Left
    tl.TextYAlignment          = Enum.TextYAlignment.Center
    tl.Text                    = opt and opt.Title or key
    tl.ZIndex                  = 12

    local overlay              = Instance.new("Frame", frame)
    overlay.Size               = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel    = 0
    overlay.ZIndex             = 12
    Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 7)

    local hit                  = Instance.new("TextButton", frame)
    hit.Size                   = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text                   = ""
    hit.AutoButtonColor        = false
    hit.ZIndex                 = 13

    local active = false
    local function pulse(on)
        if on == active then return end; active = on
        TweenService:Create(overlay, TweenInfo.new(on and 0.07 or 0.15), {BackgroundTransparency = on and 0.78 or 1}):Play()
    end

    hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then pulse(true) end end)
    hit.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then pulse(false) end end)
    hit.MouseLeave:Connect(function() pulse(false) end)

    hit.MouseButton1Click:Connect(function()
        PlayClick(); pulse(false)
        if _G.AkatCallbacks and type(_G.AkatCallbacks[key]) == "function" then
            task.spawn(function() pcall(_G.AkatCallbacks[key], true) end)
        end
    end)
end

-- ==================== SEARCH FILTER ====================
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if filterThread then task.cancel(filterThread) end
    filterThread = task.delay(0.08, function()
        filterThread = nil
        FilterToggles(activeTab, SearchBox.Text)
    end)
end)

-- ==================== RESPONSIVE WINDOW ====================
local function ApplyWindowSize(animate)
    local n, e = GetResponsiveUISizes()
    local target = isExpanded and e or n
    if animate then TweenService:Create(mainWrapper, TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = target}):Play()
    else mainWrapper.Size = target end
    task.defer(function() ClampMainWrapper(mainWrapper) end)
end

local vpConn
local function BindViewport()
    if vpConn then vpConn:Disconnect() end
    local cam = workspace.CurrentCamera
    if not cam then return end
    vpConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if not mainWrapper.Parent then return end
        ApplyWindowSize(UIState == "OPEN")
        ClampMainWrapper(mainWrapper)
        UpdateActiveBar(false)
        task.defer(UpdateCanvasSize); task.defer(UpdateTabsCanvas)
    end)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindViewport)
BindViewport()

-- ==================== BOTÕES DO TOPO ====================
ExpBtn.MouseButton1Click:Connect(function()
    PlayClick()
    if UIState ~= "OPEN" then return end
    isExpanded = not isExpanded
    ApplyWindowSize(true)
end)

local function TopBtnEffects(btn, icon, hoverColor)
    local sc = Instance.new("UIScale", btn); sc.Scale = 1
    btn.MouseEnter:Connect(function() TweenService:Create(icon, TweenInfo.new(0.13), {ImageColor3 = hoverColor}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(icon, TweenInfo.new(0.13), {ImageColor3 = TOP_COLOR}):Play(); TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end)
    btn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then TweenService:Create(sc, TweenInfo.new(0.07), {Scale = 0.92}):Play() end end)
    btn.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end end)
end

TopBtnEffects(MinBtn,   MinIcon,   Color3.fromRGB(255, 255, 255))
TopBtnEffects(ExpBtn,   ExpIcon,   Color3.fromRGB(255, 215, 0))
TopBtnEffects(CloseBtn, CloseIc,   Color3.fromRGB(80, 160, 255))

-- ==================== STATE MACHINE ====================
local isTransitioning = false

SetUIState = function(newState)
    if UIState == newState or isTransitioning then return end
    isTransitioning = true
    local dur  = 0.25
    local anim = TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if newState == "OPEN" then
        mainWrapper.Visible = true
        local n = select(1, GetResponsiveUISizes())
        mainWrapper.Size = n
        FadeSync(mainWrapper, true, 0)
        FadeSync(mainWrapper, false, dur)
        local n2, e = GetResponsiveUISizes()
        local tw = TweenService:Create(mainWrapper, anim, {Size = isExpanded and e or n2})
        tw:Play()
        tw.Completed:Connect(function()
            UIState = "OPEN"; isTransitioning = false
            SelectTab(activeTab)
            FilterToggles(activeTab, SearchBox.Text)
            UpdateActiveBar(false)
        end)

    elseif newState == "MINIMIZED" or newState == "CLOSED" then
        FadeSync(mainWrapper, true, dur)
        local n = select(1, GetResponsiveUISizes())
        local tw = TweenService:Create(mainWrapper, anim, {Size = n})
        tw:Play()
        tw.Completed:Connect(function()
            mainWrapper.Visible = false; UIState = newState; isTransitioning = false
        end)
    else
        isTransitioning = false
    end
end

-- ==================== CONFIRMAÇÃO ====================
local function ToggleConfirm(show)
    isConfirmOpen = show
    local dur = 0.22
    if show then
        mainWrapper.Visible = false; FloatBtn.Visible = false
        confirmOverlay.Visible = true
        TweenService:Create(confirmBlur, TweenInfo.new(dur), {Size = 24}):Play()
        local sc2 = confirmCard:FindFirstChildOfClass("UIScale")
        if sc2 then sc2:Destroy() end
        local sc2 = Instance.new("UIScale", confirmCard); sc2.Scale = 0.88
        TweenService:Create(sc2, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        FadeSync(confirmCard, false, dur)
    else
        TweenService:Create(confirmBlur, TweenInfo.new(dur), {Size = 0}):Play()
        FadeSync(confirmCard, true, dur)
        task.delay(dur + 0.05, function()
            if not isConfirmOpen then
                confirmOverlay.Visible = false
                if UIState == "OPEN" then mainWrapper.Visible = true end
                FloatBtn.Visible = true
            end
        end)
    end
end

MinBtn.MouseButton1Click:Connect(function() PlayClick(); SetUIState("MINIMIZED") end)
CloseBtn.MouseButton1Click:Connect(function() PlayClick(); ToggleConfirm(true) end)
btnNo.MouseButton1Click:Connect(function() ToggleConfirm(false) end)
btnYes.MouseButton1Click:Connect(function()
    TweenService:Create(confirmBlur, TweenInfo.new(0.2), {Size = 0}):Play()
    FadeSync(confirmCard, true, 0.2)
    task.wait(0.2)
    pcall(function() confirmBlur:Destroy() end)
    if _G.AkatUIShutdown then pcall(_G.AkatUIShutdown) end
end)

btnYes.MouseEnter:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(0, 120, 255)}):Play() end)
btnYes.MouseLeave:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(0, 80, 180)}):Play() end)
btnNo.MouseEnter:Connect(function()  TweenService:Create(btnNo,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 40, 50)}):Play() end)
btnNo.MouseLeave:Connect(function()  TweenService:Create(btnNo,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}):Play() end)

-- ==================== CRIAR ABAS ====================
CreateTabBtn("Farm")
CreateTabBtn("Combat")
CreateTabBtn("Visuals")
CreateTabBtn("Player")
CreateTabBtn("Settings")

-- ==================== CRIAR TOGGLES / SLIDERS POR ABA ====================

-- Farm
CreateToggle(TogglesCont, "AutoFarmLevel",   "Farm")
CreateToggle(TogglesCont, "AutoFarmBoss",    "Farm")
CreateToggle(TogglesCont, "AutoFarmMastery", "Farm")
CreateToggle(TogglesCont, "AutoFarmBones",   "Farm")
CreateToggle(TogglesCont, "AutoFarmChests",  "Farm")
CreateToggle(TogglesCont, "AutoQuest",       "Farm", true)
CreateToggle(TogglesCont, "MobAura",         "Farm", true)
CreateSlider(TogglesCont, "AuraRadius",      "Farm", 5, 80, 20)
CreateToggle(TogglesCont, "AutoSkills",      "Farm", true)

-- Combat
CreateToggle(TogglesCont, "InstantKill", "Combat")
CreateToggle(TogglesCont, "AntiKill",   "Combat")
CreateToggle(TogglesCont, "NoClip",     "Combat", true)

-- Visuals
CreateToggle(TogglesCont, "ESP",     "Visuals")
CreateToggle(TogglesCont, "NameESP", "Visuals", true)
CreateToggle(TogglesCont, "Tracer",  "Visuals", true)
CreateToggle(TogglesCont, "XRay",    "Visuals", true)

-- Player
CreateSlider(TogglesCont, "Speed",     "Player", 16, 250, 16)
CreateSlider(TogglesCont, "JumpPower", "Player", 50, 300, 50)
CreateToggle(TogglesCont, "AntiFling",   "Player", true)
CreateToggle(TogglesCont, "Invisibility","Player", true)
CreateAction(TogglesCont, "TpPlayer",   "Player")

-- Settings
CreateToggle(TogglesCont, "AntiAFK",  "Settings", true)
CreateToggle(TogglesCont, "AntiKick", "Settings", true)
CreateToggle(TogglesCont, "ChatLog",  "Settings", true)

-- ==================== INTRO ANIMADO ====================
local function RunIntro()
    local Blur             = Instance.new("BlurEffect", Lighting)
    Blur.Name              = "IntroBlur"; Blur.Size = 0

    local IntroF           = Instance.new("Frame", screenGui)
    IntroF.Size            = UDim2.new(1, 0, 1, 0)
    IntroF.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    IntroF.BackgroundTransparency = 1
    IntroF.ZIndex          = 500

    local Mask             = Instance.new("Frame", IntroF)
    Mask.AnchorPoint       = Vector2.new(0.5, 0.5)
    Mask.Position          = UDim2.new(0.5, 0, 0.5, -10)
    Mask.Size              = UDim2.new(0, 440, 0, 44)
    Mask.BackgroundTransparency = 1
    Mask.ClipsDescendants  = true
    Mask.ZIndex            = 501

    local IntroTxt         = Instance.new("TextLabel", Mask)
    IntroTxt.Size          = UDim2.new(1, 0, 1, 0)
    IntroTxt.Position      = UDim2.new(0, 0, 1, 0)
    IntroTxt.BackgroundTransparency = 1
    IntroTxt.Font          = Enum.Font.GothamBold
    IntroTxt.TextSize      = 28
    IntroTxt.RichText      = true
    IntroTxt.Text          = UI_TEXT.Intro
    IntroTxt.ZIndex        = 502

    local IntroLine        = Instance.new("Frame", IntroF)
    IntroLine.AnchorPoint  = Vector2.new(0.5, 0.5)
    IntroLine.Position     = UDim2.new(0.5, 0, 0.5, 18)
    IntroLine.Size         = UDim2.new(0, 0, 0, 2)
    IntroLine.BackgroundColor3 = Color3.fromRGB(200, 160, 0)
    IntroLine.BorderSizePixel = 0
    IntroLine.BackgroundTransparency = 1
    IntroLine.ZIndex       = 503
    Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

    TweenService:Create(IntroF, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(Blur,   TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 22}):Play()
    task.wait(0.1)
    TweenService:Create(IntroTxt,  TweenInfo.new(0.80, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
    task.wait(0.18)
    TweenService:Create(IntroLine, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 280, 0, 2)}):Play()
    task.wait(1.5)
    TweenService:Create(IntroTxt,  TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),  {TextTransparency = 1}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),  {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
    task.wait(0.28)
    TweenService:Create(IntroF, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur,   TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
    task.wait(0.28)

    RegTrans(mainWrapper)
    for _, d in ipairs(mainWrapper:GetDescendants()) do RegTrans(d) end

    local nSize = select(1, GetResponsiveUISizes())
    mainWrapper.Size    = nSize
    mainWrapper.Visible = true
    FloatBtn.Visible    = true
    UIState             = "OPEN"
    isTransitioning     = false

    local ms = Instance.new("UIScale", mainWrapper); ms.Name = "IntroScale"; ms.Scale = 0.86
    FadeSync(mainWrapper, true, 0)
    FadeSync(mainWrapper, false, 0.32)

    local openTw = TweenService:Create(ms, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    openTw:Play()

    FloatBtn.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(FloatBtn, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()

    CreateNotif("AKATSUKI SCRIPTS", "Blox Fruits Script iniciado! Bem-vindo, " .. player.DisplayName .. ".")

    openTw.Completed:Connect(function()
        ms:Destroy()
        pcall(function() Blur:Destroy() end)
        IntroF:Destroy()
        task.defer(function() SelectTab("Farm") end)
    end)
end

-- ==================== SHUTDOWN HOOK ====================
_G.AkatUIShutdown = function()
    pcall(function() if screenGui and screenGui.Parent then screenGui:Destroy() end end)
end

RunIntro()
