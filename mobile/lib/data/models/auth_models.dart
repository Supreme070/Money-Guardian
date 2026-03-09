/// Authentication data models - matching backend Pydantic schemas
/// NO dynamic, NO Object?, strictly typed

class RegisterRequest {
  final String email;
  final String password;
  final String? fullName;
  final bool acceptedTerms;
  final bool acceptedPrivacy;

  const RegisterRequest({
    required this.email,
    required this.password,
    this.fullName,
    required this.acceptedTerms,
    required this.acceptedPrivacy,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        if (fullName != null) 'full_name': fullName,
        'accepted_terms': acceptedTerms,
        'accepted_privacy': acceptedPrivacy,
      };
}

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class RefreshRequest {
  final String refreshToken;

  const RefreshRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {
        'refresh_token': refreshToken,
      };
}

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

class PasswordResetRequest {
  final String email;

  const PasswordResetRequest({required this.email});

  Map<String, String> toJson() => {'email': email};
}

class PasswordResetConfirm {
  final String token;
  final String newPassword;

  const PasswordResetConfirm({
    required this.token,
    required this.newPassword,
  });

  Map<String, String> toJson() => {
        'token': token,
        'new_password': newPassword,
      };
}

class ChangePasswordRequest {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, String> toJson() => {
        'current_password': currentPassword,
        'new_password': newPassword,
      };
}

class MessageResponse {
  final String message;

  const MessageResponse({required this.message});

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(message: json['message'] as String);
  }
}
