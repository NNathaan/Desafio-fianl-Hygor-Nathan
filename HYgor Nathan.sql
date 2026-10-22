USE omnichannel_db;

-- -----------------------------------------------------
-- Trigger: Auditoria de Preço
-- -----------------------------------------------------
DELIMITER $$

CREATE TRIGGER trg_auditoria_preco
AFTER UPDATE ON produtos
FOR EACH ROW
BEGIN
    IF OLD.preco <> NEW.preco THEN
        INSERT INTO auditoria_preco (id_produto, preco_antigo, preco_novo, data_alteracao, usuario)
        VALUES (NEW.id_produto, OLD.preco, NEW.preco, NOW(), USER());
    END IF;
END$$  -- ----------------------------------------------------- -- Stored Procedure: Processar Venda -- ----------------------------------------------------- CREATE PROCEDURE sp_registrar_venda ( IN p_id_cliente INT, IN p_id_loja INT, IN p_origem_compra ENUM('LOJA FISICA', 'E COMMERCE'), IN p_forma_pagamento ENUM('PIX', 'CARTAO', 'BOLETO'), IN p_id_produto INT, IN p_quantidade INT ) BEGIN DECLARE v_estoque_atual INT; DECLARE v_preco_unitario DECIMAL(10,2); DECLARE v_valor_total DECIMAL(10,2); DECLARE v_novo_pedido_id INT;      -- Verificar estoque e preço do produto SELECT estoque_atual, preco INTO v_estoque_atual, v_preco_unitario FROM produtos WHERE id_produto = p_id_produto;      IF v_estoque_atual IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: Produto não encontrado.'; ELSEIF v_estoque_atual < p_quantidade THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: Estoque insuficiente para realizar a venda.'; ELSE -- Cálculo do valor total SET v_valor_total = v_preco_unitario * p_quantidade;          -- Registrar o Pedido INSERT INTO pedidos (id_cliente, id_loja, origem_compra, forma_pagamento, valor_total, status) VALUES (p_id_cliente, p_id_loja, p_origem_compra, p_forma_pagamento, v_valor_total, 'CONCLUIDO');          SET v_novo_pedido_id = LAST_INSERT_ID();          -- Inserir Item do Pedido INSERT INTO itens_pedido (id_pedido, id_produto, quantidade, preco_unitario) VALUES (v_novo_pedido_id, p_id_produto, p_quantidade, v_preco_unitario);          -- Atualizar Estoque do Produto UPDATE produtos SET estoque_atual = estoque_atual - p_quantidade WHERE id_produto = p_id_produto;          -- Checar Alerta de Estoque Mínimo (RN01) IF (v_estoque_atual - p_quantidade) < 5 THEN SELECT CONCAT('ALERTA: Produto (ID ', p_id_produto, ') atinge nível de estoque mínimo de segurança!') AS mensagem_alerta; END IF; END IF; END$$

DELIMITER ;

-- =====================================================
-- TESTES DE VALIDAÇÃO DAS AUTOMAÇÕES
-- =====================================================

-- Teste 1: Trigger de Auditoria de Preço
UPDATE produtos SET preco = 4300.00 WHERE id_produto = 1;
SELECT * FROM auditoria_preco WHERE id_produto = 1;

-- Teste 2: Stored Procedure de Venda
CALL sp_registrar_venda(1, 2, 'E COMMERCE', 'PIX', 4, 2);