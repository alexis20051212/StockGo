CREATE DATABASE IF NOT EXISTS stockgo CHARACTER SET utf8mb4;
USE stockgo;
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  email VARCHAR(120) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  rol ENUM('admin','empleado') NOT NULL DEFAULT 'empleado',
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo_barras VARCHAR(50) UNIQUE,
  nombre VARCHAR(150) NOT NULL,
  marca VARCHAR(100),
  categoria VARCHAR(100),
  imagen_url VARCHAR(400),
  stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
  activo TINYINT(1) NOT NULL DEFAULT 1
);
-- Movimientos: solo INSERT (inmutables, RF17)
CREATE TABLE movimientos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  usuario_id INT NOT NULL,
  tipo ENUM('entrada','salida') NOT NULL,
  cantidad INT NOT NULL CHECK (cantidad > 0),
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);
