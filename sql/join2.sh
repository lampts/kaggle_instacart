bq query --max_rows 1  --allow_large_results --destination_table "work.tmp1" --flatten_results --replace "
SELECT
  user_id,
  order_id,
  eval_set,
  order_number,
  days_since_prior_order,
  SUM(days_since_prior_order) OVER (PARTITION BY user_id ORDER BY order_number ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_days
FROM
  [instacart.orders]
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.cum_orders" --flatten_results --replace "
SELECT
  a.user_id user_id,
  a.order_id order_id,
  a.eval_set eval_set,
  a.order_number order_number,
  a.days_since_prior_order days_since_prior_order,
  a.cum_days cum_days,
  b.max_cum_days max_cum_days,
  b.max_cum_days - a.cum_days as last_buy
FROM
  [work.tmp1] as a
LEFT OUTER JOIN
(
SELECT
  user_id, max(cum_days) as max_cum_days
FROM
  [work.tmp1]
GROUP BY
  user_id
) as b
ON
  a.user_id = b.user_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.only_rebuy" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.product_id as product_id
FROM
  [instacart.df_prior] as a
GROUP BY
  user_id, product_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.only_rebuy_train" --flatten_results --replace "
SELECT
  r.user_id as user_id,
  r.product_id as product_id,
  o.order_id as order_id,
  o.order_number as order_number,
  o.order_dow as order_dow,
  o.order_hour_of_day as order_hour_of_day,
  o.days_since_prior_order as days_since_prior_order,
  c.cum_days as cum_days
FROM
  [instacart.only_rebuy] as r
INNER JOIN
  (SELECT * FROM [instacart.orders] WHERE eval_set='train') as o
ON
  r.user_id = o.user_id
LEFT OUTER JOIN
  [instacart.cum_orders] as c
ON
  c.order_id = o.order_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.only_rebuy_test" --flatten_results --replace "
SELECT
  r.user_id as user_id,
  r.product_id as product_id,
  o.order_id as order_id,
  o.order_number as order_number,
  o.order_dow as order_dow,
  o.order_hour_of_day as order_hour_of_day,
  o.days_since_prior_order as days_since_prior_order,
  c.cum_days as cum_days
FROM
  [instacart.only_rebuy] as r
INNER JOIN
  (SELECT * FROM [instacart.orders] WHERE eval_set='test') as o
ON
  r.user_id = o.user_id
LEFT OUTER JOIN
  [instacart.cum_orders] as c
ON
  c.order_id = o.order_id
"

###

bq query --max_rows 1  --allow_large_results --destination_table "instacart.last_buy" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  a.max_order_number as max_order_number,
  a.max_reordered as max_reordered,
  a.avg_reordered as avg_reordered,
  o.order_id,
  c.cum_days as cum_days,
  o.order_number,
  o.order_dow,
  o.order_hour_of_day,
  o.days_since_prior_order
FROM
  (
  SELECT
    user_id,
    product_id,
    max(reordered) as max_reordered,
    avg(reordered) as avg_reordered,
    MAX(order_number) as max_order_number
  FROM
    [instacart.df_prior]
  GROUP BY
    user_id,
    product_id
  ) as a
LEFT OUTER JOIN
  [instacart.orders] as o
ON
  a.user_id = o.user_id AND
  a.max_order_number = o.order_number
LEFT OUTER JOIN
  [instacart.cum_orders] as c
ON
  c.order_id = o.order_id
"


bq query --max_rows 1  --allow_large_results --destination_table "instacart.last_buy_aisle" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.aisle_id as aisle_id,
  a.max_order_number as max_order_number,
  a.max_reordered as max_reordered,
  a.avg_reordered as avg_reordered,
  o.order_id,
  c.cum_days as cum_days,
  o.order_number,
  o.order_dow,
  o.order_hour_of_day,
  o.days_since_prior_order
FROM
  (
  SELECT
    user_id,
    aisle_id,
    max(reordered) as max_reordered,
    avg(reordered) as avg_reordered,
    MAX(order_number) as max_order_number
  FROM
    [instacart.df_prior]
  GROUP BY
    user_id,
    aisle_id
  ) as a
LEFT OUTER JOIN
  [instacart.orders] as o
ON
  a.user_id = o.user_id AND
  a.max_order_number = o.order_number
LEFT OUTER JOIN
  [instacart.cum_orders] as c
ON
  c.order_id = o.order_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.last_buy_depart" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.department_id as department_id,
  a.max_order_number as max_order_number,
  a.max_reordered as max_reordered,
  a.avg_reordered as avg_reordered,
  o.order_id,
  c.cum_days as cum_days,
  o.order_number,
  o.order_dow,
  o.order_hour_of_day,
  o.days_since_prior_order
FROM
  (
  SELECT
    user_id,
    department_id,
    max(reordered) as max_reordered,
    avg(reordered) as avg_reordered,
    MAX(order_number) as max_order_number
  FROM
    [instacart.df_prior]
  GROUP BY
    user_id,
    department_id
  ) as a
LEFT OUTER JOIN
  [instacart.orders] as o
ON
  a.user_id = o.user_id AND
  a.max_order_number = o.order_number
LEFT OUTER JOIN
  [instacart.cum_orders] as c
ON
  c.order_id = o.order_id
"

###


###

bq query --max_rows 1  --allow_large_results --destination_table "instacart.last_buy_2" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  a.max_order_number as max_order_number,
  a.max_reordered as max_reordered,
  a.avg_reordered as avg_reordered,
  o.order_id,
  c.cum_days as cum_days,
  o.order_number,
  o.order_dow,
  o.order_hour_of_day,
  o.days_since_prior_order
FROM
  (
  SELECT
    user_id,
    product_id,
    max(reordered) as max_reordered,
    avg(reordered) as avg_reordered,
    MAX(order_number) - 1 as max_order_number
  FROM
    [instacart.df_prior]
  GROUP BY
    user_id,
    product_id
  ) as a
LEFT OUTER JOIN
  [instacart.orders] as o
ON
  a.user_id = o.user_id AND
  a.max_order_number = o.order_number
LEFT OUTER JOIN
  [instacart.cum_orders] as c
ON
  c.order_id = o.order_id
"


bq query --max_rows 1  --allow_large_results --destination_table "instacart.last_buy_aisle_2" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.aisle_id as aisle_id,
  a.max_order_number as max_order_number,
  a.max_reordered as max_reordered,
  a.avg_reordered as avg_reordered,
  o.order_id,
  c.cum_days as cum_days,
  o.order_number,
  o.order_dow,
  o.order_hour_of_day,
  o.days_since_prior_order
FROM
  (
  SELECT
    user_id,
    aisle_id,
    max(reordered) as max_reordered,
    avg(reordered) as avg_reordered,
    MAX(order_number) - 1 as max_order_number
  FROM
    [instacart.df_prior]
  GROUP BY
    user_id,
    aisle_id
  ) as a
LEFT OUTER JOIN
  [instacart.orders] as o
ON
  a.user_id = o.user_id AND
  a.max_order_number = o.order_number
LEFT OUTER JOIN
  [instacart.cum_orders] as c
ON
  c.order_id = o.order_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.last_buy_depart_2" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.department_id as department_id,
  a.max_order_number as max_order_number,
  a.max_reordered as max_reordered,
  a.avg_reordered as avg_reordered,
  o.order_id,
  c.cum_days as cum_days,
  o.order_number,
  o.order_dow,
  o.order_hour_of_day,
  o.days_since_prior_order
FROM
  (
  SELECT
    user_id,
    department_id,
    max(reordered) as max_reordered,
    avg(reordered) as avg_reordered,
    MAX(order_number) - 1 as max_order_number
  FROM
    [instacart.df_prior]
  GROUP BY
    user_id,
    department_id
  ) as a
LEFT OUTER JOIN
  [instacart.orders] as o
ON
  a.user_id = o.user_id AND
  a.max_order_number = o.order_number
LEFT OUTER JOIN
  [instacart.cum_orders] as c
ON
  c.order_id = o.order_id
"

###





bq query --max_rows 1  --allow_large_results --destination_table "instacart.dmt_user_item_30" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  count(1) cnt_user_item,
  count(distinct a.order_id) cnt_user_order,
  avg(a.order_hour_of_day) avg_order_hour_of_day,
  min(a.order_hour_of_day) min_order_hour_of_day,
  max(a.order_hour_of_day) max_order_hour_of_day,
  max(a.reordered) max_reordered,
  sum(a.reordered) sum_reordered,
  avg(a.reordered) avg_reordered,
  AVG(a.days_since_prior_order) as avg_days_since_prior_order,
  MAX(a.days_since_prior_order) as max_days_since_prior_order,
  MIN(a.days_since_prior_order) as min_days_since_prior_order,
  sum(CASE WHEN a.order_dow = 0  THEN 1 ELSE 0 END) AS  order_dow_0,
  sum(CASE WHEN a.order_dow = 1  THEN 1 ELSE 0 END) AS  order_dow_1,
  sum(CASE WHEN a.order_dow = 2  THEN 1 ELSE 0 END) AS  order_dow_2,
  sum(CASE WHEN a.order_dow = 3  THEN 1 ELSE 0 END) AS  order_dow_3,
  sum(CASE WHEN a.order_dow = 4  THEN 1 ELSE 0 END) AS  order_dow_4,
  sum(CASE WHEN a.order_dow = 5  THEN 1 ELSE 0 END) AS  order_dow_5,
  sum(CASE WHEN a.order_dow = 6  THEN 1 ELSE 0 END) AS  order_dow_6,
  avg(CASE WHEN a.order_dow = 0  THEN a.reordered ELSE null END) AS  reorder_dow_0,
  avg(CASE WHEN a.order_dow = 1  THEN a.reordered ELSE null END) AS  reorder_dow_1,
  avg(CASE WHEN a.order_dow = 2  THEN a.reordered ELSE null END) AS  reorder_dow_2,
  avg(CASE WHEN a.order_dow = 3  THEN a.reordered ELSE null END) AS  reorder_dow_3,
  avg(CASE WHEN a.order_dow = 4  THEN a.reordered ELSE null END) AS  reorder_dow_4,
  avg(CASE WHEN a.order_dow = 5  THEN a.reordered ELSE null END) AS  reorder_dow_5,
  avg(CASE WHEN a.order_dow = 6  THEN a.reordered ELSE null END) AS  reorder_dow_6
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
GROUP BY
  user_id, product_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.dmt_user_aisle_30" --flatten_results --replace "
SELECT
  a.user_id as user_id,
  a.aisle_id as aisle_id,
  count(1) cnt_user_aisle,
  count(distinct a.order_id) cnt_aisle_order,
  count(distinct a.product_id) cnt_product_order,
  max(a.reordered) max_reordered,
  sum(a.reordered) sum_reordered,
  avg(a.reordered) avg_reordered
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
GROUP BY
  user_id, aisle_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.dmt_user_depart_30" --flatten_results --replace "
SELECT
  a.user_id user_id,
  a.department_id department_id,
  count(1) cnt_user_depart,
  count(distinct a.order_id) cnt_depart_order,
  count(distinct a.product_id) cnt_product_order,
  count(distinct a.aisle_id) cnt_aisle_order,
  max(a.reordered) max_reordered,
  sum(a.reordered) sum_reordered,
  avg(a.reordered) avg_reordered
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
GROUP BY
  user_id, department_id
"
###


###
bq query --max_rows 1  --allow_large_results --destination_table "instacart.dmt_user_item" --flatten_results --replace "
SELECT
  user_id,
  product_id,
  count(1) cnt_user_item,
  count(distinct order_id) cnt_user_order,
  avg(order_hour_of_day) avg_order_hour_of_day,
  min(order_hour_of_day) min_order_hour_of_day,
  max(order_hour_of_day) max_order_hour_of_day,
  max(reordered) max_reordered,
  sum(reordered) sum_reordered,
  avg(reordered) avg_reordered,
  AVG(days_since_prior_order) as avg_days_since_prior_order,
  MAX(days_since_prior_order) as max_days_since_prior_order,
  MIN(days_since_prior_order) as min_days_since_prior_order,
  AVG(order_dow) as avg_order_dow,
  MAX(order_dow) as max_order_dow,
  MIN(order_dow) as min_order_dow,
  sum(CASE WHEN order_dow = 0  THEN 1 ELSE 0 END) AS  order_dow_0,
  sum(CASE WHEN order_dow = 1  THEN 1 ELSE 0 END) AS  order_dow_1,
  sum(CASE WHEN order_dow = 2  THEN 1 ELSE 0 END) AS  order_dow_2,
  sum(CASE WHEN order_dow = 3  THEN 1 ELSE 0 END) AS  order_dow_3,
  sum(CASE WHEN order_dow = 4  THEN 1 ELSE 0 END) AS  order_dow_4,
  sum(CASE WHEN order_dow = 5  THEN 1 ELSE 0 END) AS  order_dow_5,
  sum(CASE WHEN order_dow = 6  THEN 1 ELSE 0 END) AS  order_dow_6,
  avg(CASE WHEN order_dow = 0  THEN reordered ELSE null END) AS  reorder_dow_0,
  avg(CASE WHEN order_dow = 1  THEN reordered ELSE null END) AS  reorder_dow_1,
  avg(CASE WHEN order_dow = 2  THEN reordered ELSE null END) AS  reorder_dow_2,
  avg(CASE WHEN order_dow = 3  THEN reordered ELSE null END) AS  reorder_dow_3,
  avg(CASE WHEN order_dow = 4  THEN reordered ELSE null END) AS  reorder_dow_4,
  avg(CASE WHEN order_dow = 5  THEN reordered ELSE null END) AS  reorder_dow_5,
  avg(CASE WHEN order_dow = 6  THEN reordered ELSE null END) AS  reorder_dow_6
FROM
  [instacart.df_prior]
GROUP BY
  user_id, product_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.dmt_user_aisle" --flatten_results --replace "
SELECT
  user_id,
  aisle_id,
  count(1) cnt_user_aisle,
  count(distinct order_id) cnt_aisle_order,
  count(distinct product_id) cnt_product_order,
  avg(order_hour_of_day) avg_order_hour_of_day,
  min(order_hour_of_day) min_order_hour_of_day,
  max(order_hour_of_day) max_order_hour_of_day,
  AVG(days_since_prior_order) as avg_days_since_prior_order,
  MAX(days_since_prior_order) as max_days_since_prior_order,
  MIN(days_since_prior_order) as min_days_since_prior_order,
  AVG(order_dow) as avg_order_dow,
  MAX(order_dow) as max_order_dow,
  MIN(order_dow) as min_order_dow,
  max(reordered) max_reordered,
  sum(reordered) sum_reordered,
  avg(reordered) avg_reordered
FROM
  [instacart.df_prior]
GROUP BY
  user_id, aisle_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.dmt_user_depart" --flatten_results --replace "
SELECT
  user_id,
  department_id,
  count(1) cnt_user_depart,
  count(distinct order_id) cnt_depart_order,
  count(distinct product_id) cnt_product_order,
  count(distinct aisle_id) cnt_aisle_order,
  avg(order_hour_of_day) avg_order_hour_of_day,
  min(order_hour_of_day) min_order_hour_of_day,
  max(order_hour_of_day) max_order_hour_of_day,
  AVG(days_since_prior_order) as avg_days_since_prior_order,
  MAX(days_since_prior_order) as max_days_since_prior_order,
  MIN(days_since_prior_order) as min_days_since_prior_order,
  AVG(order_dow) as avg_order_dow,
  MAX(order_dow) as max_order_dow,
  MIN(order_dow) as min_order_dow,
  max(reordered) max_reordered,
  sum(reordered) sum_reordered,
  avg(reordered) avg_reordered
FROM
  [instacart.df_prior]
GROUP BY
  user_id, department_id
"

bq query --max_rows 1  --allow_large_results --destination_table "instacart.user_cart_30" --flatten_results --replace "
SELECT
  user_id,
  count(1) as cnt_order_num,
  avg(cnt_order) as cnt_cart_num,
  avg(cnt_item) as avg_cnt_item,
  avg(cnt_aisle) as avg_cnt_aisle,
  avg(cnt_depart) as avg_cnt_depart,
  avg(sum_reordered) as avg_sum_reordered,
  sum(sum_reordered) as sum_reordered,
  avg(avg_reordered) as avg_reordered,
  avg(order_dow) as order_dow,
  avg(order_hour_of_day) as order_hour_of_day,
  avg(days_since_prior_order) as days_since_prior_order
FROM
(
SELECT
  a.user_id as user_id,
  a.order_id as order_id,
  count(1) cnt_order,
  count(distinct a.product_id) cnt_item,
  count(distinct a.aisle_id) cnt_aisle,
  count(distinct a.department_id) cnt_depart,
  sum(a.reordered) sum_reordered,
  avg(a.reordered) avg_reordered,
  avg(a.order_dow) as order_dow,
  avg(a.order_hour_of_day) as order_hour_of_day,
  avg(a.days_since_prior_order) as days_since_prior_order
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
GROUP BY
  user_id, order_id
)
GROUP BY
  user_id
"

###
bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user_item_30" --flatten_results --replace "
SELECT
  user_id,
  product_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.product_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
) as s
GROUP BY
  user_id, product_id
