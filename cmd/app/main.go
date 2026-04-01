// @title           EventApp API
// @version         1.2
// @description     Platform for school students and IT/robotics event organizers.
// @termsOfService  http://localhost:8080

// @contact.name   EventApp Team
// @contact.email  support@eventapp.local

// @license.name  MIT

// @host      localhost:8080
// @BasePath  /

// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Enter: Bearer {token}
package main

import (
	"fmt"
	"log"

	"eventapp/config"
	_ "eventapp/docs"
	"eventapp/internal/app"
	deliveryhttp "eventapp/internal/delivery/http"
	"eventapp/internal/delivery/http/handler"
	"eventapp/internal/infra/jwt"
	"eventapp/internal/infra/notify"
	"eventapp/internal/infra/postgres"
	redisinfra "eventapp/internal/infra/redis"
	"eventapp/internal/infra/storage"
)

func main() {
	// --- Configuration ---
	cfg := config.Load()

	// --- Database ---
	db, err := postgres.Connect(postgres.Config{
		Host:     cfg.DB.Host,
		Port:     cfg.DB.Port,
		User:     cfg.DB.User,
		Password: cfg.DB.Password,
		DBName:   cfg.DB.Name,
		SSLMode:  cfg.DB.SSLMode,
	})
	if err != nil {
		log.Fatalf("database: %v", err)
	}

	// --- Redis ---
	rdb, err := redisinfra.Connect(redisinfra.Config{
		Addr:     cfg.Redis.Addr,
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	})
	if err != nil {
		log.Fatalf("redis: %v", err)
	}

	// --- File Storage ---
	baseURL := fmt.Sprintf("http://localhost:%s/uploads", cfg.App.Port)
	fileStore, err := storage.NewLocalStore("./uploads", baseURL)
	if err != nil {
		log.Fatalf("file storage: %v", err)
	}

	// --- Repositories ---
	userRepo := postgres.NewUserRepo(db)
	eventRepo := postgres.NewEventRepo(db)
	regRepo := postgres.NewRegistrationRepo(db)
	favRepo := postgres.NewFavoriteRepo(db)
	notifRepo := postgres.NewNotificationRepo(db)
	deviceRepo := postgres.NewDeviceTokenRepo(db)
	auditRepo := postgres.NewAuditLogRepo(db)
	refreshStore := redisinfra.NewRefreshStore(rdb)

	// --- Notification sender ---
	// In development: LogSender (prints to stdout).
	// In production: replace with APNsSender or FCMSender.
	pushSender := notify.NewLogSender()

	// --- JWT ---
	jwtProvider := jwt.New(cfg.JWT.Secret)

	// --- Usecases ---
	auditSvc := app.NewAuditService(auditRepo)
	authUC := app.NewAuthUsecase(userRepo, jwtProvider, refreshStore, jwt.GenerateRefreshToken, jwt.HashRefreshToken)
	profileUC := app.NewProfileUsecase(userRepo)
	eventUC := app.NewEventUsecase(eventRepo, userRepo)
	notifUC := app.NewNotificationUsecase(notifRepo, deviceRepo, pushSender)
	regUC := app.NewRegistrationUsecase(regRepo, eventRepo, notifUC)
	favUC := app.NewFavoriteUsecase(favRepo, eventRepo)
	reportUC := app.NewReportUsecase(eventRepo, regRepo)
	adminUC := app.NewAdminUsecase(userRepo, eventRepo, regRepo, auditSvc)

	// --- Handlers ---
	authHandler := handler.NewAuthHandler(authUC, userRepo, jwtProvider)
	profileHandler := handler.NewProfileHandler(profileUC)
	eventHandler := handler.NewEventHandler(eventUC, favUC)
	regHandler := handler.NewRegistrationHandler(regUC)
	favHandler := handler.NewFavoriteHandler(favUC)
	notifHandler := handler.NewNotificationHandler(notifUC)
	calendarHandler := handler.NewCalendarHandler(eventUC)
	reportHandler := handler.NewReportHandler(reportUC)
	uploadHandler := handler.NewUploadHandler(fileStore)
	adminHandler := handler.NewAdminHandler(adminUC)

	// --- Router ---
	r := deliveryhttp.NewRouter(deliveryhttp.Dependencies{
		Auth:          authHandler,
		Profile:       profileHandler,
		Events:        eventHandler,
		Registrations: regHandler,
		Favorites:     favHandler,
		Notifications: notifHandler,
		Calendar:      calendarHandler,
		Reports:       reportHandler,
		Upload:        uploadHandler,
		Admin:         adminHandler,
		JWT:           jwtProvider,
	})

	addr := fmt.Sprintf(":%s", cfg.App.Port)
	log.Printf("[server] starting on %s (env=%s)", addr, cfg.App.Env)
	if err := r.Run(addr); err != nil {
		log.Fatalf("server: %v", err)
	}
}
