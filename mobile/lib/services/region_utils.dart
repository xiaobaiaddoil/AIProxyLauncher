const Set<String> restrictedAiRegions = {
  'CN',
  'HK',
  'MO',
  'RU',
  'KP',
  'IR',
  'BY',
  'SY',
};

const Map<String, String> regionNames = {
  'US': '美国',
  'JP': '日本',
  'TW': '台湾',
  'SG': '新加坡',
  'HK': '香港',
  'MO': '澳门',
  'CN': '中国大陆',
  'GB': '英国',
  'UK': '英国',
  'DE': '德国',
  'KR': '韩国',
  'CA': '加拿大',
  'NL': '荷兰',
  'FR': '法国',
  'AU': '澳大利亚',
  'IN': '印度',
  'RU': '俄罗斯',
  'CH': '瑞士',
  'SE': '瑞典',
  'FI': '芬兰',
  'IE': '爱尔兰',
};

const List<String> _restrictedNodeTokens = [
  '香港',
  'hong kong',
  'hongkong',
  '🇭🇰',
  '中国',
  'china',
  '🇨🇳',
  '澳门',
  'macau',
  'macao',
  '🇲🇴',
  '俄罗斯',
  'russia',
  '🇷🇺',
  '回国',
  'direct',
  '直连',
];

const List<(String, List<String>)> _nodeRegionPatterns = [
  (
    'US',
    [
      '美国',
      '🇺🇸',
      'united states',
      'america',
      'los angeles',
      'san jose',
      'seattle',
      'new york',
      'dallas',
      'chicago',
      'silicon',
    ]
  ),
  ('JP', ['日本', '🇯🇵', 'japan', 'tokyo', 'osaka', '东京', '大阪']),
  ('TW', ['台湾', '🇹🇼', 'taiwan', 'taipei', '台北']),
  ('SG', ['新加坡', '狮城', '🇸🇬', 'singapore']),
  ('HK', ['香港', '🇭🇰', 'hong kong', 'hongkong']),
  ('GB', ['英国', '🇬🇧', 'united kingdom', 'london', '伦敦']),
  ('DE', ['德国', '🇩🇪', 'germany', 'frankfurt', '法兰克福']),
  ('KR', ['韩国', '🇰🇷', 'korea', 'seoul', '首尔']),
  ('CA', ['加拿大', '🇨🇦', 'canada', 'toronto', 'vancouver']),
  ('NL', ['荷兰', '🇳🇱', 'netherlands', 'amsterdam']),
  ('FR', ['法国', '🇫🇷', 'france', 'paris']),
  ('AU', ['澳大利亚', '澳洲', '🇦🇺', 'australia', 'sydney']),
  ('RU', ['俄罗斯', '🇷🇺', 'russia', 'moscow']),
  ('CN', ['中国', '🇨🇳', 'china']),
];

final RegExp _codeTokenRegex = RegExp(
  r'(?:^|[^a-z])(us|jp|tw|sg|hk|gb|uk|de|kr|ca|nl|fr|au|ru|cn|mo)(?:$|[^a-z])',
  caseSensitive: false,
);

final RegExp _restrictedCodeRegex = RegExp(
  r'(?:^|[^a-z])(hk|cn|mo|ru)(?:$|[^a-z])',
  caseSensitive: false,
);

bool isRestrictedRegion(String code) {
  return restrictedAiRegions.contains(code.trim().toUpperCase());
}

String regionLabel(String code) {
  final upper = code.trim().toUpperCase();
  if (upper.isEmpty) return '';
  return regionNames[upper] ?? upper;
}

bool nodeLooksRestricted(String name) {
  final folded = name.toLowerCase();
  for (final token in _restrictedNodeTokens) {
    if (folded.contains(token)) return true;
  }
  return _restrictedCodeRegex.hasMatch(folded);
}

String inferRegionFromNode(String nodeName) {
  if (nodeName.isEmpty) return '';
  final folded = nodeName.toLowerCase();
  for (final (code, tokens) in _nodeRegionPatterns) {
    for (final token in tokens) {
      if (folded.contains(token)) return code;
    }
  }
  final match = _codeTokenRegex.firstMatch(folded);
  if (match != null) {
    final code = match.group(1)!.toUpperCase();
    return code == 'UK' ? 'GB' : code;
  }
  return '';
}

String parseCloudflareTraceRegion(String body) {
  for (final rawLine in body.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('loc=')) {
      final code = line.substring(4).trim().toUpperCase();
      if (code.length == 2 && RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
        return code;
      }
    }
  }
  return '';
}

