with source as (
    select *
    from {{ source('olist_ecommerce_raw', 'customers') }}
),

renamed as (
    select
        -- Identifiers
        cast(customer_id as string) as customer_id,
        cast(customer_unique_id as string) as customer_unique_id,
        cast(customer_zip_code_prefix as int64) as customer_zip_code_prefix,
        -- Attributes
        cast(customer_city as string) as customer_city,
        cast(customer_state as string) as customer_state
    from source
)

select * from renamed