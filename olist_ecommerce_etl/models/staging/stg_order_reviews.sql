with source as (

    select * 
    from {{ source('olist_ecommerce_raw', 'order_reviews') }}

),

renamed as (

    select
        -- Identifiers
        cast(review_id as string) as review_id,
        cast(order_id as string) as order_id,

        -- Metrics / Attributes
        cast(review_score as integer) as review_score,
        nullif(trim(review_comment_title), '') as review_comment_title,
        nullif(trim(review_comment_message), '') as review_comment_message,

        -- Timestamps / Dates
        cast(review_creation_date as date) as review_creation_date,
        cast(review_answer_timestamp as timestamp) as review_answer_timestamp

    from source

),

final as (

    select
        -- Composite surrogate primary key for testing grain
        {{ dbt_utils.generate_surrogate_key(['review_id', 'order_id']) }} as surrogate_key,

        *

    from renamed

)

select * from final