-- models/marts/mart_customer_repeat_rate.sql

with orders_with_customer as (

    select
        o.order_id,
        o.order_purchase_timestamp,
        c.customer_unique_id,
        c.customer_state

    from {{ ref('stg_orders') }} as o
    inner join {{ ref('stg_customers') }} as c
        on o.customer_id = c.customer_id

),

orders_ranked as (

    select
        *,
        row_number() over (
            partition by customer_unique_id
            order by order_purchase_timestamp asc
        ) as order_rank,
        count(*) over (
            partition by customer_unique_id
        ) as total_orders

    from orders_with_customer

)

select
    customer_unique_id,
    customer_state as first_order_state,
    total_orders > 1 as reordered

from orders_ranked
where order_rank = 1