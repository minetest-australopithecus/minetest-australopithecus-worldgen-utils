--[[
Copyright (c) 2015, Robert 'Bobby' Zenz
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]


--- RampPlacer is an object that allows to place ramps in the world.
RampPlacer = {}


--- Creates a new instance of RampPlacer.
--
-- @return A new instance of RampPlacer.
function RampPlacer:new()
	local instance = {
		air = nil,
		air_likes = {},
		inner_corner_template = {
			is_corner = true,
			key = "inner_corner",
			-- f f f
			-- f   f
			-- n f n
			masks = {
				{ false, false, false, false, false, false, true, false },
				{ false, false, false, false, true, false, false, false }
			}
		},
		nodes = {},
		outer_corner_template = {
			is_corner = true,
			key = "outer_corner",
			-- f f n
			-- f   t
			-- n t t
			mask = { false, false, nil, true, true, true, nil, false }
		},
		ramp_template = {
			is_corner = false,
			key = "ramp",
			-- n f n
			-- f   f
			-- n t n
			masks = {
				{ nil, false, nil, false, nil, true, nil, false },
				{ nil, false, nil, true, nil, true, nil, true }
			}
		}
	}
	
	setmetatable(instance, self)
	self.__index = self
	
	return instance
end


--- Equals function for the mask values.
--
-- @param actual The atual value, generated from the map.
-- @param mask The mask value, from the templates.
-- @return true if the values equal.
function RampPlacer.mask_value_equals(actual, mask)
	if mask == nil then
		return true
	end

	return actual == mask
end

--- Checks if the given node is "air".
--
-- @param node The node to check.
-- @return true if the node is air.
function RampPlacer:is_air(node)
	if self.air == nil then
		self.air = minetest.get_content_id("air")
	end
	
	return node == self.air or self.air_likes[node] == true
end

--- Places a ramp here if possible.
--
-- @param x The x coordinate.
-- @param z The z coordinate.
-- @param y The y coordinate.
-- @param manipulator The manipulator.
-- @param template The ramp template to use.
-- @param node_info The node information to use.
-- @param node_mask The mask of the node.
-- @param below_air If the node is below air.
-- @param above_air If the node is above air.
-- @return true If a ramp is placed.
function RampPlacer:place_ramp(x, z, y, manipulator, template, node_info, node_mask, below_air, above_air)
	local node_ramp = node_info[template.key]
	
	if node_ramp == nil then
		return false
	end
	
	local start_index = -1
	
	if template.masks ~= nil then
		for index = 1, #template.masks, 1 do
			local mask_index = arrayutil.index(node_mask, template.masks[index], RampPlacer.mask_value_equals, 2)
			
			if mask_index >= 0 then
				start_index = mask_index
			end
		end
	else
		start_index = arrayutil.index(node_mask, template.mask, self.mask_value_equals, 2)
	end
	
	if start_index >= 0 then
		local facedir = 0;
		local axis = rotationutil.POS_Y
		local rotation = rotationutil.ROT_0
		
		if below_air then
			if start_index == 1 then
				rotation = rotationutil.ROT_180
			elseif start_index == 3 then
				rotation = rotationutil.ROT_90
			elseif start_index == 5 then
				rotation = rotationutil.ROT_0
			elseif start_index == 7 then
				rotation = rotationutil.ROT_270
			end
		elseif above_air then
			axis = rotationutil.NEG_Y
			
			if template.is_corner then
				if start_index == 1 then
					rotation = rotationutil.ROT_90
				elseif start_index == 3 then
					rotation = rotationutil.ROT_180
				elseif start_index == 5 then
					rotation = rotationutil.ROT_270
				elseif start_index == 7 then
					rotation = rotationutil.ROT_0
				end
			else
				if start_index == 1 then
					rotation = rotationutil.ROT_180
				elseif start_index == 3 then
					rotation = rotationutil.ROT_270
				elseif start_index == 5 then
					rotation = rotationutil.ROT_0
				elseif start_index == 7 then
					rotation = rotationutil.ROT_90
				end
			end
		end
		
		local facedir = rotationutil.facedir(axis, rotation)
		
		manipulator:set_node(x, z, y, node_ramp, facedir)
		
		return true
	end
	
	return false
end

--- Allows to register nodes that are treated like air.
--
-- @param node The node to register as air like.
function RampPlacer:register_air_like(node)
	node = nodeutil.get_id(node)
	
	self.air_likes[node] = true
end

--- Registers a ramp with this RampPlacer.
--
-- @param node The base node.
-- @param ramp_node The ramp node.
-- @param inner_corner_node The inner corner node.
-- @param outer_corner_node The outer corner node.
-- @param floor If ramps should appear on the floor.
-- @param ceiling If ramps should appear on the ceiling.
function RampPlacer:register_ramp(node, ramp_node, inner_corner_node, outer_corner_node, floor, ceiling)
	node = nodeutil.get_id(node)
	ramp_node = nodeutil.get_id(ramp_node)
	inner_corner_node = nodeutil.get_id(inner_corner_node)
	outer_corner_node = nodeutil.get_id(outer_corner_node)
	
	self.nodes[node] = {
		ceiling = ceiling,
		floor = floor,
		inner_corner = inner_corner_node,
		node = node,
		ramp = ramp_node,
		outer_corner = outer_corner_node
	}
end

--- Places ramps in the given area.
--
-- @param manipulator The MapManipulator to use.
-- @param minp The minimum point.
-- @param maxp The maximum point.
function RampPlacer:run(manipulator, minp, maxp)
	for y = minp.y - 1, maxp.y + 1, 1 do
		for x = minp.x - 1, maxp.x + 1, 1 do
			for z = minp.z - 1, maxp.z + 1, 1 do
				self:run_on_node(manipulator, x, z, y)
			end
		end
	end
end

--- Places a ramp (or not) on the given location.
-- 
-- @param manipulator The MapManipulator to use.
-- @param x The x coordinate.
-- @param z The z coordinate.
-- @param y The y coordinate.
function RampPlacer:run_on_node(manipulator, x, z, y)
	local node = manipulator:get_node(x, z, y)
	local node_info = self.nodes[node]
	
	if node_info == nil then
		return
	end
	
	local above_air = self:is_air(manipulator:get_node(x, z, y - 1))
	local below_air = self:is_air(manipulator:get_node(x, z, y + 1))
	
	if node_info.param_floor ~= nil and not node_info.param_floor then
		below_air = false;
	end
	
	if node_info.param_ceiling ~= nil and not node_info.param_ceiling then
		above_air = false;
	end
	
	local ramp_placed = false
	
	-- Either have air below or above it, but not both and not neither.
	if above_air ~= below_air then
		--  -- ?- +-
		--  -?    +?
		--  -+ ?+ ++
		local node_mask = {
			self:is_air(manipulator:get_node(x - 1, z - 1, y)),
			self:is_air(manipulator:get_node(x, z - 1, y)),
			self:is_air(manipulator:get_node(x + 1, z - 1, y)),
			self:is_air(manipulator:get_node(x + 1, z, y)),
			self:is_air(manipulator:get_node(x + 1, z + 1, y)),
			self:is_air(manipulator:get_node(x, z + 1, y)),
			self:is_air(manipulator:get_node(x - 1, z + 1, y)),
			self:is_air(manipulator:get_node(x - 1, z, y))
		}
		
		if not self:place_ramp(x, z, y, manipulator, self.ramp_template, node_info, node_mask, below_air, above_air) then
			if not self:place_ramp(x, z, y, manipulator, self.inner_corner_template, node_info, node_mask, below_air, above_air) then
				if not self:place_ramp(x, z, y, manipulator, self.outer_corner_template, node_info, node_mask, below_air, above_air) then
					if not ramp_placed and node ~= node_info.node then
						manipulator:set_node(x, z, y, node_info.node, nil)
					end
				end
			end
		end
	end
end

