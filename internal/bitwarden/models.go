package bitwarden

type VaultItem struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	Type       int        `json:"type"`
	Login      *Login     `json:"login,omitempty"`
	Notes      string     `json:"notes,omitempty"`
	Favorite   bool       `json:"favorite"`
	Fields     []Field    `json:"fields,omitempty"`
	Card       *Card      `json:"card,omitempty"`
	Identity   *Identity  `json:"identity,omitempty"`
	SecureNote *SecureNote `json:"secureNote,omitempty"`
}

type Login struct {
	Username string `json:"username,omitempty"`
	Password string `json:"password,omitempty"`
	Uris     []URI  `json:"uris,omitempty"`
	TOTP     string `json:"totp,omitempty"`
}

type URI struct {
	URI string `json:"uri,omitempty"`
}

type Field struct {
	Name  string `json:"name"`
	Value string `json:"value"`
	Type  int    `json:"type"`
}

type Card struct {
	Brand          string `json:"brand,omitempty"`
	Number         string `json:"number,omitempty"`
	CardholderName string `json:"cardholderName,omitempty"`
	ExpMonth       string `json:"expMonth,omitempty"`
	ExpYear        string `json:"expYear,omitempty"`
	Code           string `json:"code,omitempty"`
}

type Identity struct {
	Title      string `json:"title,omitempty"`
	FirstName  string `json:"firstName,omitempty"`
	MiddleName string `json:"middleName,omitempty"`
	LastName   string `json:"lastName,omitempty"`
	Email      string `json:"email,omitempty"`
	Phone      string `json:"phone,omitempty"`
	Address1   string `json:"address1,omitempty"`
	Address2   string `json:"address2,omitempty"`
	City       string `json:"city,omitempty"`
	State      string `json:"state,omitempty"`
	PostalCode string `json:"postalCode,omitempty"`
	Country    string `json:"country,omitempty"`
}

type SecureNote struct {
	Type int `json:"type"`
}

func (i VaultItem) Icon() string {
	switch i.Type {
	case 1:
		return "🔑"
	case 2:
		return "💳"
	case 3:
		return "🔒"
	case 4:
		return "📝"
	case 5:
		return "📁"
	default:
		return "📄"
	}
}

func (i VaultItem) TypeLabel() string {
	switch i.Type {
	case 1:
		return "Login"
	case 2:
		return "Card"
	case 3:
		return "Identity"
	case 4:
		return "Note"
	case 5:
		return "Folder"
	default:
		return "Item"
	}
}

func (i VaultItem) Username() string {
	if i.Login != nil {
		return i.Login.Username
	}
	return ""
}

func (i VaultItem) PrimaryURI() string {
	if i.Login != nil && len(i.Login.Uris) > 0 {
		return i.Login.Uris[0].URI
	}
	return ""
}

func (i VaultItem) HasURI() bool {
	return i.PrimaryURI() != ""
}
