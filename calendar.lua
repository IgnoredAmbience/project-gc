local args={...}
local config = args[1].config
local profileName = args[1].profileName
local profileId = args[1].profileId

Print('Got profile name, ', profileName, "\n")

-- Get data for as few fields as possible to reduce memory usage. A full list of fields can be found at http://project-gc.com/doxygen/lua-sandbox/classPGC__LUA__Sandbox.html#a8b8f58ee20469917a29dc7a7f751d9ea
local finds = PGC_GetFinds(profileId, { fields = {'visitdate'} })

local monthInfo = {name = {}, days = {}}
for month = 1, 12 do
  local m = Date { year = 2004, month = month, day = 1 } -- Force a leap year
  monthInfo.name[month] = m:month_name(false)
  monthInfo.days[month] = m:last_day():day()
end

function inittbl(n, v)
  t = {}
  for i = 1, n do
    t[i] = v
  end
  return t
end

-- Return a table of month x day initialised to 0
function calendar()
  c = {}
  for m = 1, 12 do
    c[m] = inittbl(monthInfo.days[m], 0)
    c[m].sum = 0
  end
  c.sum = inittbl(31, 0)
  c.total = 0
 return c
end

local cal = calendar()

local df = Date.Format("yyyy-mm-dd")

for _,f in IPairs(finds) do
  local date = df:parse(f.visitdate)
  local d = date:day()
  local m = date:month()
  c[m][d] = c[m][d] + 1
  c[m].sum = c[m].sum + 1
  c.sum[d] = c.sum[d] + 1
  c.total = c.total + 1
end

local tbl = {{"Month", "Finds", "Average"}}
local monthok = false
for month = 1, 12 do
  local avg = c[month].sum / monthInfo.days[month]
  TableInsert(tbl, {monthInfo.name[month], c[month].sum, StringFormat("%.2f", avg)})
  monthok = monthok or c[month].sum > config.monthCount
end
 
local tbl2 = {{"Day", "Finds", "Average"}}

local dayok
for day = 1, 29 do
  local avg = c.sum[day] / 12
  TableInsert(tbl2, {day, c.sum[day], StringFormat("%.2f", avg)})
  dayok = dayok or c.sum[day] > config.dayCount
end


local ok = monthok and dayok
--local html = "<div style='float: left'>"..PGC_CreateHTMLTable(tbl).."</div><div style='float:left'>"..PGC_CreateHTMLTable(tbl2).."</div><br clear='all'>"
local html = PGC_CreateHTMLTable(c)
local log = false

return { ok = ok, log = log, html = html }
