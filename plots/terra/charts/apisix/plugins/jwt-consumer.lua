local ngx_re = require("ngx.re")
local apisix_core = require("apisix.core")
local apisix_consumer = require("apisix.consumer")
local resty_jwt = require("resty.jwt")

-- ---------------------------------------------------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------------------------------------------------

local plugin_name = "jwt-consumer"

local plugin_schema = {
    type = "object",
    properties = {
        plans = {
            type = "array",
            items = {
                description = "Valid plans",
                type = "string"
            }
        }
    }
}

local _M = {
    version = 1,
    priority = 2600,
    name = plugin_name,
    type = 'auth',
    schema = plugin_schema
}

function _M.check_schema(conf, schema_type)
    return apisix_core.schema.check(plugin_schema, conf)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------------------------------------------------

local function get_bearer_access_token(ctx)
    local auth_header = apisix_core.request.header(ctx, "Authorization")
    local bearer_token

    if auth_header then
        local res, _ = ngx_re.split(auth_header, " ", nil, nil, 2)
        if res and #res > 1 and string.lower(res[1]) == "bearer" then
            bearer_token = res[2]
        else
            apisix_core.log.warn("No bearer token found!")
        end
    end

    return bearer_token
end

local function get_jwt_payload(ctx)
    local bearer_token = get_bearer_access_token(ctx)
    local jwt_payload

    if bearer_token then
        local jwt = resty_jwt:load_jwt(bearer_token, nil)
        if jwt.valid then
            jwt_payload = jwt.payload
            apisix_core.log.info("JWT payload: ", apisix_core.json.delay_encode(jwt_payload))
        else
            apisix_core.log.error("Invalid jwt!")
        end
    end

    return jwt_payload
end

local function table_contains(tab, val)
    if tab and val then
        for index, value in ipairs(tab) do
            if value == val then
                return true
            end
        end
    end

    return false
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Rewrite
-- ---------------------------------------------------------------------------------------------------------------------

function _M.rewrite(conf, ctx)
    local jwt_payload = get_jwt_payload(ctx)
    local consumer

    if jwt_payload and jwt_payload.plan and table_contains(conf.plans, jwt_payload.plan) then
        consumer = {
            id = jwt_payload.plan,
            consumer_name = jwt_payload.plan,
            group_id = jwt_payload.plan,
            modifiedIndex = jwt_payload.iat,
            plugins = {
                limit_count = {}
            },
            -- not used by apisix
            sub = jwt_payload.sub
        }
    else
        consumer = {
            id = "basic",
            consumer_name = "basic",
            group_id = "basic",
            modifiedIndex = os.time(),
            plugins = {
                limit_count = {}
            },
            -- not used by apisix
            sub = "anonymous"
        }
    end

    local consumer_conf = {
        conf_version = _M.version
    }
    apisix_core.log.info("Setting consumer [" .. consumer.id .. "] for [" .. consumer.sub .. "].")
    apisix_consumer.attach_consumer(ctx, consumer, consumer_conf)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Register Variable
-- ---------------------------------------------------------------------------------------------------------------------

apisix_core.ctx.register_var(
        "jwt_sub",
        function(ctx)
            local jwt_sub
            if ctx.consumer and ctx.consumer.sub then
                jwt_sub = ctx.consumer.sub
            end

            return jwt_sub
        end,
        { no_cacheable = true }
)

return _M
