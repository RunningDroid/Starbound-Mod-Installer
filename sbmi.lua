#!/usr/bin/lua

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
local sbdir_path = os.getenv('HOME') .. '/.local/share/Steam/SteamApps/common/Starbound/'


-- takes a string thought to contain a specific key, returns the key's value or nil if the key can't be found
function getjsonvalue(rawstring, key)
    if (rawstring == nil ) or (key == nil) then
        return nil
    end
    -- FIXME: this will break on, for example "AwesomeSauce's Awesome Mod"
    local value = string.match(rawstring, '^%s+["\']' .. key ..'["\']%s*:%s*["\']([^"\']+)["\'][,]?%s*$')
    return value
end

-- takes the path to the modinfo file, returns the mod's (hopefully) pretty name or nil if it can't find a name
function getmodname(modinfo_path)
    if modinfo_path == nil then
        error('modinfo_path is nil!')
    end
    local modinfo, errmsg = io.open(modinfo_path, 'r')
    if modinfo == nil then
        error(errmsg)
    end

    for line in modinfo:lines() do
        if string.match(line, 'name') ~= nil then
            pretty_name = getjsonvalue(line, 'name')
        elseif string.match(line, 'displayName') ~= nil then
            prettier_name = getjsonvalue(line, 'displayName')
        end
    end
    io.close(modinfo)

    -- try for a pretty name
    local name = prettier_name
    if name == nil then
        -- fall back to a potentially less pretty name
        name = pretty_name
    end
    if name == nil then
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

-- takes the path to the modinfo file, returns the version of Starbound the mod is compatible with
function getmodcompatver(modinfo_path)
    if modinfo_path == nil then
        error('modinfo_path is nil!')
    end
    local modinfo, errmsg = io.open(modinfo_path, 'r')
    if modinfo == nil then
        error(errmsg)
    end

    -- try to ensure 'line' gets gc'd when we're done with it
    line = nil
    -- TODO: add a check to make sure we don't get the mod's version
    repeat
        line = modinfo:read('*l')
    until (line == nil) or (string.match(line, 'version') ~= nil)

    if not line then
        error(modinfo_path .. ' is empty!')
    end

    local version = getjsonvalue(line, 'version')
    io.close(modinfo)
    return version
end

-- takes the path to the starbound dir, returns the Starbound version
function getsbversion(sbdir)
    if sbdir == nil then
        error('sbdir is nil!')
    end

    -- check for a '/' at the end of the string
    if string.match(sbdir, '/$') == nil then
        sbdir = sbdir .. '/'
    end

    local assets, errmsg = io.open(sbdir .. 'assets/packed.pak', 'rb')
    if assets == nil then
        error(errmsg)
    end

    -- the start of the line containing the versionString in assets/packed.pak is 2646989 bytes in
    assets:seek('set', 2646989)
    local rawverstring = assets:read('*l')
    local verstring = getjsonvalue(rawverstring, 'versionString')
    return(verstring)
end

-- returns a table listing all modfiles found
function find_modinfo(dir)
    if dir == nil or type(dir) ~= 'string' then
        return nil
    end

    local modfile_table = {}
    -- TODO: check to see if pl.dir.dirtree() would be better
    for root, dirs, files in pldir.walk(dir, false, false) do
        for key, value in pairs(files) do
            if string.match(value, '.+%.modinfo$') then
                table.insert(modfile_table, root .. '/' .. value)
            end
        end
    end

    return modfile_table
end

-- returns a string with the location the file was extracted to
function extract(file)
    if file == nil then
        error('file is nil!')
    end

    local targetdir, extension = plpath.splitext(plpath.basename(file))
    local exit, errmsg = plpath.mkdir(targetdir)
    if exit == nil then
        if errmsg == 'File exists' then
            if plpath.isdir(targetdir) then
                local exit, errmsg = pldir.rmtree(targetdir)
                if exit == nil then
                    io.stderr:write('Failed to delete ' .. targetdir .. ' : ' .. errmsg .. '\n')
                end
            else
                local exit, errmsg = os.remove(targetdir)
                if exit == nil then
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
        elseif not os.execute('unzip -qqUU -d ' .. targetdir .. ' ' .. file) then
            io.stderr:write('failed to unzip ' .. file .. '!\n')
            return nil
        else
            return targetdir
        end
    elseif extension == '.rar' then
        if not os.execute('which unrar >/dev/null') then
            io.stderr:write('"which unrar" failed!\n')
            os.exit(false)
        -- FIXME: unrar is stupid, and modifying which messages should be shown breaks it
        -- example: modifying any message-related flags breaks unpacking "Dungeoneer Dungeons"
        elseif not os.execute('unrar -inul x \'' .. file .. '\' \'' .. targetdir .. '\'') then
            io.stderr:write('failed to unrar ' .. file .. '!\n')
            return nil
        else
            return targetdir
        end
    elseif extension == '.7z' then
        if not os.execute('which 7z >/dev/null') then
            io.stderr:write('"which 7z" failed!\n')
            os.exit(false)
        elseif not os.execute('7z x -o' .. targetdir .. ' ' .. file .. ' >/dev/null') then
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

