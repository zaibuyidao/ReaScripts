-- NoIndex: true
local ListView = {}
function ListView.new(props)
	props.uiState = props.uiState or {}
	props.data = props.data or {}
	props.firstIndex = props.firstIndex or 1
	props.listeners = props.listeners or {}
	return setmetatable(props, { __index = ListView})
end

function ListView:getPageSize()
	local size = math.tointeger(math.floor(self.height / self.itemHeight))
	if size < 0 then return 0 end
	return size
end

function ListView:fitFirstIndex()
	local maxScroll = #self.data - self:getPageSize() + 1
	if self.firstIndex > maxScroll then self.firstIndex = maxScroll end
	if self.firstIndex < 1 then self.firstIndex = 1 end
end

function ListView:draw()
	local pageSize = self:getPageSize()
	self.viewHolders = self.viewHolders or {}
	self:fitFirstIndex()

	for i= #self.viewHolders + 1, pageSize do
		table.insert(self.viewHolders, self.onCreateViewHolder(self, self.x, self.y + (i-1) * self.itemHeight))
	end

	for i=1, pageSize do
		local dataIndex = i + self.firstIndex - 1
		if dataIndex <= #self.data then
			self.onBindData(self, i, dataIndex)
		end
	end
	
	local removeCount = #self.viewHolders - math.min(pageSize, #self.data)
	for i=1, removeCount do
		self.onViewHolderRemoved(table.remove(self.viewHolders, #self.viewHolders))
	end
end

function ListView:scroll(amount)
	self.firstIndex = self.firstIndex + math.floor(amount)
	self:fitFirstIndex()
	self:draw()
	if self.listeners.scroll then
		for f in pairs(self.listeners.scroll) do
			f(self)
		end
	end
end

function ListView:jump(target)
	self.firstIndex = target
	self:fitFirstIndex()
	self:draw()
	if self.listeners.scroll then
		for f in pairs(self.listeners.scroll) do
			f(self)
		end
	end
end


function ListView:addScrollListener(f)
	self.listeners.scroll = self.listeners.scroll or {}
	self.listeners.scroll[f] = true
end

return ListView