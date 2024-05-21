/* Question: How many books have been ordered by each customer,
categorized as 'Low', 'Medium', and 'High' based on the number of books ordered?
Low < 5 books
5<= Medium < 10
10<= High
*/
WITH bookCTE AS (
    SELECT 
        book_id,
        order_id
    FROM 
        order_line
)
SELECT 
    c.customer_id,
    CASE 
        WHEN COUNT(b.book_id) < 5 THEN 'Low'
        WHEN COUNT(b.book_id) < 10 THEN 'Medium'
        ELSE 'High' 
    END AS book_sold_rank
FROM 
    bookCTE b 
JOIN 
    cust_order c ON c.order_id = b.order_id
GROUP BY 
    c.customer_id;


/*
Question: What is the latest status of each order?, Count number of orders in each status
and create new view to update newest orders status
*/

/*Lastest Status of each order */
CREATE VIEW Latest_Status AS
WITH StatusCTE AS (
    SELECT 
        oh.order_id,
        oh.status_id,
        oh.status_date,
        os.status_value,
        RANK() OVER (PARTITION BY oh.order_id ORDER BY oh.status_date DESC) AS last_order_filter
    FROM 
        order_history oh
    LEFT JOIN 
        order_status os ON oh.status_id = os.status_id
)
SELECT 
    order_id,
    status_value,
    status_date
FROM 
    StatusCTE
WHERE 
    last_order_filter = 1;


/* Number of orders in each status */
WITH statusCTE AS (
    SELECT 
        o.order_id,
        s.status_value,
        o.status_date
    FROM 
        order_history o
    JOIN 
        order_status s ON o.status_id = s.status_id
)
SELECT 
    status_value,
    COUNT(*) AS number_of_orders
FROM 
    statusCTE
GROUP BY 
    status_value;




/* Question: Who are the top 3 customers based on the total price of their orders? */
WITH orderCTE AS (
    SELECT 
        c.customer_id,
        SUM(o.price) AS total_price,
        RANK() OVER (ORDER BY SUM(o.price) DESC) AS rank_id
    FROM 
        order_line o
    JOIN 
        cust_order c ON o.order_id = c.order_id
    GROUP BY 
        c.customer_id
)
SELECT 
    customer_id,
    total_price
FROM 
    orderCTE
WHERE 
    rank_id <= 3;




/*
Question: Rank the author by their popularity (number of times ordered)
and categorize them as 'Bestseller', 'Popular', or 'Other'.
Note: Only count orders not have 'Cancelled' or 'Returned'
*/

CREATE VIEW AuthorBookSalesView AS
SELECT 
    ba.author_id,
    b.book_id,
    ol.order_id
FROM 
    book_author ba
JOIN 
    book b ON ba.book_id = b.book_id
JOIN 
    order_line ol ON b.book_id = ol.book_id;



CREATE VIEW OrderStatusSalesView AS
SELECT 
    co.order_id,
    oh.status_id
FROM 
    cust_order co
JOIN 
    order_history oh ON co.order_id = oh.order_id
WHERE 
    oh.status_id NOT IN (5, 6);



CREATE VIEW AuthorRanking AS(
SELECT author_id,
		COUNT(a.order_id) as total_book_sold,
		RANK() OVER (ORDER BY COUNT(*) DESC) AS popularity_rank,
		CASE 
			WHEN RANK() OVER (ORDER BY COUNT(*) DESC) <= 5 THEN 'BestSeller'
			WHEN RANK() OVER (ORDER BY COUNT(*) DESC) <= 10 THEN 'Popular'
			ELSE 'Other' END AS book_seller_rank
FROM AuthorBookSalesView a
JOIN OrderStatusSalesView o
ON a.order_id = o.order_id
GROUP BY author_id)



/*
Question: For each shipping method, rank the countries by 
the number of orders and categorize the ranking as 'High', 'Medium', or 'Low' demand.
Note: Only count orders not have 'Cancelled' or 'Returned'
*/


