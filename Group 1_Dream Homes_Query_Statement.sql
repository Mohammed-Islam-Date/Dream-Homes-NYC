/*
Customer Management Quesionts
*/

/*
QUERY 1: How many appointments result in actual sales within 30/60/90 days?

Logic behind this query statement
- Joined Customer_Interactions and Listings tables
- Used COUNT(DISTINCT interaction_id) to count total interactions
- Used CASE statements with EXTRACT(DAY FROM ...) to calculate days between interaction_dt and close_date
- Categorized interactions into 30/60/90 day buckets based on time to closing
- Filtered to listings that were actually sold or rented (WHERE close_date IS NOT NULL)

Note: Used LLM to inquire on best way to categorize our filter into 30/60/90 buckets
*/

SELECT 
    COUNT(DISTINCT ci.interaction_id) AS total_interactions,
    COUNT(DISTINCT CASE 
        WHEN l.listing_status IN ('Sold', 'Rented')
        AND EXTRACT(DAY FROM l.close_date - ci.interaction_dt) <= 30
        THEN ci.interaction_id 
    END) AS closed_within_30_days,
    COUNT(DISTINCT CASE 
        WHEN l.listing_status IN ('Sold', 'Rented')
        AND EXTRACT(DAY FROM l.close_date - ci.interaction_dt) > 30
        AND EXTRACT(DAY FROM l.close_date - ci.interaction_dt) <= 60
        THEN ci.interaction_id 
    END) AS closed_within_60_days,
    COUNT(DISTINCT CASE 
        WHEN l.listing_status IN ('Sold', 'Rented')
        AND EXTRACT(DAY FROM l.close_date - ci.interaction_dt) > 60
        AND EXTRACT(DAY FROM l.close_date - ci.interaction_dt) <= 90
        THEN ci.interaction_id 
    END) AS closed_within_90_days
FROM customer_interactions AS ci
LEFT JOIN listings l ON ci.listing_id = l.listing_id
WHERE l.close_date IS NOT NULL;

	
/*
QUERY 2: How many active contracts are pending closing, and what is the average close timeline?

Logic behind this query statement
- Used contracts table
- Used COUNT(DISTINCT contract_id) to count contracts in pending/active status
- Calculated days to closing using AGE() function on expected_close_date minus contract_date
- Used AVG(), MIN(), MAX() to get the average, shortest, and longest timelines
- Filtered contract_status = 'pending' or 'active' to exclude closed deals
- Added check for expected_close_date IS NOT NULL to exclude records with missing data
*/

SELECT 
    COUNT(DISTINCT c.contract_id) AS active_contracts_pending,
    ROUND(AVG(EXTRACT(DAY FROM AGE(c.expected_close_date::DATE, c.contract_date::DATE))), 1) AS avg_days_to_closing,
    ROUND(MIN(EXTRACT(DAY FROM AGE(c.expected_close_date::DATE, c.contract_date::DATE))), 0) AS min_days_to_closing,
    ROUND(MAX(EXTRACT(DAY FROM AGE(c.expected_close_date::DATE, c.contract_date::DATE))), 0) AS max_days_to_closing
FROM contracts AS c
WHERE c.contract_status IN ('pending', 'active')
    AND c.expected_close_date IS NOT NULL;

/*
QUERY 3: What does our customer list look like across the current pipeline?

Logic behind this query statement
- Joined Customers, Leads, Offers, and Contracts tables
- Used COUNT(DISTINCT customer_id) to count unique customers
- Used COUNT(DISTINCT) on lead_id, offer_id, and contract_id to count activities at each stage
- Group by lead_status to segment customers by where they are in the sales process
- Filtered to lead_status IN ('active', 'qualified', 'pending') to include only deals we are actively pursuing
*/

SELECT 
    cu.first_name,
    cu.last_name,
    cu.email,
    COUNT(DISTINCT l.lead_id) AS leads_in_pipeline,
    COUNT(DISTINCT o.offer_id) AS offers_submitted,
    COUNT(DISTINCT c.contract_id) AS contracts,
    COUNT(DISTINCT CASE WHEN c.contract_status = 'closed' THEN c.contract_id END) AS deals_closed
FROM customers AS cu
LEFT JOIN leads AS l ON cu.customer_id = l.customer_id
LEFT JOIN offers AS o ON cu.customer_id = o.customer_id
LEFT JOIN contracts c ON o.offer_id = c.offer_id
WHERE l.lead_status IN ('active', 'qualified', 'pending')
GROUP BY cu.customer_id, cu.first_name, cu.last_name, cu.email
ORDER BY leads_in_pipeline DESC;

