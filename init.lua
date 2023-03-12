local time_to_explode = minetest.settings:get('count_down_time') or 10

attach_bomb = {}
attach_bomb.detacher_items = {
    'default:shovel_stone',
    'default:shovel_steel',
    'default:shovel_mese',
    'default:shovel_diamond'
}

function check_in(name) 
    if name == nil then return false end -- cause nil isnt in the list :P
    for i, n in pairs(attach_bomb.detacher_items) do
        if name == n then return true end
    end
    return false
end

minetest.register_entity("attach_bomb:bomb_ent", {
    initial_properties = {
        visual='sprite',
        image='attach_bombs_blink_on.png',
        textures ={'attach_bombs_blink_on.png'},
        visual_size = {x = .5,y=.5}
    },
    on_punch = function(self, puncher) 
        if ctf_teams.get(puncher:get_player_name()) ~= ctf_teams.get(self.attacher:get_player_name()) and check_in(puncher:get_wielded_item().get_name(puncher:get_wielded_item())) then self.object:remove() 
        else explode(self.object, 10)  end

    end,--larger radius for trigger
    on_step = function(self,dtime,moveresult)
        local obj = self.object

        if not self.blink_c then self.blink_c = 1 end
        if self.blink_t ==nil then self.blink_t = 0 end
        if self.blink_tex == nil then self.blink_tex = true end -- to support not self.blink_tex
        self.blink_t = self.blink_t +dtime

        if self.blink_t >= self.blink_c then
            self.blink_t = 0
            self.blink_c = self.blink_c-(self.blink_c/time_to_explode)
            if self.blink_tex then
                self.object:set_properties({textures = {'attach_bombs_blink_off.png'} })
            else
                minetest.sound_play("timer_beep", {
                pos = pos,
                gain = 1.0,
                max_hear_distance = 8,
                })
                self.object:set_properties({textures = {'attach_bombs_blink_on.png'} })
            end
            
        
            self.blink_tex = not self.blink_tex
        end
        if not self.clock then self.clock = time_to_explode end -- explode in 20 secs
        if self.timer == nil then self.timer = 0 end
        self.timer = self.timer + dtime
        if self.timer > self.clock then
            explode(self.object,5)
        end
    end

})
minetest.register_craftitem('attach_bomb:bomb_item', {
    name='Attachable Bomb',
    desciption='Left-Click(hit) a player to attach',
    image='attach_bombs_inv.png',
    on_use= function(item_stack,user, pointed_thing)
        if minetest.is_player(pointed_thing.ref) ~= true then return nil end
        if ctf_teams.get(user:get_player_name()) == ctf_teams.get(pointed_thing.ref:get_player_name()) then minetest.chat_send_player(user:get_player_name(), "You can't attach bomb to team members!") return nil end -- dont attach bombs to team members
        
        local pos = minetest.get_pointed_thing_position(pointed_thing)
        if pos==nil then pos = {x=0,y=0,z=0} end
        local ent = minetest.add_entity(pos, 'attach_bomb:bomb_ent')
        ent:set_attach(pointed_thing.ref,'',{x=0,y=20,z=0})
        ent:get_luaentity().attacher=user
        minetest.log('action','[Attach_Bomb] '..ent:get_luaentity().attacher:get_player_name()..' attached a bomb to '..pointed_thing.ref:get_player_name())
        item_stack:take_item()
        return item_stack
    end
})


local function check_hit(pos1, pos2, obj)
	local ray = minetest.raycast(pos1, pos2, true, false)
	local hit = ray:next()

	while hit and hit.type == "node" and vector.distance(pos1, hit.under) <= 1.6 do
		hit = ray:next()
	end

	if hit and hit.type == "object" and hit.ref == obj then
		return true
	end
end


function explode(obj,radius)
    local pos = obj:get_pos()
    pos.y = pos.y+1
    local attacher = 'unkown'
    if obj:get_luaentity().attacher ~= nil then
        local attacher = obj:get_luaentity().attacher:get_player_name()
    end
    local plyrs = minetest.get_objects_inside_radius(pos, 1)

    
    minetest.add_particlespawner({
        amount = 20,
        time = 0.5,
        minpos = vector.subtract(pos, radius),
        maxpos = vector.add(pos, radius),
        minvel = {x = 0, y = 5, z = 0},
        maxvel = {x = 0, y = 7, z = 0},
        minacc = {x = 0, y = 1, z = 0},
        maxacc = {x = 0, y = 1, z = 0},
        minexptime = 0.3,
        maxexptime = 0.6,
        minsize = 7,
        maxsize = 10,
        collisiondetection = true,
        collision_removal = false,
        vertical = false,
        texture = "grenades_smoke.png",
    })

    minetest.add_particle({
        pos = pos,
        velocity = {x=0, y=0, z=0},
        acceleration = {x=0, y=0, z=0},
        expirationtime = 0.3,
        size = 30,
        collisiondetection = false,
        collision_removal = false,
        object_collision = false,
        vertical = false,
        texture = "grenades_boom.png",
        glow = 10
    })

    minetest.sound_play("grenades_explode", {
        pos = pos,
        gain = 1.0,
        max_hear_distance = 64,
    })

    for _, v in pairs(minetest.get_objects_inside_radius(pos, radius)) do
        if v:is_player() and v:get_hp() > 0 and v:get_properties().pointable then
            local footpos = vector.offset(v:get_pos(), 0, 0.1, 0)
            local headpos = vector.offset(v:get_pos(), 0, v:get_properties().eye_height, 0)
            local footdist = vector.distance(pos, footpos)
            local headdist = vector.distance(pos, headpos)
            local target_head = false

            if footdist >= headdist then
                target_head = true
            end

            local hit_pos1 = check_hit(pos, target_head and headpos or footpos, v)

            -- Check the closest distance, but if that fails try targeting the farther one
            if hit_pos1 or check_hit(pos, target_head and footpos or headpos, v) then
                if obj:get_luaentity().attacher == nil then obj:remove() return false end
                v:punch(obj:get_luaentity().attacher, 1, {
                    punch_interval = 1,
                    damage_groups = {
                        gernade = 1,
                        fleshy = 52 - ( (radius/3) * (target_head and headdist or footdist) ) -- should kill a knight one shot... might have to big of a radius though :P
                    }
                }, nil)
            end
        end
    end
    minetest.log("action", "[Attach_Bomb] A Tag Bomb attached by " .. attacher .." explodes at " .. minetest.pos_to_string(vector.round(pos)))
	obj:remove()
end

