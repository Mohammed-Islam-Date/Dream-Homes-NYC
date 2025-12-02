/* CORPORATE OFFICE CATEGORY */
/* Create Offices first (no dependencies) */
CREATE TABLE Offices (
    office_id SERIAL PRIMARY KEY,
    office_name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(2) NOT NULL CHECK (state IN ('NY', 'NJ', 'CT')),
    zip_code VARCHAR(10) NOT NULL,
    phone VARCHAR(20)
);

/* Create Teams after Offices */
CREATE TABLE Teams (
    team_id SERIAL PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL,
    team_lead_id INTEGER,
    office_id INTEGER REFERENCES Offices(office_id) ON UPDATE CASCADE ON DELETE SET NULL,
    established_date DATE,
    region VARCHAR(20)
);

/* Create Agents after Offices and Teams */
CREATE TABLE Agents (
    agent_id SERIAL PRIMARY KEY,
    office_id INTEGER REFERENCES Offices(office_id) ON UPDATE CASCADE ON DELETE SET NULL,
    team_id INTEGER REFERENCES Teams(team_id) ON UPDATE CASCADE ON DELETE SET NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    license_number VARCHAR(50) UNIQUE NOT NULL,
    hire_date DATE NOT NULL,
    status VARCHAR(20) CHECK (status IN ('Active', 'Inactive', 'Retired')),
    commission_tier VARCHAR(50)
);

/* Create Commissions after Agents */
CREATE TABLE Commissions (
    commission_id SERIAL PRIMARY KEY,
    transaction_id INTEGER,
    agent_id INTEGER NOT NULL REFERENCES Agents(agent_id) ON UPDATE CASCADE ON DELETE CASCADE,
    team_id INTEGER REFERENCES Teams(team_id) ON UPDATE CASCADE ON DELETE SET NULL,
    office_id INTEGER REFERENCES Offices(office_id) ON UPDATE CASCADE ON DELETE SET NULL,
    commission_amount NUMERIC(12,2) CHECK (commission_amount >= 0),
    commission_rate NUMERIC(5,2) CHECK (commission_rate BETWEEN 0 AND 100),
    commission_type VARCHAR(20) CHECK (commission_type IN ('Buyer', 'Seller')),
    split_percentage NUMERIC(5,2),
    paid_date DATE,
    status VARCHAR(20) CHECK (status IN ('pending', 'paid', 'disputed'))
);


/* INVENTORY CATEGORY */
/* Create Neighborhoods first (no dependencies) */
CREATE TABLE Neighborhoods (
    neighborhood_id SERIAL PRIMARY KEY,
    neighborhood_name VARCHAR(120) NOT NULL,
    city VARCHAR(120) NOT NULL,
    state VARCHAR(2) NOT NULL CHECK (state IN ('NY', 'NJ', 'CT')),
    zip_code VARCHAR(10) NOT NULL,
    walkability_score INTEGER CHECK (walkability_score BETWEEN 0 AND 100),
    UNIQUE (neighborhood_name, city, state, zip_code)
);

/* Create Schools after Neighborhoods */
CREATE TABLE Schools (
    school_id SERIAL PRIMARY KEY,
    school_name VARCHAR(160) NOT NULL,
    grade_level VARCHAR(20) NOT NULL CHECK (grade_level IN ('Elementary', 'Middle', 'High', 'K12', 'Other')),
    school_rating VARCHAR(1) CHECK (school_rating IN ('A','B','C')),
    neighborhood_id INTEGER REFERENCES Neighborhoods(neighborhood_id) ON UPDATE CASCADE ON DELETE SET NULL,
    address VARCHAR(240)
);

/* Create Properties after Neighborhoods */
CREATE TABLE Properties (
    property_id SERIAL PRIMARY KEY,
    address VARCHAR(240) NOT NULL,
    neighborhood_id INTEGER REFERENCES Neighborhoods(neighborhood_id) ON UPDATE CASCADE ON DELETE SET NULL,
    property_type VARCHAR(40) NOT NULL CHECK (property_type IN ('Single-family', 'Condo', 'Townhouse', 'Multi-unit')),
    rooms NUMERIC(2,1) NOT NULL,
    bedroom NUMERIC(2,1) NOT NULL,
    bathroom NUMERIC(2,1) NOT NULL,
    sqft INTEGER CHECK (sqft > 0),
    price NUMERIC(14,2) CHECK (price >= 0)
);