"


bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user_item" --flatten_results --replace "
SELECT
  user_id,
  product_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.product_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
) as s
GROUP BY
  user_id, product_id
"
###

###
bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user_aisle_30" --flatten_results --replace "
SELECT
  user_id,
  aisle_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.aisle_id as aisle_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.aisle_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
) as s
GROUP BY
  user_id, aisle_id
"


bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user_aisle" --flatten_results --replace "
SELECT
  user_id,
  aisle_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.aisle_id as aisle_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.aisle_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
) as s
GROUP BY
  user_id, aisle_id
"
###

###
bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user_depart_30" --flatten_results --replace "
SELECT
  user_id,
  department_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.department_id as department_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.department_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
) as s
GROUP BY
  user_id, department_id
"


bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user_depart" --flatten_results --replace "
SELECT
  user_id,
  department_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.department_id as department_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.department_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
) as s
GROUP BY
  user_id, department_id
"
###

bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user_30" --flatten_results --replace "
SELECT
  user_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.product_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
) as s
GROUP BY
  user_id
"

bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user" --flatten_results --replace "
SELECT
  user_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.product_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
) as s
GROUP BY
  user_id
"

###


bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_item_30" --flatten_results --replace "
SELECT
  product_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.product_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30
) as s
GROUP BY
  product_id