/*
Property & Inventory Questions
*/

/*
QUERY 1: How many properties are listed in each neighborhood, and what is the
average price per square foot by neighborhood?

Logic behind this query statement
- Joined Listings, Properties, Neighborhoods tables
- Used COUNT(DISTINCT property_id) to count unique properties per neighborhood
- Calculated price per sqft as listing_price / sqft
- Used AVG() to get the neighborhood level average price per sqft
- Grouped by listing_type, neighborhood_name and city
- Filtered to listing_status = 'Active' to only include current listing
*/

SELECT 
	l.listing_type,
    n.neighborhood_name,
    n.city,
    COUNT(DISTINCT p.property_id) AS property_count,
    ROUND(AVG(l.listing_price / p.sqft),2) AS avg_price_per_sqft
FROM listings AS l
INNER JOIN properties AS p ON l.property_id = p.property_id
INNER JOIN neighborhoods AS n ON p.neighborhood_id = n.neighborhood_id
WHERE 
    l.listing_status = 'Active'
    AND p.sqft IS NOT NULL
GROUP BY 
	l.listing_type,
    n.neighborhood_name,
    n.city
ORDER BY 
	l.listing_type,
    avg_price_per_sqft DESC;


/*
QUERY 2: How many housing units are located within one ZIP code of a Grade A
Public High School?

Logic behind this query statement
- Joined Neighborhoods, Schools, Properties tables
- Filtered schools to grade_level = 'High' and school_rating = 'A'
- Used ZIP code match as the proximity proxy (instead of 1-mile radius)
- Counted distinct housing units (properties) within those ZIP codes
- Used a DISTINCT subquery for Schools to prevent duplicate rows when multiple
  Grade A High Schools exist in the same neighborhood
*/

SELECT 
    n.zip_code,
    n.neighborhood_name,
    n.city,
    COUNT(DISTINCT p.property_id) AS housing_units_within_zipcode
FROM neighborhoods AS n
JOIN (
    SELECT DISTINCT neighborhood_id
    FROM Schools
    WHERE grade_level = 'High'
      AND school_rating = 'A'
) AS s ON s.neighborhood_id = n.neighborhood_id
JOIN Properties p ON p.neighborhood_id = n.neighborhood_id
GROUP BY 
    n.zip_code,
    n.neighborhood_name,
    n.city
ORDER BY 
    housing_units_within_zipcode DESC;


/*
QUERY 3: Which neighborhoods have the highest price appreciation year-over-year?

Logic behind this query statement
- Used Property_Price_History to capture price changes per listing
- Used window functions to get the first old_price and latest new_price per listing
- Calculated percent price change from first to last price for each listing
- Joined Listings, Properties, Neighborhoods to attach neighborhoods to each listing
- Aggregated the average percent change at the neighborhood level
- Ordered neighborhoods by highest average price appreciation
*/

WITH price_history_enriched AS (
    SELECT
        ph.listing_id,
        -- first recorded price for this listing
        FIRST_VALUE(ph.old_price) OVER (
            PARTITION BY ph.listing_id
            ORDER BY ph.change_date ASC
        ) AS first_price,
        -- latest recorded price for this listing
        FIRST_VALUE(ph.new_price) OVER (
            PARTITION BY ph.listing_id
            ORDER BY ph.change_date DESC
        ) AS last_price
    FROM Property_Price_History ph
),
listing_appreciation AS (
    SELECT
        l.listing_id,
        p.neighborhood_id,
        MIN(phe.first_price) AS first_price,
        MAX(phe.last_price) AS last_price,
        CASE
            WHEN MIN(phe.first_price) > 0 THEN 
                (MAX(phe.last_price) - MIN(phe.first_price)) 
                / MIN(phe.first_price) * 100.0
            ELSE NULL
        END AS pct_change
    FROM price_history_enriched phe
    JOIN Listings l 
        ON phe.listing_id = l.listing_id
    JOIN Properties p 
        ON l.property_id = p.property_id
    GROUP BY 
        l.listing_id,
        p.neighborhood_id
)

SELECT
    n.neighborhood_name,
    n.city,
    ROUND(AVG(la.pct_change), 2) AS avg_price_appreciation_pct,
    COUNT(DISTINCT la.listing_id) AS listings_with_price_changes
FROM listing_appreciation la
JOIN Neighborhoods n 
    ON la.neighborhood_id = n.neighborhood_id
