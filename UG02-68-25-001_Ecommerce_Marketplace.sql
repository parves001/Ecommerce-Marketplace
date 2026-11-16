-- =====================================================================
-- CSE-2105: DBMS Assignment
-- Project 3 : E-commerce Marketplace (Daraz-style)
-- DBMS      : XAMPP (MariaDB 10.4 or later), written as pure SQL
-- How to run: phpMyAdmin -> Import (or paste into the SQL tab).
--             The script creates the database itself and can be re-run.
-- Lines marked "EXPECTED ERROR" are commented out on purpose, because an
-- error would stop an import. Run them one at a time in the SQL tab.
-- =====================================================================

-- =====================================================================
-- TASK 4: DATABASE CREATION WITH DDL
-- =====================================================================
DROP DATABASE IF EXISTS ecommerce_marketplace;
CREATE DATABASE ecommerce_marketplace
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_marketplace;

-- ---------------------------------------------------------------------
-- 4.1 users : supertype of the ISA hierarchy (User -> Customer / Seller)
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name     VARCHAR(40)  NOT NULL,
  last_name      VARCHAR(40)  NOT NULL,
  email          VARCHAR(100) NOT NULL,
  phone          CHAR(11)     NOT NULL,
  password_hash  CHAR(64)     NOT NULL,
  user_type      ENUM('customer','seller') NOT NULL,
  account_status ENUM('active','suspended') NOT NULL DEFAULT 'active',
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_users PRIMARY KEY (user_id),
  CONSTRAINT uq_users_email UNIQUE (email),
  CONSTRAINT uq_users_phone UNIQUE (phone),
  -- Bangladeshi mobile number: 11 digits, starts with 013-019
  CONSTRAINT chk_users_phone CHECK (phone REGEXP '^01[3-9][0-9]{8}$'),
  CONSTRAINT chk_users_email CHECK (email LIKE '%_@_%._%')
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.2 customers : subtype of users, with a recursive "referred by" link
-- ---------------------------------------------------------------------
CREATE TABLE customers (
  customer_id    INT UNSIGNED NOT NULL,
  date_of_birth  DATE         NOT NULL,
  gender         ENUM('male','female','other') NOT NULL,
  loyalty_points INT          NOT NULL DEFAULT 0,
  referred_by    INT UNSIGNED NULL,
  CONSTRAINT pk_customers PRIMARY KEY (customer_id),
  -- a customer row cannot exist without its user row
  CONSTRAINT fk_customers_user FOREIGN KEY (customer_id)
    REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  -- if the referrer leaves, keep the customer and just clear the link
  CONSTRAINT fk_customers_referrer FOREIGN KEY (referred_by)
    REFERENCES customers (customer_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_customers_points CHECK (loyalty_points >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.3 sellers : subtype of users (holds sensitive business columns)
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
  seller_id        INT UNSIGNED NOT NULL,
  shop_name        VARCHAR(80)  NOT NULL,
  trade_license_no VARCHAR(20)  NOT NULL,
  nid_no           CHAR(10)     NOT NULL,
  bank_account_no  VARCHAR(20)  NOT NULL,
  shop_city        VARCHAR(40)  NOT NULL,
  commission_rate  DECIMAL(4,2) NOT NULL DEFAULT 5.00,
  is_verified      TINYINT(1)   NOT NULL DEFAULT 0,
  CONSTRAINT pk_sellers PRIMARY KEY (seller_id),
  CONSTRAINT fk_sellers_user FOREIGN KEY (seller_id)
    REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT uq_sellers_shop UNIQUE (shop_name),
  CONSTRAINT uq_sellers_license UNIQUE (trade_license_no),
  CONSTRAINT chk_sellers_commission CHECK (commission_rate BETWEEN 0 AND 30)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.4 addresses : WEAK ENTITY, identified by its owner customer
--     (partial key = address_no, full key = customer_id + address_no)
-- ---------------------------------------------------------------------
CREATE TABLE addresses (
  customer_id INT UNSIGNED     NOT NULL,
  address_no  TINYINT UNSIGNED NOT NULL,
  label       ENUM('home','office','other') NOT NULL DEFAULT 'home',
  street      VARCHAR(100) NOT NULL,
  area        VARCHAR(50)  NOT NULL,
  city        VARCHAR(40)  NOT NULL,
  division    ENUM('Dhaka','Chattogram','Rajshahi','Khulna','Barishal',
                   'Sylhet','Rangpur','Mymensingh') NOT NULL,
  postal_code CHAR(4)      NOT NULL,
  CONSTRAINT pk_addresses PRIMARY KEY (customer_id, address_no),
  -- a weak entity dies with its owner
  CONSTRAINT fk_addresses_customer FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_addresses_postal CHECK (postal_code REGEXP '^[0-9]{4}$')
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.5 categories : recursive (unary) relationship, category -> parent
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  category_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_name      VARCHAR(60)  NOT NULL,
  parent_category_id INT UNSIGNED NULL,
  CONSTRAINT pk_categories PRIMARY KEY (category_id),
  CONSTRAINT uq_categories_name UNIQUE (category_name),
  -- removing a parent turns its children into top-level categories
  CONSTRAINT fk_categories_parent FOREIGN KEY (parent_category_id)
    REFERENCES categories (category_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.6 products
-- ---------------------------------------------------------------------
CREATE TABLE products (
  product_id     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  seller_id      INT UNSIGNED  NOT NULL,
  category_id    INT UNSIGNED  NOT NULL,
  product_name   VARCHAR(120)  NOT NULL,
  brand          VARCHAR(40)   NOT NULL,
  sku            VARCHAR(20)   NOT NULL,
  price          DECIMAL(10,2) NOT NULL,
  stock_qty      INT           NOT NULL DEFAULT 0,
  product_status ENUM('active','inactive') NOT NULL DEFAULT 'active',
  listed_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_products PRIMARY KEY (product_id),
  -- a seller or category that still has products cannot be deleted
  CONSTRAINT fk_products_seller FOREIGN KEY (seller_id)
    REFERENCES sellers (seller_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_products_category FOREIGN KEY (category_id)
    REFERENCES categories (category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_products_price CHECK (price > 0),
  CONSTRAINT chk_products_stock CHECK (stock_qty >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.7 product_images : the multivalued attribute "images" of a product
-- ---------------------------------------------------------------------
CREATE TABLE product_images (
  product_id INT UNSIGNED     NOT NULL,
  image_no   TINYINT UNSIGNED NOT NULL,
  image_url  VARCHAR(200)     NOT NULL,
  CONSTRAINT pk_product_images PRIMARY KEY (product_id, image_no),
  CONSTRAINT fk_images_product FOREIGN KEY (product_id)
    REFERENCES products (product_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.8 carts (1:1 with customer) and cart_items (M:N cart - product)
-- ---------------------------------------------------------------------
CREATE TABLE carts (
  cart_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id INT UNSIGNED NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_carts PRIMARY KEY (cart_id),
  CONSTRAINT uq_carts_customer UNIQUE (customer_id),   -- one cart per customer
  CONSTRAINT fk_carts_customer FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cart_items (
  cart_id    INT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  quantity   INT          NOT NULL DEFAULT 1,
  added_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_cart_items PRIMARY KEY (cart_id, product_id),
  CONSTRAINT fk_cartitems_cart FOREIGN KEY (cart_id)
    REFERENCES carts (cart_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_cartitems_product FOREIGN KEY (product_id)
    REFERENCES products (product_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_cartitems_qty CHECK (quantity > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.9 wishlists : pure junction table (M:N customer - product)
-- ---------------------------------------------------------------------
CREATE TABLE wishlists (
  customer_id INT UNSIGNED NOT NULL,
  product_id  INT UNSIGNED NOT NULL,
  wished_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_wishlists PRIMARY KEY (customer_id, product_id),
  CONSTRAINT fk_wishlists_customer FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_wishlists_product FOREIGN KEY (product_id)
    REFERENCES products (product_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.10 orders (main transaction table) and order_items (M:N order - product)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  order_id     INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  customer_id  INT UNSIGNED     NOT NULL,
  address_no   TINYINT UNSIGNED NOT NULL,
  order_date   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  order_status ENUM('pending','confirmed','shipped','delivered','cancelled')
               NOT NULL DEFAULT 'pending',
  total_amount DECIMAL(12,2)    NOT NULL DEFAULT 0.00,
  CONSTRAINT pk_orders PRIMARY KEY (order_id),
  -- order history must survive: a customer with orders cannot be deleted
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  -- the shipping address must be one of this customer's own addresses
  CONSTRAINT fk_orders_address FOREIGN KEY (customer_id, address_no)
    REFERENCES addresses (customer_id, address_no)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_orders_total CHECK (total_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE order_items (
  order_id   INT UNSIGNED  NOT NULL,
  product_id INT UNSIGNED  NOT NULL,
  quantity   INT           NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  CONSTRAINT pk_order_items PRIMARY KEY (order_id, product_id),
  -- items have no meaning without their order
  CONSTRAINT fk_orderitems_order FOREIGN KEY (order_id)
    REFERENCES orders (order_id) ON DELETE CASCADE ON UPDATE CASCADE,
  -- a product that has been sold cannot be deleted (only set inactive)
  CONSTRAINT fk_orderitems_product FOREIGN KEY (product_id)
    REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_orderitems_qty CHECK (quantity > 0),
  CONSTRAINT chk_orderitems_price CHECK (unit_price > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.11 payments (1:1 with order)
-- ---------------------------------------------------------------------
CREATE TABLE payments (
  payment_id      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  order_id        INT UNSIGNED  NOT NULL,
  method          ENUM('bKash','Nagad','Rocket','Card','Cash on Delivery') NOT NULL,
  amount          DECIMAL(12,2) NOT NULL,
  payment_status  ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
  transaction_ref VARCHAR(30)   NULL,
  paid_at         DATETIME      NULL,
  CONSTRAINT pk_payments PRIMARY KEY (payment_id),
  CONSTRAINT uq_payments_order UNIQUE (order_id),
  CONSTRAINT uq_payments_ref UNIQUE (transaction_ref),
  -- financial records are never removed by deleting an order
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
    REFERENCES orders (order_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_payments_amount CHECK (amount > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.12 couriers and deliveries
-- ---------------------------------------------------------------------
CREATE TABLE couriers (
  courier_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  courier_name VARCHAR(60)  NOT NULL,
  hotline      VARCHAR(15)  NOT NULL,
  hq_city      VARCHAR(40)  NOT NULL DEFAULT 'Dhaka',
  CONSTRAINT pk_couriers PRIMARY KEY (courier_id),
  CONSTRAINT uq_couriers_name UNIQUE (courier_name)
) ENGINE=InnoDB;

CREATE TABLE deliveries (
  delivery_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id        INT UNSIGNED NOT NULL,
  courier_id      INT UNSIGNED NULL,
  tracking_no     VARCHAR(20)  NOT NULL,
  delivery_status ENUM('processing','in_transit','delivered','returned')
                  NOT NULL DEFAULT 'processing',
  shipped_at      DATETIME     NULL,
  delivered_at    DATETIME     NULL,
  CONSTRAINT pk_deliveries PRIMARY KEY (delivery_id),
  CONSTRAINT uq_deliveries_order UNIQUE (order_id),
  CONSTRAINT uq_deliveries_tracking UNIQUE (tracking_no),
  CONSTRAINT fk_deliveries_order FOREIGN KEY (order_id)
    REFERENCES orders (order_id) ON DELETE CASCADE ON UPDATE CASCADE,
  -- if a courier company is removed, keep the delivery history
  CONSTRAINT fk_deliveries_courier FOREIGN KEY (courier_id)
    REFERENCES couriers (courier_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_deliveries_dates
    CHECK (delivered_at IS NULL OR delivered_at >= shipped_at)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.13 reviews
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
  review_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id INT UNSIGNED NOT NULL,
  product_id  INT UNSIGNED NOT NULL,
  rating      TINYINT      NOT NULL,
  comment     VARCHAR(300) NULL,
  review_date DATE         NOT NULL,
  CONSTRAINT pk_reviews PRIMARY KEY (review_id),
  CONSTRAINT uq_reviews_once UNIQUE (customer_id, product_id), -- one review each
  CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_reviews_product FOREIGN KEY (product_id)
    REFERENCES products (product_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.14 audit_log : filled only by the audit trigger (Task 9)
-- ---------------------------------------------------------------------
CREATE TABLE audit_log (
  log_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  table_name  VARCHAR(40)  NOT NULL,
  record_id   INT UNSIGNED NOT NULL,
  action_type ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  column_name VARCHAR(40)  NOT NULL,
  old_value   VARCHAR(100) NULL,
  new_value   VARCHAR(100) NULL,
  changed_by  VARCHAR(100) NOT NULL,
  changed_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_audit_log PRIMARY KEY (log_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.15 ALTER TABLE statements
-- ---------------------------------------------------------------------
-- (a) add a column: remember when a cart was last changed
ALTER TABLE carts
  ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  ON UPDATE CURRENT_TIMESTAMP;

-- (b) add a constraint: a courier hotline is 5 to 11 digits (e.g. 16516)
ALTER TABLE couriers
  ADD CONSTRAINT chk_couriers_hotline CHECK (hotline REGEXP '^[0-9]{5,11}$');

-- (c) change a column: a longer product name is allowed
ALTER TABLE products
  MODIFY COLUMN product_name VARCHAR(150) NOT NULL;

-- Proof that the constraints work. Run each line alone in the SQL tab.
-- EXPECTED ERROR (CHECK chk_products_price):
--   INSERT INTO products (seller_id, category_id, product_name, brand, sku, price, stock_qty)
--   VALUES (21, 6, 'Free Phone', 'Test', 'TST-000', 0, 5);
-- EXPECTED ERROR (CHECK chk_users_phone):
--   INSERT INTO users (first_name, last_name, email, phone, password_hash, user_type)
--   VALUES ('Test', 'User', 'test@example.com', '12345', SHA2('x',256), 'customer');
-- =====================================================================
-- TASK 5: POPULATE THE DATABASE WITH DML
-- =====================================================================
-- 5.1 users: 20 customers (user_id 1-20) and 15 sellers (user_id 21-35)
INSERT INTO users (user_id, first_name, last_name, email, phone, password_hash, user_type, account_status, created_at) VALUES
  (1, 'Rahim', 'Uddin', 'rahim.uddin64@gmail.com', '01406711709', SHA2('cust01#pass', 256), 'customer', 'active', '2026-01-05 10:38:00'),
  (2, 'Fatema', 'Khatun', 'fatema.khatun44@gmail.com', '01685991030', SHA2('cust02#pass', 256), 'customer', 'active', '2026-01-13 09:00:00'),
  (3, 'Tanvir', 'Ahmed', 'tanvir.ahmed72@gmail.com', '01709075149', SHA2('cust03#pass', 256), 'customer', 'active', '2026-01-21 14:48:00'),
  (4, 'Nusrat', 'Jahan', 'nusrat.jahan27@gmail.com', '01965753573', SHA2('cust04#pass', 256), 'customer', 'active', '2026-01-29 08:23:00'),
  (5, 'Shakil', 'Hossain', 'shakil.hossain52@gmail.com', '01757487777', SHA2('cust05#pass', 256), 'customer', 'active', '2026-02-06 08:47:00'),
  (6, 'Sumaiya', 'Akter', 'sumaiya.akter64@gmail.com', '01645991369', SHA2('cust06#pass', 256), 'customer', 'active', '2026-02-14 08:09:00'),
  (7, 'Arif', 'Chowdhury', 'arif.chowdhury33@gmail.com', '01733504462', SHA2('cust07#pass', 256), 'customer', 'active', '2026-02-22 19:19:00'),
  (8, 'Mim', 'Rahman', 'mim.rahman30@gmail.com', '01912740647', SHA2('cust08#pass', 256), 'customer', 'active', '2026-03-02 15:18:00'),
  (9, 'Sabbir', 'Islam', 'sabbir.islam12@gmail.com', '01695107654', SHA2('cust09#pass', 256), 'customer', 'active', '2026-03-10 20:24:00'),
  (10, 'Tasnim', 'Sultana', 'tasnim.sultana81@gmail.com', '01647551521', SHA2('cust10#pass', 256), 'customer', 'active', '2026-03-18 20:06:00'),
  (11, 'Imran', 'Khan', 'imran.khan77@gmail.com', '01678879160', SHA2('cust11#pass', 256), 'customer', 'active', '2026-03-26 10:43:00'),
  (12, 'Jannatul', 'Ferdous', 'jannatul.ferdous33@gmail.com', '01681114841', SHA2('cust12#pass', 256), 'customer', 'active', '2026-04-03 18:12:00'),
  (13, 'Mehedi', 'Hasan', 'mehedi.hasan22@gmail.com', '01354942811', SHA2('cust13#pass', 256), 'customer', 'active', '2026-04-11 13:46:00'),
  (14, 'Sharmin', 'Begum', 'sharmin.begum30@gmail.com', '01692621403', SHA2('cust14#pass', 256), 'customer', 'active', '2026-04-19 15:12:00'),
  (15, 'Rakib', 'Mia', 'rakib.mia28@gmail.com', '01643242438', SHA2('cust15#pass', 256), 'customer', 'active', '2026-04-27 09:55:00'),
  (16, 'Farzana', 'Haque', 'farzana.haque31@gmail.com', '01661392744', SHA2('cust16#pass', 256), 'customer', 'active', '2026-05-05 18:00:00'),
  (17, 'Nayeem', 'Sarkar', 'nayeem.sarkar23@gmail.com', '01537452478', SHA2('cust17#pass', 256), 'customer', 'active', '2026-05-13 17:54:00'),
  (18, 'Ayesha', 'Siddiqua', 'ayesha.siddiqua52@gmail.com', '01312930250', SHA2('cust18#pass', 256), 'customer', 'active', '2026-05-21 17:32:00'),
  (19, 'Zahid', 'Talukdar', 'zahid.talukdar25@gmail.com', '01438311946', SHA2('cust19#pass', 256), 'customer', 'active', '2026-05-29 21:39:00'),
  (20, 'Rumana', 'Parvin', 'rumana.parvin75@gmail.com', '01670391038', SHA2('cust20#pass', 256), 'customer', 'active', '2026-06-06 15:59:00'),
  (21, 'Kamal', 'Hossain', 'kamal@techzonebd.com.bd', '01632409779', SHA2('sell21#pass', 256), 'seller', 'active', '2025-09-01 10:02:00'),
  (22, 'Rafiq', 'Islam', 'rafiq@gadgetbazar.com.bd', '01704802356', SHA2('sell22#pass', 256), 'seller', 'active', '2025-09-12 11:21:00'),
  (23, 'Sohel', 'Rana', 'sohel@mobilemela.com.bd', '01536143077', SHA2('sell23#pass', 256), 'seller', 'active', '2025-09-23 14:13:00'),
  (24, 'Nasrin', 'Akter', 'nasrin@laptoplagbe.com.bd', '01878095454', SHA2('sell24#pass', 256), 'seller', 'active', '2025-10-04 11:02:00'),
  (25, 'Jubayer', 'Alam', 'jubayer@soundhouse.com.bd', '01877903310', SHA2('sell25#pass', 256), 'seller', 'active', '2025-10-15 14:34:00'),
  (26, 'Monir', 'Hossen', 'monir@deshifashion.com.bd', '01984335606', SHA2('sell26#pass', 256), 'seller', 'active', '2025-10-26 10:28:00'),
  (27, 'Rokeya', 'Begum', 'rokeya@nakshiboutique.com.bd', '01837225971', SHA2('sell27#pass', 256), 'seller', 'active', '2025-11-06 14:50:00'),
  (28, 'Anwar', 'Parvez', 'anwar@ghorsajai.com.bd', '01458519937', SHA2('sell28#pass', 256), 'seller', 'active', '2025-11-17 14:45:00'),
  (29, 'Selina', 'Yasmin', 'selina@rannaghorstore.com.bd', '01953342566', SHA2('sell29#pass', 256), 'seller', 'active', '2025-11-28 12:13:00'),
  (30, 'Habib', 'Ullah', 'habib@kathmistrifurniture.com.bd', '01396186054', SHA2('sell30#pass', 256), 'seller', 'active', '2025-12-09 13:36:00'),
  (31, 'Delwar', 'Hossain', 'delwar@dinajpuragro.com.bd', '01497437038', SHA2('sell31#pass', 256), 'seller', 'active', '2025-12-20 11:27:00'),
  (32, 'Shahana', 'Parvin', 'shahana@mudidokanonline.com.bd', '01395519228', SHA2('sell32#pass', 256), 'seller', 'active', '2025-12-31 11:23:00'),
  (33, 'Billal', 'Miah', 'billal@chabaganshop.com.bd', '01902053924', SHA2('sell33#pass', 256), 'seller', 'active', '2026-01-11 10:36:00'),
  (34, 'Lamia', 'Tabassum', 'lamia@rupchorchabeauty.com.bd', '01585833571', SHA2('sell34#pass', 256), 'seller', 'active', '2026-01-22 16:55:00'),
  (35, 'Masud', 'Karim', 'masud@barishalfresh.com.bd', '01788674901', SHA2('sell35#pass', 256), 'seller', 'active', '2026-02-02 15:58:00');

-- 5.2 customers (subtype rows). referred_by is filled afterwards with UPDATE.
INSERT INTO customers (customer_id, date_of_birth, gender) VALUES
  (1, '1995-03-14', 'male'),
  (2, '1998-07-22', 'female'),
  (3, '1992-11-05', 'male'),
  (4, '2000-01-30', 'female'),
  (5, '1989-06-18', 'male'),
  (6, '1997-09-09', 'female'),
  (7, '1985-12-25', 'male'),
  (8, '2001-04-17', 'female'),
  (9, '1994-08-02', 'male'),
  (10, '1999-02-11', 'female'),
  (11, '1990-10-27', 'male'),
  (12, '1996-05-06', 'female'),
  (13, '1993-01-19', 'male'),
  (14, '1988-03-03', 'female'),
  (15, '2002-07-12', 'male'),
  (16, '1991-11-29', 'female'),
  (17, '1997-12-08', 'male'),
  (18, '1995-06-21', 'female'),
  (19, '2003-09-15', 'male'),
  (20, '1987-04-04', 'female');

UPDATE customers SET referred_by = 1 WHERE customer_id = 2;
UPDATE customers SET referred_by = 1 WHERE customer_id = 4;
UPDATE customers SET referred_by = 2 WHERE customer_id = 6;
UPDATE customers SET referred_by = 5 WHERE customer_id = 8;
UPDATE customers SET referred_by = 5 WHERE customer_id = 9;
UPDATE customers SET referred_by = 5 WHERE customer_id = 10;
UPDATE customers SET referred_by = 3 WHERE customer_id = 12;
UPDATE customers SET referred_by = 9 WHERE customer_id = 15;
UPDATE customers SET referred_by = 1 WHERE customer_id = 17;
UPDATE customers SET referred_by = 6 WHERE customer_id = 18;
UPDATE customers SET referred_by = 15 WHERE customer_id = 19;
UPDATE customers SET referred_by = 7 WHERE customer_id = 20;

-- 5.3 sellers (subtype rows)
INSERT INTO sellers (seller_id, shop_name, trade_license_no, nid_no, bank_account_no, shop_city, commission_rate, is_verified) VALUES
  (21, 'TechZone BD', 'TRAD/DSCC/480399', '0480448790', '8450587429221', 'Dhaka', 4.00, 1),
  (22, 'Gadget Bazar', 'TRAD/DSCC/139608', '5305854250', '8173737211052', 'Dhaka', 7.00, 1),
  (23, 'Mobile Mela', 'TRAD/DSCC/179592', '5381709923', '9126532646585', 'Chattogram', 5.00, 1),
  (24, 'Laptop Lagbe', 'TRAD/DSCC/192093', '5308987141', '0901729475640', 'Dhaka', 7.00, 1),
  (25, 'Sound House', 'TRAD/DSCC/688917', '7081831815', '0990096706982', 'Sylhet', 8.00, 1),
  (26, 'Deshi Fashion', 'TRAD/DSCC/307851', '0370446031', '8028109450923', 'Narayanganj', 5.00, 1),
  (27, 'Nakshi Boutique', 'TRAD/DSCC/625546', '7043626574', '9405867684268', 'Jashore', 5.00, 1),
  (28, 'Ghor Sajai', 'TRAD/DSCC/862345', '2948361993', '3994808039883', 'Dhaka', 10.00, 1),
  (29, 'Rannaghor Store', 'TRAD/DSCC/166569', '3459805589', '2996136652474', 'Khulna', 5.00, 1),
  (30, 'Kathmistri Furniture', 'TRAD/DSCC/986510', '7845941943', '2257923499185', 'Bogura', 7.00, 1),
  (31, 'Dinajpur Agro', 'TRAD/DSCC/341497', '5239687664', '8059496012589', 'Dinajpur', 6.00, 0),
  (32, 'Mudi Dokan Online', 'TRAD/DSCC/371340', '3207685219', '2461785156698', 'Rajshahi', 10.00, 1),
  (33, 'Cha Bagan Shop', 'TRAD/DSCC/730969', '0664107574', '0632154619532', 'Moulvibazar', 6.00, 1),
  (34, 'Rupchorcha Beauty', 'TRAD/DSCC/841596', '2388198523', '1663827758209', 'Dhaka', 7.00, 1),
  (35, 'Barishal Fresh', 'TRAD/DSCC/690071', '2529138617', '9760957554009', 'Barishal', 5.00, 0);

-- 5.4 addresses (weak entity). Some customers have a second address.
INSERT INTO addresses (customer_id, address_no, label, street, area, city, division, postal_code) VALUES
  (1, 1, 'home', 'House 12, Road 5', 'Dhanmondi', 'Dhaka', 'Dhaka', '1209'),
  (1, 2, 'office', 'House 6, Road 2', 'Bashundhara R/A', 'Dhaka', 'Dhaka', '1229'),
  (2, 1, 'home', 'House 44, Road 11', 'Banani', 'Dhaka', 'Dhaka', '1213'),
  (3, 1, 'home', 'Flat 3B, Sector 7', 'Uttara', 'Dhaka', 'Dhaka', '1230'),
  (3, 2, 'office', '11 Kandirpar', 'Kandirpar', 'Cumilla', 'Chattogram', '3500'),
  (4, 1, 'home', 'Block C, Lane 2', 'Mirpur 10', 'Dhaka', 'Dhaka', '1216'),
  (5, 1, 'home', '22 Agrabad C/A', 'Agrabad', 'Chattogram', 'Chattogram', '4100'),
  (5, 2, 'office', '28 Motijheel C/A', 'Motijheel', 'Dhaka', 'Dhaka', '1000'),
  (6, 1, 'home', '15 GEC Circle', 'Khulshi', 'Chattogram', 'Chattogram', '4225'),
  (7, 1, 'home', 'House 8, Zindabazar', 'Zindabazar', 'Sylhet', 'Sylhet', '3100'),
  (7, 2, 'office', '2 Ambarkhana', 'Ambarkhana', 'Sylhet', 'Sylhet', '3100'),
  (8, 1, 'home', '31 Shaheb Bazar', 'Boalia', 'Rajshahi', 'Rajshahi', '6100'),
  (9, 1, 'home', '9 KDA Avenue', 'Sonadanga', 'Khulna', 'Khulna', '9100'),
  (10, 1, 'home', '17 Sadar Road', 'Sadar', 'Barishal', 'Barishal', '8200'),
  (11, 1, 'home', '5 Station Road', 'Sadar', 'Rangpur', 'Rangpur', '5400'),
  (11, 2, 'office', 'Flat 3B, Sector 7', 'Uttara', 'Dhaka', 'Dhaka', '1230'),
  (12, 1, 'home', '40 Charpara', 'Sadar', 'Mymensingh', 'Mymensingh', '2200'),
  (13, 1, 'home', 'House 6, Road 2', 'Bashundhara R/A', 'Dhaka', 'Dhaka', '1229'),
  (14, 1, 'home', '72 Chashara', 'Chashara', 'Narayanganj', 'Dhaka', '1400'),
  (14, 2, 'office', '15 GEC Circle', 'Khulshi', 'Chattogram', 'Chattogram', '4225'),
  (15, 1, 'home', '11 Kandirpar', 'Kandirpar', 'Cumilla', 'Chattogram', '3500'),
  (16, 1, 'home', '3 College Road', 'Sadar', 'Bogura', 'Rajshahi', '5800'),
  (16, 2, 'office', '31 Shaheb Bazar', 'Boalia', 'Rajshahi', 'Rajshahi', '6100'),
  (17, 1, 'home', '28 Motijheel C/A', 'Motijheel', 'Dhaka', 'Dhaka', '1000'),
  (18, 1, 'home', '19 Mohammadpur Housing', 'Mohammadpur', 'Dhaka', 'Dhaka', '1207'),
  (19, 1, 'home', '2 Ambarkhana', 'Ambarkhana', 'Sylhet', 'Sylhet', '3100'),
  (20, 1, 'home', '55 Jessore Road', 'Sadar', 'Jashore', 'Khulna', '7400');

-- 5.5 categories: 5 top-level categories and 10 sub-categories
INSERT INTO categories (category_id, category_name, parent_category_id) VALUES
  (1, 'Electronics', NULL),
  (2, 'Fashion', NULL),
  (3, 'Home & Living', NULL),
  (4, 'Groceries', NULL),
  (5, 'Health & Beauty', NULL),
  (6, 'Smartphones', 1),
  (7, 'Laptops', 1),
  (8, 'Audio & Headphones', 1),
  (9, 'Men''s Clothing', 2),
  (10, 'Women''s Clothing', 2),
  (11, 'Kitchen Appliances', 3),
  (12, 'Furniture', 3),
  (13, 'Rice & Staples', 4),
  (14, 'Snacks & Beverages', 4),
  (15, 'Skin Care', 5);

-- 5.6 products: 30 products, 3 in each sub-category
INSERT INTO products (product_id, seller_id, category_id, product_name, brand, sku, price, stock_qty, product_status, listed_at) VALUES
  (1, 21, 6, 'Samsung Galaxy A15 6/128GB', 'Samsung', 'SM-A15-128', 21999.00, 13, 'active', '2026-02-01 16:00:00'),
  (2, 22, 6, 'Xiaomi Redmi Note 13 8/256GB', 'Xiaomi', 'XM-RN13-256', 25999.00, 9, 'active', '2026-02-05 10:00:00'),
  (3, 23, 6, 'Walton Primo NX7 4/64GB', 'Walton', 'WL-NX7-64', 11490.00, 30, 'active', '2026-02-09 13:00:00'),
  (4, 21, 7, 'HP 15s Core i5 12th Gen Laptop', 'HP', 'HP-15S-I5', 72500.00, 25, 'active', '2026-02-13 15:00:00'),
  (5, 24, 7, 'Lenovo IdeaPad Slim 3 Ryzen 5', 'Lenovo', 'LN-IPS3-R5', 64900.00, 24, 'active', '2026-02-17 19:00:00'),
  (6, 24, 7, 'ASUS VivoBook 14 Core i3', 'ASUS', 'AS-VB14-I3', 49900.00, 27, 'active', '2026-02-21 12:00:00'),
  (7, 22, 8, 'JBL Tune 520BT Wireless Headphone', 'JBL', 'JBL-T520BT', 5490.00, 36, 'active', '2026-02-25 18:00:00'),
  (8, 23, 8, 'Realme Buds T110 Earbuds', 'Realme', 'RM-BT110', 2190.00, 84, 'active', '2026-03-01 10:00:00'),
  (9, 25, 8, 'Xiaomi Mi Portable Bluetooth Speaker', 'Xiaomi', 'XM-SPK-16W', 3850.00, 174, 'active', '2026-03-05 18:00:00'),
  (10, 26, 9, 'Men''s Cotton Panjabi (Eid Collection)', 'Deshi Fashion', 'DF-PNJ-M01', 1850.00, 96, 'active', '2026-03-09 11:00:00'),
  (11, 26, 9, 'Men''s Slim Fit Denim Jeans', 'Deshi Fashion', 'DF-JNS-M02', 1450.00, 58, 'active', '2026-03-13 12:00:00'),
  (12, 26, 9, 'Men''s Premium Polo T-Shirt', 'Deshi Fashion', 'DF-POLO-M03', 690.00, 99, 'active', '2026-03-17 20:00:00'),
  (13, 27, 10, 'Jamdani Saree (Handloom)', 'Nakshi Boutique', 'NB-JMD-W01', 6500.00, 115, 'active', '2026-03-21 17:00:00'),
  (14, 27, 10, 'Women''s Three-Piece Salwar Kameez', 'Nakshi Boutique', 'NB-3PC-W02', 2450.00, 182, 'active', '2026-03-25 17:00:00'),
  (15, 27, 10, 'Nakshi Kantha Stitch Kurti', 'Nakshi Boutique', 'NB-KRT-W03', 1250.00, 45, 'active', '2026-03-29 09:00:00'),
  (16, 29, 11, 'Miyako Rice Cooker 2.8L', 'Miyako', 'MY-RC-28', 3650.00, 212, 'active', '2026-04-02 17:00:00'),
  (17, 29, 11, 'Vision Blender 3-in-1 850W', 'Vision', 'VS-BL-850', 4200.00, 108, 'active', '2026-04-06 13:00:00'),
  (18, 28, 11, 'Walton Electric Kettle 1.8L', 'Walton', 'WL-EK-18', 1290.00, 192, 'active', '2026-04-10 16:00:00'),
  (19, 30, 12, 'Hatil Wooden Dining Table (6 Seater)', 'Hatil', 'HT-DT-6S', 48500.00, 36, 'active', '2026-04-14 10:00:00'),
  (20, 30, 12, 'RFL Plastic Chair (Set of 4)', 'RFL', 'RFL-CH-4', 3200.00, 117, 'active', '2026-04-18 17:00:00'),
  (21, 28, 12, 'Regal Steel Bookshelf 5 Tier', 'Regal', 'RG-BS-5T', 8900.00, 183, 'active', '2026-04-22 18:00:00'),
  (22, 31, 13, 'Chinigura Aromatic Rice 5kg', 'Pran', 'PR-CHN-5KG', 850.00, 62, 'active', '2026-04-26 13:00:00'),
  (23, 31, 13, 'Miniket Rice 25kg', 'Rupchanda', 'RC-MNK-25KG', 2150.00, 153, 'active', '2026-04-30 09:00:00'),
  (24, 32, 13, 'Deshi Masoor Dal 2kg', 'Teer', 'TR-MDL-2KG', 340.00, 41, 'active', '2026-05-04 17:00:00'),
  (25, 33, 14, 'Ispahani Mirzapore Tea 400g', 'Ispahani', 'IS-TEA-400', 260.00, 145, 'active', '2026-05-08 18:00:00'),
  (26, 32, 14, 'Pran Chanachur 300g (Pack of 6)', 'Pran', 'PR-CHN-300X6', 480.00, 35, 'active', '2026-05-12 10:00:00'),
  (27, 35, 14, 'Barishal Coconut Naru (500g)', 'Barishal Fresh', 'BF-NARU-500', 420.00, 85, 'active', '2026-05-16 11:00:00'),
  (28, 34, 15, 'Ribana Organic Aloe Vera Gel 100g', 'Ribana', 'RB-ALV-100', 450.00, 155, 'active', '2026-05-20 11:00:00'),
  (29, 34, 15, 'Lotus Herbals Sunscreen SPF 50', 'Lotus', 'LT-SUN-50', 780.00, 137, 'active', '2026-05-24 17:00:00'),
  (30, 34, 15, 'Skin Cafe Rose Water Toner 120ml', 'Skin Cafe', 'SC-RWT-120', 390.00, 0, 'inactive', '2026-05-28 10:00:00');

-- 5.7 product_images (multivalued attribute)
INSERT INTO product_images (product_id, image_no, image_url) VALUES
  (1, 1, 'https://cdn.marketplace.com.bd/img/sm-a15-128-1.jpg'),
  (1, 2, 'https://cdn.marketplace.com.bd/img/sm-a15-128-2.jpg'),
  (2, 1, 'https://cdn.marketplace.com.bd/img/xm-rn13-256-1.jpg'),
  (2, 2, 'https://cdn.marketplace.com.bd/img/xm-rn13-256-2.jpg'),
  (3, 1, 'https://cdn.marketplace.com.bd/img/wl-nx7-64-1.jpg'),
  (4, 1, 'https://cdn.marketplace.com.bd/img/hp-15s-i5-1.jpg'),
  (4, 2, 'https://cdn.marketplace.com.bd/img/hp-15s-i5-2.jpg'),
  (5, 1, 'https://cdn.marketplace.com.bd/img/ln-ips3-r5-1.jpg'),
  (5, 2, 'https://cdn.marketplace.com.bd/img/ln-ips3-r5-2.jpg'),
  (6, 1, 'https://cdn.marketplace.com.bd/img/as-vb14-i3-1.jpg'),
  (7, 1, 'https://cdn.marketplace.com.bd/img/jbl-t520bt-1.jpg'),
  (7, 2, 'https://cdn.marketplace.com.bd/img/jbl-t520bt-2.jpg'),
  (8, 1, 'https://cdn.marketplace.com.bd/img/rm-bt110-1.jpg'),
  (8, 2, 'https://cdn.marketplace.com.bd/img/rm-bt110-2.jpg'),
  (9, 1, 'https://cdn.marketplace.com.bd/img/xm-spk-16w-1.jpg'),
  (10, 1, 'https://cdn.marketplace.com.bd/img/df-pnj-m01-1.jpg'),
  (10, 2, 'https://cdn.marketplace.com.bd/img/df-pnj-m01-2.jpg'),
  (11, 1, 'https://cdn.marketplace.com.bd/img/df-jns-m02-1.jpg'),
  (11, 2, 'https://cdn.marketplace.com.bd/img/df-jns-m02-2.jpg'),
  (12, 1, 'https://cdn.marketplace.com.bd/img/df-polo-m03-1.jpg'),
  (13, 1, 'https://cdn.marketplace.com.bd/img/nb-jmd-w01-1.jpg'),
  (13, 2, 'https://cdn.marketplace.com.bd/img/nb-jmd-w01-2.jpg'),
  (14, 1, 'https://cdn.marketplace.com.bd/img/nb-3pc-w02-1.jpg'),
  (14, 2, 'https://cdn.marketplace.com.bd/img/nb-3pc-w02-2.jpg'),
  (15, 1, 'https://cdn.marketplace.com.bd/img/nb-krt-w03-1.jpg'),
  (16, 1, 'https://cdn.marketplace.com.bd/img/my-rc-28-1.jpg'),
  (16, 2, 'https://cdn.marketplace.com.bd/img/my-rc-28-2.jpg'),
  (17, 1, 'https://cdn.marketplace.com.bd/img/vs-bl-850-1.jpg'),
  (17, 2, 'https://cdn.marketplace.com.bd/img/vs-bl-850-2.jpg'),
  (18, 1, 'https://cdn.marketplace.com.bd/img/wl-ek-18-1.jpg'),
  (19, 1, 'https://cdn.marketplace.com.bd/img/ht-dt-6s-1.jpg'),
  (19, 2, 'https://cdn.marketplace.com.bd/img/ht-dt-6s-2.jpg'),
  (20, 1, 'https://cdn.marketplace.com.bd/img/rfl-ch-4-1.jpg'),
  (20, 2, 'https://cdn.marketplace.com.bd/img/rfl-ch-4-2.jpg'),
  (21, 1, 'https://cdn.marketplace.com.bd/img/rg-bs-5t-1.jpg'),
  (22, 1, 'https://cdn.marketplace.com.bd/img/pr-chn-5kg-1.jpg'),
  (22, 2, 'https://cdn.marketplace.com.bd/img/pr-chn-5kg-2.jpg'),
  (23, 1, 'https://cdn.marketplace.com.bd/img/rc-mnk-25kg-1.jpg'),
  (23, 2, 'https://cdn.marketplace.com.bd/img/rc-mnk-25kg-2.jpg'),
  (24, 1, 'https://cdn.marketplace.com.bd/img/tr-mdl-2kg-1.jpg'),
  (25, 1, 'https://cdn.marketplace.com.bd/img/is-tea-400-1.jpg'),
  (25, 2, 'https://cdn.marketplace.com.bd/img/is-tea-400-2.jpg'),
  (26, 1, 'https://cdn.marketplace.com.bd/img/pr-chn-300x6-1.jpg'),
  (26, 2, 'https://cdn.marketplace.com.bd/img/pr-chn-300x6-2.jpg'),
  (27, 1, 'https://cdn.marketplace.com.bd/img/bf-naru-500-1.jpg'),
  (28, 1, 'https://cdn.marketplace.com.bd/img/rb-alv-100-1.jpg'),
  (28, 2, 'https://cdn.marketplace.com.bd/img/rb-alv-100-2.jpg'),
  (29, 1, 'https://cdn.marketplace.com.bd/img/lt-sun-50-1.jpg'),
  (29, 2, 'https://cdn.marketplace.com.bd/img/lt-sun-50-2.jpg'),
  (30, 1, 'https://cdn.marketplace.com.bd/img/sc-rwt-120-1.jpg');

-- 5.8 couriers
INSERT INTO couriers (courier_id, courier_name, hotline, hq_city) VALUES
  (1, 'Pathao Courier', '09678100800', 'Dhaka'),
  (2, 'RedX', '09610007339', 'Dhaka'),
  (3, 'Steadfast Courier', '09678045045', 'Dhaka'),
  (4, 'Sundarban Courier Service', '09612003003', 'Dhaka'),
  (5, 'SA Paribahan', '09612776699', 'Dhaka'),
  (6, 'eCourier', '09642344444', 'Dhaka'),
  (7, 'Paperfly', '09612360456', 'Dhaka'),
  (8, 'Delivery Tiger', '09610500500', 'Dhaka'),
  (9, 'Janani Express', '01730071171', 'Chattogram'),
  (10, 'Karatoa Courier Service', '01713228383', 'Bogura'),
  (11, 'Continental Courier', '01777788700', 'Dhaka'),
  (12, 'USB Express', '01844502502', 'Dhaka'),
  (13, 'AJR Parcel and Courier', '01730319201', 'Sylhet'),
  (14, 'Daraz Express', '16492', 'Dhaka'),
  (15, 'Bangladesh Post EMS', '16267', 'Dhaka');

-- 5.9 orders: 60 orders (main transaction table). total_amount is
--     filled by the UPDATE statement in section 5.16.
INSERT INTO orders (order_id, customer_id, address_no, order_date, order_status) VALUES
  (1, 1, 2, '2026-07-01 20:59:00', 'delivered'),
  (2, 14, 2, '2026-07-03 16:45:00', 'delivered'),
  (3, 15, 1, '2026-07-06 01:02:00', 'delivered'),
  (4, 5, 1, '2026-07-08 01:59:00', 'delivered'),
  (5, 14, 1, '2026-07-10 06:35:00', 'delivered'),
  (6, 9, 1, '2026-07-12 12:05:00', 'delivered'),
  (7, 1, 2, '2026-07-14 15:37:00', 'delivered'),
  (8, 17, 1, '2026-07-16 19:31:00', 'delivered'),
  (9, 10, 1, '2026-07-19 05:56:00', 'delivered'),
  (10, 6, 1, '2026-07-21 10:45:00', 'delivered'),
  (11, 3, 2, '2026-07-23 15:56:00', 'delivered'),
  (12, 18, 1, '2026-07-25 23:00:00', 'cancelled'),
  (13, 7, 2, '2026-07-27 19:27:00', 'cancelled'),
  (14, 10, 1, '2026-07-30 02:00:00', 'delivered'),
  (15, 1, 1, '2026-08-01 12:20:00', 'delivered'),
  (16, 14, 1, '2026-08-03 12:07:00', 'delivered'),
  (17, 3, 1, '2026-08-05 19:40:00', 'delivered'),
  (18, 2, 1, '2026-08-07 23:27:00', 'delivered'),
  (19, 6, 1, '2026-08-10 10:30:00', 'delivered'),
  (20, 5, 2, '2026-08-12 04:18:00', 'delivered'),
  (21, 3, 2, '2026-08-14 09:15:00', 'delivered'),
  (22, 6, 1, '2026-08-17 00:36:00', 'delivered'),
  (23, 4, 1, '2026-08-19 00:49:00', 'delivered'),
  (24, 18, 1, '2026-08-21 07:10:00', 'cancelled'),
  (25, 4, 1, '2026-08-23 08:28:00', 'delivered'),
  (26, 7, 2, '2026-08-25 11:22:00', 'delivered'),
  (27, 4, 1, '2026-08-27 17:23:00', 'delivered'),
  (28, 9, 1, '2026-08-30 00:15:00', 'cancelled'),
  (29, 9, 1, '2026-09-01 01:15:00', 'cancelled'),
  (30, 18, 1, '2026-09-03 07:56:00', 'delivered'),
  (31, 13, 1, '2026-09-05 11:09:00', 'cancelled'),
  (32, 14, 2, '2026-09-07 20:52:00', 'delivered'),
  (33, 18, 1, '2026-09-09 19:15:00', 'delivered'),
  (34, 8, 1, '2026-09-12 08:48:00', 'delivered'),
  (35, 4, 1, '2026-09-14 07:10:00', 'delivered'),
  (36, 15, 1, '2026-09-16 13:32:00', 'delivered'),
  (37, 8, 1, '2026-09-18 23:50:00', 'delivered'),
  (38, 12, 1, '2026-09-21 06:12:00', 'delivered'),
  (39, 4, 1, '2026-09-23 10:56:00', 'delivered'),
  (40, 4, 1, '2026-09-25 14:57:00', 'delivered'),
  (41, 11, 2, '2026-09-27 15:07:00', 'delivered'),
  (42, 12, 1, '2026-09-29 14:52:00', 'delivered'),
  (43, 7, 1, '2026-10-02 03:44:00', 'delivered'),
  (44, 11, 1, '2026-10-04 00:39:00', 'delivered'),
  (45, 4, 1, '2026-10-06 08:50:00', 'delivered'),
  (46, 1, 2, '2026-10-08 19:54:00', 'delivered'),
  (47, 7, 2, '2026-10-10 21:08:00', 'delivered'),
  (48, 15, 1, '2026-10-12 21:53:00', 'shipped'),
  (49, 15, 1, '2026-10-15 10:38:00', 'delivered'),
  (50, 13, 1, '2026-10-17 05:04:00', 'shipped'),
  (51, 2, 1, '2026-10-19 20:52:00', 'delivered'),
  (52, 2, 1, '2026-10-21 16:06:00', 'shipped'),
  (53, 1, 1, '2026-10-24 04:58:00', 'shipped'),
  (54, 6, 1, '2026-10-26 04:06:00', 'confirmed'),
  (55, 18, 1, '2026-10-28 04:57:00', 'shipped'),
  (56, 6, 1, '2026-10-30 12:37:00', 'pending'),
  (57, 1, 1, '2026-11-01 22:45:00', 'pending'),
  (58, 15, 1, '2026-11-04 06:04:00', 'pending'),
  (59, 3, 1, '2026-11-06 03:44:00', 'confirmed'),
  (60, 6, 1, '2026-11-08 05:16:00', 'pending');

-- 5.10 order_items: unit_price is the price at the time of the order
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
  (1, 1, 1, 21999.00),
  (1, 8, 1, 2190.00),
  (2, 23, 2, 2150.00),
  (3, 28, 1, 450.00),
  (3, 29, 1, 780.00),
  (3, 4, 1, 72500.00),
  (4, 1, 1, 21999.00),
  (4, 2, 1, 25999.00),
  (5, 23, 2, 2150.00),
  (6, 14, 1, 2450.00),
  (7, 2, 1, 25999.00),
  (7, 25, 1, 260.00),
  (8, 8, 2, 2190.00),
  (9, 22, 2, 850.00),
  (9, 4, 1, 72500.00),
  (10, 14, 2, 2450.00),
  (10, 27, 2, 420.00),
  (10, 26, 2, 480.00),
  (10, 15, 1, 1250.00),
  (11, 17, 1, 4200.00),
  (11, 8, 3, 2190.00),
  (11, 23, 5, 2150.00),
  (12, 29, 3, 780.00),
  (12, 17, 1, 4200.00),
  (13, 10, 5, 1850.00),
  (13, 9, 1, 3850.00),
  (13, 8, 5, 2190.00),
  (14, 24, 2, 340.00),
  (14, 29, 2, 780.00),
  (14, 19, 1, 48500.00),
  (15, 3, 1, 11490.00),
  (15, 12, 2, 690.00),
  (16, 5, 1, 64900.00),
  (16, 17, 1, 4200.00),
  (16, 24, 2, 340.00),
  (17, 5, 1, 64900.00),
  (18, 26, 5, 480.00),
  (18, 12, 1, 690.00),
  (18, 20, 1, 3200.00),
  (18, 2, 1, 25999.00),
  (19, 27, 1, 420.00),
  (19, 7, 2, 5490.00),
  (19, 29, 3, 780.00),
  (19, 25, 1, 260.00),
  (20, 3, 1, 11490.00),
  (20, 7, 3, 5490.00),
  (21, 8, 2, 2190.00),
  (21, 11, 3, 1450.00),
  (21, 14, 2, 2450.00),
  (21, 13, 1, 6500.00),
  (22, 5, 1, 64900.00),
  (22, 27, 2, 420.00),
  (22, 16, 1, 3650.00),
  (23, 17, 2, 4200.00),
  (24, 22, 1, 850.00),
  (24, 6, 1, 49900.00),
  (24, 28, 2, 450.00),
  (25, 14, 1, 2450.00),
  (26, 16, 3, 3650.00),
  (26, 18, 3, 1290.00),
  (27, 9, 3, 3850.00),
  (28, 22, 2, 850.00),
  (29, 13, 1, 6500.00),
  (29, 12, 2, 690.00),
  (30, 26, 1, 480.00),
  (30, 20, 1, 3200.00),
  (31, 13, 1, 6500.00),
  (32, 19, 1, 48500.00),
  (32, 23, 2, 2150.00),
  (32, 9, 2, 3850.00),
  (32, 17, 1, 4200.00),
  (33, 16, 1, 3650.00),
  (33, 10, 1, 1850.00),
  (34, 18, 1, 1290.00),
  (34, 26, 3, 480.00),
  (35, 6, 1, 49900.00),
  (36, 18, 2, 1290.00),
  (36, 5, 1, 64900.00),
  (36, 2, 1, 25999.00),
  (36, 27, 3, 420.00),
  (37, 2, 1, 25999.00),
  (37, 28, 1, 450.00),
  (38, 7, 1, 5490.00),
  (38, 28, 1, 450.00),
  (38, 19, 1, 48500.00),
  (39, 2, 1, 25999.00),
  (39, 27, 1, 420.00),
  (40, 27, 1, 420.00),
  (41, 24, 1, 340.00),
  (41, 15, 2, 1250.00),
  (41, 23, 3, 2150.00),
  (42, 18, 2, 1290.00),
  (42, 23, 2, 2150.00),
  (42, 2, 1, 25999.00),
  (43, 14, 1, 2450.00),
  (44, 5, 1, 64900.00),
  (44, 1, 1, 21999.00),
  (45, 17, 1, 4200.00),
  (45, 3, 1, 11490.00),
  (46, 19, 1, 48500.00),
  (46, 5, 1, 64900.00),
  (47, 15, 1, 1250.00),
  (47, 3, 1, 11490.00),
  (47, 17, 2, 4200.00),
  (48, 12, 1, 690.00),
  (48, 19, 1, 48500.00),
  (48, 4, 1, 72500.00),
  (49, 17, 2, 4200.00),
  (50, 10, 1, 1850.00),
  (51, 11, 2, 1450.00),
  (51, 25, 1, 260.00),
  (52, 18, 1, 1290.00),
  (52, 11, 2, 1450.00),
  (52, 15, 1, 1250.00),
  (53, 18, 1, 1290.00),
  (53, 17, 2, 4200.00),
  (53, 11, 1, 1450.00),
  (54, 18, 3, 1290.00),
  (54, 9, 3, 3850.00),
  (54, 28, 1, 450.00),
  (55, 24, 2, 340.00),
  (55, 29, 2, 780.00),
  (56, 8, 1, 2190.00),
  (56, 23, 1, 2150.00),
  (57, 26, 1, 480.00),
  (57, 12, 1, 690.00),
  (58, 20, 3, 3200.00),
  (58, 11, 3, 1450.00),
  (59, 10, 3, 1850.00),
  (60, 22, 1, 850.00),
  (60, 8, 2, 2190.00),
  (60, 1, 1, 21999.00);

-- 5.11 payments: a few new orders have no payment row yet
INSERT INTO payments (payment_id, order_id, method, amount, payment_status, transaction_ref, paid_at) VALUES
  (1, 1, 'Nagad', 24189.00, 'paid', 'NGMRE6GWVZ', '2026-07-01 21:37:00'),
  (2, 2, 'Card', 4300.00, 'paid', 'CDKPUTA6XV', '2026-07-03 17:00:00'),
  (3, 3, 'Card', 73730.00, 'paid', 'CDG22GRM24', '2026-07-06 01:29:00'),
  (4, 4, 'Nagad', 47998.00, 'paid', 'NGPY2TVZFL', '2026-07-08 02:31:00'),
  (5, 5, 'Cash on Delivery', 4300.00, 'paid', 'CODQVK4MRNU', '2026-07-14 09:35:00'),
  (6, 6, 'Nagad', 2450.00, 'paid', 'NGWGRBNT23', '2026-07-12 12:13:00'),
  (7, 7, 'Card', 26259.00, 'paid', 'CD8D5S3Z9T', '2026-07-14 16:04:00'),
  (8, 8, 'Card', 4380.00, 'paid', 'CDJQVKCWDP', '2026-07-16 19:34:00'),
  (9, 9, 'Cash on Delivery', 74200.00, 'paid', 'COD5QZQWH5P', '2026-07-21 08:56:00'),
  (10, 10, 'Card', 7950.00, 'paid', 'CD2AVBRMQE', '2026-07-21 10:57:00'),
  (11, 11, 'bKash', 21520.00, 'paid', 'BKU456F56F', '2026-07-23 16:20:00'),
  (12, 12, 'bKash', 6540.00, 'failed', NULL, NULL),
  (13, 13, 'bKash', 24050.00, 'failed', NULL, NULL),
  (14, 14, 'Cash on Delivery', 50740.00, 'paid', 'CODRPT4GWFZ', '2026-08-01 05:00:00'),
  (15, 15, 'Nagad', 12870.00, 'paid', 'NG2S8CESZS', '2026-08-01 12:51:00'),
  (16, 16, 'bKash', 69780.00, 'paid', 'BKWRD5ARL4', '2026-08-03 12:44:00'),
  (17, 17, 'Cash on Delivery', 64900.00, 'paid', 'CODR2GKGDUS', '2026-08-09 22:40:00'),
  (18, 18, 'bKash', 32289.00, 'paid', 'BKD4WU2TEJ', '2026-08-07 23:48:00'),
  (19, 19, 'Cash on Delivery', 14000.00, 'paid', 'COD5TSYNZR4', '2026-08-14 13:30:00'),
  (20, 20, 'Nagad', 27960.00, 'paid', 'NGZWDB3YLE', '2026-08-12 04:37:00'),
  (21, 21, 'bKash', 20130.00, 'paid', 'BKPH8MEXZN', '2026-08-14 09:52:00'),
  (22, 22, 'Cash on Delivery', 69390.00, 'paid', 'CODVPZYA56W', '2026-08-21 03:36:00'),
  (23, 23, 'Nagad', 8400.00, 'paid', 'NG7MCDVHVJ', '2026-08-19 01:11:00'),
  (24, 24, 'Rocket', 51650.00, 'failed', NULL, NULL),
  (25, 25, 'Rocket', 2450.00, 'paid', 'RKJVGUTUAJ', '2026-08-23 09:04:00'),
  (26, 26, 'Nagad', 14820.00, 'paid', 'NGWU5BBMSB', '2026-08-25 11:34:00'),
  (27, 27, 'Nagad', 11550.00, 'paid', 'NGHG7QC4H9', '2026-08-27 17:52:00'),
  (28, 28, 'bKash', 1700.00, 'failed', NULL, NULL),
  (29, 29, 'Nagad', 7880.00, 'refunded', 'NG8ZHGHJKK', '2026-09-01 01:39:00'),
  (30, 30, 'bKash', 3680.00, 'paid', 'BK85Y6KNT7', '2026-09-03 08:00:00'),
  (31, 31, 'bKash', 6500.00, 'failed', NULL, NULL),
  (32, 32, 'Nagad', 64700.00, 'paid', 'NGRKL54VGG', '2026-09-07 21:00:00'),
  (33, 33, 'bKash', 5500.00, 'paid', 'BKTTBVDJER', '2026-09-09 19:30:00'),
  (34, 34, 'Nagad', 2730.00, 'paid', 'NGDGQJ5NNX', '2026-09-12 09:01:00'),
  (35, 35, 'Rocket', 49900.00, 'paid', 'RKEUFK5C7U', '2026-09-14 07:43:00'),
  (36, 36, 'Card', 94739.00, 'paid', 'CDQ867PKPD', '2026-09-16 13:47:00'),
  (37, 37, 'Cash on Delivery', 26449.00, 'paid', 'COD85GPBZBV', '2026-09-22 02:50:00'),
  (38, 38, 'Nagad', 54440.00, 'paid', 'NG2TH9EP8P', '2026-09-21 06:47:00'),
  (39, 39, 'Rocket', 26419.00, 'paid', 'RK7Q46YNUF', '2026-09-23 11:29:00'),
  (40, 40, 'Nagad', 420.00, 'paid', 'NGC78XYM9K', '2026-09-25 15:34:00'),
  (41, 41, 'bKash', 9290.00, 'paid', 'BKEXXWK8PX', '2026-09-27 15:31:00'),
  (42, 42, 'Card', 32879.00, 'paid', 'CDXPLDHHYG', '2026-09-29 14:54:00'),
  (43, 43, 'bKash', 2450.00, 'paid', 'BKNAVTX35L', '2026-10-02 03:50:00'),
  (44, 44, 'Nagad', 86899.00, 'paid', 'NGN2LSVWB5', '2026-10-04 01:19:00'),
  (45, 45, 'bKash', 15690.00, 'paid', 'BK8HGAHWY4', '2026-10-06 09:09:00'),
  (46, 46, 'Nagad', 113400.00, 'paid', 'NGAGHZJ63S', '2026-10-08 20:21:00'),
  (47, 47, 'Card', 21140.00, 'paid', 'CD47MY3D2J', '2026-10-10 21:16:00'),
  (48, 48, 'Card', 121690.00, 'paid', 'CD3TLPS2D2', '2026-10-12 22:29:00'),
  (49, 49, 'Nagad', 8400.00, 'paid', 'NGVKSJJZXA', '2026-10-15 11:08:00'),
  (50, 50, 'bKash', 1850.00, 'paid', 'BKAXKMAJ3N', '2026-10-17 05:42:00'),
  (51, 51, 'bKash', 3160.00, 'paid', 'BKR8VNQCAE', '2026-10-19 20:54:00'),
  (52, 52, 'Cash on Delivery', 5440.00, 'pending', NULL, NULL),
  (53, 53, 'bKash', 11140.00, 'paid', 'BKF6FF6HEE', '2026-10-24 05:33:00'),
  (54, 54, 'bKash', 15870.00, 'paid', 'BKZFJXE9M8', '2026-10-26 04:28:00'),
  (55, 55, 'Nagad', 2240.00, 'paid', 'NGK8YK37JS', '2026-10-28 05:29:00'),
  (56, 56, 'bKash', 4340.00, 'pending', NULL, NULL),
  (57, 59, 'Cash on Delivery', 5550.00, 'pending', NULL, NULL);

-- 5.12 deliveries: only shipped/delivered orders (and some confirmed ones)
INSERT INTO deliveries (delivery_id, order_id, courier_id, tracking_no, delivery_status, shipped_at, delivered_at) VALUES
  (1, 1, 7, 'TRK202600001BD', 'delivered', '2026-07-02 23:59:00', '2026-07-06 08:59:00'),
  (2, 2, 7, 'TRK202600002BD', 'delivered', '2026-07-04 17:45:00', '2026-07-09 01:45:00'),
  (3, 3, 7, 'TRK202600003BD', 'delivered', '2026-07-07 06:02:00', '2026-07-09 09:02:00'),
  (4, 4, 4, 'TRK202600004BD', 'delivered', '2026-07-09 07:59:00', '2026-07-12 09:59:00'),
  (5, 5, 2, 'TRK202600005BD', 'delivered', '2026-07-11 13:35:00', '2026-07-13 20:35:00'),
  (6, 6, 6, 'TRK202600006BD', 'delivered', '2026-07-13 15:05:00', '2026-07-16 19:05:00'),
  (7, 7, 7, 'TRK202600007BD', 'delivered', '2026-07-15 23:37:00', '2026-07-18 03:37:00'),
  (8, 8, 2, 'TRK202600008BD', 'delivered', '2026-07-17 20:31:00', '2026-07-21 21:31:00'),
  (9, 9, NULL, 'TRK202600009BD', 'delivered', '2026-07-20 13:56:00', '2026-07-23 20:56:00'),
  (10, 10, 7, 'TRK202600010BD', 'delivered', '2026-07-22 14:45:00', '2026-07-24 16:45:00'),
  (11, 11, 5, 'TRK202600011BD', 'delivered', '2026-07-24 17:56:00', '2026-07-27 23:56:00'),
  (12, 14, 8, 'TRK202600014BD', 'delivered', '2026-07-31 08:00:00', '2026-08-03 16:00:00'),
  (13, 15, 8, 'TRK202600015BD', 'delivered', '2026-08-02 20:20:00', '2026-08-07 04:20:00'),
  (14, 16, 9, 'TRK202600016BD', 'delivered', '2026-08-04 14:07:00', '2026-08-08 19:07:00'),
  (15, 17, 8, 'TRK202600017BD', 'delivered', '2026-08-06 21:40:00', '2026-08-09 21:40:00'),
  (16, 18, 4, 'TRK202600018BD', 'delivered', '2026-08-09 01:27:00', '2026-08-12 02:27:00'),
  (17, 19, 9, 'TRK202600019BD', 'delivered', '2026-08-11 17:30:00', '2026-08-15 02:30:00'),
  (18, 20, 6, 'TRK202600020BD', 'delivered', '2026-08-13 12:18:00', '2026-08-17 19:18:00'),
  (19, 21, 5, 'TRK202600021BD', 'delivered', '2026-08-15 16:15:00', '2026-08-19 19:15:00'),
  (20, 22, 7, 'TRK202600022BD', 'delivered', '2026-08-18 07:36:00', '2026-08-19 10:36:00'),
  (21, 23, 8, 'TRK202600023BD', 'delivered', '2026-08-20 02:49:00', '2026-08-23 10:49:00'),
  (22, 25, 6, 'TRK202600025BD', 'delivered', '2026-08-24 16:28:00', '2026-08-26 18:28:00'),
  (23, 26, 8, 'TRK202600026BD', 'delivered', '2026-08-26 12:22:00', '2026-08-27 13:22:00'),
  (24, 27, 3, 'TRK202600027BD', 'delivered', '2026-08-28 21:23:00', '2026-09-02 04:23:00'),
  (25, 30, 7, 'TRK202600030BD', 'delivered', '2026-09-04 12:56:00', '2026-09-06 21:56:00'),
  (26, 32, 1, 'TRK202600032BD', 'delivered', '2026-09-09 00:52:00', '2026-09-12 08:52:00'),
  (27, 33, 8, 'TRK202600033BD', 'delivered', '2026-09-10 20:15:00', '2026-09-13 23:15:00'),
  (28, 34, 3, 'TRK202600034BD', 'delivered', '2026-09-13 10:48:00', '2026-09-14 19:48:00'),
  (29, 35, 7, 'TRK202600035BD', 'delivered', '2026-09-15 15:10:00', '2026-09-20 00:10:00'),
  (30, 36, 2, 'TRK202600036BD', 'delivered', '2026-09-17 15:32:00', '2026-09-20 17:32:00'),
  (31, 37, 9, 'TRK202600037BD', 'delivered', '2026-09-20 06:50:00', '2026-09-22 14:50:00'),
  (32, 38, 9, 'TRK202600038BD', 'delivered', '2026-09-22 13:12:00', '2026-09-26 16:12:00'),
  (33, 39, 7, 'TRK202600039BD', 'delivered', '2026-09-24 18:56:00', '2026-09-25 23:56:00'),
  (34, 40, 9, 'TRK202600040BD', 'delivered', '2026-09-26 19:57:00', '2026-09-28 00:57:00'),
  (35, 41, 2, 'TRK202600041BD', 'delivered', '2026-09-28 21:07:00', '2026-10-03 02:07:00'),
  (36, 42, 6, 'TRK202600042BD', 'delivered', '2026-09-30 17:52:00', '2026-10-04 00:52:00'),
  (37, 43, 8, 'TRK202600043BD', 'delivered', '2026-10-03 07:44:00', '2026-10-07 08:44:00'),
  (38, 44, 7, 'TRK202600044BD', 'delivered', '2026-10-05 07:39:00', '2026-10-07 07:39:00'),
  (39, 45, 2, 'TRK202600045BD', 'delivered', '2026-10-07 12:50:00', '2026-10-08 21:50:00'),
  (40, 46, 9, 'TRK202600046BD', 'delivered', '2026-10-10 02:54:00', '2026-10-13 03:54:00'),
  (41, 47, 7, 'TRK202600047BD', 'delivered', '2026-10-12 02:08:00', '2026-10-15 04:08:00'),
  (42, 48, 9, 'TRK202600048BD', 'in_transit', '2026-10-13 23:53:00', NULL),
  (43, 49, 2, 'TRK202600049BD', 'delivered', '2026-10-16 14:38:00', '2026-10-19 14:38:00'),
  (44, 50, 3, 'TRK202600050BD', 'in_transit', '2026-10-18 09:04:00', NULL),
  (45, 51, 9, 'TRK202600051BD', 'delivered', '2026-10-21 04:52:00', '2026-10-23 11:52:00'),
  (46, 52, 3, 'TRK202600052BD', 'in_transit', '2026-10-22 22:06:00', NULL),
  (47, 53, 7, 'TRK202600053BD', 'in_transit', '2026-10-25 10:58:00', NULL),
  (48, 55, 6, 'TRK202600055BD', 'in_transit', '2026-10-29 09:57:00', NULL);

-- 5.13 reviews: written only by customers whose order was delivered
INSERT INTO reviews (review_id, customer_id, product_id, rating, comment, review_date) VALUES
  (1, 8, 2, 5, 'Exactly as shown in the picture.', '2026-09-27'),
  (2, 2, 11, 5, 'Fast delivery, packaging was excellent.', '2026-10-29'),
  (3, 8, 18, 4, 'Exactly as shown in the picture.', '2026-09-19'),
  (4, 15, 4, 4, 'Exactly as shown in the picture.', '2026-07-10'),
  (5, 14, 23, 4, 'Fast delivery, packaging was excellent.', '2026-09-13'),
  (6, 2, 26, 3, 'Good, but delivery took a little long.', '2026-08-18'),
  (7, 4, 27, 4, 'Seller was very helpful, product is genuine.', '2026-09-29'),
  (8, 5, 7, 5, 'Exactly as shown in the picture.', '2026-08-18'),
  (9, 3, 23, 5, 'Value for money. Recommended!', '2026-07-28'),
  (10, 6, 7, 5, 'Fast delivery, packaging was excellent.', '2026-08-19'),
  (11, 3, 8, 1, 'Not satisfied, quality is below expectation.', '2026-08-01'),
  (12, 11, 24, 5, 'Original product, khub bhalo quality.', '2026-10-09'),
  (13, 10, 22, 4, 'Original product, khub bhalo quality.', '2026-07-26'),
  (14, 2, 12, 4, 'Exactly as shown in the picture.', '2026-08-14'),
  (15, 7, 17, 4, 'Value for money. Recommended!', '2026-10-16'),
  (16, 7, 14, 5, 'Fast delivery, packaging was excellent.', '2026-10-08'),
  (17, 18, 16, 2, 'Packaging was damaged on arrival.', '2026-09-15'),
  (18, 11, 1, 5, 'Seller was very helpful, product is genuine.', '2026-10-13'),
  (19, 6, 16, 4, 'Fast delivery, packaging was excellent.', '2026-08-25'),
  (20, 3, 11, 3, 'Average quality, as expected.', '2026-08-23'),
  (21, 15, 18, 3, 'Good, but delivery took a little long.', '2026-09-23'),
  (22, 6, 26, 4, 'Original product, khub bhalo quality.', '2026-07-26'),
  (23, 6, 15, 4, 'Seller was very helpful, product is genuine.', '2026-07-27'),
  (24, 14, 17, 5, 'Value for money. Recommended!', '2026-08-10'),
  (25, 3, 14, 3, 'Average quality, as expected.', '2026-08-25'),
  (26, 14, 24, 5, 'Value for money. Recommended!', '2026-08-13'),
  (27, 8, 28, 5, 'Original product, khub bhalo quality.', '2026-09-26'),
  (28, 4, 9, 5, 'Exactly as shown in the picture.', '2026-09-07'),
  (29, 6, 27, 2, 'Not satisfied, quality is below expectation.', '2026-08-25'),
  (30, 6, 5, 4, 'Seller was very helpful, product is genuine.', '2026-08-20'),
  (31, 7, 3, 4, 'Original product, khub bhalo quality.', '2026-10-19'),
  (32, 18, 26, 3, 'Average quality, as expected.', '2026-09-08');

-- 5.14 carts and cart_items
INSERT INTO carts (cart_id, customer_id, created_at) VALUES
  (1, 1, '2026-10-01 00:00:00'),
  (2, 2, '2026-10-03 01:00:00'),
  (3, 3, '2026-10-05 02:00:00'),
  (4, 4, '2026-10-07 03:00:00'),
  (5, 5, '2026-10-09 04:00:00'),
  (6, 6, '2026-10-11 05:00:00'),
  (7, 7, '2026-10-13 06:00:00'),
  (8, 8, '2026-10-15 07:00:00'),
  (9, 9, '2026-10-17 08:00:00'),
  (10, 10, '2026-10-19 09:00:00'),
  (11, 11, '2026-10-21 10:00:00'),
  (12, 12, '2026-10-23 11:00:00'),
  (13, 13, '2026-10-25 12:00:00'),
  (14, 14, '2026-10-27 13:00:00'),
  (15, 19, '2026-10-29 14:00:00'),
  (16, 20, '2026-10-31 15:00:00');

INSERT INTO cart_items (cart_id, product_id, quantity, added_at) VALUES
  (1, 16, 1, '2026-10-20 16:00:00'),
  (1, 28, 1, '2026-10-21 04:00:00'),
  (1, 26, 3, '2026-10-21 02:00:00'),
  (2, 7, 1, '2026-10-21 07:00:00'),
  (3, 23, 1, '2026-10-22 23:00:00'),
  (3, 25, 3, '2026-10-23 01:00:00'),
  (4, 28, 3, '2026-10-24 04:00:00'),
  (4, 3, 1, '2026-10-23 03:00:00'),
  (5, 15, 1, '2026-10-24 15:00:00'),
  (5, 13, 1, '2026-10-24 13:00:00'),
  (5, 2, 1, '2026-10-24 02:00:00'),
  (6, 26, 2, '2026-10-26 02:00:00'),
  (6, 29, 1, '2026-10-26 05:00:00'),
  (7, 7, 2, '2026-10-26 07:00:00'),
  (7, 28, 1, '2026-10-27 04:00:00'),
  (8, 1, 2, '2026-10-27 01:00:00'),
  (9, 7, 1, '2026-10-28 07:00:00'),
  (9, 17, 3, '2026-10-28 17:00:00'),
  (10, 14, 2, '2026-10-29 14:00:00'),
  (10, 1, 2, '2026-10-29 01:00:00'),
  (11, 14, 3, '2026-10-30 14:00:00'),
  (12, 28, 2, '2026-11-01 04:00:00'),
  (12, 14, 1, '2026-10-31 14:00:00'),
  (13, 5, 3, '2026-11-01 05:00:00'),
  (13, 17, 1, '2026-11-01 17:00:00'),
  (14, 1, 3, '2026-11-02 01:00:00'),
  (14, 26, 2, '2026-11-03 02:00:00'),
  (15, 15, 2, '2026-11-03 15:00:00'),
  (15, 23, 2, '2026-11-03 23:00:00'),
  (16, 6, 2, '2026-11-04 06:00:00'),
  (16, 28, 1, '2026-11-05 04:00:00');

-- 5.15 wishlists
INSERT INTO wishlists (customer_id, product_id, wished_at) VALUES
  (1, 2, '2026-09-12 01:00:00'),
  (1, 7, '2026-09-17 01:00:00'),
  (2, 1, '2026-09-12 02:00:00'),
  (2, 21, '2026-10-22 02:00:00'),
  (3, 1, '2026-09-13 03:00:00'),
  (3, 21, '2026-09-23 03:00:00'),
  (3, 30, '2026-10-20 03:00:00'),
  (4, 21, '2026-10-14 04:00:00'),
  (4, 30, '2026-09-30 04:00:00'),
  (5, 13, '2026-09-25 05:00:00'),
  (5, 19, '2026-10-25 05:00:00'),
  (6, 21, '2026-10-06 06:00:00'),
  (6, 30, '2026-10-10 06:00:00'),
  (8, 1, '2026-09-18 08:00:00'),
  (8, 21, '2026-09-28 08:00:00'),
  (10, 5, '2026-09-10 10:00:00'),
  (10, 13, '2026-10-10 10:00:00'),
  (12, 9, '2026-09-18 12:00:00'),
  (12, 21, '2026-09-12 12:00:00'),
  (14, 7, '2026-10-28 14:00:00'),
  (14, 19, '2026-09-26 14:00:00'),
  (16, 5, '2026-10-10 16:00:00'),
  (16, 19, '2026-09-14 16:00:00'),
  (19, 5, '2026-10-25 19:00:00'),
  (19, 21, '2026-10-29 19:00:00'),
  (19, 30, '2026-09-30 19:00:00'),
  (20, 13, '2026-09-20 20:00:00'),
  (20, 30, '2026-09-10 20:00:00');
-- ---------------------------------------------------------------------
-- 5.16 UPDATE statements
-- ---------------------------------------------------------------------
-- (a) fill the derived column orders.total_amount from the order items
UPDATE orders o
SET o.total_amount = (SELECT SUM(oi.quantity * oi.unit_price)
                      FROM order_items oi
                      WHERE oi.order_id = o.order_id);

-- (b) give 1 loyalty point for every 100 taka of delivered orders
UPDATE customers c
SET c.loyalty_points = (SELECT COALESCE(FLOOR(SUM(o.total_amount) / 100), 0)
                        FROM orders o
                        WHERE o.customer_id = c.customer_id
                          AND o.order_status = 'delivered');

-- (c) a single-row update: suspend one account
UPDATE users SET account_status = 'suspended' WHERE user_id = 20;

-- ---------------------------------------------------------------------
-- 5.17 DELETE statements
-- ---------------------------------------------------------------------
-- (a) a simple delete: customer 20 removes one product from the wishlist
DELETE FROM wishlists WHERE customer_id = 20 AND product_id = 30;

-- (b) a delete that triggers a CASCADE:
--     deleting cart 16 also deletes its rows in cart_items
SELECT COUNT(*) AS cart_items_before FROM cart_items WHERE cart_id = 16;
DELETE FROM carts WHERE cart_id = 16;
SELECT COUNT(*) AS cart_items_after  FROM cart_items WHERE cart_id = 16;

-- 5.18 row counts of every table after loading
SELECT 'users' AS table_name, COUNT(*) AS total_rows FROM users
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'addresses', COUNT(*) FROM addresses
UNION ALL SELECT 'categories', COUNT(*) FROM categories
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'product_images', COUNT(*) FROM product_images
UNION ALL SELECT 'couriers', COUNT(*) FROM couriers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'deliveries', COUNT(*) FROM deliveries
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews
UNION ALL SELECT 'carts', COUNT(*) FROM carts
UNION ALL SELECT 'cart_items', COUNT(*) FROM cart_items
UNION ALL SELECT 'wishlists', COUNT(*) FROM wishlists;
-- =====================================================================
-- TASK 6: QUERIES (24 business questions)
-- RA = the equivalent relational algebra expression (given for 10 queries)
-- =====================================================================

-- Q1 (INNER JOIN): Which products cost more than 5,000 taka, and who sells them?
-- RA: π product_name, category_name, shop_name, price
--        (σ price > 5000 (products ⋈ categories ⋈ sellers))
SELECT p.product_name, c.category_name, s.shop_name, p.price
FROM products p
INNER JOIN categories c ON c.category_id = p.category_id
INNER JOIN sellers s    ON s.seller_id   = p.seller_id
WHERE p.price > 5000
ORDER BY p.price DESC;

-- Q2 (LEFT JOIN): How many orders has every customer placed, including
--                 customers who have never ordered?
SELECT c.customer_id,
       CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
       COUNT(o.order_id) AS total_orders
FROM customers c
INNER JOIN users u ON u.user_id = c.customer_id
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, customer_name
ORDER BY total_orders DESC, c.customer_id;

-- Q3 (RIGHT JOIN): How many parcels has each courier handled, including
--                  couriers we have never used?
SELECT c.courier_name, COUNT(d.delivery_id) AS parcels_handled
FROM deliveries d
RIGHT JOIN couriers c ON c.courier_id = d.courier_id
GROUP BY c.courier_id, c.courier_name
ORDER BY parcels_handled DESC, c.courier_name;

-- Q4 (FULL OUTER JOIN, emulated): Show couriers with no delivery AND
--     deliveries with no courier in one result.
--     MariaDB has no FULL OUTER JOIN, so LEFT JOIN UNION RIGHT JOIN is used.
SELECT c.courier_name, d.tracking_no, d.delivery_status
FROM couriers c
LEFT JOIN deliveries d ON d.courier_id = c.courier_id
WHERE d.delivery_id IS NULL
UNION
SELECT c.courier_name, d.tracking_no, d.delivery_status
FROM couriers c
RIGHT JOIN deliveries d ON d.courier_id = c.courier_id
WHERE c.courier_id IS NULL;

-- Q5 (SELF JOIN): Which customer referred which customer?
-- RA: π r.customer_id, c.customer_id
--        (ρ r (customers) ⋈ r.customer_id = c.referred_by ρ c (customers))
SELECT CONCAT(ru.first_name, ' ', ru.last_name) AS referrer,
       CONCAT(cu.first_name, ' ', cu.last_name) AS referred_customer
FROM customers c
INNER JOIN customers r ON r.customer_id = c.referred_by
INNER JOIN users cu ON cu.user_id = c.customer_id
INNER JOIN users ru ON ru.user_id = r.customer_id
ORDER BY referrer, referred_customer;

-- Q6 (NATURAL JOIN): What is inside every shopping cart right now?
--     carts and cart_items share only the column cart_id.
SELECT cart_id, customer_id, product_id, quantity
FROM carts NATURAL JOIN cart_items
ORDER BY cart_id, product_id;

-- Q7 (GROUP BY + HAVING): Which sellers earned more than 50,000 taka
--                          from delivered orders?
-- RA: σ revenue > 50000 ( shop_name γ SUM(quantity * unit_price) → revenue
--        (σ order_status = 'delivered' (sellers ⋈ products ⋈ order_items ⋈ orders)))
SELECT s.shop_name,
       COUNT(DISTINCT o.order_id)        AS orders_served,
       SUM(oi.quantity * oi.unit_price)  AS revenue
FROM sellers s
INNER JOIN products p     ON p.seller_id   = s.seller_id
INNER JOIN order_items oi ON oi.product_id = p.product_id
INNER JOIN orders o       ON o.order_id    = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.shop_name
HAVING revenue > 50000
ORDER BY revenue DESC;

-- Q8 (nested subquery): Which products are priced above the average price?
-- RA: π product_name, price (products ⋈ price > avg_price (γ AVG(price) → avg_price (products)))
SELECT product_name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC;

-- Q9 (correlated subquery): What is the most expensive product in each category?
SELECT c.category_name, p.product_name, p.price
FROM products p
INNER JOIN categories c ON c.category_id = p.category_id
WHERE p.price = (SELECT MAX(p2.price)
                 FROM products p2
                 WHERE p2.category_id = p.category_id)
ORDER BY p.price DESC;

-- Q10 (EXISTS): Which customers have cancelled at least one order?
SELECT c.customer_id, CONCAT(u.first_name, ' ', u.last_name) AS customer_name
FROM customers c
INNER JOIN users u ON u.user_id = c.customer_id
WHERE EXISTS (SELECT 1 FROM orders o
              WHERE o.customer_id = c.customer_id
                AND o.order_status = 'cancelled');

-- Q11 (NOT EXISTS): Which products have never been ordered?
-- RA: π product_id (products) − π product_id (order_items)
SELECT p.product_id, p.product_name, p.stock_qty
FROM products p
WHERE NOT EXISTS (SELECT 1 FROM order_items oi
                  WHERE oi.product_id = p.product_id);

-- Q12 (IN): Which customers have paid with mobile banking (bKash or Nagad)?
SELECT DISTINCT c.customer_id, CONCAT(u.first_name, ' ', u.last_name) AS customer_name
FROM customers c
INNER JOIN users u ON u.user_id = c.customer_id
WHERE c.customer_id IN (SELECT o.customer_id
                        FROM orders o
                        INNER JOIN payments pay ON pay.order_id = o.order_id
                        WHERE pay.method IN ('bKash', 'Nagad')
                          AND pay.payment_status = 'paid')
ORDER BY c.customer_id;

-- Q13 (ANY): Which non-furniture products cost more than at least one
--            furniture product?
SELECT p.product_name, p.price
FROM products p
WHERE p.category_id <> 12
  AND p.price > ANY (SELECT f.price FROM products f WHERE f.category_id = 12)
ORDER BY p.price DESC;

-- Q14 (ALL): Which products cost more than every furniture product?
SELECT p.product_name, p.price
FROM products p
WHERE p.price > ALL (SELECT f.price FROM products f WHERE f.category_id = 12)
ORDER BY p.price DESC;

-- Q15 (UNION): In which cities do we have customers or sellers?
-- RA: π city (addresses) ∪ ρ city←shop_city (π shop_city (sellers))
SELECT city FROM addresses
UNION
SELECT shop_city FROM sellers
ORDER BY city;

-- Q16 (INTERSECT): Which products are on someone's wishlist AND have also been ordered?
-- RA: π product_id (wishlists) ∩ π product_id (order_items)
SELECT product_id FROM wishlists
INTERSECT
SELECT product_id FROM order_items;

-- Q17 (EXCEPT): Which products are wished for but have never been ordered?
-- RA: π product_id (wishlists) − π product_id (order_items)
SELECT product_id FROM wishlists
EXCEPT
SELECT product_id FROM order_items;

-- Q18 (DIVISION): Which customers have bought EVERY product in the
--                 'Smartphones' category?
-- RA: π customer_id, product_id (σ order_status ≠ 'cancelled' (orders ⋈ order_items))
--        ÷ π product_id (σ category_name = 'Smartphones' (products ⋈ categories))
SELECT c.customer_id, CONCAT(u.first_name, ' ', u.last_name) AS customer_name
FROM customers c
INNER JOIN users u ON u.user_id = c.customer_id
WHERE NOT EXISTS (
        SELECT 1
        FROM products p
        INNER JOIN categories cat ON cat.category_id = p.category_id
        WHERE cat.category_name = 'Smartphones'
          AND NOT EXISTS (
                SELECT 1
                FROM orders o
                INNER JOIN order_items oi ON oi.order_id = o.order_id
                WHERE o.customer_id = c.customer_id
                  AND oi.product_id = p.product_id
                  AND o.order_status <> 'cancelled'));

-- Q19 (window function RANK): Rank the sellers by delivered revenue.
SELECT s.shop_name,
       SUM(oi.quantity * oi.unit_price) AS revenue,
       RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS revenue_rank
FROM sellers s
INNER JOIN products p     ON p.seller_id   = s.seller_id
INNER JOIN order_items oi ON oi.product_id = p.product_id
INNER JOIN orders o       ON o.order_id    = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.shop_name
ORDER BY revenue_rank;

-- Q20 (window function ROW_NUMBER): What are the 2 best-selling products
--                                   in each category?
SELECT category_name, product_name, units_sold
FROM (SELECT c.category_name, p.product_name,
             SUM(oi.quantity) AS units_sold,
             ROW_NUMBER() OVER (PARTITION BY c.category_id
                                ORDER BY SUM(oi.quantity) DESC, p.product_id) AS rn
      FROM products p
      INNER JOIN categories c   ON c.category_id = p.category_id
      INNER JOIN order_items oi ON oi.product_id = p.product_id
      INNER JOIN orders o       ON o.order_id    = oi.order_id
      WHERE o.order_status <> 'cancelled'
      GROUP BY c.category_id, c.category_name, p.product_id, p.product_name) ranked
WHERE rn <= 2
ORDER BY category_name, units_sold DESC;

-- Q21 (window function SUM() OVER): What is the monthly revenue and the
--                                   running total over the year?
SELECT sales_month, monthly_revenue,
       SUM(monthly_revenue) OVER (ORDER BY sales_month) AS running_total
FROM (SELECT DATE_FORMAT(order_date, '%Y-%m') AS sales_month,
             SUM(total_amount) AS monthly_revenue
      FROM orders
      WHERE order_status <> 'cancelled'
      GROUP BY DATE_FORMAT(order_date, '%Y-%m')) monthly
ORDER BY sales_month;

-- Q22 (CTE): Who are our top 5 customers by money spent, and what share
--            of all sales does each one bring?
WITH customer_spend AS (
    SELECT o.customer_id, SUM(o.total_amount) AS total_spent, COUNT(*) AS orders_placed
    FROM orders o
    WHERE o.order_status <> 'cancelled'
    GROUP BY o.customer_id
)
SELECT CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
       cs.orders_placed, cs.total_spent,
       ROUND(100 * cs.total_spent / (SELECT SUM(total_spent) FROM customer_spend), 2)
         AS percent_of_sales
FROM customer_spend cs
INNER JOIN users u ON u.user_id = cs.customer_id
ORDER BY cs.total_spent DESC
LIMIT 5;

-- Q23 (recursive CTE): Show the full category tree with the path from the root.
WITH RECURSIVE category_tree AS (
    SELECT category_id, category_name, 1 AS depth,
           CAST(category_name AS CHAR(200)) AS full_path
    FROM categories
    WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, c.category_name, ct.depth + 1,
           CONCAT(ct.full_path, ' > ', c.category_name)
    FROM categories c
    INNER JOIN category_tree ct ON ct.category_id = c.parent_category_id
)
SELECT category_id, depth, full_path
FROM category_tree
ORDER BY full_path;

-- Q24 (aggregation): Which products have an average rating of 4 or more
--                    from at least 2 reviews?
-- RA: σ avg_rating ≥ 4 ∧ review_count ≥ 2
--        ( product_name γ AVG(rating) → avg_rating, COUNT(*) → review_count (products ⋈ reviews))
SELECT p.product_name,
       ROUND(AVG(r.rating), 2) AS avg_rating,
       COUNT(*) AS review_count
FROM products p
INNER JOIN reviews r ON r.product_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING AVG(r.rating) >= 4 AND COUNT(*) >= 2
ORDER BY avg_rating DESC, review_count DESC;
-- =====================================================================
-- TASK 7: VIEWS
-- =====================================================================

-- V1: simple updatable view (one table, no aggregation)
CREATE OR REPLACE VIEW v_active_products AS
SELECT product_id, product_name, brand, price, stock_qty
FROM products
WHERE product_status = 'active';

-- demonstration: an UPDATE through the view changes the base table
SELECT product_id, stock_qty FROM products WHERE product_id = 25;
UPDATE v_active_products SET stock_qty = stock_qty + 10 WHERE product_id = 25;
SELECT product_id, stock_qty FROM products WHERE product_id = 25;

-- V2: complex view with joins and aggregation (one row per seller)
CREATE OR REPLACE VIEW v_seller_sales_summary AS
SELECT s.seller_id,
       s.shop_name,
       COUNT(DISTINCT p.product_id)                   AS products_listed,
       COUNT(DISTINCT o.order_id)                     AS delivered_orders,
       COALESCE(SUM(oi.quantity), 0)                  AS units_sold,
       COALESCE(SUM(oi.quantity * oi.unit_price), 0)  AS revenue,
       (SELECT ROUND(AVG(r.rating), 2)
        FROM reviews r
        INNER JOIN products rp ON rp.product_id = r.product_id
        WHERE rp.seller_id = s.seller_id)             AS avg_rating
FROM sellers s
LEFT JOIN products p     ON p.seller_id   = s.seller_id
LEFT JOIN order_items oi ON oi.product_id = p.product_id
                        AND oi.order_id IN (SELECT order_id FROM orders
                                            WHERE order_status = 'delivered')
LEFT JOIN orders o       ON o.order_id    = oi.order_id
GROUP BY s.seller_id, s.shop_name;

SELECT * FROM v_seller_sales_summary ORDER BY revenue DESC;

-- V3: view WITH CHECK OPTION (budget products: 1,000 taka or less)
CREATE OR REPLACE VIEW v_budget_products AS
SELECT product_id, seller_id, category_id, product_name, brand, sku, price, stock_qty
FROM products
WHERE price <= 1000
WITH CHECK OPTION;

-- allowed: the new price still satisfies the view condition
UPDATE v_budget_products SET price = 870.00 WHERE product_id = 22;
SELECT product_id, product_name, price FROM v_budget_products WHERE product_id = 22;
-- EXPECTED ERROR 1369 (CHECK OPTION failed): the row would leave the view
--   UPDATE v_budget_products SET price = 5000.00 WHERE product_id = 22;

-- V4: security view. It hides the seller's NID, bank account, trade
--     licence, e-mail, phone and password. Used again in Task 13.
CREATE OR REPLACE VIEW v_seller_public AS
SELECT s.seller_id,
       s.shop_name,
       CONCAT(u.first_name, ' ', u.last_name) AS owner_name,
       s.shop_city,
       s.is_verified,
       DATE(u.created_at) AS member_since
FROM sellers s
INNER JOIN users u ON u.user_id = s.seller_id
WHERE u.account_status = 'active';

SELECT * FROM v_seller_public;
-- =====================================================================
-- TASK 8: FUNCTIONS AND STORED PROCEDURES
-- In the phpMyAdmin SQL tab, set the Delimiter box to $$ for this part.
-- =====================================================================
DELIMITER $$

-- F1: age of a person from the date of birth (derived attribute "age")
CREATE FUNCTION fn_age_from_dob(p_dob DATE)
RETURNS INT
NOT DETERMINISTIC
NO SQL
BEGIN
  RETURN TIMESTAMPDIFF(YEAR, p_dob, CURDATE());
END$$

-- F2: total value of one order, calculated from its items
CREATE FUNCTION fn_order_total(p_order_id INT UNSIGNED)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(12,2);
  SELECT COALESCE(SUM(quantity * unit_price), 0)
    INTO v_total
  FROM order_items
  WHERE order_id = p_order_id;
  RETURN v_total;
END$$

-- F3: membership tier of a customer, based on money spent on delivered orders
CREATE FUNCTION fn_customer_tier(p_customer_id INT UNSIGNED)
RETURNS VARCHAR(10)
READS SQL DATA
BEGIN
  DECLARE v_spent DECIMAL(12,2);
  SELECT COALESCE(SUM(total_amount), 0)
    INTO v_spent
  FROM orders
  WHERE customer_id = p_customer_id AND order_status = 'delivered';
  RETURN CASE
           WHEN v_spent >= 100000 THEN 'Platinum'
           WHEN v_spent >= 30000  THEN 'Gold'
           WHEN v_spent >= 5000   THEN 'Silver'
           ELSE 'Bronze'
         END;
END$$

-- P1: place an order for one product (IN and OUT parameters, IF, SIGNAL).
--     It checks the stock, inserts the order, the item and the payment as
--     ONE transaction. Stock and order total are then updated by the
--     triggers of Task 9, so this procedure is tested in section 9.8.
CREATE PROCEDURE sp_place_order(
  IN  p_customer_id INT UNSIGNED,
  IN  p_product_id  INT UNSIGNED,
  IN  p_quantity    INT,
  IN  p_method      VARCHAR(20),
  OUT p_order_id    INT UNSIGNED)
BEGIN
  DECLARE v_stock   INT;
  DECLARE v_status  VARCHAR(10);
  DECLARE v_address TINYINT UNSIGNED;
  DECLARE v_total   DECIMAL(12,2);
  -- any error: undo everything and pass the error to the caller
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be greater than zero';
  END IF;

  START TRANSACTION;
  -- lock the product row so two buyers cannot take the same stock
  SELECT stock_qty, product_status INTO v_stock, v_status
  FROM products WHERE product_id = p_product_id FOR UPDATE;

  IF v_stock IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found';
  ELSEIF v_status <> 'active' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product is not available for sale';
  ELSEIF v_stock < p_quantity THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough stock for this product';
  END IF;

  SELECT MIN(address_no) INTO v_address
  FROM addresses WHERE customer_id = p_customer_id;
  IF v_address IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer has no delivery address';
  END IF;

  INSERT INTO orders (customer_id, address_no, order_status)
  VALUES (p_customer_id, v_address, 'pending');
  SET p_order_id = LAST_INSERT_ID();

  INSERT INTO order_items (order_id, product_id, quantity)
  VALUES (p_order_id, p_product_id, p_quantity);

  SELECT total_amount INTO v_total FROM orders WHERE order_id = p_order_id;
  INSERT INTO payments (order_id, method, amount, payment_status)
  VALUES (p_order_id, p_method, v_total, 'pending');
  COMMIT;
END$$

-- P2: give a discount to every active product of one category
--     (IN and INOUT parameters, a CURSOR inside a LOOP, SIGNAL).
--     p_products_changed is INOUT: it keeps counting across several calls.
CREATE PROCEDURE sp_apply_category_discount(
  IN    p_category_id      INT UNSIGNED,
  IN    p_percent          DECIMAL(5,2),
  INOUT p_products_changed INT)
BEGIN
  DECLARE v_product_id INT UNSIGNED;
  DECLARE v_price      DECIMAL(10,2);
  DECLARE v_done       TINYINT DEFAULT 0;
  DECLARE cur_products CURSOR FOR
    SELECT product_id, price FROM products
    WHERE category_id = p_category_id AND product_status = 'active';
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  IF p_percent <= 0 OR p_percent > 50 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Discount must be between 1 and 50 percent';
  END IF;
  SET p_products_changed = COALESCE(p_products_changed, 0);

  OPEN cur_products;
  discount_loop: LOOP
    FETCH cur_products INTO v_product_id, v_price;
    IF v_done = 1 THEN
      LEAVE discount_loop;
    END IF;
    UPDATE products
    SET price = ROUND(v_price * (100 - p_percent) / 100, 2)
    WHERE product_id = v_product_id;
    SET p_products_changed = p_products_changed + 1;
  END LOOP;
  CLOSE cur_products;
END$$

-- P3: cancel an order (IN and OUT parameters, CASE).
--     Only pending or confirmed orders can be cancelled. The stock goes
--     back to the products and the payment is marked refunded or failed.
CREATE PROCEDURE sp_cancel_order(
  IN  p_order_id INT UNSIGNED,
  OUT p_message  VARCHAR(100))
BEGIN
  DECLARE v_status VARCHAR(10);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
  SELECT order_status INTO v_status
  FROM orders WHERE order_id = p_order_id FOR UPDATE;

  CASE
    WHEN v_status IS NULL THEN
      SET p_message = 'Order not found';
    WHEN v_status IN ('shipped', 'delivered') THEN
      SET p_message = CONCAT('Cannot cancel: order is already ', v_status);
    WHEN v_status = 'cancelled' THEN
      SET p_message = 'Order was already cancelled';
    ELSE
      UPDATE products p
      INNER JOIN order_items oi ON oi.product_id = p.product_id
      SET p.stock_qty = p.stock_qty + oi.quantity
      WHERE oi.order_id = p_order_id;

      UPDATE orders SET order_status = 'cancelled' WHERE order_id = p_order_id;

      UPDATE payments
      SET payment_status = CASE payment_status
                             WHEN 'paid' THEN 'refunded'
                             ELSE 'failed'
                           END
      WHERE order_id = p_order_id;
      SET p_message = 'Order cancelled and stock restored';
  END CASE;
  COMMIT;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 8.1 Tests of the functions
-- ---------------------------------------------------------------------
SELECT customer_id, date_of_birth, fn_age_from_dob(date_of_birth) AS age
FROM customers ORDER BY customer_id LIMIT 5;

SELECT order_id, total_amount, fn_order_total(order_id) AS calculated_total
FROM orders ORDER BY order_id LIMIT 5;

SELECT c.customer_id, CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
       fn_customer_tier(c.customer_id) AS tier
FROM customers c INNER JOIN users u ON u.user_id = c.customer_id
ORDER BY c.customer_id LIMIT 8;

-- ---------------------------------------------------------------------
-- 8.2 Test of sp_apply_category_discount: 10% off Snacks & Beverages (14),
--     then 5% off Skin Care (15). The INOUT counter adds both calls.
-- ---------------------------------------------------------------------
SELECT product_id, product_name, price FROM products WHERE category_id IN (14, 15);
SET @changed = 0;
CALL sp_apply_category_discount(14, 10, @changed);
CALL sp_apply_category_discount(15, 5, @changed);
SELECT @changed AS products_changed;
SELECT product_id, product_name, price FROM products WHERE category_id IN (14, 15);
-- EXPECTED ERROR 1644 (Discount must be between 1 and 50 percent):
--   CALL sp_apply_category_discount(14, 80, @changed);

-- ---------------------------------------------------------------------
-- 8.3 Test of sp_cancel_order
-- ---------------------------------------------------------------------
CALL sp_cancel_order(1, @msg);     -- a delivered order: refused
SELECT @msg AS result_for_order_1;
SELECT product_id, stock_qty FROM products
WHERE product_id IN (SELECT product_id FROM order_items WHERE order_id = 56);
CALL sp_cancel_order(56, @msg);    -- a pending order: cancelled
SELECT @msg AS result_for_order_56;
SELECT product_id, stock_qty FROM products
WHERE product_id IN (SELECT product_id FROM order_items WHERE order_id = 56);
SELECT o.order_id, o.order_status, p.payment_status
FROM orders o LEFT JOIN payments p ON p.order_id = o.order_id
WHERE o.order_id = 56;
-- =====================================================================
-- TASK 9: TRIGGERS
-- =====================================================================
DELIMITER $$

-- T1 (BEFORE INSERT, validation): an order item is refused when the
--     product is not on sale or the stock is too low. It also copies the
--     current price into unit_price when no price is given.
CREATE TRIGGER trg_order_items_before_insert
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
  DECLARE v_stock  INT;
  DECLARE v_price  DECIMAL(10,2);
  DECLARE v_status VARCHAR(10);
  SELECT stock_qty, price, product_status INTO v_stock, v_price, v_status
  FROM products WHERE product_id = NEW.product_id;

  IF v_status <> 'active' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product is not available for sale';
  END IF;
  IF NEW.quantity > v_stock THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough stock for this product';
  END IF;
  IF NEW.unit_price IS NULL OR NEW.unit_price = 0 THEN
    SET NEW.unit_price = v_price;
  END IF;
END$$

-- T2 (AFTER INSERT, derived data): reduce the stock and add the line
--     amount to the order total.
CREATE TRIGGER trg_order_items_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  UPDATE products SET stock_qty = stock_qty - NEW.quantity
  WHERE product_id = NEW.product_id;
  UPDATE orders SET total_amount = total_amount + NEW.quantity * NEW.unit_price
  WHERE order_id = NEW.order_id;
END$$

-- T3 (AFTER DELETE, derived data): when an item is removed from an order,
--     give the stock back and reduce the order total.
CREATE TRIGGER trg_order_items_after_delete
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
  UPDATE products SET stock_qty = stock_qty + OLD.quantity
  WHERE product_id = OLD.product_id;
  UPDATE orders SET total_amount = total_amount - OLD.quantity * OLD.unit_price
  WHERE order_id = OLD.order_id;
END$$

-- T4 (AFTER UPDATE, audit): every change of price or status of a product
--     is written to audit_log with old value, new value, user and time.
CREATE TRIGGER trg_products_after_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
  IF OLD.price <> NEW.price THEN
    INSERT INTO audit_log (table_name, record_id, action_type, column_name,
                           old_value, new_value, changed_by, changed_at)
    VALUES ('products', NEW.product_id, 'UPDATE', 'price',
            OLD.price, NEW.price, CURRENT_USER(), NOW());
  END IF;
  IF OLD.product_status <> NEW.product_status THEN
    INSERT INTO audit_log (table_name, record_id, action_type, column_name,
                           old_value, new_value, changed_by, changed_at)
    VALUES ('products', NEW.product_id, 'UPDATE', 'product_status',
            OLD.product_status, NEW.product_status, CURRENT_USER(), NOW());
  END IF;
END$$

-- T5 (BEFORE INSERT, own design, business rule 7): only a customer who
--     has received the product (delivered order) may review it.
CREATE TRIGGER trg_reviews_before_insert
BEFORE INSERT ON reviews
FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1
                 FROM orders o
                 INNER JOIN order_items oi ON oi.order_id = o.order_id
                 WHERE o.customer_id = NEW.customer_id
                   AND oi.product_id = NEW.product_id
                   AND o.order_status = 'delivered') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Only customers who received this product can review it';
  END IF;
END$$

-- T6 (BEFORE UPDATE, business rule 9): a shipped or delivered order
--     cannot be cancelled, and a cancelled order cannot be re-opened.
CREATE TRIGGER trg_orders_before_update
BEFORE UPDATE ON orders
FOR EACH ROW
BEGIN
  IF NEW.order_status = 'cancelled' AND OLD.order_status IN ('shipped', 'delivered') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'A shipped or delivered order cannot be cancelled';
  END IF;
  IF OLD.order_status = 'cancelled' AND NEW.order_status <> 'cancelled' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'A cancelled order cannot be re-opened';
  END IF;
END$$

-- T7 (BEFORE UPDATE, business rule 12): a customer cannot refer himself.
CREATE TRIGGER trg_customers_before_update
BEFORE UPDATE ON customers
FOR EACH ROW
BEGIN
  IF NEW.referred_by IS NOT NULL AND NEW.referred_by = NEW.customer_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A customer cannot refer himself or herself';
  END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 9.1 Test T1 (validation): product 4 has less than 500 units in stock
-- ---------------------------------------------------------------------
-- EXPECTED ERROR 1644 (Not enough stock for this product):
--   INSERT INTO order_items (order_id, product_id, quantity) VALUES (57, 4, 500);

-- ---------------------------------------------------------------------
-- 9.2 Test T2 (derived data): add 2 units of product 11 to pending order 57.
--     unit_price is not given, so T1 copies it from the product.
-- ---------------------------------------------------------------------
SELECT product_id, stock_qty FROM products WHERE product_id = 11;
SELECT order_id, total_amount FROM orders WHERE order_id = 57;
INSERT INTO order_items (order_id, product_id, quantity) VALUES (57, 11, 2);
SELECT product_id, stock_qty FROM products WHERE product_id = 11;   -- 2 less
SELECT order_id, total_amount FROM orders WHERE order_id = 57;      -- 2900 more

-- ---------------------------------------------------------------------
-- 9.3 Test T3 (AFTER DELETE): remove that item again
-- ---------------------------------------------------------------------
DELETE FROM order_items WHERE order_id = 57 AND product_id = 11;
SELECT product_id, stock_qty FROM products WHERE product_id = 11;   -- back
SELECT order_id, total_amount FROM orders WHERE order_id = 57;      -- back

-- ---------------------------------------------------------------------
-- 9.4 Test T4 (audit): change a price and a status, then read the log
-- ---------------------------------------------------------------------
UPDATE products SET price = 22499.00 WHERE product_id = 1;
UPDATE products SET product_status = 'inactive' WHERE product_id = 21;
SELECT log_id, table_name, record_id, column_name, old_value, new_value,
       changed_by, changed_at
FROM audit_log ORDER BY log_id;

-- ---------------------------------------------------------------------
-- 9.5 Test T5 (review rule)
-- ---------------------------------------------------------------------
-- EXPECTED ERROR 1644: customer 19 never bought product 4
--   INSERT INTO reviews (customer_id, product_id, rating, comment, review_date)
--   VALUES (19, 4, 5, 'Fake review', CURDATE());
-- allowed: customer 1 received product 2 (order 7)
INSERT INTO reviews (customer_id, product_id, rating, comment, review_date)
SELECT 1, 2, 5, 'Camera is very good for this price.', '2026-11-10'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM reviews WHERE customer_id = 1 AND product_id = 2);
SELECT review_id, customer_id, product_id, rating, comment
FROM reviews WHERE customer_id = 1 AND product_id = 2;

-- ---------------------------------------------------------------------
-- 9.6 Test T6 (order status rule): order 1 is already delivered
-- ---------------------------------------------------------------------
-- EXPECTED ERROR 1644 (A shipped or delivered order cannot be cancelled):
--   UPDATE orders SET order_status = 'cancelled' WHERE order_id = 1;
-- allowed: a pending order may be confirmed
UPDATE orders SET order_status = 'confirmed' WHERE order_id = 58;
SELECT order_id, order_status FROM orders WHERE order_id = 58;

-- ---------------------------------------------------------------------
-- 9.7 Test T7 (self-referral rule)
-- ---------------------------------------------------------------------
-- EXPECTED ERROR 1644 (A customer cannot refer himself or herself):
--   UPDATE customers SET referred_by = 3 WHERE customer_id = 3;

-- ---------------------------------------------------------------------
-- 9.8 Test of procedure sp_place_order (Task 8) together with the triggers
-- ---------------------------------------------------------------------
SELECT product_id, stock_qty FROM products WHERE product_id = 9;
CALL sp_place_order(3, 9, 2, 'bKash', @new_order_id);
SELECT @new_order_id AS new_order_id;
SELECT o.order_id, o.customer_id, o.order_status, o.total_amount,
       oi.product_id, oi.quantity, oi.unit_price, p.method, p.payment_status
FROM orders o
INNER JOIN order_items oi ON oi.order_id = o.order_id
INNER JOIN payments p     ON p.order_id  = o.order_id
WHERE o.order_id = @new_order_id;
SELECT product_id, stock_qty FROM products WHERE product_id = 9;    -- 2 less
-- EXPECTED ERROR 1644 (Not enough stock for this product):
--   CALL sp_place_order(3, 9, 9999, 'bKash', @new_order_id);
-- =====================================================================
-- TASK 10: TRANSACTIONS AND CONCURRENCY
-- =====================================================================

-- ---------------------------------------------------------------------
-- 10.1 Transaction 1: order checkout (all-or-nothing) with a SAVEPOINT.
--      Customer 2 orders earbuds, adds tea, then changes her mind about
--      the tea before paying.
-- ---------------------------------------------------------------------
START TRANSACTION;

INSERT INTO orders (customer_id, address_no, order_status)
VALUES (2, 1, 'pending');
SET @checkout_order = LAST_INSERT_ID();

INSERT INTO order_items (order_id, product_id, quantity)
VALUES (@checkout_order, 8, 1);
SAVEPOINT sp_first_item;

INSERT INTO order_items (order_id, product_id, quantity)
VALUES (@checkout_order, 25, 3);
SELECT order_id, total_amount AS total_with_tea
FROM orders WHERE order_id = @checkout_order;

-- undo only the tea; the order and the earbuds stay
ROLLBACK TO SAVEPOINT sp_first_item;
SELECT order_id, total_amount AS total_after_rollback_to
FROM orders WHERE order_id = @checkout_order;

INSERT INTO payments (order_id, method, amount, payment_status, transaction_ref, paid_at)
SELECT order_id, 'Nagad', total_amount, 'paid', 'NGT10DEMO1', NOW()
FROM orders WHERE order_id = @checkout_order;

UPDATE orders SET order_status = 'confirmed' WHERE order_id = @checkout_order;
COMMIT;

SELECT o.order_id, o.order_status, o.total_amount, p.method, p.payment_status
FROM orders o INNER JOIN payments p ON p.order_id = o.order_id
WHERE o.order_id = @checkout_order;

-- ---------------------------------------------------------------------
-- 10.2 Transaction 2: transfer 200 loyalty points from customer 1 to
--      customer 2 (same idea as a money transfer). A wrong credit is
--      undone with ROLLBACK TO, then the correct credit is committed.
-- ---------------------------------------------------------------------
SELECT customer_id, loyalty_points FROM customers WHERE customer_id IN (1, 2);

START TRANSACTION;
UPDATE customers SET loyalty_points = loyalty_points - 200 WHERE customer_id = 1;
SAVEPOINT sp_after_debit;

UPDATE customers SET loyalty_points = loyalty_points + 2000 WHERE customer_id = 2; -- typing mistake
ROLLBACK TO SAVEPOINT sp_after_debit;

UPDATE customers SET loyalty_points = loyalty_points + 200 WHERE customer_id = 2;  -- correct credit
COMMIT;

SELECT customer_id, loyalty_points FROM customers WHERE customer_id IN (1, 2);

-- A transfer that fails is rolled back completely. Customer 16 has 0
-- points, so the debit breaks CHECK chk_customers_points:
--   START TRANSACTION;
--   UPDATE customers SET loyalty_points = loyalty_points + 500 WHERE customer_id = 2;
--   UPDATE customers SET loyalty_points = loyalty_points - 500 WHERE customer_id = 16; -- EXPECTED ERROR 4025
--   ROLLBACK;   -- the credit to customer 2 is undone as well

-- ---------------------------------------------------------------------
-- 10.3 Concurrency problem: LOST UPDATE (run by hand in TWO sessions)
--      Open two MySQL shell windows (or two phpMyAdmin tabs), both with
--      USE ecommerce_marketplace; and follow the step numbers.
--      Two staff members each sell 1 unit of product 16 at the same time.
-- ---------------------------------------------------------------------
-- PROBLEM (both sessions read the same old stock):
--   step 1  Session A:  START TRANSACTION;
--   step 2  Session A:  SELECT stock_qty INTO @s FROM products WHERE product_id = 16;
--   step 3  Session B:  START TRANSACTION;
--   step 4  Session B:  SELECT stock_qty INTO @s FROM products WHERE product_id = 16;
--   step 5  Session A:  UPDATE products SET stock_qty = @s - 1 WHERE product_id = 16;
--   step 6  Session A:  COMMIT;
--   step 7  Session B:  UPDATE products SET stock_qty = @s - 1 WHERE product_id = 16;
--   step 8  Session B:  COMMIT;
--   step 9  either   :  SELECT stock_qty FROM products WHERE product_id = 16;
--   Result: two units were sold but the stock went down by only 1.
--           Session A's update is lost.
--
-- FIX (SELECT ... FOR UPDATE locks the row until COMMIT):
--   step 1  Session A:  START TRANSACTION;
--   step 2  Session A:  SELECT stock_qty INTO @s FROM products WHERE product_id = 16 FOR UPDATE;
--   step 3  Session B:  START TRANSACTION;
--   step 4  Session B:  SELECT stock_qty INTO @s FROM products WHERE product_id = 16 FOR UPDATE;
--                       (Session B now WAITS for Session A)
--   step 5  Session A:  UPDATE products SET stock_qty = @s - 1 WHERE product_id = 16;
--   step 6  Session A:  COMMIT;      (Session B wakes up and reads the NEW stock)
--   step 7  Session B:  UPDATE products SET stock_qty = @s - 1 WHERE product_id = 16;
--   step 8  Session B:  COMMIT;
--   step 9  either   :  SELECT stock_qty FROM products WHERE product_id = 16;
--   Result: the stock went down by 2. No update is lost.
--
-- The isolation level in use can be checked with:
SELECT @@tx_isolation AS current_isolation_level;
-- =====================================================================
-- TASK 11: INDEXING, STORAGE AND FILE ORGANISATION
-- =====================================================================

-- 11.1 A larger table for the index test: every time a customer opens a
--      product page, one row is stored. 5,000 rows are generated with a
--      CTE that builds the numbers 1 to 5000.
CREATE TABLE product_views (
  view_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id  INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NULL,
  device      ENUM('mobile','desktop','tablet') NOT NULL,
  viewed_at   DATETIME NOT NULL,
  CONSTRAINT pk_product_views PRIMARY KEY (view_id),
  CONSTRAINT fk_views_product FOREIGN KEY (product_id)
    REFERENCES products (product_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_views_customer FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

INSERT INTO product_views (product_id, customer_id, device, viewed_at)
WITH digits AS (
    SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
    UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
),
seq AS (   -- the numbers 1 to 5000
    SELECT 1 + a.d + 10 * b.d + 100 * c.d + 1000 * e.d AS n
    FROM digits a CROSS JOIN digits b CROSS JOIN digits c CROSS JOIN digits e
    WHERE e.d < 5
)
SELECT 1 + (n * 7) MOD 30,
       1 + (n * 13) MOD 20,
       ELT(1 + n MOD 3, 'mobile', 'desktop', 'tablet'),
       TIMESTAMP('2026-01-01 00:00:00') + INTERVAL ((n * 7919) MOD 446400) MINUTE
FROM seq
ORDER BY n;

SELECT COUNT(*) AS rows_loaded FROM product_views;

-- 11.2 BEFORE indexing: the query scans the whole table (type = ALL)
EXPLAIN SELECT view_id, product_id, viewed_at
FROM product_views
WHERE viewed_at BETWEEN '2026-06-01 00:00:00' AND '2026-06-02 23:59:59';

-- 11.3 The three indexes
-- (a) single-column index: range lookups on the view time
CREATE INDEX idx_views_viewed_at ON product_views (viewed_at);

-- (b) composite index: "orders of one status, newest first"
CREATE INDEX idx_orders_status_date ON orders (order_status, order_date);

-- (c) unique index: an SKU code may appear only once
CREATE UNIQUE INDEX uq_products_sku ON products (sku);

-- 11.4 AFTER indexing: the same query now does a range scan on the index
EXPLAIN SELECT view_id, product_id, viewed_at
FROM product_views
WHERE viewed_at BETWEEN '2026-06-01 00:00:00' AND '2026-06-02 23:59:59';

-- the composite index serves equality on the first column + range on the second
EXPLAIN SELECT order_id, order_date
FROM orders
WHERE order_status = 'delivered' AND order_date >= '2026-10-01';

-- the unique index gives a single-row (const) lookup
EXPLAIN SELECT product_id, product_name FROM products WHERE sku = 'HP-15S-I5';

-- 11.5 All indexes of the three tables, with their type (BTREE)
SHOW INDEX FROM product_views;
SHOW INDEX FROM orders;
SHOW INDEX FROM products;

-- EXPECTED ERROR 1062 (duplicate SKU refused by the unique index):
--   UPDATE products SET sku = 'HP-15S-I5' WHERE product_id = 5;
-- =====================================================================
-- TASK 12: SEMI-STRUCTURED DATA (JSON)
-- =====================================================================
-- Different kinds of products have different specifications (a phone has
-- RAM, a saree has fabric), so the specifications are kept in one JSON
-- column. In MariaDB JSON is stored as text, so JSON_VALID is checked.
ALTER TABLE products
  ADD COLUMN specs LONGTEXT NULL,
  ADD CONSTRAINT chk_products_specs_json CHECK (specs IS NULL OR JSON_VALID(specs));

-- JSON documents: one specification document per product
UPDATE products SET specs = '{"ram_gb": 6, "storage_gb": 128, "display_inch": 6.5, "battery_mah": 5000, "colors": ["Blue", "Black"], "warranty_months": 12, "network": "4G"}' WHERE product_id = 1;
UPDATE products SET specs = '{"ram_gb": 8, "storage_gb": 256, "display_inch": 6.67, "battery_mah": 5000, "colors": ["Green", "Black", "White"], "warranty_months": 12, "network": "4G"}' WHERE product_id = 2;
UPDATE products SET specs = '{"ram_gb": 4, "storage_gb": 64, "display_inch": 6.6, "battery_mah": 5000, "colors": ["Black"], "warranty_months": 12, "network": "4G"}' WHERE product_id = 3;
UPDATE products SET specs = '{"ram_gb": 8, "storage_gb": 512, "display_inch": 15.6, "processor": "Core i5-1235U", "os": "Windows 11", "warranty_months": 24}' WHERE product_id = 4;
UPDATE products SET specs = '{"ram_gb": 8, "storage_gb": 512, "display_inch": 15.6, "processor": "Ryzen 5 7520U", "os": "Windows 11", "warranty_months": 24}' WHERE product_id = 5;
UPDATE products SET specs = '{"ram_gb": 8, "storage_gb": 256, "display_inch": 14, "processor": "Core i3-1215U", "os": "FreeDOS", "warranty_months": 24}' WHERE product_id = 6;
UPDATE products SET specs = '{"type": "over-ear", "wireless": true, "battery_hours": 57, "colors": ["Black", "Blue"], "warranty_months": 6}' WHERE product_id = 7;
UPDATE products SET specs = '{"type": "earbuds", "wireless": true, "battery_hours": 38, "colors": ["White", "Black"], "warranty_months": 6}' WHERE product_id = 8;
UPDATE products SET specs = '{"type": "speaker", "wireless": true, "battery_hours": 13, "power_watt": 16, "colors": ["Black"], "warranty_months": 6}' WHERE product_id = 9;
UPDATE products SET specs = '{"fabric": "cotton", "sizes": ["M", "L", "XL"], "colors": ["White", "Navy"], "made_in": "Bangladesh"}' WHERE product_id = 10;
UPDATE products SET specs = '{"fabric": "denim", "sizes": ["30", "32", "34", "36"], "colors": ["Blue"], "made_in": "Bangladesh"}' WHERE product_id = 11;
UPDATE products SET specs = '{"fabric": "pique cotton", "sizes": ["S", "M", "L", "XL"], "colors": ["Black", "Maroon", "Olive"], "made_in": "Bangladesh"}' WHERE product_id = 12;
UPDATE products SET specs = '{"fabric": "jamdani cotton", "length_m": 5.5, "colors": ["Red", "Off-white"], "handmade": true, "made_in": "Bangladesh"}' WHERE product_id = 13;
UPDATE products SET specs = '{"fabric": "lawn", "sizes": ["38", "40", "42", "44"], "colors": ["Pink", "Teal"], "made_in": "Bangladesh"}' WHERE product_id = 14;
UPDATE products SET specs = '{"fabric": "cotton", "sizes": ["S", "M", "L"], "colors": ["Yellow", "Black"], "handmade": true, "made_in": "Bangladesh"}' WHERE product_id = 15;
UPDATE products SET specs = '{"capacity_l": 2.8, "power_watt": 1000, "warranty_months": 12, "colors": ["White"]}' WHERE product_id = 16;
UPDATE products SET specs = '{"capacity_l": 1.5, "power_watt": 850, "jars": 3, "warranty_months": 12}' WHERE product_id = 17;
UPDATE products SET specs = '{"capacity_l": 1.8, "power_watt": 1500, "warranty_months": 6, "colors": ["Silver"]}' WHERE product_id = 18;
UPDATE products SET specs = '{"material": "oak veneer", "seats": 6, "dimensions_cm": {"l": 180, "w": 90, "h": 76}, "assembly_required": true}' WHERE product_id = 19;
UPDATE products SET specs = '{"material": "plastic", "pieces": 4, "colors": ["Red", "Blue", "Maroon"], "assembly_required": false}' WHERE product_id = 20;
UPDATE products SET specs = '{"material": "steel", "tiers": 5, "dimensions_cm": {"l": 80, "w": 30, "h": 180}, "assembly_required": true}' WHERE product_id = 21;
UPDATE products SET specs = '{"weight_kg": 5, "origin": "Dinajpur", "organic": false, "shelf_life_months": 12}' WHERE product_id = 22;
UPDATE products SET specs = '{"weight_kg": 25, "origin": "Dinajpur", "organic": false, "shelf_life_months": 12}' WHERE product_id = 23;
UPDATE products SET specs = '{"weight_kg": 2, "origin": "Rajshahi", "organic": true, "shelf_life_months": 9}' WHERE product_id = 24;
UPDATE products SET specs = '{"weight_g": 400, "type": "black tea", "origin": "Sylhet", "shelf_life_months": 24}' WHERE product_id = 25;
UPDATE products SET specs = '{"weight_g": 300, "pieces": 6, "spicy": true, "shelf_life_months": 6}' WHERE product_id = 26;
UPDATE products SET specs = '{"weight_g": 500, "handmade": true, "origin": "Barishal", "shelf_life_months": 1}' WHERE product_id = 27;
UPDATE products SET specs = '{"weight_g": 100, "skin_type": ["oily", "normal"], "organic": true, "shelf_life_months": 24}' WHERE product_id = 28;
UPDATE products SET specs = '{"volume_ml": 100, "spf": 50, "skin_type": ["all"], "organic": false, "shelf_life_months": 36}' WHERE product_id = 29;
UPDATE products SET specs = '{"volume_ml": 120, "skin_type": ["dry", "sensitive"], "organic": true, "shelf_life_months": 18}' WHERE product_id = 30;

-- EXPECTED ERROR 4025 (CHECK chk_products_specs_json: not valid JSON):
--   UPDATE products SET specs = '{ram_gb: 8' WHERE product_id = 1;

-- 12.1 JSON_VALUE: read single values (phones and laptops with their RAM)
SELECT product_name,
       JSON_VALUE(specs, '$.ram_gb')      AS ram_gb,
       JSON_VALUE(specs, '$.storage_gb')  AS storage_gb,
       JSON_VALUE(specs, '$.display_inch') AS display_inch
FROM products
WHERE category_id IN (6, 7)
ORDER BY CAST(JSON_VALUE(specs, '$.ram_gb') AS UNSIGNED) DESC, product_name;

-- 12.2 JSON_EXTRACT: read an array and a nested object
SELECT product_name,
       JSON_EXTRACT(specs, '$.colors')          AS colors,
       JSON_EXTRACT(specs, '$.colors[0]')       AS first_color,
       JSON_EXTRACT(specs, '$.dimensions_cm.h') AS height_cm
FROM products
WHERE JSON_EXTRACT(specs, '$.colors') IS NOT NULL
   OR JSON_EXTRACT(specs, '$.dimensions_cm') IS NOT NULL
ORDER BY product_id;

-- 12.3 JSON_CONTAINS: products that are available in Black
SELECT product_id, product_name, JSON_EXTRACT(specs, '$.colors') AS colors
FROM products
WHERE JSON_CONTAINS(specs, '"Black"', '$.colors');

-- 12.4 JSON in a WHERE clause with a normal column: electronics with at
--      least 12 months of warranty, cheapest first
SELECT product_name, price, JSON_VALUE(specs, '$.warranty_months') AS warranty_months
FROM products
WHERE CAST(JSON_VALUE(specs, '$.warranty_months') AS UNSIGNED) >= 12
ORDER BY price;
-- =====================================================================
-- TASK 13: ACCESS CONTROL AND SECURITY
-- (run as root, the default user of XAMPP)
-- =====================================================================
DROP USER IF EXISTS 'mkt_admin'@'localhost';
DROP USER IF EXISTS 'mkt_staff'@'localhost';
DROP USER IF EXISTS 'mkt_viewer'@'localhost';
DROP ROLE IF EXISTS role_admin;
DROP ROLE IF EXISTS role_staff;
DROP ROLE IF EXISTS role_customer_viewer;

-- 13.1 three roles
CREATE ROLE role_admin;
CREATE ROLE role_staff;
CREATE ROLE role_customer_viewer;

-- 13.2 privileges (principle of least privilege)
-- admin: everything, but only inside this database
GRANT ALL PRIVILEGES ON ecommerce_marketplace.* TO role_admin;

-- staff: handles orders and deliveries; can read the catalogue and customers
GRANT SELECT ON ecommerce_marketplace.categories  TO role_staff;
GRANT SELECT, UPDATE ON ecommerce_marketplace.products TO role_staff;
GRANT SELECT ON ecommerce_marketplace.customers   TO role_staff;
GRANT SELECT ON ecommerce_marketplace.addresses   TO role_staff;
GRANT SELECT ON ecommerce_marketplace.couriers    TO role_staff;
GRANT SELECT, INSERT, UPDATE ON ecommerce_marketplace.orders      TO role_staff;
GRANT SELECT, INSERT, UPDATE ON ecommerce_marketplace.order_items TO role_staff;
GRANT SELECT, INSERT, UPDATE ON ecommerce_marketplace.deliveries  TO role_staff;
GRANT SELECT ON ecommerce_marketplace.payments    TO role_staff;
GRANT SELECT ON ecommerce_marketplace.v_seller_public        TO role_staff;
GRANT SELECT ON ecommerce_marketplace.v_seller_sales_summary TO role_staff;
GRANT EXECUTE ON PROCEDURE ecommerce_marketplace.sp_place_order  TO role_staff;
GRANT EXECUTE ON PROCEDURE ecommerce_marketplace.sp_cancel_order TO role_staff;

-- REVOKE: staff must not change products (prices), so UPDATE is taken back
REVOKE UPDATE ON ecommerce_marketplace.products FROM role_staff;

-- customer_viewer: read-only catalogue. Sellers are visible ONLY through
-- the security view v_seller_public (no NID, bank account or phone).
GRANT SELECT ON ecommerce_marketplace.categories        TO role_customer_viewer;
GRANT SELECT ON ecommerce_marketplace.v_active_products TO role_customer_viewer;
GRANT SELECT ON ecommerce_marketplace.reviews           TO role_customer_viewer;
GRANT SELECT ON ecommerce_marketplace.v_seller_public   TO role_customer_viewer;

-- 13.3 three users, one per role
CREATE USER 'mkt_admin'@'localhost'  IDENTIFIED BY 'Admin#2105';
CREATE USER 'mkt_staff'@'localhost'  IDENTIFIED BY 'Staff#2105';
CREATE USER 'mkt_viewer'@'localhost' IDENTIFIED BY 'Viewer#2105';

GRANT role_admin           TO 'mkt_admin'@'localhost';
GRANT role_staff           TO 'mkt_staff'@'localhost';
GRANT role_customer_viewer TO 'mkt_viewer'@'localhost';

SET DEFAULT ROLE role_admin           FOR 'mkt_admin'@'localhost';
SET DEFAULT ROLE role_staff           FOR 'mkt_staff'@'localhost';
SET DEFAULT ROLE role_customer_viewer FOR 'mkt_viewer'@'localhost';
FLUSH PRIVILEGES;

-- 13.4 check what was granted
SHOW GRANTS FOR role_staff;
SHOW GRANTS FOR role_customer_viewer;
SHOW GRANTS FOR 'mkt_viewer'@'localhost';

-- 13.5 Demonstration (log in as the restricted user in the MySQL shell):
--        xampp\mysql\bin\mysql -u mkt_viewer -p        (password: Viewer#2105)
--        USE ecommerce_marketplace;
--   PERMITTED:
--        SELECT * FROM v_seller_public;
--   DENIED, EXPECTED ERROR 1142 (SELECT command denied):
--        SELECT shop_name, nid_no, bank_account_no FROM sellers;
--   DENIED, EXPECTED ERROR 1142 (UPDATE command denied):
--        UPDATE v_active_products SET price = 1 WHERE product_id = 1;
--
--   And as staff:  xampp\mysql\bin\mysql -u mkt_staff -p   (password: Staff#2105)
--   PERMITTED:   UPDATE orders SET order_status = 'shipped' WHERE order_id = 59;
--   DENIED 1142: UPDATE products SET price = 10 WHERE product_id = 1;   (revoked)
--   DENIED 1142: DELETE FROM orders WHERE order_id = 59;

-- =====================================================================
-- BONUS: scheduled Event and monthly summary report procedure
-- =====================================================================
DELIMITER $$

-- B1: a stored procedure that prints a complete monthly summary report
CREATE PROCEDURE sp_monthly_sales_report(IN p_year INT, IN p_month INT)
BEGIN
  -- part 1: headline numbers of the month
  SELECT p_year AS report_year, p_month AS report_month,
         COUNT(*)                                           AS orders_placed,
         SUM(order_status = 'delivered')                    AS delivered,
         SUM(order_status = 'cancelled')                    AS cancelled,
         COALESCE(SUM(CASE WHEN order_status <> 'cancelled'
                           THEN total_amount END), 0)       AS revenue,
         COUNT(DISTINCT customer_id)                        AS active_customers
  FROM orders
  WHERE YEAR(order_date) = p_year AND MONTH(order_date) = p_month;

  -- part 2: revenue per category
  SELECT c.category_name,
         SUM(oi.quantity)                 AS units_sold,
         SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders o
  INNER JOIN order_items oi ON oi.order_id   = o.order_id
  INNER JOIN products p     ON p.product_id  = oi.product_id
  INNER JOIN categories c   ON c.category_id = p.category_id
  WHERE YEAR(o.order_date) = p_year AND MONTH(o.order_date) = p_month
    AND o.order_status <> 'cancelled'
  GROUP BY c.category_id, c.category_name
  ORDER BY revenue DESC;

  -- part 3: money collected per payment method
  SELECT pay.method, COUNT(*) AS payments, SUM(pay.amount) AS amount_paid
  FROM payments pay
  INNER JOIN orders o ON o.order_id = pay.order_id
  WHERE YEAR(o.order_date) = p_year AND MONTH(o.order_date) = p_month
    AND pay.payment_status = 'paid'
  GROUP BY pay.method
  ORDER BY amount_paid DESC;
END$$

-- B2: a scheduled Event. Every night it empties cart items that have
--     been sitting in a cart for more than 90 days.
CREATE EVENT ev_clear_old_cart_items
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
DO
BEGIN
  DELETE FROM cart_items WHERE added_at < NOW() - INTERVAL 90 DAY;
END$$

DELIMITER ;

-- Run this line alone in the SQL tab (it returns 3 result sets, which stops an Import):
--   CALL sp_monthly_sales_report(2026, 10);
SHOW EVENTS FROM ecommerce_marketplace;
-- The event only runs when the scheduler is on:  SET GLOBAL event_scheduler = ON;

-- ============================ END OF SCRIPT ============================
