with source as (
    select *
    from {{ source('olist_ecommerce_raw', 'order_payments') }}
),

renamed as (
    select
        -- Identifiers
        cast(order_id as string) as order_id,
        cast(payment_sequential as int64) as payment_sequential,
        cast(payment_type as string) as payment_type,
        -- Metrics
        cast(payment_installments as int64) as payment_installments,
        cast(payment_value as float64) as payment_value
    from source
),

final as (
    select
        -- Composite surrogate primary key for testing grain
        {{ dbt_utils.generate_surrogate_key(['order_id', 'payment_sequential']) }} as surrogate_key,
        *
    from renamed
)

select * from final