WITH countryCTE AS (
    SELECT 
        s.method_name,
        co.order_id,
        oh.status_id,
        a.country_id,
        c.country_name
    FROM 
        shipping_method s
    JOIN 
        cust_order co ON s.method_id = co.shipping_method_id
    JOIN 
        order_history oh ON oh.order_id = co.order_id
    JOIN 
        address a ON co.dest_address_id = a.address_id
    JOIN 
        country c ON c.country_id = a.country_id
    WHERE 
        oh.status_id NOT IN (5, 6)
)
SELECT	country_name,
		method_name,
		COUNT(order_id) as total_orders,
		RANK() OVER(PARTITION BY method_name ORDER BY COUNT(order_id) DESC) AS CountryRank,
		CASE 
			WHEN RANK() OVER(PARTITION BY method_name ORDER BY COUNT(order_id) DESC) <= 5 THEN 'High'
			WHEN RANK() OVER(PARTITION BY method_name ORDER BY COUNT(order_id) DESC) <= 15 THEN 'Medium'
			ELSE 'Low' END AS country_rank
FROM countryCTE
GROUP BY country_name, method_name



/*
Question: Generate a report showing the number of books sold each month by each publisher.
*/

CREATE VIEW PublisherSalesView AS
SELECT 
    p.publisher_id,
    p.publisher_name,
    ol.order_id,
    oh.status_id,
    co.order_date
FROM 
    publisher p
JOIN 
    book b ON p.publisher_id = b.publisher_id
JOIN 
    order_line ol ON b.book_id = ol.book_id
JOIN 
    order_history oh ON oh.order_id = ol.order_id
JOIN 
    cust_order co ON co.order_id = ol.order_id;




WITH month_sales_CTE AS (
    SELECT 
        publisher_name,
        MONTH(order_date) AS month,
        COUNT(*) AS books_sold
    FROM 
        PublisherSalesView
    WHERE 
        status_id NOT IN (5, 6)
    GROUP BY 
        publisher_name, MONTH(order_date)
)

SELECT 
    publisher_name,
    ISNULL([1], 0) AS January,
    ISNULL([2], 0) AS February,
    ISNULL([3], 0) AS March,
    ISNULL([4], 0) AS April,
    ISNULL([5], 0) AS May,
    ISNULL([6], 0) AS June,
    ISNULL([7], 0) AS July,
    ISNULL([8], 0) AS August,
    ISNULL([9], 0) AS September,
    ISNULL([10], 0) AS October,
    ISNULL([11], 0) AS November,
    ISNULL([12], 0) AS December
FROM 
    month_sales_CTE
PIVOT
(
    SUM(books_sold)
    FOR month IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12])
) AS month_sales_pivot
ORDER BY 
    publisher_name;



/*
Question: What are the top 5 best-selling books of all time?
Objective: Identify the top 5 best-selling books across all categories and publishers,
based on the total number of sales (quantities sold).
*/

Create view Top5BestSellingBook as (
select top 5 b.book_id,
		COUNT(*) as quantities_sold
from book b
join order_line ol
on b.book_id = ol.book_id
group by b.book_id
order by COUNT(*) desc)

/*
Question: How many orders have been placed by new vs. returning customers each year?
Objective: Understand customer retention by comparing the number of orders placed by 
customers ordering for the first time versus those who have placed orders in previous years.
*/

/* Create a CTE include year of customer first order */
with customer_first_order as (
select customer_id,
		min(year(order_date)) as first_order_year
from cust_order
group by customer_id),

/* Create a CTE includes year of each order */
order_by_year as (
select customer_id,
		year(order_date) as order_year
from cust_order)
select o.order_year,
		COUNT(distinct case when o.order_year = c.first_order_year then o.customer_id end) as New_Customer,
		COUNT(distinct case when o.order_year > c.first_order_year then o.customer_id end) as Return_Customer
from order_by_year o
join customer_first_order c
on o.customer_id = c.customer_id
group by o.order_year;


/*
Question: What is the average delivery time for each shipping method, 
and how does it correlate with customer satisfaction?
Objective: Analyze the efficiency of different shipping methods by calculating the average time 
taken from order placement to delivery, and see if there's a noticeable impact on customer satisfaction.
*/


/* Create a view show delivery time for each method */
create view DelieryTimeView as 
with dateCTE as (
select method_name,
		co.order_id,
		order_date,
		status_date
from shipping_method sm
join cust_order co
on co.shipping_method_id = sm.method_id
join order_history oh
on oh.order_id = co.order_id
where status_id not in(5,6))
select method_name,
		order_id,
		DATEDIFF(DAY,min(order_date),max(status_date)) as delivery_time
from dateCTE
group by method_name, order_id


select method_name,
		AVG(delivery_time) as avg_delivery_time
from [DelieryTimeView]
group by method_name