"

bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_item" --flatten_results --replace "
SELECT
  product_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.product_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
) as s
GROUP BY
  product_id
"

bq query --max_rows 20  --allow_large_results --destination_table "instacart.diff_user_item_reordered_30" --flatten_results --replace "
SELECT
  user_id,
  product_id,
  CASE WHEN avg(diffs - last_buy) is not NULL THEN avg(diffs - last_buy) ELSE -1 END as avg_diffs,
  CASE WHEN min(diffs - last_buy) is not NULL THEN min(diffs - last_buy) ELSE -1 END as min_diffs,
  CASE WHEN max(diffs - last_buy) is not NULL THEN max(diffs - last_buy) ELSE -1 END as max_diffs  
FROM
(
SELECT
  a.user_id as user_id,
  a.product_id as product_id,
  LAG(b.last_buy, 1) OVER (PARTITION BY a.user_id, a.product_id ORDER BY a.order_number) as diffs,
  b.last_buy as last_buy
FROM
  [instacart.df_prior] as a
LEFT OUTER JOIN
  [instacart.cum_orders] as b
ON
  a.order_id = b.order_id
WHERE
  b.last_buy <= 30 and reordered = 1
) as s
GROUP BY
  user_id, product_id
"



bq query --max_rows 1  --maximum_billing_tier 3 --allow_large_results --destination_table "instacart.dmt_train_only_rebuy" --flatten_results --replace "
SELECT
  CASE WHEN tr.reordered is not null THEN tr.reordered ELSE 0 END as target,
  o.user_id,
  p.aisle_id,
  p.department_id,
  o.product_id,
  o.order_id,
  o.order_number,
  o.order_dow,
  o.order_hour_of_day,
  o.days_since_prior_order,
  o.cum_days,
  du.*,
  dui3.*,
  dd.*,
  du3.*,
  dd3.*,
  udd.*,
  udd3.*,
  di.*,
  di3.*,
  u.*,
  uc.*,
  i.*,
  l.*,
  la.*,
  ld.*,
  l2.*,
  la2.*,
  ld2.*,
  ui.*,
  ua.*,
  ud.*,
  ui3.*,
  ua3.*,
  ud3.*
