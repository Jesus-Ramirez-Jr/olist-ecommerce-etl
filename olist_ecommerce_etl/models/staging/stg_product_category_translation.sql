with source as (
    select *
    from {{ source('olist_ecommerce_raw', 'product_category_translation') }}
),

renamed as (
    select
        -- Identifiers
        cast(product_category_name as string) as product_category_name,
        -- Attributes
        cast(product_category_name_english as string) as product_category_name_english
    from source
)

select * from renamed