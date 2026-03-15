UPDATE indexes
SET index_metadata_json = JSONB_SET(
    index_metadata_json::jsonb,
    '{index_config,retention}',
    '{"period": "1 day", "schedule": "daily"}'::jsonb,
    TRUE
)::TEXT
WHERE indexes.index_id IN ('otel-logs-v0_7', 'otel-traces-v0_7')
;

COMMIT;
