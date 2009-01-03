#!/usr/local/bin/lua

-- Load modules.
--LUADOC_HOME = "/usr/local/luadoc"
LUADOC_HOME = "d:/HOME/pitek/devel/MoonWiki/luadoc"
LUADOC_SUB = LUADOC_HOME.."/sub.lua"
LUADOC_CMP = LUADOC_HOME.."/cmp.lua"
dofile (LUADOC_HOME.."/analyze.lua")
dofile (LUADOC_HOME.."/compose.lua")

-- Print version number.
function print_version ()
	print ("LuaDoc "..LUADOC_VERSION)
end

-- Print usage message.
function print_help ()
	print ("Usage: "..arg[0]..[[ [options|files]
Extract documentation from files.  Available options are:
  -d path               output directory path
  -f "<find>=<repl>"    define a substitution filter (only string patterns)
  -g "<find>=<repl>"    define a substitution filter (string.gsub patterns)
  -s                    define standard substitutions for [[text]] -> <code>text</code>
  -h, --help            print this help and exit
      --noindexpage     do not generate global index page
  -q, --quiet           suppress all normal output
  -v, --version         print version information]])
end

function off_messages (arg, i, options)
	options.verbose = nil
end

-- Global filters.
FILTERS = {}
-- Process options.
OPTIONS = {
	d = function (arg, i, options)
		local dir = arg[i+1]
		if string.sub (dir, -2) ~= "/" then
			dir = dir..'/'
		end
		options.output_dir = dir
		return 1
	end,
	f = function (arg, i, options)
		local sub = arg[i+1]
		local find = string.gsub (sub, '^([^=]+)%=.*$', '%1')
		find = string.gsub (find, "(%p)", "%%%1")
		local repl = string.gsub (sub, '^.-%=([^"]+)$', '%1')
		repl = string.gsub (repl, "(%p)", "%%%1")
		table.insert (FILTERS, { find, repl })
                return 1
	end,
	g = function (arg, i, options)
		local sub = arg[i+1]
		local find = string.gsub (sub, '^([^=]+)%=.*$', '%1')
		local repl = string.gsub (sub, '^.-%=([^"]+)$', '%1')
		table.insert (FILTERS, { find, repl })
		return 1
	end,
        s = function ()
                table.insert(FILTERS, {"%[%[", "%<code%>"})
                table.insert(FILTERS, {"%]%]", "%<%/code%>"})
        end,
	h = print_help,
	help = print_help,
	q = off_messages,
	quiet = off_messages,
	v = print_version,
	version = print_version,
}
DEFAULT_OPTIONS = {
	output_dir = "",
	verbose = 1,
}
function process_options (arg)
	local files = {}
	local options = DEFAULT_OPTIONS
	for i = 1, table.getn(arg) do
		local argi = arg[i]
		if string.sub (argi, 1, 1) ~= '-' then
			table.insert (files, argi)
		else
			local opt = string.sub (argi, 2)
			if string.sub (opt, 1, 1) == '-' then
				opt = string.gsub (opt, "%-", "")
			end
			if OPTIONS[opt] then
				if OPTIONS[opt] (arg, i, options) then
					i = i+1
				end
			else
				options[opt] = 1
			end
		end
	end
	return files, options
end 

-- Process options.
local argc = table.getn(arg)
if argc < 1 then
	print_help ()
end
local files, options = process_options (arg)

-- Process files.
for i = 1, table.getn(files) do
	local f = files[i]
	local h = string.gsub (f, "lua$", "html")
	h = options.output_dir..string.gsub (h, "^.-([%w_]+%.html)$", "%1")
	if options.verbose then
		print ("Processando "..f.." (=> "..h..")")
	end
	compose (analyze (f, LUADOC_SUB), LUADOC_CMP, h)
end

-- Generate index file.
if (table.getn(files) > 0) and (not options.noindexpage) then
	index (options.output_dir)
end
