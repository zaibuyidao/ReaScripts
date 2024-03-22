-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

require('core')
CONFIG = require('config')
style = CONFIG.ui.global.style

local colorConfig = CONFIG.ui.global.color[style]
if colorConfig then
    theme_font = colorConfig.theme_font
    theme_brd = colorConfig.theme_brd
end
theme_toggle = CONFIG.ui.global.theme_toggle

-- Simple Element Class
local Element = {}
function Element:new(x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz, norm_val,norm_val2,new_title)
    local elm = {}
    elm.def_xywh = {x,y,w,h,fnt_sz} -- its default coord,used for Zoom etc
    elm.x, elm.y, elm.w, elm.h = x, y, w, h
    elm.r, elm.g, elm.b, elm.a = r, g, b, a
    elm.lbl, elm.fnt, elm.fnt_sz  = lbl, fnt, fnt_sz
    elm.norm_val = norm_val
    elm.norm_val2 = norm_val2
    elm.new_title = new_title

    setmetatable(elm, self)
    self.__index = self 
    return elm
end

-- Function for Child Classes(args = Child,Parent Class)
function extended(Child, Parent)
    setmetatable(Child,{__index = Parent}) 
end

-- Element Class Methods(Main Methods)
function Element:update_xywh()
    if not Z_w or not Z_h then return end -- return if zoom not defined
    self.x, self.w = math.ceil(self.def_xywh[1]* Z_w) , math.ceil(self.def_xywh[3]* Z_w) -- upd x,w
    self.y, self.h = math.ceil(self.def_xywh[2]* Z_h) , math.ceil(self.def_xywh[4]* Z_h) -- upd y,h
    if self.fnt_sz then --fix it!--
        self.fnt_sz = math.max(9,self.def_xywh[5]* (Z_w+Z_h)/2)
        self.fnt_sz = math.min(22,self.fnt_sz)
    end       
end

function Element:pointIN(p_x, p_y)
    return p_x >= self.x and p_x <= self.x + self.w and p_y >= self.y and p_y <= self.y + self.h
end

function Element:mouseIN()
    return gfx.mouse_cap&1==0 and self:pointIN(gfx.mouse_x,gfx.mouse_y)
end

function Element:mouseDown()
    return gfx.mouse_cap&1==1 and self:pointIN(mouse_ox,mouse_oy)
end

function Element:mouseUp() -- its actual for sliders and knobs only!
    return gfx.mouse_cap&1==0 and self:pointIN(mouse_ox,mouse_oy)
end

function Element:mouseClick()
    return gfx.mouse_cap&1==0 and last_mouse_cap&1==1 and
    self:pointIN(gfx.mouse_x,gfx.mouse_y) and self:pointIN(mouse_ox,mouse_oy)         
end

function Element:mouseR_Down()
    return gfx.mouse_cap&2==2 and self:pointIN(mouse_ox,mouse_oy)
end

function Element:mouseM_Down()
    return gfx.mouse_cap&64==64 and self:pointIN(mouse_ox,mouse_oy)
end

function Element:draw_frame()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    -- gfx.rect(x, y, w, h, false) -- frame1 直角
    gfx.roundrect(x, y, w-1, h-1, 3, false) -- frame2 圆弧形
end

function Element:mouseRClick()
    return gfx.mouse_cap & 2 == 0 and last_mouse_cap & 2 == 2 and
    self:pointIN(gfx.mouse_x, gfx.mouse_y) and self:pointIN(mouse_ox, mouse_oy)         
end
-- Create Element Child Classes(Button,Slider,Knob)

local Button = {}
local Knob = {}
local Slider = {}
local Rng_Slider = {}
local Frame = {}
local CheckBox = {}
local Textbox = {}
extended(Button,     Element)
extended(Knob,       Element)
extended(Slider,     Element)
extended(Rng_Slider, Element)
extended(Frame,      Element)
extended(CheckBox,   Element)
extended(Textbox,    Element)

-- Create Slider Child Classes(V_Slider,H_Slider)

local H_Slider = {}
local V_Slider = {}
extended(H_Slider, Slider)
extended(V_Slider, Slider)

-- Button Class Methods

function Button:draw_body()
    gfx.rect(self.x,self.y,self.w,self.h, true) -- draw btn body
end

function Button:draw_lbl()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = x+(w-lbl_w)/2; gfx.y = y+(h-lbl_h)/2
    -- 设置字体颜色
    local font_color = theme_font -- 使用配置中的颜色
    gfx.set(font_color[1], font_color[2], font_color[3], font_color[4])
    gfx.drawstr(self.lbl)
end

function Button:draw()
    self:update_xywh() -- 更新 xywh（如果窗口改变）
    local r, g, b, a = self.r, self.g, self.b, self.a
    local fnt, fnt_sz = self.fnt, self.fnt_sz

    -- 获取鼠标状态
    if self:mouseIN() then a = a - 0.5 end
    if self:mouseDown() then a = a + 0.5 end
    if self:mouseClick() and self.onClick then self.onClick() end
    if self:mouseRClick() and self.onRClick then self.onRClick() end

    if theme_toggle then
        -- 定义边框宽度
        local border_width = 1

        gfx.set(r, g, b, a)
        self:draw_frame() -- 绘制框架

        -- 绘制按钮主体
        gfx.set(r, g, b, a) -- 设置主体颜色
        gfx.rect(self.x + border_width, self.y + border_width, self.w - 2 * border_width, self.h - 2 * border_width, true) -- 主体
    else
        -- 绘制按钮主体
        gfx.set(r, g, b, a) -- 设置主体颜色
        gfx.rect(self.x, self.y, self.w, self.h, true)

        -- 鼠标悬停时绘制边框
        if self:mouseIN() then
            gfx.set(theme_brd[1], theme_brd[2], theme_brd[3], a) -- 设置悬停边框颜色
            gfx.rect(self.x, self.y, self.w, self.h, false) -- 边框
        end
    end

    -- 绘制标签
    gfx.set(0, 0, 0, 1) -- 设置标签颜色
    gfx.setfont(1, fnt, fnt_sz) -- 设置标签字体
    self:draw_lbl() -- 绘制标签