FROM
  [instacart.only_rebuy_train] as o
LEFT OUTER JOIN
  [instacart.products] as p
ON
  o.product_id = p.product_id
LEFT OUTER JOIN
  [instacart.diff_user_item] as du
ON
  du.user_id = o.user_id AND  o.product_id = du.product_id
LEFT OUTER JOIN
  [instacart.diff_user_item_reordered_30] as dui3
ON
  dui3.user_id = o.user_id AND  o.product_id = dui3.product_id
LEFT OUTER JOIN
  [instacart.diff_user_depart] as dd
ON
  dd.user_id = o.user_id AND  p.product_id = dd.department_id
LEFT OUTER JOIN
  [instacart.diff_user_item_30] as du3
ON
  du3.user_id = o.user_id AND  o.product_id = du3.product_id
LEFT OUTER JOIN
  [instacart.diff_user_depart_30] as dd3
ON
  dd3.user_id = o.user_id AND  p.product_id = dd3.department_id
LEFT OUTER JOIN
  [instacart.diff_user] as udd
ON
  udd.user_id = o.user_id
LEFT OUTER JOIN
  [instacart.diff_user_30] as udd3
ON
  udd3.user_id = o.user_id
LEFT OUTER JOIN
  [instacart.diff_item] as di
ON
  di.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.diff_item_30] as di3
