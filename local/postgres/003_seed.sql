INSERT INTO accounts (id, owner_name, balance_pence, currency)
VALUES ('acc_123', 'Example Customer', 125000, 'GBP')
ON CONFLICT (id) DO UPDATE
SET owner_name = EXCLUDED.owner_name,
    balance_pence = EXCLUDED.balance_pence,
    currency = EXCLUDED.currency;
