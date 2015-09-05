local args=...
local profileName = args.profileName
local profileId = args.profileId

local conf = args.config
--[[
Permitted config options:
* findBeforePub: true/false, whether finds before publication are counted (default: false)
* days: Threshold for a quick find in days, inclusive (0 = same day, 1 = next)
* count: Number of quick finds in a day to qualify
]]

local dayInSeconds = 86400

local types = {
  ["Traditional Cache"]                      = "http://www.geocaching.com/images/wpttypes/sm/2.gif",
  ["Multi-cache"]                            = "http://www.geocaching.com/images/wpttypes/sm/3.gif",
  ["Virtual Cache"]                          = "http://www.geocaching.com/images/wpttypes/sm/4.gif",
  ["Letterbox Hybrid"]                       = "http://www.geocaching.com/images/wpttypes/sm/5.gif",
  ["Event Cache"]                            = "http://www.geocaching.com/images/wpttypes/sm/6.gif",
  ["Cache In Trash Out Event"]               = "http://www.geocaching.com/images/wpttypes/sm/13.gif",
  ["Mega-Event Cache"]                       = "http://www.geocaching.com/images/wpttypes/sm/mega.gif",
  ["Lost and Found Event Cache"]             = "http://www.geocaching.com/images/wpttypes/sm/3653.gif",
  ["Groundspeak Lost and Found Celebration"] = "http://www.geocaching.com/images/wpttypes/sm/3774.gif",
  ["Groundspeak Block Party"]                = "http://www.geocaching.com/images/wpttypes/sm/4738.gif",
  ["Giga-Event Cache"]                       = "http://www.geocaching.com/images/wpttypes/sm/giga.gif",
  ["Unknown Cache"]                          = "http://www.geocaching.com/images/wpttypes/sm/8.gif",
  ["Groundspeak HQ"]                         = "http://www.geocaching.com/images/wpttypes/sm/3773.gif",
  ["Project APE Cache"]                      = "http://www.geocaching.com/images/wpttypes/sm/9.gif",
  ["Webcam Cache"]                           = "http://www.geocaching.com/images/wpttypes/sm/11.gif",
  ["Earthcache"]                             = "http://www.geocaching.com/images/wpttypes/sm/earthcache.gif",
  ["GPS Adventures Exhibit"]                 = "http://www.geocaching.com/images/wpttypes/sm/1304.gif",
  ["Wherigo Cache"]                          = "http://www.geocaching.com/images/wpttypes/sm/wherigo.gif",
  ["Benchmark"]                              = "http://www.geocaching.com/images/wpttypes/sm/27.gif",
  ["Locationless (Reverse) Cache"]           = "http://www.geocaching.com/images/wpttypes/sm/12.gif"
}

function MathRound(n)
  local f = MathFloor(n)
  return (n-f > 0.5 and MathCeil(n)) or f
end

function inittbl(n, v)
  t = {}
  for i = 1, n do
    t[i] = v
  end
  return t
end

function cacheHeaderHtml(dstTbl, additionalFields)
  TableInsert(dstTbl, '<tr><td/><td>GC Code</td><td>Name</td>')
  for _,fld in IPairs(additionalFields) do
    TableInsert(dstTbl, StringFormat('<td>%s</td>', fld))
  end
  TableInsert(dstTbl, '</tr>\n')
end

function cacheHtml(cache, dstTbl, additionalFields)
  TableInsert(dstTbl, '<tr>')
  TableInsert(dstTbl, StringFormat('<td><img src="%s" /></td>', types[cache.type]))
  TableInsert(dstTbl, StringFormat('<td><a href="http://coord.info/%s"> %s</a></td>', cache.gccode, cache.gccode))
  TableInsert(dstTbl, StringFormat('<td>%s</td>', cache.cache_name))
  for _,fld in IPairs(additionalFields) do
    TableInsert(dstTbl, StringFormat('<td>%s</td>', cache[fld]))
  end
  TableInsert(dstTbl, '</tr>\n')
end

function cacheLog(cache, dstTbl, additionalFields)
  TableInsert(dstTbl, StringFormat('[url=http://coord.info/%s]%s[/url] %s (%s) ', cache.gccode, cache.gccode, cache.cache_name, cache.type))
  for _, fld in IPairs(additionalFields) do
    TableInsert(dstTbl, cache[fld])
    TableInsert(dstTbl, ' ')
  end
  TableInsert(dstTbl, '\n')
end

----------------------------------------------

Print('Got profile name, ', profileName, "\n")

local df = Date.Format("yyyy-mm-dd")

local finds = PGC_GetFinds(profileId, { fields = {'gccode', 'cache_name', 'type',
                                                  'last_publish_date', 'hidden', 'visitdate'} })

local days = {}
local qualifyingDays = {}

for _,f in IPairs(finds) do
  f.published = f.last_publish_date or f.hidden
  local pub = df:parse(f.published)
  local visit = df:parse(f.visitdate)

  f.interval = MathRound((visit.time - pub.time)/dayInSeconds)

  if (conf.findBeforePub or f.interval >= 0) and f.interval <= conf.days then
    if not days[f.visitdate] then days[f.visitdate] = {} end
    local visits = days[f.visitdate]
    TableInsert(visits, f)
    if #visits == conf.count then
      TableInsert(qualifyingDays, f.visitdate)
    end
  end
end

-- Sort qualifyingDays by number of finds, descending
TableSort(qualifyingDays, function (d1, d2)
  return #(days[d1]) > #(days[d2])
end)


local ok = false
local htmlLines = {}
local logLines = {}

for i,d in IPairs(qualifyingDays) do
  ok = true
  local numFinds = #(days[d])

  local msg = StringFormat('On %s, %s found %d caches quickly:\n', d, profileName, numFinds)
  if i == 1 then
    TableInsert(logLines, msg)
  end

  TableInsert(htmlLines, msg)
  TableInsert(htmlLines, '<table>')
  cacheHeaderHtml(htmlLines, {'Published', 'Found', 'Days between'})
  for _, cache in IPairs(days[d]) do
    if i == 1 then cacheLog(cache, logLines, {'published', 'visitdate'}) end
    cacheHtml(cache, htmlLines, {'published', 'visitdate', 'interval'})
  end
  TableInsert(htmlLines, '</table><br/>')
end


-- And for the people that missed out
if #qualifyingDays == 0 then
  TableInsert(htmlLines, StringFormat('Unfortunately %s does not qualify as they did not find %d caches quickly in one day, however they have previously quickly found:\n', profileName, conf.count))
  TableInsert(htmlLines, '<table>')
  cacheHeaderHtml(htmlLines, {'Published', 'Found', 'Days between'})
  for d,t in Pairs(days) do
    for _, cache in IPairs(t) do
      cacheHtml(cache, htmlLines, {'published', 'visitdate', 'interval'})
    end
  end
  TableInsert(htmlLines, '</table>')
end


return { ok = ok, html = TableConcat(htmlLines), log = TableConcat(logLines)}