ON
  di3.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.dmt_user] as u
ON
  u.u1_user_id = o.user_id
LEFT OUTER JOIN
  [instacart.user_cart_30] as uc
ON
  uc.user_id = o.user_id
LEFT OUTER JOIN
  [instacart.dmt_item] as i
ON
  i.i1_product_id = o.product_id
LEFT OUTER JOIN
  [instacart.last_buy] as l
ON
  l.user_id = o.user_id AND l.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.last_buy_aisle] as la
ON
  la.user_id = o.user_id AND la.aisle_id = p.aisle_id
LEFT OUTER JOIN
  [instacart.last_buy_depart] as ld
ON
  ld.user_id = o.user_id AND ld.department_id = p.department_id
LEFT OUTER JOIN
  [instacart.last_buy_2] as l2
ON
  l2.user_id = o.user_id AND l2.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.last_buy_aisle_2] as la2
ON
  la2.user_id = o.user_id AND la2.aisle_id = p.aisle_id
LEFT OUTER JOIN
  [instacart.last_buy_depart_2] as ld2
ON
  ld2.user_id = o.user_id AND ld2.department_id = p.department_id
LEFT OUTER JOIN
  [instacart.dmt_user_item] as ui
ON
  ui.user_id = o.user_id AND ui.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.dmt_user_aisle] as ua
