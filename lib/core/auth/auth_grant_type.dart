enum AuthGrantType {
  clientCredentials('CLIENT_CREDENTIALS'),
  refreshToken('REFRESH_TOKEN');

  const AuthGrantType(this.value);

  final String value;
}
