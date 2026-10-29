local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local workspace = cloneref(Workspace)
local Players = cloneref(Players)
local RunService = cloneref(RunService)
local Lighting = cloneref(game:GetService("Lighting"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local HttpService = cloneref(game:GetService("HttpService"))
local GuiService = cloneref(game:GetService("GuiService"))
local GuiInset = GuiService:GetGuiInset()
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Mobile Detection
local UserInputService = cloneref(game:GetService("UserInputService"))
local isMobile = UserInputService.TouchEnabled

-- Screen Constants (775x360)
local SCREEN_WIDTH = 775
local SCREEN_HEIGHT = 360
local SAFE_MARGIN = 10

local cheat = {
    alive = true,
    connections = {
        heartbeats = {},
        renderstepped = {},
        heartbeat_idx = {},
        renderstepped_idx = {}
    },
    drawings = {},
    direct_connections = {},
    mobile_mode = isMobile,
    ui_open = true,
    rightshift_pressed = false,
    touch_camera_active = false,
    last_touch_pos = Vector2.new(0, 0),
}

-- Utility Functions
local function register_loop(list, index, func)
    local n = #list + 1
    list[n] = func
    index[func] = n
    local obj = {}
    function obj:Disconnect()
        if not func then return end
        local i = index[func]
        index[func] = nil
        if i then
            local last = #list
            local moved = list[last]
            list[i] = moved
            if moved and moved ~= func then index[moved] = i end
            list[last] = nil
        end
        func = nil
    end
    return obj
end

cheat.utility = {
    track_connection = function(connection)
        if connection then
            cheat.direct_connections[#cheat.direct_connections + 1] = connection
        end
        return connection
    end,
    
    new_heartbeat = function(func)
        return register_loop(cheat.connections.heartbeats, cheat.connections.heartbeat_idx, func)
    end,
    
    new_renderstepped = function(func)
        return register_loop(cheat.connections.renderstepped, cheat.connections.renderstepped_idx, func)
    end,
    
    new_drawing = function(class, properties)
        if not Drawing then return nil end
        local drawing = Drawing.new(class)
        for prop, value in pairs(properties) do
            pcall(function() drawing[prop] = value end)
        end
        cheat.drawings[drawing] = true
        return drawing
    end,
    
    remove_drawing = function(drawing)
        if not drawing then return end
        cheat.drawings[drawing] = nil
        pcall(function() drawing:Remove() end)
    end,
}

-- Mobile UI Panel (Compact, 775x360 optimized)
local mobile_ui = {}

function mobile_ui:Create()
    -- Main Panel - Compact
    local panel = Instance.new("ScreenGui")
    panel.Name = "pin.retaV2_mobile"
    panel.ResetOnSpawn = false
    panel.IgnoreGuiInset = true
    panel.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Top Menu Bar (compact)
    local menu_bar = Instance.new("Frame")
    menu_bar.Name = "MenuBar"
    menu_bar.Size = UDim2.new(0, 200, 0, 40)
    menu_bar.Position = UDim2.new(0, SAFE_MARGIN, 0, SAFE_MARGIN)
    menu_bar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    menu_bar.BorderColor3 = Color3.fromRGB(45, 45, 45)
    menu_bar.BorderSizePixel = 1
    menu_bar.Parent = panel
    
    -- Toggle Menu Button
    local toggle_btn = Instance.new("TextButton")
    toggle_btn.Name = "ToggleBtn"
    toggle_btn.Size = UDim2.new(0, 80, 0, 35)
    toggle_btn.Position = UDim2.new(0, 5, 0, 2)
    toggle_btn.BackgroundColor3 = Color3.fromRGB(120, 110, 180)
    toggle_btn.TextColor3 = Color3.new(1, 1, 1)
    toggle_btn.TextSize = 12
    toggle_btn.Font = Enum.Font.GothamBold
    toggle_btn.Text = "Menu"
    toggle_btn.BorderSizePixel = 0
    toggle_btn.Parent = menu_bar
    
    -- RightShift Button (Mobile replacement)
    local rshift_btn = Instance.new("TextButton")
    rshift_btn.Name = "RShiftBtn"
    rshift_btn.Size = UDim2.new(0, 110, 0, 35)
    rshift_btn.Position = UDim2.new(0, 85, 0, 2)
    rshift_btn.BackgroundColor3 = Color3.fromRGB(100, 80, 160)
    rshift_btn.TextColor3 = Color3.new(1, 1, 1)
    rshift_btn.TextSize = 11
    rshift_btn.Font = Enum.Font.GothamBold
    rshift_btn.Text = "Activate"
    rshift_btn.BorderSizePixel = 0
    rshift_btn.Parent = menu_bar
    
    -- Main Menu (collapsible)
    local menu_frame = Instance.new("ScrollingFrame")
    menu_frame.Name = "MenuFrame"
    menu_frame.Size = UDim2.new(0, 180, 0, 280)
    menu_frame.Position = UDim2.new(0, SAFE_MARGIN, 0, 55)
    menu_frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    menu_frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    menu_frame.BorderSizePixel = 1
    menu_frame.ScrollBarThickness = 6
    menu_frame.CanvasSize = UDim2.new(0, 0, 0, 600)
    menu_frame.Visible = true
    menu_frame.Parent = panel
    
    -- Cosmetic Label
    local title_label = Instance.new("TextLabel")
    title_label.Name = "Title"
    title_label.Size = UDim2.new(0, 170, 0, 25)
    title_label.Position = UDim2.new(0, 5, 0, 5)
    title_label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title_label.TextColor3 = Color3.fromRGB(120, 110, 180)
    title_label.TextSize = 12
    title_label.Font = Enum.Font.GothamBold
    title_label.Text = "pin.reta V2 MOBILE"
    title_label.BorderSizePixel = 0
    title_label.Parent = menu_frame
    
    -- FOV Control (Critical - detached from camera)
    local fov_label = Instance.new("TextLabel")
    fov_label.Size = UDim2.new(0, 170, 0, 20)
    fov_label.Position = UDim2.new(0, 5, 0, 35)
    fov_label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    fov_label.TextColor3 = Color3.new(1, 1, 1)
    fov_label.TextSize = 11
    fov_label.Font = Enum.Font.Gotham
    fov_label.Text = "FOV: 70"
    fov_label.BorderSizePixel = 0
    fov_label.Parent = menu_frame
    
    local fov_slider = Instance.new("Frame")
    fov_slider.Name = "FOVSlider"
    fov_slider.Size = UDim2.new(0, 170, 0, 12)
    fov_slider.Position = UDim2.new(0, 5, 0, 56)
    fov_slider.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    fov_slider.BorderSizePixel = 0
    fov_slider.Parent = menu_frame
    
    local fov_fill = Instance.new("Frame")
    fov_fill.Size = UDim2.new(0, 100, 1, 0)
    fov_fill.BackgroundColor3 = Color3.fromRGB(120, 110, 180)
    fov_fill.BorderSizePixel = 0
    fov_fill.Parent = fov_slider
    
    -- Sensitivity Control (Independent from touch)
    local sens_label = Instance.new("TextLabel")
    sens_label.Size = UDim2.new(0, 170, 0, 20)
    sens_label.Position = UDim2.new(0, 5, 0, 72)
    sens_label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    sens_label.TextColor3 = Color3.new(1, 1, 1)
    sens_label.TextSize = 11
    sens_label.Font = Enum.Font.Gotham
    sens_label.Text = "Sensitivity: 1.0"
    sens_label.BorderSizePixel = 0
    sens_label.Parent = menu_frame
    
    local sens_slider = Instance.new("Frame")
    sens_slider.Size = UDim2.new(0, 170, 0, 12)
    sens_slider.Position = UDim2.new(0, 5, 0, 93)
    sens_slider.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    sens_slider.BorderSizePixel = 0
    sens_slider.Parent = menu_frame
    
    local sens_fill = Instance.new("Frame")
    sens_fill.Size = UDim2.new(0, 85, 1, 0)
    sens_fill.BackgroundColor3 = Color3.fromRGB(120, 110, 180)
    sens_fill.BorderSizePixel = 0
    sens_fill.Parent = sens_slider
    
    -- Crosshair Settings
    local cross_label = Instance.new("TextLabel")
    cross_label.Size = UDim2.new(0, 170, 0, 20)
    cross_label.Position = UDim2.new(0, 5, 0, 110)
    cross_label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    cross_label.TextColor3 = Color3.fromRGB(120, 110, 180)
    cross_label.TextSize = 11
    cross_label.Font = Enum.Font.GothamBold
    cross_label.Text = "CROSSHAIR"
    cross_label.BorderSizePixel = 0
    cross_label.Parent = menu_frame
    
    local cross_toggle = Instance.new("TextButton")
    cross_toggle.Size = UDim2.new(0, 80, 0, 22)
    cross_toggle.Position = UDim2.new(0, 5, 0, 132)
    cross_toggle.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    cross_toggle.TextColor3 = Color3.new(1, 1, 1)
    cross_toggle.TextSize = 10
    cross_toggle.Font = Enum.Font.Gotham
    cross_toggle.Text = "ON"
    cross_toggle.BorderSizePixel = 0
    cross_toggle.Parent = menu_frame
    
    -- Crosshair Style
    local style_label = Instance.new("TextLabel")
    style_label.Size = UDim2.new(0, 80, 0, 18)
    style_label.Position = UDim2.new(0, 85, 0, 132)
    style_label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    style_label.TextColor3 = Color3.new(1, 1, 1)
    style_label.TextSize = 10
    style_label.Font = Enum.Font.Gotham
    style_label.Text = "Style: V"
    style_label.BorderSizePixel = 0
    style_label.Parent = menu_frame
    
    -- Info Label
    local info_label = Instance.new("TextLabel")
    info_label.Size = UDim2.new(0, 170, 0, 60)
    info_label.Position = UDim2.new(0, 5, 0, 158)
    info_label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    info_label.TextColor3 = Color3.new(1, 1, 1)
    info_label.TextSize = 9
    info_label.Font = Enum.Font.Gotham
    info_label.Text = "MOBILE BUILD\n775x360\nTouch to aim\nSwipe to move\nTap Activate"
    info_label.TextWrapped = true
    info_label.BorderSizePixel = 0
    info_label.Parent = menu_frame
    
    -- Rendering Crosshair (Always center, independent)
    local crosshair_drawing = cheat.utility.new_drawing("Line", {
        From = Vector2.new(SCREEN_WIDTH / 2 - 15, SCREEN_HEIGHT / 2),
        To = Vector2.new(SCREEN_WIDTH / 2 + 15, SCREEN_HEIGHT / 2),
        Color = Color3.fromRGB(120, 255, 120),
        Thickness = 2,
        Transparency = 0.8,
        Visible = true
    })
    
    local crosshair_v = cheat.utility.new_drawing("Line", {
        From = Vector2.new(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - 15),
        To = Vector2.new(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 + 15),
        Color = Color3.fromRGB(120, 255, 120),
        Thickness = 2,
        Transparency = 0.8,
        Visible = true
    })
    
    return {
        panel = panel,
        menu_frame = menu_frame,
        toggle_btn = toggle_btn,
        rshift_btn = rshift_btn,
        fov_label = fov_label,
        fov_fill = fov_fill,
        sens_label = sens_label,
        sens_fill = sens_fill,
        cross_toggle = cross_toggle,
        style_label = style_label,
        info_label = info_label,
        crosshair_h = crosshair_drawing,
        crosshair_v = crosshair_v
    }
end

-- Initialize Mobile UI
local ui = mobile_ui:Create()

-- Mobile Input Handling
local camera_pitch = 0
local camera_yaw = 0
local current_fov = 70
local current_sensitivity = 1.0
local crosshair_enabled = true

-- Touch Input Events
cheat.utility.track_connection(UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
    if gameProcessed or not cheat.mobile_mode then return end
    
    local current_pos = touch.Position
    local delta = current_pos - cheat.last_touch_pos
    
    -- Only rotate camera if touch is on right side of screen (aiming zone)
    if current_pos.X > SCREEN_WIDTH * 0.5 then
        camera_yaw = camera_yaw - delta.X * 0.003 * current_sensitivity
        camera_pitch = math.clamp(camera_pitch - delta.Y * 0.003 * current_sensitivity, -math.pi/2 + 0.01, math.pi/2 - 0.01)
        
        -- Apply to camera
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                Camera.CFrame = root.CFrame * CFrame.Angles(camera_pitch, camera_yaw, 0) * CFrame.new(0, 0, 0)
            end
        end
        
        cheat.touch_camera_active = true
    end
    
    cheat.last_touch_pos = current_pos
end))

cheat.utility.track_connection(UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
    cheat.touch_camera_active = false
end))

-- RightShift Button Emulation
ui.rshift_btn.MouseButton1Click:Connect(function()
    cheat.rightshift_pressed = not cheat.rightshift_pressed
    ui.rshift_btn.BackgroundColor3 = cheat.rightshift_pressed 
        and Color3.fromRGB(200, 50, 50) 
        or Color3.fromRGB(100, 80, 160)
end)

-- Toggle Menu
ui.toggle_btn.MouseButton1Click:Connect(function()
    cheat.ui_open = not cheat.ui_open
    ui.menu_frame.Visible = cheat.ui_open
end)

-- FOV Slider (independent from touch)
local fov_min, fov_max = 30, 120
ui.fov_fill.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local dragging_fov = true
        
        local function update_fov(input)
            if dragging_fov then
                local mouse_pos = Mouse.X
                local slider_pos = ui.fov_fill.Parent.AbsolutePosition.X
                local slider_size = ui.fov_fill.Parent.AbsoluteSize.X
                local relative = math.clamp((mouse_pos - slider_pos) / slider_size, 0, 1)
                
                current_fov = math.floor(fov_min + (fov_max - fov_min) * relative)
                ui.fov_fill.Size = UDim2.new(relative, 0, 1, 0)
                ui.fov_label.Text = "FOV: " .. current_fov
                
                Camera.FieldOfView = current_fov
            end
        end
        
        local function stop_dragging()
            dragging_fov = false
        end
        
        cheat.utility.track_connection(UserInputService.InputChanged:Connect(update_fov))
        cheat.utility.track_connection(UserInputService.InputEnded:Connect(function(input2, gp2)
            if input2.UserInputType == Enum.UserInputType.MouseButton1 then
                stop_dragging()
            end
        end))
    end
end)

