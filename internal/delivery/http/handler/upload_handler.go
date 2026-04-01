package handler

import (
	"io"
	"net/http"
	"path/filepath"
	"strings"

	"eventapp/internal/delivery/http/response"
	"eventapp/internal/infra/storage"

	"github.com/gin-gonic/gin"
)

// UploadHandler handles file upload endpoints.
type UploadHandler struct {
	store *storage.LocalStore
}

func NewUploadHandler(store *storage.LocalStore) *UploadHandler {
	return &UploadHandler{store: store}
}

// Upload godoc
// @Summary      Upload a file (poster image)
// @Description  Accepts a multipart file upload (jpg/png, max 5MB). Returns the public URL.
// @Tags         uploads
// @Accept       multipart/form-data
// @Produce      json
// @Security     BearerAuth
// @Param        file  formData  file  true  "Image file (jpg/png, max 5MB)"
// @Success      200   {object}  map[string]string
// @Failure      400   {object}  response.ErrorBody
// @Router       /api/upload [post]
func (h *UploadHandler) Upload(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, storage.MaxUploadSize)

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		response.ValidationErr(c, "file is required (max 5MB)", nil)
		return
	}
	defer file.Close()

	ext := strings.ToLower(filepath.Ext(header.Filename))
	if _, ok := storage.AllowedImageTypes[ext]; !ok {
		response.ValidationErr(c, "only jpg and png files are allowed", nil)
		return
	}

	// Read into limited reader for safety
	limited := io.LimitReader(file, storage.MaxUploadSize)

	url, err := h.store.Save(limited, ext)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, gin.H{"url": url})
}
