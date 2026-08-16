CREATE TABLE users (
    id_user CHAR(36) PRIMARY KEY,
    name VARCHAR(150),
    email VARCHAR(150) UNIQUE,
    password_hash VARCHAR(150),
    role VARCHAR(10) CHECK (role IN ('USER','ADMIN')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE assets (
    id_asset CHAR(36) PRIMARY KEY,
    ticker VARCHAR(10),
    name VARCHAR(100),
    asset_type VARCHAR(20) CHECK (asset_type IN ('STOCK_BR','STOCK_US','CRYPTO')),
    currency VARCHAR(10),
    exchange VARCHAR(10),
    active BOOLEAN,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE asset_prices (
    id_asset_price CHAR(36) PRIMARY KEY,
    id_asset CHAR(36),
    price DECIMAL(18,8),
    volume DECIMAL(18,8),
    captured_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_asset) REFERENCES assets(id_asset)
);

CREATE TABLE portfolios (
    id_portfolio CHAR(36) PRIMARY KEY,
    id_user CHAR(36),
    name VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_user) REFERENCES users(id_user)
);

CREATE TABLE transactions (
    id_transaction CHAR(36) PRIMARY KEY,
    id_portfolio CHAR(36),
    id_asset CHAR(36),
    type VARCHAR(10) CHECK (type IN ('BUY','SELL')),
    quantity DECIMAL(18,8),
    unit_price DECIMAL(18,8),
    total_value DECIMAL(18,2),
    transaction_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_portfolio) REFERENCES portfolios(id_portfolio),
    FOREIGN KEY (id_asset) REFERENCES assets(id_asset)
);

CREATE TABLE holdings (
    id_portfolio CHAR(36),
    id_asset CHAR(36),
    quantity DECIMAL(18,8),
    avg_price DECIMAL(18,8),
    current_value DECIMAL(18,2),
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_portfolio, id_asset),
    FOREIGN KEY (id_portfolio) REFERENCES portfolios(id_portfolio),
    FOREIGN KEY (id_asset) REFERENCES assets(id_asset)
);

CREATE TABLE watchlist_items (
    id_watchlist_items CHAR(36) PRIMARY KEY,
    id_user CHAR(36),
    id_asset CHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_user) REFERENCES users(id_user),
    FOREIGN KEY (id_asset) REFERENCES assets(id_asset)
);

CREATE TABLE alerts (
    id_alert CHAR(36) PRIMARY KEY,
    id_user CHAR(36),
    id_asset CHAR(36),
    condition_type VARCHAR(20) CHECK (condition_type IN ('ABOVE','BELOW')),
    target_price DECIMAL(18,8),
    status VARCHAR(15) CHECK (status IN ('ACTIVE','TRIGGERED','CANCELLED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    triggered_at TIMESTAMP NULL,
    FOREIGN KEY (id_user) REFERENCES users(id_user),
    FOREIGN KEY (id_asset) REFERENCES assets(id_asset)
);

CREATE TABLE audit_log (
    id_audit_log CHAR(36) PRIMARY KEY,
    entity_name VARCHAR(20),
    entity_id CHAR(36),
    action VARCHAR(10) CHECK (action IN ('CREATE','UPDATE','DELETE')),
    performed_by CHAR(36),
    payload_before JSON,
    payload_after JSON,
    performed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE statement_imports (
    id_statement_imports CHAR(36) PRIMARY KEY,
    id_user CHAR(36),
    file_url VARCHAR(100),
    status VARCHAR(10) CHECK (status IN ('PENDING','PROCESSING','DONE','FAILED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL,
    FOREIGN KEY (id_user) REFERENCES users(id_user)
);