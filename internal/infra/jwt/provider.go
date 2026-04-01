package jwt

import (
	"errors"
	"fmt"
	"time"

	"eventapp/internal/domain"

	gojwt "github.com/golang-jwt/jwt/v5"
)

const accessTokenTTL = 24 * time.Hour

// Provider issues and validates JWT access tokens.
type Provider struct {
	secret []byte
}

// New creates a JWT provider with the given HMAC secret.
func New(secret string) *Provider {
	return &Provider{secret: []byte(secret)}
}

type claims struct {
	UserID uint             `json:"user_id"`
	Role   domain.UserRole  `json:"role"`
	gojwt.RegisteredClaims
}

// Generate creates a signed JWT for the given user.
func (p *Provider) Generate(userID uint, role domain.UserRole) (string, error) {
	c := claims{
		UserID: userID,
		Role:   role,
		RegisteredClaims: gojwt.RegisteredClaims{
			ExpiresAt: gojwt.NewNumericDate(time.Now().Add(accessTokenTTL)),
			IssuedAt:  gojwt.NewNumericDate(time.Now()),
		},
	}
	token := gojwt.NewWithClaims(gojwt.SigningMethodHS256, c)
	return token.SignedString(p.secret)
}

// Validate parses and validates a JWT string, returning userID and role.
func (p *Provider) Validate(tokenString string) (uint, domain.UserRole, error) {
	token, err := gojwt.ParseWithClaims(tokenString, &claims{}, func(t *gojwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*gojwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return p.secret, nil
	})

	if err != nil {
		if errors.Is(err, gojwt.ErrTokenExpired) {
			return 0, "", domain.NewAppError("TOKEN_EXPIRED", "token has expired", err)
		}
		return 0, "", domain.NewAppError("INVALID_TOKEN", "invalid token", err)
	}

	c, ok := token.Claims.(*claims)
	if !ok || !token.Valid {
		return 0, "", domain.NewAppError("INVALID_TOKEN", "invalid token claims", nil)
	}

	return c.UserID, c.Role, nil
}

// ValidateIgnoringExpiry parses a JWT and returns userID and role even if the token is expired.
// The signature is still verified. Used during token refresh to identify the user.
func (p *Provider) ValidateIgnoringExpiry(tokenString string) (uint, domain.UserRole, error) {
	parser := gojwt.NewParser(gojwt.WithoutClaimsValidation())
	token, err := parser.ParseWithClaims(tokenString, &claims{}, func(t *gojwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*gojwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return p.secret, nil
	})
	if err != nil {
		return 0, "", domain.NewAppError("INVALID_TOKEN", "invalid token", err)
	}

	c, ok := token.Claims.(*claims)
	if !ok {
		return 0, "", domain.NewAppError("INVALID_TOKEN", "invalid token claims", nil)
	}

	return c.UserID, c.Role, nil
}
