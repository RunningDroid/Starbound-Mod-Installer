--
--------------------------------------------------------------------------------
--         FILE:  starbound-mods.lua
--        USAGE:  ./starbound-mods.lua
--  DESCRIPTION:  a starbound mod handler written in lua
--      OPTIONS:  ---
-- REQUIREMENTS:  luaposix, dtrx
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  RunningDroid (), <runningdroid@zoho.com>
--      VERSION:  0.2
--      CREATED:  02/23/2014 02:34:19 PM EST
--     REVISION:  ---
--------------------------------------------------------------------------------
--

local posix = require('posix')
local lapp = require('pl.lapp')
local pldir = require('pl.dir')
local plpath = require('pl.path')

local args = lapp [[
    Adds or removes mods from Starbound
    -a,--add    add one or more mods
    -r,--remove remove one or more mods
    -l,--list   list installed mods
]]

-- not an assert, more like an error
function not_an_assert(exit, msg)
    if exit == false or exit == nil then
        io.stderr:write(msg..'\n')
        os.exit(1)
    end
end

-- returns a table listing all modfiles found
function find_modinfo(dir)
    if dir == nil or type(dir) ~= 'string' then
        return nil
    end

    return pldir.getallfiles(dir, '*.modinfo')
end

-- returns a string with the location the file was extracted to
function extract(file)
    if file == nil then
        error('file is nil!')
    end

    local filename = string.lower(posix.basename(file))
    local targetdir, errmsg = posix.mkdtemp(filename .. '.XXXXXX')
    if targetdir == nil then
        error(errmsg)
    end

    if string.match(filename, '.%.zip' ) then
        not_an_assert(os.execute('which unzip >/dev/null'), '"which unzip" failed!')
        not_an_assert(os.execute('unzip -d ' .. targetdir .. ' ' .. file .. ' >/dev/null'), 'failed to unzip ' .. filename .. '!')
        return targetdir
    elseif string.match(filename, '.%.rar' ) then
        not_an_assert(os.execute('which unrar >/dev/null'), '"which unrar" failed!')
        not_an_assert(os.execute('unrar x ' .. file .. ' ' .. targetdir), 'failed to unrar ' .. filename .. '!')
        return targetdir
    elseif string.match(filename, '.%.7z' ) then
        not_an_assert(os.execute('which 7z >/dev/null'), '"which 7z" failed!')
        not_an_assert(os.execute('7z x -o' .. targetdir .. ' ' .. file .. ' >/dev/null'), 'failed to un-7z ' .. filename .. '!')
        return targetdir
    end
end

function add(file)
    local oldpwd = plpath.currentdir()
    tmpdir = posix.mkdtemp(posix.getenv('XDG_RUNTIME_DIR') .. '/' .. 'starbound-mods.XXXXXX')
    plpath.chdir(tmpdir)
    local dir = extract(oldpwd .. '/' .. file)
    local modinfos = find_modinfo(dir)
    for key, value in pairs(modinfos) do
        --TODO: add a version check
        local installed_path = posix.getenv('HOME') .. '/.local/share/Steam/SteamApps/common/Starbound/mods/' .. posix.dirname(value)
        if plpath.exists(installed_path) then
            if plpath.isdir(installed_path) then
                not_an_assert(pldir.rmtree(installed_path), 'Failed to delete directory: ' .. installed_path)
            else
                not_an_assert(os.remove(installed_path), 'Failed to delete file: ' .. installed_path)
            end
            pldir.movefile(posix.dirname(value), posix.getenv('HOME') .. '/.local/share/Steam/SteamApps/common/Starbound/mods/')
        else
            pldir.movefile(posix.dirname(value), posix.getenv('HOME') .. '/.local/share/Steam/SteamApps/common/Starbound/mods/')
        end
    end
end

function remove(file)
    local mod_dir = posix.getenv('HOME') .. '/.local/share/Steam/SteamApps/common/Starbound/mods/'
    if not plpath.isdir(mod_dir) then
        error('you need to run Starbound before running this', 0)
    end
    plpath.chdir(mod_dir)

    if plpath.exists(file) then
        print('Removing ' .. file)
        if plpath.isdir(file) then
            local exit, errmsg = pldir.rmtree(plpath.abspath(file))
            if exit == nil then
                io.stderr:write(file .. " : " .. errmsg)
            end
        else
            local exit, errmsg = os.remove(file)
            if exit == nil then
                io.stderr:write(file .. " : " .. errmsg)
            end
        end
    else
        io.stderr:write(file .. " doesn't exist.\n")
    end
end

function list()
    local mod_dir = posix.getenv('HOME') .. '/.local/share/Steam/SteamApps/common/Starbound/mods/'
    if not plpath.isdir(mod_dir) then
        error('you need to run Starbound before running this', 0)
    end
    plpath.chdir(mod_dir)
    for key, value in pairs(pldir.getdirectories('.')) do
        print(plpath.basename(value))
    end
    -- this is more accurate, but slow
--    local modinfos = find_modinfo(plpath.currentdir())
--    for key, value in pairs(modinfos) do
--        -- TODO: get the mod's name from the modinfo
--        print(plpath.basename(plpath.dirname(value)))
--    end
end

-- handle the arguments
if (args.add == true and args.list == true) or (args.add == true and args.remove == true) or (args.remove == true and args.list == true) then
    lapp.error('error: too many commands')
elseif (args.add == true) or (args.remove == true) then
    local i = 1
    while rawlen(args) >= i do
        if args.add == true then
            add(args[i])
        else
            remove(args[i])
        end
        i = i + 1
    end
elseif args.list == true then
    list()
else
    lapp.error('error: missing commands')
end
