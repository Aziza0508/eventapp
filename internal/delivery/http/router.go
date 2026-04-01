package http

import (
	"eventapp/internal/delivery/http/handler"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/domain"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

// Dependencies holds all handlers needed to wire up the router.
type Dependencies struct {
	Auth          *handler.AuthHandler
	Profile       *handler.ProfileHandler
	Events        *handler.EventHandler
	Registrations *handler.RegistrationHandler
	Favorites     *handler.FavoriteHandler
	Notifications *handler.NotificationHandler
	Calendar      *handler.CalendarHandler
	Reports       *handler.ReportHandler
	Upload        *handler.UploadHandler
	Admin         *handler.AdminHandler
	JWT           middleware.JWTValidator
}

// NewRouter builds and returns the gin engine with all routes.
func NewRouter(deps Dependencies) *gin.Engine {
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.RequestID())
	r.Use(middleware.Logger())

	// Metrics collection.
	metrics := middleware.NewMetrics()
	r.Use(metrics.Middleware())

	// Health + readiness + metrics (unauthenticated — for infra probes).
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	r.GET("/ready", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ready"})
	})
	r.GET("/metrics", metrics.Handler())

	// Swagger UI
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// Static files for uploads
	r.Static("/uploads", "./uploads")

	// Public auth routes
	auth := r.Group("/auth")
	{
		auth.POST("/register", deps.Auth.Register)
		auth.POST("/login", deps.Auth.Login)
		auth.POST("/refresh", deps.Auth.Refresh)
	}

	// Authenticated auth routes
	authProtected := r.Group("/auth")
	authProtected.Use(middleware.Auth(deps.JWT))
	{
		authProtected.POST("/logout", deps.Auth.Logout)
	}

	// Protected routes — all require a valid JWT
	api := r.Group("/api")
	api.Use(middleware.Auth(deps.JWT))
	{
		// Profile
		api.GET("/me", deps.Profile.GetProfile)
		api.PUT("/me", deps.Profile.UpdateProfile)

		// Favorites
		api.GET("/me/favorites", deps.Favorites.ListMy)

		// Events — read
		api.GET("/events", deps.Events.List)
		api.GET("/events/:id", deps.Events.GetByID)

		// Events — bookmarks + calendar
		api.POST("/events/:id/favorite", deps.Favorites.Add)
		api.DELETE("/events/:id/favorite", deps.Favorites.Remove)
		api.GET("/events/:id/calendar.ics", deps.Calendar.GetICS)

		// Notifications
		api.GET("/notifications", deps.Notifications.List)
		api.GET("/notifications/unread-count", deps.Notifications.UnreadCount)
		api.PATCH("/notifications/:id/read", deps.Notifications.MarkRead)
		api.POST("/notifications/read-all", deps.Notifications.MarkAllRead)

		// Device tokens (push)
		api.POST("/devices", deps.Notifications.RegisterDevice)
		api.DELETE("/devices", deps.Notifications.UnregisterDevice)

		// Reports (organizer/admin)
		reports := api.Group("/reports")
		reports.Use(middleware.RequireRole(domain.RoleOrganizer, domain.RoleAdmin))
		{
			reports.GET("/events/:id/attendance", deps.Reports.AttendanceJSON)
			reports.GET("/events/:id/attendance.csv", deps.Reports.AttendanceCSV)
			reports.GET("/organizer/summary", deps.Reports.OrganizerSummary)
			reports.GET("/organizer/summary.csv", deps.Reports.OrganizerSummaryCSV)
		}

		// Events — write (organizer/admin)
		organizerOnly := api.Group("/")
		organizerOnly.Use(middleware.RequireRole(domain.RoleOrganizer, domain.RoleAdmin))
		{
			organizerOnly.POST("/events", deps.Events.Create)
			organizerOnly.PUT("/events/:id", deps.Events.Update)
			organizerOnly.DELETE("/events/:id", deps.Events.Delete)
			organizerOnly.GET("/events/:id/participants", deps.Registrations.Participants)
			organizerOnly.GET("/events/:id/participants/export.csv", deps.Registrations.ExportCSV)
			organizerOnly.PATCH("/registrations/:id/status", deps.Registrations.UpdateStatus)
			organizerOnly.PATCH("/registrations/:id/checkin", deps.Registrations.CheckinByQR)
		}

		// Upload (organizer/admin)
		uploadGroup := api.Group("/")
		uploadGroup.Use(middleware.RequireRole(domain.RoleOrganizer, domain.RoleAdmin))
		{
			uploadGroup.POST("/upload", deps.Upload.Upload)
		}

		// Registrations
		api.POST("/events/:id/apply", deps.Registrations.Apply)
		api.DELETE("/registrations/:id", deps.Registrations.Cancel)
		api.GET("/registrations/:id/qr", deps.Registrations.GetQRPayload)
		api.GET("/my/events", deps.Registrations.MyRegistrations)

		// Admin
		admin := api.Group("/admin")
		admin.Use(middleware.RequireRole(domain.RoleAdmin))
		{
			admin.GET("/dashboard", deps.Admin.Dashboard)
			admin.GET("/audit", deps.Admin.AuditLogs)
			admin.GET("/users", deps.Admin.ListUsers)
			admin.PATCH("/users/:id/block", deps.Admin.BlockUser)
			admin.PATCH("/users/:id/unblock", deps.Admin.UnblockUser)
			admin.PATCH("/users/:id/role", deps.Admin.ChangeRole)
			admin.GET("/organizers/pending", deps.Admin.ListPendingOrganizers)
			admin.PATCH("/organizers/:id/approve", deps.Admin.ApproveOrganizer)
			admin.PATCH("/organizers/:id/reject", deps.Admin.RejectOrganizer)
		}
	}

	return r
}
