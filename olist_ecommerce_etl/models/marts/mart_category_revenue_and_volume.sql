with order_items_categorized as (

    select
        oi.order_id,
        oi.price,
        coalesce(t.product_category_name_english, p.product_category_name, 'uncategorized') as product_category_name_english

    from {{ ref('stg_order_items') }} oi
    inner join {{ ref('stg_orders') }} o
        on oi.order_id = o.order_id
    left join {{ ref('stg_products') }} p
        on oi.product_id = p.product_id
    left join {{ ref('stg_product_category_translation') }} t
        on p.product_category_name = t.product_category_name

    where o.order_status = 'delivered'

)

select
    product_category_name_english,
    count(distinct order_id) as order_count,
    round(sum(price), 2) as total_revenue,
    rank() over (order by sum(price) desc) as revenue_rank,
    rank() over (order by count(distinct order_id) desc) as order_count_rank

from order_items_categorized
group by 1
order by total_revenue desc