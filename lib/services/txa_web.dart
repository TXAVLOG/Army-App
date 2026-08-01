class TXAWeb {
  static const String domain = 'https://army-txa-app.web.app';
  static const String inviteUrlTemplate = '$domain/invite/%username%';

  /// Returns the invite link for a specific username
  static String getInviteLink(String username) {
    final cleaned = username.replaceAll('@', '');
    return inviteUrlTemplate.replaceAll('%username%', cleaned);
  }
}
