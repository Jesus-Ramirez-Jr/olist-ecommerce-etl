with source as (
    select *
    from {{ source('olist_ecommerce_raw', 'products') }}
),

renamed as (
    select
        -- Identifiers
        cast(product_id as string) as product_id,
        -- Attributes
        cast(product_category_name as string) as product_category_name,
        cast(product_name_lenght as int64) as product_name_length,
        cast(product_description_lenght as int64) as product_description_length,
        cast(product_photos_qty as int64) as product_photos_qty,
        cast(product_weight_g as int64) as product_weight_g,
        cast(product_length_cm as int64) as product_length_cm,
        cast(product_height_cm as int64) as product_height_cm,
        cast(product_width_cm as int64) as product_width_cm
    from source
)

select * from renamed