#!/usr/bin/lua
--
--  StarBound Mod Installer
--  Copyright (C) 2014  Seth Phillips
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--

local lapp = require('pl.lapp')
local pldir = require('pl.dir')
local plpath = require('pl.path')

local VERSION = 0.7

local args = lapp [[
    Adds or removes mods from Starbound
    -a,--add    add one or more mods
    -r,--remove remove one or more mods
    -l,--list   list installed mods
]]

-- get the path to the starbound dir
local SBDIR_PATH = os.getenv('HOME') .. '/.local/share/Steam/SteamApps/common/Starbound/'


-- takes a string thought to contain a specific key, returns the key's value or nil if the key can't be found
function getjsonvalue(rawstring, key)
    if (not rawstring) or (not key) then
        return nil
    end
    local value = string.match(rawstring, '^%s+["\']' .. key ..'["\']%s*:%s*["\'](.+)["\'][,]?%s*$')
    return value
end

-- takes a string to be used with the shell, returns an escaped string
function escape(string)
    string = string.gsub(string, '`', '\\`')
    string = string.gsub(string, '"', '\\"')
    string = string.gsub(string, '!', '\\!')
    string = string.gsub(string, '%$', '\\$')
    string = string.gsub(string, '%c', '\\%1')
    string = string.gsub(string, '^', '"')
    string = string.gsub(string, '$', '"')
    return string
end

-- takes the path to the modinfo file, returns the mod's (hopefully) pretty name or nil if it can't find a name
function getmodname(modinfo_path)
    if not modinfo_path then
        error('modinfo_path is nil!')
    end
    local modinfo, errmsg = io.open(modinfo_path, 'r')
    if not modinfo then
        error(errmsg)
    end

    for line in modinfo:lines() do
        if string.match(line, 'name') then
            pretty_name = getjsonvalue(line, 'name')
        elseif string.match(line, 'displayName') then
            prettier_name = getjsonvalue(line, 'displayName')
        end
    end
    io.close(modinfo)

    -- try for a pretty name
    local name = prettier_name
    if not name then
        -- fall back to a potentially less pretty name
        name = pretty_name
    end
    if not name then
        -- fall back to the dirname (should never happen)
        io.stderr:write(modinfo_path .. ' is missing a name!\n')
        name = plpath.basename(plpath.dirname(modinfo_path))
    end
    -- ensure these don't interfere
    pretty_name = nil
    prettier_name = nil
    line = nil
    return name
end

