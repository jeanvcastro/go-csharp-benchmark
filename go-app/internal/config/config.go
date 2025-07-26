package config

import (
	"os"
	"strconv"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
}

type ServerConfig struct {
	Port string
	Host string
}

type DatabaseConfig struct {
	Host            string
	Port            string
	User            string
	Password        string
	Database        string
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime int
}

func Load() *Config {
	return &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
			Host: getEnv("SERVER_HOST", "0.0.0.0"),
		},
		Database: DatabaseConfig{
			Host:            getEnv("DB_HOST", "postgres"),
			Port:            getEnv("DB_PORT", "5432"),
			User:            getEnv("DB_USER", "benchmark_user"),
			Password:        getEnv("DB_PASSWORD", "benchmark_pass"),
			Database:        getEnv("DB_NAME", "benchmark"),
			MaxOpenConns:    getEnvAsInt("DB_MAX_CONNECTIONS", 100),
			MaxIdleConns:    getEnvAsInt("DB_MAX_IDLE_CONNECTIONS", 10),
			ConnMaxLifetime: getEnvAsInt("DB_CONNECTION_MAX_LIFETIME", 300),
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}