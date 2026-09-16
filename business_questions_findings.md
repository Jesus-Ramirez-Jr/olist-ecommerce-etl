# Olist E-Commerce ETL — Business Questions & Findings

**Project:** `olist-ecommerce-etl` — end-to-end ETL and analytics pipeline (Python → GCS → BigQuery → dbt) built on the Brazilian E-Commerce Public Dataset (Olist).

Six business questions guide the analytics layer, grouped into two domains: customer retention & loyalty, and product & vendor performance. Each question is answered by a dedicated dbt mart, built one at a time, empirically verified, covered by permanent tests, and documented before moving to the next.

---

## Customer Retention & Loyalty ✅ Domain Complete

### 1. What percentage of customers place more than one order, and how does that repeat rate vary by state? ✅ Complete

**Finding:**
- Overall repeat purchase rate: **3.12%** (2,997 of 96,096 customers placed more than one order)
- By state, limited to states with 1,000+ customers (smaller states showed volatile, unreliable rates and were excluded from the comparison): rates ranged from **1.68% (Ceará)** to **3.43% (Rio de Janeiro)**, with most states clustered tightly between roughly 2.7% and 3.4%
- Ceará stood out as the clear low outlier even after controlling for sample size — a candidate worth further investigation, but *not* a confirmed effect, since no formal significance test has been run against it yet

**Methodology:** `mart_customer_repeat_rate` — one row per unique customer (`customer_unique_id`). The `reordered` flag comes from total order count per customer; the customer's state is attributed from their *first* order specifically (not their most recent), so that the state used to explain repeat behavior is knowable independent of whether the customer went on to reorder.

### 2. Among customers who reorder, how much time typically passes between their first and second order? ✅ Complete

**Finding:**
Among customers who reorder, the median time between their first and second purchase is 27–28 days. The mean duration is substantially higher, at 79.99 days — heavily inflated by a long right tail of extreme reorder delays reaching up to 608 days. The median is the more honest representation of typical behavior.

| Metric | Elapsed Time (Days) |
|---|---|
| Minimum | 0 |
| 25th Percentile | 0 |
| 50th Percentile (Median) | ~27–28 |
| 75th Percentile | 122 |
| Maximum | 608 |

Notably, 30.9% of reordering customers (927 of 2,997) placed their second order on the exact same calendar day as their first. Because this same-day group makes up over a quarter of all reorderers, the 25th percentile is mathematically guaranteed to land at 0 days.

The underlying driver behind these same-day reorders remains unverified — possible explanations include genuine rapid rebuying, cart orders split across multiple sellers, or duplicate order submissions. Further analysis of order item composition would be needed before drawing conclusions about customer intent, but the presence of same-day reorders is a clear structural feature of this distribution, not noise.

**Methodology:** `mart_time_between_orders` — orders are partitioned by `customer_unique_id` and ranked by purchase timestamp using `ROW_NUMBER()`. The result is split into two CTEs: first orders (`order_sequence = 1`) and second orders (`order_sequence = 2`), inner-joined on `customer_unique_id` so only customers with at least two orders survive. Elapsed time is the calendar-day difference between the two timestamps (`TIMESTAMP_DIFF(..., DAY)`), computed across the surviving 2,997 customers.

### 3. Is there a relationship between a customer's review score on their first order and whether they ever order again? ✅ Complete

**Finding:** No meaningful relationship between first-order review score and reorder likelihood — reorder rates across all five scores sit in a tight band (2.85%–3.22%), with no clear trend as review score improves.

| Score | Customers | Reorder Rate |
|---|---|---|
| 1 | 10,995 | 3.15% |
| 2 | 3,033 | 2.93% |
| 3 | 7,859 | 3.03% |
| 4 | 18,497 | 2.85% |
| 5 | 54,976 | 3.22% |

(736 customers whose first order had no review were excluded from this breakdown.)

Most notably, customers who left a 1-star review reorder at nearly the same rate (3.15%) as customers who left a 5-star review (3.22%) — directly counter to the intuitive assumption that a bad first-order experience predicts churn. Scores 2 and 4 show the lowest rates (2.93%, 2.85%), but given sample sizes, these differences are not large enough to treat as confirmed without formal significance testing (not yet run). Working hypothesis: review scores on this platform may often reflect delivery/logistics issues rather than dissatisfaction with the product or marketplace itself — directly testable once question 6 is built.

**Methodology:** `mart_first_order_retention` — one row per unique customer (`customer_unique_id`), joined to a deduplicated reviews table (`stg_order_reviews` had duplicate submissions for 547 orders) scoped specifically to the customer's first order.

---

## Product & Vendor Performance ✅ Domain Complete

### 4. Which product categories drive the most revenue, and does that ranking hold up by order volume instead? ✅ Complete

