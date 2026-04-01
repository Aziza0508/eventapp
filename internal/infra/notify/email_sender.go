package notify

import (
	"bytes"
	"fmt"
	"html/template"
	"log"
	"net/smtp"
)

// SMTPConfig holds email delivery settings.
type SMTPConfig struct {
	Host     string // e.g. "smtp.gmail.com"
	Port     string // e.g. "587"
	User     string // sender email
	Password string // app-specific password
	From     string // display from, e.g. "EventApp <noreply@eventapp.kz>"
	Enabled  bool   // set false to skip sending (dev mode)
}

// EmailSender sends HTML emails via SMTP.
// In development (Enabled=false), it only logs the email content.
type EmailSender struct {
	cfg  SMTPConfig
	tmpl *template.Template
}

// NewEmailSender creates an email sender and parses the built-in template.
func NewEmailSender(cfg SMTPConfig) *EmailSender {
	tmpl := template.Must(template.New("email").Parse(emailTemplate))
	return &EmailSender{cfg: cfg, tmpl: tmpl}
}

// EmailData holds the template variables for notification emails.
type EmailData struct {
	Title      string
	Body       string
	EventTitle string
	EventDate  string
	EventCity  string
	ActionURL  string
}

// SendEmail sends an HTML email to the given address.
func (s *EmailSender) SendEmail(to, subject string, data EmailData) error {
	var buf bytes.Buffer
	if err := s.tmpl.Execute(&buf, data); err != nil {
		return fmt.Errorf("render email template: %w", err)
	}

	if !s.cfg.Enabled {
		log.Printf("[email/dev] → to=%s subject=%q (SMTP disabled, not sent)", to, subject)
		return nil
	}

	msg := fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n%s",
		s.cfg.From, to, subject, buf.String(),
	)

	auth := smtp.PlainAuth("", s.cfg.User, s.cfg.Password, s.cfg.Host)
	addr := s.cfg.Host + ":" + s.cfg.Port

	if err := smtp.SendMail(addr, auth, s.cfg.User, []string{to}, []byte(msg)); err != nil {
		return fmt.Errorf("smtp send: %w", err)
	}

	log.Printf("[email] sent to=%s subject=%q", to, subject)
	return nil
}

// emailTemplate is a reusable HTML email template for all notification types.
const emailTemplate = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background: #f5f5f7; }
    .container { max-width: 560px; margin: 24px auto; background: #fff; border-radius: 12px; overflow: hidden; }
    .header { background: linear-gradient(135deg, #4A6BF5, #8C5CF6); padding: 32px 24px; text-align: center; }
    .header h1 { color: #fff; font-size: 20px; margin: 0; }
    .body { padding: 24px; }
    .body p { color: #333; font-size: 15px; line-height: 1.6; }
    .event-card { background: #f8f8fa; border-radius: 8px; padding: 16px; margin: 16px 0; }
    .event-card .label { color: #888; font-size: 12px; text-transform: uppercase; }
    .event-card .value { color: #333; font-size: 14px; font-weight: 600; }
    .cta { display: inline-block; background: linear-gradient(135deg, #4A6BF5, #8C5CF6); color: #fff; text-decoration: none; padding: 12px 24px; border-radius: 24px; font-weight: 600; font-size: 14px; margin-top: 16px; }
    .footer { text-align: center; padding: 16px; color: #aaa; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>{{.Title}}</h1>
    </div>
    <div class="body">
      <p>{{.Body}}</p>
      {{if .EventTitle}}
      <div class="event-card">
        <div class="label">Event</div>
        <div class="value">{{.EventTitle}}</div>
        {{if .EventDate}}
        <div class="label" style="margin-top:8px">Date</div>
        <div class="value">{{.EventDate}}</div>
        {{end}}
        {{if .EventCity}}
        <div class="label" style="margin-top:8px">Location</div>
        <div class="value">{{.EventCity}}</div>
        {{end}}
      </div>
      {{end}}
      {{if .ActionURL}}
      <p style="text-align:center"><a href="{{.ActionURL}}" class="cta">Open in App</a></p>
      {{end}}
    </div>
    <div class="footer">EventApp &mdash; Your STEM event platform</div>
  </div>
</body>
</html>`
