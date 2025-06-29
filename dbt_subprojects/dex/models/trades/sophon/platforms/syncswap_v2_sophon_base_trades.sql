{{
    config(
        schema = 'syncswap_v2_sophon',
        alias = 'base_trades',
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['tx_hash', 'evt_index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{% set syncswap_v2_start_date = "2024-10-21" %} -- Sophon mainnet launch

WITH 
    -- All SyncSwap V2 Pools
    pools AS (
        SELECT pool, token0, token1
        FROM {{ source('syncswap_v2_sophon', 'SyncSwapClassicPoolFactory_evt_PoolCreated') }}
    )
    
    , base AS (
        SELECT * FROM {{ source('syncswap_v2_sophon', 'SyncSwapClassicPool_evt_Swap') }}
        {% if is_incremental() %}
        WHERE {{incremental_predicate('evt_block_time')}}
        {% else %}
        WHERE evt_block_time >= timestamp '{{syncswap_v2_start_date}}'
        {% endif %}
    )
    
SELECT
    'sophon' AS blockchain
    , 'syncswap' As project
    , '2' AS version
    , CAST(date_trunc('month', evt_block_time) AS DATE) AS block_month
    , CAST(date_trunc('day', evt_block_time) AS DATE) AS block_date
    , evt_block_time AS block_time
    , evt_block_number AS block_number
    , IF(amount0Out = 0, amount1Out, amount0Out) AS token_bought_amount_raw
    , IF(amount0In = 0, amount1In, amount0In) AS token_sold_amount_raw
    , IF(amount0Out = 0, token1, token0) AS token_bought_address
    , IF(amount0In = 0, token1, token0) AS token_sold_address
    , to AS taker
    , CAST(NULL AS VARBINARY) AS maker
    , contract_address AS project_contract_address
    , evt_tx_hash AS tx_hash
    , evt_index
FROM base
LEFT JOIN pools ON pool = contract_address 
