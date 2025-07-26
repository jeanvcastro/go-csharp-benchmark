package main

import (
	"log"
	"net/http"

	"benchmark-go/internal/config"
	"benchmark-go/internal/database"
	"benchmark-go/internal/handlers"
	"benchmark-go/internal/metrics"
	"benchmark-go/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	cfg := config.Load()

	if err := database.InitializePostgres(cfg); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer database.ClosePostgres()

	metrics.StartSystemMetricsCollection()

	router := setupRouter()

	serverAddr := cfg.Server.Host + ":" + cfg.Server.Port
	log.Printf("Starting server on %s", serverAddr)

	if err := router.Run(serverAddr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func setupRouter() *gin.Engine {
	router := gin.New()

	router.Use(middleware.TimingMiddleware())
	router.Use(middleware.MetricsMiddleware())
	router.Use(middleware.RequestTimingMiddleware())

	userHandler := handlers.NewUserHandler()
	orderHandler := handlers.NewOrderHandler()

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "healthy",
			"service": "benchmark-go",
		})
	})

	router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	api := router.Group("/api/v1")
	{
		users := api.Group("/users")
		{
			users.GET("", userHandler.GetUsers)
			users.GET("/:id", userHandler.GetUserByID)
			users.POST("", userHandler.CreateUser)
			users.PUT("/:id", userHandler.UpdateUser)
			users.DELETE("/:id", userHandler.DeleteUser)
		}

		orders := api.Group("/orders")
		{
			orders.GET("", orderHandler.GetOrders)
			orders.GET("/:id", orderHandler.GetOrderByID)
			orders.POST("", orderHandler.CreateOrder)
		}
	}

	return router
}