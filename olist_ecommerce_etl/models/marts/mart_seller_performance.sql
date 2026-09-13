with order_items_by_seller as (

    select
        order_id,
        seller_id,
        sum(price) as seller_order_revenue
    from {{ ref('stg_order_items') }}
    group by order_id, seller_id

),

delivered_orders as (

    select
        order_id,
        order_delivered_customer_date,
        order_estimated_delivery_date
    from {{ ref('stg_orders') }}
    where order_status = 'delivered'

),

deduped_reviews as (

    select order_id, review_score
    from (
        select
            order_id,
            review_score,
            row_number() over (
                partition by order_id
                order by review_answer_timestamp desc
            ) as review_rank
        from {{ ref('stg_order_reviews') }}
    )
    where review_rank = 1

),

order_seller_grain as (

    select
        ois.order_id,
        ois.seller_id,
        ois.seller_order_revenue,
        case
            when do.order_delivered_customer_date <= do.order_estimated_delivery_date
                then 1 else 0
        end as on_time_flag,
        timestamp_diff(
            do.order_estimated_delivery_date,
            do.order_delivered_customer_date,
            day
        ) as days_early,
        dr.review_score
    from order_items_by_seller ois
    inner join delivered_orders do
        on ois.order_id = do.order_id
    left join deduped_reviews dr
        on ois.order_id = dr.order_id

),

seller_aggregates as (

    select
        seller_id,
        count(distinct order_id) as delivered_order_count,
        round(sum(seller_order_revenue), 2) as total_revenue,
        round(avg(on_time_flag), 4) as on_time_rate,
        round(avg(days_early), 1) as avg_days_early,
        round(avg(review_score), 2) as avg_review_score,
        count(review_score) as reviewed_order_count
    from order_seller_grain
    group by seller_id

)

select
    seller_id,
    delivered_order_count,
    total_revenue,
    on_time_rate,
    avg_days_early,
    avg_review_score,
    reviewed_order_count,
    delivered_order_count >= 10 as meets_min_order_threshold,
    rank() over (order by total_revenue desc) as revenue_rank
from seller_aggregates