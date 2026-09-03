String stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
