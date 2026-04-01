package postgres

import (
	"fmt"
	"log"

	"eventapp/internal/domain"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Config holds PostgreSQL connection parameters.
type Config struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// DSN builds the connection string.
func (c Config) DSN() string {
	ssl := c.SSLMode
	if ssl == "" {
		ssl = "disable"
	}
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, ssl,
	)
}

// Connect opens a GORM database connection and runs AutoMigrate for dev convenience.
// In production, use the SQL migrations in /migrations instead.
func Connect(cfg Config) (*gorm.DB, error) {
	db, err := gorm.Open(postgres.Open(cfg.DSN()), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Warn),
	})
	if err != nil {
		return nil, fmt.Errorf("connect postgres: %w", err)
	}

	// AutoMigrate keeps schema in sync during development.
	// The SQL migration files in /migrations serve as the authoritative schema reference.
	log.Println("[db] running auto-migrate...")
	if err := db.AutoMigrate(
		&domain.User{},
		&domain.Event{},
		&domain.Registration{},
		&domain.Favorite{},
		&domain.Notification{},
		&domain.DeviceToken{},
		&domain.AuditLog{},
	); err != nil {
		return nil, fmt.Errorf("auto-migrate: %w", err)
	}
	log.Println("[db] migrations done")

	return db, nil
}