-- Sensitivity Slider (independent from touch)
local sens_min, sens_max = 0.3, 3.0
ui.sens_fill.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local dragging_sens = true
        
        local function update_sens(input)
            if dragging_sens then
                local mouse_pos = Mouse.X
                local slider_pos = ui.sens_fill.Parent.AbsolutePosition.X
                local slider_size = ui.sens_fill.Parent.AbsoluteSize.X
                local relative = math.clamp((mouse_pos - slider_pos) / slider_size, 0, 1)
                
                current_sensitivity = math.floor((sens_min + (sens_max - sens_min) * relative) * 10) / 10
                ui.sens_fill.Size = UDim2.new(relative, 0, 1, 0)
                ui.sens_label.Text = "Sensitivity: " .. current_sensitivity
            end
        end
        
        local function stop_dragging()
            dragging_sens = false
        end
        
        cheat.utility.track_connection(UserInputService.InputChanged:Connect(update_sens))
        cheat.utility.track_connection(UserInputService.InputEnded:Connect(function(input2, gp2)
            if input2.UserInputType == Enum.UserInputType.MouseButton1 then
                stop_dragging()
            end
        end))
    end
end)

-- Crosshair Toggle
ui.cross_toggle.MouseButton1Click:Connect(function()
    crosshair_enabled = not crosshair_enabled
    ui.cross_toggle.BackgroundColor3 = crosshair_enabled 
        and Color3.fromRGB(50, 150, 50) 
        or Color3.fromRGB(150, 50, 50)
    ui.cross_toggle.Text = crosshair_enabled and "ON" or "OFF"
    ui.crosshair_h.Visible = crosshair_enabled
    ui.crosshair_v.Visible = crosshair_enabled
end)

-- Crosshair Rendering Loop (Always center, never moves)
cheat.utility.new_renderstepped(function()
    if ui.crosshair_h and ui.crosshair_v and crosshair_enabled then
        local center_x = SCREEN_WIDTH / 2
        local center_y = SCREEN_HEIGHT / 2
        local cross_size = 15
        
        ui.crosshair_h.From = Vector2.new(center_x - cross_size, center_y)
        ui.crosshair_h.To = Vector2.new(center_x + cross_size, center_y)
        
        ui.crosshair_v.From = Vector2.new(center_x, center_y - cross_size)
        ui.crosshair_v.To = Vector2.new(center_x, center_y + cross_size)
        
        ui.crosshair_h.Visible = true
        ui.crosshair_v.Visible = true
    end
end)

-- Cleanup on death
cheat.utility.track_connection(LocalPlayer.CharacterAdded:Connect(function()
    camera_pitch = 0
    camera_yaw = 0
end))

-- Keep alive signal
while cheat.alive do
    task.wait(5)
end