WHERE la.pct_change IS NOT NULL
GROUP BY 
    n.neighborhood_name,
    n.city
ORDER BY 
    avg_price_appreciation_pct DESC;


/*
QUERY 4: How many properties are in walkable neighborhoods (score 70+) vs.
car-dependent areas (score <50)?

Logic behind this query statement
- Joined Properties with Neighborhoods
- Classified neighborhoods into two buckets using walkability_score:
      * Walkable: score >= 70
      * Car-dependent: score < 50
	  * Excluded neighborhoods with scores between 50 and 69 since 
	    they do not fall under either category
- Counted distinct properties in each category
*/

SELECT
    CASE 
        WHEN n.walkability_score >= 70 THEN 'Walkable'
        ELSE 'Car-dependent'
    END AS walkability_category,
    COUNT(DISTINCT p.property_id) AS property_count
FROM Properties p
JOIN Neighborhoods n ON p.neighborhood_id = n.neighborhood_id
WHERE 
    n.walkability_score >= 70
    OR n.walkability_score < 50
GROUP BY 
    CASE 
        WHEN n.walkability_score >= 70 THEN 'Walkable'
        ELSE 'Car-dependent'
    END
ORDER BY walkability_category;


/*
QUERY 5: What percentage of sold properties had a price reduction before closing?

Logic behind this query statement
- Selected listings with listing_status = 'Sold' and close_date is not null
- Joined with Property_Price_History to detect price changes
- Counted only reductions where new_price < old_price
- Ensured the price reduction occurred before or on the close_date
- Calculated the percentage of sold listings that experienced a reduction
*/

WITH sold_listings AS (
    SELECT 
        listing_id,
        close_date
    FROM Listings
    WHERE 
        listing_status = 'Sold'
        AND close_date IS NOT NULL
),
reductions AS (
    SELECT DISTINCT 
        ph.listing_id
    FROM Property_Price_History ph
    JOIN sold_listings sl ON ph.listing_id = sl.listing_id
    WHERE 
        ph.new_price < ph.old_price
        AND ph.change_date <= sl.close_date
)

SELECT
    COUNT(r.listing_id)::decimal 
        / COUNT(sl.listing_id) * 100 AS pct_sold_with_reduction
FROM sold_listings sl
LEFT JOIN reductions r ON sl.listing_id = r.listing_id;

/*
Corporate Operations Questions
*/


/*
QUERY 1: How many commissions did each agent earn and what is the total commission amount?

Logic behind this query statement
- Joined Commissions and Agents tables
- Used COUNT(DISTINCT commission_id) to count number of commissions earned
- Used SUM(commission_amount) to total commissions per agent across all time
- Grouped by agent_id and agent name to get per-agent totals
- Filtered to status = 'paid' to exclude commissions marked as pending or disputed
- Ordered by total_commission DESC to see top earners first
- Included commission_type breakdown to show buyer vs seller commission split
*/

SELECT 
    a.agent_id,
    a.first_name,
    a.last_name,
    a.email,
    c.commission_type,
	COUNT(DISTINCT c.commission_id) AS commission_count,
    ROUND(SUM(c.commission_amount), 2) AS total_commission
FROM commissions AS c
INNER JOIN agents AS a ON c.agent_id = a.agent_id
WHERE c.status = 'paid'
GROUP BY a.agent_id, a.first_name, a.last_name, a.email, c.commission_type
ORDER BY a.agent_id, total_commission DESC;

/*
QUERY 2: Which office location generated the most revenue in the past quarter?

Logic behind this query statement
- Joined Commissions, Offices, and Contracts tables
- Used SUM(commission_amount) to calculate total commissions earned per office
- Filtered for past 3 months using DATE_TRUNC and CURRENT_DATE - INTERVAL '3 months'
- Grouped by office_id and office_name to get totals for each office
- Ordered by total_revenue DESC to show top performing offices first
- Only counted 'paid' commissions to reflect actual earnings received
*/

SELECT 
    o.office_id,
    o.office_name,
    o.city,
    o.state,
    ROUND(SUM(c.commission_amount), 2) AS total_revenue_past_quarter,
    COUNT(DISTINCT c.commission_id) AS commission_count
FROM commissions AS c
INNER JOIN offices AS o ON c.office_id = o.office_id
WHERE c.paid_date >= CURRENT_DATE - INTERVAL '3 months'
    AND c.status = 'paid'
GROUP BY o.office_id, o.office_name, o.city, o.state
ORDER BY total_revenue_past_quarter DESC;