ON
  ua.user_id = o.user_id AND ua.aisle_id = p.aisle_id
LEFT OUTER JOIN
  [instacart.dmt_user_depart] as ud
ON
  ud.user_id = o.user_id AND ud.department_id = p.department_id
LEFT OUTER JOIN
  [instacart.dmt_user_item_30] as ui3
ON
  ui3.user_id = o.user_id AND ui3.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.dmt_user_aisle_30] as ua3
ON
  ua3.user_id = o.user_id AND ua3.aisle_id = p.aisle_id
LEFT OUTER JOIN
  [instacart.dmt_user_depart_30] as ud3
ON
  ud3.user_id = o.user_id AND ud3.department_id = p.department_id
LEFT OUTER JOIN
  [instacart.df_train] as tr
ON
  tr.user_id = o.user_id AND tr.product_id = o.product_id AND tr.order_id = o.order_id
"



bq query --maximum_billing_tier 2 --max_rows 1  --allow_large_results --destination_table "instacart.dmt_test_only_rebuy" --flatten_results --replace "
SELECT
  o.user_id,
  p.aisle_id,
  p.department_id,
  o.product_id,
  o.order_id,
  o.order_number,
  o.order_dow,
  o.order_hour_of_day,
  o.days_since_prior_order,
  o.cum_days,
  du.*,
  dui3.*,
  dd.*,
  du3.*,
  dd3.*,
  udd.*,
  udd3.*,
  di.*,
  di3.*,
  u.*,
  uc.*,
  i.*,
  l.*,
  la.*,
  ld.*,
  l2.*,
  la2.*,
  ld2.*,
  ui.*,
  ua.*,
  ud.*,
  ui3.*,
  ua3.*,
  ud3.*
