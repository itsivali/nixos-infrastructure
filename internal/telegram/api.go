package telegram

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// API handles communication with the Telegram Bot API.
type API struct {
	token   string
	baseURL string
	client  *http.Client
}

// NewAPI creates a new Telegram API client.
func NewAPI(token string) *API {
	return &API{
		token:   token,
		baseURL: fmt.Sprintf("https://api.telegram.org/bot%s", token),
		client: &http.Client{
			// Must exceed the getUpdates long-poll timeout (60s); otherwise
			// idle polls are cancelled by the client before Telegram returns.
			Timeout: 90 * time.Second,
		},
	}
}

// SendMessage sends a text message with optional parse mode.
func (a *API) SendMessage(chatID int64, text string, parseMode string) error {
	params := url.Values{
		"chat_id":                  {strconv.FormatInt(chatID, 10)},
		"text":                     {text},
		"disable_web_page_preview": {"true"},
	}
	if parseMode != "" {
		params.Set("parse_mode", parseMode)
	}
	return a.post("sendMessage", params)
}

// SendMarkdown sends a message with Markdown formatting.
func (a *API) SendMarkdown(chatID int64, text string) error {
	return a.SendMessage(chatID, text, "Markdown")
}

// SendHTML sends a message with HTML formatting.
func (a *API) SendHTML(chatID int64, text string) error {
	return a.SendMessage(chatID, text, "HTML")
}

// SendTyping sends a typing action indicator.
func (a *API) SendTyping(chatID int64) error {
	params := url.Values{
		"chat_id": {strconv.FormatInt(chatID, 10)},
		"action":  {"typing"},
	}
	return a.post("sendChatAction", params)
}

// SendLongMessage splits and sends a long message in chunks.
func (a *API) SendLongMessage(chatID int64, text string, maxChars int) error {
	if maxChars <= 0 {
		maxChars = 3500
	}

	if len(text) <= maxChars {
		return a.SendMarkdown(chatID, text)
	}

	lines := strings.Split(text, "\n")
	chunk := ""
	inCodeBlock := false

	for _, line := range lines {
		toggled := strings.HasPrefix(line, "```")
		candidate := line
		if chunk != "" {
			candidate = chunk + "\n" + line
		}

		if len(candidate) > maxChars && chunk != "" {
			// Send current chunk
			if inCodeBlock {
				chunk += "\n```"
			}
			if err := a.SendMarkdown(chatID, chunk); err != nil {
				return err
			}
			if inCodeBlock {
				chunk = "```"
			} else {
				chunk = ""
			}
			candidate = line
		}

		chunk = candidate

		if toggled {
			inCodeBlock = !inCodeBlock
		}
	}

	if chunk != "" {
		if inCodeBlock {
			chunk += "\n```"
		}
		return a.SendMarkdown(chatID, chunk)
	}

	return nil
}