/*
QUERY 3: What is the average commission split between brokers, agents, and teams across
different transaction types?

Logic behind this query statement
- Only used commissions table
- Used AVG(commission_amount) to get average total commission per transaction type
- Used AVG(split_percentage) to show what percentage goes to the agent
- Calculated implied company percentage as (100 - split_percentage)
- Grouped by commission_type (Buyer vs Seller) to compare splits
- Filtered to status = 'paid' to reflect actual payouts

*/

SELECT 
    c.commission_type,
    COUNT(DISTINCT c.commission_id) AS commission_count,
    ROUND(AVG(c.commission_amount), 2) AS avg_commission_amount,
    ROUND(AVG(c.commission_rate), 2) AS avg_commission_rate_pct,
    ROUND(AVG(c.split_percentage), 2) AS avg_agent_split_pct,
    ROUND(100 - AVG(c.split_percentage), 2) AS avg_company_split_pct
FROM commissions AS c
WHERE c.status = 'paid'
GROUP BY c.commission_type
ORDER BY c.commission_type;

/*
QUERY 4: Which agent team has the highest average sales price and lowest average
days-on-market?

Logic behind this query statement
- Joined Teams, Agents, Listings, and Properties tables
- Used AVG(listing_price) to calculate average sales price per team
- Calculated AVG(days on market) using EXTRACT(DAY FROM close_date - listing_date)
- Grouped by team_id and team_name to get metrics for each team
- Filtered to listing_status = 'Sold' to only count completed sales
- Ordered by avg_sales_price DESC to show top performing teams by price
*/

SELECT 
    t.team_id,
    t.team_name,
    t.region,
    COUNT(DISTINCT l.listing_id) AS total_sales,
    ROUND(AVG(l.listing_price), 2) AS avg_sales_price,
    ROUND(AVG(EXTRACT(DAY FROM AGE(l.close_date, l.listing_date))), 1) AS avg_days_on_market
FROM teams AS t
INNER JOIN agents AS a ON t.team_id = a.team_id
INNER JOIN listings AS l ON a.agent_id = l.agent_id
WHERE l.listing_status IN ('Sold', 'Rented')
    AND l.close_date IS NOT NULL
GROUP BY t.team_id, t.team_name, t.region
ORDER BY avg_sales_price DESC, avg_days_on_market ASC;

/*********/


/*
Market Analysis & Pricing Questions
*/

/*
QUERY 1: What is the average price-per-square-foot for condos vs. townhouses vs.
single-family homes in New York?

Logic behind this query statement
- Joined listings, properties, neighborhoods table
- Apply filter to get state = 'NY' and property_type as enlisted in the question
- Used AVG() to calculate price-per-sqft
- Grouped by property type and neighborhood
*/

SELECT 
    p.property_type,
    n.neighborhood_name,
    COUNT(DISTINCT p.property_id) AS property_count,
    ROUND(AVG(CAST(l.listing_price AS NUMERIC) / p.sqft), 2) AS avg_price_per_sqft
FROM listings AS l
INNER JOIN properties AS p ON l.property_id = p.property_id
INNER JOIN neighborhoods AS n ON p.neighborhood_id = n.neighborhood_id
WHERE n.state = 'NY'
	AND p.property_type IN ('Single-family', 'Condo', 'Townhouse')
    AND p.sqft > 0
    AND l.listing_status IN ('Sold', 'Rented')
GROUP BY 
	p.property_type,
    n.neighborhood_name,
	l.listing_price
ORDER BY p.property_type, avg_price_per_sqft DESC;


/*
QUERY 2: What is the price trend for 2-bedroom apartments over the past 12 months?

Logic behind this query statement
- Joined listings, properties, neighborhoods table
- Used DATE_TRUNC() to group by month
- Used LAG() window function to get previous month's average
- Calculated month-over-month percentage change, specifically used PARTITION to perform this calculation within respective neighborhood_id

*/

SELECT 
    DATE_TRUNC('month', l.listing_date)::DATE AS listing_month,
	n.neighborhood_name,
    COUNT(DISTINCT p.property_id) AS total_2br_properties,
    ROUND(AVG(l.listing_price), 2) AS avg_listing_price,
    ROUND(
        (AVG(l.listing_price) - LAG(AVG(l.listing_price), 1) 
         OVER (PARTITION BY n.neighborhood_id ORDER BY DATE_TRUNC('month', l.listing_date))) 
        / LAG(AVG(l.listing_price), 1) 
         OVER (PARTITION BY n.neighborhood_id ORDER BY DATE_TRUNC('month', l.listing_date)) * 100,
        2
    ) AS month_over_month_pct_change
