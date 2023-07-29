--[[
    ownerxfer aka "Transfer Prop Ownership"
    very stupid simple script for transferring entities between players

    Copyright (C) 2023 by rikka

    Permission to use, copy, modify, and/or distribute this software for any
    purpose with or without fee is hereby granted.

    THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
    WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
    MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
    ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
    WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
    ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
    OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
]]--

ownerxfer = ownerxfer or {}

-- we use this same string in all our hooks and net messages
local ident = "rikka_transfer_ownership"
-- name of the ulib permission
local ulib_override = "ownerxfer override"

if ULib then
    -- ulib version
    function ownerxfer.canOverride(ply)
        return ply:query(ulib_override)
    end
else
    -- this can be overridden in your scripts
    function ownerxfer.canOverride(ply)
        return ply:IsSuperAdmin()
    end
end

if SERVER then

    if not CPPI then
        print("WARNING: no CPPI-compatible prop protection addon found!")
        print("ownerxfer will be totally useless!")
    end

    if ULib then
        ULib.ucl.registerAccess(ulib_override, ULib.ACCESS_SUPERADMIN, "Permits transferring ownership of props not owned by the user", "Prop Protection")
    end

    -- pool our network message, of course
    util.AddNetworkString(ident)

    -- net receiver for a transfer request from a client
    net.Receive(ident, function (len, ply)
        -- make sure we have a CPPI PP
        if not CPPI then return end

        -- read args from client
        local tgt = net.ReadEntity()
        local ent = net.ReadEntity()

        -- validate them
        local owner = ent:CPPIGetOwner()
        local valid = IsValid(tgt) and tgt:IsPlayer() and IsValid(ent)
        local owned = owner == ply

        -- discover all constrained entities
        local constrained = constraint.GetAllConstrainedEntities(ent)

        -- validate them too
        if not ownerxfer.canOverride(ply) then
            for k, v in pairs(constrained) do
                if not IsValid(v) then
                    valid = false
                elseif v:CPPIGetOwner() ~= ply then
                    owned = false
                end
            end
        end

        if (owned or ownerxfer.canOverride(ply)) and valid then
            --print("transferring ownership of", ent, "and constrained entities from", owner, "to", tgt, "on request of", ply)
            ent:CPPISetOwner(tgt)
            for k, v in pairs(constrained) do
                v:CPPISetOwner(tgt)
            end

            -- notify client of success
            net.Start(ident)
            net.WriteBool(true)
            net.WriteString("Ownership transferred!")
            net.Send(ply)

            -- notify receiver too
            net.Start(ident)
            net.WriteBool(true)
            net.WriteString(ply:Nick() .. " has given you ownership of something.")
            net.Send(tgt)
        else
            -- notify client of failure
            net.Start(ident)
            net.WriteBool(false)
            if not owned then
                net.WriteString("The entity or something it is constrained to is not owned by you.")
            else
                net.WriteString("Transfer request denied by server.")
            end
            net.Send(ply)
        end
    end)

else

    -- notify doohickey
    net.Receive(ident, function ()
        local ok = net.ReadBool()
        local msg = net.ReadString()
        if ok then
            notification.AddLegacy(msg, NOTIFY_GENERIC, 5)
            surface.PlaySound("buttons/button24.wav")
        else
            notification.AddLegacy(msg, NOTIFY_ERROR, 5)
            surface.PlaySound("buttons/button10.wav")
        end
    end)

    -- property thingy
    properties.Add(ident, {
        MenuLabel = "Transfer Ownership",
        Order = 9999999,
        MenuIcon = "icon16/key.png",
        PrependSpacer = true,
        Filter = function (self, ent, ply)
            -- need CPPI-compatible prop protection and a valid ent
            if not CPPI or not IsValid(ent) then return false end
            -- if we own this prop, show the option
            return ownerxfer.canOverride(LocalPlayer()) or ent:CPPIGetOwner() == ply
        end,
        MenuOpen = function(self, option, ent, tr)
            -- add submenu options for each player currently connected
            local submenu = option:AddSubMenu()
            for k, v in ipairs(player.GetAll()) do
                if not ownerxfer.canOverride(LocalPlayer()) and v == LocalPlayer() then continue end
                local tgt = v
                submenu:AddOption(v:Nick() .. " (" .. v:SteamID() .. ")", function ()
                    -- send a message to the server requesting transfer
                    net.Start(ident)
                    net.WriteEntity(tgt)
                    net.WriteEntity(ent)
                    net.SendToServer()
                end)
            end
        end,
        Action = function () end
    })

end