FROM
  [instacart.only_rebuy_test] as o
LEFT OUTER JOIN
  [instacart.products] as p
ON
  o.product_id = p.product_id
LEFT OUTER JOIN
  [instacart.diff_user_item] as du
ON
  du.user_id = o.user_id AND  o.product_id = du.product_id
LEFT OUTER JOIN
  [instacart.diff_user_item_reordered_30] as dui3
ON
  dui3.user_id = o.user_id AND  o.product_id = dui3.product_id
LEFT OUTER JOIN
  [instacart.diff_user_depart] as dd
ON
  dd.user_id = o.user_id AND  p.product_id = dd.department_id
LEFT OUTER JOIN
  [instacart.diff_user_item_30] as du3
ON
  du3.user_id = o.user_id AND  o.product_id = du3.product_id
LEFT OUTER JOIN
  [instacart.diff_user_depart_30] as dd3
ON
  dd3.user_id = o.user_id AND  p.product_id = dd3.department_id
LEFT OUTER JOIN
  [instacart.diff_user] as udd
ON
  udd.user_id = o.user_id
LEFT OUTER JOIN
  [instacart.diff_user_30] as udd3
ON
  udd3.user_id = o.user_id
LEFT OUTER JOIN
  [instacart.diff_item] as di
ON
  di.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.diff_item_30] as di3
ON
  di3.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.dmt_user] as u
ON
  u.u1_user_id = o.user_id
LEFT OUTER JOIN
  [instacart.user_cart_30] as uc
ON
  uc.user_id = o.user_id
LEFT OUTER JOIN
  [instacart.dmt_item] as i
ON
  i.i1_product_id = o.product_id
LEFT OUTER JOIN
  [instacart.dmt_user_item] as ui
ON
  ui.user_id = o.user_id AND ui.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.last_buy] as l
ON
  l.user_id = o.user_id AND l.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.last_buy_aisle] as la
ON
  la.user_id = o.user_id AND la.aisle_id = p.aisle_id
LEFT OUTER JOIN
  [instacart.last_buy_depart] as ld
ON
  ld.user_id = o.user_id AND ld.department_id = p.department_id
LEFT OUTER JOIN
  [instacart.last_buy_2] as l2
ON
  l2.user_id = o.user_id AND l2.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.last_buy_aisle_2] as la2
ON
  la2.user_id = o.user_id AND la2.aisle_id = p.aisle_id
LEFT OUTER JOIN
  [instacart.last_buy_depart_2] as ld2
ON
  ld2.user_id = o.user_id AND ld2.department_id = p.department_id
LEFT OUTER JOIN
  [instacart.dmt_user_aisle] as ua
ON
  ua.user_id = o.user_id AND ua.aisle_id = p.aisle_id
LEFT OUTER JOIN
  [instacart.dmt_user_depart] as ud
ON
  ud.user_id = o.user_id AND ud.department_id = p.department_id
LEFT OUTER JOIN
  [instacart.dmt_user_item_30] as ui3
ON
  ui3.user_id = o.user_id AND ui3.product_id = o.product_id
LEFT OUTER JOIN
  [instacart.dmt_user_aisle_30] as ua3
ON
  ua3.user_id = o.user_id AND ua3.aisle_id = p.aisle_id
LEFT OUTER JOIN
  [instacart.dmt_user_depart_30] as ud3
ON
  ud3.user_id = o.user_id AND ud3.department_id = p.department_id
"

gsutil -m rm -r gs://kaggle-instacart-takami/data/

bq extract --compression GZIP instacart.dmt_train_only_rebuy gs://kaggle-instacart-takami/data/dmt_train_only_rebuy/data*.csv.gz
bq extract --compression GZIP instacart.dmt_test_only_rebuy gs://kaggle-instacart-takami/data/dmt_test_only_rebuy/data*.csv.gz

rm -rf ../data/
gsutil -m cp -r gs://kaggle-instacart-takami/data/ ../