FROM Listings l
INNER JOIN Properties p ON l.property_id = p.property_id
INNER JOIN Neighborhoods n ON p.neighborhood_id = n.neighborhood_id
WHERE CAST(p.bedroom AS INTEGER) = 2
    AND l.listing_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY 
    DATE_TRUNC('month', l.listing_date),
	n.neighborhood_name,
    n.neighborhood_id
ORDER BY listing_month DESC, neighborhood_name;


/*
QUERY 3: How many properties in a given neighborhood are within 10% of their asking price vs.
sold below asking?

Logic behind this query statement:
- Joined offers, listings, properties, neighborhoods tables
- Used CASE statements to categorize offer scenarios
- Used COUNT(DISTINCT CASE WHEN...) for conditional counts i.e. within 10%, below, above asking
	* within_10pct_of_asking is sold between 90-100% of listing_price
	* below_10pct_discount is sold under 90% of listing_price
	* above_asking is sold higher than listing_price
- Calculated average price variance percentage
*/

SELECT 
    n.neighborhood_name,
    COUNT(DISTINCT o.offer_id) AS total_completed_sales,
	ROUND(AVG(l.listing_price), 2) AS avg_asking_price,
	ROUND(AVG(o.offer_price), 2) AS avg_final_sale_price,
    ROUND(((AVG(o.offer_price) - AVG(l.listing_price)) / AVG(l.listing_price) * 100), 2) AS avg_price_variance_pct,
    COUNT(DISTINCT CASE WHEN o.offer_price >= l.listing_price * 0.9 AND o.offer_price <= l.listing_price THEN o.offer_id END) AS within_10pct_of_asking,
    COUNT(DISTINCT CASE WHEN o.offer_price < l.listing_price * 0.9 THEN o.offer_id END) AS below_10pct_discount,
    COUNT(DISTINCT CASE WHEN o.offer_price > l.listing_price THEN o.offer_id END) AS above_asking
FROM Offers o
INNER JOIN Listings l ON o.listing_id = l.listing_id
INNER JOIN Properties p ON l.property_id = p.property_id
INNER JOIN Neighborhoods n ON p.neighborhood_id = n.neighborhood_id
WHERE o.status = 'accepted'
GROUP BY n.neighborhood_name, n.city
ORDER BY total_completed_sales DESC;


/*
QUERY 4: Which neighborhoods show the strongest demand for rentals compared to homes for
sale, based on inquiry and occupancy rates?

Logic behind this query statement:
- Joined neighborhoods, properties, listings, customer interactions tables
- Used COUNT(DISTINCT listing_id) to count total listings per neighborhood
- Used conditional COUNT(DISTINCT CASE WHEN...) to separate rental vs. sale inquiries by 
  checking listing_type = 'Rent' or 'Sale' AND interaction_id exists
- Calculated rental_closure_rate by dividing rented listings by total rental listings, 
  multiplied by 100 to get the percentage
- Calculated sale_closure_rate by dividing sold listings by total sale listings, 
  multiplied by 100 to get the percentage
- Filtered with HAVING clause to remove NULL rates from the rental_closure_rate column (NULL values doesn't serves the purpose of our question) 

Note: Use of LLM to syntax optimization e.g.
	* to handle calculations when certain neighborhoods had no rental or sales, LLM recommended the use of NULLIF(..., 0)
	* suggested the use of ::NUMERIC because I encountered the issue of rental_closure_rate & sale_closure_rate returning only null or 0.00 value on initial execution

*/

SELECT 
    n.neighborhood_name,
    COUNT(DISTINCT l.listing_id) AS total_rental_sale_listings,
    COUNT(DISTINCT CASE WHEN l.listing_type = 'Rent' AND ci.interaction_id IS NOT NULL THEN ci.interaction_id END) AS rental_inquiries,
    COUNT(DISTINCT CASE WHEN l.listing_type = 'Sale' AND ci.interaction_id IS NOT NULL THEN ci.interaction_id END) AS sale_inquiries,
    ROUND(
        COUNT(DISTINCT CASE WHEN l.listing_status = 'Rented' THEN l.listing_id END)::NUMERIC 
        / NULLIF(COUNT(DISTINCT CASE WHEN l.listing_type = 'Rent' THEN l.listing_id END), 0) * 100,
        2
    ) AS rental_closure_rate,
    ROUND(
        COUNT(DISTINCT CASE WHEN l.listing_status = 'Sold' THEN l.listing_id END)::NUMERIC 
        / NULLIF(COUNT(DISTINCT CASE WHEN l.listing_type = 'Sale' THEN l.listing_id END), 0) * 100,
        2
    ) AS sale_closure_rate
