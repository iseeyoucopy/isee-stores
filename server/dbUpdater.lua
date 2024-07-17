CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS isee_stores (
            `store_id` int(11) NOT NULL AUTO_INCREMENT,  -- A unified primary key
            `owner_id` int(30) NOT NULL,
            `store_name` varchar(255) NOT NULL,
            `store_coords` longtext NOT NULL,
            `store_type` varchar(20) NOT NULL,
            `webhook_link` varchar(255) NOT NULL DEFAULT 'none',
            `inv_limit` int(30) NOT NULL DEFAULT 0,
            `ledger` double(11,2) NOT NULL DEFAULT 0.00,
            `blip_hash` varchar(255) NOT NULL DEFAULT 'none',
            `item_id` int(11) NOT NULL,
            `item_db_name` varchar(255) NOT NULL,
            `item_name` varchar(255) NOT NULL,
            `item_price` double(11,2) NOT NULL,
            `item_stock` int(30) NOT NULL,
            `item_metadata` longtext NOT NULL,
            `item_description` varchar(255) NOT NULL,
            `weapon_id` int(30) NOT NULL,
            `weapon_price` double(11,2) NOT NULL,
            `label` varchar(255) NOT NULL,
            `custom_desc` varchar(255) DEFAULT NULL,
            `weapon_name` varchar(255) NOT NULL,
            `weapon_info` longtext NOT NULL,
            PRIMARY KEY (`store_id`),
            UNIQUE KEY `unique_store_item_weapon` (`store_id`, `item_id`, `weapon_id`),
            KEY `owner_id` (`owner_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])
    
    MySQL.query.await( "ALTER TABLE `isee_stores` ADD CONSTRAINT `isee_stores_ibfk_1` FOREIGN KEY  IF NOT EXISTS (`owner_id`) REFERENCES `characters` (`charidentifier`) ON DELETE CASCADE")

    -- Commit any pending transactions to ensure changes are saved
    MySQL.query.await("COMMIT;")
    print("\x1b[32mDatabase tables for\x1b[0m \x1b[34m[`isee_stores`]\x1b[0m \x1b[32mcreated or updated successfully.\x1b[0m")
end)
