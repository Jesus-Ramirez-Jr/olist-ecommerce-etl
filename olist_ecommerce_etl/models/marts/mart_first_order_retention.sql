-- models/marts/mart_first_order_retention.sql

with orders_ranked as (

    select
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        row_number() over (
            partition by c.customer_unique_id
            order by o.order_purchase_timestamp
        ) as order_sequence,
        count(*) over (
            partition by c.customer_unique_id
        ) as total_orders
    from {{ ref('stg_orders') }} o
    left join {{ ref('stg_customers') }} c
        on o.customer_id = c.customer_id

),

first_orders as (

    select
        customer_unique_id,
        order_id,
        total_orders,
        total_orders > 1 as reordered
    from orders_ranked
    where order_sequence = 1

),

reviews_deduped as (

    select
        order_id,
        review_score,
        row_number() over (
            partition by order_id
            order by review_answer_timestamp desc
        ) as review_rank
    from {{ ref('stg_order_reviews') }}

),

latest_review_per_order as (

    select
        order_id,
        review_score
    from reviews_deduped
    where review_rank = 1

)

select
    fo.customer_unique_id,
    fo.reordered,
    r.review_score as first_order_review_score
from first_orders fo
left join latest_review_per_order r
    on fo.order_id = r.order_id