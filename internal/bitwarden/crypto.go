package bitwarden

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"strings"

	"filippo.io/age"
	"filippo.io/age/armor"
)

// EncryptWithAgeRecipient encrypts data using age with the given recipient.
// The recipient can be a public key string (age1...) or a recipient object.
func EncryptWithAgeRecipient(data []byte, recipient age.Recipient) ([]byte, error) {
	var buf bytes.Buffer
	aw := armor.NewWriter(&buf)
	w, err := age.Encrypt(aw, recipient)
	if err != nil {
		return nil, fmt.Errorf("create age encryptor: %w", err)
	}
	if _, err := w.Write(data); err != nil {
		return nil, fmt.Errorf("write to age encryptor: %w", err)
	}
	if err := w.Close(); err != nil {
		return nil, fmt.Errorf("close age encryptor: %w", err)
	}
	if err := aw.Close(); err != nil {
		return nil, fmt.Errorf("close armor writer: %w", err)
	}
	return buf.Bytes(), nil
}

// EncryptWithAgeKeyFile encrypts data using age, deriving the public key
// from the identity file at keyFilePath.
func EncryptWithAgeKeyFile(data []byte, keyFilePath string) ([]byte, error) {
	identities, err := readAgeIdentities(keyFilePath)
	if err != nil {
		return nil, err
	}
	if len(identities) == 0 {
		return nil, fmt.Errorf("no identities found in %s", keyFilePath)
	}

	// Get the recipient (public key) from the first identity
	x25519Identity, ok := identities[0].(*age.X25519Identity)
	if !ok {
		return nil, fmt.Errorf("identity is not X25519 type")
	}
	recipient := x25519Identity.Recipient()

	var buf bytes.Buffer
	aw := armor.NewWriter(&buf)
	w, err := age.Encrypt(aw, recipient)
	if err != nil {
		return nil, fmt.Errorf("create age encryptor: %w", err)
	}
	if _, err := w.Write(data); err != nil {
		return nil, fmt.Errorf("write to age encryptor: %w", err)
	}
	if err := w.Close(); err != nil {
		return nil, fmt.Errorf("close age encryptor: %w", err)
	}
	if err := aw.Close(); err != nil {
		return nil, fmt.Errorf("close armor writer: %w", err)
	}
	return buf.Bytes(), nil
}

// DecryptWithAge decrypts age-encrypted data using the identity file at keyFilePath.
func DecryptWithAge(encrypted []byte, keyFilePath string) ([]byte, error) {
	identities, err := readAgeIdentities(keyFilePath)
	if err != nil {
		return nil, err
	}

	ar := armor.NewReader(bytes.NewReader(encrypted))
	r, err := age.Decrypt(ar, identities...)
	if err != nil {
		return nil, fmt.Errorf("decrypt age data: %w", err)
	}

	decrypted, err := io.ReadAll(r)
	if err != nil {
		return nil, fmt.Errorf("read decrypted data: %w", err)
	}
	return decrypted, nil
}

// readAgeIdentities reads age identities from a key file.
func readAgeIdentities(keyFilePath string) ([]age.Identity, error) {
	f, err := os.Open(keyFilePath)
	if err != nil {
		return nil, fmt.Errorf("open age key file: %w", err)
	}
	defer f.Close()

	identities, err := age.ParseIdentities(f)
	if err != nil {
		return nil, fmt.Errorf("parse age identities: %w", err)
	}
	return identities, nil
}

// EncryptFileAge encrypts a file in-place using age with the given recipient.
func EncryptFileAge(filePath string, recipientPubKey string) error {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("read file for encryption: %w", err)
	}

	// Parse the recipient public key
	recipient, err := age.ParseX25519Recipient(strings.TrimSpace(recipientPubKey))
	if err != nil {
		return fmt.Errorf("parse age recipient: %w", err)
	}

	encrypted, err := EncryptWithAgeRecipient(data, recipient)
	if err != nil {
		return err
	}
	return os.WriteFile(filePath, encrypted, 0600)
}

// DecryptFileAge decrypts an age-encrypted file using the identity at keyFilePath.
func DecryptFileAge(filePath string, keyFilePath string) ([]byte, error) {
	encrypted, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("read encrypted file: %w", err)
	}
	return DecryptWithAge(encrypted, keyFilePath)
}
