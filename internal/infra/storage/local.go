package storage

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
)

// LocalStore stores uploaded files on the local filesystem.
// Files are served as static assets via the /uploads/* route.
type LocalStore struct {
	dir     string // absolute path to uploads directory
	baseURL string // public URL prefix, e.g. "http://localhost:8080/uploads"
}

// NewLocalStore creates a local file store, ensuring the directory exists.
func NewLocalStore(dir, baseURL string) (*LocalStore, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("create uploads dir: %w", err)
	}
	return &LocalStore{dir: dir, baseURL: strings.TrimRight(baseURL, "/")}, nil
}

// AllowedImageTypes maps extensions to MIME types for validation.
var AllowedImageTypes = map[string]string{
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".png":  "image/png",
}

const MaxUploadSize = 5 << 20 // 5 MB

// Save writes a file to disk and returns the public URL.
// ext must include the dot, e.g. ".jpg".
func (s *LocalStore) Save(reader io.Reader, ext string) (string, error) {
	filename := uuid.New().String() + ext
	path := filepath.Join(s.dir, filename)

	f, err := os.Create(path)
	if err != nil {
		return "", fmt.Errorf("create file: %w", err)
	}
	defer f.Close()

	if _, err := io.Copy(f, reader); err != nil {
		os.Remove(path) // best-effort cleanup
		return "", fmt.Errorf("write file: %w", err)
	}

	return s.baseURL + "/" + filename, nil
}
