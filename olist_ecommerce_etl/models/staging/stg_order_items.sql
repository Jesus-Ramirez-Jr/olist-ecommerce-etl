with source as (
    select *
    from {{ source('olist_ecommerce_raw', 'order_items') }}
),

renamed as (
    select
        -- Identifiers
        cast(order_id as string) as order_id,
        cast(order_item_id as int64) as order_item_id,
        cast(product_id as string) as product_id,
        cast(seller_id as string) as seller_id,
        -- Timestamps / Dates
        cast(shipping_limit_date as timestamp) as shipping_limit_date,
        -- Metrics
        cast(price as float64) as price,
        cast(freight_value as float64) as freight_value
    from source
),

final as (
    select
        -- Composite surrogate primary key for testing grain
        {{ dbt_utils.generate_surrogate_key(['order_id', 'order_item_id']) }} as surrogate_key,
        *
    from renamed
)

select * from final