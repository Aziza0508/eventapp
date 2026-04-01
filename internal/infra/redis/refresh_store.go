package redis

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RefreshStore implements app.RefreshTokenStore using Redis.
//
// Key schema:
//
//	rt:{userID}:{tokenHash}  →  "1"   (with TTL)
//
// This allows per-token revocation and per-user revocation via SCAN.
type RefreshStore struct {
	rdb *redis.Client
}

// NewRefreshStore creates a Redis-backed refresh token store.
func NewRefreshStore(rdb *redis.Client) *RefreshStore {
	return &RefreshStore{rdb: rdb}
}

func tokenKey(userID uint, tokenHash string) string {
	return fmt.Sprintf("rt:%d:%s", userID, tokenHash)
}

func userPattern(userID uint) string {
	return fmt.Sprintf("rt:%d:*", userID)
}

// Save stores a refresh token hash with a TTL.
func (s *RefreshStore) Save(ctx context.Context, userID uint, tokenHash string, ttl time.Duration) error {
	return s.rdb.Set(ctx, tokenKey(userID, tokenHash), "1", ttl).Err()
}

// Exists checks if a refresh token hash is still valid.
func (s *RefreshStore) Exists(ctx context.Context, userID uint, tokenHash string) (bool, error) {
	n, err := s.rdb.Exists(ctx, tokenKey(userID, tokenHash)).Result()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// Revoke deletes a specific refresh token.
func (s *RefreshStore) Revoke(ctx context.Context, userID uint, tokenHash string) error {
	return s.rdb.Del(ctx, tokenKey(userID, tokenHash)).Err()
}

// RevokeAll deletes all refresh tokens for a user.
func (s *RefreshStore) RevokeAll(ctx context.Context, userID uint) error {
	var cursor uint64
	pattern := userPattern(userID)
	for {
		keys, next, err := s.rdb.Scan(ctx, cursor, pattern, 100).Result()
		if err != nil {
			return err
		}
		if len(keys) > 0 {
			if err := s.rdb.Del(ctx, keys...).Err(); err != nil {
				return err
			}
		}
		cursor = next
		if cursor == 0 {
			break
		}
	}
	return nil
}