// SendPhoto sends a local image file to the chat.
func (a *API) SendPhoto(chatID int64, filePath string, caption string) error {
	f, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("open photo: %w", err)
	}
	defer f.Close()

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("photo", filepath.Base(filePath))
	if err != nil {
		return fmt.Errorf("create form file: %w", err)
	}
	if _, err := io.Copy(part, f); err != nil {
		return fmt.Errorf("copy photo: %w", err)
	}
	if err := writer.WriteField("chat_id", strconv.FormatInt(chatID, 10)); err != nil {
		return err
	}
	if caption != "" {
		if err := writer.WriteField("caption", caption); err != nil {
			return err
		}
		if err := writer.WriteField("parse_mode", "Markdown"); err != nil {
			return err
		}
	}
	if err := writer.Close(); err != nil {
		return err
	}

	req, err := http.NewRequest("POST", a.baseURL+"/sendPhoto", body)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := a.client.Do(req)
	if err != nil {
		return fmt.Errorf("telegram API sendPhoto: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("read response: %w", err)
	}

	var result struct {
		Ok          bool   `json:"ok"`
		Description string `json:"description"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return fmt.Errorf("parse response: %w", err)
	}
	if !result.Ok {
		return fmt.Errorf("telegram API sendPhoto: %s", result.Description)
	}
	return nil
}

// EditMessage edits an existing message.
func (a *API) EditMessage(chatID int64, messageID int, text string, parseMode string) error {
	params := url.Values{
		"chat_id":    {strconv.FormatInt(chatID, 10)},
		"message_id": {strconv.Itoa(messageID)},
		"text":       {text},
	}
	if parseMode != "" {
		params.Set("parse_mode", parseMode)
	}
	return a.post("editMessageText", params)
}

// AnswerCallback answers a callback query.
func (a *API) AnswerCallback(callbackQueryID string, text string) error {
	params := url.Values{
		"callback_query_id": {callbackQueryID},
	}
	if text != "" {
		params.Set("text", text)
	}
	return a.post("answerCallbackQuery", params)
}

// SendInlineKeyboard sends a message with inline keyboard buttons.
func (a *API) SendInlineKeyboard(chatID int64, text string, buttons []InlineButton) error {
	keyboard := buildInlineKeyboard(buttons)
	params := url.Values{
		"chat_id":                  {strconv.FormatInt(chatID, 10)},
		"text":                     {text},
		"parse_mode":               {"Markdown"},
		"reply_markup":             {keyboard},
		"disable_web_page_preview": {"true"},
	}
	return a.post("sendMessage", params)
}

// InlineButton represents an inline keyboard button.
type InlineButton struct {
	Text         string
	CallbackData string
}

// KeyboardButton represents a reply-keyboard button.
type KeyboardButton struct {
	Text string `json:"text"`
}

// SendReplyKeyboard sends a message with a persistent reply keyboard
// (the main menu). Buttons are grouped into rows; each cell is a
// label such as "🖥 /status".
func (a *API) SendReplyKeyboard(chatID int64, text string, rows [][]string) error {
	keyboard := buildReplyKeyboard(rows)
	params := url.Values{
		"chat_id":                  {strconv.FormatInt(chatID, 10)},
		"text":                     {text},
		"parse_mode":               {"Markdown"},
		"reply_markup":             {keyboard},
		"disable_web_page_preview": {"true"},
		"resize_keyboard":          {"true"},
	}
	return a.post("sendMessage", params)
}

func buildReplyKeyboard(rows [][]string) string {
	if len(rows) == 0 {
		return ""
	}
	kbd := make([][]KeyboardButton, 0, len(rows))
	for _, r := range rows {
		row := make([]KeyboardButton, 0, len(r))
		for _, label := range r {
			row = append(row, KeyboardButton{Text: label})
		}
		kbd = append(kbd, row)
	}
	data, _ := json.Marshal(map[string]any{
		"keyboard":          kbd,
		"resize_keyboard":   true,
		"one_time_keyboard": false,
	})
	return string(data)
}

func buildInlineKeyboard(buttons []InlineButton) string {
	if len(buttons) == 0 {
		return ""
	}

	rows := make([][]InlineButton, 0)
	row := make([]InlineButton, 0)
	for i, btn := range buttons {
		row = append(row, btn)
		if (i+1)%3 == 0 || i == len(buttons)-1 {
			rows = append(rows, row)
			row = make([]InlineButton, 0)
		}
	}

	keyboard := map[string]any{
		"inline_keyboard": rows,
	}
	data, _ := json.Marshal(keyboard)
	return string(data)
}

// RegisterCommands registers bot commands with the Telegram API.
func (a *API) RegisterCommands(commands []CommandInfo) error {
	type command struct {
		Command     string `json:"command"`
		Description string `json:"description"`
	}

	cmds := make([]command, len(commands))
	for i, c := range commands {
		cmds[i] = command{
			Command:     c.Name,
			Description: c.Description,
		}
	}

	data, _ := json.Marshal(cmds)
	params := url.Values{
		"commands": {string(data)},
	}
	return a.post("setMyCommands", params)
}

// CommandInfo represents a command for registration with Telegram.
type CommandInfo struct {
	Name        string
	Description string
}

// GetUpdates long-polls for new updates.
func (a *API) GetUpdates(offset int, timeout int) ([]Update, error) {
	params := url.Values{
		"offset":          {strconv.Itoa(offset)},
		"timeout":         {strconv.Itoa(timeout)},
		"allowed_updates": {`["message","callback_query"]`},
	}

	resp, err := a.get("getUpdates", params)
	if err != nil {
		return nil, err
	}

	var result struct {
		Ok     bool     `json:"ok"`
		Result []Update `json:"result"`
	}
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("parse updates: %w", err)
	}

	if !result.Ok {
		return nil, fmt.Errorf("getUpdates returned ok=false")
	}

	return result.Result, nil
}

// Update represents a Telegram update.
type Update struct {
	UpdateID      int            `json:"update_id"`
	Message       *UpdateMessage `json:"message,omitempty"`
	CallbackQuery *CallbackQuery `json:"callback_query,omitempty"`
}

// UpdateMessage represents a message in an update.
type UpdateMessage struct {
	MessageID int    `json:"message_id"`
	From      *User  `json:"from"`
	Chat      *Chat  `json:"chat"`
	Text      string `json:"text"`
	Date      int64  `json:"date"`
}

// CallbackQuery represents a callback query.
type CallbackQuery struct {
	ID      string         `json:"id"`
	From    *User          `json:"from"`
	Chat    *Chat          `json:"chat,omitempty"`
	Data    string         `json:"data"`
	Message *UpdateMessage `json:"message,omitempty"`
}

// User represents a Telegram user.
type User struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
}

// Chat represents a Telegram chat.
type Chat struct {
	ID   int64  `json:"id"`
	Type string `json:"type"`
}

// post sends a POST request to the Telegram API.
func (a *API) post(method string, params url.Values) error {
	resp, err := a.client.PostForm(a.baseURL+"/"+method, params)
	if err != nil {
		return fmt.Errorf("telegram API %s: %w", method, err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("read response: %w", err)
	}

	var result struct {
		Ok          bool   `json:"ok"`
		Description string `json:"description"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return fmt.Errorf("parse response: %w", err)
	}

	if !result.Ok {
		return fmt.Errorf("telegram API %s: %s", method, result.Description)
	}

	return nil
}

// get sends a GET request to the Telegram API.
func (a *API) get(method string, params url.Values) ([]byte, error) {
	reqURL := a.baseURL + "/" + method + "?" + params.Encode()
	resp, err := a.client.Get(reqURL)
	if err != nil {
		return nil, fmt.Errorf("telegram API %s: %w", method, err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	return body, nil
}