end

-- CheckBox Class Methods
function CheckBox:set_norm_val()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local val = self.norm_val      -- current value,check
    local menu_tb = self.norm_val2 -- checkbox table
    local menu_str = ""
       for i=1, #menu_tb,1 do
         if i~=val then menu_str = menu_str..menu_tb[i].."|"
                   else menu_str = menu_str.."!"..menu_tb[i].."|" -- add check
         end
       end
    gfx.x = self.x; gfx.y = self.y + self.h
    local new_val = gfx.showmenu(menu_str)        -- show checkbox menu
    if new_val>0 then self.norm_val = new_val end -- change check(!)
end

function CheckBox:draw_body()
    gfx.rect(self.x,self.y,self.w,self.h, true) -- draw checkbox body
end

function CheckBox:draw_lbl()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = x-lbl_w-5; gfx.y = y+(h-lbl_h)/2
    -- 设置字体颜色
    local font_color = theme_font -- 使用配置中的颜色
    gfx.set(font_color[1], font_color[2], font_color[3], font_color[4])
    gfx.drawstr(self.lbl) -- draw checkbox label
end

function CheckBox:draw_val()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local val = self.norm_val2[self.norm_val]
    local val_w, val_h = gfx.measurestr(val)
    gfx.x = x+5; gfx.y = y+(h-val_h)/2
    -- 设置字体颜色
    local font_color = theme_font -- 使用配置中的颜色
    gfx.set(font_color[1], font_color[2], font_color[3], font_color[4])
    gfx.drawstr(val) -- draw checkbox val
end

function CheckBox:draw()
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz

    -- Get mouse state
    -- in element
    if self:mouseIN() then a=a-0.5 end
    -- in elm L_down
    if self:mouseDown() then a=a-0.5 end
    -- in elm L_up(released and was previously pressed) --
    if self:mouseClick() then self:set_norm_val()
       if self:mouseClick() and self.onClick then self.onClick() end
    end

    -- Draw btn frame and body
    gfx.set(theme_brd[1], theme_brd[2], theme_brd[3], theme_brd[4])
    self:draw_frame()

    -- Draw ch_box body, frame
    --self:draw_frame()   -- frame
    gfx.set(r,g,b,a)    -- set body color
    self:draw_body()    -- body

    -- Draw label
    gfx.set(0, 0, 0, 1)   -- set label,val color -- (0.7, 0.9, 0.4, 1) 下拉框颜色
    gfx.setfont(1, fnt, fnt_sz) -- set label,val fnt
    self:draw_lbl()             -- draw lbl
    self:draw_val()             -- draw val
end

-- Frame Class Methods
function Frame:draw()
   self:update_xywh() -- Update xywh(if wind changed)
   local r,g,b,a  = self.r,self.g,self.b,self.a
   if self:mouseIN() then a=a+0.1 end
   gfx.set(r,g,b,a)   -- set frame color
   self:draw_frame()  -- draw frame
end

--  Textbox Class Methods
function Textbox:draw_body()
    gfx.rect(self.x, self.y, self.w, self.h, true) -- draw textbox body
end

function Textbox:draw_label()
    -- 绘制标题
    local title_w, title_h = gfx.measurestr(self.new_title)
    gfx.x = self.x - title_w - 5
    gfx.y = self.y + (self.h - title_h) / 2  -- 标题位于文本框上方
    -- 设置字体颜色
    local font_color = theme_font -- 使用配置中的颜色
    gfx.set(font_color[1], font_color[2], font_color[3], font_color[4])
    gfx.drawstr(self.new_title)

    -- 绘制文本
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = self.x + (self.w - lbl_w) / 2
    gfx.y = self.y + (self.h - lbl_h) / 2
    gfx.drawstr(self.lbl)

end

--gActiveLayer = 1
function Textbox:draw()
    self:update_xywh() -- Update xywh(if wind changed)
    --self:update_zoom() -- check and update if window resized
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    --if (self.tab & (1 << gActiveLayer)) == 0 and self.tab ~= 0 then return end

    if self:mouseIN() then a=a-0.5 end
    if self:mouseDown() then a=a-0.5 end

    if self:mouseRClick() and self.onRClick then self.onRClick() end -- if mouseR clicked and released, execute onRClick()
    if self:mouseClick() and self.onClick then self.onClick() end -- if mouse clicked and released, execute onClick()
    
    -- Draw btn frame and body
    gfx.set(theme_brd[1], theme_brd[2], theme_brd[3], theme_brd[4])
    self:draw_frame()

    --self:draw_frame()
    gfx.set(r,g,b,a) -- set the drawing colour for the e.Element
    self:draw_body()

    gfx.set(original_r, original_g, original_b, original_a)

    -- Draw label
    gfx.set(0, 0, 0, 1) -- set label color
    gfx.setfont(1, fnt, fnt_sz) -- set label font
    self:draw_label()
end

-- 导出类
return {
    Button = Button,
    Knob = Knob,
    Slider = Slider,
    Rng_Slider = Rng_Slider,
    Frame = Frame,
    CheckBox = CheckBox,
    Textbox = Textbox
}