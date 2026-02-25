ALTER TABLE product ADD COLUMN IF NOT EXISTS price double precision;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS date_created date default current_date;

DROP TABLE IF EXISTS product_info;

DROP TABLE IF EXISTS orders_date;