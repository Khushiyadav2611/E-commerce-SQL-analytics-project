-- ============================================================
-- E-Commerce Analytics — MySQL Schema
-- Run this in MySQL Workbench (or `mysql` CLI) to create the database
-- ============================================================

CREATE DATABASE IF NOT EXISTS ecommerce_analytics;
USE ecommerce_analytics;

CREATE TABLE customers (
    customer_id     INT PRIMARY KEY,
    customer_name   VARCHAR(100) NOT NULL,
    email           VARCHAR(150),
    city            VARCHAR(50),
    region          VARCHAR(20),        -- North / South / East / West
    segment         VARCHAR(30),        -- Consumer / Corporate / Small Business
    signup_date     DATE
) ENGINE=InnoDB;

CREATE TABLE products (
    product_id      INT PRIMARY KEY,
    product_name    VARCHAR(100) NOT NULL,
    category        VARCHAR(50),
    sub_category    VARCHAR(50),
    unit_price      DECIMAL(10,2),
    cost_price      DECIMAL(10,2)
) ENGINE=InnoDB;

CREATE TABLE orders (
    order_id        INT PRIMARY KEY,
    customer_id     INT,
    order_date      DATE,
    ship_date       DATE,
    region          VARCHAR(20),
    payment_method  VARCHAR(30),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

CREATE TABLE order_items (
    order_item_id   INT PRIMARY KEY,
    order_id        INT,
    product_id      INT,
    quantity        INT,
    unit_price      DECIMAL(10,2),
    discount_pct    INT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

-- Relationship:
-- customers (1) ---- (many) orders (1) ---- (many) order_items (many) ---- (1) products
