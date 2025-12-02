Overview

This project modernizes the data infrastructure for Dream Homes NYC, a growing real-estate brokerage that previously depended on fragmented spreadsheets to manage customers, properties, agents, and transactions. Our goal was to construct a reliable, scalable relational database and build the associated ETL and analytics pipeline needed for real-world decision-making. Since no internal data was accessible, we generated a wholly synthetic dataset that replicates the structure of modern real-estate portals such as Zillow and StreetEasy. The finished system supports sophisticated analytical queries, offers a centralized source of truth, and seamlessly interfaces with business intelligence tools.

System Design

Customers, Inventory, and Corporate Operations are the three main domains of the fully normalized PostgreSQL database (3NF) that we created. To preserve referential integrity and guarantee accurate, clean data, each table has stringent constraints. The schema was led by an associated entity-relationship diagram (ERD), which verified the relationships necessary to address important business concerns like pricing patterns, customer interactions, agent performance, and neighborhood characteristics.
To populate the database, we constructed an end-to-end Python ETL pipeline using Faker, Pandas, and SQLAlchemy. The pipeline generates realistic synthetic data, conducts changes to fit the schema’s requirements, and loads the tables in dependency order. This approach ensures that all foreign keys align correctly, emulating the behavior of a true production database.

Analytics & Insights

With the database populated, we designed a set of analytical SQL processes matched with the agency’s main business requirements. These assessments measure office and team performance, track customer conversions over time, assess pricing behavior across areas, look at the effects of walkability, investigate commission arrangements, and spot trends in sold properties. The results indicate how the database may assist day-to-day operational demands as well as long-term strategic planning.
To make these findings available to non-technical consumers, we designed interactive dashboards in Metabase. Executives can see KPIs such as contract pipelines, neighborhood inventories, revenue performance, and agent productivity without needing to write SQL, ensuring transparency across the enterprise.

Key Components

1. Normalized PostgreSQL schema (3NF)
2. Python ETL pipeline for loading, cleaning, and creating data
3. Synthetic datasets for 14 tables
4. Analytical SQL procedures for business insights
5. Metabase dashboards for executive-level reporting

Team

Indang Safitrie, Sarah Mastiur, Ashley Choi, Mohammed Islam
