
with order_categories as (

    select distinct
        oi.order_id,
        coalesce(t.product_category_name_english, p.product_category_name, 'uncategorized') as product_category

    from {{ ref('stg_order_items') }} oi
    left join {{ ref('stg_products') }} p
        on oi.product_id = p.product_id
    left join {{ ref('stg_product_category_translation') }} t
        on p.product_category_name = t.product_category_name

),

delivered_orders as (

    select
        order_id,
        timestamp_diff(order_delivered_customer_date, order_purchase_timestamp, day) as delivery_time_days

    from {{ ref('stg_orders') }}
    where order_status = 'delivered'
      and order_delivered_customer_date is not null

),

deduped_reviews as (

    select order_id, review_score
    from (
        select
            order_id,
            review_score,
            row_number() over (partition by order_id order by review_answer_timestamp desc) as rn
        from {{ ref('stg_order_reviews') }}
    )
    where rn = 1

),

final as (

    select
        oc.order_id,
        oc.product_category,
        d.delivery_time_days,
        r.review_score

    from order_categories oc
    inner join delivered_orders d
        on oc.order_id = d.order_id
    left join deduped_reviews r
        on oc.order_id = r.order_id

)

select * from final