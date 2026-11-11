-- Ejecutar UNA vez en la base existente (Aiven) ANTES de desplegar la nueva versión del backend.
USE stockgo;  -- base de datos de StockGo (en Aiven también se llama stockgo)
ALTER TABLE productos ADD COLUMN stock_minimo INT NOT NULL DEFAULT 5;
CREATE TABLE IF NOT EXISTS auditoria (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  accion VARCHAR(30) NOT NULL,
  entidad VARCHAR(30) NOT NULL,
  detalle VARCHAR(250),
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);
