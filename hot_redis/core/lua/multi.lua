
function rank_lists_by_length()
    local ranker_key = "__tmp__.hot_redis.rank_lists_by_length"
    for _, key in ipairs(KEYS) do
        redis.call('ZADD',
            ranker_key,
            redis.call('LLEN', key),
            key)
    end
    local result = redis.call('ZREVRANGE', ranker_key, ARGV[1], ARGV[2],
        'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end

function rank_sets_by_cardinality()
    local ranker_key = "__tmp__.hot_redis.rank_sets_by_cardinality"
    for _, key in ipairs(KEYS) do
        redis.call('ZADD',
            ranker_key,
            redis.call('SCARD', key),
            key)
    end
    local result = redis.call('ZREVRANGE', ranker_key, ARGV[1], ARGV[2],
        'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end

function rank_zsets_by_cardinality()
    local ranker_key = "__tmp__.hot_redis.rank_zsets_by_cardinality"
    for _, key in ipairs(KEYS) do
        redis.call('ZADD',
            ranker_key,
            redis.call('ZCARD', key),
            key)
    end
    local result = redis.call('ZREVRANGE', ranker_key, ARGV[1], ARGV[2],
        'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end

function rank_by_sum_of_decaying_score()
    local from, halflife, cache_timeout, min, max = unpack(ARGS)
    local ranker_key = "__tmp__.hot_redis.rank_by_sum_of_decaying_score"
    for _, key in ipairs(KEYS) do
        local score_cache_key = key .. ':sum_of_decaying_scores:' .. halflife
        local score = redis.call('GET', score_cache_key)
        if not score then
            score = 0
            local cursor = 0
            while 1 do
                local c, values = unpack(redis.call('ZSCAN', key, cursor))
                cursor = c
                for index, val in ipairs(values) do
                    if index % 2 == 0 then
                        score = score + math.pow(0.5, ((from - val) / halflife))
                    end
                end
                if cursor == 0 then break end
            end
            if cache_timeout > 0 then
                redis.call('SET', score_cache_key, score, 'EX', cache_timeout)
            end
        end
        redis.call('ZADD', ranker_key, score, key)
    end
    local result = redis.call('ZREVRANGE', ranker_key, min, max, 'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end