-- TODO: fix how the mod 'Your Starbound Crew' is handled (it uses a universe directory, which doesn't have a *.modinfo)
-- takes a path to a archive and the path to the starbound dir, returns true if successful nil if not
function add(file_path, sbdir)
    local oldpwd = plpath.currentdir()
    tmpdir = os.getenv('XDG_RUNTIME_DIR') .. '/' .. 'starbound-mods'
    plpath.mkdir(tmpdir)
    plpath.chdir(tmpdir)
    local dir = extract(plpath.normpath(oldpwd .. '/' .. file_path))
    if dir == nil then
        return nil
    end
    local modinfos = find_modinfo(dir)
    local sbversion = getsbversion(sbdir)
    -- key is useless, file_path is the path to the modinfo
    for key, modinfo_path in pairs(modinfos) do
        -- if the file contains '\r' then we replace it with '\n'
        local modinfo = io.open(modinfo_path)
        local modinfo_content = modinfo:read('*a')
        if string.match(modinfo_content, '\r') then
            modinfo = io.open(modinfo_path, 'w+')
            local fixed_modinfo = string.gsub(modinfo_content, '\r', '\n')
            modinfo, errmsg = modinfo:write(fixed_modinfo)
            if modinfo == nil then
                error(errmsg)
            end
            modinfo:flush()
        end
        io.close(modinfo)

        local modcompatver = getmodcompatver(modinfo_path)
        local modname = getmodname(modinfo_path)
        if modcompatver ~= sbversion then
            if modcompatver == nil then
                io.stderr:write('modcompatver for "' .. modinfo_path ..'" is nil!\n')
            elseif sbversion == nil then
                io.stderr:write('sbversion is nil!\n')
            else
                io.stdout:write('Warning: ' .. modname .. 'may not be compatible with the current version of Starbound.\n')
                io.stdout:write('Do you wish to continue? [N/y]:')
                local answer = io.stdin:read()
                if string.match(string.lower(answer), 'y') ~= nil then
                    force_install = true
                end
            end
        end

        if (modcompatver == sbversion) or force_install then
            io.stdout:write('Adding ' .. modname .. '\n')
            local installed_path = sbdir .. 'mods/' .. modname
            if plpath.exists(installed_path) then
                if plpath.isdir(installed_path) then
                    local exit, errmsg = pldir.rmtree(installed_path)
                    if exit == nil then
                        io.stderr:write('Failed to delete ' .. installed_path .. ' : ' .. errmsg .. '\n')
                    end
                else
                    local exit, errmsg = os.remove(installed_path)
                    if exit == nil then
                        io.stderr:write('Failed to delete ' .. installed_path .. ' : ' .. errmsg .. '\n')
                    end
                end

                -- make the final path be starbound/mods/$prettyname
                if modname ~= nil then
                    pldir.movefile(plpath.dirname(modinfo_path), modname)
                    pldir.movefile(modname, sbdir .. 'mods/')
                    return true
                else
                    pldir.movefile(plpath.dirname(modinfo_path), sbdir .. 'mods/')
                    return true
                end
            else
                if modname ~= nil then
                    pldir.movefile(plpath.dirname(modinfo_path), modname)
                    pldir.movefile(modname, sbdir .. 'mods/')
                    return true
                else
                    pldir.movefile(plpath.dirname(modinfo_path), sbdir .. 'mods/')
                    return true
                end
            end
        else
        end
    end
    plpath.chdir(oldpwd)
end

-- takes the path to the starbound install, the name of the dir to remove and the name of the mod being removed
function remove(sbdir, mod_dirname, modname)
    local mod_dir = sbdir .. 'mods/'
    plpath.chdir(mod_dir)

    if plpath.exists(mod_dirname) then
        io.stdout:write('Removing ' .. modname .. '\n')
        if plpath.isdir(mod_dirname) then
            local exit, errmsg = pldir.rmtree(plpath.abspath(mod_dirname))
            if exit == nil then
                io.stderr:write('Failed to delete ' .. modname .. " : " .. errmsg .. '\n')
            end
        else
            local exit, errmsg = os.remove(mod_dirname)
            if exit == nil then
                io.stderr:write('Failed to delete ' .. modname .. " : " .. errmsg .. '\n')
            end
        end
    else
        io.stderr:write(modname .. ' isn\'t installed.\n')
    end
end

-- takes the path to the starbound mods dir, returns at table containing the modnames and the full path to the mod's directory
function list_mods(mod_dir)
    --local mod_dir = sbdir_path .. 'mods/'
    if not plpath.isdir(mod_dir) then
        error('you need to run Starbound before running this', 0)
    end
    local modinfos = find_modinfo(mod_dir)
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
    local installed_mods = list_mods(sbdir_path .. 'mods/')
    while rawlen(args) >= i do
        if args.add == true then
            add(args[i], sbdir_path)
        else
            if installed_mods[args[i]] ~= nil then
                remove(sbdir_path, installed_mods[args[i]], args[i])
            else
                io.stderr:write(args[i] .. ' doesn\'t exist\n')
            end
        end
        i = i + 1
    end
elseif args.list == true then
    local installed_mods = list_mods(sbdir_path .. 'mods/')
    -- TODO: add a sort
    for key, value in pairs(installed_mods) do
        io.stdout:write(key..'\n')
    end
else
    lapp.error('error: missing commands')
end
