WITH RECURSIVE dates (date, OFFSET) AS (
	-- Gera sequência de dias em um período
    SELECT :data_inicial AS date, 1 AS OFFSET	-- data inicial
    UNION ALL
    SELECT DATE_ADD(:data_final, INTERVAL OFFSET DAY), OFFSET + 1		-- data inicial
    FROM dates
    WHERE dates.date < :data_final	-- data final
),
available_addresses AS (
	-- Quantidade total de itens (Removendo itens oculpados em pedidos da estrutura antiga)
    SELECT isa.item_id, SUM(isa.quantity) as quantity
    FROM item_storage_addresses isa          
    WHERE isa.quantity > 0
    AND isa.transaction_item_id IS NULL
    GROUP BY isa.item_id
),
unavailable_dates AS (
    -- Caso base: interseções entre dois pedidos
    SELECT 
        LEAST(p1.id, p2.id) AS pedido_1,
		GREATEST(p2.id, p1.id) AS pedido_2,  
		ol.id_item,
        SUM(ol.quantity) as quantity,
		GREATEST(p1.delivery_at, p2.delivery_at) AS delivery_at,
		LEAST(p1.return_at, p2.return_at) AS return_at        
    FROM orders p1
	JOIN orders p2 ON p1.id != p2.id
		AND p1.delivery_at <= p2.return_at
        AND p1.return_at >= p2.delivery_at
    JOIN order_lines ol ON ol.id_order = p1.id
    WHERE p1.id_order_status NOT IN (1, 5)	
    GROUP BY pedido_1, pedido_2, ol.id_item, delivery_at, return_at

    UNION ALL

    -- Parte recursiva: expandir interseções para mais de N pedidos
    SELECT 
        LEAST(gi.pedido_1, p.id) AS pedido_1,
		GREATEST(p.id, gi.pedido_1) AS pedido_2,  
        ol.id_item,
		gi.quantity + ol.quantity AS quantity,
		GREATEST(gi.delivery_at, p.delivery_at) AS delivery_at,
		LEAST(gi.return_at, p.return_at) AS return_at        
    FROM unavailable_dates gi
    JOIN orders p ON p.id > gi.pedido_2
		AND gi.delivery_at <= p.return_at
        AND gi.return_at >= p.delivery_at
    JOIN order_lines ol ON ol.id_order = p.id 
		AND ol.id_item = gi.id_item
	WHERE p.id_order_status NOT IN (1, 5)	
)
SELECT aa.item_id,
    aa.quantity AS item_total_quantity,
    MAX(ud.quantity) AS quantity_unavailable,
    MIN(aa.quantity - ud.quantity) as quantity_available
FROM available_addresses aa
JOIN dates d ON 1 = 1
LEFT JOIN unavailable_dates ud ON ud.id_item = aa.item_id
WHERE aa.item_id IN (:item_id) -- teste para apenas um item
-- ADICIONAR JOINS E CONDIÇÕES AO INVÉS PARA LISTAGEM DOS ITENS
GROUP BY aa.item_id, item_total_quantity;