**Finding:**
Restricted to delivered orders only (97.28% of all order revenue — canceled, unavailable, and in-progress statuses excluded, since this is a static historical extract and those orders' final outcomes are unknown).

At the top of the list, revenue and order-volume rankings are stable: the top 7 categories by revenue (`health_beauty`, `watches_gifts`, `bed_bath_table`, `sports_leisure`, `computers_accessories`, `furniture_decor`, `housewares`) all sit within ±5 places of their order-count rank — the biggest categories are big on both dimensions, so the headline "top categories" answer doesn't change much depending on which metric leads.

The ranking diverges meaningfully in the middle of the pack, driven by price point per order:

| Category (higher revenue rank than volume rank) | Orders | Revenue | Revenue rank | Order-count rank | Avg $/order |
|---|---|---|---|---|---|
| computers | 177 | $218,684.14 | 17 | 46 | ~$1,236 |
| small_appliances_home_oven_and_coffee | 72 | $46,589.56 | 36 | 56 | ~$647 |
| agro_industry_and_commerce | 177 | $70,566.10 | 30 | 46 | ~$399 |
| home_appliances_2 | 227 | $107,953.95 | 27 | 41 | ~$476 |
| fixed_telephony | 212 | $55,315.21 | 33 | 43 | ~$261 |

| Category (higher volume rank than revenue rank) | Orders | Revenue | Revenue rank | Order-count rank | Avg $/order |
|---|---|---|---|---|---|
| books_technical | 256 | $18,702.23 | 50 | 35 | ~$73 |
| drinks | 287 | $21,529.84 | 47 | 33 | ~$75 |
| food | 441 | $28,731.15 | 42 | 29 | ~$65 |
| books_general_interest | 496 | $45,302.15 | 38 | 27 | ~$91 |
| food_drink | 221 | $14,942.88 | 52 | 42 | ~$68 |

`computers`' 29-place shift is the largest in the dataset (74 categories total) but checks out against intuition — a ~$1,236 average order value is exactly what a low-frequency, high-ticket category should look like, not a sign of a data bug.

Two data-quality caveats that affect how this ranking should be read, not just how it was built:
- 610 products carry no category at all and roll up into an `uncategorized` bucket, which ranks **21st by revenue and 19th by order count out of 74 categories** — solidly mid-pack, not a negligible edge case. This is a data completeness gap, not a real product category, and should be called out explicitly whenever this ranking is shown, not presented as if it were a genuine category.
- Two Portuguese category names (`portateis_cozinha_e_preparadores_de_alimentos`, `pc_gamer`) have no English translation in Olist's own source mapping — a known gap in the original dataset, not introduced here. Combined they're 13 products and 0.04% of total revenue, immaterial in dollar terms, and shown under their raw Portuguese names rather than a fabricated translation.

**Methodology:** `mart_category_revenue_and_volume` — one row per product category. Category name resolves via `coalesce(english translation, raw Portuguese name, 'uncategorized')` through `LEFT JOIN`s (order items → products → category translation), so no order item is silently dropped for missing category or translation data. Filtered to `order_status = 'delivered'` only — reconciles to $13,221,498.11, the delivered-only revenue total (vs. $13,591,643.70 across all statuses). `order_count` = distinct delivered orders touching that category; `total_revenue` = sum of order-item price. `revenue_rank` and `order_count_rank` are `RANK() OVER` window functions on each metric, computed on the same grain so the two orderings can be compared directly per category rather than eyeballed across two separately sorted lists.

### 5. Do sellers with the highest revenue also have the best delivery and review performance, or is there a volume/quality tradeoff? ✅ Complete

**Finding:**
No meaningful tradeoff. Analysis restricted to sellers with 10+ delivered orders (1,238 of 2,970 total sellers — 41.7% of sellers, but 90.8% of all delivered-order revenue), since a seller with only a handful of orders can show a misleadingly perfect or poor on-time/review rate purely from small-sample noise.

| Revenue quartile (1 = highest) | Sellers | Revenue range | Avg on-time rate | Avg review score |
|---|---|---|---|---|
| 1 | 310 | $9,070 – $226,988 | 91.67% | 4.12 |
| 2 | 310 | $3,908 – $9,065 | 92.02% | 4.15 |
| 3 | 309 | $1,708 – $3,905 | 91.84% | 4.18 |
| 4 (lowest) | 309 | $263 – $1,689 | 92.82% | 4.24 |

There is a consistent direction — review score rises smoothly and monotonically from 4.12 (highest-revenue quartile) to 4.24 (lowest-revenue quartile), and on-time rate is lowest in quartile 1 and highest in quartile 4, though it dips slightly in quartile 3 rather than moving in a perfectly straight line. So if a bias exists at all, the highest-revenue sellers perform *marginally worse*, not better, on both quality dimensions — the opposite direction from an "excellence drives volume" story.

But the size of that gap is small enough not to call it a real tradeoff: a 1.15-percentage-point spread in on-time rate (91.67% to 92.82%) and a 0.12-point spread in review score (4.12 to 4.24 out of 5) across the entire revenue distribution. This is confirmed directly, not just inferred from quartile averaging: `CORR(total_revenue, on_time_rate) = -0.023` and `CORR(total_revenue, avg_review_score) = -0.046` across all 1,238 qualifying sellers — both correlations are effectively zero. Average delivery timing (`avg_days_early`, ~11.1–11.5 days across every quartile) is flat as well.

**Bottom line:** high-revenue sellers are not sacrificing delivery reliability or customer satisfaction to achieve volume. There's a faint, consistent directional lean the other way (bigger sellers score marginally lower on both dimensions), but at this effect size it would overstate the data to frame it as a genuine tradeoff rather than a near-negligible signal.

**Methodology:** `mart_seller_performance` — one row per seller with at least one delivered order (2,970 total). Built by first collapsing `stg_order_items` to `(order_id, seller_id)` grain (summing price per seller per order, so a seller with multiple line items on one order isn't double-counted), inner-joined to delivered orders only (`order_status = 'delivered'`, consistent with question 4's revenue definition), left-joined to a deduplicated `stg_order_reviews` (same dedup pattern as question 3 — `ROW_NUMBER()` partitioned by `order_id`, ordered by `review_answer_timestamp DESC`, keeping rank 1). `on_time_rate` = share of that seller's delivered orders where `order_delivered_customer_date <= order_estimated_delivery_date`; `avg_review_score` excludes orders with no review (5 of 2,970 sellers have zero reviewed orders). `meets_min_order_threshold` flags sellers with 10+ delivered orders — the threshold was chosen empirically by checking the seller order-count distribution first (median 7 orders, mean 32.9, heavily right-skewed; 18% of sellers have exactly 1 order) and picking the point that dropped the most low-volume/low-signal sellers for the smallest revenue cost (10+ orders keeps 90.8% of revenue vs. 96.0% at a 5+ threshold).

**Known data limitation:** on-time delivery and review score are order-level facts in the source data, not seller-level. When an order contains items from more than one seller, every seller on that order inherits the same delivery outcome and the same review score, even though only one seller may have been responsible for what went right or wrong. This is a real constraint of the Olist dataset, not something the mart's join logic can resolve, and applies to this finding across the board.

### 6. Is there a relationship between delivery time and review score, and does it hold across product categories? ✅ Complete

**Finding:**
Yes — delivery time and review score are meaningfully related, and the relationship holds in every product category with enough data to check, though its strength varies by category.

Overall correlation: **-0.3285** across 97,268 order-category rows (96,470 delivered orders, after excluding 8 orders with a missing delivery date — 0.008% of delivered orders, a source data-quality gap rather than a build defect). This is a real, moderate relationship — the strongest of any correlation found in this project so far, and a sharp contrast to question 5's near-zero seller revenue/quality correlations (-0.02 to -0.05).

Restricting to the 63 of 74 product categories with 30 or more orders (a floor chosen because a correlation computed on fewer data points is dominated by noise — this cutoff still covers 99.81% of qualifying order volume), every one of the 63 categories shows a negative correlation. None flip positive — the direction of the relationship is universal wherever there's enough data to check it.

The strength of the relationship varies meaningfully by category, from -0.15 (`costruction_tools_tools`) to -0.62 (`fashion_underwear_beach`) — roughly a 4x spread. This spread was checked against sample size as a possible confound (`corr(n, |category correlation|) = -0.001`, essentially zero) and does not appear to be a sample-size artifact — it looks like a real difference between categories. As a sanity check on the overall number, the four largest categories by volume (`bed_bath_table`, `health_beauty`, `sports_leisure`, `computers_accessories` — together about a third of the mart) all land between -0.32 and -0.38, tightly clustered around the overall -0.3285, confirming the aggregate figure reflects the typical order rather than being skewed by an unrepresentative slice.

This connects directly to question 3's finding: a customer's first-order review score had no relationship to whether they reordered, which was counterintuitive on its face. This result offers a plausible explanation — a meaningful share of low review scores may reflect delivery/logistics frustration rather than dissatisfaction with the product or marketplace itself, which would explain why a bad first-order review didn't predict churn the way genuine product/marketplace dissatisfaction would.

**Caveats:** This is a correlation, not a causal claim — a slow delivery plausibly causes a lower review score, but both could also share a root cause (an unreliable seller or a difficult shipping region) not tested here. Also, `delivery_time_days` and `review_score` are order-level facts; on the roughly 0.8% of delivered orders spanning more than one product category, every category on that order shows the identical value — the same order-level-fact limitation disclosed in question 5's seller analysis.

**Methodology:** `mart_delivery_time_review_score` — one row per `(order_id, product_category)` pair, for delivered orders with a non-null `order_delivered_customer_date`. Product categories come from order items joined through products to the category translation table, using the same `coalesce(English name, raw Portuguese name, 'uncategorized')` fallback chain as question 4. Delivery time is `order_purchase_timestamp` to `order_delivered_customer_date` in elapsed calendar days — the customer's actual wait, not lateness relative to the estimated delivery date (that comparison is question 5's `on_time_flag`). Review score is deduplicated to each order's most recent review submission, same pattern as questions 3 and 5.

---

## Tech Stack

Python (extraction) · Google Cloud Storage (raw landing zone) · BigQuery (warehouse) · dbt-core 1.12.0 / dbt-bigquery 1.12.0 (transformation, testing, documentation) · GitHub for version control
