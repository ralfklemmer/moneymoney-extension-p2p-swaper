WebBanking {
  version = 1.0,
  url = "https://swaper.com",
  description = "Fetch balances from Swaper. Shows current account value and profit since deposit.",
  services = { "Swaper Account" },
}

-- ============================================================================
--        Custom extension data structures
-- ============================================================================
local swaperConfig = {
  restPathLogin = "https://swaper.com/rest/public/login",
  restPathOverview = "https://swaper.com/rest/public/profile/overview",
  securityToken = nil,
  securityCookies = nil,
  initialResponseHeader = nil,
  header = nil,
}

local moneymoneyView = {
  accountData = nil,
  overviewTable = nil
}

local LOG = ">> Swaper Extension: "
local connection = Connection()

-- ============================================================================
--        MoneyMoney lifecycle integration
-- ============================================================================
function SupportsBank(protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "Swaper Account"
end

function InitializeSession(protocol, bankCode, username, username2, password, username3)
  MM.printStatus(LOG .. "Connecting to Swaper ...")
  moneymoneyView.accountData = SwaperLogin(username, password)
  MM.printStatus(LOG .. "Login successful.")
  moneymoneyView.overviewTable = SwaperCallOverview(swaperConfig.header)
  MM.printStatus(LOG .. "Reading data successfully.")
end

function ListAccounts (knownAccounts)
  MM.printStatus(LOG .. "ListAccounts ...")
  return {{
    name = "Swaper",
    accountNumber = "Swaper",
    currency = "EUR",
    portfolio = true,
    type = "AccountTypePortfolio"
  }}
end

function RefreshAccount (account, since)
  MM.printStatus(LOG .. "Refreshing ...")
  local entry = {}
  local overViewData = moneymoneyView.overviewTable
  local security = {
    name = "Account",
    price = tonumber(overViewData.accountValue),
    quantity = 1,
    purchasePrice = tonumber(overViewData.deposits) - tonumber(overViewData.withdrawals),
    currency = nil, -- don't change, otherwise 2 digits will be cut off
  }
  table.insert(entry, security)

  return {securities = entry }
end

function EndSession ()
  connection:request("POST", "https://swaper.com/rest/public/logout", "{}", "application/json", swaperConfig.header)
  MM.printStatus(LOG .. "Session ended.")
  return nil
end

-- ============================================================================
--        Swaper Rest calls
-- ============================================================================

-------------------------------------------------------------------------------
-- POST https://swaper.com/rest/public/login
-------------------------------------------------------------------------------
function SwaperLogin(username, password)
  local body = '{"name":"' .. username .. '", "password":"' .. password .. '"}'

  local responseBody, charset, mimeType, filename, responseHeader = connection:request("POST", swaperConfig.restPathLogin, body, "application/json", {})
  initSwaperConfig(responseHeader)

  return JSON(responseBody):dictionary()
end

-------------------------------------------------------------------------------
-- GET https://swaper.com/rest/public/profile/overview
-------------------------------------------------------------------------------
function SwaperCallOverview()
  local responseBody = connection:request("GET", swaperConfig.restPathOverview, nil, nil, swaperConfig.header)
  return JSON(responseBody):dictionary()
end

function initSwaperConfig(responseHeader)
  swaperConfig.initialResponseHeader = responseHeader
  swaperConfig.securityToken = responseHeader["_csrf"]
  swaperConfig.securityCookies = connection:getCookies()
  swaperConfig.header = {
    ["Cookie"] = swaperConfig.securityCookies,
    ["x-xsrf-token"] = swaperConfig.securityToken
  }
end

-- ============================================================================
--        Util functions
-- ============================================================================
function printTable(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. printTable(v) .. ','
    end
    s = s .. '} '
    print(LOG .. s)
    return s
  else
    return tostring(o)
  end
end

function printCurl(restPath)
  local curlCommand = "curl -X GET '" .. restPath .. "' "
  for k, v in pairs(swaperConfig.header) do
    curlCommand = curlCommand .. "-H '" .. k .. ": " .. v .. "' "
  end
  print(LOG ..curlCommand)
end

-- SIGNATURE: MC0CFQCLTL5BKOsMhRJ1vZhCRG54Dsrm+AIUL9Ben/o9Xu/K7YzJzxw8kcebmyU=
