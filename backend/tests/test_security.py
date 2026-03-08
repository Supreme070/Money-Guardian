"""Tests for security utilities: encryption, tokens, password hashing."""

from uuid import uuid4

import pytest

from app.core.security import (
    create_access_token,
    create_refresh_token,
    create_token_pair,
    decode_token,
    decrypt_sensitive_data,
    encrypt_sensitive_data,
    get_password_hash,
    verify_password,
)


class TestPasswordHashing:
    """Tests for bcrypt password hashing."""

    def test_hash_and_verify(self) -> None:
        password = "SecureP@ss123"
        hashed = get_password_hash(password)
        assert verify_password(password, hashed) is True

    def test_wrong_password_fails(self) -> None:
        hashed = get_password_hash("correct_password")
        assert verify_password("wrong_password", hashed) is False

    def test_different_hashes_for_same_password(self) -> None:
        password = "SamePassword"
        hash1 = get_password_hash(password)
        hash2 = get_password_hash(password)
        assert hash1 != hash2  # bcrypt uses different salt each time
        assert verify_password(password, hash1) is True
        assert verify_password(password, hash2) is True


class TestTokenEncryption:
    """Tests for Fernet encryption of sensitive data."""

    def test_encrypt_decrypt_roundtrip(self) -> None:
        plaintext = "access-sandbox-abc123-plaid-token"
        encrypted = encrypt_sensitive_data(plaintext)
        decrypted = decrypt_sensitive_data(encrypted)
        assert decrypted == plaintext

    def test_encrypted_is_different_from_plaintext(self) -> None:
        plaintext = "my-secret-token"
        encrypted = encrypt_sensitive_data(plaintext)
        assert encrypted != plaintext

    def test_different_ciphertexts_for_same_plaintext(self) -> None:
        """Fernet includes a random IV, so same plaintext = different ciphertext."""
        plaintext = "same-token"
        enc1 = encrypt_sensitive_data(plaintext)
        enc2 = encrypt_sensitive_data(plaintext)
        assert enc1 != enc2
        assert decrypt_sensitive_data(enc1) == plaintext
        assert decrypt_sensitive_data(enc2) == plaintext

    def test_decrypt_invalid_data_raises(self) -> None:
        with pytest.raises(Exception):
            decrypt_sensitive_data("not-valid-fernet-data")


class TestJWTTokens:
    """Tests for JWT token creation and decoding."""

    def test_create_access_token(self) -> None:
        user_id = uuid4()
        tenant_id = uuid4()
        token = create_access_token(user_id, tenant_id, "test@example.com")
        payload = decode_token(token)
        assert payload is not None
        assert payload.sub == str(user_id)
        assert payload.tenant_id == str(tenant_id)
        assert payload.email == "test@example.com"
        assert payload.token_type == "access"

    def test_create_refresh_token(self) -> None:
        user_id = uuid4()
        tenant_id = uuid4()
        token = create_refresh_token(user_id, tenant_id, "test@example.com")
        payload = decode_token(token)
        assert payload is not None
        assert payload.token_type == "refresh"

    def test_create_token_pair(self) -> None:
        user_id = uuid4()
        tenant_id = uuid4()
        pair = create_token_pair(user_id, tenant_id, "test@example.com")
        assert pair.token_type == "bearer"

        access = decode_token(pair.access_token)
        refresh = decode_token(pair.refresh_token)
        assert access is not None and access.token_type == "access"
        assert refresh is not None and refresh.token_type == "refresh"
        assert access.sub == refresh.sub == str(user_id)
        assert access.tenant_id == refresh.tenant_id == str(tenant_id)

    def test_decode_invalid_token_returns_none(self) -> None:
        assert decode_token("not.a.valid.jwt") is None

    def test_decode_tampered_token_returns_none(self) -> None:
        user_id = uuid4()
        tenant_id = uuid4()
        token = create_access_token(user_id, tenant_id, "test@example.com")
        # Tamper with the token
        tampered = token[:-5] + "XXXXX"
        assert decode_token(tampered) is None

    def test_token_contains_tenant_id(self) -> None:
        """Every token MUST contain tenant_id for multi-tenant security."""
        user_id = uuid4()
        tenant_id = uuid4()
        token = create_access_token(user_id, tenant_id, "test@example.com")
        payload = decode_token(token)
        assert payload is not None
        assert payload.tenant_id == str(tenant_id)
