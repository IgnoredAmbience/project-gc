local args={...}
local conf = args[1].config
local profileName = args[1].profileName
local profileId = args[1].profileId

Print('Got profile name, ', profileName, "\n")

-- Get data for as few fields as possible to reduce memory usage. A full list of fields can be found at http://project-gc.com/doxygen/lua-sandbox/classPGC__LUA__Sandbox.html#a8b8f58ee20469917a29dc7a7f751d9ea
local finds = PGC_GetFinds(profileId, { fields = {'visitdate'} })

function inittbl(n, v)
  t = {}
  for i = 1, n do
    t[i] = v
  end
  return t
end

local days = inittbl(31, 0)
local months = inittbl(12, 0)

local df = Date.Format("yyyy-mm-dd")

for _,f in IPairs(finds) do
    local date = df:parse(f.visitdate)
  
	local day = date:day()
    if(date:day() < 30) then
      days[day] = days[day] + 1
    end
  
  	local month = date:month()
    months[month] = months[month] + 1
end

local tbl = {{"Month", "Finds", "Average"}}
local monthok = false
for month = 1, 12 do
  local m = Date { month = month }
  local avg = months[month] / m:last_day():day()
  TableInsert(tbl, {m:month_name(true), months[month], StringFormat("%.2f", avg)})
  monthok = monthok or months[month] > 620
end
 
local tbl2 = {{"Day", "Finds", "Average"}}

local dayok
for day = 1, 29 do
  local avg = days[day] / 12
  TableInsert(tbl2, {day, days[day], StringFormat("%.2f", avg)})
  dayok = dayok or days[day] > 240
end


local ok = monthok and dayok
local html = "<div style='float: left'>"..PGC_CreateHTMLTable(tbl).."</div><div style='float:left'>"..PGC_CreateHTMLTable(tbl2).."</div><br clear='all'>"
local log = false




return { ok = ok, log = log, html = html }
