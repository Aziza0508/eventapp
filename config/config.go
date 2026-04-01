package config

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
)

// Config holds all application configuration read from environment variables.
type Config struct {
	DB    DBConfig
	JWT   JWTConfig
	Redis RedisConfig
	SMTP  SMTPConfig
	App   AppConfig
}

// SMTPConfig holds email notification settings.
type SMTPConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	From     string
	Enabled  bool
}

// RedisConfig holds Redis connection parameters.
type RedisConfig struct {
	Addr     string // host:port
	Password string
	DB       int
}

// DBConfig holds PostgreSQL connection parameters.
type DBConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	Name     string
	SSLMode  string
}

// JWTConfig holds JWT settings.
type JWTConfig struct {
	// Secret is the HMAC key for signing tokens. Must be strong in production.
	Secret string
}

// AppConfig holds HTTP server settings.
type AppConfig struct {
	Port string
	Env  string // "development" | "production"
}

// Load reads configuration from environment variables.
// It tries to load a .env file first; a missing .env is not fatal in production.
func Load() *Config {
	if err := godotenv.Load(); err != nil {
		log.Println("[config] no .env file found — using system environment")
	}

	secret := strings.TrimSpace(os.Getenv("JWT_SECRET"))
	if secret == "" || secret == "super_secret_key_for_hackathon" {
		log.Println("[config] WARNING: JWT_SECRET is weak — change it before production")
	}

	redisDB := 0
	if v := getEnv("REDIS_DB", "0"); v != "0" {
		// best-effort parse; default 0
		var d int
		if _, err := fmt.Sscanf(v, "%d", &d); err == nil {
			redisDB = d
		}
	}

	return &Config{
		DB: DBConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "postgres"),
			Password: getEnv("DB_PASSWORD", "password"),
			Name:     getEnv("DB_NAME", "eventapp"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		JWT: JWTConfig{
			Secret: secret,
		},
		Redis: RedisConfig{
			Addr:     getEnv("REDIS_ADDR", "localhost:6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       redisDB,
		},
		SMTP: SMTPConfig{
			Host:     getEnv("SMTP_HOST", ""),
			Port:     getEnv("SMTP_PORT", "587"),
			User:     getEnv("SMTP_USER", ""),
			Password: getEnv("SMTP_PASSWORD", ""),
			From:     getEnv("SMTP_FROM", "EventApp <noreply@eventapp.kz>"),
			Enabled:  getEnv("SMTP_ENABLED", "false") == "true",
		},
		App: AppConfig{
			Port: getEnv("PORT", "8080"),
			Env:  getEnv("APP_ENV", "development"),
		},
	}
}

func getEnv(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