-- returns a table listing all modfiles found
function findmodinfo(dir)
    if not dir or type(dir) ~= 'string' then
        return nil
    end

    local modfile_table = {}
    for root, dirs, files in pldir.walk(dir, false, false) do
        for key, value in pairs(files) do
            if string.match(value, '.+%.modinfo$') then
                modfile_table[#modfile_table+1] = plpath.abspath(root .. '/' .. value)
            end
        end
    end
    return modfile_table
end

-- takes a dir that's thought to contain .world files, returns a table containing the absolute paths to the .world files or nil if it can't find any
function findworldfiles(dir)
    if not dir or type(dir) ~= 'string' then
        return nil
    end

    local worldfile_table = {}
    for root, dirs, files in pldir.walk(dir, false, false) do
        for key, value in pairs(files) do
            if string.match(value, '.+%.world$') then
                worldfile_table[#worldfile_table+1] = plpath.abspath(root .. '/' .. value)
            end
        end
    end
    if #worldfile_table ~= 0 then
        return worldfile_table
    else
        return nil
    end
end

-- returns a string with the location the file was extracted to
function extract(file)
    if not file then
        error('file is nil!')
    end

    local targetdir, extension = plpath.splitext(plpath.basename(file))
    local exit, errmsg = plpath.mkdir(targetdir)
    if not exit then
        if errmsg == 'File exists' then
            if plpath.isdir(targetdir) then
                local exit, errmsg = pldir.rmtree(targetdir)
                if not exit then
                    io.stderr:write('Failed to delete ' .. targetdir .. ' : ' .. errmsg .. '\n')
                end
            else
                local exit, errmsg = os.remove(targetdir)
                if not exit then
                    io.stderr:write('Failed to delete ' .. targetdir .. ' : ' .. errmsg .. '\n')
                end
            end
        else
        error(errmsg)
        end
    end

    if not os.execute() then
        io.stderr:write('You don\'t have a shell?\n')
        os.exit(false)
    end
    if extension == '.zip' then
        if not os.execute('which unzip >/dev/null') then
            io.stderr:write('"which unzip" failed!\n')
            os.exit(false)
        elseif not os.execute('unzip -qqUU -d ' .. escape(targetdir) .. ' ' .. escape(file)) then
            io.stderr:write('failed to unzip ' .. file .. '!\n')
            return nil
        else
            return targetdir
        end
    elseif extension == '.rar' then
        if not os.execute('which unrar >/dev/null') then
            io.stderr:write('"which unrar" failed!\n')
            os.exit(false)
        elseif not os.execute('unrar -inul x ' .. escape(file) .. ' ' .. escape(targetdir)) then
            io.stderr:write('failed to unrar ' .. file .. '!\n')
            return nil
        else
            return targetdir
        end
    elseif extension == '.7z' then
        if not os.execute('which 7z >/dev/null') then
            io.stderr:write('"which 7z" failed!\n')
            os.exit(false)
        elseif not os.execute('7z x ' .. escape(file) .. ' -o' .. escape(targetdir) .. ' >/dev/null') then
            io.stderr:write('failed to un-7z ' .. file .. '!\n')
            return nil
        else
            return targetdir
        end
    elseif not plpath.exists(filename) then
        io.stderr:write('This file doesn\'t exist: ' .. file ..'\n')
        return nil
    else
        io.stderr:write('I don\'t know how to handle this file: ' .. file .. '\n')
    end
end

-- takes a path to a archive and the path to the starbound dir, returns true if successful nil if not
function add(file_path, sbdir)
    local oldpwd = plpath.currentdir()
    tmpdir = os.getenv('XDG_RUNTIME_DIR') .. '/' .. 'starbound-mods'
    plpath.mkdir(tmpdir)
    plpath.chdir(tmpdir)
    local dir = extract(plpath.normpath(oldpwd .. '/' .. file_path))
    if not dir then
        plpath.chdir(oldpwd)
        return nil
    end
    local modinfos = findmodinfo(dir)
    local worldfiles = findworldfiles(dir)
    -- key is useless, file_path is the path to the modinfo
    for key, modinfo_path in pairs(modinfos) do
        -- if the file contains '\r' then we replace it with '\n'
        local modinfo = io.open(modinfo_path)
        local modinfo_content = modinfo:read('*a')
        if string.match(modinfo_content, '\r') then
            modinfo = io.open(modinfo_path, 'w+')
            local fixed_modinfo = string.gsub(modinfo_content, '\r', '\n')
            modinfo, errmsg = modinfo:write(fixed_modinfo)
            if not modinfo then
                error(errmsg)
            end
            modinfo:flush()
        end
        io.close(modinfo)

        local modname = getmodname(modinfo_path)
        io.stdout:write('Adding ' .. modname .. '\n')
        local installed_path = ""
        local installed_dir = string.gsub(string.gsub(escape(modname), '%s', ''), '\\`', '')
        if modname then
            installed_path = sbdir .. 'mods/' .. string.gsub(installed_dir, '"', '')
        else
            installed_path = sbdir .. 'mods/' .. plpath.basename(plpath.dirname(modinfo))
        end
        if worldfiles then
            for number, worldfile in ipairs(worldfiles) do
                local exit = pldir.movefile(escape(worldfile), sbdir .. 'universe')
                if not exit then
                    io.stderr:write('Failed to move ' .. worldfile)
                end
            end
        end
        if plpath.exists(installed_path) then
            if plpath.isdir(installed_path) then
                local exit, errmsg = pldir.rmtree(installed_path)
                if not exit then
                    io.stderr:write('Failed to delete ' .. installed_path .. ' : ' .. errmsg .. '\n')
                    plpath.chdir(oldpwd)
                    return nil
                end
            else
                local exit, errmsg = os.remove(installed_path)
                if not exit then
                    io.stderr:write('Failed to delete ' .. installed_path .. ' : ' .. errmsg .. '\n')
                    plpath.chdir(oldpwd)
                    return nil
                end
            end

            -- make the final path be starbound/mods/$prettyname
            if modname then
                local exit, errmsg = pldir.movefile(plpath.dirname(modinfo_path), installed_dir)
                if not exit then
                    io.stderr:write(errmsg .. '\n')
                end
                local exit, errmsg = pldir.movefile(installed_dir, sbdir .. 'mods/')
                if not exit then
                    io.stderr:write(errmsg .. '\n')
                end
                plpath.chdir(oldpwd)
                return true
            else
                local exit, errmsg = pldir.movefile(plpath.dirname(modinfo_path), sbdir .. 'mods/')
                if not exit then
                    io.stderr:write(errmsg .. '\n')
                end
                plpath.chdir(oldpwd)
                return true
            end
        else
            if modname then
                local exit, errmsg = pldir.movefile(plpath.dirname(modinfo_path), installed_dir)
                if not exit then
                    io.stderr:write(errmsg .. '\n')
                end
                local exit, errmsg = pldir.movefile(installed_dir, sbdir .. 'mods/')
                if not exit then
                    io.stderr:write(errmsg .. '\n')
                end
                plpath.chdir(oldpwd)
                return true
            else
                local exit, errmsg = pldir.movefile(plpath.dirname(modinfo_path), sbdir .. 'mods/')
                if not exit then
                    io.stderr:write(errmsg .. '\n')
                end
                plpath.chdir(oldpwd)
                return true
            end
        end
    end
    return nil
end

-- takes the path to the starbound install, the name of the dir to remove and the name of the mod being removed
function remove(sbdir, mod_dirname, modname)
    local mod_dir = sbdir .. 'mods/'
    plpath.chdir(mod_dir)

    if plpath.exists(mod_dirname) then
        io.stdout:write('Removing ' .. modname .. '\n')
        if plpath.isdir(mod_dirname) then
            local exit, errmsg = pldir.rmtree(plpath.abspath(mod_dirname))
            if not exit  then
                io.stderr:write('Failed to delete ' .. modname .. " : " .. errmsg .. '\n')
            end
        else
            local exit, errmsg = os.remove(mod_dirname)
            if not exit then
                io.stderr:write('Failed to delete ' .. modname .. " : " .. errmsg .. '\n')
            end
        end
    else
        io.stderr:write(modname .. ' isn\'t installed.\n')
    end
end

-- takes the path to the starbound mods dir, returns at table containing the modnames and the full path to the mod's directory
function listmods(mod_dir)
    if not plpath.isdir(mod_dir) then
        error('you need to run Starbound before running this', 0)
    end
    local modinfos = findmodinfo(mod_dir)
    local list = {}
    for key, value in pairs(modinfos) do
        local mod_name = getmodname(value)
        list[mod_name] = plpath.dirname(value)
    end
    return list
end

-- handle the arguments
if (args.add == true and args.list == true) or (args.add == true and args.remove == true) or (args.remove == true and args.list == true) then
    lapp.error('error: too many commands')
elseif (args.add == true) or (args.remove == true) then
    local i = 1
    local installed_mods = listmods(SBDIR_PATH .. 'mods/')
    while rawlen(args) >= i do
        if args.add == true then
            local exit = add(args[i], SBDIR_PATH)
            if not exit then
                io.stderr:write(args[i] .. ': failed to install')
            end
        else
            if installed_mods[args[i]] then
                remove(SBDIR_PATH, installed_mods[args[i]], args[i])
            else
                io.stderr:write(args[i] .. ' doesn\'t exist\n')
            end
        end
        i = i + 1
    end
elseif args.list == true then
    local installed_mods = listmods(SBDIR_PATH .. 'mods/')
    for key, value in pairs(installed_mods) do
        io.stdout:write(key..'\n')
    end
else
    lapp.error('error: missing commands')
end