/* Create Listings after Properties and Agents */
CREATE TABLE Listings (
    listing_id SERIAL PRIMARY KEY,
    property_id INTEGER NOT NULL REFERENCES Properties(property_id) ON UPDATE CASCADE ON DELETE CASCADE,
    agent_id INTEGER REFERENCES Agents(agent_id) ON UPDATE CASCADE ON DELETE SET NULL,
    listing_type VARCHAR(10) NOT NULL CHECK (listing_type IN ('Sale', 'Rent')),
    listing_date DATE NOT NULL,
    listing_price NUMERIC(14,2) CHECK (listing_price >= 0),
    listing_status VARCHAR(20) NOT NULL CHECK (listing_status IN ('Active', 'Pending', 'Sold', 'Rented', 'Expired', 'Withdrawn')),
    close_date DATE,
    last_updated TIMESTAMP DEFAULT NOW(),
    CONSTRAINT chk_listing_dates CHECK (close_date IS NULL OR close_date >= listing_date)
);

/* Create Property_Price_History after Listings */
CREATE TABLE Property_Price_History (
    price_history_id SERIAL PRIMARY KEY,
    listing_id INTEGER NOT NULL REFERENCES Listings(listing_id) ON UPDATE CASCADE ON DELETE CASCADE,
    old_price NUMERIC(14,2) CHECK (old_price >= 0),
    new_price NUMERIC(14,2) CHECK (new_price >= 0),
    change_date TIMESTAMP DEFAULT NOW(),
    reason_for_change VARCHAR(160),
    CONSTRAINT chk_price_change CHECK (old_price IS NULL OR new_price <> old_price)
);


/* CUSTOMERS CATEGORY */
/* Create Customers first (no dependencies) */
CREATE TABLE Customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    address VARCHAR(255),
    customer_type VARCHAR(10) NOT NULL CHECK (customer_type IN ('buyer','seller','renter')),
    created_date DATE NOT NULL DEFAULT CURRENT_DATE,
    updated_date DATE
);

/* Create Leads after Customers */
CREATE TABLE Leads (
    lead_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES Customers(customer_id) ON UPDATE CASCADE ON DELETE CASCADE,
    lead_date DATE NOT NULL,
    lead_source VARCHAR(20) CHECK (lead_source IN ('email','digital','print','event','referral','cold_call')),
    lead_status VARCHAR(10) NOT NULL CHECK (lead_status IN ('active','converted','lost','archived')),
    est_value NUMERIC(12,2),
    notes TEXT
);

/* Create Customer_Interactions after Customers and Leads */
CREATE TABLE Customer_Interactions (
    interaction_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES Customers(customer_id) ON UPDATE CASCADE ON DELETE CASCADE,
    lead_id INTEGER REFERENCES Leads(lead_id) ON UPDATE CASCADE ON DELETE SET NULL,
    interaction_dt TIMESTAMP NOT NULL DEFAULT NOW(),
    channel VARCHAR(15) CHECK (channel IN ('call','email','text','meeting','showing','other')),
    subject VARCHAR(120),
    details TEXT,
    listing_id INTEGER REFERENCES Listings(listing_id) ON UPDATE CASCADE ON DELETE SET NULL,
    outcome VARCHAR(20)
);

/* Create Offers after Customers and Listings (and optionally Agents) */
CREATE TABLE Offers (
    offer_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES Customers(customer_id) ON UPDATE CASCADE ON DELETE CASCADE,
    listing_id INTEGER NOT NULL REFERENCES Listings(listing_id) ON UPDATE CASCADE ON DELETE CASCADE,
    agent_id INTEGER REFERENCES Agents(agent_id) ON UPDATE CASCADE ON DELETE SET NULL,
    offer_price NUMERIC(12,2) NOT NULL CHECK (offer_price > 0),
    offer_date DATE NOT NULL,
    status VARCHAR(16) NOT NULL CHECK (status IN ('submitted','counter','accepted','rejected','expired')),
    contingencies TEXT
);

/* Create Contracts after Offers */
CREATE TABLE Contracts (
    contract_id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL UNIQUE REFERENCES Offers(offer_id) ON UPDATE CASCADE ON DELETE CASCADE,
    contract_type VARCHAR(10) NOT NULL CHECK (contract_type IN ('purchase','lease','listing')),
    contract_date DATE NOT NULL,
    expected_close_date DATE,
    signed_date DATE,
    contract_status VARCHAR(12) NOT NULL CHECK (contract_status IN ('pending','active','closed','expired','terminated')),
    terms TEXT
);