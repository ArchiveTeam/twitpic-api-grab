local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
dofile("urlcode.lua")
dofile("table_show.lua")
JSON = (loadfile "JSON.lua")()

load_json_file = function(file)
  if file then
    local f = io.open(file)
    local data = f:read("*all")
    f:close()
    return JSON:decode(data)
  else
    return nil
  end
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

local downloaded = {}

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  
  if item_type == "imageapi" then
    
    if string.match(url, "http://api%.twitpic%.com/2/comments/show%.json%?media_id=[^&]+&page=1") then
      json = load_json_file(file)
      
      local numpages = json.total_pages
      
      while numpages ~= 0 do
        local media_id = string.match(url, "http://api%.twitpic%.com/2/comments/show%.json%?media_id=([^&]+)&page=[0-9]+")
        table.insert(urls, { url=("http://api.twitpic.com/2/comments/show.json?media_id="..media_id.."&page="..numpages) })
        numpages = numpages - 1
      end
    end
--      if (string.match(html, '{"total_comments":"[0-9]+","total_pages":[0-9]+}') or string.match(html, '"code":404')) then
--        local page = string.match(url, "http://api%.twitpic%.com/2/comments/show%.json%?media_id=[^&]+&page=([0-9]+)")
--        local newpage = page + 1
--        local media_id = string.match(url, "http://api%.twitpic%.com/2/comments/show%.json%?media_id=([^&]+)&page=[0-9]+")
--        table.insert(urls, { url=("http://api.twitpic.com/2/comments/show.json?media_id="..media_id.."&page="..newpage) })
--      end
--    elseif string.match(url, "http://twitpic%.com/comments/show%.json%?media_id=[^&]+&last_seen=[0-9]+") then
--      json = load_json_file(file)
--        
--      for commentid in string.gmatch(json, 'id = ["]?([0-9]+)["]?,[ ]?media_id = ["]?[0-9a-z]+["]?') do
--        for commentspage in string.gmatch(json, 'id = ["]?([^"]+)["]?,[ ]?media_id = ["]?([^"]+)["]?') do
--          local newcomment = "http://twitpic.com/comments/show.json?media_id="..commentspage.."&last_seen="..commentid
--          table.insert(urls, { url=newcomment })
--        end
--      end
--      
--      for avatar_url in string.gmatch(json, 'avatar_url = "(http[^"]+)"') do
--        table.insert(urls, { url=avatarurl })
--      end
--      
--      for profile_background_image_url in string.gmatch(json, 'profile_background_image_url = "(http[^"]+)"') do
--        table.insert(urls, { url=backgroundimageurl })
--      end
--      
  end
  
  return urls
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local ishtml = urlpos["link_expect_html"]
  local parenturl = parent["url"]
  local wgetreason = reason

  if downloaded[url] == true then
    return false
  end

  -- Chfoo - Can I use "local html = nil" in "wget.callbacks.download_child_p"?
  local html = nil

  if item_type == "imageapi" then
    if string.match(url, "cloudfront%.net") or
      string.match(url, "twimg%.com")  or
      string.match(url, "amazonaws%.com") then
      return verdict
    end
  end
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  local status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if status_code >= 200 and status_code <= 399 then
    downloaded[url.url] = true
  end
  
  -- consider 403 as banned from twitpic, not pernament failure
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404) or
    (status_code == 403 and string.match(url["host"], "twitpic%.com")) then
    if string.match(url["host"], "twitpic%.com") or
      string.match(url["host"], "cloudfront%.net") or
      string.match(url["host"], "twimg%.com") or
      string.match(url["host"], "amazonaws%.com") then
      
      io.stdout:write("\nServer returned "..http_stat.statcode.." for " .. url["url"] .. ". Sleeping.\n")
      io.stdout:flush()
      
      os.execute("sleep 1800")
      
      tries = tries + 1
      
      if tries >= 3 then
        return wget.actions.ABORT
      else
        return wget.actions.CONTINUE
      end
    else
      io.stdout:write("\nServer returned "..http_stat.statcode.." for " .. url["url"] .. ". Sleeping.\n")
      io.stdout:flush()
      
      os.execute("sleep 10")
      
      tries = tries + 1
      
      if tries >= 5 then
        return wget.actions.BORT
      else
        return wget.actions.CONTINUE
      end
    end
  elseif status_code == 0 then
    io.stdout:write("\nServer returned "..http_stat.statcode.." for " .. url["url"] .. ". Sleeping.\n")
    io.stdout:flush()
    
    os.execute("sleep 10")
    
    tries = tries + 1
    
    if tries >= 5 then
      admit_failure(status_code, url.url)
      return wget.actions.NOTHING
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  -- We're okay; sleep a bit (if we have to) and continue
  -- local sleep_time = 0.1 * (math.random(1000, 2000) / 100.0)
  local sleep_time = 0

  --  if string.match(url["host"], "cdn") or string.match(url["host"], "media") then
  --    -- We should be able to go fast on images since that's what a web browser does
  --    sleep_time = 0
  --  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