FROM neighborhoods AS n
LEFT JOIN properties AS p ON n.neighborhood_id = p.neighborhood_id
LEFT JOIN listings AS l ON p.property_id = l.property_id
LEFT JOIN customer_interactions AS ci ON l.listing_id = ci.listing_id
GROUP BY n.neighborhood_id, n.neighborhood_name, n.city
HAVING
	ROUND(
        COUNT(DISTINCT CASE WHEN l.listing_status = 'Rented' THEN l.listing_id END)::NUMERIC 
        / NULLIF(COUNT(DISTINCT CASE WHEN l.listing_type = 'Rent' THEN l.listing_id END), 0) * 100,
        2)
	is not null
ORDER BY n.city;


/*
QUERY 5: What is the percentage of deals in the pipeline that successfully convert into completed
transactions, and how does this conversion rate compare between rental and sales
listings?

Logic behind this query statement:
- Joined listings, properties, neighborhoods, interactions, offers, contracts tables
- Counted distinct listings at each stage (inquiries, offers, accepted, closed)
- Divided deals closed by inquiries to get conversion percentage
- Grouped by listing type to compare rental vs. sales
*/

SELECT 
    l.listing_type,
    n.city,
    COUNT(DISTINCT l.listing_id) AS total_listings,
    COUNT(DISTINCT CASE WHEN ci.interaction_id IS NOT NULL THEN l.listing_id END) AS with_inquiries,
    COUNT(DISTINCT CASE WHEN o.offer_id IS NOT NULL THEN l.listing_id END) AS with_offers,
    COUNT(DISTINCT CASE WHEN o.status = 'accepted' THEN l.listing_id END) AS offers_accepted,
    -- COUNT(DISTINCT CASE WHEN c.contract_status = 'closed' THEN l.listing_id END) AS deals_closed,
	-- In case listing_type with zero inquires P12M returns as zero
    COUNT(DISTINCT CASE WHEN c.contract_status = 'closed' THEN l.listing_id END) AS deals_closed,
    ROUND(
        COUNT(DISTINCT CASE WHEN c.contract_status = 'closed' THEN l.listing_id END)::NUMERIC 
        / NULLIF(COUNT(DISTINCT CASE WHEN ci.interaction_id IS NOT NULL THEN l.listing_id END), 0) * 100,
        2
    ) AS inquiry_to_closure_pct
FROM Listings l
INNER JOIN Properties p ON l.property_id = p.property_id
INNER JOIN Neighborhoods n ON p.neighborhood_id = n.neighborhood_id
LEFT JOIN Customer_Interactions ci ON l.listing_id = ci.listing_id
LEFT JOIN Offers o ON l.listing_id = o.listing_id
LEFT JOIN Contracts c ON o.offer_id = c.offer_id
WHERE l.listing_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY l.listing_type, n.city
ORDER BY l.listing_type, inquiry_to_closure_pct DESC;


/*
QUERY 6: What is the average time on market for rental listings compared to for-sale listings?

Logic behind this query statement:
- Joined listings, properties, neighborhoods tables
- Used AGE() function to calculate days between close and listing dates
- Used AVG(), MIN(), MAX() on the day calculation
- Grouped by listing type to compare rental vs. for-sale speed
*/

SELECT 
    l.listing_type,
    n.city,
    COUNT(DISTINCT l.listing_id) AS total_listings,
    ROUND(AVG(EXTRACT(DAY FROM AGE(l.close_date, l.listing_date))), 1) AS avg_days_on_market,
    ROUND(MIN(EXTRACT(DAY FROM AGE(l.close_date, l.listing_date))), 0) AS min_days,
    ROUND(MAX(EXTRACT(DAY FROM AGE(l.close_date, l.listing_date))), 0) AS max_days
FROM Listings l
INNER JOIN Properties p ON l.property_id = p.property_id
INNER JOIN Neighborhoods n ON p.neighborhood_id = n.neighborhood_id
WHERE l.listing_date >= CURRENT_DATE - INTERVAL '12 months'
    AND l.close_date IS NOT NULL
GROUP BY l.listing_type, n.city
ORDER BY l.listing_type, avg_days_on_market ASC;

