package postgres

import (
	"errors"

	"eventapp/internal/app"
	"eventapp/internal/domain"

	"gorm.io/gorm"
)

// UserRepo implements app.UserRepository using GORM.
type UserRepo struct{ db *gorm.DB }

func NewUserRepo(db *gorm.DB) *UserRepo { return &UserRepo{db: db} }

func (r *UserRepo) Create(user *domain.User) error {
	return r.db.Create(user).Error
}

func (r *UserRepo) GetByEmail(email string) (*domain.User, error) {
	var u domain.User
	if err := r.db.Where("email = ?", email).First(&u).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r *UserRepo) GetByID(id uint) (*domain.User, error) {
	var u domain.User
	if err := r.db.First(&u, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r *UserRepo) Update(user *domain.User) error {
	return r.db.Save(user).Error
}

func (r *UserRepo) ListByRoleAndApproval(role domain.UserRole, approved bool) ([]domain.User, error) {
	var users []domain.User
	if err := r.db.Where("role = ? AND approved = ?", role, approved).
		Order("created_at DESC").Find(&users).Error; err != nil {
		return nil, err
	}
	return users, nil
}

func (r *UserRepo) ListFiltered(f app.UserFilter) ([]domain.User, int64, error) {
	q := r.db.Model(&domain.User{})

	if f.Role != "" {
		q = q.Where("role = ?", f.Role)
	}
	if f.Approved != nil {
		q = q.Where("approved = ?", *f.Approved)
	}
	if f.Blocked != nil {
		q = q.Where("blocked = ?", *f.Blocked)
	}
	if f.Search != "" {
		p := "%" + f.Search + "%"
		q = q.Where("(full_name ILIKE ? OR email ILIKE ?)", p, p)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if f.Limit <= 0 || f.Limit > 100 {
		f.Limit = 50
	}
	if f.Page <= 0 {
		f.Page = 1
	}
	offset := (f.Page - 1) * f.Limit

	var users []domain.User
	err := q.Order("created_at DESC").Offset(offset).Limit(f.Limit).Find(&users).Error
	return users, total, err
}

func (r *UserRepo) CountByRole() (map[domain.UserRole]int64, error) {
	type result struct {
		Role  domain.UserRole
		Count int64
	}
	var rows []result
	err := r.db.Model(&domain.User{}).
		Select("role, count(*) as count").
		Group("role").
		Find(&rows).Error
	if err != nil {
		return nil, err
	}
	m := make(map[domain.UserRole]int64)
	for _, row := range rows {
		m[row.Role] = row.Count
	}
	return m, nil
}
