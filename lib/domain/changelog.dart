/// One heading in a release (New, Improved, Fixed) and its lines.
class ChangelogSection {
  final String title;
  final List<String> items;
  const ChangelogSection(this.title, this.items);
}

/// One released version: `## 1.1.0+2 · 2026-11-13` in CHANGELOG.md.
class Release {
  final String version;
  final int build;
  final DateTime? date;
  final List<ChangelogSection> sections;

  const Release({required this.version, required this.build, this.date, this.sections = const []});

  /// "1.1.0 (build 2)", as Settings shows it.
  String get label => '$version (build $build)';
}

/// Reads CHANGELOG.md, the one changelog for GitHub and the app. Pure.
///
/// Understands only what the file uses: `## <version>+<build> · <yyyy-mm-dd>`
/// starts a release, `### <title>` a section, `- ` an item (indented lines
/// continue it). Anything else (the intro) is ignored, as are headings that
/// don't match.
class Changelog {
  Changelog._();

  static final _release = RegExp(r'^##\s+(\d+\.\d+\.\d+)\+(\d+)(?:\s*[·\-–]\s*(\d{4}-\d{2}-\d{2}))?\s*$');

  /// Releases newest first, in file order.
  static List<Release> parse(String markdown) {
    final releases = <Release>[];
    String? version;
    var build = 0;
    DateTime? date;
    var sections = <ChangelogSection>[];
    String? sectionTitle;
    var items = <String>[];

    void closeSection() {
      if (sectionTitle != null && items.isNotEmpty) sections.add(ChangelogSection(sectionTitle!, items));
      sectionTitle = null;
      items = [];
    }

    void closeRelease() {
      closeSection();
      if (version != null) releases.add(Release(version: version!, build: build, date: date, sections: sections));
      version = null;
      sections = [];
    }

    for (final raw in markdown.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('## ')) {
        closeRelease();
        final m = _release.firstMatch(line);
        if (m != null) {
          version = m.group(1);
          build = int.parse(m.group(2)!);
          date = m.group(3) == null ? null : DateTime.tryParse(m.group(3)!);
        }
      } else if (version == null) {
        continue; // Intro text before the first release.
      } else if (line.startsWith('### ')) {
        closeSection();
        sectionTitle = line.substring(4).trim();
      } else if (line.startsWith('- ') && sectionTitle != null) {
        items.add(line.substring(2).trim());
      } else if (line.startsWith('  ') && line.trim().isNotEmpty && items.isNotEmpty) {
        items[items.length - 1] = '${items.last} ${line.trim()}';
      }
    }
    closeRelease();
    return releases;
  }
}
