local args={...}
local conf = args[1].config
local profileName = args[1].profileName
local profileId = args[1].profileId
-- Print produces debug log
Print('Got profile name, ', profileName, "\n")


--[[
-- Example filter code
local filter = {}
if(conf.country ~= nil) then
	filter['country'] = conf.country
end
--]]


--[[
-- Get data for as few fields as possible to reduce memory usage. A full list of fields can be found at http://project-gc.com/doxygen/lua-sandbox/classPGC__LUA__Sandbox.html#a8b8f58ee20469917a29dc7a7f751d9ea
local finds = PGC_GetFinds(profileId, { fields = {'gccode', 'cache_name', 'visitdate', 'country'}, order = 'OLDESTFIRST', filter = filter })
--]]


--[[
-- Do calculations
for _,f in IPairs(finds) do
	--
end
--]]



local ok = false
local log = false
local html = false


-- Check if challenge is fulfilled and if so, set ok = true
-- ok = true

if(ok == true) then
  -- Produce example log, Project-GC recommends using bbcode if it's useful.
  -- Do not use  log = log .. "foo"  in loops with many iterations, it consumes a lot of memory in LUA.
  log = {}
  TableInsert(log, "foo")
  TableInsert(log, "bar")
  TableInsert(log, "baz")
  log = TableConcat(log, "\n")
end


--[[
More feedback can be given by producing html into the html variable
Can be of good use to show the user his/her progress
Doesn't actually have to be html
--]]


return { ok = ok, log = log, html = html }
