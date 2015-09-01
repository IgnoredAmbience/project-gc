local args={...}
local conf = args[1].config
local profileName = args[1].profileName
local profileId = args[1].profileId

Print('Got profile name, ', profileName, "\n")

-- Get data for as few fields as possible to reduce memory usage. A full list of fields can be found at http://project-gc.com/doxygen/lua-sandbox/classPGC__LUA__Sandbox.html#a8b8f58ee20469917a29dc7a7f751d9ea
local finds = PGC_GetFinds(profileId, { fields = {'visitdate'} })

local days = {}
local months = {}

local df = Date.Format("yyyy-mm-dd")

for _,f in IPairs(finds) do
    local date = df:parse(f.visitdate)
  
	local day = date:day()
    if(date:day() < 30) then
      days[day] = (days[day] or 0) + 1
    end
  
  	local month = date:month()
    months[month] = (months[month] or 0) + 1
end

local monthok = false
for month = 1, 12 do
  local m = Date { month = month }
  local avg = months[month] / m:last_day():day()
  Print(m:month_name(), " total: ", months[month], " average: ", avg ,"\n")
  monthok = monthok or months[month] > 620
end

local dayok
for day = 1, 29 do
  local avg = days[day] / 12
  Print(day, " total: ", days[day], " average: ", avg ,"\n")
  dayok = dayok or days[day] > 240
end


local ok = monthok and dayok
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
