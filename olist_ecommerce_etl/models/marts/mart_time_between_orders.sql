

with orders_ranked as (

    select
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        row_number() over (
            partition by c.customer_unique_id
            order by o.order_purchase_timestamp
        ) as order_sequence
    from {{ ref('stg_orders') }} o
    left join {{ ref('stg_customers') }} c
        on o.customer_id = c.customer_id

),

first_orders as (

    select
        customer_unique_id,
        order_id,
        order_purchase_timestamp
    from orders_ranked
    where order_sequence = 1

),

second_orders as (

    select
        customer_unique_id,
        order_id,
        order_purchase_timestamp
    from orders_ranked
    where order_sequence = 2

)

    select
        f.customer_unique_id as customer_unique_id,
        f.order_id as first_order_id,
        f.order_purchase_timestamp as first_order_timestamp,
        s.order_id as second_order_id,
        s.order_purchase_timestamp as second_order_timestamp,
        TIMESTAMP_DIFF(s.order_purchase_timestamp, f.order_purchase_timestamp, day) as days_between_orders
    from first_orders f
    inner join second_orders s ON f.customer_unique_id = s.customer_unique_id