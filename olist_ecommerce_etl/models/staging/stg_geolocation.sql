with source as (
    select *
    from {{ source('olist_ecommerce_raw', 'geolocation') }}
),

renamed as (
    select
        -- Identifiers
        cast(geolocation_zip_code_prefix as int64) as geolocation_zip_code_prefix,
        -- Coordinates
        cast(geolocation_lat as float64) as geolocation_lat,
        cast(geolocation_lng as float64) as geolocation_lng,
        -- Attributes
        cast(geolocation_city as string) as geolocation_city,
        cast(geolocation_state as string) as geolocation_state
    from source
)

select * from renamed